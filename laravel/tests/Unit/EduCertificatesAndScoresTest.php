<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Edu;
use App\Mz\Services\EduCertificates;
use App\Mz\Services\EduDashboard;
use App\Mz\Services\EduLearning;
use App\Mz\Services\EduOutcomes;
use App\Mz\Services\EduScores;
use App\Mz\Services\ReportExport;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EduCertificatesAndScoresTest extends TestCase
{
    private AuthContext $adminAuth;
    private AuthContext $certifierAuth;
    private AuthContext $reporterAuth;
    private AuthContext $studentAuth;
    private AuthContext $otherStudentAuth;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = $this->makeAuth(1, 'Admin Haile', ['education.manage' => true, 'reports.view' => true]);
        $this->certifierAuth = $this->makeAuth(2, 'Certifier Yohannes', ['education.certify' => true]);
        $this->reporterAuth = $this->makeAuth(3, 'Reporter Martha', ['education.reports' => true]);
        $this->studentAuth = $this->makeAuth(10, 'Student Abebe', []);
        $this->otherStudentAuth = $this->makeAuth(11, 'Student Kebede', []);
    }

    private function makeAuth(int $id, string $name, array $perms = []): AuthContext
    {
        $auth = new AuthContext();
        $auth->id = $id;
        $auth->fullName = $name;
        $auth->status = 'active';
        $auth->accountType = ! empty($perms['education.manage']) ? 'admin' : 'user';
        $auth->tokenVersion = 1;
        $auth->mustChangePassword = false;
        $auth->isAdmin = ! empty($perms['education.manage']);
        $auth->isSystem = false;
        $auth->isMemberStaff = false;
        $auth->level = ! empty($perms['education.manage']) ? 100 : 10;
        $auth->permissions = $perms;
        return $auth;
    }

    private function setUpSchema(): void
    {
        if (! Schema::hasTable('settings')) {
            Schema::create('settings', function ($table) {
                $table->id();
                $table->string('key')->unique();
                $table->text('value')->nullable();
                $table->string('type')->default('string');
                $table->text('description')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('users')) {
            Schema::create('users', function ($table) {
                $table->id();
                $table->string('full_name');
                $table->string('phone')->nullable();
                $table->string('member_no')->nullable();
                $table->string('member_group')->default('youth_adult');
                $table->string('status')->default('active');
                $table->string('account_type')->default('user');
                $table->softDeletes();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_academic_years')) {
            Schema::create('edu_academic_years', function ($table) {
                $table->id();
                $table->string('name');
                $table->integer('eth_year');
                $table->date('starts_on');
                $table->date('ends_on');
                $table->boolean('is_current')->default(false);
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_terms')) {
            Schema::create('edu_terms', function ($table) {
                $table->id();
                $table->unsignedBigInteger('academic_year_id');
                $table->string('name');
                $table->date('starts_on');
                $table->date('ends_on');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_levels')) {
            Schema::create('edu_levels', function ($table) {
                $table->id();
                $table->string('name');
                $table->integer('sequence')->default(1);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_categories')) {
            Schema::create('edu_categories', function ($table) {
                $table->id();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->text('description')->nullable();
                $table->string('slug')->nullable();
                $table->string('image')->nullable();
                $table->integer('sort_order')->default(0);
                $table->string('status')->default('published');
                $table->boolean('is_active')->default(true);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_subjects')) {
            Schema::create('edu_subjects', function ($table) {
                $table->id();
                $table->unsignedBigInteger('category_id')->nullable();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->string('slug')->nullable();
                $table->string('code')->nullable();
                $table->text('description')->nullable();
                $table->string('cover_image')->nullable();
                $table->string('visibility')->default('enrolled');
                $table->boolean('sequential')->default(false);
                $table->string('status')->default('published');
                $table->boolean('is_active')->default(true);
                $table->integer('sort_order')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_units')) {
            Schema::create('edu_units', function ($table) {
                $table->id();
                $table->unsignedBigInteger('subject_id');
                $table->string('title');
                $table->string('status')->default('published');
                $table->integer('sort_order')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lessons')) {
            Schema::create('edu_lessons', function ($table) {
                $table->id();
                $table->unsignedBigInteger('subject_id')->nullable();
                $table->unsignedBigInteger('unit_id')->nullable();
                $table->string('title');
                $table->string('title_en')->nullable();
                $table->text('summary')->nullable();
                $table->text('summary_en')->nullable();
                $table->text('body')->nullable();
                $table->string('video_url')->nullable();
                $table->integer('est_minutes')->nullable();
                $table->integer('duration_minutes')->nullable();
                $table->tinyInteger('is_mandatory')->default(1);
                $table->boolean('requires_quiz')->default(false);
                $table->string('status')->default('published');
                $table->dateTime('published_at')->nullable();
                $table->text('scripture_refs')->nullable();
                $table->text('objectives')->nullable();
                $table->integer('sort_order')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lesson_progress')) {
            Schema::create('edu_lesson_progress', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->unsignedBigInteger('lesson_id');
                $table->boolean('completed')->default(false);
                $table->dateTime('completed_at')->nullable();
                $table->dateTime('last_accessed_at')->nullable();
                $table->dateTime('last_opened_at')->nullable();
                $table->boolean('bookmarked')->default(false);
                $table->timestamps();
                $table->unique(['user_id', 'lesson_id']);
            });
        }

        if (! Schema::hasTable('edu_classes')) {
            Schema::create('edu_classes', function ($table) {
                $table->id();
                $table->string('name');
                $table->string('status')->default('active');
                $table->unsignedBigInteger('academic_year_id')->nullable();
                $table->unsignedBigInteger('term_id')->nullable();
                $table->unsignedBigInteger('level_id')->nullable();
                $table->string('academic_year')->nullable();
                $table->string('semester')->nullable();
                $table->decimal('pass_mark', 5, 2)->default(50.00);
                $table->boolean('allow_multiple_enrollments')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_course_teachers')) {
            Schema::create('edu_course_teachers', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->unsignedBigInteger('user_id');
                $table->string('role')->default('primary');
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_enrollments')) {
            Schema::create('edu_enrollments', function ($table) {
                $table->id();
                $table->unsignedBigInteger('class_id');
                $table->unsignedBigInteger('user_id');
                $table->string('program')->default('regular');
                $table->string('status')->default('enrolled');
                $table->timestamps();
                $table->unique(['class_id', 'user_id']);
            });
        }

        if (! Schema::hasTable('edu_courses')) {
            Schema::create('edu_courses', function ($table) {
                $table->id();
                $table->unsignedBigInteger('class_id');
                $table->unsignedBigInteger('subject_id')->nullable();
                $table->string('name');
                $table->string('code')->nullable();
                $table->string('mode')->default('physical'); // physical, online, hybrid
                $table->decimal('pass_mark', 5, 2)->default(50.00);
                $table->json('eligible_groups')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_course_enrollments')) {
            Schema::create('edu_course_enrollments', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->unsignedBigInteger('user_id');
                $table->string('status')->default('enrolled');
                $table->unsignedBigInteger('changed_by')->nullable();
                $table->timestamps();
                $table->unique(['course_id', 'user_id']);
            });
        }

        if (! Schema::hasTable('edu_course_outcomes')) {
            Schema::create('edu_course_outcomes', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->unsignedBigInteger('user_id');
                $table->decimal('score_percent', 5, 2)->nullable();
                $table->string('result')->default('incomplete'); // passed, failed, incomplete
                $table->string('status')->default('draft'); // draft, finalized, superseded
                $table->dateTime('finalized_at')->nullable();
                $table->unsignedBigInteger('finalized_by')->nullable();
                $table->decimal('pass_mark', 5, 2)->default(50.00);
                $table->tinyInteger('counts_for_progression')->default(1);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_certificates')) {
            Schema::create('edu_certificates', function ($table) {
                $table->id();
                $table->string('number', 64)->unique();
                $table->string('verify_code', 16)->unique();
                $table->unsignedBigInteger('user_id');
                $table->unsignedBigInteger('course_id');
                $table->unsignedBigInteger('outcome_id');
                $table->dateTime('issued_at');
                $table->unsignedBigInteger('issued_by');
                $table->string('status', 32)->default('valid'); // valid, revoked, replaced
                $table->unsignedBigInteger('replaced_by')->nullable();
                $table->text('revoked_reason')->nullable();
                $table->string('pdf_path', 255)->nullable();
                $table->json('snapshot');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_retakes')) {
            Schema::create('edu_retakes', function ($table) {
                $table->id();
                $table->unsignedBigInteger('outcome_id');
                $table->unsignedBigInteger('course_id');
                $table->unsignedBigInteger('user_id');
                $table->string('status')->default('requested');
                $table->unsignedBigInteger('decided_by')->nullable();
                $table->dateTime('decided_at')->nullable();
                $table->text('decision_note')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_assignments')) {
            Schema::create('edu_assignments', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->string('title');
                $table->text('instructions')->nullable();
                $table->dateTime('due_at')->nullable();
                $table->dateTime('publish_at')->nullable();
                $table->string('late_policy')->default('refuse');
                $table->dateTime('late_until')->nullable();
                $table->json('target_user_ids')->nullable();
                $table->tinyInteger('allow_resubmit')->default(1);
                $table->boolean('is_group')->default(false);
                $table->string('status')->default('published');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_submissions')) {
            Schema::create('edu_submissions', function ($table) {
                $table->id();
                $table->unsignedBigInteger('assignment_id');
                $table->unsignedBigInteger('user_id');
                $table->unsignedBigInteger('group_id')->nullable();
                $table->dateTime('submitted_at')->nullable();
                $table->dateTime('graded_at')->nullable();
                $table->boolean('is_late')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quizzes')) {
            Schema::create('edu_quizzes', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->string('title');
                $table->string('kind')->default('quiz');
                $table->string('availability')->default('open');
                $table->string('status')->default('published');
                $table->integer('attempts_allowed')->default(1);
                $table->dateTime('publish_at')->nullable();
                $table->dateTime('opens_at')->nullable();
                $table->dateTime('closes_at')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quiz_questions')) {
            Schema::create('edu_quiz_questions', function ($table) {
                $table->id();
                $table->unsignedBigInteger('quiz_id')->nullable();
                $table->decimal('points', 6, 2)->default(1);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quiz_attempts')) {
            Schema::create('edu_quiz_attempts', function ($table) {
                $table->id();
                $table->unsignedBigInteger('quiz_id');
                $table->unsignedBigInteger('user_id');
                $table->integer('attempt_no')->default(1);
                $table->string('status')->default('submitted');
                $table->dateTime('started_at')->nullable();
                $table->dateTime('submitted_at')->nullable();
                $table->dateTime('completed_at')->nullable();
                $table->dateTime('expires_at')->nullable();
                $table->boolean('needs_grading')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_class_staff')) {
            Schema::create('edu_class_staff', function ($table) {
                $table->id();
                $table->unsignedBigInteger('class_id');
                $table->unsignedBigInteger('user_id');
                $table->string('role')->default('attendance_taker');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_schedule')) {
            Schema::create('edu_schedule', function ($table) {
                $table->id();
                $table->unsignedBigInteger('class_id');
                $table->unsignedBigInteger('course_id')->nullable();
                $table->integer('day_of_week')->default(0);
                $table->string('starts', 10)->default('08:00');
                $table->string('ends', 10)->default('09:00');
                $table->string('room')->nullable();
                $table->string('frequency')->default('weekly');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_groups')) {
            Schema::create('edu_groups', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->string('name');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_group_members')) {
            Schema::create('edu_group_members', function ($table) {
                $table->id();
                $table->unsignedBigInteger('group_id');
                $table->unsignedBigInteger('user_id');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_assessments')) {
            Schema::create('edu_assessments', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->string('title');
                $table->decimal('max_score', 6, 2)->default(100);
                $table->decimal('weight', 5, 2)->default(100);
                $table->date('held_on')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_scores')) {
            Schema::create('edu_scores', function ($table) {
                $table->id();
                $table->unsignedBigInteger('assessment_id');
                $table->unsignedBigInteger('user_id');
                $table->decimal('score', 6, 2)->nullable();
                $table->string('remark')->nullable();
                $table->string('status')->default('draft');
                $table->unsignedInteger('attempt')->default(1);
                $table->unsignedBigInteger('recorded_by')->nullable();
                $table->dateTime('published_at')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_attendance')) {
            Schema::create('edu_attendance', function ($table) {
                $table->id();
                $table->unsignedBigInteger('class_id');
                $table->unsignedBigInteger('user_id');
                $table->date('session_date');
                $table->string('status')->default('present');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('attendance')) {
            Schema::create('attendance', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->date('occurrence_date');
                $table->string('status')->default('present');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('attendance_edu_classes')) {
            Schema::create('attendance_edu_classes', function ($table) {
                $table->id();
                $table->unsignedBigInteger('attendance_id');
                $table->unsignedBigInteger('class_id');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_requests')) {
            Schema::create('edu_requests', function ($table) {
                $table->id();
                $table->string('status')->default('pending');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_complaints')) {
            Schema::create('edu_complaints', function ($table) {
                $table->id();
                $table->string('status')->default('submitted');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_featured')) {
            Schema::create('edu_featured', function ($table) {
                $table->id();
                $table->string('target_type');
                $table->unsignedBigInteger('target_id');
                $table->string('title')->nullable();
                $table->string('subtitle')->nullable();
                $table->string('image')->nullable();
                $table->dateTime('starts_at')->nullable();
                $table->dateTime('ends_at')->nullable();
                $table->integer('sort_order')->default(0);
                $table->boolean('is_active')->default(true);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('program_edu_classes')) {
            Schema::create('program_edu_classes', function ($table) {
                $table->id();
                $table->unsignedBigInteger('program_id');
                $table->unsignedBigInteger('class_id');
                $table->timestamps();
            });
        }
    }

    private function createFixtures(string $mode = 'online'): array
    {
        $now = Dates::sql(Dates::now());

        // Users
        DB::table('users')->insertOrIgnore([
            ['id' => 1, 'full_name' => 'Admin Haile', 'member_no' => 'M-001', 'member_group' => 'youth_adult'],
            ['id' => 2, 'full_name' => 'Certifier Yohannes', 'member_no' => 'M-002', 'member_group' => 'youth_adult'],
            ['id' => 3, 'full_name' => 'Reporter Martha', 'member_no' => 'M-003', 'member_group' => 'youth_adult'],
            ['id' => 10, 'full_name' => 'Student Abebe', 'member_no' => 'M-010', 'member_group' => 'youth_adult'],
            ['id' => 11, 'full_name' => 'Student Kebede', 'member_no' => 'M-011', 'member_group' => 'youth_adult'],
        ]);

        // Academic period
        $yearId = DB::table('edu_academic_years')->insertGetId([
            'name' => '2017 ዓ.ም. የትምህርት ዘመን',
            'eth_year' => 2017,
            'starts_on' => '2024-09-11',
            'ends_on' => '2025-07-07',
            'is_current' => true,
        ]);

        $termId = DB::table('edu_terms')->insertGetId([
            'academic_year_id' => $yearId,
            'name' => '1ኛ መንፈቀ ትምህርት',
            'starts_on' => '2024-09-11',
            'ends_on' => '2025-01-30',
        ]);

        $levelId = DB::table('edu_levels')->insertGetId([
            'name' => '1ኛ ክፍል (Grade 1)',
            'sequence' => 1,
        ]);

        // Class & Course
        $classId = DB::table('edu_classes')->insertGetId([
            'name' => 'የመጀመሪያ ዓመት ክፍል ሀ',
            'academic_year_id' => $yearId,
            'term_id' => $termId,
            'level_id' => $levelId,
            'pass_mark' => 50.00,
        ]);

        $subjectId = DB::table('edu_subjects')->insertGetId([
            'name' => 'ክርስቲያናዊ ሥነ ምግባር',
            'status' => 'published',
        ]);

        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => $subjectId,
            'name' => 'ክርስቲያናዊ ሥነ ምግባር 101',
            'mode' => $mode,
            'pass_mark' => 50.00,
        ]);

        // Enroll students
        DB::table('edu_enrollments')->insert([
            ['class_id' => $classId, 'user_id' => 10, 'status' => 'active', 'program' => 'regular'],
            ['class_id' => $classId, 'user_id' => 11, 'status' => 'active', 'program' => 'regular'],
        ]);

        // Curriculum
        $unitId = DB::table('edu_units')->insertGetId(['subject_id' => $subjectId, 'title' => 'Unit 1']);
        $lessonId = DB::table('edu_lessons')->insertGetId([
            'subject_id' => $subjectId,
            'unit_id' => $unitId,
            'title' => 'Lesson 1',
            'is_mandatory' => 1,
            'status' => 'published',
        ]);

        return [
            'year_id' => $yearId,
            'term_id' => $termId,
            'level_id' => $levelId,
            'class_id' => $classId,
            'subject_id' => $subjectId,
            'course_id' => $courseId,
            'lesson_id' => $lessonId,
        ];
    }

    public function test_f13_certificate_eligibility_enforces_passed_outcome_and_mandatory_lessons(): void
    {
        $fx = $this->createFixtures('online');
        $courseId = $fx['course_id'];
        $lessonId = $fx['lesson_id'];

        // 1. Outcome passed and finalized
        $outcomeId = DB::table('edu_course_outcomes')->insertGetId([
            'course_id' => $courseId,
            'user_id' => 10,
            'score_percent' => 75.0,
            'result' => 'passed',
            'status' => 'finalized',
            'counts_for_progression' => 1,
            'pass_mark' => 50.0,
        ]);

        // Before completing online mandatory lesson: completion is 0%, eligible is false
        $elig = EduCertificates::eligible($this->adminAuth, $courseId, 10);
        $this->assertCount(1, $elig);
        $this->assertFalse($elig[0]['eligible']);
        $this->assertEquals(0.0, $elig[0]['completion_percent']);

        // Refuses issue
        try {
            EduCertificates::issue($this->adminAuth, $courseId, [10]);
            $this->fail('Expected NOT_ELIGIBLE exception');
        } catch (ApiError $e) {
            $this->assertEquals('NOT_ELIGIBLE', $e->errorCode);
        }

        // Complete mandatory lesson
        DB::table('edu_lesson_progress')->insert([
            'user_id' => 10,
            'lesson_id' => $lessonId,
            'completed' => true,
            'completed_at' => Dates::sql(Dates::now()),
        ]);

        // Now eligible is true
        $eligAfter = EduCertificates::eligible($this->adminAuth, $courseId, 10);
        $this->assertTrue($eligAfter[0]['eligible']);
        $this->assertEquals(100.0, $eligAfter[0]['completion_percent']);

        // Successfully issue
        $issued = EduCertificates::issue($this->certifierAuth, $courseId, [10]);
        $this->assertCount(1, $issued);
        $cert = $issued[0];
        $this->assertStringStartsWith('MH-2017-', $cert['number']);
        $this->assertEquals(10, strlen($cert['verify_code']));
        $this->assertEquals('valid', $cert['status']);
        $this->assertEquals('Student Abebe', $cert['snapshot']['student_name']);

        // Duplicate issue refused
        try {
            EduCertificates::issue($this->certifierAuth, $courseId, [10]);
            $this->fail('Expected CERTIFICATE_EXISTS exception');
        } catch (ApiError $e) {
            $this->assertEquals('CERTIFICATE_EXISTS', $e->errorCode);
        }
    }

    public function test_f13_certificate_revocation_and_reissuing_with_replacement_linking(): void
    {
        $fx = $this->createFixtures('physical');
        $courseId = $fx['course_id'];

        // Passed finalized outcome
        DB::table('edu_course_outcomes')->insert([
            'course_id' => $courseId,
            'user_id' => 10,
            'score_percent' => 88.0,
            'result' => 'passed',
            'status' => 'finalized',
            'counts_for_progression' => 1,
            'pass_mark' => 50.0,
        ]);

        $issued = EduCertificates::issue($this->adminAuth, $courseId, [10]);
        $certId = $issued[0]['id'];
        $code = $issued[0]['verify_code'];
        $number = $issued[0]['number'];

        // Verify public check returns valid
        $verify = EduCertificates::verify($code);
        $this->assertEquals('valid', $verify['status']);
        $this->assertEquals('Student Abebe', $verify['student_name']);
        $this->assertEquals($number, $verify['number']);

        // Revoke
        $revoked = EduCertificates::revoke($this->certifierAuth, $certId, 'Name typo correction needed');
        $this->assertEquals('revoked', $revoked['status']);
        $this->assertEquals('Name typo correction needed', $revoked['revoked_reason']);

        $verifyRevoked = EduCertificates::verify($code);
        $this->assertEquals('revoked', $verifyRevoked['status']);
        $this->assertEquals('Name typo correction needed', $verifyRevoked['revoked_reason']);

        // Reissue
        $reissued = EduCertificates::reissue($this->certifierAuth, $certId, 'Reissued with correct spelling');
        $this->assertEquals('valid', $reissued['status']);
        $this->assertNotEquals($code, $reissued['verify_code']);
        $this->assertNotEquals($number, $reissued['number']);

        // Old certificate verification now links replacement
        $verifyOld = EduCertificates::verify($code);
        $this->assertEquals('replaced', $verifyOld['status']);
        $this->assertEquals($reissued['number'], $verifyOld['replacement_number']);
    }

    public function test_f13_pdf_and_public_web_page_rendering(): void
    {
        $fx = $this->createFixtures('physical');
        $courseId = $fx['course_id'];

        DB::table('edu_course_outcomes')->insert([
            'course_id' => $courseId,
            'user_id' => 10,
            'score_percent' => 92.0,
            'result' => 'passed',
            'status' => 'finalized',
            'counts_for_progression' => 1,
            'pass_mark' => 50.0,
        ]);

        $issued = EduCertificates::issue($this->adminAuth, $courseId, [10]);
        $certId = $issued[0]['id'];
        $code = $issued[0]['verify_code'];

        // Test PDF generation
        $pdf = EduCertificates::renderPdf($certId);
        $this->assertNotEmpty($pdf);
        $this->assertStringStartsWith('%PDF', $pdf);

        // Test Web verification page
        $web = EduCertificates::renderVerifyWebPage($code);
        $this->assertEquals(200, $web->getStatusCode());
        $html = $web->getContent();
        $this->assertStringContainsString('VALID', $html);
        $this->assertStringContainsString('Student Abebe', $html);
        $this->assertStringContainsString($issued[0]['number'], $html);

        // Web verification for invalid code
        $invalidWeb = EduCertificates::renderVerifyWebPage('NON_EXISTENT');
        $this->assertEquals(200, $invalidWeb->getStatusCode());
        $this->assertStringContainsString('Invalid Verification Code', $invalidWeb->getContent());
    }

    public function test_f14_student_dashboard_enriches_academic_period_outcomes_and_certificates(): void
    {
        $fx = $this->createFixtures('physical');
        $courseId = $fx['course_id'];

        // Passed finalized outcome
        DB::table('edu_course_outcomes')->insert([
            'course_id' => $courseId,
            'user_id' => 10,
            'score_percent' => 84.0,
            'result' => 'passed',
            'status' => 'finalized',
            'counts_for_progression' => 1,
            'pass_mark' => 50.0,
        ]);

        EduCertificates::issue($this->adminAuth, $courseId, [10]);

        // Student dashboard call
        $dash = EduDashboard::forUser($this->studentAuth);

        $this->assertNotNull($dash['student']);
        $st = $dash['student'];

        // Academic period
        $this->assertNotNull($st['academic_period']);
        $this->assertEquals('2017 ዓ.ም. የትምህርት ዘመን', $st['academic_period']['year_name']);
        $this->assertEquals(2017, $st['academic_period']['eth_year']);
        $this->assertEquals('1ኛ ክፍል (Grade 1)', $st['academic_period']['level_name']);

        // Outcomes
        $this->assertCount(1, $st['outcomes']);
        $this->assertEquals('passed', $st['outcomes'][0]['result']);

        // Certificates
        $this->assertCount(1, $st['certificates']);
        $this->assertEquals('valid', $st['certificates'][0]['status']);
    }

    public function test_f15_academic_and_engagement_scores_calculation_per_d8(): void
    {
        $fx = $this->createFixtures('physical');
        $courseId = $fx['course_id'];
        $classId = $fx['class_id'];
        $subjectId = $fx['subject_id'];
        $lessonId = $fx['lesson_id'];

        // Student 10:
        // Outcome score: 90%
        DB::table('edu_course_outcomes')->insert([
            'course_id' => $courseId,
            'user_id' => 10,
            'score_percent' => 90.0,
            'result' => 'passed',
            'status' => 'finalized',
            'counts_for_progression' => 1,
            'pass_mark' => 50.0,
        ]);

        // Mandatory lessons: 1 published mandatory lesson completed by student 10 (100% -> 50% * 1.0 = 50.0)
        DB::table('edu_lesson_progress')->insert([
            'user_id' => 10,
            'lesson_id' => $lessonId,
            'completed' => 1,
            'completed_at' => Dates::sql(Dates::now()),
        ]);

        // Assignments: 1 published assignment due, submitted by student 10 (100% -> 30% * 1.0 = 30.0)
        $assignId = DB::table('edu_assignments')->insertGetId([
            'course_id' => $courseId,
            'title' => 'Homework 1',
            'due_at' => Dates::sql(Dates::of(Dates::now())->modify('-1 day')),
            'status' => 'published',
        ]);
        DB::table('edu_submissions')->insert([
            'assignment_id' => $assignId,
            'user_id' => 10,
            'submitted_at' => Dates::sql(Dates::now()),
        ]);

        // Quizzes: 1 open quiz, attempted by student 10 (100% -> 20% * 1.0 = 20.0)
        $quizId = DB::table('edu_quizzes')->insertGetId([
            'course_id' => $courseId,
            'title' => 'Quiz 1',
            'availability' => 'open',
        ]);
        DB::table('edu_quiz_attempts')->insert([
            'quiz_id' => $quizId,
            'user_id' => 10,
            'status' => 'submitted',
        ]);

        // Student 10 Engagement score: 50 + 30 + 20 = 100.0%

        // Student 11 (Kebede):
        // Outcome score: 70%
        DB::table('edu_course_outcomes')->insert([
            'course_id' => $courseId,
            'user_id' => 11,
            'score_percent' => 70.0,
            'result' => 'passed',
            'status' => 'finalized',
            'counts_for_progression' => 1,
            'pass_mark' => 50.0,
        ]);
        // Student 11 did not complete the lesson, did not submit the assignment, but attempted the quiz
        DB::table('edu_quiz_attempts')->insert([
            'quiz_id' => $quizId,
            'user_id' => 11,
            'status' => 'submitted',
        ]);
        // Student 11 Engagement score: (0/1 * 50) + (0/1 * 30) + (1/1 * 20) = 20.0%

        $scores = EduScores::forPeriod($this->reporterAuth, classId: $classId);
        $this->assertCount(2, $scores);

        $s10 = collect($scores)->firstWhere('user_id', 10);
        $s11 = collect($scores)->firstWhere('user_id', 11);

        $this->assertEquals(90.0, $s10['academic_score']);
        $this->assertEquals(100.0, $s10['engagement_score']);
        $this->assertEquals(1, $s10['mandatory_lessons_completed']);
        $this->assertEquals(1, $s10['assignments_submitted']);
        $this->assertEquals(1, $s10['quiz_attempts']);

        $this->assertEquals(70.0, $s11['academic_score']);
        $this->assertEquals(20.0, $s11['engagement_score']);
        $this->assertEquals(0, $s11['mandatory_lessons_completed']);
        $this->assertEquals(0, $s11['assignments_submitted']);
        $this->assertEquals(1, $s11['quiz_attempts']);

        // Check permission requirement
        try {
            EduScores::forPeriod($this->studentAuth, classId: $classId);
            $this->fail('Expected FORBIDDEN without education.reports');
        } catch (ApiError $e) {
            $this->assertEquals('FORBIDDEN', $e->errorCode);
        }
    }

    public function test_f15_report_export_scores_and_activity(): void
    {
        $fx = $this->createFixtures('physical');
        $courseId = $fx['course_id'];
        $classId = $fx['class_id'];

        DB::table('edu_course_outcomes')->insert([
            'course_id' => $courseId,
            'user_id' => 10,
            'score_percent' => 85.0,
            'result' => 'passed',
            'status' => 'finalized',
            'counts_for_progression' => 1,
            'pass_mark' => 50.0,
        ]);

        // Test ReportExport::build for education-scores
        $scoreReport = ReportExport::build($this->reporterAuth, 'education-scores', ['class_id' => $classId]);
        $this->assertEquals('Student Academic & Engagement Scores', $scoreReport['title']);
        $this->assertCount(1, $scoreReport['tables']);
        $this->assertGreaterThan(0, count($scoreReport['tables'][0]['rows']));

        // Test ReportExport::build for education-activity
        $activityReport = ReportExport::build($this->reporterAuth, 'education-activity', ['class_id' => $classId]);
        $this->assertEquals('Education Activity Report', $activityReport['title']);
        $this->assertCount(1, $activityReport['tables']);
    }
}
