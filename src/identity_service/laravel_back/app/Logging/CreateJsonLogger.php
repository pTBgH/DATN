<?php

namespace App\Logging;

use Monolog\Logger;
use Monolog\Level;
use Monolog\Handler\RotatingFileHandler;
use App\Logging\StructuredJsonFormatter;

class CreateJsonLogger
{
    public function __invoke(array $config)
    {
        $path = $config['path'] ?? storage_path('logs/laravel.log');
        $level = $config['level'] ?? Level::Debug;
        $days = $config['days'] ?? 14;

        $logger = new Logger('json');

        $handler = new RotatingFileHandler(
            $path,
            $days,
            $level
        );

        $handler->setFormatter(new StructuredJsonFormatter());

        $logger->pushHandler($handler);

        return $logger;
    }
}
