<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Facades\DB;

class HotReloadServiceProvider extends ServiceProvider
{
    public function register()
    {
        // No bindings required
    }

    public function boot()
    {
        $this->registerSignalHandler();
    }

    protected function registerSignalHandler()
    {
        if (!extension_loaded('pcntl')) {
            return;
        }

        // Enable async signals
        pcntl_async_signals(true);

        // Reload DB connection on SIGUSR1
        pcntl_signal(SIGUSR1, function () {
            try {
                self::reloadDatabaseConnection();
                logger()->info('HotReload: SIGUSR1 handled, DB reloaded');
            } catch (\Throwable $e) {
                logger()->error('HotReload: reload failed: ' . $e->getMessage());
            }
        });
    }

    /**
     * Re-read /app-secrets/.env and refresh DB connection at runtime.
     */
    public static function reloadDatabaseConnection()
    {
        $envFile = env('DOTENV_PATH', '/app-secrets/.env');

        if (!file_exists($envFile)) {
            logger()->warning('HotReload: env file not found: ' . $envFile);
            return;
        }

        $content = file_get_contents($envFile);
        $lines = preg_split('/\r\n|\r|\n/', $content);
        $creds = [];
        foreach ($lines as $line) {
            if (preg_match('/^([A-Z0-9_]+)=(.*)$/', $line, $m)) {
                $key = $m[1];
                $val = trim($m[2], "\"'");
                $creds[$key] = $val;
            }
        }

        // Update runtime config if present
        if (isset($creds['DB_USERNAME'])) {
            config(['database.connections.mysql.username' => $creds['DB_USERNAME']]);
        }
        if (isset($creds['DB_PASSWORD'])) {
            config(['database.connections.mysql.password' => $creds['DB_PASSWORD']]);
        }

        // Purge and reconnect
        DB::purge('mysql');
        DB::reconnect('mysql');
    }
}
