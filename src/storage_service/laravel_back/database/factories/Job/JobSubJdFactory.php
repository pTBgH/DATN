<?php

namespace Database\Factories\Job;

use App\Enums\JobStatusEnum;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;

class JobSubJdFactory extends Factory
{
    protected $model = \App\Models\Job\JobSubJd::class;

    public function definition(): array
    {
        $minSalary = $this->faker->numberBetween(5000000, 20000000);
        $maxSalary = $minSalary + $this->faker->numberBetween(200000, 1000000);
        
        // Tạo Title trước để gen Slug khớp
        $title = $this->faker->jobTitle();
        $slug = Str::slug($title) . '-' . Str::random(6); // Thêm random để tránh trùng

        // Tạo nội dung HTML
        $htmlDesc = '<h3>Job Description</h3><p>' . implode('</p><p>', $this->faker->paragraphs(3)) . '</p>';
        $htmlReq = '<ul><li>' . implode('</li><li>', $this->faker->sentences(3)) . '</li></ul>';
        $htmlBen = '<ul><li>' . implode('</li><li>', $this->faker->sentences(3)) . '</li></ul>';

        return [
            // ID để Model tự sinh (HasUuids) hoặc prefix nếu muốn
            // 'JobID' => 'TEST_' . Str::random(31), 

            'status' => $this->faker->randomElement(JobStatusEnum::cases()),
            'pending_data' => null,
            
            'Title' => $title,
            'slug' => $slug, // <--- ĐÃ BỔ SUNG SLUG
            
            'JobLink' => $this->faker->url(),
            'MaxSalary' => $maxSalary,
            'MinSalary' => $minSalary,
            'ExperienceYear' => $this->faker->numberBetween(1, 10),
            'MinAge' => $this->faker->numberBetween(18, 25),
            'MaxAge' => $this->faker->numberBetween(30, 50),
            
            'OpenDate' => $this->faker->dateTimeBetween('-1 month', 'now')->format('Y-m-d'),
            'EndDate' => $this->faker->dateTimeBetween('+1 week', '+3 months')->format('Y-m-d'),
            
            'PictureUrl' => $this->faker->imageUrl(640, 480, 'business'),
            'detail_address' => $this->faker->address(),
            
            // Các trường Text ngắn
            'Experience' => $this->faker->numberBetween(1, 5) . ' years experience.',
            'Degree' => $this->faker->randomElement(['Bachelor', 'College', 'Master Degree']),
            'TechnicalSkill' => implode('; ', $this->faker->words(3)),
            'SoftSkill' => implode('; ', $this->faker->words(3)),
            'Keywords' => implode('; ', $this->faker->words(5)),
            
            // Các trường HTML và Text tương ứng
            'Job_Description' => $htmlDesc,
            'MainDescription' => strip_tags($htmlDesc), // <--- Bổ sung bản text plain
            'Job_Requirements' => $htmlReq,
            'Job_Benefits' => $htmlBen,

            // Các chỉ số mặc định
            'ViewCount' => $this->faker->numberBetween(0, 1000),
            'ApplyCount' => $this->faker->numberBetween(0, 50),
            'Version' => 1,
        ];
    }

    public function pendingUpdate(): Factory
    {
        return $this->state(function (array $attributes) {
            return [
                'status' => JobStatusEnum::PENDING,
                'pending_data' => [
                    'Title' => '[UPDATED] ' . $attributes['Title'],
                    'MinSalary' => 10000000,
                    'Job_Description' => '<p>Updated content...</p>'
                ],
            ];
        });
    }

    public function withRandomForeignKeys(): Factory
    {
        static $foreignKeys;

        // Cache lại danh sách ID để chạy nhanh hơn
        if (is_null($foreignKeys)) {
            $foreignKeys = [
                'jobTypeIds' => DB::table('job_types')->pluck('JobTypeID')->toArray(),
                'jobSectorIds' => DB::table('job_sectors')->pluck('JobSectorID')->toArray(),
                'degreeLevelIds' => DB::table('job_degreelevels')->pluck('DegreeID')->toArray(),
                'currencyIds' => DB::table('sys_currencies')->pluck('CurrencyID')->toArray(),
                'workingTypeIds' => DB::table('job_workingtypes')->pluck('WorkingTypeID')->toArray(),
                'contractTypeIds' => DB::table('job_contracttypes')->pluck('ContractTypeID')->toArray(),
                'sexIds' => DB::table('sys_sexes')->pluck('SexID')->toArray(), // <--- Bổ sung Giới tính
                'locationIds' => DB::table('sys_locations')->limit(100)->pluck('LocationID')->toArray(), // <--- Bổ sung Location
            ];
        }

        return $this->state(function (array $attributes) use ($foreignKeys) {
            $safeRand = fn($arr) => !empty($arr) ? $arr[array_rand($arr)] : null;

            return [
                'JobTypeID' => $safeRand($foreignKeys['jobTypeIds']),
                'JobSectorID' => $safeRand($foreignKeys['jobSectorIds']),
                'DegreeLevelID' => $safeRand($foreignKeys['degreeLevelIds']),
                'CurrencyID' => $safeRand($foreignKeys['currencyIds']),
                'WorkingTypeID' => $safeRand($foreignKeys['workingTypeIds']),
                'ContractTypeID' => $safeRand($foreignKeys['contractTypeIds']),
                'SexID' => $safeRand($foreignKeys['sexIds']), // <--- Random Giới tính
                'LocationID' => $safeRand($foreignKeys['locationIds']), // <--- Random Location
            ];
        });
    }
}