<?php

namespace App\Models;

use App\Models\Traits\HasUuids; // Import trait để tự động tạo UUID
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes; // Import SoftDeletes trait

class Cv extends Model
{
    use HasFactory, HasUuids, SoftDeletes;


    protected $table = 'usr_cvs';

    protected $primaryKey = 'CVID';


    protected $keyType = 'string';

    public $incrementing = false;

    const CREATED_AT = 'CreatedAt';
    const UPDATED_AT = 'UpdatedAt';
    const DELETED_AT = 'DeletedAt';

    public function status()
    {
        return $this->belongsTo(CvStatus::class, 'StatusID', 'StatusID');
    }

    public function sector()
    {
        return $this->belongsTo(JobSector::class, 'SectorID', 'JobSectorID');
    }

    protected $fillable = [
        'UserID',
        'Title',
        'Name',
        'StatusID',
        'SectorID',
        'Email',
        'Phone',
        'CVPath',
        'ExperienceYears',
        'AboutMe',
        'AddressDistrict',
        'AddressCity',
        'Education',
        'Experience',
        'TechnicalSkills',
        'SoftSkills',
        'Certifications',
        'Extracurricular',
        'Awards',
        'Publications',
        'Position',
        'IsPublic',
        'IsDefault',
        'ProfileImage',
        'Template',
    ];

    protected $casts = [
        'Education' => 'array',
        'Experience' => 'array',
        'SoftSkills' => 'array',
        'TechnicalSkills' => 'array',
        'Certifications' => 'array',
        'Extracurricular' => 'array',
        'Publications' => 'array',
        'Awards' => 'array',
        'Template' => 'array',

        'AboutMe' => 'string',
        'Position' => 'string',

        'IsPublic' => 'boolean',
        'IsDefault' => 'boolean',
        'ExperienceYears' => 'integer',
    ];
}