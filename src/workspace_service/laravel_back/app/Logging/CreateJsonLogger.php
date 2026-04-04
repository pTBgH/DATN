<?php

namespace App\Logging;

use Monolog\Logger;
use Monolog\Handler\StreamHandler;
use Monolog\Handler\RotatingFileHandler;
use App\Logging\StructuredJsonFormatter;

class CreateJsonLogger
{
    public function __invoke(array $config)
    {        
        $path = $config['path'] ?? storage_path('logs/laravel.log');
        $level = $config['level'] ?? Level::Debug;
        $days = $config['days'] ?? 14; // Lấy 'days' từ config nếu có

        $logger = new Logger('json');

        // Sử dụng RotatingFileHandler
        $handler = new RotatingFileHandler(
            $path,
            $days, // Số ngày log sẽ được giữ
            $level
        );
        
        $handler->setFormatter(new StructuredJsonFormatter());
        
        $logger->pushHandler($handler);
        
        return $logger;
    }
}