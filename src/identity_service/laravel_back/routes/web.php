<?php
use App\Http\Controllers\Controller;

// use App\Http\Controllers\Job\CvMatchingController;

// // API routes that proxy to FastAPI
// Route::get('/', [CvMatchingController::class, 'index'])->name('home');
// Route::middleware([])->post('/recommendations/upload-cv', [CvMatchingController::class, 'uploadCV'])->name('upload.cv');

// Route::middleware([])->post('/recommendations/keyword-search', [CvMatchingController::class, 'getKeywordJobs'])->name('fastjob.search');
// // Route::middleware([])->post('/resume/fields', [CvMatchingController::class, 'getExtractedKeywords'])->name('fields.resume');\

// Route::get('/api/provinces', [CvMatchingController::class, 'getProvinces'])->name('api.provinces');
// Route::get('/api/districts/{provinceCode}', [CvMatchingController::class, 'getDistricts'])->name('api.districts');
// Route::get('/api/recent_jobs', [CvMatchingController::class, 'getMostRecentJobs'])->name('api.recent_jobs');

// Route::middleware([])->post('/recommendations/keyword-search', [CvMatchingController::class, 'getKeywordJobs'])->name('fastjob.search');
// Route::middleware([])->post('/resume/fields', [CvMatchingController::class, 'getExtractedKeywords'])->name('fields.resume');
// Route::middleware([])->post('/api/get_html', [CvMatchingController::class, 'getJobHTML'])->name('api.get_html');
// Route::get('/csrf-token', function () {
//     return response()->json(['csrf_token' => csrf_token()]);
// });

// Include internal-only routes (hot-reload) if present
if (file_exists(__DIR__ . '/internal.php')) {
	require __DIR__ . '/internal.php';
}