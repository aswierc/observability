<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Observability\OtelSdk;
use Closure;
use Illuminate\Http\Request;
use OpenTelemetry\API\Globals;
use OpenTelemetry\API\Trace\SpanKind;
use OpenTelemetry\API\Trace\StatusCode;
use OpenTelemetry\Context\Propagation\ArrayAccessGetterSetter;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

final class ObservabilityMiddleware
{
    private const METER_NAME = 'app.metrics';
    private const METER_VERSION = '0.1.0';
    private const HISTOGRAM_NAME = 'app_request_duration_ms';

    private static mixed $histogram = null;

    public function handle(Request $request, Closure $next): Response
    {
        OtelSdk::boot();

        $carrier = [];
        foreach ($request->headers->all() as $key => $values) {
            $carrier[strtolower((string) $key)] = is_array($values) ? implode(',', $values) : (string) $values;
        }

        $context = Globals::propagator()->extract($carrier, ArrayAccessGetterSetter::getInstance());
        $tracer = Globals::tracerProvider()->getTracer('laravel-api', '0.1.0');

        $path = '/' . ltrim($request->path(), '/');
        $span = $tracer
            ->spanBuilder(sprintf('%s %s', $request->method(), $path))
            ->setParent($context)
            ->setSpanKind(SpanKind::KIND_SERVER)
            ->setAttributes([
                'http.method' => $request->method(),
                'http.route' => $path,
                'url.path' => $path,
            ])
            ->startSpan();

        $scope = $span->activate();
        $startNs = hrtime(true);

        try {
            $response = $next($request);
        } catch (Throwable $e) {
            $span->recordException($e);
            $span->setStatus(StatusCode::STATUS_ERROR, $e->getMessage());
            throw $e;
        } finally {
            $durationMs = (hrtime(true) - $startNs) / 1_000_000;
            $statusCode = isset($response) ? $response->getStatusCode() : 500;

            $span->setAttribute('http.status_code', $statusCode);
            if ($statusCode >= 500) {
                $span->setStatus(StatusCode::STATUS_ERROR);
            }
            $span->end();
            $scope->detach();

            $this->histogram()->record($durationMs, [
                'http.method' => $request->method(),
                'http.route' => $path,
                'http.status_code' => (string) $statusCode,
            ]);
        }

        return $response;
    }

    private function histogram(): mixed
    {
        if (self::$histogram !== null) {
            return self::$histogram;
        }

        $meter = Globals::meterProvider()->getMeter(self::METER_NAME, self::METER_VERSION);
        self::$histogram = $meter->createHistogram(self::HISTOGRAM_NAME, 'ms', 'HTTP request duration');

        return self::$histogram;
    }
}

