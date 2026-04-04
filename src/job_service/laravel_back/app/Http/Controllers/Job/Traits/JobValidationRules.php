<?php

namespace App\Http\Controllers\Job\Traits;

trait JobValidationRules
{
    public function validationRules(): array
    {
        return [
            'company_id'       => 'nullable|string', 
            'pipeline_id'      => 'nullable|string|max:36', 
            'title' => 'sometimes|required|string|max:1000',
            'description' => 'nullable|string', // đổi tên từ job_des
            'requirements' => 'nullable|string', // đổi tên từ job_req
            'benefits' => 'nullable|string', // đổi tên từ job_ben
            'keywords' => 'nullable|string',
            'deadline' => 'nullable|date|after_or_equal:today', // đổi tên từ due_date
            'up_date' => 'nullable|date|after_or_equal:today',

            // --- CẬP NHẬT CÁC QUY TẮC LƯƠNG VÀ CÁC TRƯỜNG KHÁC ---
            'salary_max' => 'nullable|integer|min:0',
            'salary_min' => 'nullable|integer|min:0',
            'currency' => 'nullable|integer|exists:sys_currencies,CurrencyID', // Giả sử là ID
            'min_age' => 'nullable|integer',
            'max_age' => 'nullable|integer', // max_age phải lớn hơn min_age
            'job_link' => 'nullable|string|url:http,https|max:2048',
            'exp_years' => 'nullable|integer|min:0|max:50',

            // Các trường ID
            'job_type'         => 'nullable|integer', 
            'job_sector'       => 'nullable|integer',
            'working_type'     => 'nullable|integer',
            'contract_type'    => 'nullable|integer',
            'degree_level'     => 'nullable|integer',
            'sex'              => 'nullable|integer',

            'location_id'      => 'nullable|integer', // Location check lỏng
            'detail_address'   => 'nullable|string|max:2048',
            'deadline'         => 'nullable|date|after_or_equal:today',
            'up_date'          => 'nullable|date',
        ];
    }
}