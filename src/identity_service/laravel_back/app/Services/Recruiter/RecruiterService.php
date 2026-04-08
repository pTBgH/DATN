<?php

namespace App\Services\Recruiter;

use App\Models\Recruiter\Recruiter;
use Illuminate\Support\Facades\Log;
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
            Log::warning('Recruiter tried to request approval from invalid state.', [
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

        Log::info('Recruiter updated interested sectors.', [
            'recruiter_id' => $recruiter->RecruiterID,
            'job_sectors' => $jobSectorIds
        ]);

        return $recruiter;
    }

    public function updateProfile(Recruiter $recruiter, array $validatedData): Recruiter
    {
        try {
            if (!$recruiter->exists) {
                throw new \Exception('Recruiter does not exist.');
            }

            // --- CÁCH MỚI (AN TOÀN): Mapping thủ công ---
            $updateData = [];

            // Mapping từ request (snake_case) sang DB (PascalCase)
            if (array_key_exists('user_name', $validatedData)) 
                $updateData['UserName'] = $validatedData['user_name'];
                
            if (array_key_exists('phone_number', $validatedData)) 
                $updateData['PhoneNumber'] = $validatedData['phone_number'];
                
            if (array_key_exists('first_name', $validatedData)) 
                $updateData['FirstName'] = $validatedData['first_name'];
                
            if (array_key_exists('last_name', $validatedData)) 
                $updateData['LastName'] = $validatedData['last_name'];

            // Log để debug xem data chuẩn bị update là gì
            Log::info('Updating Recruiter DB Data:', $updateData);
            unset($recruiter->type);

            $recruiter->update($updateData);

            return $recruiter->fresh();

        } catch (\Illuminate\Database\QueryException $e) {
            // Log lỗi SQL chi tiết ra stderr để bạn đọc được ngay
            Log::channel('stderr')->error('SQL Error in RecruiterService:', [
                'sql' => $e->getSql(),
                'bindings' => $e->getBindings(),
                'error' => $e->getMessage()
            ]);
            throw new \Exception('Database error: ' . $e->getMessage());
        } catch (\Exception $e) {
            Log::channel('stderr')->error('Update Profile Error: ' . $e->getMessage());
            throw $e;
        }
    }
    // Các hàm dành cho Admin (approve, reject) sẽ được thêm vào ở chỗ khác hay đây luôn?
}