<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Edu;
use App\Mz\Services\EduAcademicYears;
use App\Mz\Services\EduCurriculumImport;
use App\Mz\Services\EduLearning;
use App\Mz\Support\ApiError;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EducationCurriculumClassArchitectureTest extends TestCase
{
    private array $actx;
    private AuthContext $auth;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->auth = new AuthContext();
        $this->auth->id = 1;
        $this->auth->fullName = 'Admin User';
        $this->auth->status = 'active';
        $this->auth->accountType = 'admin';
        $this->auth->tokenVersion = 1;
        $this->auth->mustChangePassword = false;
        $this->auth->isAdmin = true;
        $this->auth->isSystem = true;
        $this->auth->isMemberStaff = false;
        $this->auth->level = 100;
        $this->auth->permissions = ['education.manage' => true, 'education.content' => true, 'education.register' => true];
        $this->actx = ['auth' => $this->auth];
    }

    private function setUpSchema(): void
    {
        Schema::dropIfExists('edu_scores');
        Schema::dropIfExists('edu_assessments');
        Schema::dropIfExists('edu_assignments');
        Schema::dropIfExists('edu_course_teachers');
        Schema::dropIfExists('edu_course_enrollments');
        Schema::dropIfExists('edu_enrollments');
        Schema::dropIfExists('edu_schedule');
        Schema::dropIfExists('edu_class_staff');
        Schema::dropIfExists('program_edu_courses');
        Schema::dropIfExists('edu_courses');
        Schema::dropIfExists('edu_lesson_materials');
        Schema::dropIfExists('edu_lesson_progress');
        Schema::dropIfExists('edu_lessons');
        Schema::dropIfExists('edu_units');
        Schema::dropIfExists('edu_subjects');
        Schema::dropIfExists('edu_categories');
        Schema::dropIfExists('edu_classes');
        Schema::dropIfExists('edu_terms');
        Schema::dropIfExists('edu_academic_years');
        Schema::dropIfExists('edu_levels');
        Schema::dropIfExists('audit_logs');
        Schema::dropIfExists('users');

        Schema::create('users', function ($table) {
            $table->increments('id');
            $table->string('full_name', 150);
            $table->string('phone', 30)->nullable();
            $table->string('account_type', 30)->default('member');
            $table->string('status', 30)->default('active');
            $table->timestamp('deleted_at')->nullable();
            $table->timestamps();
        });

        Schema::create('audit_logs', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('user_id')->nullable();
            $table->string('action', 50);
            $table->string('entity_type', 50);
            $table->unsignedInteger('entity_id')->nullable();
            $table->text('details')->nullable();
            $table->timestamps();
        });

        Schema::create('edu_academic_years', function ($table) {
            $table->increments('id');
            $table->integer('eth_year')->unique();
            $table->string('name', 100);
            $table->date('starts_on')->nullable();
            $table->date('ends_on')->nullable();
            $table->string('status', 20)->default('active');
            $table->boolean('is_current')->default(false);
            $table->unsignedInteger('created_by')->nullable();
            $table->timestamps();
        });

        Schema::create('edu_terms', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('academic_year_id');
            $table->string('name', 100);
            $table->integer('sort_order')->default(0);
            $table->date('starts_on')->nullable();
            $table->date('ends_on')->nullable();
            $table->string('status', 20)->default('active');
            $table->timestamps();
        });

        Schema::create('edu_levels', function ($table) {
            $table->increments('id');
            $table->string('code', 20)->unique();
            $table->string('name', 100);
            $table->string('name_en', 100)->nullable();
            $table->string('kind', 20)->default('grade');
            $table->integer('sort_order')->default(0);
            $table->boolean('is_active')->default(true);
            $table->boolean('built_in')->default(false);
            $table->timestamps();
        });

        Schema::create('edu_classes', function ($table) {
            $table->increments('id');
            $table->string('name', 150);
            $table->string('name_en', 150)->nullable();
            $table->text('description')->nullable();
            $table->text('description_en')->nullable();
            $table->string('term', 80)->nullable();
            $table->string('academic_year', 20)->nullable();
            $table->string('semester', 40)->nullable();
            $table->unsignedInteger('department_id')->nullable();
            $table->unsignedInteger('academic_year_id')->nullable();
            $table->unsignedInteger('term_id')->nullable();
            $table->unsignedInteger('level_id')->nullable();
            $table->string('streams', 255)->nullable();
            $table->dateTime('registration_opens_at')->nullable();
            $table->dateTime('registration_closes_at')->nullable();
            $table->boolean('allow_regular')->default(true);
            $table->boolean('allow_distance')->default(true);
            $table->boolean('allow_self_registration')->default(false);
            $table->boolean('allow_multiple')->default(false);
            $table->unsignedInteger('capacity')->nullable();
            $table->string('status', 20)->default('active');
            $table->unsignedInteger('created_by')->nullable();
            $table->timestamps();
        });

        Schema::create('edu_categories', function ($table) {
            $table->increments('id');
            $table->string('name', 150);
            $table->string('name_en', 150)->nullable();
            $table->string('icon_key', 40)->nullable();
            $table->integer('sort_order')->default(0);
            $table->string('status', 20)->default('active');
            $table->timestamps();
        });

        Schema::create('edu_subjects', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('category_id')->nullable();
            $table->unsignedTinyInteger('grade')->nullable();
            $table->string('name', 150);
            $table->string('name_en', 150)->nullable();
            $table->string('code', 30)->nullable();
            $table->text('description')->nullable();
            $table->text('objectives')->nullable();
            $table->string('visibility', 20)->default('members');
            $table->boolean('sequential')->default(false);
            $table->string('status', 20)->default('published');
            $table->integer('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('edu_units', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('subject_id');
            $table->string('title', 200);
            $table->string('title_en', 200)->nullable();
            $table->text('description')->nullable();
            $table->integer('sort_order')->default(0);
            $table->string('status', 20)->default('published');
            $table->timestamps();
        });

        Schema::create('edu_lessons', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('subject_id');
            $table->unsignedInteger('unit_id')->nullable();
            $table->string('title', 200);
            $table->string('title_en', 200)->nullable();
            $table->text('summary')->nullable();
            $table->longText('body')->nullable();
            $table->text('objectives')->nullable();
            $table->integer('sort_order')->default(0);
            $table->string('status', 20)->default('published');
            $table->timestamp('published_at')->nullable();
            $table->timestamps();
        });

        Schema::create('edu_courses', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('class_id');
            $table->unsignedInteger('subject_id')->nullable();
            $table->string('name', 150);
            $table->string('code', 30)->nullable();
            $table->text('description')->nullable();
            $table->unsignedInteger('teacher_user_id')->nullable();
            $table->unsignedInteger('term_id')->nullable();
            $table->string('member_groups', 255)->nullable();
            $table->string('mode', 20)->default('physical');
            $table->decimal('pass_mark', 5, 2)->default(50.0);
            $table->integer('progress')->default(0);
            $table->date('completed_at')->nullable();
            $table->string('status', 20)->default('active');
            $table->timestamps();
        });

        Schema::create('edu_course_teachers', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('course_id');
            $table->unsignedInteger('user_id');
            $table->string('status', 20)->default('active');
            $table->boolean('is_primary')->default(false);
            $table->text('note')->nullable();
            $table->timestamps();
        });

        Schema::create('edu_enrollments', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('class_id');
            $table->unsignedInteger('user_id');
            $table->unsignedInteger('academic_year_id')->nullable();
            $table->boolean('exclusive')->default(true);
            $table->string('program', 20)->default('regular');
            $table->string('stream', 80)->nullable();
            $table->string('status', 20)->default('active');
            $table->timestamps();
        });

        Schema::create('edu_course_enrollments', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('course_id');
            $table->unsignedInteger('user_id');
            $table->string('status', 20)->default('enrolled');
            $table->timestamps();
        });

        Schema::create('edu_schedule', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('class_id');
            $table->unsignedInteger('course_id')->nullable();
            $table->tinyInteger('weekday');
            $table->string('frequency', 20)->default('weekly');
            $table->tinyInteger('week_of_month')->nullable();
            $table->string('program', 20)->default('all');
            $table->string('mode', 20)->default('in_person');
            $table->string('starts', 10);
            $table->string('ends', 10);
            $table->string('location', 150)->nullable();
        });

        Schema::create('edu_class_staff', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('class_id');
            $table->unsignedInteger('user_id');
            $table->timestamps();
        });

        Schema::create('program_edu_courses', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('program_id');
            $table->unsignedInteger('course_id');
            $table->timestamps();
        });
    }

    public function test_canonical_grades_and_curriculum_import(): void
    {
        EduAcademicYears::ensureCanonicalGrades();
        $levels = DB::table('edu_levels')->where('kind', 'grade')->orderBy('sort_order')->get();
        $this->assertCount(12, $levels);

        $summary = EduCurriculumImport::import(false);
        $this->assertEquals(12, $summary['grades_processed']);
        $this->assertGreaterThan(50, $summary['subjects_created']);

        // Verify Grade 7 curriculum subjects
        $g7Subjects = DB::table('edu_subjects')->where('grade', 7)->get();
        $this->assertCount(7, $g7Subjects);
    }

    public function test_class_creation_auto_connects_to_curriculum(): void
    {
        EduAcademicYears::ensureCanonicalGrades();
        EduCurriculumImport::import(false);

        $yearId = DB::table('edu_academic_years')->insertGetId([
            'eth_year' => 2017,
            'name' => '2017 ዓ.ም',
            'is_current' => 1,
            'status' => 'active',
        ]);

        $g7Level = DB::table('edu_levels')->where('sort_order', 7)->first();

        // Create class for Grade 7
        $class = Edu::createClass($this->actx, [
            'name' => '7ኛ ክፍል',
            'name_en' => 'Grade 7',
            'academic_year_id' => $yearId,
            'level_id' => $g7Level->id,
            'allow_regular' => true,
            'allow_distance' => true,
        ]);

        $this->assertNotEmpty($class['id']);
        $this->assertEquals('7ኛ ክፍል', $class['name']);
        $this->assertTrue($class['curriculum']['is_connected']);
        $this->assertEquals(7, $class['curriculum']['grade']);
        $this->assertCount(7, $class['courses']);

        // Verify each course links directly to a curriculum subject without duplication
        foreach ($class['courses'] as $course) {
            $this->assertNotNull($course['subject_id']);
            $this->assertNotEmpty($course['curriculum_subject']);
            $this->assertGreaterThan(0, $course['curriculum_subject']['units_count']);
            $this->assertGreaterThan(0, $course['curriculum_subject']['lessons_count']);
        }
    }

    public function test_prevent_duplicate_class_creation_for_same_grade_and_academic_year(): void
    {
        EduAcademicYears::ensureCanonicalGrades();
        EduCurriculumImport::import(false);

        $yearId = DB::table('edu_academic_years')->insertGetId([
            'eth_year' => 2017,
            'name' => '2017 ዓ.ም',
            'is_current' => 1,
            'status' => 'active',
        ]);

        $g7Level = DB::table('edu_levels')->where('sort_order', 7)->first();

        Edu::createClass($this->actx, [
            'name' => '7ኛ ክፍል',
            'academic_year_id' => $yearId,
            'level_id' => $g7Level->id,
        ]);

        $this->expectException(ApiError::class);
        Edu::createClass($this->actx, [
            'name' => '7ኛ ክፍል ሌላ',
            'academic_year_id' => $yearId,
            'level_id' => $g7Level->id,
        ]);
    }

    public function test_ensure_all_12_grade_classes_established_without_duplication(): void
    {
        EduAcademicYears::ensureCanonicalGrades();
        EduCurriculumImport::import(false);

        $yearId = DB::table('edu_academic_years')->insertGetId([
            'eth_year' => 2017,
            'name' => '2017 ዓ.ም',
            'is_current' => 1,
            'status' => 'active',
        ]);

        // Run ensureGradeClasses
        $res = Edu::ensureGradeClasses($yearId);
        $this->assertEquals(12, $res['total_grades']);

        $classes = DB::table('edu_classes')->where('academic_year_id', $yearId)->get();
        $this->assertCount(12, $classes);

        // Run second time (idempotent - zero duplicates)
        $res2 = Edu::ensureGradeClasses($yearId);
        $this->assertEquals(12, $res2['total_grades']);
        $classesAfter = DB::table('edu_classes')->where('academic_year_id', $yearId)->get();
        $this->assertCount(12, $classesAfter);
    }

    public function test_curriculum_preview_api(): void
    {
        EduAcademicYears::ensureCanonicalGrades();
        EduCurriculumImport::import(false);

        $g7Level = DB::table('edu_levels')->where('sort_order', 7)->first();
        $preview = Edu::curriculumPreview($g7Level->id);

        $this->assertTrue($preview['has_curriculum']);
        $this->assertEquals(7, $preview['grade']);
        $this->assertEquals(7, $preview['total_subjects']);
        $this->assertCount(7, $preview['subjects']);
        $this->assertGreaterThan(0, $preview['subjects'][0]['units_count']);
        $this->assertGreaterThan(0, $preview['subjects'][0]['lessons_count']);
    }

    public function test_student_and_teacher_curriculum_access(): void
    {
        EduAcademicYears::ensureCanonicalGrades();
        EduCurriculumImport::import(false);

        $yearId = DB::table('edu_academic_years')->insertGetId([
            'eth_year' => 2017,
            'name' => '2017 ዓ.ም',
            'is_current' => 1,
            'status' => 'active',
        ]);

        $g7Level = DB::table('edu_levels')->where('sort_order', 7)->first();
        $class = Edu::createClass($this->actx, [
            'name' => '7ኛ ክፍል',
            'academic_year_id' => $yearId,
            'level_id' => $g7Level->id,
        ]);

        $studentId = DB::table('users')->insertGetId(['full_name' => 'Abebe Student', 'status' => 'active']);
        $teacherId = DB::table('users')->insertGetId(['full_name' => 'Teacher Samuel', 'status' => 'active']);

        // Enroll student in Grade 7 class
        DB::table('edu_enrollments')->insert([
            'class_id' => $class['id'],
            'user_id' => $studentId,
            'academic_year_id' => $yearId,
            'status' => 'active',
        ]);

        // Student assigned grades automatically includes Grade 7
        $assignedGrades = EduLearning::studentAssignedGrades($studentId);
        $this->assertContains(7, $assignedGrades);

        // Student has access to curriculum subject of Grade 7
        $sub1 = DB::table('edu_subjects')->where('grade', 7)->first();
        $this->assertTrue(EduLearning::isEnrolledInSubject($studentId, $sub1->id));

        // Assign teacher to course 1
        $c1 = $class['courses'][0];
        DB::table('edu_courses')->where('id', $c1['id'])->update(['teacher_user_id' => $teacherId]);
        DB::table('edu_course_teachers')->insert([
            'course_id' => $c1['id'],
            'user_id' => $teacherId,
            'status' => 'active',
            'is_primary' => true,
        ]);

        // Teacher teaching subject ids includes the curriculum subject
        $teacherSubIds = EduLearning::teachingSubjectIds($teacherId);
        $this->assertContains((int) $c1['subject_id'], $teacherSubIds);
    }
}

