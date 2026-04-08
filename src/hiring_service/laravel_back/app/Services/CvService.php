<?php
// file: app/Services/CvService.php

namespace App\Services;

use App\Models\Cv\Cv;
use App\Services\FileUploadService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;
use finfo; 
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Str;
use App\Models\Recruiter\Recruiter;

class CvService
{
    private FileUploadService $fileUploadService;

    public function __construct(FileUploadService $fileUploadService)
    {
        $this->fileUploadService = $fileUploadService;
    }

    private function incrementCvVersion(string $cvId): void
    {
        $newVersion = Cache::increment("cv_version:{$cvId}");
        Log::channel('daily_normal')->info('CV version incremented.', [
            'cv_id' => $cvId,
            'new_version' => $newVersion
        ]);
    }

    public function createCv(array $data): \App\Models\Cv
    {
        try {
            $newCv = \App\Models\Cv::create($data);

            Log::channel('daily_normal')->info('New CV created in MySQL', [
                'timestamp' => now()->toIso8601String(),
                'cv_id' => $newCv->CVID,
                'user_id' => $data['UserID'],
            ]);

            return $newCv;

        } catch (\Exception $e) {
            Log::channel('daily_error')->error('Error creating CV in MySQL', [
                'timestamp' => now()->toIso8601String(),
                'error' => $e->getMessage(),
                'class'  => __CLASS__,
                'method' => __METHOD__,
                'trace' => $e->getTraceAsString(),
            ]);
            throw new \Exception('Error creating CV in MySQL: ' . $e->getMessage());
        }
    }

    public function createCvFromPayload(string $userId, array $payload): Cv
    {
        try {
            // Xác định xem đây có phải là CV đầu tiên của người dùng không
            $isFirstCv = !Cv::where('UserID', $userId)->exists();
            
            // Xây dựng dữ liệu cuối cùng để lưu vào DB
            $cvData = array_merge(
                $payload, // Dữ liệu từ frontend (name, email, education, etc.)
                [
                    'UserID' => $userId,
                    'IsDefault' => $isFirstCv,
                ]
            );

            // Ghi đè Title nếu không được cung cấp
            if (empty($cvData['Title'])) {
                $cvData['Title'] = 'CV mới chưa có tên ' . now()->format('Y-m-d H:i');
            }

            $newCv = Cv::create($cvData);

            Log::channel('daily_normal')->info('New CV created from full payload.', [
                'user_id' => $userId,
                'new_cv_id' => $newCv->CVID,
            ]);

            return $newCv;

        } catch (\Exception $e) {
            Log::channel('daily_error')->error('Failed to create CV from payload in CvService.', [
                'user_id' => $userId,
                'error' => $e->getMessage(),
            ]);
            throw $e; // Ném lại exception để controller xử lý
        }
    }


    public function updateCV(string $cvId, array $updatePayload): ?Cv
    {
        $cv = Cv::find($cvId);
        if (!$cv) {
            Log::channel('daily_error')->warning('Attempted to update a non-existent CV.', ['cv_id' => $cvId]);
            return null;
        }
        $cv->update($updatePayload);

        $this->incrementCvVersion($cv->CVID);

        Log::channel('daily_normal')->info('CV updated successfully.', [
            'cv_id' => $cvId,
            'new_version' => Cache::get("cv_version:{$cv->CVID}") // Log thêm để kiểm tra
        ]);

        return $cv->fresh();
    }
    
    public function setCvAsDefault(string $userId, string $cvIdToSetDefault): void
    {
        DB::transaction(function () use ($userId, $cvIdToSetDefault) {
            Cv::where('UserID', $userId)
              ->where('CVID', '!=', $cvIdToSetDefault)
              ->update(['IsDefault' => 0]);

            Cv::where('CVID', $cvIdToSetDefault)
              ->update(['IsDefault' => 1]);
        });
    }

    public function prepareCvPayloadFromExtractedData(
        string $userId,
        string $filePathInBucket,
        UploadedFile $originalFile,
        array $extractedData
    ): array {
        $profileImageDataUrl = $this->processBase64Image($extractedData['profile_image_base64'] ?? null);

        $title = pathinfo($originalFile->getClientOriginalName(), PATHINFO_FILENAME);

        return [
            'UserID'          => $userId,
            'Title'           => $title,
            'CVPath'          => $filePathInBucket,
            'ProfileImage'    => $profileImageDataUrl,
            'Name'            => $extractedData['name'] ?? null,
            'Phone'           => $extractedData['phone'] ?? null,
            'Email'           => $extractedData['email'] ?? null,
            'Education'       => $extractedData['cv']['education'] ?? [],
            'Experience'      => $extractedData['cv']['experience'] ?? [],
            'TechnicalSkills' => $extractedData['cv']['technical_skills'] ?? [],
            'SoftSkills'      => $extractedData['cv']['soft_skills'] ?? [],
            'ExperienceYears' => $extractedData['cv']['exp_years'] ?? 0,
            'AboutMe'         => $extractedData['cv']['about_me'] ?? '',
            'AddressDistrict' => $extractedData['cv']['address_district'] ?? '',
            'AddressCity'     => $extractedData['cv']['address_city'] ?? '',
            'Position'        => $extractedData['cv']['position_applying'] ?? null,
            'Extracurricular' => $extractedData['cv']['extracurricular_activities'] ?? [],
            'Certifications'  => $extractedData['cv']['certifications_and_licenses'] ?? [],
            'Publications'    => $extractedData['cv']['publications'] ?? [],
            'Awards'          => $extractedData['cv']['awards'] ?? [],
        ];
    }
    
    private function processBase64Image(?string $rawBase64): ?string
    {
        if (!$rawBase64) return null;
        try {
            $binaryImageData = base64_decode($rawBase64, true);
            if ($binaryImageData === false) return null;
            $finfo = new finfo(FILEINFO_MIME_TYPE);
            $mimeType = $finfo->buffer($binaryImageData);
            if (strpos($mimeType, 'image/') === 0) {
                return 'data:' . $mimeType . ';base64,' . $rawBase64;
            }
            return null;
        } catch (\Exception $e) {
            Log::channel('daily_error')->error('Error processing base64 image.', ['error' => $e->getMessage()]);
            return null;
        }
    }
    
    public function deleteCv(Cv $cv, User $user): ?string
    {
        if ($cv->UserID !== $user->id) {
            throw new AuthorizationException('You are not authorized to delete this CV.');
        }

        try {
            // $filePath = $cv->CVPath; 
            // if ($filePath && Storage::disk('public')->exists($filePath)) {
            //     Storage::disk('public')->delete($filePath);
            //     Log::channel('daily_normal')->info("CV file deleted from storage.", ['path' => $filePath]);
            // }

            $cvId = $cv->CVID; // Lưu lại ID để log
            if ($cv->delete()) {
                Log::channel('daily_normal')->info("CV record deleted from database.", ['cv_id' => $cvId, 'user_id' => $user->id]);
                return $cvId;
            }

            return null;

        } catch (\Exception $e) {
            Log::channel('daily_error')->error('Failed to delete CV.', [
                'cv_id' => $cv->CVID,
                'user_id' => $user->id,
                'error' => $e->getMessage()
            ]);
            throw $e; 
        }
    }

    public function duplicateCv(string $originalCvId, string $userId): ?Cv
    {
        $originalCv = Cv::where('CVID', $originalCvId)
                        ->where('UserID', $userId)
                        ->first();

        if (!$originalCv) {
            Log::channel('daily_warning')->warning('Attempted to duplicate a non-existent or unauthorized CV.', [
                'original_cv_id' => $originalCvId,
                'user_id' => $userId,
            ]);
            return null;
        }

        $newCv = $originalCv->replicate();
        
        $newCv->CVID = (string) Str::uuid(); 
        
        $newCv->Title = $originalCv->Title . ' (Copy)';
        
        $newCv->IsDefault = 0;
        $newCv->CVPath = "N/A";

        $newCv->CreatedAt = now();
        $newCv->UpdatedAt = now();
        
        try {
            $newCv->save();

            Log::channel('daily_normal')->info('CV duplicated successfully.', [
                'original_cv_id' => $originalCvId,
                'new_cv_id' => $newCv->CVID,
                'user_id' => $userId,
            ]);

            return $newCv;

        } catch (\Exception $e) {
            Log::channel('daily_error')->error('Error saving duplicated CV.', [
                'original_cv_id' => $originalCvId,
                'user_id' => $userId,
                'error' => $e->getMessage(),
            ]);
            return null;
        }
    }

    public function updateCvTitle(string $cvId, string $newTitle, string $userId): ?Cv
    {
        $cv = Cv::where('CVID', $cvId)
                ->where('UserID', $userId)
                ->first();

        if (!$cv) {
            Log::channel('daily_warning')->warning('Attempted to update title of a non-existent or unauthorized CV.', [
                'cv_id' => $cvId,
                'user_id' => $userId,
            ]);
            return null;
        }

        try {
            $cv->Title = $newTitle;
            $cv->save();

            Log::channel('daily_normal')->info('CV title updated successfully.', [
                'cv_id' => $cvId,
                'user_id' => $userId,
            ]);
            
            return $cv;

        } catch (\Exception $e) {
            Log::channel('daily_error')->error('Error updating CV title.', [
                'cv_id' => $cvId,
                'user_id' => $userId,
                'error' => $e->getMessage(),
            ]);
            return null;
        }
    }

    public function updateTemplate(string $cvId, string $userId, array $templateData): ?Cv
    {
        // Tìm CV đồng thời xác thực quyền sở hữu của người dùng
        $cv = Cv::where('CVID', $cvId)
                ->where('UserID', $userId)
                ->first();

        if (!$cv) {
            Log::channel('daily_warning')->warning('SERVICE: Attempted to update template of a non-existent or unauthorized CV.', [
                'cv_id' => $cvId,
                'user_id' => $userId,
            ]);
            return null;
        }

        try {
            // Cập nhật trường Template và lưu
            $cv->Template = $templateData;
            $cv->save();

            Log::channel('daily_normal')->info('SERVICE: CV template updated successfully.', [
                'cv_id' => $cv->CVID,
                'user_id' => $userId
            ]);
            
            // Trả về đối tượng CV đã được làm mới
            return $cv->fresh();

        } catch (\Exception $e) {
            Log::channel('daily_error')->error('SERVICE: EXCEPTION caught while updating CV template.', [
                'cv_id' => $cvId,
                'user_id' => $userId,
                'error_message' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
            
            return null;
        }
    }

    public function getCvVersion(string $cvId): int
    {
        return (int) Cache::get("cv_version:{$cvId}", 1);
    }


}