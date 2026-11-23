<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Attendance;
use App\Mz\Services\Programs;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EducationUnifiedAttendanceTest extends TestCase
{
    private AuthContext $adminAuth;
    private AuthContext $hrAuth;
    private AuthContext $unauthorizedAuth;
    private array $adminActx;
    private array $hrActx;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = $this->makeAuth(1, 'Super Admin', ['programs.manage' => true, 'attendance.manage' => true, 'education.manage' => true], 100);
        $this->hrAuth = $this->makeAuth(2, 'HR Officer', ['attendance.manage' => true, 'programs.manage' => true], 50);
        $this->unauthorizedAuth = $this->makeAuth(3, 'Regular Member', [], 10);

        $this->adminActx = ['auth' => $this->adminAuth, 'ip' => '127.0.0.1', 'userAgent' => 'PHPUnit', 'requestId' => 'req-1', 'source' => 'web', 'offset' => 0];
        $this->hrActx = ['auth' => $this->hrAuth, 'ip' => '127.0.0.1', 'userAgent' => 'PHPUnit', 'requestId' => 'req-2', 'source' => 'web', 'offset' => 0];
    }

    private function makeAuth(int $id, string $name, array $perms, int $level): AuthContext
    {
        $a = new AuthContext();
        $a->id = $id;
        $a->fullName = $name;
        $a->status = 'active';
        $a->accountType = $level >= 50 ? 'admin' : 'user';
        $a->tokenVersion = 1;
        $a->mustChangePassword = false;
        $a->isAdmin = $level >= 100;
        $a->isSystem = false;
        $a->isMemberStaff = false;
        $a->level = $level;
        $a->permissions = $perms;
        return $a;
    }

    private function setUpSchema(): void
    {
        Schema::dropIfExists('attendance_records');
        Schema::dropIfExists('attendance_sessions');
        Schema::dropIfExists('attendance_edu_classes');
        Schema::dropIfExists('attendance');
        Schema::dropIfExists('program_edu_courses');
        Schema::dropIfExists('program_edu_classes');
        Schema::dropIfExists('programs');
        Schema::dropIfExists('program_categories');
        Schema::dropIfExists('edu_enrollments');
        Schema::dropIfExists('edu_course_enrollments');
        Schema::dropIfExists('edu_courses');
        Schema::dropIfExists('edu_academic_years');
        Schema::dropIfExists('edu_levels');
        Schema::dropIfExists('edu_classes');
        Schema::dropIfExists('edu_subjects');
        Schema::dropIfExists('roles');
        Schema::dropIfExists('users');
        Schema::dropIfExists('audit_logs');
        Schema::dropIfExists('settings');

        DB::statement('CREATE TABLE edu_levels (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code VARCHAR(32) NOT NULL,
            name VARCHAR(100) NOT NULL
        )');

        DB::statement('CREATE TABLE edu_academic_years (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            eth_year INTEGER NOT NULL,
            name VARCHAR(100) NOT NULL
        )');

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
            payload TEXT NULL,
            ip VARCHAR(45) NULL,
            user_agent VARCHAR(255) NULL,
            request_id VARCHAR(64) NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        )');

        DB::statement('CREATE TABLE roles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(100) NOT NULL,
            is_hidden BOOLEAN NOT NULL DEFAULT 0
        )');

        DB::statement('CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name VARCHAR(100) NOT NULL,
            phone VARCHAR(20) NULL,
            status VARCHAR(20) NOT NULL DEFAULT "active",
            membership_status VARCHAR(20) NOT NULL DEFAULT "active",
            account_type VARCHAR(20) NOT NULL DEFAULT "user",
            role_id INTEGER NULL,
            member_group VARCHAR(20) NULL,
            created_at DATETIME NULL,
            deleted_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE program_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(100) NOT NULL,
            name_en VARCHAR(100) NULL,
            color VARCHAR(20) NULL,
            description TEXT NULL,
            is_active BOOLEAN NOT NULL DEFAULT 1,
            is_education BOOLEAN NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE program_participants (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            program_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            status VARCHAR(30) NOT NULL DEFAULT "registered"
        )');

        DB::statement('CREATE TABLE program_occurrence_overrides (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            program_id INTEGER NOT NULL,
            occurrence_date DATE NOT NULL,
            action VARCHAR(30) NOT NULL,
            starts_at DATETIME NULL,
            ends_at DATETIME NULL,
            reason VARCHAR(500) NULL,
            changed_by INTEGER NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE program_reminder_choices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            program_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            offsets VARCHAR(100) NULL
        )');

        DB::statement('CREATE TABLE attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            program_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            occurrence_date DATE NULL,
            date DATE NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT "present",
            punctuality VARCHAR(20) NOT NULL DEFAULT "on_time",
            channel VARCHAR(20) NOT NULL DEFAULT "manual",
            recorded_by INTEGER NOT NULL,
            note TEXT NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL,
            UNIQUE(program_id, user_id, date)
        )');

        DB::statement('CREATE TABLE programs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category_id INTEGER NULL,
            title VARCHAR(255) NOT NULL,
            description TEXT NULL,
            image VARCHAR(255) NULL,
            location VARCHAR(255) NULL,
            starts_at DATETIME NOT NULL,
            ends_at DATETIME NOT NULL,
            has_end_time BOOLEAN NOT NULL DEFAULT 0,
            reminder_offsets VARCHAR(100) NULL,
            requires_registration BOOLEAN NOT NULL DEFAULT 0,
            requires_attendance BOOLEAN NOT NULL DEFAULT 1,
            capacity INTEGER NULL,
            audience VARCHAR(50) NOT NULL DEFAULT "all",
            event_type VARCHAR(40) NULL,
            status VARCHAR(30) NOT NULL DEFAULT "draft",
            reminder_enabled BOOLEAN NOT NULL DEFAULT 1,
            reminder_days_before INTEGER NOT NULL DEFAULT 1,
            is_mandatory_reminder BOOLEAN NOT NULL DEFAULT 0,
            reminder_interval_days INTEGER NULL,
            reminder_interval_start INTEGER NULL,
            reminder_title VARCHAR(255) NULL,
            reminder_body VARCHAR(1000) NULL,
            recurrence VARCHAR(50) NOT NULL DEFAULT "once",
            monthly_rule VARCHAR(50) NULL,
            recurrence_until DATE NULL,
            ethiopian_days VARCHAR(60) NULL,
            is_additional BOOLEAN NOT NULL DEFAULT 0,
            counts_for_selection BOOLEAN NOT NULL DEFAULT 1,
            member_groups VARCHAR(60) NULL,
            schedule_id INTEGER NULL,
            created_by INTEGER NULL,
            updated_by INTEGER NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
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

        DB::statement('CREATE TABLE edu_classes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            level_id INTEGER NULL,
            academic_year_id INTEGER NULL,
            name VARCHAR(100) NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT "active"
        )');

        DB::statement('CREATE TABLE edu_subjects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(150) NOT NULL
        )');

        DB::statement('CREATE TABLE edu_courses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            class_id INTEGER NOT NULL,
            subject_id INTEGER NOT NULL,
            teacher_user_id INTEGER NULL,
            name VARCHAR(150) NOT NULL,
            member_groups VARCHAR(60) NULL
        )');

        DB::statement('CREATE TABLE edu_enrollments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            class_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            academic_year_id INTEGER NULL,
            status VARCHAR(20) NOT NULL DEFAULT "active"
        )');

        DB::statement('CREATE TABLE edu_course_enrollments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            course_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT "enrolled"
        )');



        DB::statement('CREATE TABLE attendance_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            program_id INTEGER NOT NULL,
            occurrence_date DATE NOT NULL,
            date DATE NULL,
            status VARCHAR(20) NOT NULL DEFAULT "active",
            started_at DATETIME NULL,
            ended_at DATETIME NULL,
            end_reason VARCHAR(50) NULL,
            opened_by INTEGER NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE attendance_closures (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            program_id INTEGER NOT NULL,
            occurrence_date DATE NOT NULL,
            closed_at DATETIME NOT NULL,
            closed_by INTEGER NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE attendance_edu_classes (
            attendance_id INTEGER NOT NULL,
            class_id INTEGER NOT NULL,
            course_id INTEGER NULL,
            PRIMARY KEY (attendance_id, class_id)
        )');
    }

    public function test_education_program_configuration_and_student_restriction(): void
    {
        // 1. Create education program category
        $catId = DB::table('program_categories')->insertGetId([
            'name' => 'የትምህርት መርሐግብር',
            'is_education' => 1,
            'is_active' => 1,
        ]);

        // 2. Create Class and Subject
        $classId = (int) DB::table('edu_classes')->insertGetId(['name' => 'ክፍል ፲']);
        $subjectId = (int) DB::table('edu_subjects')->insertGetId(['name' => 'ነገረ መለኮት']);
        $courseId = (int) DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => $subjectId,
            'name' => 'ነገረ መለኮት ፲',
        ]);

        // 3. Create Enrolled Student in class 10 and Unrelated Student
        $studentA = (int) DB::table('users')->insertGetId(['full_name' => 'Student A (Class 10)']);
        $studentB = (int) DB::table('users')->insertGetId(['full_name' => 'Student B (Unrelated)']);

        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => $studentA, 'status' => 'active']);

        // 4. Create Education Program linked to class and course
        $program = Programs::create($this->adminActx, [
            'title' => 'ቅዳሜ የነገረ መለኮት ትምህርት',
            'starts_at' => '2026-10-31 09:00:00',
            'category_id' => $catId,
            'status' => 'published',
            'class_ids' => [$classId],
            'course_ids' => [$courseId],
        ]);

        $this->assertSame('ቅዳሜ የነገረ መለኮት ትምህርት', $program['title']);
        $this->assertTrue($program['is_education']);
        $this->assertEquals([$classId], $program['class_ids']);
        $this->assertEquals([$courseId], $program['course_ids']);

        // 5. Check attendance expected members: MUST only include studentA, NOT studentB
        $progObj = (object) [
            'id' => $program['id'],
            'category_id' => $catId,
            'is_education' => 1,
            'target_audience' => 'all',
        ];
        $expectedQuery = Attendance::expectedMembers($progObj, '2026-10-31');
        $expectedUserIds = $expectedQuery->pluck('u.id')->all();

        $this->assertContains($studentA, $expectedUserIds);
        $this->assertNotContains($studentB, $expectedUserIds);

        // 6. HR records attendance
        $record = Attendance::record($this->hrActx, [
            'program_id' => $program['id'],
            'user_id' => $studentA,
            'date' => '2026-10-31',
            'status' => 'present',
            'punctuality' => 'on_time',
        ]);

        $this->assertSame('present', $record['status']);
        $this->assertSame($this->hrAuth->id, $record['recorded_by']);

        // 7. Duplicate submission updates rather than creating duplicate row
        $duplicateRecord = Attendance::record($this->hrActx, [
            'program_id' => $program['id'],
            'user_id' => $studentA,
            'date' => '2026-10-31',
            'status' => 'late',
            'punctuality' => 'late',
        ]);

        $this->assertSame('late', $duplicateRecord['status']);
        $count = DB::table('attendance')->where(['program_id' => $program['id'], 'user_id' => $studentA, 'date' => '2026-10-31'])->count();
        $this->assertSame(1, $count);

        // 8. Non-education program uses standard membership
        $generalCatId = DB::table('program_categories')->insertGetId([
            'name' => 'ጠቅላላ መርሐግብር',
            'is_education' => 0,
            'is_active' => 1,
        ]);
        $generalProg = Programs::create($this->adminActx, [
            'title' => 'አጠቃላይ የጸሎት መርሐግብር',
            'starts_at' => '2026-11-01 17:00:00',
            'category_id' => $generalCatId,
        ]);
        $this->assertFalse($generalProg['is_education']);
    }

    public function test_programs_attendance_auto_closure_at_scheduled_end(): void
    {
        $pastStart = Dates::now()->modify('-2 hours');
        $pastEnd = Dates::now()->modify('-15 minutes');
        $occurrenceDate = $pastStart->format('Y-m-d');

        $progId = DB::table('programs')->insertGetId([
            'title' => 'ተጠናቃሪ መርሐግብር',
            'starts_at' => Dates::sql($pastStart),
            'ends_at' => Dates::sql($pastEnd),
            'has_end_time' => 1,
            'requires_attendance' => 1,
            'status' => 'published',
            'recurrence' => 'once',
            'created_at' => Dates::sql($pastStart),
            'updated_at' => Dates::sql($pastStart),
        ]);

        $sessionId = DB::table('attendance_sessions')->insertGetId([
            'program_id' => $progId,
            'occurrence_date' => $occurrenceDate,
            'status' => 'active',
            'started_at' => Dates::sql($pastStart),
            'created_at' => Dates::sql($pastStart),
            'updated_at' => Dates::sql($pastStart),
        ]);

        // 1. Run closeExpiredSessions directly
        $closedCount = \App\Mz\Services\AttendanceSessions::closeExpiredSessions();
        $this->assertSame(1, $closedCount);

        // 2. Verify attendance session is marked ended with scheduled_end
        $session = DB::table('attendance_sessions')->where('id', $sessionId)->first();
        $this->assertSame('ended', $session->status);
        $this->assertSame('scheduled_end', $session->end_reason);
        $this->assertEquals(Dates::sql($pastEnd), $session->ended_at);

        // 3. Verify closure was recorded in attendance_closures for audit & historical record
        $closure = DB::table('attendance_closures')->where(['program_id' => $progId, 'occurrence_date' => $occurrenceDate])->first();
        $this->assertNotNull($closure);
        $this->assertEquals(Dates::sql($pastEnd), $closure->closed_at);
        $this->assertNull($closure->closed_by);

        // 4. Repeated invocation is idempotent
        $this->assertSame(0, \App\Mz\Services\AttendanceSessions::closeExpiredSessions());

        // 5. Verify mz:jobs entry runs smoothly
        $jobs = \App\Mz\Jobs\Jobs::all();
        $this->assertArrayHasKey('attendance:auto-close', $jobs);
        $jobResult = $jobs['attendance:auto-close'][1]();
        $this->assertSame(['closed_sessions' => 0], $jobResult);
    }
}

