<?php

declare(strict_types=1);

namespace App\Observability;

use OpenTelemetry\API\Globals;
use OpenTelemetry\API\Logs\Severity;

final class OtelLog
{
    public static function info(string $body, array $attributes = []): void
    {
        OtelSdk::boot();

        $logger = Globals::loggerProvider()->getLogger('symfony-api', '0.1.0');
        if (!$logger->isEnabled()) {
            return;
        }

        $logger->logRecordBuilder()
            ->setSeverityNumber(Severity::INFO)
            ->setSeverityText('INFO')
            ->setBody($body)
            ->setAttributes($attributes)
            ->emit();
    }
}
