<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Http\Upload;
use App\Mz\Services\Edu;
use App\Mz\Services\EduAssignments;
use App\Mz\Services\EduCertificates;
use App\Mz\Services\EduDashboard;
use App\Mz\Services\EduLearning;
use App\Mz\Services\EduReportCard;
use App\Mz\Services\EduScores;
use App\Mz\Support\ApiError;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EducationPhase1CriticalStabilizationTest extends TestCase
{
    private AuthContext $adminAuth;
    private AuthContext $teacherAuth;
    private AuthContext $studentAuth;
    private array $adminActx;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = new AuthContext();
        $this->adminAuth->id = 1;
        $this->adminAuth->fullName = 'Admin User';
        $this->adminAuth->status = 'active';
        $this->adminAuth->isAdmin = true;
        $this->adminAuth->permissions = ['education.manage' => true, 'education.register' => true, 'education.reports' => true];
        $this->adminActx = ['auth' => $this->adminAuth];

        $this->teacherAuth = new AuthContext();
        $this->teacherAuth->id = 2;
        $this->teacherAuth->fullName = 'Teacher User';
        $this->teacherAuth->status = 'active';
        $this->teacherAuth->isAdmin = false;
        $this->teacherAuth->permissions = [];

        $this->studentAuth = new AuthContext();
        $this->studentAuth->id = 3;
        $this->studentAuth->fullName = 'Student User';
        $this->studentAuth->status = 'active';
        $this->studentAuth->isAdmin = false;
        $this->studentAuth->permissions = [];
    }

    private function setUpSchema(): void
    {
        Schema::dropIfExists('edu_scores');
        Schema::dropIfExists('edu_assessments');
        Schema::dropIfExists('edu_assignment_submissions');
        Schema::dropIfExists('edu_submission_versions');
        Schema::dropIfExists('edu_submissions');
        Schema::dropIfExists('edu_assignments');
        Schema::dropIfExists('edu_group_members');
        Schema::dropIfExists('edu_groups');
        Schema::dropIfExists('edu_course_teachers');
        Schema::dropIfExists('edu_course_enrollments');
        Schema::dropIfExists('edu_enrollments');
        Schema::dropIfExists('edu_courses');
        Schema::dropIfExists('edu_lesson_progress');
        Schema::dropIfExists('edu_lessons');
        Schema::dropIfExists('edu_units');
        Schema::dropIfExists('edu_subjects');
        Schema::dropIfExists('edu_classes');
        Schema::dropIfExists('edu_terms');
        Schema::dropIfExists('edu_academic_years');
        Schema::dropIfExists('users');

        Schema::create('users', function ($table) {
            $table->id();
            $table->string('full_name');
            $table->string('phone')->nullable();
            $table->string('member_no')->nullable();
            $table->string('member_group')->nullable();
            $table->string('status')->default('active');
            $table->timestamp('deleted_at')->nullable();
            $table->timestamps();
        });

        Schema::create('edu_academic_years', function ($table) {
            $table->id();
            $table->string('name');
            $table->integer('eth_year')->default(2018);
            $table->date('starts_on');
            $table->date('ends_on');
            $table->boolean('is_current')->default(true);
            $table->string('status')->default('active');
            $table->timestamps();
        });

        Schema::create('edu_terms', function ($table) {
            $table->id();
            $table->unsignedBigInteger('academic_year_id');
            $table->string('name');
            $table->integer('term_number')->default(1);
            $table->date('starts_on');
            $table->date('ends_on');
            $table->boolean('is_current')->default(true);
            $table->timestamps();
        });

        Schema::create('edu_classes', function ($table) {
            $table->id();
            $table->unsignedBigInteger('academic_year_id')->nullable();
            $table->unsignedBigInteger('term_id')->nullable();
            $table->string('name');
            $table->integer('grade')->nullable();
            $table->unsignedBigInteger('level_id')->nullable();
            $table->string('status')->default('active');
            $table->timestamps();
        });

        Schema::create('edu_subjects', function ($table) {
            $table->id();
            $table->unsignedBigInteger('category_id')->nullable();
            $table->string('name');
            $table->string('name_en')->nullable();
            $table->integer('grade')->nullable();
            $table->string('visibility')->default('public');
            $table->integer('sort_order')->default(1);
            $table->string('status')->default('active');
            $table->timestamps();
        });

        Schema::create('edu_units', function ($table) {
            $table->id();
            $table->unsignedBigInteger('subject_id');
            $table->string('title');
            $table->integer('sort_order')->default(1);
            $table->string('status')->default('published');
            $table->timestamps();
        });

        Schema::create('edu_lessons', function ($table) {
            $table->id();
            $table->unsignedBigInteger('subject_id');
            $table->unsignedBigInteger('unit_id')->nullable();
            $table->string('title');
            $table->boolean('is_mandatory')->default(false);
            $table->string('status')->default('published');
            $table->integer('sort_order')->default(1);
            $table->timestamps();
        });

        Schema::create('edu_lesson_progress', function ($table) {
            $table->id();
            $table->unsignedBigInteger('user_id');
            $table->unsignedBigInteger('lesson_id');
            $table->timestamp('completed_at')->nullable();
            $table->timestamp('last_opened_at')->nullable();
            $table->timestamps();
        });

        Schema::create('edu_courses', function ($table) {
            $table->id();
            $table->unsignedBigInteger('class_id');
            $table->unsignedBigInteger('subject_id')->nullable();
            $table->string('name');
            $table->string('code')->nullable();
            $table->string('mode')->default('physical');
            $table->decimal('pass_mark', 5, 2)->default(50.0);
            $table->unsignedBigInteger('teacher_user_id')->nullable();
            $table->string('status')->default('active');
            $table->timestamps();
        });

        Schema::create('edu_course_teachers', function ($table) {
            $table->id();
            $table->unsignedBigInteger('course_id');
            $table->unsignedBigInteger('user_id');
            $table->string('role')->default('primary');
            $table->string('status')->default('active');
            $table->timestamps();
        });

        Schema::create('edu_enrollments', function ($table) {
            $table->id();
            $table->unsignedBigInteger('class_id');
            $table->unsignedBigInteger('user_id');
            $table->string('program')->default('regular');
            $table->string('status')->default('active');
            $table->timestamps();
        });

        Schema::create('settings', function ($table) {
            $table->string('key')->primary();
            $table->text('value')->nullable();
            $table->timestamps();
        });

        Schema::create('edu_course_enrollments', function ($table) {
            $table->id();
            $table->unsignedBigInteger('course_id');
            $table->unsignedBigInteger('user_id');
            $table->string('status')->default('enrolled');
            $table->timestamps();
        });

        Schema::create('edu_assignments', function ($table) {
            $table->id();
            $table->unsignedBigInteger('course_id')->nullable();
            $table->unsignedBigInteger('class_id')->nullable();
            $table->unsignedBigInteger('subject_id')->nullable();
            $table->integer('grade')->nullable();
            $table->unsignedBigInteger('teacher_id')->nullable();
            $table->string('title');
            $table->string('title_en')->nullable();
            $table->text('instructions')->nullable();
            $table->text('instructions_en')->nullable();
            $table->text('attachments')->nullable();
            $table->decimal('max_score', 8, 2)->default(100.0);
            $table->timestamp('due_at')->nullable();
            $table->string('status')->default('published');
            $table->boolean('allow_late')->default(true);
            $table->boolean('allow_resubmit')->default(true);
            $table->boolean('is_group')->default(false);
            $table->timestamps();
        });

        Schema::create('edu_assignment_submissions', function ($table) {
            $table->id();
            $table->unsignedBigInteger('assignment_id');
            $table->unsignedBigInteger('user_id');
            $table->text('text_response')->nullable();
            $table->text('attachments')->nullable();
            $table->decimal('score', 8, 2)->nullable();
            $table->text('feedback')->nullable();
            $table->unsignedBigInteger('graded_by')->nullable();
            $table->timestamp('graded_at')->nullable();
            $table->string('status')->default('submitted');
            $table->boolean('is_late')->default(false);
            $table->timestamp('submitted_at')->nullable();
            $table->timestamp('released_at')->nullable();
            $table->timestamps();
            $table->unique(['assignment_id', 'user_id']);
        });

        Schema::create('edu_submissions', function ($table) {
            $table->id();
            $table->unsignedBigInteger('assignment_id');
            $table->unsignedBigInteger('user_id');
            $table->unsignedBigInteger('group_id')->nullable();
            $table->text('text')->nullable();
            $table->string('file')->nullable();
            $table->string('file_name')->nullable();
            $table->decimal('score', 8, 2)->nullable();
            $table->text('feedback')->nullable();
            $table->timestamp('graded_at')->nullable();
            $table->unsignedBigInteger('graded_by')->nullable();
            $table->timestamp('submitted_at')->nullable();
            $table->boolean('is_late')->default(false);
            $table->timestamps();
        });

        Schema::create('edu_submission_versions', function ($table) {
            $table->id();
            $table->unsignedBigInteger('submission_id');
            $table->text('text')->nullable();
            $table->string('file')->nullable();
            $table->string('file_name')->nullable();
            $table->timestamp('submitted_at')->nullable();
            $table->boolean('is_late')->default(false);
            $table->timestamps();
        });

        Schema::create('edu_assessments', function ($table) {
            $table->id();
            $table->unsignedBigInteger('course_id');
            $table->string('title');
            $table->decimal('max_score', 8, 2)->default(100.0);
            $table->timestamps();
        });

        Schema::create('edu_scores', function ($table) {
            $table->id();
            $table->unsignedBigInteger('assessment_id');
            $table->unsignedBigInteger('user_id');
            $table->decimal('score', 8, 2)->nullable();
            $table->string('status')->default('published');
            $table->timestamp('published_at')->nullable();
            $table->timestamps();
        });

        Schema::create('edu_course_outcomes', function ($table) {
            $table->id();
            $table->unsignedBigInteger('course_id');
            $table->unsignedBigInteger('user_id');
            $table->decimal('score_percent', 5, 2)->default(0);
            $table->decimal('pass_mark', 5, 2)->default(50);
            $table->string('result')->default('passed');
            $table->string('grade_letter')->nullable();
            $table->string('status')->default('completed');
            $table->boolean('counts_for_progression')->default(true);
            $table->timestamp('finalized_at')->nullable();
            $table->timestamps();
        });

        Schema::create('edu_retakes', function ($table) {
            $table->id();
            $table->unsignedBigInteger('course_id');
            $table->unsignedBigInteger('user_id');
            $table->string('status')->default('pending');
            $table->timestamps();
        });

        Schema::create('edu_certificates', function ($table) {
            $table->id();
            $table->unsignedBigInteger('course_id');
            $table->unsignedBigInteger('user_id');
            $table->string('status')->default('valid');
            $table->timestamp('issued_at')->nullable();
            $table->timestamps();
        });

        Schema::create('edu_class_staff', function ($table) {
            $table->id();
            $table->unsignedBigInteger('class_id');
            $table->unsignedBigInteger('user_id');
            $table->string('role')->default('homeroom');
            $table->timestamps();
        });

        Schema::create('edu_schedule', function ($table) {
            $table->id();
            $table->unsignedBigInteger('class_id');
            $table->unsignedBigInteger('course_id')->nullable();
            $table->string('day_of_week')->default('monday');
            $table->time('starts_at')->nullable();
            $table->time('ends_at')->nullable();
            $table->timestamps();
        });

        Schema::create('edu_quizzes', function ($table) {
            $table->id();
            $table->unsignedBigInteger('course_id')->nullable();
            $table->unsignedBigInteger('lesson_id')->nullable();
            $table->string('title');
            $table->string('title_en')->nullable();
            $table->string('status')->default('published');
            $table->timestamp('closes_at')->nullable();
            $table->timestamp('results_release_at')->nullable();
            $table->string('review_policy')->default('after_close');
            $table->timestamps();
        });

        Schema::create('edu_quiz_questions', function ($table) {
            $table->id();
            $table->unsignedBigInteger('quiz_id');
            $table->decimal('points', 5, 2)->default(1);
            $table->timestamps();
        });

        Schema::create('edu_quiz_attempts', function ($table) {
            $table->id();
            $table->unsignedBigInteger('quiz_id');
            $table->unsignedBigInteger('user_id');
            $table->integer('attempt_no')->default(1);
            $table->string('status')->default('submitted');
            $table->decimal('auto_score', 8, 2)->default(0);
            $table->decimal('manual_score', 8, 2)->default(0);
            $table->decimal('max_score', 8, 2)->default(100);
            $table->text('question_ids')->nullable();
            $table->boolean('needs_grading')->default(false);
            $table->timestamp('started_at')->nullable();
            $table->timestamp('submitted_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();
        });

        Schema::create('edu_featured', function ($table) {
            $table->id();
            $table->string('title');
            $table->boolean('is_active')->default(true);
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('ends_at')->nullable();
            $table->integer('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('attendance', function ($table) {
            $table->id();
            $table->unsignedBigInteger('user_id');
            $table->date('occurrence_date')->nullable();
            $table->string('status')->default('present');
            $table->timestamps();
        });

        Schema::create('attendance_edu_classes', function ($table) {
            $table->id();
            $table->unsignedBigInteger('attendance_id')->nullable();
            $table->unsignedBigInteger('class_id');
            $table->timestamps();
        });

        Schema::create('program_edu_classes', function ($table) {
            $table->id();
            $table->unsignedBigInteger('program_id');
            $table->unsignedBigInteger('class_id');
            $table->timestamps();
        });

        Schema::create('edu_attendance', function ($table) {
            $table->id();
            $table->unsignedBigInteger('class_id');
            $table->unsignedBigInteger('user_id');
            $table->date('session_date')->nullable();
            $table->string('status')->default('present');
            $table->timestamps();
        });

        Schema::create('edu_categories', function ($table) {
            $table->id();
            $table->string('name');
            $table->string('status')->default('active');
            $table->integer('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('edu_groups', function ($table) {
            $table->id();
            $table->unsignedBigInteger('course_id');
            $table->string('name');
            $table->timestamps();
        });

        Schema::create('edu_group_members', function ($table) {
            $table->id();
            $table->unsignedBigInteger('group_id');
            $table->unsignedBigInteger('user_id');
            $table->timestamps();
        });

        // Insert seed users
        DB::table('users')->insert([
            ['id' => 1, 'full_name' => 'Admin User', 'member_no' => 'M001', 'member_group' => 'A'],
            ['id' => 2, 'full_name' => 'Teacher User', 'member_no' => 'M002', 'member_group' => 'B'],
            ['id' => 3, 'full_name' => 'Student User', 'member_no' => 'M003', 'member_group' => 'C'],
        ]);
    }

    /** TASK 1: Test Course Completion Percentage Calculation and Fallbacks */
    public function test_course_completion_calculation_and_fallbacks(): void
    {
        $subjectId = DB::table('edu_subjects')->insertGetId([
            'name' => 'Spiritual Education Grade 5',
            'grade' => 5,
            'status' => 'active',
        ]);

        $classId = DB::table('edu_classes')->insertGetId([
            'name' => 'Grade 5 Class',
            'grade' => 5,
            'status' => 'active',
        ]);

        DB::table('edu_enrollments')->insert([
            'class_id' => $classId,
            'user_id' => 3,
            'status' => 'active',
        ]);

        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => $subjectId,
            'name' => 'Spiritual Education Course',
            'status' => 'active',
        ]);

        // Scenario A: 0 lessons published -> accurately reports 0.0% completion (not misleading 100%)
        $comp0 = EduLearning::courseCompletion(3, $courseId);
        $this->assertEquals(0, $comp0['completed']);
        $this->assertEquals(0, $comp0['total']);
        $this->assertEquals(0.0, $comp0['percent']);
        $this->assertTrue($comp0['is_enrolled']);

        // Scenario B: 4 lessons published without explicit is_mandatory=1 (default 0)
        // System must fallback to all published lessons rather than claiming 100% complete
        $lessonIds = [];
        for ($i = 1; $i <= 4; $i++) {
            $lessonIds[] = DB::table('edu_lessons')->insertGetId([
                'subject_id' => $subjectId,
                'title' => "Lesson $i",
                'is_mandatory' => 0,
                'status' => 'published',
            ]);
        }

        // Student hasn't opened any: 0% complete
        $compB0 = EduLearning::courseCompletion(3, $courseId);
        $this->assertEquals(0, $compB0['completed']);
        $this->assertEquals(4, $compB0['total']);
        $this->assertEquals(0.0, $compB0['percent']);

        // Student completes 2 out of 4: 50% complete
        DB::table('edu_lesson_progress')->insert([
            ['user_id' => 3, 'lesson_id' => $lessonIds[0], 'completed_at' => now()],
            ['user_id' => 3, 'lesson_id' => $lessonIds[1], 'completed_at' => now()],
        ]);
        $compB2 = EduLearning::courseCompletion(3, $courseId);
        $this->assertEquals(2, $compB2['completed']);
        $this->assertEquals(4, $compB2['total']);
        $this->assertEquals(50.0, $compB2['percent']);

        // Student completes all 4: 100% complete
        DB::table('edu_lesson_progress')->insert([
            ['user_id' => 3, 'lesson_id' => $lessonIds[2], 'completed_at' => now()],
            ['user_id' => 3, 'lesson_id' => $lessonIds[3], 'completed_at' => now()],
        ]);
        $compB4 = EduLearning::courseCompletion(3, $courseId);
        $this->assertEquals(4, $compB4['completed']);
        $this->assertEquals(4, $compB4['total']);
        $this->assertEquals(100.0, $compB4['percent']);
    }

    /** TASK 2: Test Curriculum Sync Without Undefined $hasGradeCol Error */
    public function test_curriculum_sync_without_undefined_variable_error(): void
    {
        $classId = DB::table('edu_classes')->insertGetId([
            'name' => 'Grade 7 Section A',
            'grade' => 7,
            'status' => 'active',
        ]);

        DB::table('edu_subjects')->insert([
            ['name' => 'Ge\'ez Language', 'grade' => 7, 'status' => 'active'],
            ['name' => 'Church History', 'grade' => 7, 'status' => 'active'],
        ]);

        // Must run cleanly without throwing undefined variable $hasGradeCol exception
        $result = Edu::connectClassToCurriculum($classId);

        $this->assertIsArray($result);
        $this->assertEquals(7, $result['grade']);
        $this->assertEquals(2, $result['total_subjects']);
        $this->assertEquals(2, $result['connected']);
    }

    /** TASK 3: Test Text-Only Submissions Handled Cleanly */
    public function test_text_only_assignment_submission_succeeds(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Grade 8 Class', 'grade' => 8]);
        $courseId = DB::table('edu_courses')->insertGetId(['class_id' => $classId, 'name' => 'Course 8']);

        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => 3, 'status' => 'active']);
        DB::table('edu_course_enrollments')->insert(['course_id' => $courseId, 'user_id' => 3, 'status' => 'enrolled']);

        $assignmentId = DB::table('edu_assignments')->insertGetId([
            'course_id' => $courseId,
            'teacher_id' => 2,
            'title' => 'Essay on Ancient Churches',
            'max_score' => 100.0,
            'status' => 'published',
            'allow_late' => true,
            'allow_resubmit' => true,
        ]);

        // Submit text-only with NO file ($file === null)
        $result = EduAssignments::submit($this->studentAuth, $assignmentId, [
            'text_response' => 'This is my comprehensive essay on Lalibela.',
        ], null);

        $this->assertIsArray($result);
        $this->assertEquals('submitted', $result['status']);
        $this->assertEquals('This is my comprehensive essay on Lalibela.', $result['text_response']);

        // Check modern table
        $modern = DB::table('edu_assignment_submissions')->where(['assignment_id' => $assignmentId, 'user_id' => 3])->first();
        $this->assertNotNull($modern);
        $this->assertEquals('This is my comprehensive essay on Lalibela.', $modern->text_response);

        // Check legacy table history preservation
        $legacy = DB::table('edu_submissions')->where(['assignment_id' => $assignmentId, 'user_id' => 3])->first();
        $this->assertNotNull($legacy);
        $this->assertEquals('This is my comprehensive essay on Lalibela.', $legacy->text);
    }

    /** TASK 4: Test Dashboard Due Soon & Engagement Submissions Consolidation */
    public function test_submitted_assignments_disappear_from_dashboard_due_soon(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Grade 9 Class', 'grade' => 9]);
        $courseId = DB::table('edu_courses')->insertGetId(['class_id' => $classId, 'name' => 'Course 9']);

        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => 3, 'status' => 'active']);
        DB::table('edu_course_enrollments')->insert(['course_id' => $courseId, 'user_id' => 3, 'status' => 'enrolled']);

        $assignmentId = DB::table('edu_assignments')->insertGetId([
            'course_id' => $courseId,
            'teacher_id' => 2,
            'title' => 'Math Homework 1',
            'due_at' => now()->addDays(2),
            'status' => 'published',
        ]);

        // Before submitting: dashboard lists the assignment in due soon
        $dashBefore = EduDashboard::forUser($this->studentAuth);
        $dueBefore = array_column($dashBefore['student']['assignments_due'] ?? [], 'id');
        $this->assertContains($assignmentId, $dueBefore);

        // Submit via modern classroom
        EduAssignments::submit($this->studentAuth, $assignmentId, ['text_response' => 'Done!']);

        // After submitting: dashboard must remove the assignment from due soon!
        $dashAfter = EduDashboard::forUser($this->studentAuth);
        $dueAfter = array_column($dashAfter['student']['assignments_due'] ?? [], 'id');
        $this->assertNotContains($assignmentId, $dueAfter);
    }

    /** TASK 5: Test Teacher Authorization via edu_course_teachers */
    public function test_teacher_authorization_via_course_teachers_table(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Grade 10 Class', 'grade' => 10]);
        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'name' => 'Theology 10',
            'teacher_user_id' => null, // Legacy column is NULL!
        ]);

        // Assign teacher via modern canonical junction table
        DB::table('edu_course_teachers')->insert([
            'course_id' => $courseId,
            'user_id' => 2, // teacher
            'role' => 'primary',
            'status' => 'active',
        ]);

        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => 3, 'status' => 'active']);

        // 1. Teacher views student scores: must NOT throw 403 Forbidden!
        $scores = EduScores::forStudent($this->teacherAuth, 3);
        $this->assertIsArray($scores);
        $this->assertEquals(3, $scores['student']['id']);

        // 2. Teacher views student report card: must NOT throw 403 Forbidden!
        $reportCard = EduReportCard::generateData($this->teacherAuth, 3);
        $this->assertIsArray($reportCard);
        $this->assertEquals('Student User', $reportCard['full_name']);
    }

    /** TASK 6: Test Upload::optional Text-Only Non-Multipart Behavior */
    public function test_upload_optional_handles_non_file_requests_without_error(): void
    {
        // When request does not have multipart file, Upload::optional must return null, never throw FILE_REQUIRED
        $res = Upload::optional('document', 'file');
        $this->assertNull($res);

        $res2 = Upload::optional('submission', 'submission');
        $this->assertNull($res2);
    }

    /** TASK 7: Verify Zero-Published-Lessons Cannot Qualify Online/Hybrid Course For Certificate */
    public function test_zero_published_lessons_cannot_qualify_online_or_hybrid_course_for_certificate(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Grade 11 Class', 'grade' => 11]);
        $subjectId = DB::table('edu_subjects')->insertGetId(['name' => 'Advanced Liturgy', 'grade' => 11]);
        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => $subjectId,
            'name' => 'Online Liturgy',
            'mode' => 'online',
            'pass_mark' => 50.0,
        ]);

        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => 3, 'status' => 'active']);

        // Student has a passed outcome
        DB::table('edu_course_outcomes')->insert([
            'course_id' => $courseId,
            'user_id' => 3,
            'score_percent' => 85.0,
            'pass_mark' => 50.0,
            'result' => 'passed',
            'status' => 'finalized',
            'counts_for_progression' => 1,
        ]);

        // When course has 0 published lessons:
        // courseCompletion returns percent=0.0 and total=0
        $comp = EduLearning::courseCompletion(3, $courseId);
        $this->assertEquals(0, $comp['total']);
        $this->assertEquals(0.0, $comp['percent']);

        // Certificate eligibility MUST require total_lessons > 0 for online/hybrid courses!
        $eligibleList = EduCertificates::eligible($this->adminAuth, $courseId, 3);
        $this->assertNotEmpty($eligibleList);
        $this->assertFalse($eligibleList[0]['eligible'], 'Zero-published-lessons course must NEVER be eligible for certificate');
    }

    /** TASK 8: Verify Course Completion Requires Active Enrollment */
    public function test_course_completion_requires_valid_enrollment(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Grade 9 Class', 'grade' => 9]);
        $subjectId = DB::table('edu_subjects')->insertGetId(['name' => 'Church Music', 'grade' => 9, 'visibility' => 'enrolled_only']);
        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => $subjectId,
            'name' => 'Hymnology',
        ]);

        DB::table('edu_lessons')->insert([
            'subject_id' => $subjectId,
            'title' => 'First Hymn',
            'status' => 'published',
            'is_mandatory' => 1,
        ]);

        // User 4 is NOT enrolled in class or course
        $comp = EduLearning::courseCompletion(4, $courseId);
        $this->assertEquals(0.0, $comp['percent']);
        $this->assertEquals(0, $comp['total']);
        $this->assertFalse($comp['is_enrolled']);
    }

    /** TASK 9: Verify Homeroom Teacher Authorization via edu_class_staff */
    public function test_homeroom_teacher_authorized_via_class_staff(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Grade 12 Homeroom', 'grade' => 12]);
        $courseId = DB::table('edu_courses')->insertGetId(['class_id' => $classId, 'name' => 'Senior Theology']);

        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => 3, 'status' => 'active']);

        // User 2 is NOT course teacher, but is class staff (homeroom teacher)
        DB::table('edu_class_staff')->insert([
            'class_id' => $classId,
            'user_id' => 2,
            'role' => 'homeroom',
        ]);

        // Homeroom teacher views student scores: must succeed!
        $scores = EduScores::forStudent($this->teacherAuth, 3);
        $this->assertIsArray($scores);
        $this->assertEquals(3, $scores['student']['id']);

        // Homeroom teacher views report card: must succeed!
        $reportCard = EduReportCard::generateData($this->teacherAuth, 3);
        $this->assertIsArray($reportCard);
        $this->assertEquals('Student User', $reportCard['full_name']);
    }

    /** TASK 10: Verify Unauthorized Student Cannot View Another Student Scores or Report Card */
    public function test_unauthorized_student_cannot_view_other_student_data(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Grade 6 Class', 'grade' => 6]);
        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => 3, 'status' => 'active']);

        // Another student (User 4)
        $otherStudentAuth = new AuthContext();
        $otherStudentAuth->id = 4;
        $otherStudentAuth->fullName = 'Another Student';
        $otherStudentAuth->status = 'active';
        $otherStudentAuth->isAdmin = false;
        $otherStudentAuth->permissions = [];

        $this->expectException(ApiError::class);
        $this->expectExceptionMessage('You cannot view this student\'s scores');
        EduScores::forStudent($otherStudentAuth, 3);
    }

    /** TASK 11: Verify Inactive (Suspended/Removed) Teacher is Forbidden */
    public function test_inactive_teacher_forbidden_from_viewing_student_scores(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Grade 5 Class', 'grade' => 5]);
        $courseId = DB::table('edu_courses')->insertGetId(['class_id' => $classId, 'name' => 'History 5']);
        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => 3, 'status' => 'active']);

        // Suspended teacher
        DB::table('edu_course_teachers')->insert([
            'course_id' => $courseId,
            'user_id' => 2,
            'role' => 'primary',
            'status' => 'suspended',
        ]);

        $this->expectException(ApiError::class);
        $this->expectExceptionMessage('You cannot view this student\'s scores');
        EduScores::forStudent($this->teacherAuth, 3);
    }

    /** TASK 12: Verify Single Published Lesson and Partially Completed Lessons */
    public function test_one_published_lesson_not_completed_and_partially_completed(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Grade 4 Class', 'grade' => 4]);
        $subjectId = DB::table('edu_subjects')->insertGetId(['name' => 'Subject 4', 'grade' => 4]);
        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => $subjectId,
            'name' => 'Course 4',
        ]);
        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => 3, 'status' => 'active']);

        $l1 = DB::table('edu_lessons')->insertGetId([
            'subject_id' => $subjectId,
            'title' => 'First Lesson',
            'status' => 'published',
            'is_mandatory' => 1,
        ]);

        // 1 published lesson, not completed -> 0.0%
        $comp1 = EduLearning::courseCompletion(3, $courseId);
        $this->assertEquals(0, $comp1['completed']);
        $this->assertEquals(1, $comp1['total']);
        $this->assertEquals(0.0, $comp1['percent']);

        // Add 2nd lesson
        $l2 = DB::table('edu_lessons')->insertGetId([
            'subject_id' => $subjectId,
            'title' => 'Second Lesson',
            'status' => 'published',
            'is_mandatory' => 1,
        ]);

        // Complete lesson 1 of 2 -> 50.0%
        DB::table('edu_lesson_progress')->insert([
            'user_id' => 3,
            'lesson_id' => $l1,
            'completed_at' => now(),
        ]);
        $comp2 = EduLearning::courseCompletion(3, $courseId);
        $this->assertEquals(1, $comp2['completed']);
        $this->assertEquals(2, $comp2['total']);
        $this->assertEquals(50.0, $comp2['percent']);

        // Complete lesson 2 of 2 -> 100.0%
        DB::table('edu_lesson_progress')->insert([
            'user_id' => 3,
            'lesson_id' => $l2,
            'completed_at' => now(),
        ]);
        $comp3 = EduLearning::courseCompletion(3, $courseId);
        $this->assertEquals(2, $comp3['completed']);
        $this->assertEquals(2, $comp3['total']);
        $this->assertEquals(100.0, $comp3['percent']);
    }

    /** TASK 13: Verify Inactive (Dropped/Suspended) Enrollment Returns Inactive Status */
    public function test_inactive_enrollment_rejected_from_completion(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Grade 3 Class', 'grade' => 3]);
        $subjectId = DB::table('edu_subjects')->insertGetId(['name' => 'Subject 3', 'grade' => 3, 'visibility' => 'enrolled_only']);
        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => $subjectId,
            'name' => 'Course 3',
        ]);

        // User 5 has dropped status
        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => 5, 'status' => 'dropped']);

        DB::table('edu_lessons')->insert([
            'subject_id' => $subjectId,
            'title' => 'Lesson in Course 3',
            'status' => 'published',
            'is_mandatory' => 1,
        ]);

        $comp = EduLearning::courseCompletion(5, $courseId);
        $this->assertEquals(0.0, $comp['percent']);
        $this->assertEquals(0, $comp['total']);
        $this->assertFalse($comp['is_enrolled']);
    }

    /** TASK 14: Verify Teacher IDOR Protection (Cannot View Other Teacher's Students) */
    public function test_teacher_cannot_access_other_teacher_students_via_idor(): void
    {
        // Class A with Teacher 2
        $classA = DB::table('edu_classes')->insertGetId(['name' => 'Class A', 'grade' => 1]);
        $courseA = DB::table('edu_courses')->insertGetId(['class_id' => $classA, 'name' => 'Course A']);
        DB::table('edu_course_teachers')->insert(['course_id' => $courseA, 'user_id' => 2, 'status' => 'active']);

        // Class B with Teacher 6 and Student 5
        $classB = DB::table('edu_classes')->insertGetId(['name' => 'Class B', 'grade' => 2]);
        $courseB = DB::table('edu_courses')->insertGetId(['class_id' => $classB, 'name' => 'Course B']);
        DB::table('edu_course_teachers')->insert(['course_id' => $courseB, 'user_id' => 6, 'status' => 'active']);
        DB::table('edu_enrollments')->insert(['class_id' => $classB, 'user_id' => 5, 'status' => 'active']);

        // Teacher 2 tries to access Student 5's report card: MUST throw 403 Forbidden!
        $this->expectException(ApiError::class);
        $this->expectExceptionMessage('You cannot view this student\'s report card');
        EduReportCard::generateData($this->teacherAuth, 5);
    }

    /** TASK 15: Verify Complete Assignment Submission, Resubmission & Grading Lifecycle */
    public function test_complete_assignment_submission_lifecycle_and_version_history(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Grade 12 Lifecycle', 'grade' => 12]);
        $courseId = DB::table('edu_courses')->insertGetId(['class_id' => $classId, 'name' => 'Theology 12']);
        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => 3, 'status' => 'active']);
        DB::table('edu_course_teachers')->insert(['course_id' => $courseId, 'user_id' => 2, 'status' => 'active']);

        $assignmentId = DB::table('edu_assignments')->insertGetId([
            'course_id' => $courseId,
            'teacher_id' => 2,
            'title' => 'Comprehensive Liturgy Paper',
            'max_score' => 100.0,
            'status' => 'published',
            'allow_late' => true,
            'allow_resubmit' => true,
        ]);

        // 1. Initial Submission: text only
        $sub1 = EduAssignments::submit($this->studentAuth, $assignmentId, ['text_response' => 'First Draft']);
        $this->assertEquals('submitted', $sub1['status']);
        $this->assertEquals('First Draft', $sub1['text_response']);

        // 2. Resubmission: update text
        $sub2 = EduAssignments::submit($this->studentAuth, $assignmentId, ['text_response' => 'Final Revised Paper']);
        $this->assertEquals('resubmitted', $sub2['status']);
        $this->assertEquals('Final Revised Paper', $sub2['text_response']);

        // Verify version history: 2 versions stored in edu_submission_versions
        $detail = EduAssignments::studentDetail($this->studentAuth, $assignmentId);
        $this->assertNotEmpty($detail['my_submission']);
        $this->assertCount(2, $detail['my_submission']['versions']);

        // 3. Teacher Grades submission
        $graded = EduAssignments::gradeSubmission($this->adminActx, $sub2['id'], 95.0, 'Excellent revision!', true);
        $this->assertEquals(95.0, $graded['score']);
        $this->assertEquals('returned', $graded['status']);
        $this->assertEquals('Excellent revision!', $graded['feedback']);

        // Verify edu_submissions synchronized
        $legacy = DB::table('edu_submissions')->where(['assignment_id' => $assignmentId, 'user_id' => 3])->first();
        $this->assertNotNull($legacy);
        $this->assertEquals(95.0, (float) $legacy->score);
        $this->assertEquals('Excellent revision!', $legacy->feedback);
    }
}
