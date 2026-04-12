<?php
namespace App\Logging;

use Monolog\Formatter\JsonFormatter;
use Monolog\LogRecord;

class StructuredJsonFormatter extends JsonFormatter
{
    public function format(LogRecord $record): string
    {
        $normalizedContext = $this->truncateStrings(
            $this->normalize($record->context)
        );

        $normalizedExtra = $this->normalize($record->extra);

        $base = [
            'timestamp' => $record->datetime->format('Y-m-d\TH:i:sP'),
            'level' => $record->level->value,
            'level_name' => $record->level->getName(),
            'message' => $record->message,
            'context' => $normalizedContext,
            'extra' => $normalizedExtra,
        ];

        if (isset($normalizedContext['log_type'])) {
            $base['log_type'] = $normalizedContext['log_type'];
            unset($base['context']['log_type']);
        }

        if (isset($normalizedContext['controller'])) {
            $base['controller'] = $normalizedContext['controller'];
            unset($base['context']['controller']);
        }

        try {
            return $this->toJson($base, true) . ($this->appendNewline ? "\n" : '');
        } catch (\Throwable $e) {
            return json_encode([
                'level' => 'critical',
                'message' => 'JSON Formatting Failed: ' . $e->getMessage()
            ]) . "\n";
        }
    }

    private function truncateStrings(array $data, int $limit = 1000): array
    {
        array_walk_recursive($data, function (&$value) use ($limit) {
            if (is_string($value) && strlen($value) > $limit) {
                $value = substr($value, 0, $limit) . '...';
            }
        });

        return $data;
    }
}
