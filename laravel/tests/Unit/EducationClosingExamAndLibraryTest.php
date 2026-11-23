<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\EduLearning;
use App\Mz\Services\EduQuizzes;
use App\Mz\Services\Items;
use App\Mz\Services\Library;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EducationClosingExamAndLibraryTest extends TestCase
{
    private AuthContext $adminAuth;
    private array $adminActx;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = new AuthContext();
        $this->adminAuth->id = 1;
        $this->adminAuth->fullName = 'Education Admin';
        $this->adminAuth->status = 'active';
        $this->adminAuth->accountType = 'admin';
        $this->adminAuth->tokenVersion = 1;
        $this->adminAuth->mustChangePassword = false;
        $this->adminAuth->isAdmin = true;
        $this->adminAuth->isSystem = false;
        $this->adminAuth->isMemberStaff = false;
        $this->adminAuth->level = 100;
        $this->adminAuth->permissions = [
            'education.manage' => true,
            'education.exams' => true,
            'education.quizzes' => true,
            'education.materials' => true,
            'items.manage' => true,
            'library.circulate' => true,
        ];

        $this->adminActx = [
            'auth' => $this->adminAuth,
            'ip' => '127.0.0.1',
            'userAgent' => 'PHPUnit',
            'requestId' => 'req-' . uniqid(),
            'source' => 'web',
            'offset' => 0,
        ];
    }

    private function setUpSchema(): void
    {
        Schema::dropIfExists('edu_quiz_draws');
        Schema::dropIfExists('edu_quiz_attempts');
        Schema::dropIfExists('edu_quiz_questions');
        Schema::dropIfExists('edu_quizzes');
        Schema::dropIfExists('edu_assessments');
        Schema::dropIfExists('edu_lesson_materials');
        Schema::dropIfExists('edu_lessons');
        Schema::dropIfExists('edu_units');
        Schema::dropIfExists('edu_courses');
        Schema::dropIfExists('edu_classes');
        Schema::dropIfExists('edu_subjects');
        Schema::dropIfExists('items');
        Schema::dropIfExists('users');
        Schema::dropIfExists('edu_enrollments');
        Schema::dropIfExists('edu_course_enrollments');

        Schema::dropIfExists('departments');
        Schema::dropIfExists('item_categories');

        DB::statement('CREATE TABLE departments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(100) NOT NULL,
            name_en VARCHAR(100) NULL,
            code VARCHAR(10) NULL
        )');

        DB::statement('CREATE TABLE item_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key VARCHAR(50) UNIQUE NOT NULL,
            name VARCHAR(100) NOT NULL,
            name_en VARCHAR(100) NULL
        )');

        DB::statement('CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name VARCHAR(100) NOT NULL,
            phone VARCHAR(20) NULL,
            status VARCHAR(20) NOT NULL DEFAULT "active",
            deleted_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_enrollments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            class_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT "active",
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_course_enrollments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            course_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT "enrolled",
            created_at DATETIME NULL,
            updated_at DATETIME NULL
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

        DB::statement('CREATE TABLE edu_classes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(100) NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT "active",
            created_by INTEGER NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_subjects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(150) NOT NULL,
            name_en VARCHAR(150) NULL,
            visibility VARCHAR(30) NOT NULL DEFAULT "members",
            status VARCHAR(30) NOT NULL DEFAULT "published",
            sort_order INTEGER NOT NULL DEFAULT 0,
            sequential BOOLEAN NOT NULL DEFAULT 0,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_courses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            class_id INTEGER NOT NULL,
            subject_id INTEGER NOT NULL,
            name VARCHAR(150) NOT NULL,
            status VARCHAR(30) NOT NULL DEFAULT "active",
            teacher_user_id INTEGER NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_assessments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            course_id INTEGER NOT NULL,
            title VARCHAR(150) NOT NULL,
            max_score NUMERIC NOT NULL DEFAULT 100,
            weight NUMERIC NOT NULL DEFAULT 50,
            held_on DATE NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_quizzes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            course_id INTEGER NULL,
            magazine_id INTEGER NULL,
            lesson_id INTEGER NULL,
            assessment_id INTEGER NULL,
            title VARCHAR(200) NOT NULL,
            title_en VARCHAR(200) NULL,
            instructions TEXT NULL,
            instructions_en TEXT NULL,
            opens_at DATETIME NULL,
            closes_at DATETIME NULL,
            results_release_at DATETIME NULL,
            kind VARCHAR(30) NOT NULL DEFAULT "quiz",
            time_limit_minutes INTEGER NULL,
            max_attempts INTEGER NOT NULL DEFAULT 1,
            scoring VARCHAR(20) NOT NULL DEFAULT "best",
            shuffle BOOLEAN NOT NULL DEFAULT 0,
            review_policy VARCHAR(30) NOT NULL DEFAULT "after_close",
            status VARCHAR(30) NOT NULL DEFAULT "draft",
            created_by INTEGER NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_quiz_questions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            quiz_id INTEGER NOT NULL,
            type VARCHAR(30) NOT NULL DEFAULT "single",
            prompt TEXT NOT NULL,
            prompt_en TEXT NULL,
            options TEXT NULL,
            answer TEXT NULL,
            explanation TEXT NULL,
            explanation_en TEXT NULL,
            points NUMERIC NOT NULL DEFAULT 1,
            sort_order INTEGER NOT NULL DEFAULT 0
        )');

        DB::statement('CREATE TABLE edu_quiz_attempts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            quiz_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            attempt_no INTEGER NOT NULL DEFAULT 1,
            status VARCHAR(30) NOT NULL DEFAULT "in_progress",
            needs_grading BOOLEAN NOT NULL DEFAULT 0,
            score NUMERIC NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_quiz_draws (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            quiz_id INTEGER NOT NULL,
            bank_id INTEGER NOT NULL,
            count INTEGER NOT NULL DEFAULT 0,
            points_each NUMERIC NOT NULL DEFAULT 1
        )');

        DB::statement('CREATE TABLE edu_lessons (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subject_id INTEGER NOT NULL,
            unit_id INTEGER NULL,
            title VARCHAR(200) NOT NULL,
            status VARCHAR(30) NOT NULL DEFAULT "published",
            sort_order INTEGER NOT NULL DEFAULT 0
        )');

        DB::statement('CREATE TABLE edu_lesson_materials (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lesson_id INTEGER NULL,
            category_id INTEGER NULL,
            subject_id INTEGER NULL,
            grade INTEGER NULL,
            kind VARCHAR(30) NOT NULL DEFAULT "file",
            title VARCHAR(200) NOT NULL,
            title_en VARCHAR(200) NULL,
            original_name VARCHAR(255) NULL,
            mime VARCHAR(100) NULL,
            size INTEGER NULL,
            url VARCHAR(500) NULL,
            path VARCHAR(255) NULL,
            status VARCHAR(30) NOT NULL DEFAULT "published",
            sort_order INTEGER NOT NULL DEFAULT 0
        )');

        DB::statement('CREATE TABLE library_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            parent_id INTEGER NULL,
            domain VARCHAR(32) NOT NULL DEFAULT "timhirt",
            category_type VARCHAR(32) NOT NULL DEFAULT "physical",
            name VARCHAR(200) NOT NULL,
            name_en VARCHAR(200) NULL,
            description TEXT NULL,
            code VARCHAR(32) NULL,
            is_active BOOLEAN NOT NULL DEFAULT 1,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        )');

        DB::statement('CREATE TABLE items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(200) NOT NULL,
            subtitle VARCHAR(255) NULL,
            author VARCHAR(200) NULL,
            publisher VARCHAR(200) NULL,
            publication_year INTEGER NULL,
            language VARCHAR(64) DEFAULT "am",
            code VARCHAR(50) NOT NULL,
            kind VARCHAR(20) NOT NULL DEFAULT "physical",
            domain VARCHAR(32) NOT NULL DEFAULT "timhirt",
            category VARCHAR(100) NULL,
            library_category_id INTEGER NULL,
            description TEXT NULL,
            image VARCHAR(255) NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            available_quantity INTEGER NOT NULL DEFAULT 1,
            condition VARCHAR(100) NULL,
            status VARCHAR(30) NOT NULL DEFAULT "active",
            location VARCHAR(200) NULL,
            notes TEXT NULL,
            department_id INTEGER NULL,
            direct_borrowable BOOLEAN NOT NULL DEFAULT 0,
            max_quantity INTEGER NULL,
            max_days INTEGER NULL,
            renewable BOOLEAN NOT NULL DEFAULT 0,
            file_path VARCHAR(255) NULL,
            file_mime VARCHAR(100) NULL,
            file_size INTEGER NULL,
            downloads INTEGER NOT NULL DEFAULT 0,
            created_by INTEGER NULL,
            updated_by INTEGER NULL,
            deleted_at DATETIME NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');
    }

    public function test_closing_exam_prerequisite_checklist_and_validation(): void
    {
        $classId = (int) DB::table('edu_classes')->insertGetId(['name' => '10A']);
        $subjectId = (int) DB::table('edu_subjects')->insertGetId(['name' => 'ነገረ መለኮት']);
        $courseId = (int) DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => $subjectId,
            'name' => 'ነገረ መለኮት 10A',
        ]);
        $assessmentId = (int) DB::table('edu_assessments')->insertGetId([
            'course_id' => $courseId,
            'title' => 'Final Exam Assessment',
            'max_score' => 100,
            'weight' => 50,
        ]);

        // Create exam with assessment linked
        $exam = EduQuizzes::create($this->adminActx, $courseId, [
            'title' => 'የመጨረሻ ፈተና',
            'kind' => 'exam',
            'assessment_id' => $assessmentId,
        ]);
        $this->assertSame('exam', $exam['kind']);
        $this->assertFalse($exam['prerequisites']['can_publish']);

        // Attempting to publish without questions and schedule throws EXAM_PREREQUISITE_FAILED
        try {
            EduQuizzes::update($this->adminActx, $exam['id'], ['status' => 'published']);
            $this->fail('Expected EXAM_PREREQUISITE_FAILED or QUIZ_EMPTY');
        } catch (ApiError $e) {
            $this->assertTrue(in_array($e->errorCode, ['QUIZ_EMPTY', 'EXAM_PREREQUISITE_FAILED'], true));
        }

        // Add a question
        DB::table('edu_quiz_questions')->insert([
            'quiz_id' => $exam['id'],
            'prompt' => 'የመጀመሪያው ጥያቄ',
            'points' => 10,
        ]);

        // Attempt publishing with question but without schedule and time limit
        try {
            EduQuizzes::update($this->adminActx, $exam['id'], ['status' => 'published']);
            $this->fail('Expected EXAM_PREREQUISITE_FAILED');
        } catch (ApiError $e) {
            $this->assertSame('EXAM_PREREQUISITE_FAILED', $e->errorCode);
        }

        // Satisfy all prerequisites
        $updated = EduQuizzes::update($this->adminActx, $exam['id'], [
            'opens_at' => '2026-11-01 09:00:00',
            'closes_at' => '2026-11-01 12:00:00',
            'time_limit_minutes' => 90,
            'status' => 'published',
        ]);

        $this->assertSame('published', $updated['status']);
        $this->assertTrue($updated['prerequisites']['can_publish']);
    }

    public function test_separate_physical_and_digital_book_categories(): void
    {
        // 1. Create Physical category
        $physCat = Library::saveCategory($this->adminActx, [
            'name' => 'የታሪክ መጻሕፍት (Physical)',
            'code' => 'HIST-P',
            'category_type' => 'physical',
            'description' => 'Printed history books',
            'domain' => 'timhirt',
        ]);
        $this->assertSame('physical', $physCat['category_type']);
        $this->assertSame('Printed history books', $physCat['description']);

        // 2. Create Digital category
        $digCat = Library::saveCategory($this->adminActx, [
            'name' => 'የሕጻናት ዲጂታል መጻሕፍት',
            'code' => 'KIDS-D',
            'category_type' => 'digital',
            'description' => 'Children digital collection',
            'domain' => 'timhirt',
        ]);
        $this->assertSame('digital', $digCat['category_type']);

        // 3. Filter categories by type
        $physList = Library::categories('timhirt', false, 'physical');
        $this->assertCount(1, $physList);
        $this->assertSame('HIST-P', $physList[0]['code']);

        $digList = Library::categories('timhirt', false, 'digital');
        $this->assertCount(1, $digList);
        $this->assertSame('KIDS-D', $digList[0]['code']);
    }

    public function test_detailed_book_editor_metadata_persistence(): void
    {
        // Create an item with book metadata
        $book = Items::create($this->adminActx, [
            'name' => 'የቤተክርስቲያን ታሪክ',
            'subtitle' => 'የመጀመሪያው መጽሐፍ',
            'author' => 'መ/ር ሳህሉ',
            'publisher' => 'ተንሣኤ ማተሚያ ቤት',
            'publication_year' => 2015,
            'language' => 'am',
            'code' => 'HIS-001',
            'kind' => 'physical',
            'quantity' => 5,
        ]);

        $this->assertSame('የመጀመሪያው መጽሐፍ', $book['subtitle']);
        $this->assertSame('ተንሣኤ ማተሚያ ቤት', $book['publisher']);
        $this->assertSame(2015, $book['publication_year']);
        $this->assertSame('am', $book['language']);

        // Update detailed metadata via Items::update
        $updated = Items::update($this->adminActx, $book['id'], [
            'subtitle' => 'የተሻሻለው ሁለተኛ እትም',
            'publication_year' => 2018,
            'quantity' => 7,
        ]);

        $this->assertSame('የተሻሻለው ሁለተኛ እትም', $updated['subtitle']);
        $this->assertSame(2018, $updated['publication_year']);
        $this->assertSame(7, $updated['quantity']);
    }

    public function test_all_materials_and_admin_quizzes_batch_loading(): void
    {
        $subjectId = (int) DB::table('edu_subjects')->insertGetId(['name' => 'ሥነ-ምግባር']);
        $lessonId = (int) DB::table('edu_lessons')->insertGetId([
            'subject_id' => $subjectId,
            'title' => 'ምዕራፍ ፩ ትምህርት',
        ]);

        DB::table('edu_lesson_materials')->insert([
            'lesson_id' => $lessonId,
            'title' => 'የምዕራፉ ማጠቃለያ ሰነድ',
            'kind' => 'file',
            'mime' => 'application/pdf',
            'size' => 1024,
        ]);

        $materials = EduLearning::allMaterials($this->adminAuth);
        $this->assertCount(1, $materials);
        $this->assertSame('የምዕራፉ ማጠቃለያ ሰነድ', $materials[0]['title']);
        $this->assertSame('ምዕራፍ ፩ ትምህርት', $materials[0]['lesson_title']);

        // Admin quizzes batch loading
        $classId = (int) DB::table('edu_classes')->insertGetId(['name' => 'Class A']);
        $courseId = (int) DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => $subjectId,
            'name' => 'ሥነ-ምግባር Course',
        ]);
        EduQuizzes::create($this->adminActx, $courseId, ['title' => 'ፈተና ፩']);

        $quizzes = EduQuizzes::allAdminQuizzes($this->adminAuth);
        $this->assertCount(1, $quizzes);
        $this->assertSame('ፈተና ፩', $quizzes[0]['title']);
    }
}
