<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Attendance;
use App\Mz\Services\Edu;
use App\Mz\Services\EduDashboard;
use App\Mz\Services\Payments;
use App\Mz\Services\Programs;
use App\Mz\Services\ReportExport;
use App\Mz\Services\Schedule;
use App\Mz\Services\Sinksar;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Ethiopian;
use App\Mz\Support\EthiopianCalendar;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class MasterImplementationVerificationTest extends TestCase
{
    private AuthContext $adminAuth;
    private AuthContext $memberAuth;
    private int $adminId = 1;
    private int $memberId = 20;
    private int $categoryId;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = new AuthContext();
        $this->adminAuth->id = $this->adminId;
        $this->adminAuth->fullName = 'Admin Tester';
        $this->adminAuth->status = 'active';
        $this->adminAuth->accountType = 'admin';
        $this->adminAuth->tokenVersion = 1;
        $this->adminAuth->isAdmin = true;
        $this->adminAuth->permissions = [
            'programs.manage' => true,
            'attendance.manage' => true,
            'attendance.take' => true,
            'attendance.view' => true,
            'attendance.reports' => true,
            'attendance.override' => true,
            'contributions.manage' => true,
            'contributions.view' => true,
            'education.manage' => true,
            'education.view' => true,
        ];

        $this->memberAuth = new AuthContext();
        $this->memberAuth->id = $this->memberId;
        $this->memberAuth->fullName = 'Member Tester';
        $this->memberAuth->status = 'active';
        $this->memberAuth->accountType = 'user';
        $this->memberAuth->tokenVersion = 1;
        $this->memberAuth->isAdmin = false;
        $this->memberAuth->permissions = [];

        $this->categoryId = DB::table('program_categories')->insertGetId([
            'name' => 'ጠቅላላ መርሐ ግብር',
            'name_en' => 'General Program',
            'color' => '#1A5276',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function setUpSchema(): void
    {
        Schema::dropIfExists('synaxarium_saints');
        Schema::dropIfExists('synaxarium_entries');
        Schema::dropIfExists('sinksar_narratives');
        Schema::dropIfExists('sinksar_records');
        Schema::dropIfExists('contribution_receipts');
        Schema::dropIfExists('payments');
        Schema::dropIfExists('payment_rates');
        Schema::dropIfExists('attendance_signatures');
        Schema::dropIfExists('attendance_closures');
        Schema::dropIfExists('attendance');
        Schema::dropIfExists('program_occurrence_overrides');
        Schema::dropIfExists('program_participants');
        Schema::dropIfExists('program_reminder_choices');
        Schema::dropIfExists('program_edu_classes');
        Schema::dropIfExists('program_edu_courses');
        Schema::dropIfExists('programs');
        Schema::dropIfExists('program_categories');
        Schema::dropIfExists('edu_enrollments');
        Schema::dropIfExists('edu_schedule');
        Schema::dropIfExists('edu_courses');
        Schema::dropIfExists('edu_subjects');
        Schema::dropIfExists('edu_curriculum_subjects');
        Schema::dropIfExists('edu_classes');
        Schema::dropIfExists('edu_levels');
        Schema::dropIfExists('edu_academic_years');
        Schema::dropIfExists('roles');
        Schema::dropIfExists('audit_logs');
        Schema::dropIfExists('settings');
        Schema::dropIfExists('users');

        Schema::create('audit_logs', function ($table) {
            $table->id();
            $table->unsignedBigInteger('actor_id')->nullable();
            $table->boolean('is_hidden')->default(false);
            $table->string('action');
            $table->string('entity_type')->nullable();
            $table->unsignedBigInteger('entity_id')->nullable();
            $table->text('metadata')->nullable();
            $table->string('ip')->nullable();
            $table->text('user_agent')->nullable();
            $table->timestamps();
        });

        Schema::create('settings', function ($table) {
            $table->id();
            $table->string('key')->unique();
            $table->text('value')->nullable();
            $table->string('type')->default('string');
            $table->timestamps();
        });

        Schema::create('roles', function ($table) {
            $table->id();
            $table->string('name', 100);
            $table->boolean('is_hidden')->default(false);
            $table->timestamps();
        });

        Schema::create('users', function ($table) {
            $table->increments('id');
            $table->string('username', 50)->nullable();
            $table->string('full_name', 150);
            $table->string('phone', 30)->nullable();
            $table->string('email', 150)->nullable();
            $table->string('member_no', 30)->nullable();
            $table->string('member_group', 30)->default('youth_adult');
            $table->string('member_type', 30)->default('student');
            $table->string('account_type', 30)->default('user');
            $table->unsignedInteger('role_id')->nullable();
            $table->string('status', 30)->default('active');
            $table->string('membership_status', 30)->default('active');
            $table->string('profile_image', 255)->nullable();
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('program_categories', function ($table) {
            $table->id();
            $table->string('name');
            $table->string('name_en')->nullable();
            $table->string('color', 16)->default('#333333');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        Schema::create('programs', function ($table) {
            $table->increments('id');
            $table->string('title', 255);
            $table->text('description')->nullable();
            $table->string('location', 255)->nullable();
            $table->dateTime('starts_at');
            $table->dateTime('ends_at')->nullable();
            $table->boolean('has_end_time')->default(true);
            $table->boolean('requires_registration')->default(false);
            $table->boolean('requires_attendance')->default(true);
            $table->integer('capacity')->nullable();
            $table->string('audience', 50)->default('all');
            $table->string('event_type', 50)->nullable();
            $table->string('status', 20)->default('draft');
            $table->boolean('reminder_enabled')->default(true);
            $table->integer('reminder_days_before')->default(1);
            $table->boolean('is_mandatory_reminder')->default(false);
            $table->integer('reminder_interval_days')->nullable();
            $table->date('reminder_interval_start')->nullable();
            $table->string('reminder_title', 255)->nullable();
            $table->text('reminder_body')->nullable();
            $table->string('reminder_offsets', 100)->nullable();
            $table->string('recurrence', 50)->default('once');
            $table->string('monthly_rule', 50)->nullable();
            $table->text('ordinal_weeks')->nullable();
            $table->text('recurring_weekdays')->nullable();
            $table->date('recurrence_until')->nullable();
            $table->string('ethiopian_days', 100)->nullable();
            $table->boolean('is_additional')->default(false);
            $table->boolean('counts_for_selection')->default(true);
            $table->unsignedInteger('category_id')->nullable();
            $table->string('member_groups', 255)->nullable();
            $table->unsignedInteger('schedule_id')->nullable();
            $table->string('image', 255)->nullable();
            $table->unsignedInteger('created_by')->nullable();
            $table->unsignedInteger('updated_by')->nullable();
            $table->timestamps();
        });

        Schema::create('program_occurrence_overrides', function ($table) {
            $table->id();
            $table->foreignId('program_id');
            $table->date('occurrence_date');
            $table->string('action'); // 'suspended', 'cancelled', 'rescheduled', 'moved'
            $table->string('reason')->nullable();
            $table->dateTime('starts_at')->nullable();
            $table->dateTime('ends_at')->nullable();
            $table->string('new_location')->nullable();
            $table->foreignId('changed_by')->nullable();
            $table->timestamps();
            $table->unique(['program_id', 'occurrence_date']);
        });

        Schema::create('program_participants', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('program_id');
            $table->unsignedInteger('user_id');
            $table->string('status', 20)->default('registered');
            $table->timestamps();
        });

        Schema::create('program_reminder_choices', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('program_id');
            $table->unsignedInteger('user_id');
            $table->string('offsets', 100);
            $table->timestamps();
        });

        Schema::create('attendance_closures', function ($table) {
            $table->id();
            $table->unsignedInteger('program_id');
            $table->date('occurrence_date');
            $table->dateTime('closed_at')->nullable();
            $table->unsignedInteger('closed_by')->nullable();
            $table->timestamps();
        });

        Schema::create('attendance', function ($table) {
            $table->id();
            $table->foreignId('program_id');
            $table->date('occurrence_date');
            $table->date('date')->nullable();
            $table->foreignId('user_id');
            $table->string('status')->default('present'); // present, late, absent, excused
            $table->string('punctuality')->default('on_time');
            $table->string('channel')->default('manual');
            $table->string('via')->default('manual');
            $table->unsignedBigInteger('signature_id')->nullable();
            $table->boolean('signature_exempt')->default(false);
            $table->text('notes')->nullable();
            $table->text('note')->nullable();
            $table->dateTime('attended_at')->nullable();
            $table->foreignId('session_id')->nullable();
            $table->foreignId('recorded_by')->nullable();
            $table->timestamps();
            $table->unique(['program_id', 'occurrence_date', 'user_id']);
        });

        Schema::create('attendance_signatures', function ($table) {
            $table->id();
            $table->foreignId('attendance_id')->unique();
            $table->string('signature_path');
            $table->timestamps();
        });

        Schema::create('payments', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('user_id');
            $table->string('period', 7);
            $table->unsignedInteger('months')->default(1);
            $table->string('coverage_end', 7);
            $table->string('member_type', 30)->nullable();
            $table->decimal('monthly_rate', 12, 2)->nullable();
            $table->decimal('amount', 12, 2);
            $table->string('payment_method', 30)->default('cash');
            $table->string('reference_no', 100)->nullable();
            $table->date('payment_date')->nullable();
            $table->string('status', 30)->default('completed');
            $table->unsignedInteger('recorded_by')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('payment_rates', function ($table) {
            $table->increments('id');
            $table->string('member_type', 30);
            $table->decimal('monthly_amount', 12, 2);
            $table->string('currency', 8)->default('ETB');
            $table->date('effective_from');
            $table->unsignedInteger('created_by')->nullable();
            $table->timestamps();
        });

        Schema::create('sinksar_records', function ($table) {
            $table->id();
            $table->unsignedTinyInteger('ethiopian_month');
            $table->unsignedTinyInteger('ethiopian_day');
            $table->string('month_name_am', 50)->nullable();
            $table->string('weekday_am', 50)->nullable();
            $table->string('weekday_en', 50)->nullable();
            $table->boolean('is_fasting')->default(false);
            $table->string('fasting_reason', 255)->nullable();
            $table->text('annual_feasts')->nullable();
            $table->text('monthly_feasts')->nullable();
            $table->text('summary')->nullable();
            $table->boolean('full_text_available')->default(false);
            $table->text('raw_payload')->nullable();
            $table->boolean('notification_sent')->default(false);
            $table->timestamp('refreshed_at')->nullable();
            $table->timestamps();
            $table->unique(['ethiopian_month', 'ethiopian_day']);
        });

        Schema::create('sinksar_narratives', function ($table) {
            $table->id();
            $table->unsignedTinyInteger('ethiopian_month');
            $table->unsignedTinyInteger('ethiopian_day');
            $table->string('title');
            $table->string('source')->nullable();
            $table->text('summary')->nullable();
            $table->longText('body');
            $table->boolean('verified')->default(false);
            $table->timestamps();
        });

        Schema::create('synaxarium_entries', function ($table) {
            $table->id();
            $table->unsignedTinyInteger('month');
            $table->unsignedTinyInteger('day');
            $table->string('title');
            $table->longText('body_am');
            $table->string('source_identifier')->nullable();
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->boolean('is_editorially_verified')->default(false);
            $table->timestamps();
        });

        Schema::create('synaxarium_saints', function ($table) {
            $table->id();
            $table->unsignedTinyInteger('month');
            $table->unsignedTinyInteger('day');
            $table->string('name');
            $table->unsignedSmallInteger('order_index')->default(0);
            $table->timestamps();
        });

        Schema::create('edu_academic_years', function ($table) {
            $table->id();
            $table->integer('eth_year');
            $table->string('name');
            $table->timestamps();
        });

        Schema::create('edu_classes', function ($table) {
            $table->id();
            $table->string('name');
            $table->foreignId('academic_year_id')->nullable();
            $table->foreignId('level_id')->nullable();
            $table->string('status', 20)->default('active');
            $table->timestamps();
        });

        Schema::create('edu_levels', function ($table) {
            $table->id();
            $table->string('code')->nullable();
            $table->string('name');
            $table->integer('sort_order')->default(0);
            $table->integer('sequence')->default(1);
            $table->timestamps();
        });

        Schema::create('edu_courses', function ($table) {
            $table->id();
            $table->string('name');
            $table->string('code')->nullable();
            $table->foreignId('class_id')->nullable();
            $table->timestamps();
        });

        Schema::create('edu_subjects', function ($table) {
            $table->id();
            $table->integer('grade')->default(1);
            $table->string('name');
            $table->string('code')->nullable();
            $table->integer('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('edu_enrollments', function ($table) {
            $table->id();
            $table->foreignId('user_id');
            $table->foreignId('class_id');
            $table->string('status')->default('active');
            $table->timestamps();
        });

        DB::table('users')->insert([
            ['id' => 1, 'full_name' => 'Admin Tester', 'status' => 'active', 'account_type' => 'admin', 'membership_status' => 'active', 'member_group' => 'youth_adult', 'member_type' => 'worker', 'created_at' => now(), 'updated_at' => now()],
            ['id' => 20, 'full_name' => 'Member Tester', 'status' => 'active', 'account_type' => 'user', 'membership_status' => 'active', 'member_group' => 'youth_adult', 'member_type' => 'student', 'created_at' => now(), 'updated_at' => now()],
        ]);

        DB::table('payment_rates')->insert([
            ['member_type' => 'student', 'monthly_amount' => 500.00, 'currency' => 'ETB', 'effective_from' => '2020-01-01', 'created_at' => now(), 'updated_at' => now()],
            ['member_type' => 'worker', 'monthly_amount' => 500.00, 'currency' => 'ETB', 'effective_from' => '2020-01-01', 'created_at' => now(), 'updated_at' => now()],
        ]);
    }

    public function test_first_and_third_sundays_and_second_and_fourth_saturdays(): void
    {
        // 1. First and third Sundays in November 2026: Nov 1 and Nov 15
        $p1 = (object) [
            'starts_at' => '2026-11-01 09:00:00',
            'ends_at' => '2026-11-01 11:00:00',
            'recurrence' => 'monthly',
            'monthly_rule' => 'nth_weekday',
            'ordinal_weeks' => '1,3',
            'recurring_weekdays' => '0', // Sunday
            '_overrides' => [],
        ];
        $occs1 = Schedule::between($p1, '2026-11-01', '2026-11-30');
        $dates1 = array_map(fn($o) => $o['date'], $occs1);
        $this->assertEquals(['2026-11-01', '2026-11-15'], $dates1);

        // 2. Second and fourth Saturdays in November 2026: Nov 14 and Nov 28
        $p2 = (object) [
            'starts_at' => '2026-11-01 09:00:00',
            'ends_at' => '2026-11-01 11:00:00',
            'recurrence' => 'monthly',
            'monthly_rule' => 'nth_weekday',
            'ordinal_weeks' => '2,4',
            'recurring_weekdays' => '6', // Saturday
            '_overrides' => [],
        ];
        $occs2 = Schedule::between($p2, '2026-11-01', '2026-11-30');
        $dates2 = array_map(fn($o) => $o['date'], $occs2);
        $this->assertEquals(['2026-11-14', '2026-11-28'], $dates2);
    }

    public function test_months_with_five_occurrences_and_no_duplicates(): void
    {
        // November 2026 has 5 Sundays (Nov 1, 8, 15, 22, 29)
        // Request 1st, 3rd, and 5th Sundays
        $p = (object) [
            'starts_at' => '2026-11-01 09:00:00',
            'ends_at' => '2026-11-01 11:00:00',
            'recurrence' => 'monthly',
            'monthly_rule' => 'nth_weekday',
            'ordinal_weeks' => '1,3,5',
            'recurring_weekdays' => '0',
            '_overrides' => [],
        ];
        $occs = Schedule::between($p, '2026-11-01', '2026-11-30');
        $dates = array_map(fn($o) => $o['date'], $occs);
        $this->assertEquals(['2026-11-01', '2026-11-15', '2026-11-29'], $dates);

        // Verify no duplicate occurrences
        $this->assertEquals(count($dates), count(array_unique($dates)));

        // Verify correct Ethiopian dates via previewSchedule
        $preview = Programs::previewSchedule([
            'recurrence' => 'monthly',
            'monthly_rule' => 'nth_weekday',
            'starts_at' => '2026-11-01 09:00:00',
            'ends_at' => '2026-11-01 11:00:00',
            'ordinal_weeks' => [1, 3, 5],
            'recurring_weekdays' => [0],
            'recurrence_until' => '2026-11-30',
        ]);
        $this->assertCount(3, $preview['occurrences']);
        $this->assertEquals('2026-11-01', $preview['occurrences'][0]['date']);
        $this->assertEquals('Sunday', $preview['occurrences'][0]['weekday_en']);
        $this->assertStringContainsString('2019', $preview['occurrences'][0]['ethiopian_date']);
    }

    public function test_program_suspension_persists_and_rejects_attendance(): void
    {
        // Tests Area 4
        $actx = ['auth' => $this->adminAuth];
        $today = Dates::todayLocal();

        $prog = Programs::create($actx, [
            'title' => 'Weekly Fellowship',
            'category_id' => $this->categoryId,
            'starts_at' => $today . ' 14:00:00',
            'ends_at' => $today . ' 16:00:00',
            'status' => 'published',
            'recurrence' => 'weekly',
        ]);

        $occurrenceDate = $today;

        // 1. Suspend the program for today
        $res = Programs::setOccurrence($actx, $prog['id'], $occurrenceDate, [
            'action' => 'suspended',
            'reason' => 'Church renovation',
        ]);
        $this->assertEquals('suspended', $res['action']);

        // Check override exists in database
        $override = DB::table('program_occurrence_overrides')
            ->where('program_id', $prog['id'])
            ->where('occurrence_date', $occurrenceDate)
            ->where('action', 'suspended')
            ->first();
        $this->assertNotNull($override);

        // 2. Attendance recording must be REJECTED with OCCURRENCE_SUSPENDED
        try {
            Attendance::record($actx, [
                'program_id' => $prog['id'],
                'date' => $occurrenceDate,
                'user_id' => $this->memberId,
                'status' => 'present',
            ]);
            $this->fail('Expected ApiError for OCCURRENCE_SUSPENDED');
        } catch (\Exception $e) {
            $this->assertInstanceOf(ApiError::class, $e);
            $this->assertEquals('OCCURRENCE_SUSPENDED', $e->errorCode);
        }

        // 3. Other dates must be UNAFFECTED
        $futureDate = Dates::addDays($today, 7);
        $futureRecorded = Attendance::record($actx, [
            'program_id' => $prog['id'],
            'date' => $futureDate,
            'user_id' => $this->memberId,
            'status' => 'present',
        ]);
        $this->assertEquals('present', $futureRecorded['status']);

        // 4. Unsuspend restores attendance recording capability for today
        $unsuspendRes = Programs::setOccurrence($actx, $prog['id'], $occurrenceDate, [
            'action' => 'unsuspend',
        ]);
        $this->assertEquals('restore', $unsuspendRes['action']);

        $recorded = Attendance::record($actx, [
            'program_id' => $prog['id'],
            'date' => $occurrenceDate,
            'user_id' => $this->memberId,
            'status' => 'present',
        ]);
        $this->assertEquals('present', $recorded['status']);
    }

    public function test_attendance_export_pdf_and_xlsx_validation(): void
    {
        // Tests Area 5 - Generate real XLSX and PDF
        $prog = Programs::create(['auth' => $this->adminAuth], [
            'title' => 'Sunday Liturgy',
            'category_id' => $this->categoryId,
            'starts_at' => '2026-11-01 07:00:00',
            'ends_at' => '2026-11-01 10:00:00',
            'status' => 'published',
            'recurrence' => 'once',
        ]);

        $attId = DB::table('attendance')->insertGetId([
            'program_id' => $prog['id'],
            'user_id' => $this->memberId,
            'occurrence_date' => '2026-11-01',
            'date' => '2026-11-01',
            'status' => 'present',
            'attended_at' => '2026-11-01 07:30:00',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('attendance_signatures')->insert([
            'attendance_id' => $attId,
            'signature_path' => 'signatures/test.png',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $actx = ['auth' => $this->adminAuth];

        // 1. Export XLSX
        $xlsx = ReportExport::export($actx, 'attendance', 'xlsx', ['program_id' => $prog['id']]);
        $this->assertNotEmpty($xlsx[0]); // Binary bytes
        $this->assertEquals('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', $xlsx[1]);
        $this->assertStringEndsWith('.xlsx', $xlsx[2]);
        file_put_contents(base_path('../scratch/attendance_audit_export.xlsx'), $xlsx[0]);

        // 2. Export PDF
        $pdf = ReportExport::export($actx, 'attendance', 'pdf', ['program_id' => $prog['id']]);
        $this->assertNotEmpty($pdf[0]);
        $this->assertEquals('application/pdf', $pdf[1]);
        $this->assertStringEndsWith('.pdf', $pdf[2]);
        $this->assertStringStartsWith('%PDF-', substr($pdf[0], 0, 5)); // Valid PDF header!
        file_put_contents(base_path('../scratch/attendance_audit_export.pdf'), $pdf[0]);
    }

    public function test_payments_yearly_contribution_summary(): void
    {
        // Tests Area 6
        // Insert payments for 2017 E.C.
        DB::table('payments')->insert([
            [
                'user_id' => $this->memberId,
                'period' => '2017-01',
                'months' => 1,
                'coverage_end' => '2017-01',
                'amount' => 500.00,
                'status' => 'completed',
                'payment_date' => '2024-09-15',
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'user_id' => $this->memberId,
                'period' => '2017-02',
                'months' => 1,
                'coverage_end' => '2017-02',
                'amount' => 500.00,
                'status' => 'completed',
                'payment_date' => '2024-10-15',
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);

        $summary = Payments::yearlyContributionSummary(['year' => 2017]);

        $this->assertEquals(2017, $summary['year']);
        $this->assertEquals(1000.00, $summary['total_collected_amount']);
        $this->assertCount(13, $summary['months']); // All 13 Ethiopian months
        $this->assertEquals('መስከረም', $summary['months'][0]['month_name_am']);
        $this->assertEquals(500.00, $summary['months'][0]['total_collected_amount']);
        $this->assertEquals('ጳጉሜን', $summary['months'][12]['month_name_am']);
    }

    public function test_sinksar_formatting_and_dit_sanitization(): void
    {
        // Tests Area 7 & 8
        $recordId = DB::table('sinksar_records')->insertGetId([
            'ethiopian_month' => 3, // Hidar
            'ethiopian_day' => 21,  // Tsion Mariam
            'month_name_am' => 'ኅዳር',
            'weekday_am' => 'እሑድ',
            'annual_feasts' => json_encode(['ማርያምdit*', 'ፅዮንd*']),
            'monthly_feasts' => json_encode([]),
            'full_text_available' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('sinksar_narratives')->insert([
            'ethiopian_month' => 3,
            'ethiopian_day' => 21,
            'title' => 'ቅድስት ድንግል ማርያምdit*',
            'body' => 'በዚህች ቀን የእግዚአብሔርንd* ድንቅ ሥራ እናከብራለንdit*።',
            'verified' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $rawRecord = DB::table('sinksar_records')->where('id', $recordId)->first();
        $rawRecord->gregorian_date = '2026-11-30';
        $rawRecord->ethiopian_date = '2019-03-21';
        $rawRecord->ethiopian_year = 2019;
        $rawRecord->fasting_reason = null;

        $calendarInfo = EthiopianCalendar::fromGregorian(2026, 11, 30);

        $formatted = Sinksar::formatRecord($rawRecord, $calendarInfo);

        $this->assertNotEmpty($formatted['narratives']);
        $this->assertStringNotContainsString('dit*', $formatted['narratives'][0]['title']);
        $this->assertStringNotContainsString('d*', $formatted['narratives'][0]['body']);
        $this->assertStringContainsString('ቅድስት ድንግል ማርያም', $formatted['narratives'][0]['title']);
        $this->assertStringContainsString('የእግዚአብሔርን ድንቅ ሥራ', $formatted['narratives'][0]['body']);

        // Check annual feasts sanitized
        $this->assertNotEmpty($formatted['annual_feasts']);
        $this->assertStringNotContainsString('dit*', $formatted['annual_feasts'][0]);
        $this->assertStringNotContainsString('d*', $formatted['annual_feasts'][1]);
    }

    public function test_sinksar_all_13_months_and_multiple_commemorations(): void
    {
        // Tests Area 7: Verify feast expansion for all 13 Ethiopian months (including Pagumen)
        for ($m = 1; $m <= 13; $m++) {
            $daysInMonth = ($m === 13) ? 5 : 30;
            $sampleRecord = (object) [
                'id' => $m,
                'ethiopian_month' => $m,
                'ethiopian_day' => 1,
                'month_name_am' => EthiopianCalendar::MONTHS_AM[$m],
                'weekday_am' => 'እሑድ',
                'weekday_en' => 'Sunday',
                'annual_feasts' => json_encode(['ቅዱስ ራጉኤል', 'ቅዱስ ዮሐንስ መጥምቅ']),
                'monthly_feasts' => json_encode([]),
                'summary' => null,
                'full_text_available' => false,
                'gregorian_date' => '2026-09-11',
                'ethiopian_date' => "2019-{$m}-01",
                'ethiopian_year' => 2019,
                'is_fasting' => false,
                'fasting_reason' => null,
                'refreshed_at' => null,
            ];
            $info = [
                'year' => 2019,
                'month' => $m,
                'day' => 1,
                'month_am' => EthiopianCalendar::MONTHS_AM[$m],
                'formatted' => "{$m} 1",
            ];
            $res = Sinksar::formatRecord($sampleRecord, $info);
            $this->assertEquals($m, $res['ethiopian_month']);
            $this->assertNotEmpty($res['annual_feasts']);
            $this->assertCount(2, $res['annual_feasts']); // Multiple commemorations preserved
        }
    }

    public function test_education_canonical_details_and_student_access_control(): void
    {
        // Tests Area 9 & 12
        $yearId = DB::table('edu_academic_years')->insertGetId(['eth_year' => 2019, 'name' => '2019 E.C.']);
        $levelId = DB::table('edu_levels')->insertGetId(['name' => 'ክፍል 7', 'code' => 'G07', 'sort_order' => 7, 'sequence' => 7]);
        $classId = DB::table('edu_classes')->insertGetId([
            'name' => 'ክፍል 7 - ሰንበት',
            'academic_year_id' => $yearId,
            'level_id' => $levelId,
            'status' => 'active',
        ]);

        // Enroll member 20 in Class 7
        DB::table('edu_enrollments')->insert([
            'user_id' => $this->memberId,
            'class_id' => $classId,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Add subjects for Grade 7 and Grade 10
        $sub7 = DB::table('edu_subjects')->insertGetId(['grade' => 7, 'name' => 'ነገረ ሃይማኖት 7', 'code' => 'G07-S01']);
        $sub10 = DB::table('edu_subjects')->insertGetId(['grade' => 10, 'name' => 'ነገረ ሃይማኖት 10', 'code' => 'G10-S01']);

        // Check studentAssignedGrades
        $assignedGrades = \App\Mz\Services\EduLearning::studentAssignedGrades($this->memberId);
        $this->assertEquals([7], $assignedGrades);
    }

    public function test_course_code_standardization(): void
    {
        // Tests Area 10
        $this->assertEquals('G01-S01', Edu::standardizeCourseCode(1, 1));
        $this->assertEquals('G03-S04', Edu::standardizeCourseCode(3, 4));
        $this->assertEquals('G12-S05', Edu::standardizeCourseCode(12, 5));
    }
}
