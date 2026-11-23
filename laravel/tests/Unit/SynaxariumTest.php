<?php

namespace Tests\Unit;

use App\Models\SynaxariumDailySaint;
use App\Models\SynaxariumEntry;
use App\Models\SynaxariumMonth;
use App\Models\SynaxariumSaint;
use App\Models\SynaxariumSource;
use App\Mz\Services\Sinksar;
use App\Mz\Services\Synaxarium;
use App\Mz\Support\EthiopianCalendar;
use Illuminate\Console\Command;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class SynaxariumTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();
    }

    private function setUpSchema(): void
    {
        if (!Schema::hasTable('synaxarium_months')) {
            Schema::create('synaxarium_months', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedTinyInteger('month_number')->unique();
                $table->string('name_am', 50);
                $table->string('name_en', 50);
                $table->string('name_geez', 50)->nullable();
                $table->unsignedTinyInteger('days_count')->default(30);
                $table->unsignedTinyInteger('order_index')->default(0);
                $table->string('season_am', 50)->nullable();
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('synaxarium_sources')) {
            Schema::create('synaxarium_sources', function (Blueprint $table) {
                $table->bigIncrements('id');
                $table->string('book_id', 10)->unique();
                $table->string('classification', 50)->default('main_reading');
                $table->unsignedTinyInteger('month_number')->nullable()->index();
                $table->string('filename', 255);
                $table->string('collection', 100)->default('C12_Synaxarium_Senkisar');
                $table->string('group', 50)->default('Sinksar_Amharic');
                $table->string('title', 255);
                $table->string('language', 10)->default('am');
                $table->unsignedInteger('total_chapters')->default(0);
                $table->unsignedBigInteger('file_size')->default(0);
                $table->string('checksum', 64)->nullable();
                $table->string('import_status', 20)->default('pending');
                $table->timestamp('imported_at')->nullable();
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('synaxarium_entries')) {
            Schema::create('synaxarium_entries', function (Blueprint $table) {
                $table->bigIncrements('id');
                $table->unsignedTinyInteger('month')->index();
                $table->unsignedTinyInteger('day')->index();
                $table->string('unique_code', 10)->unique();
                $table->string('title', 255);
                $table->string('date_heading', 100)->nullable();
                $table->text('summary')->nullable();
                $table->longText('body_am');
                $table->longText('raw_content')->nullable();
                $table->json('annual_feasts')->nullable();
                $table->json('monthly_feasts')->nullable();
                $table->text('verses')->nullable();
                $table->string('source_book_id', 10)->nullable()->index();
                $table->unsignedInteger('chapter_number')->nullable();
                $table->unsignedInteger('char_count')->default(0);
                $table->unsignedInteger('word_count')->default(0);
                $table->string('editorial_status', 20)->default('imported');
                $table->boolean('is_editorially_verified')->default(false);
                $table->text('editorial_notes')->nullable();
                $table->unsignedBigInteger('verified_by')->nullable();
                $table->timestamp('verified_at')->nullable();
                $table->timestamps();

                $table->unique(['month', 'day'], 'uq_synaxarium_month_day');
            });
        }

        if (!Schema::hasTable('synaxarium_daily_saints')) {
            Schema::create('synaxarium_daily_saints', function (Blueprint $table) {
                $table->bigIncrements('id');
                $table->unsignedBigInteger('entry_id')->nullable()->index();
                $table->unsignedTinyInteger('month')->index();
                $table->unsignedTinyInteger('day')->index();
                $table->string('source_book_id', 10)->nullable()->index();
                $table->string('title', 255);
                $table->longText('section_text_clean');
                $table->longText('section_text_raw')->nullable();
                $table->unsignedInteger('commemoration_lines_count')->default(0);
                $table->string('editorial_status', 20)->default('imported');
                $table->boolean('is_editorially_verified')->default(false);
                $table->timestamps();

                $table->unique(['month', 'day'], 'uq_synax_daily_saints_date');
            });
        }

        if (!Schema::hasTable('synaxarium_saints')) {
            Schema::create('synaxarium_saints', function (Blueprint $table) {
                $table->bigIncrements('id');
                $table->unsignedBigInteger('entry_id')->nullable()->index();
                $table->unsignedTinyInteger('month')->index();
                $table->unsignedTinyInteger('day')->index();
                $table->unsignedInteger('order_index')->default(0);
                $table->string('name', 255)->index();
                $table->string('type', 100)->nullable();
                $table->string('feast_type', 50)->default('annual');
                $table->longText('biography')->nullable();
                $table->string('source_reference', 255)->nullable();
                $table->longText('raw_content')->nullable();
                $table->string('source_book_id', 10)->nullable()->index();
                $table->string('editorial_status', 20)->default('imported');
                $table->boolean('is_editorially_verified')->default(false);
                $table->timestamps();

                $table->index(['month', 'day'], 'idx_synaxarium_saints_date');
            });
        }

        if (!Schema::hasTable('sinksar_daily')) {
            Schema::create('sinksar_daily', function (Blueprint $table) {
                $table->increments('id');
                $table->date('gregorian_date')->unique();
                $table->string('ethiopian_date', 30);
                $table->unsignedSmallInteger('ethiopian_year');
                $table->unsignedTinyInteger('ethiopian_month');
                $table->unsignedTinyInteger('ethiopian_day');
                $table->string('month_name_am', 30);
                $table->string('weekday_am', 20);
                $table->string('weekday_en', 20);
                $table->boolean('is_fasting')->default(false);
                $table->string('fasting_reason', 150)->nullable();
                $table->string('featured_title', 255)->nullable();
                $table->text('summary')->nullable();
                $table->json('annual_feasts')->nullable();
                $table->json('monthly_feasts')->nullable();
                $table->boolean('full_text_available')->default(false);
                $table->timestamp('refreshed_at')->nullable();
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('sinksar_narratives')) {
            Schema::create('sinksar_narratives', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedTinyInteger('ethiopian_month');
                $table->unsignedTinyInteger('ethiopian_day');
                $table->string('title', 255);
                $table->string('source', 150)->nullable();
                $table->text('summary')->nullable();
                $table->longText('body');
                $table->boolean('verified')->default(false);
                $table->timestamps();
            });
        }

        // Pre-seed months
        $months = Synaxarium::defaultMonthsData();
        foreach ($months as $m) {
            DB::table('synaxarium_months')->updateOrInsert(
                ['month_number' => $m['month_number']],
                [
                    'name_am' => $m['name_am'],
                    'name_en' => $m['name_en'],
                    'name_geez' => $m['name_geez'],
                    'days_count' => $m['days_count'],
                    'order_index' => $m['order_index'],
                    'season_am' => $m['season_am'] ?? null,
                    'updated_at' => now(),
                    'created_at' => now(),
                ]
            );
        }
    }

    private function ensureImported(): void
    {
        if (DB::table('synaxarium_entries')->count() < 366) {
            $archivePath = 'c:\\Users\\HP\\Documents\\Downloads\\senkisar.zip';
            $exitCode = Artisan::call('synaxarium:import', ['path' => $archivePath]);
            $this->assertSame(Command::SUCCESS, $exitCode);
        }
    }

    public function test_month_seeding_creates_all_13_months(): void
    {
        $list = Synaxarium::listMonths();
        $this->assertCount(13, $list);
        $this->assertSame(1, $list[0]['month_number']);
        $this->assertSame('መስከረም', $list[0]['name_am']);
        $this->assertSame(30, $list[0]['days_count']);

        $this->assertSame(13, $list[12]['month_number']);
        $this->assertSame('ጳጉሜ', $list[12]['name_am']);
        $this->assertSame(6, $list[12]['days_count']);
    }

    public function test_complete_synaxarium_import_and_verification_suite(): void
    {
        $this->ensureImported();

        // 1. Source verification: 26 files (13 main books + 13 saints books)
        $sourcesCount = DB::table('synaxarium_sources')->count();
        $this->assertSame(26, $sourcesCount);

        $mainSources = DB::table('synaxarium_sources')->where('classification', 'main_reading')->count();
        $this->assertSame(13, $mainSources);

        $saintsSources = DB::table('synaxarium_sources')->where('classification', 'saints_list')->count();
        $this->assertSame(13, $saintsSources);

        // 2. Entries verification: Exactly 366 entries (12 x 30 + Pagumen 6)
        $entriesCount = DB::table('synaxarium_entries')->count();
        $this->assertSame(366, $entriesCount);

        // 3. Daily saints sections: Exactly 366 sections
        $dailySaintsCount = DB::table('synaxarium_daily_saints')->count();
        $this->assertSame(366, $dailySaintsCount);

        // 4. Extracted saints commemorations count
        $saintsCount = DB::table('synaxarium_saints')->count();
        $this->assertGreaterThanOrEqual(850, $saintsCount);

        // 5. Test retrieval for all 12 Ethiopian months
        for ($m = 1; $m <= 12; $m++) {
            $entry = Synaxarium::getEntry($m, 1);
            $this->assertNotNull($entry);
            $this->assertSame($m, $entry['month']);
            $this->assertSame(1, $entry['day']);
            $this->assertNotEmpty($entry['title']);
            $this->assertNotEmpty($entry['body_am']);
            $this->assertNotNull($entry['daily_saints']);
            $this->assertNotEmpty($entry['daily_saints']['section_text_clean']);
        }

        // 6. Test Pagumen 5 & Pagumen 6 calendar conditions
        $pag5 = Synaxarium::getEntry(13, 5, 2017);
        $this->assertSame(13, $pag5['month']);
        $this->assertSame(5, $pag5['day']);
        $this->assertNull($pag5['leap_year_info']);

        // Pagumen 6 in common year (2017 E.C.)
        $this->assertFalse(EthiopianCalendar::isLeapYear(2017));
        $pag6Common = Synaxarium::getEntry(13, 6, 2017);
        $this->assertNotNull($pag6Common['leap_year_info']);
        $this->assertTrue($pag6Common['leap_year_info']['is_leap_year_day']);
        $this->assertFalse($pag6Common['leap_year_info']['is_valid_for_year']);
        $this->assertStringContainsString('፭ ቀናት ብቻ', $pag6Common['leap_year_info']['note']);

        // Pagumen 6 in leap year (2015 E.C.)
        $this->assertTrue(EthiopianCalendar::isLeapYear(2015));
        $pag6Leap = Synaxarium::getEntry(13, 6, 2015);
        $this->assertNotNull($pag6Leap['leap_year_info']);
        $this->assertTrue($pag6Leap['leap_year_info']['is_leap_year_day']);
        $this->assertTrue($pag6Leap['leap_year_info']['is_valid_for_year']);
        $this->assertStringContainsString('በዘመነ ዮሐንስ', $pag6Leap['leap_year_info']['note']);

        // 7. Verify Nehase 15 & Nehase 16 separation
        $neh15 = Synaxarium::getEntry(12, 15);
        $this->assertSame(12, $neh15['month']);
        $this->assertSame(15, $neh15['day']);

        $neh16 = Synaxarium::getEntry(12, 16);
        $this->assertSame(12, $neh16['month']);
        $this->assertSame(16, $neh16['day']);

        $this->assertNotSame($neh15['id'], $neh16['id']);
        $this->assertNotSame($neh15['title'], $neh16['title']);
        $this->assertNotSame($neh15['body_am'], $neh16['body_am']);
        $this->assertNotNull($neh15['daily_saints']);
        $this->assertNotNull($neh16['daily_saints']);
        $this->assertNotSame($neh15['daily_saints']['id'], $neh16['daily_saints']['id']);

        // 8. Editorial verification policy: Default strictly to false
        $verifiedEntriesCount = DB::table('synaxarium_entries')->where('is_editorially_verified', true)->count();
        $this->assertSame(0, $verifiedEntriesCount, 'Imported entries must default to is_editorially_verified = false');

        $statusCount = DB::table('synaxarium_entries')->where('editorial_status', 'imported')->count();
        $this->assertSame(366, $statusCount, 'All imported entries must have editorial_status = imported');

        $verifiedDailySaintsCount = DB::table('synaxarium_daily_saints')->where('is_editorially_verified', true)->count();
        $this->assertSame(0, $verifiedDailySaintsCount, 'Imported daily saints must default to is_editorially_verified = false');

        $verifiedSaintsCount = DB::table('synaxarium_saints')->where('is_editorially_verified', true)->count();
        $this->assertSame(0, $verifiedSaintsCount, 'Imported saints must default to is_editorially_verified = false');

        // 9. Legacy Sinksar API compatibility adapter (fallback)
        DB::table('sinksar_narratives')->where('ethiopian_month', 1)->where('ethiopian_day', 1)->delete();

        $mockRecord = (object) [
            'id' => 101,
            'gregorian_date' => '2026-09-11',
            'ethiopian_date' => '2019-01-01',
            'ethiopian_year' => 2019,
            'ethiopian_month' => 1,
            'ethiopian_day' => 1,
            'month_name_am' => 'መስከረም',
            'weekday_am' => 'ዓርብ',
            'weekday_en' => 'Friday',
            'is_fasting' => false,
            'fasting_reason' => null,
            'featured_title' => 'ርዕሰ ዐውደ ዓመት ዮሐንስ መጥምቅ',
            'summary' => 'ቅዱስ ዮሐንስ መጥምቅ',
            'annual_feasts' => json_encode([['id' => '1', 'title' => 'ርዕሰ ዐውደ ዓመት']]),
            'monthly_feasts' => json_encode([['id' => '1', 'title' => 'ልደታ']]),
            'full_text_available' => false,
            'refreshed_at' => now()->toIso8601String(),
        ];

        $info = [
            'ethiopian_month' => 1,
            'ethiopian_day' => 1,
            'ethiopian_year' => 2019,
        ];

        $formatted = Sinksar::formatRecord($mockRecord, $info);
        $expectedKeys = [
            'id', 'gregorian_date', 'ethiopian_date', 'ethiopian_year', 'ethiopian_month',
            'ethiopian_day', 'month_name_am', 'weekday_am', 'weekday_en', 'formatted_date',
            'formatted_full', 'is_fasting', 'fasting_reason', 'featured_title', 'summary',
            'annual_feasts', 'monthly_feasts', 'full_text_available', 'narratives',
            'has_narratives', 'refreshed_at'
        ];
        foreach ($expectedKeys as $k) {
            $this->assertArrayHasKey($k, $formatted, "Legacy key {$k} must be present in response");
        }

        $this->assertTrue($formatted['has_narratives']);
        $this->assertTrue($formatted['full_text_available']);
        $this->assertCount(1, $formatted['narratives']);
        $this->assertFalse($formatted['narratives'][0]['verified'], 'Fallback narrative must have verified = false');

        // 10. Legacy narrative precedence (custom narrative takes precedence)
        DB::table('sinksar_narratives')->insert([
            'ethiopian_month' => 1,
            'ethiopian_day' => 1,
            'title' => 'Custom Legacy Narrative for Meskerem 1',
            'source' => 'Church Synod Verified',
            'summary' => 'Ecclesiastical verified text',
            'body' => 'Full verified body of custom legacy narrative.',
            'verified' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $formattedWithPrecedence = Sinksar::formatRecord($mockRecord, $info);
        $this->assertTrue($formattedWithPrecedence['has_narratives']);
        $this->assertCount(1, $formattedWithPrecedence['narratives']);
        $this->assertSame('Custom Legacy Narrative for Meskerem 1', $formattedWithPrecedence['narratives'][0]['title']);
        $this->assertSame('Church Synod Verified', $formattedWithPrecedence['narratives'][0]['source']);
        $this->assertTrue($formattedWithPrecedence['narratives'][0]['verified']);

        DB::table('sinksar_narratives')->where('ethiopian_month', 1)->where('ethiopian_day', 1)->delete();

        // 11. Search verification
        $res = Synaxarium::search('ማርያም', 10);
        $this->assertSame('ማርያም', $res['query']);
        $this->assertGreaterThan(0, $res['entries_count']);
        $this->assertGreaterThan(0, $res['saints_count']);

        // 12. Idempotent import re-run
        $archivePath = 'c:\\Users\\HP\\Documents\\Downloads\\senkisar.zip';
        $exitCode = Artisan::call('synaxarium:import', ['path' => $archivePath]);
        $this->assertSame(Command::SUCCESS, $exitCode);

        $this->assertSame(366, DB::table('synaxarium_entries')->count());
        $this->assertSame(366, DB::table('synaxarium_daily_saints')->count());
    }
}
