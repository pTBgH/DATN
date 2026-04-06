<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\Kafka\KafkaHelper;
use App\Models\ServiceUser; // <--- Model local
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;



class ConsumeIdentityEvents extends Command
{
    protected $signature = 'kafka:consume-identity';
    protected $description = 'Sync user data from Identity Service';

    public function handle(KafkaHelper $kafka)
    {
        $groupId = "identity-hiring-sync-group";
        $consumer = $kafka->createConsumer($groupId, ['job7189.identity']);

        $this->info("Listening for Identity events (Group: $groupId)...");
        (new StructuredLogger('system', 'action'))->info(['message' => "Kafka Consumer started - Group: $groupId");

        while (true) {
            $message = $consumer->consume(5000);
            
            // Log mọi message nhận được (kể cả lỗi)
            Log::debug("Kafka message received", [
                'err' => $message->err,
                'topic' => $message->topic_name ?? null,
                'partition' => $message->partition ?? null,
                'offset' => $message->offset ?? null
            ]);
            
            if ($message->err === RD_KAFKA_RESP_ERR_NO_ERROR) {
                try {
                    (new StructuredLogger('system', 'action'))->info(['message' => "Raw payload: " . $message->payload);
                    
                    $payload = json_decode($message->payload, true);
                    
                    (new StructuredLogger('system', 'action'))->info(['message' => "Decoded payload", $payload);
                    
                    $eventType = $payload['event_type'] ?? '';
                    
                    if ($eventType === 'user.updated') {
                        $this->syncUser($payload['data']);
                    } else {
                        (new StructuredLogger('system', 'warning'))->warning(['message' => "Unknown event type: $eventType");
                    }
                    
                    $consumer->commit($message);
                    (new StructuredLogger('system', 'action'))->info(['message' => "Message committed successfully");
                    
                } catch (\Exception $e) {
                    (new StructuredLogger('system', 'error'))->error(['message' => "Identity Sync Error: " . $e->getMessage(), [
                        'trace' => $e->getTraceAsString()
                    ]);
                }
            } elseif ($message->err === RD_KAFKA_RESP_ERR__PARTITION_EOF) {
                Log::debug("Reached end of partition");
            } elseif ($message->err === RD_KAFKA_RESP_ERR__TIMED_OUT) {
                Log::debug("Consumer timeout (no new messages)");
            } else {
                (new StructuredLogger('system', 'error'))->error(['message' => "Kafka error: " . $message->errstr()]);
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

        (new StructuredLogger('system', 'action'))->info(['message' => "Manually synced name: " . ($user->name ?? 'null'));
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
    //     (new StructuredLogger('system', 'action'))->info(['message' => "Synced User: " . $data['name']);

    //     $this->info("Synced User: " . $data['name']);
    // }
}