<?php

use App\Mz\Jobs\Jobs;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

// Unattended background scheduling:
Schedule::command('sinksar:refresh --notify')->dailyAt('00:05')->timezone('Africa/Addis_Ababa');
Schedule::command('mz:jobs')->everyMinute();

// Optional manual trigger; background work normally runs request-driven (see App\Mz\Jobs\Jobs).
Artisan::command('mz:jobs {names?* : job names, e.g. programs:reminders} {--force : run even if not due} {--list : show jobs}', function () {
    if ($this->option('list')) {
        foreach (Jobs::all() as $name => [$when]) $this->line(str_pad($name, 26) . (is_int($when) ? "every {$when}s" : "daily at $when"));
        return 0;
    }
    $names = $this->argument('names') ?: null;
    $out = Jobs::runDue($names, (bool) $this->option('force') || (bool) $names);
    $this->line(json_encode($out, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
    return 0;
})->purpose('Run the background jobs that are due (reminders, dispatch, fines, cleanup)');

Artisan::command('mz:telegram-webhook', function () {
    $res = Jobs::telegramWebhook();
    $this->line(json_encode($res, JSON_PRETTY_PRINT));
    return 0;
})->purpose('Register Telegram webhook with current PUBLIC_BASE_URL');

// Creates (or re-keys) an internal system-authority account. Run on the server console only:
//   SYSTEM_BOOTSTRAP_PASSWORD=… php artisan mz:superadmin --name="…" --phone=09XXXXXXXX [--email=x@y] [--rotate-totp]
// The password comes from the environment (never argv, which leaks into shell history).
Artisan::command('mz:superadmin {--name=} {--phone=} {--email=} {--rotate-totp}', function () {
    $phone = \App\Mz\Support\V::normalizePhone((string) $this->option('phone'));
    $name = (string) $this->option('name');
    if (! $phone || $name === '') {
        $this->error('Usage: php artisan mz:superadmin --name="Full Name" --phone=09XXXXXXXX [--email=a@b.c] [--rotate-totp]');
        return 1;
    }
    $pwd = (string) getenv('SYSTEM_BOOTSTRAP_PASSWORD');
    if (strlen($pwd) < 14 || ! preg_match('/[A-Za-z]/', $pwd) || ! preg_match('/\d/', $pwd)) {
        $this->error('Set SYSTEM_BOOTSTRAP_PASSWORD (>= 14 chars, letters and digits) in the environment.');
        return 1;
    }
    $db = \Illuminate\Support\Facades\DB::class;
    $role = $db::table('roles')->where('slug', \App\Mz\Auth\Catalog::ROLE_SYSTEM)->first();
    $existing = $db::table('users')->where('phone', $phone)->first();
    if ($existing && (int) $existing->role_id !== (int) $role->id) {
        $this->error('That phone number belongs to a non-system account.');
        return 1;
    }
    $secret = \App\Mz\Auth\Totp::generateSecret();
    $hash = \App\Mz\Auth\Passwords::hash($pwd);
    if ($existing) {
        $patch = ['password_hash' => $hash, 'token_version' => $existing->token_version + 1];
        $newTotp = $this->option('rotate-totp') || ! $existing->totp_secret_enc;
        if ($newTotp) $patch['totp_secret_enc'] = \App\Mz\Support\Crypto::encryptSecret($secret);
        $db::table('users')->where('id', $existing->id)->update($patch);
        $this->info("Updated system account #{$existing->id}.");
        if (! $newTotp) return 0;
    } else {
        $email = $this->option('email');
        $id = $db::table('users')->insertGetId([
            'full_name' => $name, 'phone' => $phone, 'email' => $email ? strtolower($email) : null, 'password_hash' => $hash,
            'account_type' => 'admin', 'role_id' => $role->id, 'totp_secret_enc' => \App\Mz\Support\Crypto::encryptSecret($secret),
            'password_changed_at' => $db::raw('NOW()'),
        ]);
        $db::table('user_preferences')->insert(['user_id' => $id]);
        $this->info("Created system account #$id.");
    }
    $this->line("\nAdd this to an authenticator app (shown once):");
    $this->line(\App\Mz\Auth\Totp::keyUri($phone, 'Mezmur Zelideta System', $secret));
    return 0;
})->purpose('Create or re-key the internal system-authority account');

// At-rest encryption of the sensitive columns (MZ-Seal, see App\Mz\Crypto). New and changed rows are
// encrypted automatically; this command handles the data already in the database:
//   php artisan mz:encrypt-data --dry-run        how many values are still plain text
//   php artisan mz:encrypt-data                  encrypt them (run once after deploying; safe to repeat)
//   php artisan mz:encrypt-data --rotate         re-encrypt with the current DATA_ENCRYPTION_KEY
//   php artisan mz:encrypt-data --decrypt        store plain text again (needs DATA_ENCRYPTION=false)
//   php artisan mz:encrypt-data --generate-key   print a new DATA_ENCRYPTION_KEY
// Back up the database and the key first: without the key the encrypted data cannot be read.
Artisan::command('mz:encrypt-data {--dry-run : only count} {--decrypt : store plain text again} {--rotate : re-encrypt with the current key} {--table=* : limit to these tables} {--chunk=500 : rows per batch} {--generate-key : print a new key and exit} {--force : do not ask for confirmation in production}', function () {
    if ($this->option('generate-key')) {
        $this->line('DATA_ENCRYPTION_KEY=' . \App\Mz\Crypto\Seal::generateKey());
        $this->warn('Store it in .env AND in a safe place: losing it means losing the encrypted data. Values sealed with a previous DATA_ENCRYPTION_KEY need it in DATA_ENCRYPTION_OLD_KEYS (the APP_KEY-derived key is always accepted); then run --rotate.');
        return 0;
    }
    $mode = $this->option('decrypt') ? 'decrypt' : ($this->option('rotate') ? 'rotate' : 'encrypt');
    $dry = (bool) $this->option('dry-run');
    if (! $dry && app()->environment('production') && ! $this->option('force')
        && ! $this->confirm("Run mz:encrypt-data ($mode) on the PRODUCTION database? Make sure the database and the key are backed up.")) {
        return 1;
    }
    if ($mode === 'encrypt' && ! \App\Mz\Crypto\Seal::enabled()) {
        $this->warn('DATA_ENCRYPTION=false: existing values are encrypted, but new writes will be stored as plain text.');
    }
    try {
        $total = 0;
        $report = \App\Mz\Crypto\DataEncryptor::run($mode, (array) $this->option('table'), (int) $this->option('chunk'), $dry, function ($t, $c, $n) use (&$total) {
            $total += $n;
            if ($n > 0) $this->line(sprintf('  %-34s %8d', "$t.$c", $n));
        });
    } catch (\RuntimeException $e) {
        $this->error($e->getMessage());
        return 1;
    }
    $verb = ['encrypt' => 'encrypted', 'decrypt' => 'decrypted', 'rotate' => 're-encrypted'][$mode];
    $this->info(($dry ? 'Would be ' : '') . "$verb: $total value(s) in " . count($report) . ' column(s).');
    return 0;
})->purpose('Encrypt (or decrypt / re-key) the sensitive columns already stored in the database');

// Amharic saved as "?" in `items` / `borrowings` while they were latin1 (fixed by the utf8mb4
// migration): restore those values from the original dump. Only values that are nothing but "?"
// are replaced, and only where the dump has real text for the same row.
//   php artisan mz:repair-text ../hersolot_mh_prod.sql --dry-run     list what would change
//   php artisan mz:repair-text ../hersolot_mh_prod.sql               restore
Artisan::command('mz:repair-text {dump : path of the .sql dump} {--table=* : items and/or borrowings} {--dry-run : only list}', function () {
    $path = (string) $this->argument('dump');
    if (! is_file($path)) {
        $this->error("Dump not found: $path");
        return 1;
    }
    $sql = (string) file_get_contents($path);
    $tables = $this->option('table') ?: ['items', 'borrowings'];
    $dry = (bool) $this->option('dry-run');
    $total = 0;
    foreach ($tables as $t) {
        foreach (\App\Mz\Support\TextRepair::repair($sql, $t, $dry) as $c) {
            $total++;
            $this->line(sprintf('%s #%d %s: "%s" → "%s"', $t, $c['id'], $c['column'], $c['now'], $c['restored']));
        }
    }
    $this->info(($dry ? 'Would restore ' : 'Restored ') . "$total value(s).");
    return 0;
})->purpose('Restore Amharic text that a latin1 table saved as "?" (items, borrowings) from a dump');
