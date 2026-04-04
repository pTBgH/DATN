<?php

namespace App\Providers;

use App\Events\JobStateChanged;
use App\Listeners\JobPublishingListener;
use Illuminate\Foundation\Support\Providers\EventServiceProvider as ServiceProvider;
use Illuminate\Support\Facades\Event;

class EventServiceProvider extends ServiceProvider
{
    protected $listen = [
        JobStateChanged::class => [
            JobPublishingListener::class,
        ],
    ];

    public function boot(): void
    {
        // 
    }

    public function shouldDiscoverEvents(): bool
    {
        return false;
    }
}