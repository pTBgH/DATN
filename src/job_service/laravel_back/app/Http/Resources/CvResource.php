<?php
namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
/**
 * Định dạng dữ liệu CV đã được ẨN DANH để hiển thị cho nhà tuyển dụng.
 * Resource này AN TOÀN để sử dụng ở mọi nơi.
 */
class CvResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->CVID,
            'title' => $this->Title,
            'experience_years' => (int) $this->ExperienceYears,
            'position_applying' => $this->Position,
            'city' => $this->AddressCity,
            'updated_at' => optional($this->UpdatedAt)->toIso8601String(),
            // 'recruiter_interaction' => $this->recruiter_interaction ?? ['is_saved' => false, 'is_contacted' => false],
            'is_default' => (bool) $this->getAttr('IsDefault', 'is_default'),


            $this->mergeWhen($this->isDetailedView($request), [
                'about_me' => $this->AboutMe,
                'technical_skills' => $this->TechnicalSkills,
                'soft_skills' => $this->SoftSkills,
                'education' => $this->Education,
                'experience' => $this->Experience, // Giả định đã được làm sạch
                'certifications' => $this->Certifications,
                'awards' => $this->Awards,
                'is_default' => (bool) $this->getAttr('IsDefault', 'is_default'),
            ]),

            // 'recruiter_interaction' => [
            //     'is_saved' => $this->recruiter_interaction['is_saved'] ?? false,
            //     'is_contacted' => $this->recruiter_interaction['is_contacted'] ?? false,
            // ]
        ];
    }

    private function isDetailedView(Request $request): bool
    {
        // Ví dụ: kiểm tra xem route có phải là route xem chi tiết CV ẩn danh không
        return $request->routeIs('employer.cvs.show_anonymous'); 
    }
}