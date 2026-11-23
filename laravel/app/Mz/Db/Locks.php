<?php

namespace App\Mz\Db;

use Closure;
use Illuminate\Support\Facades\DB;

/** Cross-process mutex using MySQL named locks (jobs never run twice at the same time). */
final class Locks
{
    /** Runs fn under the lock, waiting up to [seconds] for another process to release it. */
    public static function waitFor(string $name, Closure $fn, int $seconds = 10): mixed
    {
        if (DB::getDriverName() !== 'mysql') {
            return $fn();
        }

        $got = DB::selectOne('SELECT GET_LOCK(?, ?) AS got', [$name, $seconds]);
        if (! $got || (int) $got->got !== 1) {
            throw new \App\Mz\Support\ApiError(503, 'BUSY', 'Please try again');
        }
        try {
            return $fn();
        } finally {
            DB::select('SELECT RELEASE_LOCK(?)', [$name]);
        }
    }

    /** Runs fn under the lock; returns ['skipped' => true] when another process holds it. */
    public static function named(string $name, Closure $fn): mixed
    {
        if (DB::getDriverName() !== 'mysql') {
            return $fn();
        }

        $got = DB::selectOne('SELECT GET_LOCK(?, 0) AS got', [$name]);
        if (! $got || (int) $got->got !== 1) {
            return ['skipped' => true];
        }
        try {
            return $fn();
        } finally {
            DB::select('SELECT RELEASE_LOCK(?)', [$name]);
        }
    }
}
