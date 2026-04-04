<?php
// filepath: ./laravel_back/config/cors.php
// file: config/cors.php

return [
    'paths' => ['api/*', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['*'], // Cho phép tất cả các method

    'allowed_origins' => ['*'], // Cho phép tất cả các origin

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'], // Cho phép tất cả các header

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => true, // Giữ nguyên là true
];