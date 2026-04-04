<?php

namespace App\Http\Controllers\Traits;

use App\Enums\SystemRole;

trait HasPermissionValidation
{
    protected function getPermissionRules(string $prefix = ''): array
    {
        $validRoles = implode(',', array_column(SystemRole::cases(), 'value'));

        return [
            $prefix . 'role' => 'nullable|string|in:' . $validRoles,

            $prefix . 'permissions' => [
                'nullable',
                'array',
                "required_without:{$prefix}role",
            ],

            $prefix . 'permissions.workspace' => 'nullable|integer|min:0',
            $prefix . 'permissions.job'       => 'nullable|integer|min:0',
            $prefix . 'permissions.candidate' => 'nullable|integer|min:0',
            $prefix . 'permissions.pipeline'  => 'nullable|integer|min:0',
        ];
    }
}