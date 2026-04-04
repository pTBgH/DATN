<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class JobCompanyResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'company_id'   => $this->CompanyID,
            'name'         => $this->CompanyName,
            'logo'         => $this->PicturePath,
            'website'      => $this->Website,
            'description'  => $this->Description,
            
            // Map Location
            'location'     => $this->location?->DetailLocation,
            'city_id'      => $this->location?->CityID,     // Frontend cần cái này để bind vào dropdown
            'district_id'  => $this->location?->DistrictID, // Frontend cần cái này
            
            // Map Size & Industry
            'size_id'      => $this->SizeID,
            'size_name'    => $this->size?->SizeName,
            
            'industry_id'  => $this->IndustryID,
            'industry_name'=> $this->industry?->IndustryName,
            
            'is_active'    => (bool) $this->IsActive,
            'updated_at'   => $this->UpdatedAt,
        ];
    }
}