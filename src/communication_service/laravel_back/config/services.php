<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'token' => env('POSTMARK_TOKEN'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'resend' => [
        'key' => env('RESEND_KEY'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    // 'elasticsearch' => [
    //     'scheme' => env('ELASTICSEARCH_SCHEME', 'http'),
    //     'host' => env('ELASTICSEARCH_HOST', 'elasticsearch'),
    //     'port' => env('ELASTICSEARCH_PORT', '9200'),
    //     'username' => env('ELASTICSEARCH_USERNAME', 'elastic'),
    //     'password' => env('ELASTICSEARCH_PASSWORD', 'pass'),

    // ],  

    'keycloak' => [
        'base_url' => env('KEYCLOAK_BASE_URL'),
        'realm'    => env('KEYCLOAK_REALM'),
        'clients' => [
            'recruiter' => env('KEYCLOAK_RECRUITER_CLIENT_ID', 'recruiter-client'),
            'candidate' => env('KEYCLOAK_CANDIDATE_CLIENT_ID', 'candidate-client'), // Mặc định là candidate-client
        ],
    ],

    'nextjs' => [
        'internal_api_secret' => env('NEXTJS_INTERNAL_API_SECRET'),
    ],

    'pagination' => [
        'size' => env('PAGINATION_SIZE', 20),
    ],

    'admin_workspace' => [
        'id' => env('SUPER_ADMIN_WORKSPACE_ID'),
    ],

    'kafka' => [
        'brokers' => env('KAFKA_BROKERS', 'kafka-0.kafka-svc.job7189-ns.svc.cluster.local:9092'),
    ],
];
