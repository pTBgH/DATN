<?php
namespace App\Enums;

trait BitmaskHelper
{
    // Hàm cũ bạn đã có
    public static function can(int $userPermissions, self ...$requiredPermissions): bool
    {
        $requiredCode = 0;
        foreach ($requiredPermissions as $permission) {
            $requiredCode |= $permission->value;
        }
        return ($userPermissions & $requiredCode) === $requiredCode;
    }

    /**
     * Tính tổng giá trị bitmask cho một danh sách các case
     */
    public static function getMask(array $cases): int
    {
        $mask = 0;
        foreach ($cases as $case) {
            $mask |= $case->value;
        }
        return $mask;
    }
}