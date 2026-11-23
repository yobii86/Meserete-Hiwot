<?php

namespace App\Mz\Services;

use App\Mz\Support\Z;
use App\Mz\Support\ZType;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Member IDs (መ/ሕ/ወ/17): a permanent number (users.member_no, from id_sequences, never edited or
 * reused) plus a prefix chosen by the member's group (setting member_id.format). Port of
 * memberIdService.js. The hidden system authority has no number.
 */
final class MemberIds
{
    public const MEMBER_GROUPS = ['children', 'youth_adult', 'married'];
    public const FORMAT_DEFAULT = [
        'prefixes' => ['youth_adult' => 'መ/ሕ/ወ', 'children' => 'መ/ሕ/ሕ', 'married' => 'መ/ሕ/ባ'],
        'separator' => '/',
        'min_digits' => 0,
    ];
    private const SETTING_KEY = 'member_id.format';

    private static ?array $cached = null;

    public static function formatSchema(): ZType
    {
        $prefix = Z::string()->trim()->max(30)->regex('/^[^\s<>]*$/u', 'NO_SPACES');
        return Z::object([
            // One prefix per member type (built-in or administrator-created); a type without its own
            // prefix uses the youth / adult one.
            'prefixes' => Z::record($prefix)->refine(fn ($v) => ! array_diff(array_keys($v), MemberGroups::keys()), 'INVALID_MEMBER_GROUP'),
            'separator' => Z::enum(['/', '-', '.', ' ', '']),
            'min_digits' => Z::number()->int()->min(0)->max(8),
        ])->strict();
    }

    public static function loadFormat(): array
    {
        $value = Settings::get(self::SETTING_KEY);
        self::$cached = $value
            ? array_merge(self::FORMAT_DEFAULT, $value, ['prefixes' => array_merge(self::FORMAT_DEFAULT['prefixes'], $value['prefixes'] ?? [])])
            : self::FORMAT_DEFAULT;
        return self::$cached;
    }

    /** The format, read once per request. */
    public static function currentFormat(): array
    {
        return self::$cached ?? self::loadFormat();
    }

    public static function format(int|string|null $memberNo, ?string $group, ?array $fmt = null): ?string
    {
        if ($memberNo === null) {
            return null;
        }
        $fmt ??= self::currentFormat();
        $digits = str_pad((string) $memberNo, (int) ($fmt['min_digits'] ?? 0), '0', STR_PAD_LEFT);
        $p = $fmt['prefixes'][$group ?? ''] ?? ($fmt['prefixes']['youth_adult'] ?? '');
        return $p !== '' ? $p . $fmt['separator'] . $digits : $digits;
    }

    /** Adds member_id to rows carrying member_no and member_group. */
    public static function decorate(array $rows, string $no = 'member_no', string $group = 'member_group', string $out = 'member_id'): array
    {
        $fmt = self::currentFormat();
        foreach ($rows as $r) {
            if (is_object($r)) {
                $r->{$out} = self::format($r->{$no} ?? null, $r->{$group} ?? null, $fmt);
            }
        }
        return $rows;
    }

    /** "17", "#17", "መ/ሕ/ወ/17", "MH-0042" → the number; plain words → null. */
    public static function noFromQuery(?string $q): ?int
    {
        return preg_match('/^\s*(?:#|.*?[\/\-.\s])?0*(\d{1,9})\s*$/u', (string) $q, $m) ? (int) $m[1] : null;
    }

    /** Name / phone / member-number search on a users query (alias "u"). */
    public static function search(Builder $qb, ?string $q, string $alias = 'u', bool $phone = true): Builder
    {
        if (! $q) {
            return $qb;
        }
        $no = self::noFromQuery($q);
        return $qb->where(function ($w) use ($q, $alias, $phone, $no) {
            $w->where("$alias.full_name", 'like', "%$q%");
            if ($phone) $w->orWhere("$alias.phone", 'like', "%$q%");
            if ($no !== null) $w->orWhere("$alias.member_no", $no);
        });
    }

    /** Every member account: users and administrators, never the hidden system authority. */
    /**
     * Same as memberAccounts() for a query on `users` with another alias (or none): members AND
     * administrators — administrators are members too — never the hidden system authority.
     */
    public static function membersAndAdmins(Builder $qb, string $alias = 'users'): Builder
    {
        $qb->whereIn("$alias.account_type", ['user', 'admin']);
        if (Schema::hasTable('roles')) {
            $qb->whereNotExists(fn ($s) => $s->select(DB::raw(1))->from('roles as hr2')->whereColumn('hr2.id', "$alias.role_id")->where('hr2.is_hidden', true));
        }
        return $qb;
    }

    public static function memberAccounts(Builder $qb): Builder
    {
        $qb->whereIn('u.account_type', ['user', 'admin'])
            ->whereNull('u.deleted_at');
        if (Schema::hasTable('roles')) {
            $qb->whereNotExists(fn ($s) => $s->select(DB::raw(1))->from('roles as hr')->whereColumn('hr.id', 'u.role_id')->where('hr.is_hidden', true));
        }
        return $qb;
    }

    /** Give the account its permanent number if it has none (idempotent; skips hidden roles). */
    public static function assign(int $userId): ?int
    {
        $u = DB::table('users as u')->leftJoin('roles as r', 'r.id', '=', 'u.role_id')->where('u.id', $userId)->first(['u.member_no', 'r.is_hidden']);
        if (! $u || $u->member_no || $u->is_hidden) {
            return $u?->member_no;
        }
        // LAST_INSERT_ID(expr) makes the increment atomic per connection.
        DB::update("UPDATE id_sequences SET value = LAST_INSERT_ID(value + 1) WHERE name = 'member_no'");
        $next = (int) DB::selectOne('SELECT LAST_INSERT_ID() AS next')->next;
        $n = DB::table('users')->where('id', $userId)->whereNull('member_no')->update(['member_no' => $next]);
        if (! $n) {
            return DB::table('users')->where('id', $userId)->value('member_no');
        }
        return $next;
    }

    public static function updateFormat(array $input, ?int $actorId): array
    {
        $parsed = Z::parse(self::formatSchema(), $input);
        Settings::put(self::SETTING_KEY, $parsed, $actorId);
        return self::loadFormat();
    }
}
