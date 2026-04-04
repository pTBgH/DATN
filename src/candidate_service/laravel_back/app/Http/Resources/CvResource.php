<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CvResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'cv_id'          => $this->CVID,
            'user_id'     => $this->UserID,
            'title'       => $this->Title,
            'cv_path'     => $this->CVPath,
            'is_default'  => (bool) $this->IsDefault,
            
            // Nếu có link xem (được enrich từ controller) thì hiện, không thì null
            'view_url'    => $this->view_url ?? null, 

            'created_at'  => $this->CreatedAt,
            'updated_at'  => $this->UpdatedAt,
        ];
    }
}