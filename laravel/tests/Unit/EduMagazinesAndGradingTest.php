<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Borrowings;
use App\Mz\Services\EduMagazines;
use App\Mz\Services\EduQuizzes;
use App\Mz\Services\Items;
use App\Mz\Services\Library;
use App\Mz\Services\Storage;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EduMagazinesAndGradingTest extends TestCase
{
    private AuthContext $adminAuth;
    private AuthContext $memberAuth;
    private array $adminActx;
    private array $memberActx;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = $this->makeAuth(1, 'Admin User', ['education.manage' => true, 'education.content' => true, 'items.manage' => true, 'borrowing.manage' => true]);
        $this->memberAuth = $this->makeAuth(2, 'Member User', []);

        $this->adminActx = ['auth' => $this->adminAuth];
        $this->memberActx = ['auth' => $this->memberAuth];

        DB::table('users')->insertOrIgnore([
            ['id' => 1, 'full_name' => 'Admin User', 'status' => 'active', 'account_type' => 'admin', 'member_no' => '1001', 'member_group' => 'adult'],
            ['id' => 2, 'full_name' => 'Member User', 'status' => 'active', 'account_type' => 'user', 'member_no' => '1002', 'member_group' => 'adult'],
        ]);
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
                $table->string('key')->primary();
                $table->text('value')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('users')) {
            Schema::create('users', function ($table) {
                $table->id();
                $table->string('full_name');
                $table->string('phone')->nullable();
                $table->string('member_no')->nullable();
                $table->string('member_group')->nullable();
                $table->string('status')->default('active');
                $table->string('account_type')->default('user');
                $table->unsignedBigInteger('role_id')->nullable();
                $table->softDeletes();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_classes')) {
            Schema::create('edu_classes', function ($table) {
                $table->id();
                $table->string('name');
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_subjects')) {
            Schema::create('edu_subjects', function ($table) {
                $table->id();
                $table->string('name');
                $table->string('status')->default('published');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_courses')) {
            Schema::create('edu_courses', function ($table) {
                $table->id();
                $table->unsignedBigInteger('class_id');
                $table->unsignedBigInteger('subject_id')->nullable();
                $table->string('name');
                $table->string('status')->default('active');
                $table->unsignedBigInteger('teacher_user_id')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_course_enrollments')) {
            Schema::create('edu_course_enrollments', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->unsignedBigInteger('user_id');
                $table->string('status')->default('enrolled');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_magazines')) {
            Schema::create('edu_magazines', function ($table) {
                $table->id();
                $table->string('title', 200);
                $table->string('title_en', 200)->nullable();
                $table->string('issue_number', 50)->nullable();
                $table->string('period_info', 100)->nullable();
                $table->text('description')->nullable();
                $table->string('cover_image', 255)->nullable();
                $table->string('pdf_path', 255)->nullable();
                $table->string('pdf_mime', 100)->nullable();
                $table->unsignedBigInteger('pdf_size')->default(0);
                $table->string('status', 20)->default('draft');
                $table->date('issue_date');
                $table->datetime('published_at')->nullable();
                $table->unsignedBigInteger('created_by')->nullable();
                $table->unsignedBigInteger('updated_by')->nullable();
                $table->boolean('notification_sent')->default(false);
                $table->timestamps();
                $table->softDeletes();
            });
        }

        if (! Schema::hasTable('edu_quizzes')) {
            Schema::create('edu_quizzes', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id')->nullable();
                $table->unsignedBigInteger('magazine_id')->nullable();
                $table->unsignedBigInteger('lesson_id')->nullable();
                $table->unsignedBigInteger('assessment_id')->nullable();
                $table->string('title');
                $table->string('title_en')->nullable();
                $table->text('instructions')->nullable();
                $table->text('instructions_en')->nullable();
                $table->string('status')->default('draft');
                $table->string('kind')->default('quiz');
                $table->boolean('official')->default(false);
                $table->integer('max_attempts')->default(1);
                $table->integer('time_limit_minutes')->nullable();
                $table->string('review_policy')->default('always');
                $table->string('score_policy')->default('always');
                $table->string('scoring')->default('best');
                $table->boolean('shuffle')->default(false);
                $table->datetime('opens_at')->nullable();
                $table->datetime('closes_at')->nullable();
                $table->datetime('results_release_at')->nullable();
                $table->boolean('randomize_questions')->default(false);
                $table->boolean('randomize_options')->default(false);
                $table->unsignedBigInteger('created_by')->nullable();
                $table->unsignedBigInteger('updated_by')->nullable();
                $table->timestamps();
                $table->softDeletes();
            });
        }

        if (! Schema::hasTable('edu_quiz_questions')) {
            Schema::create('edu_quiz_questions', function ($table) {
                $table->id();
                $table->unsignedBigInteger('quiz_id')->nullable();
                $table->unsignedBigInteger('bank_id')->nullable();
                $table->string('type')->default('multiple_choice');
                $table->text('prompt');
                $table->text('prompt_en')->nullable();
                $table->text('explanation')->nullable();
                $table->text('explanation_en')->nullable();
                $table->json('options')->nullable();
                $table->text('answer')->nullable();
                $table->decimal('points', 6, 2)->default(1.00);
                $table->integer('sort_order')->default(0);
                $table->timestamps();
                $table->softDeletes();
            });
        }

        if (! Schema::hasTable('edu_quiz_attempts')) {
            Schema::create('edu_quiz_attempts', function ($table) {
                $table->id();
                $table->unsignedBigInteger('quiz_id');
                $table->unsignedBigInteger('user_id');
                $table->integer('attempt_no')->default(1);
                $table->string('status')->default('in_progress');
                $table->datetime('started_at');
                $table->datetime('submitted_at')->nullable();
                $table->datetime('expires_at')->nullable();
                $table->decimal('auto_score', 6, 2)->default(0.00);
                $table->decimal('manual_score', 6, 2)->default(0.00);
                $table->decimal('max_score', 6, 2)->default(0.00);
                $table->boolean('needs_grading')->default(false);
                $table->json('question_ids')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quiz_answers')) {
            Schema::create('edu_quiz_answers', function ($table) {
                $table->id();
                $table->unsignedBigInteger('attempt_id');
                $table->unsignedBigInteger('question_id');
                $table->text('response')->nullable();
                $table->boolean('is_correct')->nullable();
                $table->decimal('points_awarded', 6, 2)->nullable();
                $table->text('feedback')->nullable();
                $table->unsignedBigInteger('graded_by')->nullable();
                $table->datetime('graded_at')->nullable();
                $table->timestamps();
                $table->unique(['attempt_id', 'question_id']);
            });
        }

        if (! Schema::hasTable('edu_quiz_draws')) {
            Schema::create('edu_quiz_draws', function ($table) {
                $table->id();
                $table->unsignedBigInteger('quiz_id');
                $table->unsignedBigInteger('bank_id');
                $table->integer('count')->default(1);
                $table->decimal('points_each', 6, 2)->default(1.00);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('items')) {
            Schema::create('items', function ($table) {
                $table->id();
                $table->string('name');
                $table->string('author')->nullable();
                $table->string('kind')->default('physical');
                $table->string('code')->nullable();
                $table->string('category')->nullable();
                $table->unsignedBigInteger('library_category_id')->nullable();
                $table->string('domain')->default('mezmur');
                $table->text('description')->nullable();
                $table->integer('quantity')->default(1);
                $table->integer('available_quantity')->default(1);
                $table->string('condition')->default('good');
                $table->string('status')->default('active');
                $table->string('image')->nullable();
                $table->string('location')->nullable();
                $table->text('notes')->nullable();
                $table->unsignedBigInteger('department_id')->nullable();
                $table->boolean('direct_borrowable')->default(false);
                $table->integer('max_quantity')->nullable();
                $table->integer('max_days')->nullable();
                $table->boolean('renewable')->default(true);
                $table->string('file_path')->nullable();
                $table->string('file_mime')->nullable();
                $table->unsignedBigInteger('file_size')->nullable();
                $table->integer('downloads')->default(0);
                $table->string('narration_path')->nullable();
                $table->string('narration_mime')->nullable();
                $table->integer('narration_duration')->nullable();
                $table->unsignedBigInteger('created_by')->nullable();
                $table->unsignedBigInteger('updated_by')->nullable();
                $table->softDeletes();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('departments')) {
            Schema::create('departments', function ($table) {
                $table->id();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->string('code_prefix')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('item_categories')) {
            Schema::create('item_categories', function ($table) {
                $table->string('key')->primary();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->string('code');
                $table->integer('sort_order')->default(0);
                $table->boolean('is_active')->default(true);
                $table->boolean('built_in')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('borrowings')) {
            Schema::create('borrowings', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->unsignedBigInteger('item_id');
                $table->integer('quantity')->default(1);
                $table->string('status')->default('active');
                $table->date('borrowed_on');
                $table->date('due_on');
                $table->date('returned_on')->nullable();
                $table->unsignedBigInteger('issued_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('borrowing_batches')) {
            Schema::create('borrowing_batches', function ($table) {
                $table->id();
                $table->unsignedBigInteger('created_by')->nullable();
                $table->integer('record_count')->default(1);
                $table->text('notes')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('library_categories')) {
            Schema::create('library_categories', function ($table) {
                $table->id();
                $table->unsignedBigInteger('parent_id')->nullable();
                $table->string('domain')->default('timhirt');
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->string('code')->nullable();
                $table->integer('sort_order')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('notifications')) {
            Schema::create('notifications', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->string('type');
                $table->string('title');
                $table->text('body');
                $table->string('entity_type')->nullable();
                $table->unsignedBigInteger('entity_id')->nullable();
                $table->string('dedupe_key')->nullable();
                $table->boolean('is_read')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('audit_logs')) {
            Schema::create('audit_logs', function ($table) {
                $table->id();
                $table->unsignedBigInteger('actor_id')->nullable();
                $table->string('action');
                $table->string('entity_type')->nullable();
                $table->unsignedBigInteger('entity_id')->nullable();
                $table->json('details')->nullable();
                $table->boolean('is_hidden')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('roles')) {
            Schema::create('roles', function ($table) {
                $table->id();
                $table->string('name');
                $table->boolean('is_hidden')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('library_requests')) {
            Schema::create('library_requests', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->unsignedBigInteger('item_id');
                $table->integer('quantity')->default(1);
                $table->string('status')->default('requested');
                $table->text('note')->nullable();
                $table->date('needed_on')->nullable();
                $table->text('review_note')->nullable();
                $table->datetime('reviewed_at')->nullable();
                $table->unsignedBigInteger('borrowing_id')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('library_copies')) {
            Schema::create('library_copies', function ($table) {
                $table->id();
                $table->unsignedBigInteger('item_id');
                $table->string('barcode')->nullable();
                $table->string('status')->default('available');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('library_favorites')) {
            Schema::create('library_favorites', function ($table) {
                $table->unsignedBigInteger('user_id');
                $table->unsignedBigInteger('item_id');
                $table->primary(['user_id', 'item_id']);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('library_progress')) {
            Schema::create('library_progress', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->unsignedBigInteger('item_id');
                $table->integer('page')->default(1);
                $table->integer('page_count')->nullable();
                $table->integer('audio_position_ms')->default(0);
                $table->timestamps();
            });
        }
    }

    // =========================================================================
    // 1. ሰሌዳ መጽሔት (Seleda Magazine) Tests
    // =========================================================================

    public function test_can_create_and_list_magazines(): void
    {
        $mag = EduMagazines::create($this->adminActx, [
            'title' => 'ሰሌዳ መጽሔት ቁጥር 1',
            'title_en' => 'Seleda Issue 1',
            'issue_number' => '1',
            'period_info' => 'ጥቅምት 2017',
            'description' => 'የመጀመሪያው እትም',
            'issue_date' => '2026-10-01',
            'status' => 'draft',
        ]);

        $this->assertEquals('ሰሌዳ መጽሔት ቁጥር 1', $mag['title']);
        $this->assertEquals('draft', $mag['status']);

        // Member cannot see draft issues in list
        $memberList = EduMagazines::list($this->memberAuth, [], Page::params(['page' => 1, 'limit' => 10]));
        $this->assertCount(0, $memberList['items']);

        // Admin sees draft issue
        $adminList = EduMagazines::list($this->adminAuth, [], Page::params(['page' => 1, 'limit' => 10]));
        $this->assertCount(1, $adminList['items']);

        // Publish magazine with PDF
        $published = EduMagazines::update($this->adminActx, $mag['id'], [
            'status' => 'published',
            'pdf_path' => 'public/magazines/issue1.pdf',
            'published_at' => Dates::sql(Dates::now()),
        ]);
        $this->assertEquals('published', $published['status']);

        // Member now sees published issue
        $memberList = EduMagazines::list($this->memberAuth, [], Page::params(['page' => 1, 'limit' => 10]));
        $this->assertCount(1, $memberList['items']);

        // Latest magazine returns the published issue
        $latest = EduMagazines::latest($this->memberAuth);
        $this->assertNotNull($latest);
        $this->assertEquals($mag['id'], $latest['id']);
    }

    public function test_can_link_quiz_to_magazine_issue(): void
    {
        $mag = EduMagazines::create($this->adminActx, [
            'title' => 'ሰሌዳ መጽሔት ቁጥር 2',
            'issue_date' => '2026-10-15',
            'pdf_path' => 'public/magazines/issue2.pdf',
            'status' => 'published',
            'published_at' => Dates::sql(Dates::now()),
        ]);

        $quiz = EduMagazines::createQuiz($this->adminActx, $mag['id'], [
            'title' => 'የእትም 2 ፈተና',
            'instructions' => 'መጽሔቱን አንብበው ይመልሱ',
            'max_attempts' => 2,
        ]);

        $this->assertEquals($mag['id'], $quiz['magazine_id']);
        $this->assertNull($quiz['course_id']);

        // Quizzes of magazine
        $quizzes = EduMagazines::quizzes($this->memberAuth, $mag['id']);
        $this->assertCount(1, $quizzes);
        $this->assertEquals('የእትም 2 ፈተና', $quizzes[0]['title']);

        // Magazine detail includes quizzes
        $detail = EduMagazines::detail($this->memberAuth, $mag['id']);
        $this->assertEquals(1, $detail['quiz_count']);
        $this->assertCount(1, $detail['quizzes']);
    }

    // =========================================================================
    // 2. Short-Answer Grading Persistence & Hidden Results
    // =========================================================================

    public function test_short_answer_grading_persists_score_and_feedback(): void
    {
        $quizId = DB::table('edu_quizzes')->insertGetId([
            'title' => 'ፈተና ከፅሁፍ ጥያቄ ጋር',
            'status' => 'published',
            'max_attempts' => 1,
            'review_policy' => 'after_submit',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $mcId = DB::table('edu_quiz_questions')->insertGetId([
            'quiz_id' => $quizId,
            'type' => 'single',
            'prompt' => 'ጥያቄ 1',
            'points' => 5.0,
            'answer' => json_encode('A'),
            'options' => json_encode([['id' => 'A', 'text' => 'መልስ ሀ']]),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $stId = DB::table('edu_quiz_questions')->insertGetId([
            'quiz_id' => $quizId,
            'type' => 'short_text',
            'prompt' => 'ስለ ሰንበት ት/ቤት ታሪክ በአጭሩ ጻፉ',
            'points' => 10.0,
            'answer' => 'ሞዴል መልስ',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Member takes quiz
        $attempt = EduQuizzes::start($this->memberAuth, $quizId);
        $this->assertEquals(1, $attempt['attempt_no']);

        // Member submits answers
        $submitted = EduQuizzes::submit($this->memberAuth, $attempt['id'], [
            ['question_id' => $mcId, 'response' => 'A'],
            ['question_id' => $stId, 'response' => 'ሰንበት ት/ቤት በ1950ዎቹ ተመሠረተ።'],
        ]);

        // Attempt must require manual grading and be marked pending_grading
        $this->assertTrue((bool) $submitted['needs_grading']);
        $this->assertEquals('pending_grading', $submitted['status']);

        // Student viewing attempt should have complete scores hidden
        $studentAttempt = EduQuizzes::studentAttempt($this->memberAuth, $attempt['id']);
        $this->assertNull($studentAttempt['score'], 'Score must be hidden while manual grading is pending');
        $this->assertFalse($studentAttempt['answers_visible'], 'Answers must be hidden while manual grading is pending');

        // Teacher grades the short-answer question and gives feedback
        $graded = EduQuizzes::gradeAnswer($this->adminActx, $attempt['id'], $stId, 8.5, 'በጣም ጥሩ መልስ ነው! ዝርዝር ነጥቦች ተካተዋል።');

        // Check DB row directly
        $ansRow = DB::table('edu_quiz_answers')->where(['attempt_id' => $attempt['id'], 'question_id' => $stId])->first();
        $this->assertNotNull($ansRow);
        $this->assertEquals(8.5, (float) $ansRow->points_awarded);
        $this->assertEquals('በጣም ጥሩ መልስ ነው! ዝርዝር ነጥቦች ተካተዋል።', $ansRow->feedback);
        $this->assertEquals(1, $ansRow->graded_by);
        $this->assertNotNull($ansRow->graded_at);

        // All questions graded: attempt is now marked graded, needs_grading is false
        $this->assertFalse((bool) $graded['needs_grading']);
        $this->assertEquals('graded', $graded['status']);
        $this->assertEquals(13.5, (float) $graded['score']); // 5 auto + 8.5 manual

        // Student viewing attempt now sees score, answers, and feedback
        $studentAttemptAfter = EduQuizzes::studentAttempt($this->memberAuth, $attempt['id']);
        $this->assertEquals(13.5, (float) $studentAttemptAfter['score']);
        $this->assertTrue($studentAttemptAfter['answers_visible']);

        // Check question in attempt output has feedback
        $stInAttempt = current(array_filter($studentAttemptAfter['questions'], fn ($q) => $q['id'] == $stId));
        $this->assertEquals(8.5, (float) $stInAttempt['points_awarded']);
        $this->assertEquals('በጣም ጥሩ መልስ ነው! ዝርዝር ነጥቦች ተካተዋል።', $stInAttempt['feedback']);
    }

    // =========================================================================
    // 3. Enforce Maximum Exam Attempt Count
    // =========================================================================

    public function test_enforces_maximum_exam_attempt_count(): void
    {
        $quizId = DB::table('edu_quizzes')->insertGetId([
            'title' => 'የአንድ ሙከራ ፈተና',
            'status' => 'published',
            'max_attempts' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $mcId = DB::table('edu_quiz_questions')->insertGetId([
            'quiz_id' => $quizId,
            'type' => 'single',
            'prompt' => 'ጥያቄ',
            'points' => 10.0,
            'answer' => json_encode('A'),
            'options' => json_encode([['id' => 'A', 'text' => 'መልስ']]),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Attempt 1 starts successfully
        $attempt1 = EduQuizzes::start($this->memberAuth, $quizId);
        $this->assertEquals(1, $attempt1['attempt_no']);

        // Submit attempt 1
        EduQuizzes::submit($this->memberAuth, $attempt1['id'], [
            ['question_id' => $mcId, 'response' => 'A'],
        ]);

        // Attempt 2 must be rejected with MAX_ATTEMPTS_REACHED
        $this->expectException(ApiError::class);
        EduQuizzes::start($this->memberAuth, $quizId);
    }

    // =========================================================================
    // 4. Separation of Property Items & Education Books
    // =========================================================================

    public function test_digital_books_are_excluded_from_property_items_list(): void
    {
        // Physical property item (e.g. microphone)
        DB::table('items')->insert([
            'name' => 'ገመድ አልባ ማይክሮፎን',
            'kind' => 'physical',
            'category' => 'equipment',
            'quantity' => 2,
            'available_quantity' => 2,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Digital book (PDF)
        DB::table('items')->insert([
            'name' => 'የኦርቶዶክስ ተዋሕዶ እምነት ዲጂታል መጽሐፍ',
            'kind' => 'digital',
            'category' => 'books',
            'domain' => 'timhirt',
            'file_path' => 'private/books/test.pdf',
            'quantity' => 1,
            'available_quantity' => 1,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Items::list without explicit kind excludes digital items by default
        $items = Items::list([], Page::params(['page' => 1, 'limit' => 20]));
        $names = array_column($items['items'], 'name');
        $this->assertContains('ገመድ አልባ ማይክሮፎን', $names);
        $this->assertNotContains('የኦርቶዶክስ ተዋሕዶ እምነት ዲጂታል መጽሐፍ', $names);
    }

    public function test_digital_books_cannot_be_borrowed(): void
    {
        $digitalId = DB::table('items')->insertGetId([
            'name' => 'ዲጂታል መጽሐፍ',
            'kind' => 'digital',
            'category' => 'books',
            'domain' => 'timhirt',
            'direct_borrowable' => true,
            'file_path' => 'private/books/test.pdf',
            'quantity' => 1,
            'available_quantity' => 1,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Attempting to borrow digital item must fail with ITEM_IS_DIGITAL
        $this->expectException(ApiError::class);
        Borrowings::create($this->adminActx, [
            'user_id' => $this->memberAuth->id,
            'item_id' => $digitalId,
            'quantity' => 1,
            'borrowed_on' => '2026-10-20',
            'due_on' => '2026-10-27',
        ]);
    }

    public function test_library_books_excludes_general_property_items(): void
    {
        // General property item (furniture)
        DB::table('items')->insert([
            'name' => 'የቢሮ ወንበር',
            'kind' => 'physical',
            'category' => 'furniture',
            'domain' => 'property',
            'quantity' => 5,
            'available_quantity' => 5,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Library physical book
        DB::table('items')->insert([
            'name' => 'መጽሐፈ ቅዳሴ',
            'kind' => 'physical',
            'category' => 'books',
            'domain' => 'timhirt',
            'quantity' => 3,
            'available_quantity' => 3,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Library::books catalog
        $books = Library::books($this->memberAuth, [], Page::params(['page' => 1, 'limit' => 20]));
        $bookNames = array_column($books['items'], 'title');

        $this->assertContains('መጽሐፈ ቅዳሴ', $bookNames);
        $this->assertNotContains('የቢሮ ወንበር', $bookNames);
    }

    public function test_magazine_pdf_and_cover_upload_and_replacement(): void
    {
        // 1. Create a draft magazine
        $created = EduMagazines::create($this->adminActx, [
            'title' => 'ሰሌዳ መጽሔት እትም ፭',
            'title_en' => 'Seleda Issue 5',
            'issue_number' => 'ቅጽ ፩ ቁ. ፭',
            'period_info' => 'ጥቅምት ፳፻፲፱',
            'description' => 'የሙከራ እትም',
            'issue_date' => '2026-11-02',
            'status' => 'draft',
        ]);
        $id = $created['id'];
        $this->assertNotNull($id);

        // 2. Upload cover image
        $pngBytes = base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');
        $coverTmp = tempnam(sys_get_temp_dir(), 'cov') . '.png';
        file_put_contents($coverTmp, $pngBytes);
        $coverFile = new UploadedFile($coverTmp, 'cover.png', 'image/png', null, true);

        $afterCover = EduMagazines::uploadCover($this->adminActx, $id, $coverFile);
        $this->assertNotEmpty($afterCover['cover_url']);
        $cover1Path = DB::table('edu_magazines')->where('id', $id)->value('cover_image');
        $this->assertStringStartsWith('public/images/magazines/', $cover1Path);

        // 3. Upload PDF
        $pdfContent = "%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n190\n%%EOF\n";
        $pdfTmp = tempnam(sys_get_temp_dir(), 'pdf') . '.pdf';
        file_put_contents($pdfTmp, $pdfContent);
        $pdfFile = new UploadedFile($pdfTmp, 'magazine.pdf', 'application/pdf', null, true);

        $afterPdf = EduMagazines::uploadPdf($this->adminActx, $id, $pdfFile);
        $this->assertNotEmpty($afterPdf['pdf_url']);
        $this->assertGreaterThan(0, $afterPdf['pdf_size']);
        $pdf1Path = DB::table('edu_magazines')->where('id', $id)->value('pdf_path');
        $this->assertStringStartsWith('public/magazines/', $pdf1Path);

        // 4. Replace PDF and assert previous file was cleaned up
        $pdfTmp2 = tempnam(sys_get_temp_dir(), 'pdf2') . '.pdf';
        file_put_contents($pdfTmp2, $pdfContent . "% v2\n");
        $pdfFile2 = new UploadedFile($pdfTmp2, 'magazine_v2.pdf', 'application/pdf', null, true);

        $afterPdf2 = EduMagazines::uploadPdf($this->adminActx, $id, $pdfFile2);
        $pdf2Path = DB::table('edu_magazines')->where('id', $id)->value('pdf_path');
        $this->assertNotEquals($pdf1Path, $pdf2Path);
        $this->assertFileDoesNotExist(Storage::publicPath($pdf1Path));
        $this->assertFileExists(Storage::publicPath($pdf2Path));

        // 5. Replace Cover and assert previous file was cleaned up
        $coverTmp2 = tempnam(sys_get_temp_dir(), 'cov2') . '.png';
        file_put_contents($coverTmp2, $pngBytes);
        $coverFile2 = new UploadedFile($coverTmp2, 'cover_v2.png', 'image/png', null, true);

        $afterCover2 = EduMagazines::uploadCover($this->adminActx, $id, $coverFile2);
        $cover2Path = DB::table('edu_magazines')->where('id', $id)->value('cover_image');
        $this->assertNotEquals($cover1Path, $cover2Path);
        $this->assertFileDoesNotExist(Storage::publicPath($cover1Path));
        $this->assertFileExists(Storage::publicPath($cover2Path));

        // 6. Remove Cover and assert file was cleaned up
        $afterRemove = EduMagazines::removeCover($this->adminActx, $id);
        $this->assertNull($afterRemove['cover_url']);
        $this->assertNull(DB::table('edu_magazines')->where('id', $id)->value('cover_image'));
        $this->assertFileDoesNotExist(Storage::publicPath($cover2Path));

        // Clean up
        Storage::remove($pdf2Path);
        @unlink($coverTmp);
        @unlink($coverTmp2);
        @unlink($pdfTmp);
        @unlink($pdfTmp2);
    }
}
