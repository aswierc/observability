<?php

declare(strict_types=1);

namespace App\EventSubscriber;

use App\Observability\OtelSdk;
use OpenTelemetry\API\Globals;
use OpenTelemetry\API\Trace\SpanInterface;
use OpenTelemetry\API\Trace\SpanKind;
use OpenTelemetry\API\Trace\StatusCode;
use OpenTelemetry\Context\Propagation\ArrayAccessGetterSetter;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpKernel\Event\ExceptionEvent;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\Event\ResponseEvent;
use Symfony\Component\HttpKernel\KernelEvents;
use Throwable;

final class ObservabilitySubscriber implements EventSubscriberInterface
{
    private const METER_NAME = 'app.metrics';
    private const METER_VERSION = '0.1.0';
    private const HISTOGRAM_NAME = 'app_request_duration_ms';

    private const ATTR_SPAN = '_otel.span';
    private const ATTR_SCOPE = '_otel.scope';
    private const ATTR_START_NS = '_otel.start_ns';

    private static mixed $histogram = null;

    public static function getSubscribedEvents(): array
    {
        return [
            KernelEvents::REQUEST => ['onRequest', -10],
            KernelEvents::EXCEPTION => ['onException', 0],
            KernelEvents::RESPONSE => ['onResponse', 0],
        ];
    }

    public function onRequest(RequestEvent $event): void
    {
        if (!$event->isMainRequest()) {
            return;
        }

        OtelSdk::boot();

        $request = $event->getRequest();

        $carrier = [];
        foreach ($request->headers->all() as $key => $values) {
            $carrier[strtolower((string) $key)] = is_array($values) ? implode(',', $values) : (string) $values;
        }

        $context = Globals::propagator()->extract($carrier, ArrayAccessGetterSetter::getInstance());
        $tracer = Globals::tracerProvider()->getTracer('symfony-api', '0.1.0');

        $path = (string) $request->getPathInfo();
        if ($path === '') {
            $path = '/';
        }

        $span = $tracer
            ->spanBuilder(sprintf('%s %s', $request->getMethod(), $path))
            ->setParent($context)
            ->setSpanKind(SpanKind::KIND_SERVER)
            ->setAttributes([
                'http.method' => $request->getMethod(),
                'url.path' => $path,
            ])
            ->startSpan();

        $scope = $span->activate();
        $request->attributes->set(self::ATTR_SPAN, $span);
        $request->attributes->set(self::ATTR_SCOPE, $scope);
        $request->attributes->set(self::ATTR_START_NS, hrtime(true));
    }

    public function onException(ExceptionEvent $event): void
    {
        if (!$event->isMainRequest()) {
            return;
        }

        $span = $this->spanFromRequest($event->getRequest());
        if (!$span) {
            return;
        }

        $e = $event->getThrowable();
        $span->recordException($e);
        $span->setStatus(StatusCode::STATUS_ERROR, $e->getMessage());
    }

    public function onResponse(ResponseEvent $event): void
    {
        if (!$event->isMainRequest()) {
            return;
        }

        $request = $event->getRequest();
        $span = $this->spanFromRequest($request);
        $scope = $request->attributes->get(self::ATTR_SCOPE);
        $startNs = (int) ($request->attributes->get(self::ATTR_START_NS) ?? 0);

        $response = $event->getResponse();
        $statusCode = $response->getStatusCode();

        $path = (string) $request->getPathInfo();
        if ($path === '') {
            $path = '/';
        }

        $route = $request->attributes->get('_route');
        $httpRoute = is_string($route) && $route !== '' ? $route : $path;

        try {
            if ($span) {
                $span->setAttribute('http.status_code', $statusCode);
                $span->setAttribute('http.route', $httpRoute);
                if ($statusCode >= 500) {
                    $span->setStatus(StatusCode::STATUS_ERROR);
                }
                $span->end();
            }
        } catch (Throwable) {
            // best-effort
        } finally {
            if (is_object($scope) && method_exists($scope, 'detach')) {
                $scope->detach();
            }

            $durationMs = $startNs > 0 ? (hrtime(true) - $startNs) / 1_000_000 : 0.0;
            $this->histogram()->record($durationMs, [
                'http.method' => $request->getMethod(),
                'http.route' => $httpRoute,
                'http.status_code' => (string) $statusCode,
            ]);
        }
    }

    private function spanFromRequest(object $request): ?SpanInterface
    {
        $span = $request->attributes->get(self::ATTR_SPAN);
        return $span instanceof SpanInterface ? $span : null;
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
