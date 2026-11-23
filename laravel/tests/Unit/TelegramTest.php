<?php

namespace Tests\Unit;

use App\Mz\Notifications\Telegram;
use App\Mz\Support\Crypto;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class TelegramTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config(['mz.telegram.token' => 'test-token', 'mz.telegram.username' => 'TestBot']);

        if (! \Illuminate\Support\Facades\Schema::hasTable('users')) {
            \Illuminate\Support\Facades\Schema::create('users', function ($table) {
                $table->id();
                $table->string('full_name');
                $table->string('phone')->nullable();
                $table->string('account_type')->default('user');
                $table->string('status')->default('active');
                $table->string('telegram_chat_id', 64)->nullable()->unique();
                $table->string('telegram_username', 64)->nullable();
                $table->dateTime('telegram_linked_at')->nullable();
                $table->timestamps();
            });
        }

        if (! \Illuminate\Support\Facades\Schema::hasTable('telegram_link_tokens')) {
            \Illuminate\Support\Facades\Schema::create('telegram_link_tokens', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->string('token_hash', 64)->unique();
                $table->dateTime('expires_at');
                $table->dateTime('used_at')->nullable();
                $table->timestamps();
            });
        }
    }

    public function test_create_link_token_and_successful_linking(): void
    {
        Http::fake([
            'https://api.telegram.org/*' => Http::response(['ok' => true, 'result' => true]),
        ]);

        $userId = DB::table('users')->insertGetId([
            'full_name' => 'Abebe Kebede',
            'phone' => '0911223344',
            'account_type' => 'student',
            'status' => 'active',
            'created_at' => now(),
        ]);

        $linkInfo = Telegram::createLinkToken($userId);
        $this->assertNotEmpty($linkInfo['url']);
        $this->assertStringContainsString('https://t.me/TestBot?start=', $linkInfo['url']);

        $token = str_replace('https://t.me/TestBot?start=', '', $linkInfo['url']);

        // Simulate Telegram sending webhook update with /start <token>
        Telegram::handleUpdate([
            'message' => [
                'chat' => ['id' => 12345678, 'type' => 'private'],
                'from' => ['id' => 12345678, 'username' => 'abebe_k'],
                'text' => "/start $token",
            ],
        ]);

        // User should now be linked
        $user = DB::table('users')->where('id', $userId)->first();
        $this->assertEquals(12345678, $user->telegram_chat_id);
        $this->assertEquals('abebe_k', $user->telegram_username);
        $this->assertNotNull($user->telegram_linked_at);

        // Calling /start again with same token or without token should not return invalid/expired error,
        // but inform user they are already linked!
        Telegram::handleUpdate([
            'message' => [
                'chat' => ['id' => 12345678, 'type' => 'private'],
                'from' => ['id' => 12345678, 'username' => 'abebe_k'],
                'text' => "/start $token",
            ],
        ]);

        Http::assertSent(function ($request) {
            $data = $request->data();
            return isset($data['text']) && str_contains($data['text'], 'Abebe Kebede');
        });
    }

    public function test_invalid_token_returns_error_message(): void
    {
        Http::fake([
            'https://api.telegram.org/*' => Http::response(['ok' => true, 'result' => true]),
        ]);

        Telegram::handleUpdate([
            'message' => [
                'chat' => ['id' => 99999999, 'type' => 'private'],
                'from' => ['id' => 99999999, 'username' => 'unknown_user'],
                'text' => '/start invalidtoken12345678',
            ],
        ]);

        Http::assertSent(function ($request) {
            $data = $request->data();
            return isset($data['text']) && $data['text'] === T::t('telegram.invalid');
        });
    }
}
