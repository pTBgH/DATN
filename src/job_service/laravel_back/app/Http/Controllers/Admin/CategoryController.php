<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Job\JobSector;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class CategoryController extends Controller
{
    public function indexSectors(): JsonResponse
    {
        $sectors = JobSector::orderBy('JobSectorName', 'asc')->get();
        return response()->json($sectors);
    }

    public function storeSector(Request $request): JsonResponse
    {
        $request->validate([
            'name' => 'required|string|max:255|unique:job_sectors,JobSectorName'
        ], [
            'name.unique' => 'Tên ngành nghề này đã tồn tại.'
        ]);
        
        $sector = JobSector::create([
            'JobSectorName' => $request->name
        ]);
        
        return response()->json($sector, 201);
    }

    public function updateSector(Request $request, $id): JsonResponse
    {
        // Tìm theo Primary Key (JobSectorID)
        $sector = JobSector::findOrFail($id);

        $request->validate([
            // Unique nhưng bỏ qua ID hiện tại
            'name' => 'required|string|max:255|unique:job_sectors,JobSectorName,' . $id . ',JobSectorID'
        ], [
            'name.unique' => 'Tên ngành nghề này đã tồn tại.'
        ]);

        $sector->update([
            'JobSectorName' => $request->name
        ]);

        return response()->json($sector);
    }

    public function destroySector($id): JsonResponse
    {
        $sector = JobSector::findOrFail($id);

        // TODO: Có thể check xem Sector này đang có Job nào dùng không trước khi xóa
        // if ($sector->jobs()->exists()) {
        //     return response()->json(['message' => 'Cannot delete sector in use.'], 409);
        // }

        try {
            $sector->delete();
            return response()->json(['message' => 'Sector deleted successfully.']);
        } catch (\Exception $e) {
            return response()->json(['message' => 'Cannot delete this sector due to constraints.'], 500);
        }
    }
}