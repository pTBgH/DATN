<?php

namespace App\Models\Hiring;

use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasUuids;

class Scorecard extends Model
{
    use HasUuids;

    protected $table = 'hiring_scorecards';
    protected $primaryKey = 'ScorecardID';
    public $incrementing = false;
    protected $keyType = 'string';

    const CREATED_AT = 'CreatedAt';
    const UPDATED_AT = 'UpdatedAt';

    protected $fillable = [
        'ScorecardID',
        'ApplicationID',
        'InterviewerID',
        'InterviewerName',
        'ScoreJson',
        'Comment',
        'CreatedAt'
    ];

    protected $casts = [
        'ScoreJson' => 'array', // Tự động cast JSON sang Array khi lấy ra
        'CreatedAt' => 'datetime',
    ];
}