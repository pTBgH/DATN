<?php

namespace App\Support\Logging;

use Illuminate\Support\Facades\Log;



class StructuredLogger
{
    private string $module;
    private string $action;
    private ?string $userId;
    private ?string $userName;
    private string $traceId;
    private string $source;

    public function __construct(
        string $module,
        string $action,
        ?string $userId   = null,
        ?string $userName = null,
        ?string $source   = null
    ) {
        $this->module    = $module;
        $this->action    = $action;
        $this->userId    = $userId;
        $this->userName  = $userName;
        $this->traceId   = $this->resolveTraceId();
        $this->source    = $source ?? $this->inferSource();
    }

    public function info(array $context = [], ?string $destination = null, ?float $durationMs = null): void
    {
        $this->write('info', 'success', $context, $destination, $durationMs);
    }

    public function warning(array $context = [], ?string $destination = null, ?float $durationMs = null): void
    {
        $this->write('warning', 'warning', $context, $destination, $durationMs);
    }

    public function error(array $context = [], ?string $destination = null, ?float $durationMs = null): void
    {
        $this->write('error', 'failed', $context, $destination, $durationMs);
    }

    public function processing(array $context = [], ?string $destination = null): void
    {
        $this->write('info', 'processing', $context, $destination);
    }

    public function startTimer(): float
    {
        return microtime(true);
    }

    public function elapsed(float $start): float
    {
        return round((microtime(true) - $start) * 1000, 2);
    }

    public function withAction(string $action): self
    {
        $clone = clone $this;
        $clone->action = $action;
        return $clone;
    }

    public function getTraceId(): string
    {
        return $this->traceId;
    }

    private function write(string $level, string $status, array $context, ?string $destination, ?float $durationMs = null): void
    {
        $payload = [
            'timestamp'   => now()->toIso8601String(),
            'trace_id'    => $this->traceId,
            'instance_id' => $this->resolveInstanceId(),
            'module'      => $this->module,
            'action'      => $this->action,
            'user_id'     => $this->userId,
            'user_name'   => $this->userName,
            'client_id'   => $this->resolveClientId(),
            'source'      => $this->source,
            'destination' => $destination,
            'status'      => $status,
            'duration_ms' => $durationMs,
            'context'     => $context,
        ];

        // Dùng channel 'structured' - phải đăng ký channel này trong config/logging.php
        Log::channel('structured')->{$level}(json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
    }

    private function resolveInstanceId(): string
    {
        try { return app('instance_id'); } catch (\Throwable $e) { return config('services.app_meta.instance_id', gethostname()); }
    }

    private function resolveClientId(): string
    {
        try { return app('client_id'); } catch (\Throwable $e) { return 'queue-worker'; }
    }

    private function resolveTraceId(): string
    {
        try { return app('trace_id'); } catch (\Throwable $e) { return \Ramsey\Uuid\Uuid::uuid4()->toString(); }
    }

    private function inferSource(): string
    {
        $frames = debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS, 5);
        foreach ($frames as $frame) {
            $class = $frame['class'] ?? null;
            if ($class && !str_contains($class, 'StructuredLogger')) {
                return ($frame['class'] ?? '') . '::' . ($frame['function'] ?? '');
            }
        }
        return 'unknown';
    }
}
