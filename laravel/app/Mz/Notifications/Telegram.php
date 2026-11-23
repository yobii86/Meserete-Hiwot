<?php

namespace App\Mz\Notifications;

use App\Mz\Support\ApiError;
use App\Mz\Support\Crypto;
use App\Mz\Support\Dates;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Telegram bot (port of telegramService.js): account linking, password-reset codes, temporary
 * passwords. Production receives updates through the webhook; `php artisan mz:telegram poll` is
 * for local development.
 */
final class Telegram
{
    private const LINK_TTL_MIN = 30;
    private static ?string $cachedUsername = null;

    public static function token(): string
    {
        return trim((string) (config('mz.telegram.token') ?: env('TELEGRAM_BOT_TOKEN', '')));
    }

    public static function botUsername(): string
    {
        if (self::$cachedUsername !== null) {
            return self::$cachedUsername;
        }

        $u = trim(ltrim((string) (config('mz.telegram.username') ?: env('TELEGRAM_BOT_USERNAME', '')), '@'));
        if ($u !== '') {
            return self::$cachedUsername = $u;
        }

        $token = self::token();
        if ($token === '') {
            return '';
        }

        try {
            $me = self::api('getMe', timeout: 5);
            if (!empty($me['username'])) {
                return self::$cachedUsername = (string) $me['username'];
            }
        } catch (\Throwable $e) {
            Log::warning('telegram getMe failed to resolve username: ' . $e->getMessage());
        }

        return '';
    }

    public static function enabled(): bool
    {
        return self::token() !== '';
    }

    public static function testConnection(): array
    {
        $token = self::token();
        if ($token === '') {
            return [
                'configured' => false,
                'status' => 'not_configured',
                'message' => 'Telegram bot is not configured (missing TELEGRAM_BOT_TOKEN)',
                'bot_username' => null,
                'bot_name' => null,
            ];
        }

        try {
            $me = self::api('getMe', timeout: 10);
            if (empty($me) || empty($me['is_bot'])) {
                return [
                    'configured' => true,
                    'status' => 'invalid_token',
                    'message' => 'Telegram Bot API rejected the credentials.',
                    'bot_username' => null,
                    'bot_name' => null,
                ];
            }

            self::$cachedUsername = (string) ($me['username'] ?? '');

            return [
                'configured' => true,
                'status' => 'connected',
                'message' => 'Connected successfully to Telegram Bot API.',
                'bot_username' => $me['username'] ?? null,
                'bot_name' => $me['first_name'] ?? null,
                'bot_id' => $me['id'] ?? null,
                'can_join_groups' => (bool) ($me['can_join_groups'] ?? false),
                'can_read_all_group_messages' => (bool) ($me['can_read_all_group_messages'] ?? false),
            ];
        } catch (\Throwable $e) {
            $msg = $e->getMessage();
            $lower = strtolower($msg);
            $status = (str_contains($lower, 'unauthorized') || str_contains($msg, '401') || str_contains($lower, 'not found') || str_contains($msg, '404'))
                ? 'invalid_token'
                : 'connection_failed';

            return [
                'configured' => true,
                'status' => $status,
                'message' => "Telegram connection failed: $msg",
                'bot_username' => null,
                'bot_name' => null,
            ];
        }
    }

    public static function userStatus(int $userId): array
    {
        $u = DB::table('users')->where('id', $userId)->first(['telegram_chat_id', 'telegram_username', 'telegram_linked_at']);
        $test = self::testConnection();

        return [
            'linked' => (bool) $u?->telegram_chat_id,
            'username' => $u?->telegram_username,
            'linked_at' => $u?->telegram_linked_at,
            'bot_configured' => $test['configured'],
            'bot_status' => $test['status'],
            'bot_username' => $test['bot_username'] ?: self::botUsername(),
            'bot_name' => $test['bot_name'] ?? null,
        ];
    }

    public static function escapeHtml(?string $s): string
    {
        return str_replace(['&', '<', '>'], ['&amp;', '&lt;', '&gt;'], (string) $s);
    }

    public static function api(string $method, array $body = [], int $timeout = 15): mixed
    {
        $token = self::token();
        if ($token === '') {
            throw new \RuntimeException('Telegram bot token is not configured');
        }
        $apiBase = rtrim((string) (config('mz.telegram.api_base') ?: 'https://api.telegram.org'), '/');
        $res = Http::timeout($timeout)->asJson()->post("{$apiBase}/bot{$token}/$method", (object) $body);
        $json = $res->json() ?? [];
        if (empty($json['ok'])) {
            throw new \RuntimeException("telegram $method failed: " . ($json['description'] ?? $res->status()));
        }
        return $json['result'] ?? null;
    }

    /** Best-effort HTML message; never throws. */
    public static function sendMessage(int|string|null $chatId, string $html): bool
    {
        if (! self::enabled() || ! $chatId) {
            return false;
        }
        try {
            self::api('sendMessage', ['chat_id' => $chatId, 'text' => $html, 'parse_mode' => 'HTML', 'disable_web_page_preview' => true]);
            return true;
        } catch (\Throwable $e) {
            Log::warning('telegram send failed', ['error' => $e->getMessage()]);
            return false;
        }
    }

    public static function sendToUser(int $userId, string $html): bool
    {
        $u = DB::table('users')->where('id', $userId)->first(['telegram_chat_id']);
        return $u?->telegram_chat_id ? self::sendMessage($u->telegram_chat_id, $html) : false;
    }

    public static function createLinkToken(int $userId): array
    {
        if (! self::enabled()) {
            throw new ApiError(503, 'TELEGRAM_NOT_CONFIGURED', 'Telegram bot is not configured');
        }
        $token = Crypto::randomToken(24);
        DB::transaction(function () use ($userId, $token) {
            // Delete already-expired tokens to keep the table clean
            DB::table('telegram_link_tokens')->where('expires_at', '<=', gmdate('Y-m-d H:i:s'))->delete();
            DB::table('telegram_link_tokens')->insert([
                'user_id' => $userId,
                'token_hash' => Crypto::hmac("tg:$token"),
                'expires_at' => gmdate('Y-m-d H:i:s', time() + self::LINK_TTL_MIN * 60),
            ]);
        });
        $bot = self::botUsername();
        if ($bot === '') {
            throw new ApiError(503, 'TELEGRAM_NOT_CONFIGURED', 'Telegram bot username could not be resolved');
        }
        return ['url' => "https://t.me/$bot?start=$token", 'bot_username' => $bot, 'expires_in_minutes' => self::LINK_TTL_MIN];
    }

    public static function unlink(int $userId): void
    {
        $u = DB::table('users')->where('id', $userId)->first(['telegram_chat_id']);
        DB::table('users')->where('id', $userId)->update(['telegram_chat_id' => null, 'telegram_username' => null, 'telegram_linked_at' => null]);
        if ($u?->telegram_chat_id) {
            self::sendMessage($u->telegram_chat_id, T::t('telegram.unlinked'));
        }
    }

    private static function linkChat(string $token, array $chat, ?array $from): bool
    {
        $tokenHash = Crypto::hmac("tg:$token");
        $row = DB::table('telegram_link_tokens')
            ->where('token_hash', $tokenHash)
            ->whereNull('used_at')
            ->where('expires_at', '>', gmdate('Y-m-d H:i:s'))
            ->first();

        if (! $row) {
            // 1. If this Telegram account is already linked to a user, inform them nicely
            $alreadyLinked = DB::table('users')->where('telegram_chat_id', $chat['id'])->first(['id', 'full_name']);
            if ($alreadyLinked) {
                return self::sendMessage($chat['id'], T::t('telegram.linked', ['name' => self::escapeHtml($alreadyLinked->full_name)]));
            }

            // 2. If this token was just recently redeemed (e.g. within last 15 min), also confirm
            $recentlyUsed = DB::table('telegram_link_tokens')
                ->where('token_hash', $tokenHash)
                ->whereNotNull('used_at')
                ->first();
            if ($recentlyUsed) {
                $user = DB::table('users')->where('id', $recentlyUsed->user_id)->first(['full_name']);
                if ($user) {
                    return self::sendMessage($chat['id'], T::t('telegram.linked', ['name' => self::escapeHtml($user->full_name)]));
                }
            }

            return self::sendMessage($chat['id'], T::t('telegram.invalid'));
        }

        $user = DB::transaction(function () use ($row, $chat, $from) {
            $now = Dates::sql(now());
            // Mark all active link tokens for this user as used
            DB::table('telegram_link_tokens')->where('user_id', $row->user_id)->whereNull('used_at')->update(['used_at' => $now]);
            // One Telegram account ↔ one app account: release it from anyone else first.
            DB::table('users')->where('telegram_chat_id', $chat['id'])->where('id', '<>', $row->user_id)->update(['telegram_chat_id' => null, 'telegram_username' => null, 'telegram_linked_at' => null]);
            DB::table('users')->where('id', $row->user_id)->update([
                'telegram_chat_id' => $chat['id'],
                'telegram_username' => ! empty($from['username']) ? mb_substr((string) $from['username'], 0, 64) : null,
                'telegram_linked_at' => $now,
            ]);
            return DB::table('users')->where('id', $row->user_id)->first(['full_name']);
        });
        return self::sendMessage($chat['id'], T::t('telegram.linked', ['name' => self::escapeHtml($user->full_name)]));
    }

    /** Process one Telegram update (webhook or polling). */
    public static function handleUpdate(?array $update): void
    {
        $msg = $update['message'] ?? null;
        if (empty($msg['text']) || ($msg['chat']['type'] ?? null) !== 'private') {
            return;
        }
        $parts = preg_split('/\s+/', trim($msg['text']), 3);
        $command = $parts[0] ?? '';
        $arg = $parts[1] ?? null;
        if ($command === '/start' && $arg && preg_match('/^[A-Za-z0-9_-]{8,64}$/', $arg)) {
            self::linkChat($arg, $msg['chat'], $msg['from'] ?? null);
            return;
        }
        if ($command === '/stop') {
            $u = DB::table('users')->where('telegram_chat_id', $msg['chat']['id'])->first(['id']);
            if ($u) {
                self::unlink($u->id);
                return;
            }
        }
        self::sendMessage($msg['chat']['id'], T::t('telegram.welcome'));
    }

    public static function verifyWebhookSecret(?string $header): bool
    {
        $secret = (string) config('mz.telegram.webhook_secret');
        return $secret !== '' && hash_equals($secret, (string) $header);
    }
}
