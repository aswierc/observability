<?php

declare(strict_types=1);

use App\Observability\OtelLog;
use PhpAmqpLib\Connection\AMQPStreamConnection;
use PhpAmqpLib\Message\AMQPMessage;
use PhpAmqpLib\Wire\AMQPTable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Route;

Route::get('/health', function () {
    return response()->json(['ok' => true]);
});

Route::get('/sleep', function () {
    $ms = max(0, (int) request()->query('ms', 200));
    usleep($ms * 1000);

    OtelLog::info('slept', ['sleep_ms' => $ms]);

    return response()->json(['slept_ms' => $ms]);
});

Route::get('/chain', function () {
    $ms = max(0, (int) request()->query('ms', 200));
    $downstream = rtrim((string) env('DOWNSTREAM_URL', 'http://fastapi/sleep'), '/');

    $headers = [];
    \OpenTelemetry\API\Globals::propagator()->inject($headers, \OpenTelemetry\Context\Propagation\ArrayAccessGetterSetter::getInstance());

    $response = Http::withHeaders($headers)->timeout(2.5)->get($downstream, ['ms' => $ms]);
    $response->throw();

    OtelLog::info('chain-downstream', ['downstream' => $downstream, 'sleep_ms' => $ms]);

    return response()->json([
        'downstream_url' => $downstream,
        'downstream_status' => $response->status(),
        'downstream_json' => $response->json(),
    ]);
});

Route::get('/db', function () {
    $row = DB::selectOne('select 1 as one');
    OtelLog::info('db-query', ['result' => (int) ($row->one ?? 0)]);

    return response()->json(['db' => (int) ($row->one ?? 0)]);
});

Route::get('/publish', function () {
    $ms = max(0, (int) request()->query('ms', 200));

    $host = (string) env('RABBITMQ_HOST', 'rabbitmq');
    $port = (int) env('RABBITMQ_PORT', 5672);
    $user = (string) env('RABBITMQ_USER', 'app');
    $pass = (string) env('RABBITMQ_PASS', 'app');
    $queue = (string) env('RABBITMQ_QUEUE', 'observability');

    $headers = [];
    \OpenTelemetry\API\Globals::propagator()->inject($headers, \OpenTelemetry\Context\Propagation\ArrayAccessGetterSetter::getInstance());

    $payload = [
        'id' => bin2hex(random_bytes(8)),
        'sleep_ms' => $ms,
        'sent_at' => gmdate('c'),
    ];

    $connection = new AMQPStreamConnection($host, $port, $user, $pass);
    $channel = $connection->channel();
    $channel->queue_declare($queue, false, false, false, false);

    $message = new AMQPMessage(json_encode($payload, JSON_THROW_ON_ERROR), [
        'content_type' => 'application/json',
        'delivery_mode' => 1,
        'application_headers' => new AMQPTable($headers),
        'correlation_id' => $payload['id'],
    ]);
    $channel->basic_publish($message, '', $queue);

    $channel->close();
    $connection->close();

    OtelLog::info('published', ['queue' => $queue, 'sleep_ms' => $ms, 'message_id' => $payload['id']]);

    return response()->json(['queued' => true, 'queue' => $queue, 'message' => $payload]);
});
