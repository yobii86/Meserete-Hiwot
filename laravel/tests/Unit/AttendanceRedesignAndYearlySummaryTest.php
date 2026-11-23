<?php

namespace Tests\Unit;

use App\Mz\Services\Attendance;
use App\Mz\Support\EthiopianCalendar;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class AttendanceRedesignAndYearlySummaryTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();
        DB::table('attendance')->delete();
        DB::table('programs')->delete();
        DB::table('users')->delete();
    }

    private function setUpSchema(): void
    {
        if (! Schema::hasTable('users')) {
            Schema::create('users', function ($table) {
                $table->id();
                $table->string('email')->nullable();
                $table->string('password')->nullable();
                $table->string('full_name');
                $table->string('phone')->nullable();
                $table->string('member_no')->nullable();
                $table->string('member_type')->nullable();
                $table->string('member_group')->nullable();
                $table->string('account_type')->default('user');
                $table->string('status')->default('active');
                $table->string('membership_status')->default('active');
                $table->string('profile_image')->nullable();
                $table->softDeletes();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('programs')) {
            Schema::create('programs', function ($table) {
                $table->id();
                $table->string('title');
                $table->string('status')->default('published');
                $table->boolean('requires_attendance')->default(true);
                $table->unsignedBigInteger('category_id')->nullable();
                $table->dateTime('starts_at')->nullable();
                $table->dateTime('ends_at')->nullable();
                $table->string('recurrence')->default('once');
                $table->string('monthly_rule')->nullable();
                $table->date('recurrence_until')->nullable();
                $table->string('ethiopian_days')->nullable();
                $table->string('audience')->default('all');
                $table->string('member_groups')->nullable();
                $table->boolean('is_additional')->default(false);
                $table->boolean('counts_for_selection')->default(true);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('program_categories')) {
            Schema::create('program_categories', function ($table) {
                $table->id();
                $table->string('name');
                $table->string('color')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('program_occurrences')) {
            Schema::create('program_occurrences', function ($table) {
                $table->id();
                $table->unsignedBigInteger('program_id');
                $table->date('occurrence_date');
                $table->boolean('is_suspended')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('attendance')) {
            Schema::create('attendance', function ($table) {
                $table->id();
                $table->unsignedBigInteger('program_id');
                $table->unsignedBigInteger('user_id');
                $table->date('occurrence_date');
                $table->string('status')->default('present');
                $table->dateTime('attended_at')->nullable();
                $table->unsignedBigInteger('recorded_by')->nullable();
                $table->unsignedBigInteger('signature_id')->nullable();
                $table->string('via')->default('manual');
                $table->text('notes')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('attendance_signatures')) {
            Schema::create('attendance_signatures', function ($table) {
                $table->id();
                $table->unsignedBigInteger('attendance_id');
                $table->string('path')->nullable();
                $table->timestamps();
            });
        }
    }

    public function test_yearly_summary_returns_thirteen_ethiopian_months_and_accurate_rates(): void
    {
        $year = 2019;
        $m1Date = EthiopianCalendar::toGregorian($year, 1, 10)->format('Y-m-d');
        $m2Date = EthiopianCalendar::toGregorian($year, 2, 15)->format('Y-m-d');

        $userId = DB::table('users')->insertGetId([
            'full_name' => 'Abebe Kebede',
            'phone' => '0911000001',
            'account_type' => 'user',
            'status' => 'active',
            'membership_status' => 'active',
            'member_group' => 'youth_adult',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $progId = DB::table('programs')->insertGetId([
            'title' => 'Sunday Service',
            'status' => 'published',
            'requires_attendance' => true,
            'starts_at' => "$m1Date 08:00:00",
            'ends_at' => "$m1Date 10:00:00",
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Insert present mark in month 1
        DB::table('attendance')->insert([
            'program_id' => $progId,
            'user_id' => $userId,
            'occurrence_date' => $m1Date,
            'status' => 'present',
            'attended_at' => "$m1Date 08:05:00",
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Insert absent mark in month 2
        DB::table('attendance')->insert([
            'program_id' => $progId,
            'user_id' => $userId,
            'occurrence_date' => $m2Date,
            'status' => 'absent',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $summary = Attendance::yearlySummary(['year' => $year]);

        $this->assertEquals($year, $summary['year']);
        $this->assertEquals(1, $summary['total_present']);
        $this->assertEquals(1, $summary['total_absent']);
        $this->assertEquals(2, $summary['total_expected']);
        $this->assertEquals(50.0, $summary['attendance_rate']);
        $this->assertCount(13, $summary['months']);

        // Check month 1 (Meskerem)
        $m1 = $summary['months'][0];
        $this->assertEquals(1, $m1['month']);
        $this->assertEquals('መስከረም', $m1['month_name_am']);
        $this->assertEquals(1, $m1['present']);
        $this->assertEquals(0, $m1['absent']);
        $this->assertEquals(100.0, $m1['attendance_rate']);

        // Check month 2 (Tikimt)
        $m2 = $summary['months'][1];
        $this->assertEquals(2, $m2['month']);
        $this->assertEquals('ጥቅምት', $m2['month_name_am']);
        $this->assertEquals(0, $m2['present']);
        $this->assertEquals(1, $m2['absent']);
        $this->assertEquals(0.0, $m2['attendance_rate']);

        // Check month 13 (Pagume)
        $m13 = $summary['months'][12];
        $this->assertEquals(13, $m13['month']);
        $this->assertEquals('ጳጉሜ', $m13['month_name_am']);
        $this->assertEquals(0, $m13['present']);
    }

    public function test_monthly_summary_and_by_program(): void
    {
        $year = 2019;
        $mDate = EthiopianCalendar::toGregorian($year, 3, 5)->format('Y-m-d');

        $userId = DB::table('users')->insertGetId([
            'full_name' => 'Chala Tadesse',
            'phone' => '0911000002',
            'account_type' => 'user',
            'status' => 'active',
            'membership_status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $progId = DB::table('programs')->insertGetId([
            'title' => 'Choir Practice',
            'status' => 'published',
            'requires_attendance' => true,
            'starts_at' => "$mDate 17:00:00",
            'ends_at' => "$mDate 19:00:00",
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('attendance')->insert([
            'program_id' => $progId,
            'user_id' => $userId,
            'occurrence_date' => $mDate,
            'status' => 'present',
            'attended_at' => "$mDate 17:02:00",
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $monthly = Attendance::monthlySummary(['year' => $year, 'month' => 3]);
        $this->assertEquals(3, $monthly['month']);
        $this->assertEquals('ኅዳር', $monthly['month_name_am']);
        $this->assertEquals(1, $monthly['present']);
        $this->assertEquals(100.0, $monthly['attendance_rate']);

        $byProg = Attendance::byProgram(['year' => $year]);
        $this->assertNotEmpty($byProg);
        $choirProg = collect($byProg)->firstWhere('id', $progId);
        $this->assertNotNull($choirProg);
        $this->assertEquals('Choir Practice', $choirProg['title']);
        $this->assertEquals(1, $choirProg['present_count']);
        $this->assertEquals(100.0, $choirProg['attendance_rate']);
    }

    public function test_member_profile_and_my_yearly_summary(): void
    {
        $year = 2019;
        $mDate = EthiopianCalendar::toGregorian($year, 1, 20)->format('Y-m-d');

        $userId = DB::table('users')->insertGetId([
            'full_name' => 'Sara Haile',
            'phone' => '0911000003',
            'account_type' => 'user',
            'status' => 'active',
            'membership_status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $progId = DB::table('programs')->insertGetId([
            'title' => 'Bible Study',
            'status' => 'published',
            'requires_attendance' => true,
            'starts_at' => "$mDate 18:00:00",
            'ends_at' => "$mDate 19:30:00",
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('attendance')->insert([
            'program_id' => $progId,
            'user_id' => $userId,
            'occurrence_date' => $mDate,
            'status' => 'present',
            'attended_at' => "$mDate 18:05:00",
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $profile = Attendance::adminMemberProfile($userId, $year);
        $this->assertEquals('Sara Haile', $profile['user']['full_name']);
        $this->assertEquals(1, $profile['total_present']);
        $this->assertEquals(100.0, $profile['attendance_rate']);
        $this->assertCount(13, $profile['months']);
        $this->assertNotEmpty($profile['recent_records']);

        $mySummary = Attendance::myYearlySummary($userId, $year);
        $this->assertEquals($profile['attendance_rate'], $mySummary['attendance_rate']);
    }
}
