<?php

namespace App\Http\Controllers\Candidate;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Models\User; // Import Model mới
use App\Services\Kafka\KafkaHelper;

class CandidateProfileController extends Controller
{
    protected KafkaHelper $kafka;

    public function __construct(KafkaHelper $kafka)
    {
        $this->kafka = $kafka;
    }

    public function show()
    {
        $userId = Auth::id(); 
        $authUser = Auth::user(); // GenericUser

        // Dùng firstOrCreate của Eloquent
        // Nó tự check DB, nếu chưa có thì tạo mới (Tự sinh UUIDv7, tự điền CreatedAt)
        $user = User::firstOrCreate(
            ['UserID' => $userId], // Điều kiện tìm (ID nội bộ đã map từ middleware)
            [
                'KeycloakUserID' => $authUser->id ?? null,
                'Email'          => $authUser->email ?? '',
                'UserName'       => $authUser->name ?? 'New Candidate',
                // Tách tên sơ bộ nếu cần (Middleware đã làm tốt hơn, nhưng đây là fallback)
                'FirstName'      => $authUser->first_name ?? '', 
                'LastName'       => $authUser->last_name ?? '',
            ]
        );

        return response()->json([
            'user_id'          => $user->UserID,
            'email'            => $user->Email,
            'user_name'        => $user->UserName,
            'first_name'       => $user->FirstName,
            'last_name'        => $user->LastName,
            'avatar'           => $user->LogoURL,
            'phone_number'     => $user->PhoneNumber,
            'sex_id'           => $user->SexID,
            'birth'            => $user->Birth,
            'experience_years' => $user->ExperienceYears,
            'description'      => $user->Description,
            'social_links'     => $user->SocialLinks ?? [], // Model đã cast sang array
            'alias'            => $user->Alias ?? [],
        ]);
    }

    public function update(Request $request)
    {
        $userId = Auth::id();
        
        $user = User::findOrFail($userId); // Tìm hoặc lỗi 404

        $data = $request->validate([
            'user_name'        => 'nullable|string|max:255',
            'first_name'       => 'nullable|string|max:255',
            'last_name'        => 'nullable|string|max:255',
            'phone_number'     => 'nullable|string|max:20',
            'sex_id'           => 'nullable|integer',
            'birth'            => 'nullable|date',
            'avatar'           => 'nullable|string|max:2048',
            'experience_years' => 'nullable|integer|min:0',
            'description'      => 'nullable|string',
            'social_links'     => 'nullable|array',
            'alias'            => 'nullable|array',
        ]);

        // Mapping dữ liệu
        // Bạn có thể dùng $user->fill() nhưng cần map key snake_case -> PascalCase
        
        if (isset($data['user_name'])) $user->UserName = $data['user_name'];
        if (isset($data['first_name'])) $user->FirstName = $data['first_name'];
        if (isset($data['last_name'])) $user->LastName = $data['last_name'];
        if (isset($data['phone_number'])) $user->PhoneNumber = $data['phone_number'];
        if (isset($data['avatar'])) $user->LogoURL = $data['avatar']; // Map Avatar -> LogoURL
        
        // Các trường trùng tên hoặc logic đơn giản
        $directMap = ['sex_id' => 'SexID', 
                      'experience_years' => 'ExperienceYears', 'description' => 'Description', 
                      'birth' => 'Birth', 'social_links' => 'SocialLinks', 'alias' => 'Alias'];

        foreach ($directMap as $reqKey => $colName) {
            if (array_key_exists($reqKey, $data)) {
                $user->$colName = $data[$reqKey];
            }
        }

        $user->save(); // Tự động update UpdatedAt
        $user->refresh();

        try {
            $this->kafka->produce('job7189.identity', [
                'event_type' => 'user.updated',
                'timestamp'  => microtime(true),
                'data' => [
                    'id'          => $user->UserID,
                    'keycloak_id' => $user->KeycloakUserID,
                    'email'       => $user->Email,
                    'name'        => $user->UserName, // Hoặc ghép First/Last
                    'avatar'      => $user->LogoURL,
                    'type'        => 'candidate'
                ]
            ]);
        } catch (\Exception $e) {
            Log::error("Kafka Update Failed: " . $e->getMessage());
        }

        return $this->show();
    }
}