<?php

namespace Tests\Unit;

use App\Mz\Services\EduCurriculumImport;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EduCurriculumImportTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();
    }

    private function setUpSchema(): void
    {
        Schema::dropIfExists('edu_lessons');
        Schema::dropIfExists('edu_units');
        Schema::dropIfExists('edu_courses');
        Schema::dropIfExists('edu_classes');
        Schema::dropIfExists('edu_subjects');
        Schema::dropIfExists('edu_categories');

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

        Schema::create('edu_classes', function ($table) {
            $table->increments('id');
            $table->string('name', 100);
            $table->string('description', 255)->nullable();
            $table->string('term', 50)->nullable();
            $table->unsignedInteger('level_id')->nullable();
            $table->string('status', 20)->default('active');
            $table->timestamps();
        });

        Schema::create('edu_courses', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('class_id');
            $table->unsignedInteger('subject_id')->nullable();
            $table->string('name', 150);
            $table->string('status', 20)->default('active');
            $table->timestamps();
        });

        Schema::create('edu_units', function ($table) {
            $table->increments('id');
            $table->unsignedInteger('subject_id');
            $table->string('title', 200);
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
            $table->longText('body')->nullable();
            $table->integer('sort_order')->default(0);
            $table->string('status', 20)->default('published');
            $table->timestamps();
        });

        // Seed Class 1 (7ኛ) and 6 legacy courses
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
    }

    public function test_category_resolution_maps_authentic_theological_disciplines(): void
    {
        $this->assertEquals(1, EduCurriculumImport::resolveCategoryId('መሠረተ ሃይማኖት'));
        $this->assertEquals(1, EduCurriculumImport::resolveCategoryId('ኦርቶዶክሳዊ የስብከት ዘዴ'));
        $this->assertEquals(4, EduCurriculumImport::resolveCategoryId('የመጽሐፍ ቅዱስ ታሪክ'));
        $this->assertEquals(4, EduCurriculumImport::resolveCategoryId('የመጻሕፍት ሊቃውንት መግቢያ 1'));
        $this->assertEquals(5, EduCurriculumImport::resolveCategoryId('ክርስቲያናዊ ሥነ ምግባር'));
        $this->assertEquals(5, EduCurriculumImport::resolveCategoryId('ኦርቶዶክሳዊ የጾታ ትምህርት ሀ'));
        $this->assertEquals(5, EduCurriculumImport::resolveCategoryId('ሥነ ልቡና መግቢያ'));
        $this->assertEquals(6, EduCurriculumImport::resolveCategoryId('ሥርዓተ ቤተክርስቲያን'));
        $this->assertEquals(6, EduCurriculumImport::resolveCategoryId('ምሥጢራተ ቤተ ክርስቲያን'));
        $this->assertEquals(6, EduCurriculumImport::resolveCategoryId('የቤተክርስቲያን አስተዳደር'));
        $this->assertEquals(3, EduCurriculumImport::resolveCategoryId('የቤተ ክርስቲያን ታሪክ'));
        $this->assertEquals(3, EduCurriculumImport::resolveCategoryId('ፍልስፍና መግቢያ'));
        $this->assertEquals(7, EduCurriculumImport::resolveCategoryId('ግእዝ'));
        $this->assertEquals(8, EduCurriculumImport::resolveCategoryId('ዜማ'));
    }

    public function test_curriculum_import_dry_run_validates_12_grades_and_leaves_db_untouched(): void
    {
        $summary = EduCurriculumImport::import(dryRun: true);

        $this->assertTrue($summary['dry_run']);
        $this->assertEquals(12, $summary['grades_processed']);
        $this->assertEquals(81, $summary['subjects_created']);
        $this->assertEquals(415, $summary['units_created']);
        $this->assertEquals(2951, $summary['lessons_created']);
        $this->assertEquals(6, $summary['legacy_courses_mapped']);

        // Assert zero database rows created during dry run
        $this->assertEquals(0, DB::table('edu_subjects')->count());
        $this->assertEquals(0, DB::table('edu_units')->count());
        $this->assertEquals(0, DB::table('edu_lessons')->count());
    }

    public function test_curriculum_import_is_idempotent_and_maps_legacy_courses(): void
    {
        // First Run: Live import
        $firstRun = EduCurriculumImport::import(dryRun: false);

        $this->assertFalse($firstRun['dry_run']);
        $this->assertEquals(12, $firstRun['grades_processed']);
        $this->assertEquals(81, $firstRun['subjects_created']);
        $this->assertEquals(0, $firstRun['subjects_updated']);
        $this->assertEquals(81, DB::table('edu_subjects')->count());

        // Verify that Class 1 (7ኛ) courses are linked to canonical Grade 7 subjects
        $course1 = DB::table('edu_courses')->where('id', 1)->first();
        $this->assertNotNull($course1->subject_id);
        $mappedSubject = DB::table('edu_subjects')->where('id', $course1->subject_id)->first();
        $this->assertStringContainsString('መሠረተ ሃይማኖት', $mappedSubject->name);

        // Second Run: Idempotency assertion
        $secondRun = EduCurriculumImport::import(dryRun: false);

        $this->assertEquals(0, $secondRun['subjects_created'], 'Second run must not create duplicate subjects');
        $this->assertEquals(81, $secondRun['subjects_updated'], 'Second run must update existing subjects');
        $this->assertEquals(81, DB::table('edu_subjects')->count(), 'Subject count must remain exactly 81');
    }
}
