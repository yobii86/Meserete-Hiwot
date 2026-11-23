<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Attendance;
use App\Mz\Services\ContributionReceipts;
use App\Mz\Services\Items;
use App\Mz\Services\Payments;
use App\Mz\Services\Programs;
use App\Mz\Services\Schedule;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class MasterFixesAttendanceBooksMediaSchedulingTest extends TestCase
{
    private AuthContext $adminAuth;
    private array $actx;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = new AuthContext();
        $this->adminAuth->id = 9999;
        $this->adminAuth->fullName = 'Admin Test';
        $this->adminAuth->accountType = 'admin';
        $this->adminAuth->isAdmin = true;
        $this->adminAuth->isSystem = true;
        $this->adminAuth->level = 100;
        $this->adminAuth->permissions = ['attendance.manage' => true, 'programs.manage' => true];
        $this->actx = [
            'auth' => $this->adminAuth,
            'ip' => '127.0.0.1',
            'userAgent' => 'PHPUnit',
        ];

        DB::table('settings')->delete();
        DB::table('settings')->insert([
            'key' => 'payments.policy',
            'value' => json_encode(['currency' => 'ETB', 'start_period' => null, 'grace_days' => 0]),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function setUpSchema(): void
    {
        if (! Schema::hasTable('settings')) {
            Schema::create('settings', function ($table) {
                $table->id();
                $table->string('key')->unique();
                $table->text('value')->nullable();
                $table->unsignedBigInteger('updated_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('departments')) {
            Schema::create('departments', function ($table) {
                $table->id();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('item_categories')) {
            Schema::create('item_categories', function ($table) {
                $table->id();
                $table->string('key')->unique();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('users')) {
            Schema::create('users', function ($table) {
                $table->id();
                $table->string('email')->nullable();
                $table->string('full_name');
                $table->string('phone')->nullable();
                $table->string('member_no')->nullable();
                $table->string('member_type')->nullable();
                $table->string('member_group')->nullable();
                $table->string('account_type')->default('user');
                $table->string('status')->default('active');
                $table->string('membership_status')->default('active');
                $table->softDeletes();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('program_categories')) {
            Schema::create('program_categories', function ($table) {
                $table->id();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->string('color')->nullable();
                $table->boolean('is_active')->default(true);
                $table->integer('display_order')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('program_occurrence_overrides')) {
            Schema::create('program_occurrence_overrides', function ($table) {
                $table->id();
                $table->unsignedBigInteger('program_id');
                $table->date('occurrence_date');
                $table->string('action');
                $table->dateTime('starts_at')->nullable();
                $table->dateTime('ends_at')->nullable();
                $table->string('reason')->nullable();
                $table->unsignedBigInteger('changed_by')->nullable();
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
                $table->boolean('has_end_time')->default(true);
                $table->string('recurrence')->default('once');
                $table->string('monthly_rule')->nullable();
                $table->date('recurrence_until')->nullable();
                $table->string('ethiopian_days')->nullable();
                $table->string('audience')->default('all');
                $table->string('location')->nullable();
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
                $table->string('via')->nullable();
                $table->text('notes')->nullable();
                $table->dateTime('attended_at')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('books')) {
            Schema::create('books', function ($table) {
                $table->id();
                $table->string('title');
                $table->string('category')->default('books');
                $table->string('kind')->default('physical');
                $table->string('author')->nullable();
                $table->integer('total_quantity')->default(1);
                $table->integer('available_quantity')->default(1);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('items')) {
            Schema::create('items', function ($table) {
                $table->id();
                $table->unsignedBigInteger('department_id')->nullable();
                $table->string('title');
                $table->string('name')->nullable();
                $table->string('category')->default('equipment');
                $table->string('kind')->default('physical');
                $table->unsignedBigInteger('library_category_id')->nullable();
                $table->softDeletes();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('payment_rates')) {
            Schema::create('payment_rates', function ($table) {
                $table->id();
                $table->string('member_type');
                $table->decimal('monthly_amount', 10, 2);
                $table->string('currency')->default('ETB');
                $table->date('effective_from');
                $table->unsignedBigInteger('created_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('payments')) {
            Schema::create('payments', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->string('period');
                $table->integer('months')->default(1);
                $table->string('coverage_end')->nullable();
                $table->string('member_type')->nullable();
                $table->decimal('monthly_rate', 10, 2)->nullable();
                $table->decimal('amount', 10, 2)->default(0);
                $table->string('currency')->default('ETB');
                $table->string('method')->default('cash');
                $table->string('reference')->nullable();
                $table->date('paid_on')->nullable();
                $table->string('receipt')->nullable();
                $table->text('note')->nullable();
                $table->string('status')->default('recorded');
                $table->unsignedBigInteger('recorded_by')->nullable();
                $table->unsignedBigInteger('verified_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('contribution_receipts')) {
            Schema::create('contribution_receipts', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->string('period');
                $table->integer('months')->default(1);
                $table->string('coverage_end')->nullable();
                $table->decimal('expected_amount', 10, 2)->default(0);
                $table->decimal('submitted_amount', 10, 2)->default(0);
                $table->string('currency')->default('ETB');
                $table->string('method')->default('bank');
                $table->string('reference')->nullable();
                $table->date('paid_on')->nullable();
                $table->string('receipt_path')->nullable();
                $table->text('member_note')->nullable();
                $table->string('status')->default('submitted');
                $table->text('review_note')->nullable();
                $table->dateTime('reviewed_at')->nullable();
                $table->unsignedBigInteger('payment_id')->nullable();
                $table->timestamps();
            });
        }
    }

    public function testPastProgramAttendanceIsBlocked(): void
    {
        $progId = DB::table('programs')->insertGetId([
            'title' => 'Sunday Service',
            'starts_at' => '2026-01-01 08:00:00',
            'ends_at' => '2026-01-01 10:00:00',
            'status' => 'published',
            'requires_attendance' => 1,
            'audience' => 'all',
        ]);

        $userId = DB::table('users')->insertGetId([
            'full_name' => 'Test User',
            'member_type' => 'worker',
            'member_group' => 'choir',
            'status' => 'active',
            'membership_status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $pastDate = '2026-01-01';

        try {
            Attendance::record($this->actx, [
                'program_id' => $progId,
                'user_id' => $userId,
                'date' => $pastDate,
                'status' => 'present',
            ]);
            $this->fail('Expected PAST_PROGRAM_ATTENDANCE_BLOCKED on record()');
        } catch (ApiError $e) {
            $this->assertSame('PAST_PROGRAM_ATTENDANCE_BLOCKED', $e->errorCode);
        }

        try {
            Attendance::set($this->actx, $progId, $userId, [
                'date' => $pastDate,
                'status' => 'present',
            ]);
            $this->fail('Expected PAST_PROGRAM_ATTENDANCE_BLOCKED on set()');
        } catch (ApiError $e) {
            $this->assertSame('PAST_PROGRAM_ATTENDANCE_BLOCKED', $e->errorCode);
        }

        try {
            Attendance::bulkSet($this->actx, $progId, [
                'date' => $pastDate,
                'user_ids' => [$userId],
                'status' => 'excused',
                'notes' => 'Medical leave',
            ], true);
            $this->fail('Expected PAST_PROGRAM_ATTENDANCE_BLOCKED on bulkSet()');
        } catch (ApiError $e) {
            $this->assertSame('PAST_PROGRAM_ATTENDANCE_BLOCKED', $e->errorCode);
        }
    }

    public function testPhysicalBooksTableSeparationAndItemsExclusion(): void
    {
        $bookId = DB::table('books')->insertGetId([
            'title' => 'Dersane Michael',
            'category' => 'books',
            'kind' => 'physical',
            'total_quantity' => 5,
            'available_quantity' => 5,
        ]);

        $itemId = DB::table('items')->insertGetId([
            'title' => 'Microphone Shure SM58',
            'name' => 'Microphone Shure SM58',
            'category' => 'sound',
            'kind' => 'physical',
            'library_category_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // 1. Items list must NOT contain the book
        $items = Items::list([], ['limit' => 50, 'offset' => 0, 'page' => 1]);
        $itemNames = array_column($items['items'], 'name');
        $this->assertContains('Microphone Shure SM58', $itemNames);
        $this->assertNotContains('Dersane Michael', $itemNames);

        // 2. Creating a book as a generic item must be rejected
        try {
            Items::create($this->actx, [
                'title' => 'New Hymn Book',
                'category' => 'books',
                'kind' => 'physical',
            ]);
            $this->fail('Expected BOOKS_NOT_GENERIC_ITEM');
        } catch (ApiError $e) {
            $this->assertSame('BOOKS_NOT_GENERIC_ITEM', $e->errorCode);
        }
    }

    public function testBiweeklyProgramRecurrence(): void
    {
        $program = (object) [
            'id' => 101,
            'starts_at' => '2026-11-01 09:00:00',
            'ends_at' => '2026-11-01 11:00:00',
            'recurrence' => 'biweekly',
            'recurrence_until' => '2026-12-31',
            '_overrides' => [],
        ];

        $occs = Schedule::between($program, '2026-11-01', '2026-11-30');
        $dates = array_column($occs, 'date');

        // Nov 1, Nov 15 (+14d), Nov 29 (+14d)
        $this->assertContains('2026-11-01', $dates);
        $this->assertContains('2026-11-15', $dates);
        $this->assertContains('2026-11-29', $dates);
        $this->assertNotContains('2026-11-08', $dates); // Nov 8 is weekly, not biweekly
        $this->assertCount(3, $dates);
    }

    public function testNonOverlappingProgramIntervals(): void
    {
        $catId = DB::table('program_categories')->insertGetId([
            'name' => 'General',
            'name_en' => 'General',
            'color' => '#C6A044',
            'is_active' => 1,
        ]);

        $existingId = DB::table('programs')->insertGetId([
            'title' => 'Morning Prayer',
            'starts_at' => '2026-11-25 09:00:00',
            'ends_at' => '2026-11-25 11:00:00',
            'category_id' => $catId,
            'has_end_time' => 1,
            'recurrence' => 'once',
            'status' => 'published',
            'location' => 'Main Hall',
        ]);

        // 1. Afternoon program on the same date (14:00 - 16:00) -> NO overlap
        $conflicts = Programs::checkOverlap([
            'starts_at' => '2026-11-25 14:00:00',
            'ends_at' => '2026-11-25 16:00:00',
            'recurrence' => 'once',
            'location' => 'Main Hall',
        ]);
        $this->assertEmpty($conflicts, 'Non-intersecting intervals on the same day must not conflict');

        // 2. Intersecting program (10:00 - 12:00) -> Overlap detected
        $conflictsOverlap = Programs::checkOverlap([
            'starts_at' => '2026-11-25 10:00:00',
            'ends_at' => '2026-11-25 12:00:00',
            'recurrence' => 'once',
            'location' => 'Main Hall',
        ]);
        $this->assertNotEmpty($conflictsOverlap, 'Intersecting intervals must conflict');
        $this->assertSame($existingId, $conflictsOverlap[0]['program_id']);
    }

    public function testMeskerem2019NotPayableAndReceiptRestriction(): void
    {
        $userId = DB::table('users')->insertGetId([
            'full_name' => 'Member Test',
            'member_type' => 'worker',
            'member_group' => 'choir',
            'status' => 'active',
            'membership_status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('payment_rates')->insert([
            'member_type' => 'worker',
            'monthly_amount' => 50.00,
            'currency' => 'ETB',
            'effective_from' => '2025-01-01',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // 1. Payments::record() for 2019-01 must throw MESKEREM_2019_NOT_PAYABLE
        try {
            Payments::record($this->actx, [
                'user_id' => $userId,
                'period' => '2019-01',
                'months' => 1,
                'method' => 'cash',
            ]);
            $this->fail('Expected MESKEREM_2019_NOT_PAYABLE on Payments::record');
        } catch (ApiError $e) {
            $this->assertSame('MESKEREM_2019_NOT_PAYABLE', $e->errorCode);
        }

        // 2. ContributionReceipts::calculateExpected() for 2019-01 must throw MESKEREM_2019_NOT_PAYABLE
        try {
            ContributionReceipts::calculateExpected($userId, '2019-01', 1);
            $this->fail('Expected MESKEREM_2019_NOT_PAYABLE on calculateExpected');
        } catch (ApiError $e) {
            $this->assertSame('MESKEREM_2019_NOT_PAYABLE', $e->errorCode);
        }
    }

    public function testYearSummaryReturnsStructuredPaidAndUnpaidMonths(): void
    {
        $userId = DB::table('users')->insertGetId([
            'full_name' => 'Year Summary Member',
            'member_type' => 'worker',
            'member_group' => 'choir',
            'status' => 'active',
            'membership_status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $res = Payments::forMember($userId);
        $this->assertArrayHasKey('year', $res);
        $year = $res['year'];
        $this->assertArrayHasKey('paid_months', $year);
        $this->assertArrayHasKey('unpaid_months', $year);
        $this->assertArrayHasKey('paid_month_details', $year);
        $this->assertArrayHasKey('unpaid_month_details', $year);

        // All 12 months unpaid initially
        $this->assertCount(12, $year['unpaid_month_details']);
        $this->assertSame('መስከረም', $year['unpaid_month_details'][0]['name']);
        $this->assertSame('ጥቅምት', $year['unpaid_month_details'][1]['name']);
    }
}
