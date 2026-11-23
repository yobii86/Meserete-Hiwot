<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Edu;
use App\Mz\Services\EduLearning;
use App\Mz\Services\Library;
use App\Mz\Services\Sync;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EduSearchAndFavoritesTest extends TestCase
{
    private AuthContext $auth;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpTestSchema();

        $this->auth = new AuthContext();
        $this->auth->id = 55;
        $this->auth->fullName = 'Test Student';
        $this->auth->status = 'active';
        $this->auth->accountType = 'user';
        $this->auth->tokenVersion = 1;
        $this->auth->mustChangePassword = false;
        $this->auth->isAdmin = false;
        $this->auth->isSystem = false;
        $this->auth->isMemberStaff = false;
        $this->auth->level = 10;
        $this->auth->permissions = [];
    }

    private function setUpTestSchema(): void
    {
        if (! Schema::hasTable('items')) {
            Schema::create('items', function ($table) {
                $table->increments('id');
                $table->string('name');
                $table->string('author')->nullable();
                $table->string('code')->nullable();
                $table->string('kind')->default('digital');
                $table->string('category')->default('books');
                $table->unsignedInteger('library_category_id')->nullable();
                $table->text('description')->nullable();
                $table->string('domain')->default('timhirt');
                $table->string('image')->nullable();
                $table->string('file_path')->nullable();
                $table->unsignedBigInteger('file_size')->nullable();
                $table->unsignedInteger('available_quantity')->default(1);
                $table->unsignedInteger('quantity')->default(1);
                $table->string('status')->default('active');
                $table->softDeletes();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('library_favorites')) {
            Schema::create('library_favorites', function ($table) {
                $table->unsignedInteger('user_id');
                $table->unsignedInteger('item_id');
                $table->dateTime('created_at')->useCurrent();
                $table->primary(['user_id', 'item_id']);
            });
        }

        if (! Schema::hasTable('library_categories')) {
            Schema::create('library_categories', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('parent_id')->nullable();
                $table->string('domain')->default('timhirt');
                $table->string('category_type')->default('physical');
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->text('description')->nullable();
                $table->string('code')->nullable();
                $table->boolean('is_active')->default(1);
                $table->unsignedInteger('sort_order')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('library_requests')) {
            Schema::create('library_requests', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('user_id');
                $table->unsignedInteger('item_id');
                $table->unsignedInteger('quantity')->default(1);
                $table->string('status')->default('requested');
                $table->text('note')->nullable();
                $table->date('needed_on')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('library_progress')) {
            Schema::create('library_progress', function ($table) {
                $table->unsignedInteger('user_id');
                $table->unsignedInteger('item_id');
                $table->unsignedInteger('page')->default(1);
                $table->unsignedInteger('page_count')->nullable();
                $table->unsignedInteger('audio_position_ms')->default(0);
                $table->timestamps();
                $table->primary(['user_id', 'item_id']);
            });
        }

        if (! Schema::hasTable('library_copies')) {
            Schema::create('library_copies', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('item_id');
                $table->unsignedInteger('copy_no')->default(1);
                $table->string('copy_code');
                $table->string('condition')->default('good');
                $table->string('status')->default('available');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_categories')) {
            Schema::create('edu_categories', function ($table) {
                $table->increments('id');
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->text('description')->nullable();
                $table->unsignedInteger('sort_order')->default(0);
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_subjects')) {
            Schema::create('edu_subjects', function ($table) {
                $table->increments('id');
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->string('code')->nullable();
                $table->text('description')->nullable();
                $table->unsignedInteger('category_id')->nullable();
                $table->unsignedInteger('sort_order')->default(0);
                $table->string('status')->default('published');
                $table->string('visibility')->default('members');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_classes')) {
            Schema::create('edu_classes', function ($table) {
                $table->increments('id');
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->string('code')->nullable();
                $table->unsignedTinyInteger('grade')->nullable();
                $table->unsignedTinyInteger('level_id')->nullable();
                $table->unsignedInteger('academic_year_id')->nullable();
                $table->unsignedInteger('term_id')->nullable();
                $table->boolean('allow_regular')->default(1);
                $table->boolean('allow_distance')->default(1);
                $table->string('academic_year')->nullable();
                $table->string('term')->nullable();
                $table->text('description')->nullable();
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_academic_years')) {
            Schema::create('edu_academic_years', function ($table) {
                $table->increments('id');
                $table->unsignedSmallInteger('eth_year')->default(2019);
                $table->string('name')->default('2019 ዓ.ም');
                $table->boolean('is_current')->default(1);
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_terms')) {
            Schema::create('edu_terms', function ($table) {
                $table->increments('id');
                $table->string('name')->default('1ኛ መንፈቀ ዓመት');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_levels')) {
            Schema::create('edu_levels', function ($table) {
                $table->increments('id');
                $table->string('code')->nullable();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->string('kind')->default('grade');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_courses')) {
            Schema::create('edu_courses', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('class_id');
                $table->unsignedInteger('subject_id')->nullable();
                $table->string('name');
                $table->string('code')->nullable();
                $table->text('description')->nullable();
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_enrollments')) {
            Schema::create('edu_enrollments', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('class_id');
                $table->unsignedInteger('user_id');
                $table->string('program')->nullable();
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_course_enrollments')) {
            Schema::create('edu_course_enrollments', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('user_id');
                $table->unsignedInteger('course_id');
                $table->string('status')->default('enrolled');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_course_teachers')) {
            Schema::create('edu_course_teachers', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('user_id');
                $table->unsignedInteger('course_id');
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_class_staff')) {
            Schema::create('edu_class_staff', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('user_id');
                $table->unsignedInteger('class_id');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_schedule')) {
            Schema::create('edu_schedule', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('class_id');
                $table->unsignedInteger('course_id')->nullable();
                $table->string('starts')->nullable();
                $table->string('ends')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_units')) {
            Schema::create('edu_units', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('subject_id');
                $table->string('title');
                $table->string('title_en')->nullable();
                $table->text('description')->nullable();
                $table->unsignedInteger('sort_order')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lesson_materials')) {
            Schema::create('edu_lesson_materials', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('lesson_id')->nullable();
                $table->unsignedInteger('subject_id')->nullable();
                $table->string('title');
                $table->string('original_name')->nullable();
                $table->string('kind')->default('file');
                $table->string('mime')->nullable();
                $table->string('path')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lessons')) {
            Schema::create('edu_lessons', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('subject_id');
                $table->unsignedInteger('unit_id')->nullable();
                $table->string('title');
                $table->text('summary')->nullable();
                $table->text('body')->nullable();
                $table->text('objectives')->nullable();
                $table->text('scripture_refs')->nullable();
                $table->unsignedInteger('sort_order')->default(0);
                $table->string('status')->default('published');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_assignments')) {
            Schema::create('edu_assignments', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('course_id')->nullable();
                $table->unsignedInteger('class_id')->nullable();
                $table->string('title');
                $table->text('instructions')->nullable();
                $table->decimal('max_score', 6, 2)->default(100.00);
                $table->dateTime('due_at')->nullable();
                $table->string('status')->default('published');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quizzes')) {
            Schema::create('edu_quizzes', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('course_id')->nullable();
                $table->unsignedInteger('lesson_id')->nullable();
                $table->string('title');
                $table->text('instructions')->nullable();
                $table->unsignedInteger('duration_minutes')->default(30);
                $table->string('status')->default('published');
                $table->timestamps();
            });
        }
    }

    public function testGlobalSearchFindsSupportedContentTypes(): void
    {
        DB::table('items')->truncate();
        DB::table('edu_classes')->truncate();
        DB::table('edu_assignments')->truncate();
        DB::table('edu_quizzes')->truncate();
        DB::table('edu_lessons')->truncate();
        DB::table('edu_subjects')->truncate();

        // 1. Seed searchable records with matching keyword 'Tewahedo'
        $bookId = DB::table('items')->insertGetId([
            'name' => 'Tewahedo Faith and Life',
            'author' => 'Dn. Yonas',
            'code' => 'BK-101',
            'kind' => 'digital',
            'file_path' => 'books/tewahedo.pdf',
            'status' => 'active',
            'domain' => 'timhirt',
        ]);

        $classId = DB::table('edu_classes')->insertGetId([
            'name' => 'Grade 7 Tewahedo Class',
            'term' => 'Term 1',
            'status' => 'active',
        ]);

        $assignId = DB::table('edu_assignments')->insertGetId([
            'title' => 'Tewahedo History Assignment',
            'instructions' => 'Write about church fathers',
            'status' => 'published',
        ]);

        $quizId = DB::table('edu_quizzes')->insertGetId([
            'title' => 'Tewahedo Dogma Quiz',
            'instructions' => 'Answer all 10 questions',
            'status' => 'published',
        ]);

        $subjId = DB::table('edu_subjects')->insertGetId([
            'name' => 'Tewahedo Theology',
            'status' => 'published',
            'visibility' => 'members',
        ]);

        $lessonId = DB::table('edu_lessons')->insertGetId([
            'subject_id' => $subjId,
            'title' => 'Foundations of Tewahedo',
            'status' => 'published',
        ]);

        $results = EduLearning::search($this->auth, 'Tewahedo');

        $this->assertNotEmpty($results['books'], 'Search should return matching books');
        $this->assertEquals('Tewahedo Faith and Life', $results['books'][0]->title);

        $this->assertNotEmpty($results['classes'], 'Search should return matching classes');
        $this->assertEquals('Grade 7 Tewahedo Class', $results['classes'][0]->name);

        $this->assertNotEmpty($results['assignments'], 'Search should return matching assignments');
        $this->assertEquals('Tewahedo History Assignment', $results['assignments'][0]->title);

        $this->assertNotEmpty($results['quizzes'], 'Search should return matching quizzes');
        $this->assertEquals('Tewahedo Dogma Quiz', $results['quizzes'][0]->title);

        $this->assertNotEmpty($results['lessons'], 'Search should return matching lessons');
        $this->assertEquals('Foundations of Tewahedo', $results['lessons'][0]->title);

        $this->assertNotEmpty($results['subjects'], 'Search should return matching subjects');
        $this->assertEquals('Tewahedo Theology', $results['subjects'][0]->name);
    }

    public function testFavoriteEndToEndToggleAndPersistence(): void
    {
        DB::table('items')->truncate();
        DB::table('library_favorites')->truncate();

        $bookId = DB::table('items')->insertGetId([
            'name' => 'Spiritual Reading',
            'kind' => 'digital',
            'file_path' => 'books/reading.pdf',
            'status' => 'active',
            'domain' => 'timhirt',
        ]);

        // 1. Toggle ON when null provided
        $res1 = Library::favorite($this->auth->id, $bookId, null);
        $this->assertTrue($res1['is_favorite']);
        $this->assertTrue($res1['favorited']);
        $this->assertEquals(1, DB::table('library_favorites')->where(['user_id' => $this->auth->id, 'item_id' => $bookId])->count());

        // 2. Toggle OFF when null provided again
        $res2 = Library::favorite($this->auth->id, $bookId, null);
        $this->assertFalse($res2['is_favorite']);
        $this->assertFalse($res2['favorited']);
        $this->assertEquals(0, DB::table('library_favorites')->where(['user_id' => $this->auth->id, 'item_id' => $bookId])->count());

        // 3. Explicitly set favorite true
        $res3 = Library::favorite($this->auth->id, $bookId, true);
        $this->assertTrue($res3['is_favorite']);
        $this->assertEquals(1, DB::table('library_favorites')->where(['user_id' => $this->auth->id, 'item_id' => $bookId])->count());

        // 4. Repeated add does not fail or duplicate
        $res4 = Library::favorite($this->auth->id, $bookId, true);
        $this->assertTrue($res4['is_favorite']);
        $this->assertEquals(1, DB::table('library_favorites')->where(['user_id' => $this->auth->id, 'item_id' => $bookId])->count());

        // 5. Explicitly set favorite false
        $res5 = Library::favorite($this->auth->id, $bookId, false);
        $this->assertFalse($res5['is_favorite']);
        $this->assertEquals(0, DB::table('library_favorites')->where(['user_id' => $this->auth->id, 'item_id' => $bookId])->count());
    }

    public function testSyncOperationsForLibraryFavorites(): void
    {
        DB::table('items')->truncate();
        DB::table('library_favorites')->truncate();

        $bookId = DB::table('items')->insertGetId([
            'name' => 'Sync Test Book',
            'kind' => 'digital',
            'file_path' => 'books/sync.pdf',
            'status' => 'active',
            'domain' => 'timhirt',
        ]);

        $ops = Sync::ops();
        $this->assertArrayHasKey('library.favorite.add', $ops);
        $this->assertArrayHasKey('library.favorite.remove', $ops);

        // Run library.favorite.add
        $addFn = $ops['library.favorite.add'][1];
        $addRes = $addFn($this->auth->id, ['item_id' => $bookId]);
        $this->assertTrue($addRes['changed']);
        $this->assertTrue($addRes['server']['is_favorite']);
        $this->assertEquals(1, DB::table('library_favorites')->where(['user_id' => $this->auth->id, 'item_id' => $bookId])->count());

        // Run library.favorite.remove
        $removeFn = $ops['library.favorite.remove'][1];
        $remRes = $removeFn($this->auth->id, ['item_id' => $bookId], ['client_ts' => now()->toIso8601String()]);
        $this->assertTrue($remRes['changed']);
        $this->assertEquals(0, DB::table('library_favorites')->where(['user_id' => $this->auth->id, 'item_id' => $bookId])->count());
    }

    public function testClassSerializationDoesNotProduceRawObjects(): void
    {
        DB::table('edu_classes')->truncate();
        DB::table('edu_academic_years')->truncate();
        DB::table('edu_terms')->truncate();
        DB::table('edu_levels')->truncate();
        DB::table('edu_enrollments')->truncate();

        $yearId = DB::table('edu_academic_years')->insertGetId([
            'eth_year' => 2019,
            'name' => '2019 ዓ.ም',
            'is_current' => 1,
            'status' => 'active',
        ]);

        $termId = DB::table('edu_terms')->insertGetId([
            'name' => '1ኛ መንፈቀ ዓመት',
        ]);

        $levelId = DB::table('edu_levels')->insertGetId([
            'code' => 'G7',
            'name' => '7ኛ ክፍል',
            'name_en' => 'Grade 7',
            'kind' => 'grade',
        ]);

        $classId = DB::table('edu_classes')->insertGetId([
            'name' => 'Grade 7 Class A',
            'academic_year_id' => $yearId,
            'term_id' => $termId,
            'level_id' => $levelId,
            'status' => 'active',
            'allow_regular' => 1,
            'allow_distance' => 1,
        ]);

        DB::table('edu_enrollments')->insert([
            'class_id' => $classId,
            'user_id' => $this->auth->id,
            'status' => 'active',
        ]);

        $overview = Edu::overview($this->auth);
        $this->assertNotEmpty($overview['classes']);
        $c = $overview['classes'][0];

        // Ensure academic_year is a clean string, never a raw array or {id: ...}
        $this->assertIsString($c['academic_year']);
        $this->assertEquals('2019 ዓ.ም', $c['academic_year']);
        $this->assertStringNotContainsString('{', $c['academic_year']);

        // Structured object should be in academic_year_obj
        $this->assertIsArray($c['academic_year_obj']);
        $this->assertEquals(2019, $c['academic_year_obj']['eth_year']);
        $this->assertTrue($c['academic_year_obj']['is_current']);

        // Grade must be resolved and non-empty
        $this->assertEquals('7ኛ ክፍል', $c['grade']);
        $this->assertEquals('Grade 7 Class A', $c['name']);
    }

    public function testMultiUserAndMultiBookFavoritesIsolationAndIdList(): void
    {
        DB::table('items')->truncate();
        DB::table('library_favorites')->truncate();

        $bookA = DB::table('items')->insertGetId([
            'name' => 'Book Alpha',
            'kind' => 'digital',
            'file_path' => 'books/alpha.pdf',
            'status' => 'active',
            'domain' => 'timhirt',
        ]);
        $bookB = DB::table('items')->insertGetId([
            'name' => 'Book Beta',
            'kind' => 'digital',
            'file_path' => 'books/beta.pdf',
            'status' => 'active',
            'domain' => 'timhirt',
        ]);
        $bookC = DB::table('items')->insertGetId([
            'name' => 'Book Gamma',
            'kind' => 'digital',
            'file_path' => 'books/gamma.pdf',
            'status' => 'active',
            'domain' => 'timhirt',
        ]);

        $user1 = 101;
        $user2 = 202;

        // User 1 favorites A and B
        Library::favorite($user1, $bookA, true);
        Library::favorite($user1, $bookB, true);

        // User 2 favorites B and C
        Library::favorite($user2, $bookB, true);
        Library::favorite($user2, $bookC, true);

        // Test myFavoriteIds
        $u1Ids = Library::myFavoriteIds($user1);
        $u2Ids = Library::myFavoriteIds($user2);

        $this->assertEqualsCanonicalizing([$bookA, $bookB], $u1Ids);
        $this->assertEqualsCanonicalizing([$bookB, $bookC], $u2Ids);

        // Test books() output isolation
        $auth1 = new AuthContext();
        $auth1->id = $user1;
        $auth1->fullName = 'User 1';
        $auth1->status = 'active';
        $auth1->accountType = 'user';
        $auth1->isAdmin = true;
        $auth1->isSystem = true;

        $auth2 = new AuthContext();
        $auth2->id = $user2;
        $auth2->fullName = 'User 2';
        $auth2->status = 'active';
        $auth2->accountType = 'user';
        $auth2->isAdmin = true;
        $auth2->isSystem = true;

        $books1 = Library::books($auth1, [], ['limit' => 10, 'cursor' => null]);
        $map1 = collect($books1['items'])->keyBy('id')->map(fn ($b) => $b['is_favorite'])->all();
        $this->assertTrue($map1[$bookA]);
        $this->assertTrue($map1[$bookB]);
        $this->assertFalse($map1[$bookC]);

        $books2 = Library::books($auth2, [], ['limit' => 10, 'cursor' => null]);
        $map2 = collect($books2['items'])->keyBy('id')->map(fn ($b) => $b['is_favorite'])->all();
        $this->assertFalse($map2[$bookA]);
        $this->assertTrue($map2[$bookB]);
        $this->assertTrue($map2[$bookC]);

        // Unfavoriting B for user 1 does not affect user 2
        Library::favorite($user1, $bookB, false);
        $this->assertEqualsCanonicalizing([$bookA], Library::myFavoriteIds($user1));
        $this->assertEqualsCanonicalizing([$bookB, $bookC], Library::myFavoriteIds($user2));
    }
}
