<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\Kafka\KafkaHelper;
use App\Models\ServiceUser; // <--- Model local
use Illuminate\Support\Facades\Log;

class ConsumeIdentityEvents extends Command
{
    protected $signature = 'kafka:consume-identity';
    protected $description = 'Sync user data from Identity Service';

    public function handle(KafkaHelper $kafka)
    {
        $groupId = "identity-communication-sync-group";
        $consumer = $kafka->createConsumer($groupId, ['job7189.identity']);

        $this->info("Listening for Identity events (Group: $groupId)...");
        Log::info("Kafka Consumer started - Group: $groupId");

        while (true) {
            $message = $consumer->consume(5000);
            
            // Log polling noise ra channel riêng để không spam main log
            if ($message->err === RD_KAFKA_RESP_ERR__TIMED_OUT || $message->err === RD_KAFKA_RESP_ERR__PARTITION_EOF) {
                Log::channel('kafka')->debug("Kafka message received", [
                    'err' => $message->err,
                    'topic' => $message->topic_name ?? null,
                    'partition' => $message->partition ?? null,
                    'offset' => $message->offset ?? null
                ]);
            } else {
                Log::debug("Kafka message received", [
                    'err' => $message->err,
                    'topic' => $message->topic_name ?? null,
                    'partition' => $message->partition ?? null,
                    'offset' => $message->offset ?? null
                ]);
            }
            
            if ($message->err === RD_KAFKA_RESP_ERR_NO_ERROR) {
                try {
                    Log::info("Raw payload: " . $message->payload);
                    
                    $payload = json_decode($message->payload, true);
                    
                    Log::info("Decoded payload", $payload);
                    
                    $eventType = $payload['event_type'] ?? '';
                    
                    if ($eventType === 'user.updated') {
                        $this->syncUser($payload['data']);
                    } else {
                        Log::warning("Unknown event type: $eventType");
                    }
                    
                    $consumer->commit($message);
                    Log::info("Message committed successfully");
                    
                } catch (\Exception $e) {
                    Log::error("Identity Sync Error: " . $e->getMessage(), [
                        'trace' => $e->getTraceAsString()
                    ]);
                }
            } elseif ($message->err === RD_KAFKA_RESP_ERR__PARTITION_EOF) {
                Log::channel('kafka')->debug("Reached end of partition");
            } elseif ($message->err === RD_KAFKA_RESP_ERR__TIMED_OUT) {
                Log::channel('kafka')->debug("Consumer timeout (no new messages)");
            } else {
                Log::error("Kafka error: " . $message->errstr());
            }
        }
    }
    
    private function syncUser(array $data)
    {
        $user = ServiceUser::firstOrNew(['internal_id' => $data['id']]);

        $user->keycloak_id = $data['keycloak_id'] ?? $user->keycloak_id;
        $user->email       = $data['email']       ?? $user->email;
        $user->name        = $data['name']        ?? $user->name;     // <--- test chỗ này
        $user->type        = $data['type']        ?? $user->type;
        $user->updated_at  = now();

        $user->saveQuietly(); // hoặc $user->save(['timestamps' => false]) nếu cần

        Log::info("Manually synced name: " . ($user->name ?? 'null'));
        $this->info("Synced name → " . ($user->name ?? 'null'));
    }


    // private function syncUser(array $data)
    // {
    //     ServiceUser::updateOrCreate(
    //         ['internal_id' => $data['id']], // Tìm theo UUID
    //         [
    //             'keycloak_id' => $data['keycloak_id'],
    //             'email'       => $data['email'],
    //             'name'        => $data['name'],
    //             'type'        => $data['type'],
    //             'updated_at'  => now()
    //         ]
    //     );
        
    //     Log::debug("Synced User Data: ", $data);
    //     Log::info("Synced User: " . $data['name']);

    //     $this->info("Synced User: " . $data['name']);
    // }
}