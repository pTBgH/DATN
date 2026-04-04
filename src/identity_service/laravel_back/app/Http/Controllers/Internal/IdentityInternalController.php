<?php

namespace App\Http\Controllers\Internal;

use App\Http\Controllers\Controller;
use App\Models\Recruiter\Recruiter;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;



class IdentityInternalController extends Controller
{
    public function syncUser(Request $request)
    {

        (new StructuredLogger('system', 'action'))->info(['message' => "Toi duoc goi ne");

        $kcid = $request->input('keycloak_id');
        $type = $request->input('type');

        // Các biến này từ request sẽ BỊ BỎ QUA, chỉ dùng data trong DB
        // $email = $request->input('email'); 
        // $name = $request->input('name');

        $id = null;
        $email = null;
        $user_name = null;
        $firstName = null;
        $lastName = null;

        if ($type === 'recruiter') {
            // 1. Tìm Nhà tuyển dụng trong DB
            $recruiter = Recruiter::where('KeycloakUserID', $kcid)->first();

            if (!$recruiter) {
                (new StructuredLogger('system', 'warning'))->warning(['message' => "Recruiter with Keycloak ID {$kcid} not found in DB.");
                return response()->json(['message' => 'Recruiter profile not found'], 404);
            }

            if ($recruiter->StatusID != 1) {
                (new StructuredLogger('system', 'warning'))->warning(['message' => "Recruiter with Keycloak ID {$kcid} is inactive or banned.");
                return response()->json(['message' => 'Account is Banned/Inactive'], 403);
            }
            
            // Lấy dữ liệu THẬT từ Database
            $id = $recruiter->RecruiterID;
            $email = $recruiter->Email;
            $user_name = $recruiter->UserName; // Hoặc $recruiter->FirstName . ' ' . $recruiter->LastName
            $firstName = $recruiter->FirstName;
            $lastName = $recruiter->LastName;
        } else {
            // 2. Tìm Ứng viên trong DB (Sử dụng Model User)
            $candidate = User::where('KeycloakUserID', $kcid)->first();

            if (!$candidate) {
                (new StructuredLogger('system', 'warning'))->warning(['message' => "Candidate with Keycloak ID {$kcid} not found in DB.");
                return response()->json(['message' => 'Candidate profile not found'], 404);
            }

            // Lấy dữ liệu THẬT từ Database
            $id = $candidate->UserID;
            $email = $candidate->Email;
            $user_name = $candidate->UserName;
            $firstName = $candidate->FirstName;
            $lastName = $candidate->LastName;
        }

        (new StructuredLogger('system', 'action'))->info(['message' => "SyncUser: Type={$type}, KeycloakID={$kcid}, InternalID={$id}");
        (new StructuredLogger('system', 'action'))->info(['message' => "SyncUser Data: id={$id}, Email={$email}, UserName={$user_name}, FirstName={$firstName}, LastName={$lastName}");

        return response()->json([
            'id' => $id,
            'email' => $email,
            'name' => $user_name,
            'first_name' => $firstName,
            'last_name' => $lastName,
            'type' => $type
        ]);
    }

    public function getUserDetail($id)
    {
        // 1. Tìm trong bảng Ứng viên (usr_users) trước
        $candidate = \Illuminate\Support\Facades\DB::table('usr_users')
            ->where('UserID', $id)
            ->select(['UserID as id', 'Email as email', 'UserName as name'])
            ->first();

        if ($candidate) {
            return response()->json($candidate);
        }

        // 2. Nếu không thấy, tìm trong bảng Recruiter (rct_profiles)
        $recruiter = \Illuminate\Support\Facades\DB::table('rct_profiles')
            ->where('RecruiterID', $id)
            ->select(['RecruiterID as id', 'Email as email', \Illuminate\Support\Facades\DB::raw("CONCAT(FirstName, ' ', LastName) as name")])
            ->first();

        if ($recruiter) {
            return response()->json($recruiter);
        }

        // 3. Không thấy đâu cả
        return response()->json(['message' => 'User not found'], 404);
    }
}