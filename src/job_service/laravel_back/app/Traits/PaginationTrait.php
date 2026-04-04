<?php

namespace App\Traits;

use Illuminate\Pagination\LengthAwarePaginator;

trait PaginationTrait
{
    protected function paginate($queryOrItems, ?int $perPage = null): LengthAwarePaginator
    {
        $perPage    = $perPage ?: config('services.pagination.size');
        $page       = (int) request()->query('page', 1);
        $query      = $queryOrItems;
        $paginator  = null;

        if (method_exists($query, 'paginate')) {
            // Nếu là Builder, dùng paginate trực tiếp
            $paginator = $query->paginate($perPage, ['*'], 'page', $page);
        } else {
            // Nếu là Collection hoặc mảng: tạo thủ công
            $items      = $query instanceof \Illuminate\Support\Collection
                            ? $query
                            : collect($query);
            $total      = $items->count();
            $slice      = $items->forPage($page, $perPage);
            $paginator  = new LengthAwarePaginator(
                $slice->values()->all(),
                $total,
                $perPage,
                $page,
                [
                    'path'  => request()->url(),
                    'query' => request()->query(),
                ]
            );
        }

        // Giữ nguyên các query string khác (filters, sort…)
        return $paginator->appends(request()->query());
    }
}
