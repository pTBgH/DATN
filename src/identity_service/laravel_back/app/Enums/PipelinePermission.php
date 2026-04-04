<?php

namespace App\Enums;

enum PipelinePermission: int
{
    use BitmaskHelper;

    case READ_PIPELINE           = 1;    // Bit 1
    case CREATE_PIPELINE         = 2;    // Bit 2
    case UPDATE_PIPELINE         = 4;    // Bit 3
    case ADD_STAGE               = 8;    // Bit 4
    case DELETE_STAGE            = 16;   // Bit 5
    case CONFIG_STAGE_EVENTS     = 32;   // Bit 6: Cấu hình automation
    case VIEW_EVENT_LOGS         = 64;   // Bit 7

    public static function standardCases(): array
    {
        return [
            self::READ_PIPELINE,
            self::CREATE_PIPELINE,
            self::UPDATE_PIPELINE,
            self::ADD_STAGE,
            self::DELETE_STAGE,
            self::CONFIG_STAGE_EVENTS,
            self::VIEW_EVENT_LOGS,
        ];
    }

    public static function getStandardMask(): int
    {
        return self::getMask(self::standardCases());
    }
}