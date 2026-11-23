<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Attendance;
use App\Mz\Services\AttendanceSessions;
use App\Mz\Services\Payments;
use App\Mz\Services\Programs;
use App\Mz\Services\Schedule;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Ethiopian;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class ProgramSuspensionAndContributionVerificationTest extends TestCase
{
    private AuthContext $adminAuth;
    private AuthContext $attendanceTakerAuth;
    private AuthContext $memberAuth;
    private int $programCategoryId;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = $this->makeAuth(1, 'Admin Abebe', ['programs.manage' => true, 'attendance.manage' => true, 'attendance.override' => true, 'contributions.manage' => true], true, 100);
        $this->attendanceTakerAuth = $this->makeAuth(2, 'Taker Chala', ['programs.manage' => true, 'attendance.take' => true], false, 50);
        $this->memberAuth = $this->makeAuth(10, 'Student Daniel', [], false, 0);

        $this->programCategoryId = DB::table('program_categories')->insertGetId([
            'name' => 'መደበኛ መርሐ ግብር',
            'name_en' => 'Regular Program',
            'color' => '#650D20',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function makeAuth(int $id, string $name, array $perms = [], bool $isAdmin = false, int $level = 0): AuthContext
    {
        $auth = new AuthContext();
        $auth->id = $id;
        $auth->fullName = $name;
        $auth->status = 'active';
        $auth->accountType = $isAdmin ? 'admin' : 'user';
        $auth->tokenVersion = 1;
        $auth->mustChangePassword = false;
        $auth->isAdmin = $isAdmin;
        $auth->isSystem = false;
        $auth->isMemberStaff = false;
        $auth->level = $level;
        $auth->permissions = $perms;
        return $auth;
    }

    private function setUpSchema(): void
    {
        Schema::dropIfExists('contribution_receipts');
        Schema::dropIfExists('payments');
        Schema::dropIfExists('payment_rates');
        Schema::dropIfExists('attendance_sessions');
        Schema::dropIfExists('attendance_closures');
        Schema::dropIfExists('attendance');
        Schema::dropIfExists('edu_enrollments');
        Schema::dropIfExists('edu_schedule');
        Schema::dropIfExists('edu_courses');
        Schema::dropIfExists('edu_classes');
        Schema::dropIfExists('edu_levels');
        Schema::dropIfExists('edu_academic_years');
        Schema::dropIfExists('program_occurrence_overrides');
        Schema::dropIfExists('program_participants');
        Schema::dropIfExists('program_reminder_choices');
        Schema::dropIfExists('program_edu_classes');
        Schema::dropIfExists('program_edu_courses');
        Schema::dropIfExists('programs');
        Schema::dropIfExists('program_categories');
        Schema::dropIfExists('users');
        Schema::dropIfExists('roles');
        Schema::dropIfExists('settings');
        Schema::dropIfExists('audit_logs');

        DB::statement('CREATE TABLE settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key VARCHAR(100) UNIQUE,
            value TEXT NULL,
            type VARCHAR(20) DEFAULT "string",
            description TEXT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        )');

        DB::statement('CREATE TABLE audit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            actor_id INTEGER NULL,
            user_id INTEGER NULL,
            is_hidden BOOLEAN DEFAULT 0,
            action VARCHAR(100) NOT NULL,
            entity_type VARCHAR(100) NULL,
            entity_id INTEGER NULL,
            metadata TEXT NULL,
            details TEXT NULL,
            ip VARCHAR(45) NULL,
            user_agent VARCHAR(255) NULL,
            request_id VARCHAR(64) NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        )');

        DB::statement('CREATE TABLE roles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(100) NOT NULL,
            is_hidden BOOLEAN DEFAULT 0
        )');

        DB::statement('CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name VARCHAR(150) NOT NULL,
            phone VARCHAR(30) NULL,
            email VARCHAR(150) NULL,
            member_no VARCHAR(30) NULL,
            member_group VARCHAR(30) DEFAULT "youth_adult",
            member_type VARCHAR(30) NULL,
            account_type VARCHAR(30) DEFAULT "user",
            role_id INTEGER NULL,
            status VARCHAR(30) DEFAULT "active",
            membership_status VARCHAR(30) DEFAULT "active",
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            deleted_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE program_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(100) NOT NULL,
            name_en VARCHAR(100) NULL,
            color VARCHAR(30) DEFAULT "#650D20",
            is_active BOOLEAN DEFAULT 1,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        )');

        DB::statement('CREATE TABLE programs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title VARCHAR(255) NOT NULL,
            description TEXT NULL,
            location VARCHAR(255) NULL,
            starts_at DATETIME NOT NULL,
            ends_at DATETIME NULL,
            has_end_time BOOLEAN DEFAULT 1,
            requires_registration BOOLEAN DEFAULT 0,
            requires_attendance BOOLEAN DEFAULT 1,
            capacity INTEGER NULL,
            audience VARCHAR(50) DEFAULT "all",
            event_type VARCHAR(50) NULL,
            status VARCHAR(20) DEFAULT "draft",
            reminder_enabled BOOLEAN DEFAULT 1,
            reminder_days_before INTEGER DEFAULT 1,
            is_mandatory_reminder BOOLEAN DEFAULT 0,
            reminder_interval_days INTEGER NULL,
            reminder_interval_start DATE NULL,
            reminder_title VARCHAR(255) NULL,
            reminder_body TEXT NULL,
            reminder_offsets VARCHAR(100) NULL,
            recurrence VARCHAR(50) DEFAULT "once",
            monthly_rule VARCHAR(50) NULL,
            recurrence_until DATE NULL,
            ethiopian_days VARCHAR(100) NULL,
            is_additional BOOLEAN DEFAULT 0,
            counts_for_selection BOOLEAN DEFAULT 1,
            category_id INTEGER NULL,
            member_groups VARCHAR(255) NULL,
            schedule_id INTEGER NULL,
            image VARCHAR(255) NULL,
            created_by INTEGER NULL,
            updated_by INTEGER NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL,
            deleted_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE program_participants (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            program_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT "registered",
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE program_reminder_choices (
            user_id INTEGER NOT NULL,
            program_id INTEGER NOT NULL,
            offsets VARCHAR(100) NULL,
            PRIMARY KEY (user_id, program_id)
        )');

        DB::statement('CREATE TABLE program_edu_classes (
            program_id INTEGER NOT NULL,
            class_id INTEGER NOT NULL,
            PRIMARY KEY (program_id, class_id)
        )');

        DB::statement('CREATE TABLE program_edu_courses (
            program_id INTEGER NOT NULL,
            course_id INTEGER NOT NULL,
            PRIMARY KEY (program_id, course_id)
        )');

        DB::statement('CREATE TABLE program_occurrence_overrides (
            program_id INTEGER NOT NULL,
            occurrence_date DATE NOT NULL,
            action VARCHAR(50) NOT NULL,
            starts_at DATETIME NULL,
            ends_at DATETIME NULL,
            reason TEXT NULL,
            changed_by INTEGER NULL,
            PRIMARY KEY (program_id, occurrence_date)
        )');

        DB::statement('CREATE TABLE edu_academic_years (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            eth_year INTEGER NOT NULL,
            name VARCHAR(100) NOT NULL,
            is_current BOOLEAN DEFAULT 0,
            status VARCHAR(20) DEFAULT "active",
            starts_at DATE NULL,
            ends_at DATE NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_levels (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code VARCHAR(50) NOT NULL,
            name VARCHAR(100) NOT NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_classes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(100) NOT NULL,
            academic_year_id INTEGER NULL,
            level_id INTEGER NULL,
            status VARCHAR(20) DEFAULT "active",
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_schedule (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            academic_year_id INTEGER NULL,
            class_id INTEGER NOT NULL,
            course_id INTEGER NULL,
            weekday INTEGER NOT NULL,
            starts VARCHAR(20) NOT NULL,
            ends VARCHAR(20) NOT NULL,
            location VARCHAR(255) NULL,
            frequency VARCHAR(50) DEFAULT "weekly",
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_enrollments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            academic_year_id INTEGER NULL,
            class_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            status VARCHAR(20) DEFAULT "active",
            program VARCHAR(50) DEFAULT "regular",
            enrolled_at DATETIME NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_courses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(150) NOT NULL,
            class_id INTEGER NOT NULL,
            teacher_user_id INTEGER NULL,
            member_groups VARCHAR(255) NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            program_id INTEGER NOT NULL,
            occurrence_date DATE NOT NULL,
            user_id INTEGER NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT "present",
            attended_at DATETIME NULL,
            elapsed_seconds INTEGER NULL,
            recorded_by INTEGER NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE (program_id, occurrence_date, user_id)
        )');

        DB::statement('CREATE TABLE attendance_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            program_id INTEGER NOT NULL,
            occurrence_date DATE NOT NULL,
            status VARCHAR(30) DEFAULT "active",
            started_at DATETIME NOT NULL,
            ended_at DATETIME NULL,
            started_by INTEGER NOT NULL,
            ended_by INTEGER NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE (program_id, occurrence_date)
        )');

        DB::statement('CREATE TABLE attendance_closures (
            program_id INTEGER NOT NULL,
            occurrence_date DATE NOT NULL,
            closed_at DATETIME NULL,
            closed_by INTEGER NULL,
            PRIMARY KEY (program_id, occurrence_date)
        )');

        DB::statement('CREATE TABLE payment_rates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            member_type VARCHAR(30) NOT NULL,
            monthly_amount DECIMAL(12, 2) NOT NULL,
            currency VARCHAR(8) DEFAULT "ETB",
            effective_from DATE NOT NULL,
            created_by INTEGER NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        )');

        DB::statement('CREATE TABLE payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            period VARCHAR(7) NOT NULL,
            months INTEGER DEFAULT 1,
            coverage_end VARCHAR(7) NOT NULL,
            member_type VARCHAR(30) NULL,
            monthly_rate DECIMAL(12, 2) NULL,
            amount DECIMAL(12, 2) NOT NULL,
            currency VARCHAR(8) DEFAULT "ETB",
            method VARCHAR(30) DEFAULT "cash",
            reference VARCHAR(120) NULL,
            paid_on DATE NOT NULL,
            receipt VARCHAR(255) NULL,
            receipt_path VARCHAR(255) NULL,
            note VARCHAR(500) NULL,
            status VARCHAR(30) DEFAULT "recorded",
            recorded_by INTEGER NULL,
            verified_by INTEGER NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        )');

        DB::statement('CREATE TABLE contribution_receipts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            period VARCHAR(7) NOT NULL,
            months INTEGER DEFAULT 1,
            coverage_end VARCHAR(7) NOT NULL,
            expected_amount DECIMAL(12, 2) NOT NULL,
            submitted_amount DECIMAL(12, 2) NOT NULL,
            currency VARCHAR(8) DEFAULT "ETB",
            method VARCHAR(30) DEFAULT "bank",
            reference VARCHAR(120) NULL,
            paid_on DATE NOT NULL,
            receipt_path VARCHAR(255) NOT NULL,
            member_note TEXT NULL,
            status VARCHAR(30) DEFAULT "submitted",
            reviewed_by INTEGER NULL,
            reviewed_at DATETIME NULL,
            rejection_reason TEXT NULL,
            payment_id INTEGER NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        )');

        DB::table('users')->insert([
            ['id' => 1, 'full_name' => 'Admin Abebe', 'account_type' => 'admin', 'member_type' => 'worker', 'status' => 'active'],
            ['id' => 2, 'full_name' => 'Taker Chala', 'account_type' => 'user', 'member_type' => 'worker', 'status' => 'active'],
            ['id' => 10, 'full_name' => 'Student Daniel', 'account_type' => 'user', 'member_type' => 'student', 'status' => 'active'],
        ]);
    }

    public function test_program_occurrence_suspension_trace_and_eligibility_exclusion(): void
    {
        $actx = ['auth' => $this->attendanceTakerAuth, 'ip' => '127.0.0.1', 'userAgent' => 'Test', 'requestId' => 'test-req', 'source' => 'mobile', 'offset' => 0];

        $today = Dates::todayLocal();
        $pastDate = date('Y-m-d', strtotime('-7 days', strtotime($today)));
        $date1 = $today;
        $date2 = date('Y-m-d', strtotime('+7 days', strtotime($today)));
        $recurrenceUntil = date('Y-m-d', strtotime('+10 days', strtotime($today)));

        // 1. Create a weekly program with occurrences starting 7 days ago
        $p = Programs::create(['auth' => $this->adminAuth], [
            'title' => 'ሳምንታዊ የመዝሙር ልምምድ (Weekly Choir)',
            'starts_at' => $pastDate . ' 14:00:00',
            'ends_at' => $pastDate . ' 16:00:00',
            'recurrence' => 'weekly',
            'recurrence_until' => $recurrenceUntil,
            'category_id' => $this->programCategoryId,
            'status' => 'published',
            'counts_for_selection' => true,
        ]);

        $programId = $p['id'];

        // Verify past occurrence rejection
        $pastRejected = false;
        try {
            Programs::setOccurrence($actx, $programId, $pastDate, ['action' => 'suspended', 'reason' => 'ያለፈ ቀን']);
        } catch (ApiError $e) {
            $pastRejected = true;
            $this->assertEquals('PAST_OCCURRENCE_CANNOT_BE_SUSPENDED', $e->errorCode);
        }
        $this->assertTrue($pastRejected, 'Suspending past occurrence must be rejected');

        // 2. Suspend today's occurrence
        $suspendResult = Programs::setOccurrence($actx, $programId, $date1, [
            'action' => 'suspended',
            'reason' => 'የበዓል ዝግጅት ምክንያት ተሰርዟል',
        ]);
        $this->assertNotEmpty($suspendResult);
        $this->assertTrue($suspendResult[0]['suspended']);
        $this->assertEquals('የበዓል ዝግጅት ምክንያት ተሰርዟል', $suspendResult[0]['reason']);
        $this->assertTrue($suspendResult['success']);

        // 3. Verify override storage
        $overrideRow = DB::table('program_occurrence_overrides')
            ->where('program_id', $programId)
            ->where('occurrence_date', $date1)
            ->first();
        $this->assertNotNull($overrideRow);
        $this->assertEquals('suspended', $overrideRow->action);
        $this->assertEquals('የበዓል ዝግጅት ምክንያት ተሰርዟል', $overrideRow->reason);

        // 4. Occurrence list includes cancelled/suspended with proper flag
        $pObj = DB::table('programs')->where('id', $programId)->first();
        Schedule::loadOverrides([$pObj]);
        $allOccurrences = Schedule::between($pObj, $date1, $recurrenceUntil, null, true);
        $this->assertCount(2, $allOccurrences);

        $occ1 = collect($allOccurrences)->firstWhere('date', $date1);
        $occ2 = collect($allOccurrences)->firstWhere('date', $date2);

        $this->assertTrue($occ1['suspended']);
        $this->assertFalse($occ2['suspended'] ?? false);

        // 5. Attendance Session Handling: Attempting to start session on suspended date MUST fail with PROGRAM_SUSPENDED
        $sessionFailed = false;
        try {
            AttendanceSessions::start($actx, $programId, $date1);
        } catch (ApiError $e) {
            $sessionFailed = true;
            $this->assertEquals('PROGRAM_SUSPENDED', $e->errorCode);
        }
        $this->assertTrue($sessionFailed, 'Starting an attendance session on a suspended occurrence must fail with PROGRAM_SUSPENDED');

        // 6. Member Attendance Calculations:
        // Set Daniel's user created_at to before the program
        DB::table('users')->where('id', 10)->update(['created_at' => '2026-10-01 00:00:00']);

        // Check member occurrences: Suspended occurrence is completely omitted!
        $memberOccs = Attendance::memberOccurrences(10, [
            'from' => $date1,
            'to' => $recurrenceUntil,
            'programIds' => [$programId],
        ]);
        $this->assertCount(1, $memberOccs, 'Suspended occurrence must be completely omitted from member expected occurrences');
        $this->assertEquals($date2, $memberOccs[0]['date']);

        // 7. Verify stats: Date 1 creates neither Present nor Absent records!
        // Member attends Date 2:
        DB::table('attendance')->insert([
            'program_id' => $programId,
            'occurrence_date' => $date2,
            'user_id' => 10,
            'status' => 'present',
            'attended_at' => $date2 . ' 14:10:00',
            'recorded_by' => 2,
        ]);

        $stats = Attendance::stats(10, [
            'from' => $date1,
            'to' => $recurrenceUntil,
            'programIds' => [$programId],
        ], Dates::of($recurrenceUntil . ' 23:59:59'));

        $this->assertEquals(1, $stats['total_programs'], 'Total past expected occurrences must be 1, because suspended occurrence is excluded');
        $this->assertEquals(1, $stats['attended'], 'Attended count must be 1');
        $this->assertEquals(0, $stats['absent'], 'Suspended occurrence must NOT count as absent');
        $this->assertEquals(100.0, (float) $stats['percentage'], 'Attendance rate must be 100% (1/1), not 50% (1/2)');

        // 8. Restore occurrence:
        $restoreResult = Programs::setOccurrence($actx, $programId, $date1, [
            'action' => 'restore',
        ]);
        $this->assertNotEmpty($restoreResult);
        $this->assertFalse($restoreResult[0]['suspended']);

        // Verify override record is cleaned up
        $restoredOverride = DB::table('program_occurrence_overrides')
            ->where('program_id', $programId)
            ->where('occurrence_date', $date1)
            ->first();
        $this->assertNull($restoredOverride);

        // Verify Date 1 is now back in active schedule
        $pObj2 = DB::table('programs')->where('id', $programId)->first();
        Schedule::loadOverrides([$pObj2]);
        $restoredOccs = Schedule::between($pObj2, $date1, $recurrenceUntil, null, false);
        $this->assertCount(2, $restoredOccs);
    }

    public function test_monthly_contribution_ordering_and_multi_month_calculation_for_hidar(): void
    {
        $actx = ['auth' => $this->adminAuth, 'ip' => '127.0.0.1', 'userAgent' => 'Test', 'requestId' => 'test-req', 'source' => 'web', 'offset' => 0];

        // 1. Setup rates: Student = 50 ETB, Worker = 100 ETB
        DB::table('payment_rates')->insert([
            ['member_type' => 'student', 'monthly_amount' => 50.00, 'currency' => 'ETB', 'effective_from' => '2026-09-11'],
            ['member_type' => 'worker', 'monthly_amount' => 100.00, 'currency' => 'ETB', 'effective_from' => '2026-09-11'],
        ]);

        // 2. Setup 4 Users:
        // User 20: Worker, Paid through Hidar 2019 (Meskerem 2019-01, Tikimt 2019-02, Hidar 2019-03)
        // User 21: Student, Paid only through Tikimt 2019 (Meskerem 2019-01, Tikimt 2019-02) -> Outstanding Hidar
        // User 22: Worker, Submitted receipt for 300 ETB with status = submitted (unverified pending)
        // User 23: Student, No payments recorded at all
        DB::table('users')->insert([
            ['id' => 20, 'full_name' => 'Abebe Worker (Paid Through)', 'member_no' => 'W-001', 'member_group' => 'group_a', 'member_type' => 'worker', 'account_type' => 'user', 'status' => 'active'],
            ['id' => 21, 'full_name' => 'Bekele Student (Partial Paid)', 'member_no' => 'S-001', 'member_group' => 'group_a', 'member_type' => 'student', 'account_type' => 'user', 'status' => 'active'],
            ['id' => 22, 'full_name' => 'Chaltu Worker (Pending Receipt)', 'member_no' => 'W-002', 'member_group' => 'group_b', 'member_type' => 'worker', 'account_type' => 'user', 'status' => 'active'],
            ['id' => 23, 'full_name' => 'Dawit Student (No Payment)', 'member_no' => 'S-002', 'member_group' => 'group_b', 'member_type' => 'student', 'account_type' => 'user', 'status' => 'active'],
        ]);

        // Record User 20 multi-month payment: 3 months from 2019-01 to 2019-03 (300 ETB)
        DB::table('payments')->insert([
            'user_id' => 20,
            'period' => '2019-01',
            'months' => 3,
            'coverage_end' => '2019-03',
            'member_type' => 'worker',
            'monthly_rate' => 100.00,
            'amount' => 300.00,
            'currency' => 'ETB',
            'method' => 'bank',
            'reference' => 'TXN-W001-3M',
            'paid_on' => '2026-11-01',
            'status' => 'recorded',
        ]);

        // Record User 21 multi-month payment: 2 months from 2019-01 to 2019-02 (100 ETB)
        DB::table('payments')->insert([
            'user_id' => 21,
            'period' => '2019-01',
            'months' => 2,
            'coverage_end' => '2019-02',
            'member_type' => 'student',
            'monthly_rate' => 50.00,
            'amount' => 100.00,
            'currency' => 'ETB',
            'method' => 'telebirr',
            'reference' => 'TXN-S001-2M',
            'paid_on' => '2026-10-15',
            'status' => 'recorded',
        ]);

        // User 22 submits receipt for 3 months (300 ETB), pending review
        DB::table('contribution_receipts')->insert([
            'user_id' => 22,
            'period' => '2019-01',
            'months' => 3,
            'coverage_end' => '2019-03',
            'expected_amount' => 300.00,
            'submitted_amount' => 300.00,
            'currency' => 'ETB',
            'method' => 'cbe_birr',
            'reference' => 'PENDING-REC-22',
            'paid_on' => '2026-11-02',
            'receipt_path' => 'private/receipts/22.jpg',
            'status' => 'submitted',
        ]);

        // 3. Query Detailed Contributions for Ethiopian Year 2019, Month 3 (ሕዳር 2019)
        $res = Payments::detailedContributions([
            'year' => 2019,
            'month' => 3,
        ], ['limit' => 50, 'page' => 1]);

        $this->assertCount(7, $res['items']); // 4 test users + 3 seeded users (admin, taker, daniel)
        $items = collect($res['items']);

        $u20 = $items->firstWhere('user_id', 20);
        $u21 = $items->firstWhere('user_id', 21);
        $u22 = $items->firstWhere('user_id', 22);
        $u23 = $items->firstWhere('user_id', 23);

        // User 20: Paid through Hidar
        $this->assertEquals('paid', $u20['status']);
        $this->assertEquals(1, $u20['priority']);
        $this->assertEquals(3, $u20['months_paid']);
        $this->assertEquals(0, $u20['months_unpaid']);
        $this->assertEquals(300.0, (float) $u20['total_paid']);
        $this->assertEquals(0.0, (float) $u20['outstanding']);

        // User 21: Partially paid through Tikimt (unpaid Hidar)
        $this->assertEquals('partial', $u21['status']);
        $this->assertEquals(2, $u21['priority']);
        $this->assertEquals(2, $u21['months_paid']);
        $this->assertEquals(1, $u21['months_unpaid']);
        $this->assertEquals(100.0, (float) $u21['total_paid']);
        $this->assertEquals(50.0, (float) $u21['outstanding']);

        // User 22: Pending receipt (NOT counted as paid)
        $this->assertEquals('pending', $u22['status']);
        $this->assertEquals(3, $u22['priority']);
        $this->assertEquals(0, $u22['months_paid']);
        $this->assertEquals(3, $u22['months_unpaid']);
        $this->assertEquals(0.0, (float) $u22['total_paid']);
        $this->assertEquals(300.0, (float) $u22['total_expected']);
        $this->assertEquals(300.0, (float) $u22['outstanding']);
        $this->assertTrue($u22['has_pending_receipt']);

        // User 23: No payment
        $this->assertEquals('unpaid', $u23['status']);
        $this->assertEquals(4, $u23['priority']);
        $this->assertEquals(0, $u23['months_paid']);
        $this->assertEquals(3, $u23['months_unpaid']);
        $this->assertEquals(150.0, (float) $u23['outstanding']);

        // 4. Verify exact ordering: Priority 1 (Paid through) -> Priority 2 (Partial) -> Priority 3 (Pending) -> Priority 4 (Unpaid)
        $orderedUserIds = array_column($res['items'], 'user_id');
        $pos20 = array_search(20, $orderedUserIds, true);
        $pos21 = array_search(21, $orderedUserIds, true);
        $pos22 = array_search(22, $orderedUserIds, true);
        $pos23 = array_search(23, $orderedUserIds, true);

        $this->assertLessThan($pos21, $pos20, 'User 20 (paid through) must appear before User 21 (partial)');
        $this->assertLessThan($pos22, $pos21, 'User 21 (partial) must appear before User 22 (pending receipt)');
        $this->assertLessThan($pos23, $pos22, 'User 22 (pending receipt) must appear before User 23 (unpaid)');

        // 5. Test Filters:
        // Filter by member_type = worker
        $workersRes = Payments::detailedContributions([
            'year' => 2019,
            'month' => 3,
            'member_type' => 'worker',
        ], ['limit' => 50, 'page' => 1]);
        $workerIds = array_column($workersRes['items'], 'user_id');
        $this->assertContains(20, $workerIds);
        $this->assertContains(22, $workerIds);
        $this->assertNotContains(21, $workerIds);
        $this->assertNotContains(23, $workerIds);

        // Filter by member_group = group_a
        $groupARes = Payments::detailedContributions([
            'year' => 2019,
            'month' => 3,
            'member_group' => 'group_a',
        ], ['limit' => 50, 'page' => 1]);
        $groupAIds = array_column($groupARes['items'], 'user_id');
        $this->assertContains(20, $groupAIds);
        $this->assertContains(21, $groupAIds);
        $this->assertNotContains(22, $groupAIds);
        $this->assertNotContains(23, $groupAIds);

        // Filter by status = partial
        $partialRes = Payments::detailedContributions([
            'year' => 2019,
            'month' => 3,
            'status' => 'partial',
        ], ['limit' => 50, 'page' => 1]);
        $partialIds = array_column($partialRes['items'], 'user_id');
        $this->assertEquals([21], $partialIds);
    }
}

