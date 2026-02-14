<?php

declare(strict_types=1);

namespace App\Command;

use App\Observability\OtelLog;
use App\Observability\OtelSdk;
use OpenTelemetry\API\Globals;
use OpenTelemetry\API\Trace\SpanKind;
use OpenTelemetry\API\Trace\StatusCode;
use OpenTelemetry\Context\Propagation\ArrayAccessGetterSetter;
use PhpAmqpLib\Connection\AMQPStreamConnection;
use PhpAmqpLib\Message\AMQPMessage;
use PhpAmqpLib\Wire\AMQPTable;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Contracts\HttpClient\HttpClientInterface;
use Throwable;

#[AsCommand(
    name: 'app:rabbit:consume',
    description: 'Consume messages from RabbitMQ queue and continue OTel trace from message headers.',
)]
final class ConsumeRabbitCommand extends Command
{
    private const METER_NAME = 'app.metrics';
    private const METER_VERSION = '0.1.0';
    private const HISTOGRAM_NAME = 'app_consume_duration_ms';

    private static mixed $histogram = null;

    public function __construct(private readonly HttpClientInterface $client)
    {
        parent::__construct();
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        OtelSdk::boot();

        $host = $_ENV['RABBITMQ_HOST'] ?? 'rabbitmq';
        $port = (int) ($_ENV['RABBITMQ_PORT'] ?? 5672);
        $user = $_ENV['RABBITMQ_USER'] ?? 'app';
        $pass = $_ENV['RABBITMQ_PASS'] ?? 'app';
        $queue = $_ENV['RABBITMQ_QUEUE'] ?? 'observability';

        $connection = new AMQPStreamConnection((string) $host, $port, (string) $user, (string) $pass);
        $channel = $connection->channel();
        $channel->queue_declare((string) $queue, false, false, false, false);

        $output->writeln(sprintf('Consuming from queue=%s on %s:%d', (string) $queue, (string) $host, $port));

        $callback = function (AMQPMessage $msg) use ($channel, $queue, $output): void {
            $startNs = hrtime(true);

            $carrier = $this->carrierFromMessage($msg);
            $parent = Globals::propagator()->extract($carrier, ArrayAccessGetterSetter::getInstance());

            $tracer = Globals::tracerProvider()->getTracer('symfony-consumer', '0.1.0');
            $span = $tracer
                ->spanBuilder(sprintf('process %s', (string) $queue))
                ->setParent($parent)
                ->setSpanKind(SpanKind::KIND_CONSUMER)
                ->setAttributes([
                    'messaging.system' => 'rabbitmq',
                    'messaging.destination.name' => (string) $queue,
                    'messaging.operation' => 'process',
                ])
                ->startSpan();

            $scope = $span->activate();

            try {
                $body = (string) $msg->getBody();
                $data = json_decode($body, true, flags: JSON_THROW_ON_ERROR);
                $sleepMs = max(0, (int) ($data['sleep_ms'] ?? 0));
                $messageId = (string) ($data['id'] ?? '');

                if ($messageId !== '') {
                    $span->setAttribute('messaging.message.id', $messageId);
                }

                if ($sleepMs > 0) {
                    usleep($sleepMs * 1000);
                }

                $downstream = rtrim((string) ($_ENV['DOWNSTREAM_URL'] ?? 'http://fastapi/sleep'), '/');
                $headers = [];
                Globals::propagator()->inject($headers, ArrayAccessGetterSetter::getInstance());

                $response = $this->client->request('GET', $downstream, [
                    'query' => ['ms' => $sleepMs],
                    'headers' => $headers,
                    'timeout' => 2.5,
                ]);
                $span->setAttribute('downstream.url', $downstream);
                $span->setAttribute('downstream.status_code', $response->getStatusCode());

                OtelLog::info('consumed', [
                    'queue' => (string) $queue,
                    'sleep_ms' => $sleepMs,
                    'message_id' => $messageId,
                    'downstream' => $downstream,
                ]);

                $channel->basic_ack($msg->getDeliveryTag());
            } catch (Throwable $e) {
                $span->recordException($e);
                $span->setStatus(StatusCode::STATUS_ERROR, $e->getMessage());

                OtelLog::info('consume-error', [
                    'queue' => (string) $queue,
                    'error' => $e->getMessage(),
                ]);

                $channel->basic_nack($msg->getDeliveryTag(), false, true);
            } finally {
                $durationMs = (hrtime(true) - $startNs) / 1_000_000;
                $this->histogram()->record($durationMs, [
                    'messaging.system' => 'rabbitmq',
                    'messaging.destination.name' => (string) $queue,
                ]);

                $span->end();
                $scope->detach();

                try {
                    $tp = Globals::tracerProvider();
                    if (method_exists($tp, 'forceFlush')) {
                        $tp->forceFlush();
                    }

                    $lp = Globals::loggerProvider();
                    if (method_exists($lp, 'forceFlush')) {
                        $lp->forceFlush();
                    }

                    $mp = Globals::meterProvider();
                    if (method_exists($mp, 'forceFlush')) {
                        $mp->forceFlush();
                    }
                } catch (Throwable) {
                    // best-effort flush
                }
            }
        };

        $channel->basic_qos(null, 1, null);
        $channel->basic_consume((string) $queue, '', false, false, false, false, $callback);

        while ($channel->is_consuming()) {
            $channel->wait();
        }

        $channel->close();
        $connection->close();

        return Command::SUCCESS;
    }

    private function carrierFromMessage(AMQPMessage $msg): array
    {
        $props = $msg->get_properties();
        $table = $props['application_headers'] ?? null;
        if (!$table instanceof AMQPTable) {
            return [];
        }

        $data = $table->getNativeData();
        $carrier = [];

        foreach ($data as $key => $value) {
            if (!is_string($key)) {
                continue;
            }
            if (is_scalar($value) || $value === null) {
                $carrier[strtolower($key)] = (string) $value;
            }
        }

        return $carrier;
    }

    private function histogram(): mixed
    {
        if (self::$histogram !== null) {
            return self::$histogram;
        }

        $meter = Globals::meterProvider()->getMeter(self::METER_NAME, self::METER_VERSION);
        self::$histogram = $meter->createHistogram(self::HISTOGRAM_NAME, 'ms', 'RabbitMQ message processing duration');

        return self::$histogram;
    }
}
