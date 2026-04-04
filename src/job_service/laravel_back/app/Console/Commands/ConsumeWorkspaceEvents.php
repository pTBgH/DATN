<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\Kafka\KafkaHelper;
use App\Models\Job\JobCompany;
use App\Models\Sys\SysLocation;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;



class ConsumeWorkspaceEvents extends Command
{
    protected $signature = 'kafka:consume-workspace';
    protected $description = 'Sync workspace data from Workspace Service';

    public function handle(KafkaHelper $kafka)
    {
        $groupId = "workspace-job-sync-group";
        $topics = ['job7189.workspace'];
        $consumer = $kafka->createConsumer($groupId, $topics);

        $this->info("Listening for Workspace events...");
        (new StructuredLogger('system', 'action'))->info(['message' => "Kafka Consumer [Workspace] started.");

        while (true) {
            $message = $consumer->consume(5000);

            if ($message->err === RD_KAFKA_RESP_ERR_NO_ERROR) {
                try {
                    $payload = json_decode($message->payload, true);
                    $eventType = $payload['event_type'] ?? '';
                    $data = $payload['data'] ?? [];

                    (new StructuredLogger('system', 'action'))->info(['message' => "Received event: $eventType", ['id' => $data['workspace_id'] ?? 'N/A']);

                    if ($eventType === 'workspace.created') {
                        $this->handleWorkspaceCreated($data);
                    } elseif ($eventType === 'workspace.updated') {
                        $this->handleWorkspaceUpdated($data);
                    }

                    $consumer->commit($message);
                } catch (\Exception $e) {
                    // Log lỗi để không chết consumer loop
                    (new StructuredLogger('system', 'error'))->error(['message' => "Workspace Sync Error: " . $e->getMessage());
                }
            }
        }
    }

    private function handleWorkspaceCreated(array $data)
    {
        $workspaceId = $data['workspace_id'];
        
        // Kiểm tra tồn tại
        if (JobCompany::where('CompanyID', $workspaceId)->exists()) {
            $this->info("Company already exists: $workspaceId");
            return;
        }

        // Khai báo biến bên ngoài transaction để dùng cho log
        $company = null;

        DB::transaction(function () use ($data, $workspaceId, &$company) {
            if (
                isset($data['location']) ||
                isset($data['city']) ||
                isset($data['district'])
            ) {
                $location = SysLocation::create([
                    'CityID'         => $data['city'] ?? null,
                    'DistrictID'     => $data['district'] ?? null,
                    'DetailLocation' => $data['location'] ?? null,
                ]);

                $locationId = $location->LocationID;
            }

            // GÁN VÀO BIẾN $company ĐỂ KHÔNG BỊ LỖI UNDEFINED
            $company = JobCompany::create([
                'CompanyID'   => $workspaceId,
                'CompanyName' => $data['name'],
                'PicturePath' => $data['logo'] ?? null,
                'LocationID'  => $locationId,
                'SizeID'      => $data['size'] ?? null,      // Lấy key 'size'
                'IndustryID'  => $data['industry'] ?? null,  // Lấy key 'industry'
                'Website'     => $data['website'] ?? null,
                'IsActive'    => true,
            ]);
        });

        // Kiểm tra nếu tạo thành công mới log
        if ($company) {
            (new StructuredLogger('system', 'action'))->info(['message' => "Created Company Success", $company->toArray());
            $this->info("Created Company: $workspaceId");
        }
    }

    private function handleWorkspaceUpdated(array $data)
    {
        $workspaceId = $data['workspace_id'];
        $company = JobCompany::find($workspaceId);
        
        if (!$company) {
            return $this->handleWorkspaceCreated($data); 
        }

        DB::transaction(function () use ($company, $data) {
            // Update Location
            if (isset($data['location'])) {
                if ($company->LocationID) {
                    SysLocation::where('LocationID', $company->LocationID)
                        ->update(['DetailLocation' => $data['location']]);
                } else {
                    $loc = SysLocation::create(['DetailLocation' => $data['location']]);
                    $company->LocationID = $loc->LocationID;
                }
            }
            
            // Update Info
            $updateData = [];
            if (isset($data['name'])) $updateData['CompanyName'] = $data['name'];
            if (isset($data['logo'])) $updateData['PicturePath'] = $data['logo'];
            
            // Map đúng key 'size' và 'industry'
            if (isset($data['size'])) $updateData['SizeID'] = $data['size'];
            if (isset($data['industry'])) $updateData['IndustryID'] = $data['industry'];
            
            if (isset($data['website'])) $updateData['Website'] = $data['website'];

            if (!empty($updateData) || isset($data['location'])) {
                $company->update($updateData);
            }
        });
        $this->info("Updated Company: $workspaceId");
    }
}