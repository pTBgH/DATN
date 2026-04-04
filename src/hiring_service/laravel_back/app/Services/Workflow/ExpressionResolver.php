<?php

namespace App\Services\Workflow;

use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;



class ExpressionResolver
{
    /**
     * Duyệt qua mảng parameters và thay thế các biến {{ variable }}
     */
    public function resolve(array $parameters, array $context): array
    {
        $resolved = [];

        foreach ($parameters as $key => $value) {
            if (is_array($value)) {
                // Đệ quy nếu tham số là mảng lồng nhau (ví dụ mảng variables trong email)
                $resolved[$key] = $this->resolve($value, $context);
                continue;
            }

            if (is_string($value)) {
                // Chỉ log nếu thấy có dấu hiệu biến động
                if (str_contains($value, '{{')) {
                    // (new StructuredLogger('system', 'action'))->info(['message' => "[ExpressionResolver] Resolving string: {$value}");
                }
                $resolved[$key] = $this->interpolate($value, $context);
            } else {
                $resolved[$key] = $value;
            }
        }

        return $resolved;
    }

    /**
     * Thực hiện thay thế chuỗi bằng regex
     */
    private function interpolate(string $text, array $context): string
    {
        // Regex tìm chuỗi nằm giữa {{ và }} (có thể có khoảng trắng)
        return preg_replace_callback('/\{\{\s*([\w\.]+)\s*\}\}/', function ($matches) use ($context) {
            $path = $matches[1]; // Ví dụ: "candidate_email" hoặc "job.title"
            
            // data_get là hàm helper của Laravel, hỗ trợ dot notation
            $value = data_get($context, $path);

            if (is_null($value)) {
                (new StructuredLogger('system', 'warning'))->warning(['message' => "[ExpressionResolver] Variable not found in context: {{$path}}");
                return ''; // Trả về rỗng nếu không tìm thấy
            }

            return (string) $value;
        }, $text);
    }
}