<?php

declare(strict_types=1);

namespace App\Controller;

use App\Observability\OtelLog;
use OpenTelemetry\API\Trace\Span;
use OpenTelemetry\API\Globals;
use OpenTelemetry\Context\Propagation\ArrayAccessGetterSetter;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Contracts\HttpClient\HttpClientInterface;

final class ApiController
{
    #[Route('/health', name: 'health', methods: ['GET'])]
    public function health(): JsonResponse
    {
        return new JsonResponse(['ok' => true]);
    }

    #[Route('/sleep', name: 'sleep', methods: ['GET'])]
    public function sleep(Request $request): JsonResponse
    {
        $ms = max(0, (int) $request->query->get('ms', 200));
        usleep($ms * 1000);

        OtelLog::info('slept', ['sleep_ms' => $ms]);

        return new JsonResponse(['slept_ms' => $ms]);
    }

    #[Route('/chain', name: 'chain', methods: ['GET'])]
    public function chain(Request $request, HttpClientInterface $client): JsonResponse
    {
        $ms = max(0, (int) $request->query->get('ms', 200));
        $downstream = rtrim((string) ($_ENV['DOWNSTREAM_URL'] ?? 'http://laravel-api/chain'), '/');

        $headers = [];
        Globals::propagator()->inject($headers, ArrayAccessGetterSetter::getInstance());

        $response = $client->request('GET', $downstream, [
            'query' => ['ms' => $ms],
            'headers' => $headers,
            'timeout' => 2.5,
        ]);

        $status = $response->getStatusCode();
        $body = $response->toArray(false);

        OtelLog::info('chain-downstream', ['downstream' => $downstream, 'sleep_ms' => $ms, 'status' => $status]);

        return new JsonResponse([
            'downstream_url' => $downstream,
            'downstream_status' => $status,
            'downstream_json' => $body,
        ]);
    }

    #[Route('/flow', name: 'flow', methods: ['GET'])]
    public function flow(Request $request, HttpClientInterface $client): JsonResponse
    {
        $ms = max(0, (int) $request->query->get('ms', 200));
        $publishUrl = rtrim((string) ($_ENV['PUBLISH_URL'] ?? 'http://laravel-api/publish'), '/');

        $traceId = Span::getCurrent()->getContext()->getTraceId();

        $headers = [];
        Globals::propagator()->inject($headers, ArrayAccessGetterSetter::getInstance());

        $response = $client->request('GET', $publishUrl, [
            'query' => ['ms' => $ms],
            'headers' => $headers,
            'timeout' => 2.5,
        ]);

        $status = $response->getStatusCode();
        $body = $response->toArray(false);

        OtelLog::info('flow-publish', ['publish_url' => $publishUrl, 'sleep_ms' => $ms, 'status' => $status]);

        return new JsonResponse([
            'trace_id' => $traceId,
            'publish_url' => $publishUrl,
            'publish_status' => $status,
            'publish_json' => $body,
            'note' => 'Consumer will continue this trace asynchronously via RabbitMQ headers.',
        ]);
    }
}
