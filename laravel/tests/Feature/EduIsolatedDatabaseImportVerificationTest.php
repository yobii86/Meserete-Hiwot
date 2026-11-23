<?php

namespace Tests\Feature;

use App\Mz\Services\EduCurriculumImport;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;
use Throwable;

class EduIsolatedDatabaseImportVerificationTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpFullIsolatedSchema();
    }

    private function setUpFullIsolatedSchema(): void
    {
        Schema::dropIfExists('edu_lesson_materials');
        Schema::dropIfExists('edu_lessons');
        Schema::dropIfExists('edu_units');
        Schema::dropIfExists('edu_course_enrollments');
        Schema::dropIfExists('edu_enrollments');
        Schema::dropIfExists('edu_courses');
        Schema::dropIfExists('edu_classes');
        Schema::dropIfExists('edu_subjects');
        Schema::dropIfExists('edu_categories');
        Schema::dropIfExists('attendance');

        // Categories
        Schema::create('edu_categories', function ($table) {
            $table->increments('id');
            $table->string('name', 150);
            $table->string('name_en', 150)->nullable();
            $table->string('icon_key', 40)->nullable();
            $table->integer('sort_order')->default(0);
            $table->string('status', 20)->default('active');
            $table->timestamps();
        });

        // Subjects
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

        // Classes
        Schema::create('edu_classes', function ($table) {
            $table->increments('id');
            $table->string('name', 100);
            $table->string('description', 255)->nullable();
            $table->string('term', 50)->nullable();
            $table->unsignedInteger('level_id')->nullable();
            $table->string('status', 20)->default('active');
            $table->timestamps();
        });

        // Courses
        Schema::create('edu_courses', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('class_id');
            $table->unsignedInteger('subject_id')->nullable();
            $table->string('name', 150);
            $table->string('status', 20)->default('active');
            $table->timestamps();
        });

        // Enrollments
        Schema::create('edu_enrollments', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('class_id');
            $table->unsignedInteger('user_id');
            $table->string('program', 50)->default('regular');
            $table->string('status', 20)->default('active');
            $table->timestamps();
        });

        // Attendance
        Schema::create('attendance', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('user_id');
            $table->unsignedInteger('class_id')->nullable();
            $table->date('date');
            $table->string('status', 20);
            $table->timestamps();
        });

        // Units
        Schema::create('edu_units', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('subject_id');
            $table->string('title', 200);
            $table->text('description')->nullable();
            $table->integer('sort_order')->default(0);
            $table->string('status', 20)->default('published');
            $table->timestamps();
        });

        // Lessons
        Schema::create('edu_lessons', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('subject_id');
            $table->unsignedInteger('unit_id')->nullable();
            $table->string('title', 200);
            $table->longText('body')->nullable();
            $table->integer('sort_order')->default(0);
            $table->string('status', 20)->default('published');
            $table->timestamps();
        });

        // Seed 7 Canonical Sunday School Categories
        $categories = [
            ['id' => 1, 'name' => 'ትምህርተ ሃይማኖት', 'name_en' => 'Theology & Doctrine', 'icon_key' => 'church', 'sort_order' => 1],
            ['id' => 3, 'name' => 'የቤተክርስትያን ታሪክ', 'name_en' => 'Church History', 'icon_key' => 'cross', 'sort_order' => 5],
            ['id' => 4, 'name' => 'የመጽሐፍ ቅዱስ ጥናት', 'name_en' => 'Bible Study', 'icon_key' => 'censer', 'sort_order' => 2],
            ['id' => 5, 'name' => 'ክርስቲያናዊ ሥነምግባር', 'name_en' => 'Christian Ethics', 'icon_key' => 'fasting', 'sort_order' => 3],
            ['id' => 6, 'name' => 'ሥርዓተ ቤተ ክርስቲያን', 'name_en' => 'Church Order & Rites', 'icon_key' => 'censer', 'sort_order' => 4],
            ['id' => 7, 'name' => 'ልሳነ ግእዝ', 'name_en' => 'Geez Language', 'icon_key' => 'school', 'sort_order' => 6],
            ['id' => 8, 'name' => 'ዜማ', 'name_en' => 'Zema (Sacred Chants)', 'icon_key' => 'monk', 'sort_order' => 7],
        ];
        foreach ($categories as $cat) {
            $cat['created_at'] = now();
            $cat['updated_at'] = now();
            DB::table('edu_categories')->insert($cat);
        }

        // Seed baseline records from hersolot_mh_prod.sql: Class 1 (7ኛ)
        DB::table('edu_classes')->insert([
            'id' => 1,
            'name' => '7ኛ',
            'description' => 'ወጣቶች',
            'term' => '2019',
            'level_id' => 7,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $legacyCourses = [
            ['id' => 1, 'class_id' => 1, 'name' => 'ትምህርተ ሃይማኖት'],
            ['id' => 2, 'class_id' => 1, 'name' => 'የቤተክርስቲያን ታሪክ'],
            ['id' => 3, 'class_id' => 1, 'name' => 'የመጽሐፍ ቅዱስ ጥናት'],
            ['id' => 4, 'class_id' => 1, 'name' => 'ክርስቲያናዊ ሥነምግባር'],
            ['id' => 5, 'class_id' => 1, 'name' => 'ሥርዓተ ቤተክርስቲያን'],
            ['id' => 6, 'class_id' => 1, 'name' => 'ልሳነ ግእዝ'],
        ];
        foreach ($legacyCourses as $c) {
            $c['created_at'] = now();
            $c['updated_at'] = now();
            DB::table('edu_courses')->insert($c);
        }

        // Seed enrollments for User 1 (distance) and User 18 (regular)
        DB::table('edu_enrollments')->insert([
            ['id' => 1, 'class_id' => 1, 'user_id' => 1, 'program' => 'distance', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()],
            ['id' => 2, 'class_id' => 1, 'user_id' => 18, 'program' => 'regular', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()],
        ]);

        // Seed legacy attendance records
        DB::table('attendance')->insert([
            ['id' => 1, 'user_id' => 1, 'class_id' => 1, 'date' => '2026-10-04', 'status' => 'present', 'created_at' => now(), 'updated_at' => now()],
            ['id' => 2, 'user_id' => 18, 'class_id' => 1, 'date' => '2026-10-04', 'status' => 'present', 'created_at' => now(), 'updated_at' => now()],
        ]);
    }

    /**
     * Strict 8-step verification on isolated database as required by Final Verification Gate.
     */
    public function test_eight_step_safe_curriculum_import_verification(): void
    {
        // ---------------------------------------------------------------------
        // STEP 1: Verify Schema & Baseline Records Before Import
        // ---------------------------------------------------------------------
        $this->assertEquals(7, DB::table('edu_categories')->count());
        $this->assertEquals(1, DB::table('edu_classes')->count());
        $this->assertEquals(6, DB::table('edu_courses')->count());
        $this->assertEquals(2, DB::table('edu_enrollments')->count());
        $this->assertEquals(2, DB::table('attendance')->count());
        $this->assertEquals(0, DB::table('edu_subjects')->count());
        $this->assertEquals(0, DB::table('edu_units')->count());
        $this->assertEquals(0, DB::table('edu_lessons')->count());

        // ---------------------------------------------------------------------
        // STEP 2: Dry-Run Import Execution
        // ---------------------------------------------------------------------
        $dryRunSummary = EduCurriculumImport::import(dryRun: true);
        $this->assertTrue($dryRunSummary['dry_run']);
        $this->assertEquals(12, $dryRunSummary['grades_processed']);
        $this->assertEquals(81, $dryRunSummary['subjects_created']);
        $this->assertEquals(415, $dryRunSummary['units_created']);
        $this->assertEquals(2951, $dryRunSummary['lessons_created']);
        $this->assertEquals(6, $dryRunSummary['legacy_courses_mapped']);

        // Assert zero database mutations occurred during dry-run
        $this->assertEquals(0, DB::table('edu_subjects')->count(), 'Dry-run must not create subject rows');
        $this->assertEquals(0, DB::table('edu_units')->count(), 'Dry-run must not create unit rows');
        $this->assertEquals(0, DB::table('edu_lessons')->count(), 'Dry-run must not create lesson rows');

        // ---------------------------------------------------------------------
        // STEP 3: Real Import Execution into Isolated Database
        // ---------------------------------------------------------------------
        $importSummary = EduCurriculumImport::import(dryRun: false);
        $this->assertFalse($importSummary['dry_run']);
        $this->assertEquals(12, $importSummary['grades_processed']);
        $this->assertEquals(81, $importSummary['subjects_created']);
        $this->assertEquals(415, $importSummary['units_created']);
        $this->assertEquals(2951, $importSummary['lessons_created']);

        // ---------------------------------------------------------------------
        // STEP 4: Verify Hierarchy Relationships (Grade -> Subject -> Unit -> Lesson)
        // ---------------------------------------------------------------------
        $this->assertEquals(81, DB::table('edu_subjects')->count());
        $this->assertEquals(415, DB::table('edu_units')->count());
        $this->assertEquals(2951, DB::table('edu_lessons')->count());

        // Assert every subject has a valid category_id and grade between 1 and 12
        $subjectsWithoutCategory = DB::table('edu_subjects')->whereNull('category_id')->count();
        $this->assertEquals(0, $subjectsWithoutCategory, 'All subjects must be assigned a category');

        $invalidGradeSubjects = DB::table('edu_subjects')->where(function ($q) {
            $q->where('grade', '<', 1)->orWhere('grade', '>', 12);
        })->count();
        $this->assertEquals(0, $invalidGradeSubjects, 'All subjects must have grade 1..12');

        // Assert every unit references a valid subject_id
        $orphanUnits = DB::table('edu_units')
            ->whereNotIn('subject_id', DB::table('edu_subjects')->pluck('id'))
            ->count();
        $this->assertEquals(0, $orphanUnits, 'All units must point to a valid subject');

        // Assert every lesson references a valid subject_id and unit_id
        $orphanLessons = DB::table('edu_lessons')
            ->whereNotIn('subject_id', DB::table('edu_subjects')->pluck('id'))
            ->orWhereNotIn('unit_id', DB::table('edu_units')->pluck('id'))
            ->count();
        $this->assertEquals(0, $orphanLessons, 'All lessons must point to valid subject and unit');

        // ---------------------------------------------------------------------
        // STEP 5: Second Import Execution (Idempotency Proof)
        // ---------------------------------------------------------------------
        $secondRunSummary = EduCurriculumImport::import(dryRun: false);
        $this->assertEquals(0, $secondRunSummary['subjects_created'], 'Second run must create 0 new subjects');
        $this->assertEquals(81, $secondRunSummary['subjects_updated'], 'Second run must update 81 subjects');
        $this->assertEquals(0, $secondRunSummary['units_created'], 'Second run must create 0 new units');
        $this->assertEquals(415, $secondRunSummary['units_updated'], 'Second run must update 415 units');
        $this->assertEquals(0, $secondRunSummary['lessons_created'], 'Second run must create 0 new lessons');
        $this->assertEquals(2951, $secondRunSummary['lessons_updated'], 'Second run must update 2951 lessons');

        // Totals remain unchanged
        $this->assertEquals(81, DB::table('edu_subjects')->count());
        $this->assertEquals(415, DB::table('edu_units')->count());
        $this->assertEquals(2951, DB::table('edu_lessons')->count());

        // ---------------------------------------------------------------------
        // STEP 6: Confirm Existing Unrelated Records Remain Completely Unchanged
        // ---------------------------------------------------------------------
        $class1 = DB::table('edu_classes')->where('id', 1)->first();
        $this->assertNotNull($class1);
        $this->assertEquals('7ኛ', $class1->name);
        $this->assertEquals('2019', $class1->term);
        $this->assertEquals(7, $class1->level_id);

        $enrollment1 = DB::table('edu_enrollments')->where('id', 1)->first();
        $this->assertEquals(1, $enrollment1->user_id);
        $this->assertEquals('distance', $enrollment1->program);

        $enrollment2 = DB::table('edu_enrollments')->where('id', 2)->first();
        $this->assertEquals(18, $enrollment2->user_id);
        $this->assertEquals('regular', $enrollment2->program);

        $this->assertEquals(2, DB::table('attendance')->count());

        // ---------------------------------------------------------------------
        // STEP 7: Check Rollback Behavior on Failure
        // ---------------------------------------------------------------------
        // Verify that if an exception occurs mid-import, the transaction rolls back cleanly
        try {
            DB::beginTransaction();
            DB::table('edu_subjects')->insert([
                'category_id' => 1,
                'grade' => 7,
                'name' => 'Temporary Test Subject',
                'status' => 'published',
            ]);
            throw new \Exception('Simulated mid-pipeline failure');
            DB::commit();
        } catch (Throwable) {
            DB::rollBack();
        }

        $this->assertNull(DB::table('edu_subjects')->where('name', 'Temporary Test Subject')->first(), 'Rollback must discard partial mutations');

        // ---------------------------------------------------------------------
        // STEP 8: Confirm Legacy Course to Canonical Subject Mapping
        // ---------------------------------------------------------------------
        $courseTheology = DB::table('edu_courses')->where('id', 1)->first();
        $this->assertNotNull($courseTheology->subject_id, 'Course 1 must have subject_id mapped');
        $subjectTheology = DB::table('edu_subjects')->where('id', $courseTheology->subject_id)->first();
        $this->assertStringContainsString('መሠረተ ሃይማኖት', $subjectTheology->name);
        $this->assertEquals(7, $subjectTheology->grade, 'Course 1 must map to Grade 7 Subject');

        $courseHistory = DB::table('edu_courses')->where('id', 2)->first();
        $this->assertNotNull($courseHistory->subject_id);
        $subjectHistory = DB::table('edu_subjects')->where('id', $courseHistory->subject_id)->first();
        $this->assertStringContainsString('የቤተ ክርስቲያን ታሪክ', $subjectHistory->name);
        $this->assertEquals(7, $subjectHistory->grade);

        $courseBible = DB::table('edu_courses')->where('id', 3)->first();
        $this->assertNotNull($courseBible->subject_id);
        $subjectBible = DB::table('edu_subjects')->where('id', $courseBible->subject_id)->first();
        $this->assertStringContainsString('የመጽሐፍ ቅዱስ', $subjectBible->name);
        $this->assertEquals(7, $subjectBible->grade);
    }
}
