<?php

namespace App\Services\Recruiter;

use App\Models\Recruiter\Recruiter;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use Illuminate\Support\Str;

class RecruiterService
{
    public function findOrCreateRecruiter(string $keycloakUserId, array $dataFromRequest = []): array
    {
        // Tìm kiếm trước
        $recruiter = Recruiter::where('KeycloakUserID', $keycloakUserId)->first();

        if ($recruiter) {
            Log::channel('daily_normal')->info('Recruiter profile already exists.', ['keycloak_user_id' => $keycloakUserId]);
            return [
                'recruiter' => $recruiter,
                'was_created' => false, // Báo rằng không phải tạo mới
            ];
        }
        
        // Nếu không tìm thấy, tạo mới
        Log::channel('daily_normal')->info('Creating new recruiter profile.', ['keycloak_user_id' => $keycloakUserId]);
        
        $newRecruiter = Recruiter::create([
            'RecruiterID' => Str::uuid()->toString(),
            'KeycloakUserID' => $keycloakUserId,
            'CompanyID' => $dataFromRequest['company_id'] ?? null,
            'StatusID' => 1, // 1 = Trạng thái 'NEW'
        ]);

        return [
            'recruiter' => $newRecruiter,
            'was_created' => true, // Báo rằng vừa tạo mới
        ];
    }

    public function createNewRecruiter(string $keycloakUserId, array $data): Recruiter
    {
        Log::channel('daily_normal')->info('Creating new recruiter profile.', ['keycloak_user_id' => $keycloakUserId]);
        return Recruiter::create([
            'RecruiterID' => \Illuminate\Support\Str::uuid(),
            'KeycloakUserID' => $keycloakUserId,
            'CompanyID' => $data['company_id'],
            'StatusID' => 1, // 1 = NEW
        ]);
    }

    public function requestApproval(Recruiter $recruiter): ?Recruiter
    {
        if (!$recruiter) {
            Log::channel('daily_error')->error('requestApproval service called with a null recruiter object.');
            return null;
        }

        if ($recruiter->StatusID !== 1) {
            (new StructuredLogger('system', 'warning'))->warning(['message' => 'Recruiter tried to request approval from invalid state.', [
                'recruiter_id' => $recruiter->RecruiterID,
                'current_status' => $recruiter->StatusID
            ]);
            return null;
        }
        $recruiter->StatusID = 2; // 2 = PENDING
        $recruiter->save();
        Log::channel('daily_normal')->info('Recruiter approval request submitted.', ['recruiter_id' => $recruiter->RecruiterID]);
        return $recruiter;
    }

    public function updateInterestedSectors(Recruiter $recruiter, array $jobSectorIds): Recruiter
    {
        $recruiter->interestedSectors()->sync($jobSectorIds);

        Log::channel('daily_normal')->info('Recruiter updated interested sectors.', [
            'recruiter_id' => $recruiter->RecruiterID,
            'job_sectors' => $jobSectorIds
        ]);

        return $recruiter;
    }

    public function updateProfile(Recruiter $recruiter, array $validatedData): Recruiter
    {
        try {
            if (!$recruiter->exists) {
                Log::channel('daily_error')->error('Recruiter does not exist in database.', [
                    'recruiter_id' => $recruiter->RecruiterID
                ]);
                throw new \Exception('Recruiter does not exist.');
            }

            Log::channel('daily_normal')->info('Validated data received from controller', [
                'recruiter_id' => $recruiter->RecruiterID,
                'data' => $validatedData
            ]);

            $updateData = [];

            foreach ($validatedData as $key => $value) {
                $updateData[Str::studly($key)] = $value;
            }

            Log::channel('daily_normal')->info('Mapped data for database update', [
                'recruiter_id' => $recruiter->RecruiterID,
                'data' => $updateData
            ]);
            
            $updated = $recruiter->update($updateData);
            Log::channel('daily_normal')->info('Attempted to update recruiter profile in database.', [
                'recruiter_id' => $recruiter->RecruiterID,
                'data' => $updateData,
                'update_result' => $updated
            ]);

            if (!$updated) {
                Log::channel('daily_error')->error('Failed to update recruiter profile.', [
                    'recruiter_id' => $recruiter->RecruiterID,
                    'data' => $updateData
                ]);
                throw new \Exception('Failed to update recruiter profile.');
            }

            Log::channel('daily_normal')->info('Recruiter profile updated successfully.', [
                'recruiter_id' => $recruiter->RecruiterID,
                'updated_fields' => array_keys($updateData)
            ]);
            
            return $recruiter->fresh();
        } catch (\Illuminate\Database\QueryException $e) {
            Log::channel('daily_error')->error('Database error updating recruiter profile.', [
                'recruiter_id' => $recruiter->RecruiterID,
                'error' => $e->getMessage()
            ]);
            throw new \Exception('Failed to update profile due to database error.');
        } catch (\Exception $e) {
            Log::channel('daily_error')->error('Unexpected error updating recruiter profile.', [
                'recruiter_id' => $recruiter->RecruiterID,
                'error' => $e->getMessage()
            ]);
            throw new \Exception('An unexpected error occurred while updating the profile.');
        }
    }
    // Các hàm dành cho Admin (approve, reject) sẽ được thêm vào ở chỗ khác hay đây luôn?
}