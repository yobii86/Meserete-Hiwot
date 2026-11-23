<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\EduAttendance;
use App\Mz\Support\EthiopianCalendar;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EduAttendanceDashboardTest extends TestCase
{
    private AuthContext $adminAuth;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = new AuthContext();
        $this->adminAuth->id = 1;
        $this->adminAuth->fullName = 'Admin User';
        $this->adminAuth->status = 'active';
        $this->adminAuth->accountType = 'admin';
        $this->adminAuth->tokenVersion = 1;
        $this->adminAuth->isAdmin = true;
        $this->adminAuth->permissions = ['education.manage' => true, 'education.view' => true];
    }

    private function setUpSchema(): void
    {
        Schema::dropIfExists('attendance_signatures');
        Schema::dropIfExists('attendance_edu_classes');
        Schema::dropIfExists('attendance');
        Schema::dropIfExists('program_edu_courses');
        Schema::dropIfExists('program_edu_classes');
        Schema::dropIfExists('program_occurrences');
        Schema::dropIfExists('programs');
        Schema::dropIfExists('program_categories');
        Schema::dropIfExists('edu_enrollments');
        Schema::dropIfExists('edu_courses');
        Schema::dropIfExists('edu_classes');
        Schema::dropIfExists('edu_levels');
        Schema::dropIfExists('edu_academic_years');
        Schema::dropIfExists('users');

        DB::statement('CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name VARCHAR(100) NOT NULL,
            phone VARCHAR(20) NULL,
            member_no VARCHAR(50) NULL,
            member_group VARCHAR(50) NULL,
            member_type VARCHAR(50) NULL,
            profile_image VARCHAR(255) NULL,
            status VARCHAR(20) NOT NULL DEFAULT "active",
            membership_status VARCHAR(20) NOT NULL DEFAULT "active",
            account_type VARCHAR(20) NOT NULL DEFAULT "user"
        )');

        DB::statement('CREATE TABLE edu_academic_years (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            eth_year INTEGER NOT NULL,
            name VARCHAR(100) NOT NULL,
            is_current BOOLEAN DEFAULT 1
        )');

        DB::statement('CREATE TABLE edu_levels (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code VARCHAR(32) NOT NULL,
            name VARCHAR(100) NOT NULL
        )');

        DB::statement('CREATE TABLE edu_classes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(100) NOT NULL,
            level_id INTEGER NULL,
            academic_year_id INTEGER NULL,
            status VARCHAR(20) NOT NULL DEFAULT "active"
        )');

        DB::statement('CREATE TABLE edu_courses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            class_id INTEGER NOT NULL,
            name VARCHAR(150) NOT NULL
        )');

        DB::statement('CREATE TABLE edu_enrollments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            class_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT "active"
        )');

        DB::statement('CREATE TABLE program_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(100) NOT NULL,
            color VARCHAR(20) NULL,
            is_education BOOLEAN NOT NULL DEFAULT 1
        )');

        DB::statement('CREATE TABLE programs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category_id INTEGER NULL,
            title VARCHAR(255) NOT NULL,
            starts_at DATETIME NULL,
            ends_at DATETIME NULL,
            location VARCHAR(255) NULL,
            status VARCHAR(30) NOT NULL DEFAULT "published"
        )');

        DB::statement('CREATE TABLE program_occurrences (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            program_id INTEGER NOT NULL,
            occurrence_date DATE NOT NULL,
            is_suspended BOOLEAN NOT NULL DEFAULT 0
        )');

        DB::statement('CREATE TABLE program_edu_classes (
            program_id INTEGER NOT NULL,
            class_id INTEGER NOT NULL,
            PRIMARY KEY (program_id, class_id)
        )');

        DB::statement('CREATE TABLE attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            program_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            occurrence_date DATE NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT "present",
            punctuality VARCHAR(20) DEFAULT "on_time",
            via VARCHAR(20) DEFAULT "manual",
            recorded_by INTEGER NULL,
            signature_id INTEGER NULL,
            notes TEXT NULL,
            attended_at DATETIME NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE attendance_edu_classes (
            attendance_id INTEGER NOT NULL,
            class_id INTEGER NOT NULL,
            PRIMARY KEY (attendance_id, class_id)
        )');

        DB::statement('CREATE TABLE program_edu_courses (
            program_id INTEGER NOT NULL,
            course_id INTEGER NOT NULL,
            PRIMARY KEY (program_id, course_id)
        )');

        DB::statement('CREATE TABLE attendance_signatures (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            attendance_id INTEGER NOT NULL,
            path VARCHAR(255) NOT NULL
        )');
    }

    public function test_education_attendance_dashboard_computes_accurate_kpi_and_analytics(): void
    {
        $year = 2019;
        $m1Date = EthiopianCalendar::toGregorian($year, 1, 10)->format('Y-m-d');
        $m2Date = EthiopianCalendar::toGregorian($year, 2, 12)->format('Y-m-d');

        $student1 = DB::table('users')->insertGetId(['full_name' => 'Abebe Bekele', 'phone' => '0911111111', 'account_type' => 'user']);
        $student2 = DB::table('users')->insertGetId(['full_name' => 'Sara Daniel', 'phone' => '0922222222', 'account_type' => 'user']);

        $ayId = DB::table('edu_academic_years')->insertGetId(['eth_year' => $year, 'name' => "$year ዓ.ም", 'is_current' => 1]);
        $levelId = DB::table('edu_levels')->insertGetId(['code' => 'G10', 'name' => '10ኛ ክፍል']);
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'ክፍል 10-A', 'level_id' => $levelId, 'academic_year_id' => $ayId]);

        DB::table('edu_enrollments')->insert([
            ['class_id' => $classId, 'user_id' => $student1, 'status' => 'active'],
            ['class_id' => $classId, 'user_id' => $student2, 'status' => 'active'],
        ]);

        $catId = DB::table('program_categories')->insertGetId(['name' => 'የትምህርት መርሐግብር', 'color' => '#650D20', 'is_education' => 1]);
        $progId = DB::table('programs')->insertGetId(['category_id' => $catId, 'title' => 'ነገረ መለኮት ክፍል', 'status' => 'published']);

        DB::table('program_edu_classes')->insert(['program_id' => $progId, 'class_id' => $classId]);

        // Student 1: present in month 1, absent in month 2
        $a1 = DB::table('attendance')->insertGetId([
            'program_id' => $progId,
            'user_id' => $student1,
            'occurrence_date' => $m1Date,
            'status' => 'present',
            'attended_at' => "$m1Date 08:30:00",
        ]);
        DB::table('attendance_edu_classes')->insert(['attendance_id' => $a1, 'class_id' => $classId]);

        $a2 = DB::table('attendance')->insertGetId([
            'program_id' => $progId,
            'user_id' => $student1,
            'occurrence_date' => $m2Date,
            'status' => 'absent',
        ]);
        DB::table('attendance_edu_classes')->insert(['attendance_id' => $a2, 'class_id' => $classId]);

        // Student 2: present in month 1
        $a3 = DB::table('attendance')->insertGetId([
            'program_id' => $progId,
            'user_id' => $student2,
            'occurrence_date' => $m1Date,
            'status' => 'present',
            'attended_at' => "$m1Date 08:35:00",
        ]);
        DB::table('attendance_edu_classes')->insert(['attendance_id' => $a3, 'class_id' => $classId]);

        // Test dashboard query
        $data = EduAttendance::dashboard($this->adminAuth, ['year' => $year]);

        $this->assertEquals(2, $data['kpi']['total_students']);
        $this->assertEquals(2, $data['kpi']['total_sessions']);
        $this->assertEquals(2, $data['kpi']['present']);
        $this->assertEquals(1, $data['kpi']['absent']);
        $this->assertEquals(3, $data['kpi']['total_expected']);
        $this->assertEquals(66.7, $data['kpi']['attendance_rate']);

        // Check 13 months trend
        $this->assertCount(13, $data['analytics']['monthly_trends']);
        $m1 = $data['analytics']['monthly_trends'][0];
        $this->assertEquals(1, $m1['month']);
        $this->assertEquals('መስከረም', $m1['month_name_am']);
        $this->assertEquals(2, $m1['present']);
        $this->assertEquals(100.0, $m1['rate']);

        $m2 = $data['analytics']['monthly_trends'][1];
        $this->assertEquals(2, $m2['month']);
        $this->assertEquals('ጥቅምት', $m2['month_name_am']);
        $this->assertEquals(0, $m2['present']);
        $this->assertEquals(1, $m2['absent']);
        $this->assertEquals(0.0, $m2['rate']);

        // Check students performance
        $this->assertCount(2, $data['students_performance']);
        $s2 = collect($data['students_performance'])->firstWhere('id', $student2);
        $this->assertEquals(100.0, $s2['rate']);
        $this->assertEquals(1, $s2['present']);

        $s1 = collect($data['students_performance'])->firstWhere('id', $student1);
        $this->assertEquals(50.0, $s1['rate']);
        $this->assertEquals(1, $s1['present']);
        $this->assertEquals(1, $s1['absent']);
    }

    public function test_education_student_profile_and_record_detail(): void
    {
        $year = 2019;
        $date = EthiopianCalendar::toGregorian($year, 3, 5)->format('Y-m-d');

        $student = DB::table('users')->insertGetId(['full_name' => 'Dawit Yohannes', 'phone' => '0933333333', 'account_type' => 'user']);
        $ayId = DB::table('edu_academic_years')->insertGetId(['eth_year' => $year, 'name' => "$year ዓ.ም", 'is_current' => 1]);
        $levelId = DB::table('edu_levels')->insertGetId(['code' => 'G11', 'name' => '11ኛ ክፍል']);
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'ክፍል 11-B', 'level_id' => $levelId, 'academic_year_id' => $ayId]);

        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => $student, 'status' => 'active']);

        $catId = DB::table('program_categories')->insertGetId(['name' => 'የትምህርት መርሐግብር', 'color' => '#650D20', 'is_education' => 1]);
        $progId = DB::table('programs')->insertGetId(['category_id' => $catId, 'title' => 'የቤተክርስቲያን ታሪክ', 'status' => 'published']);

        $attId = DB::table('attendance')->insertGetId([
            'program_id' => $progId,
            'user_id' => $student,
            'occurrence_date' => $date,
            'status' => 'present',
            'attended_at' => "$date 09:10:00",
            'notes' => 'On time with book',
        ]);
        DB::table('attendance_edu_classes')->insert(['attendance_id' => $attId, 'class_id' => $classId]);
        DB::table('attendance_signatures')->insert(['attendance_id' => $attId, 'path' => 'signatures/sig_test.png']);

        $profile = EduAttendance::studentProfile($this->adminAuth, $student, ['year' => $year]);
        $this->assertEquals('Dawit Yohannes', $profile['student']['full_name']);
        $this->assertEquals('ክፍል 11-B', $profile['student']['class_name']);
        $this->assertEquals('11ኛ ክፍል', $profile['student']['grade_name']);
        $this->assertEquals(1, $profile['summary']['present_sessions']);
        $this->assertEquals(100.0, $profile['summary']['attendance_rate']);
        $this->assertCount(1, $profile['records']);
        $this->assertTrue($profile['records'][0]['has_signature']);
        $this->assertEquals('signed', $profile['records'][0]['signature_status']);

        // Check single record detail
        $detail = EduAttendance::recordDetail($this->adminAuth, $attId);
        $this->assertEquals($attId, $detail['id']);
        $this->assertEquals('Dawit Yohannes', $detail['student']['full_name']);
        $this->assertEquals('የቤተክርስቲያን ታሪክ', $detail['program']['title']);
        $this->assertTrue($detail['signature']['has_signature']);
        $this->assertEquals('signed', $detail['signature']['status']);
    }
}

