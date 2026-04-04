<?php
namespace App\Logging;

use Monolog\Formatter\JsonFormatter;
use Monolog\LogRecord;

class StructuredJsonFormatter extends JsonFormatter
{
    public function format(LogRecord $record): string
    {
        // 1. Sử dụng normalize() có sẵn của Monolog để làm sạch dữ liệu
        // Nó tự động xử lý resource, object, và circular reference
        $normalizedContext = $this->truncateStrings(
            $this->normalize($record->context)
        );

        $normalizedExtra = $this->normalize($record->extra);

        $base = [
            'timestamp' => $record->datetime->format('Y-m-d\TH:i:sP'),
            'level' => $record->level->value,
            'level_name' => $record->level->getName(),
            'message' => $record->message,
            'context' => $normalizedContext, // Đã an toàn
            'extra' => $normalizedExtra,     // Đã an toàn
        ];

        // Xử lý các trường custom nếu có trong context (sau khi đã normalize)
        if (isset($normalizedContext['log_type'])) {
            $base['log_type'] = $normalizedContext['log_type'];
            unset($base['context']['log_type']); // Xóa khỏi context để đỡ trùng lặp
        }

        if (isset($normalizedContext['controller'])) {
            $base['controller'] = $normalizedContext['controller'];
            unset($base['context']['controller']);
        }

        // 2. Wrap trong try-catch để đảm bảo log không bao giờ làm sập app
        try {
            return $this->toJson($base, true) . ($this->appendNewline ? "\n" : '');
        } catch (\Throwable $e) {
            // Fallback cực đoan: nếu vẫn lỗi thì trả về chuỗi đơn giản
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