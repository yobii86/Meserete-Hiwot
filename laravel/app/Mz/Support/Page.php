<?php

namespace App\Mz\Support;

use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;

/** Pagination identical to the Node.js backend (page / limit / offset; meta {page, limit, total, pages}). */
final class Page
{
    public const MAX = 100;

    public static function params(array $query = []): array
    {
        $page = max(1, (int) (is_numeric($query['page'] ?? null) ? $query['page'] : 1) ?: 1);
        $raw = $query['limit'] ?? null;
        $limit = is_numeric($raw) && (int) $raw > 0 ? (int) $raw : 20;
        $limit = min(self::MAX, max(1, $limit));
        return ['page' => $page, 'limit' => $limit, 'offset' => ($page - 1) * $limit];
    }

    /** @return array{items: array, meta: array{page:int,limit:int,total:int,pages:int}} */
    public static function paginate(Builder $qb, array $p): array
    {
        $count = clone $qb;
        $count->columns = null;
        $count->orders = null;
        $count->unionOrders = null;
        $count->limit = null;
        $count->offset = null;
        $count->bindings['select'] = [];
        $count->bindings['order'] = [];
        if ($count->groups || $count->distinct || $count->havings) {
            $sub = clone $qb;
            $sub->orders = null;
            $sub->bindings['order'] = [];
            $sub->limit = null;
            $sub->offset = null;
            $total = (int) DB::query()->fromSub($sub, 'c')->count();
        } else {
            $total = (int) $count->count();
        }
        $limit = max(1, (int) ($p['limit'] ?? $p['per_page'] ?? 20));
        $page = max(1, (int) ($p['page'] ?? 1));
        $offset = isset($p['offset']) ? (int) $p['offset'] : ($page - 1) * $limit;
        $items = (clone $qb)->limit($limit)->offset($offset)->get()->all();
        return ['items' => $items, 'meta' => ['page' => $page, 'limit' => $limit, 'total' => $total, 'pages' => (int) ceil($total / $limit)]];
    }
}
