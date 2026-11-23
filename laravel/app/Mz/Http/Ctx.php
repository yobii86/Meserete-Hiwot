<?php

namespace App\Mz\Http;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Z;
use App\Mz\Support\ZType;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;

/** Request-scoped helpers for route handlers (req.auth, auditCtx(req), validate(...)). */
final class Ctx
{
    public static function req(): Request
    {
        return request();
    }

    public static function auth(): AuthContext
    {
        $a = request()->attributes->get('mz_auth');
        if (! $a) {
            throw ApiError::unauthorized();
        }
        return $a;
    }

    public static function authOrNull(): ?AuthContext
    {
        return request()->attributes->get('mz_auth');
    }

    public static function bodyOrNull(): ?array
    {
        try {
            return self::input();
        } catch (\Throwable) {
            return null;
        }
    }

    /** auditCtx(req): { auth, ip, userAgent }. */
    public static function actx(): array
    {
        $r = request();
        return ['auth' => self::authOrNull(), 'ip' => $r->ip(), 'userAgent' => $r->userAgent()];
    }

    /** { ip, userAgent } for services. */
    public static function meta(): array
    {
        return ['ip' => request()->ip(), 'userAgent' => request()->userAgent()];
    }

    public static function ip(): ?string
    {
        return request()->ip();
    }

    /** The JSON body (or multipart fields) as an array. */
    public static function input(): array
    {
        $r = request();
        if ($r->isJson()) {
            $raw = $r->getContent();
            if (trim($raw) === '') {
                return [];
            }
            $j = json_decode($raw, true);
            if (json_last_error() !== JSON_ERROR_NONE) {
                throw ApiError::badRequest('INVALID_JSON', 'Malformed JSON body');
            }
            return is_array($j) ? $j : [];
        }
        return $r->request->all();
    }

    /** validate(schema) on the body. */
    public static function body(ZType $schema): mixed
    {
        return Z::parse($schema, self::input());
    }

    /** validate(schema, 'query'). */
    public static function query(ZType $schema): mixed
    {
        return Z::parse($schema, request()->query->all());
    }

    /** validate(schema, 'params') — route parameters. */
    public static function params(ZType $schema): mixed
    {
        return Z::parse($schema, request()->route()?->parameters() ?? []);
    }

    /** Positive integer route parameter (validate(idParam, 'params')). */
    public static function id(string $name = 'id'): int
    {
        $p = Z::parse(Z::object([$name => \App\Mz\Support\V::id()]), [$name => request()->route($name)]);
        return $p[$name];
    }

    /** Raw query parameters (strings). */
    public static function q(): array
    {
        return request()->query->all();
    }

    public static function file(string $field = 'file'): ?UploadedFile
    {
        $f = request()->file($field);
        return $f instanceof UploadedFile ? $f : null;
    }
}
