<?php

declare(strict_types=1);

namespace App\Observability;

use OpenTelemetry\API\Trace\Propagation\TraceContextPropagator;
use OpenTelemetry\SDK\Logs\LoggerProviderFactory;
use OpenTelemetry\SDK\Metrics\MeterProviderFactory;
use OpenTelemetry\SDK\Sdk;
use OpenTelemetry\SDK\Trace\TracerProviderFactory;

final class OtelSdk
{
    private static bool $booted = false;

    public static function boot(): void
    {
        if (self::$booted) {
            return;
        }
        self::$booted = true;

        if (Sdk::isDisabled()) {
            return;
        }

        $tracerProvider = (new TracerProviderFactory())->create();
        $meterProvider = (new MeterProviderFactory())->create();
        $loggerProvider = (new LoggerProviderFactory())->create($meterProvider);

        Sdk::builder()
            ->setAutoShutdown(true)
            ->setTracerProvider($tracerProvider)
            ->setMeterProvider($meterProvider)
            ->setLoggerProvider($loggerProvider)
            ->setPropagator(TraceContextPropagator::getInstance())
            ->buildAndRegisterGlobal();
    }
}

