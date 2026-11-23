<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Library;
use App\Mz\Services\LibraryCirculation;
use App\Mz\Services\ReportExport;
use App\Mz\Services\Sync;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class LibraryDigitalAndCirculationTest extends TestCase
{
    private AuthContext $adminAuth;
    private AuthContext $librarianAuth;
    private AuthContext $studentAuth;
    private AuthContext $otherStudentAuth;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = $this->makeAuth(1, 'Admin Haile', ['items.manage' => true, 'library.circulate' => true, 'reports.view' => true]);
        $this->librarianAuth = $this->makeAuth(2, 'Librarian Martha', ['library.circulate' => true, 'borrowing.manage' => true, 'reports.view' => true]);
        $this->studentAuth = $this->makeAuth(10, 'Student Abebe', []);
        $this->otherStudentAuth = $this->makeAuth(11, 'Student Kebede', []);
    }

    private function makeAuth(int $id, string $name, array $perms = []): AuthContext
    {
        $auth = new AuthContext();
        $auth->id = $id;
        $auth->fullName = $name;
        $auth->status = 'active';
        $auth->accountType = (! empty($perms['items.manage']) || ! empty($perms['library.circulate'])) ? 'admin' : 'user';
        $auth->tokenVersion = 1;
        $auth->mustChangePassword = false;
        $auth->isAdmin = ! empty($perms['items.manage']);
        $auth->isSystem = false;
        $auth->isMemberStaff = false;
        $auth->level = ! empty($perms['items.manage']) ? 100 : 10;
        $auth->permissions = $perms;
        return $auth;
    }

    private function makeActx(AuthContext $auth): array
    {
        return [
            'auth' => $auth,
            'ip' => '127.0.0.1',
            'userAgent' => 'PHPUnit',
            'requestId' => 'req-' . uniqid(),
            'source' => 'web',
            'offset' => 0,
        ];
    }

    private function setUpSchema(): void
    {
        Schema::dropIfExists('library_sync_conflicts');
        Schema::dropIfExists('library_loans');
        Schema::dropIfExists('library_copies');
        Schema::dropIfExists('library_progress');
        Schema::dropIfExists('library_favorites');
        Schema::dropIfExists('library_requests');
        Schema::dropIfExists('settings');
        Schema::dropIfExists('items');
        Schema::dropIfExists('library_categories');
        Schema::dropIfExists('users');
        Schema::dropIfExists('audit_logs');
        Schema::dropIfExists('sync_receipts');

        DB::statement('CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name VARCHAR(100) NOT NULL,
            phone VARCHAR(20) NULL,
            email VARCHAR(100) NULL,
            member_no INTEGER NULL,
            member_group VARCHAR(10) NULL,
            status VARCHAR(20) NOT NULL DEFAULT "active",
            deleted_at DATETIME NULL
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
            file_path VARCHAR(255) NULL,
            file_mime VARCHAR(100) NULL,
            file_size INTEGER NULL,
            narration_path VARCHAR(255) NULL,
            narration_mime VARCHAR(100) NULL,
            narration_duration INTEGER NULL,
            downloads INTEGER NOT NULL DEFAULT 0,
            status VARCHAR(20) NOT NULL DEFAULT "active",
            deleted_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE library_favorites (
            user_id INTEGER NOT NULL,
            item_id INTEGER NOT NULL,
            created_at DATETIME NOT NULL,
            PRIMARY KEY (user_id, item_id)
        )');

        DB::statement('CREATE TABLE library_progress (
            user_id INTEGER NOT NULL,
            item_id INTEGER NOT NULL,
            page INTEGER NOT NULL DEFAULT 1,
            page_count INTEGER NULL,
            audio_position_ms INTEGER NOT NULL DEFAULT 0,
            updated_at DATETIME NOT NULL,
            PRIMARY KEY (user_id, item_id)
        )');

        DB::statement('CREATE TABLE library_copies (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_id INTEGER NOT NULL,
            copy_no INTEGER NOT NULL,
            copy_code VARCHAR(64) NOT NULL UNIQUE,
            condition VARCHAR(20) NOT NULL DEFAULT "good",
            location VARCHAR(100) NULL,
            status VARCHAR(20) NOT NULL DEFAULT "available",
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        )');

        DB::statement('CREATE TABLE library_loans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            copy_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            checked_out_at DATETIME NOT NULL,
            due_on DATE NOT NULL,
            returned_at DATETIME NULL,
            condition_out VARCHAR(20) NOT NULL DEFAULT "good",
            condition_in VARCHAR(20) NULL,
            issued_by INTEGER NOT NULL,
            received_by INTEGER NULL,
            signature_path VARCHAR(255) NOT NULL,
            sha256 VARCHAR(64) NULL,
            notes VARCHAR(500) NULL,
            status VARCHAR(20) NOT NULL DEFAULT "active",
            open_copy_id INTEGER GENERATED ALWAYS AS (CASE WHEN status = "active" THEN copy_id ELSE NULL END) STORED,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        )');
        DB::statement('CREATE UNIQUE INDEX uq_library_loans_open ON library_loans (open_copy_id)');

        DB::statement('CREATE TABLE library_sync_conflicts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind VARCHAR(20) NOT NULL,
            code VARCHAR(64) NOT NULL,
            copy_code VARCHAR(64) NOT NULL,
            copy_id INTEGER NULL,
            user_id INTEGER NULL,
            submitted_by INTEGER NOT NULL,
            client_event_id VARCHAR(64) NULL,
            payload TEXT NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT "pending",
            resolution_note VARCHAR(500) NULL,
            resolved_by INTEGER NULL,
            resolved_at DATETIME NULL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        )');

        DB::statement('CREATE TABLE library_requests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            item_id INTEGER NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            note VARCHAR(500) NULL,
            needed_on DATE NULL,
            status VARCHAR(20) NOT NULL DEFAULT "requested",
            review_note VARCHAR(500) NULL,
            reviewed_by INTEGER NULL,
            reviewed_at DATETIME NULL,
            borrowing_id INTEGER NULL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
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
            details TEXT NULL,
            ip VARCHAR(45) NULL,
            user_agent VARCHAR(255) NULL,
            request_id VARCHAR(64) NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        )');

        DB::statement('CREATE TABLE sync_receipts (
            client_event_id VARCHAR(64) PRIMARY KEY,
            created_at DATETIME NOT NULL
        )');

        // Seed users
        foreach ([1 => 'Admin Haile', 2 => 'Librarian Martha', 10 => 'Student Abebe', 11 => 'Student Kebede'] as $uid => $name) {
            DB::table('users')->insert([
                'id' => $uid,
                'full_name' => $name,
                'phone' => '09110000' . $uid,
                'email' => "user{$uid}@example.com",
                'member_no' => $uid,
                'member_group' => 'A',
                'status' => 'active',
            ]);
        }
    }

    public function test_f16_library_categories_hierarchy_and_management(): void
    {
        $actx = $this->makeActx($this->adminAuth);

        // 1. Create parent category
        $parent = Library::saveCategory($actx, [
            'name' => 'ነገረ መለኮት',
            'name_en' => 'Theology',
            'code' => 'THEO',
            'domain' => 'timhirt',
            'sort_order' => 1,
        ]);
        $this->assertEquals('ነገረ መለኮት', $parent['name']);
        $this->assertEquals('THEO', $parent['code']);

        // 2. Create child category
        $child = Library::saveCategory($actx, [
            'parent_id' => $parent['id'],
            'name' => 'ክርስቶሎጂ',
            'name_en' => 'Christology',
            'code' => 'CHRI',
            'domain' => 'timhirt',
            'sort_order' => 2,
        ]);
        $this->assertEquals($parent['id'], $child['parent_id']);

        // 3. Tree view
        $tree = Library::categories('timhirt', tree: true);
        $this->assertCount(1, $tree);
        $this->assertEquals('ነገረ መለኮት', $tree[0]['name']);
        $this->assertCount(1, $tree[0]['children']);
        $this->assertEquals('ክርስቶሎጂ', $tree[0]['children'][0]['name']);

        // 4. Create book in child category
        $bookId = DB::table('items')->insertGetId([
            'name' => 'ትምህርተ ክርስቶስ',
            'author' => 'መ/ር ሳህሉ',
            'code' => 'BK-001',
            'kind' => 'digital',
            'domain' => 'timhirt',
            'library_category_id' => $child['id'],
            'file_path' => 'private/books/test.pdf',
            'file_mime' => 'application/pdf',
            'file_size' => 1024,
            'status' => 'active',
        ]);

        // Filter books by parent category should match child category books
        $res = Library::books($this->studentAuth, ['category_id' => $parent['id']], ['limit' => 10, 'offset' => 0]);
        $this->assertCount(1, $res['items']);
        $this->assertEquals('ትምህርተ ክርስቶስ', $res['items'][0]['title']);

        // Deleting category containing books must fail with conflict
        $this->expectException(ApiError::class);
        Library::deleteCategory($actx, $child['id']);
    }

    public function test_f16_library_favorites_and_progress_tracking(): void
    {
        $bookId = DB::table('items')->insertGetId([
            'name' => 'ሃይማኖተ አበው',
            'author' => 'ቅዱሳን አባቶች',
            'code' => 'BK-002',
            'kind' => 'digital',
            'domain' => 'timhirt',
            'file_path' => 'private/books/haymanot.pdf',
            'file_mime' => 'application/pdf',
            'file_size' => 2048,
            'narration_path' => 'public/audio/mezmurs/test.mp3',
            'narration_mime' => 'audio/mpeg',
            'narration_duration' => 360,
            'status' => 'active',
        ]);

        // 1. Toggle favorite
        $favRes = Library::favorite($this->studentAuth->id, $bookId, true);
        $this->assertTrue($favRes['is_favorite']);

        // Check book details show is_favorite = true
        $b = Library::book($this->studentAuth, $bookId);
        $this->assertTrue($b['is_favorite']);
        $this->assertEquals(360, $b['narration_duration']);

        // 2. Track reading & audio progress
        $prog = Library::saveProgress($this->studentAuth->id, $bookId, [
            'page' => 24,
            'page_count' => 180,
            'audio_position_ms' => 45000,
        ]);
        $this->assertEquals(24, $prog['page']);
        $this->assertEquals(180, $prog['page_count']);
        $this->assertEquals(45000, $prog['audio_position_ms']);

        // Verify retrieval
        $savedProg = Library::getProgress($this->studentAuth->id, $bookId);
        $this->assertNotNull($savedProg);
        $this->assertEquals(24, $savedProg['page']);
        $this->assertEquals(45000, $savedProg['audio_position_ms']);

        // Verify myFavorites list
        $favs = Library::myFavorites($this->studentAuth, ['limit' => 10, 'offset' => 0]);
        $this->assertCount(1, $favs['items']);
        $this->assertEquals($bookId, $favs['items'][0]['id']);

        // Remove favorite
        $unfav = Library::favorite($this->studentAuth->id, $bookId, false);
        $this->assertFalse($unfav['is_favorite']);
        $bAfter = Library::book($this->studentAuth, $bookId);
        $this->assertFalse($bAfter['is_favorite']);
    }

    public function test_f16_offline_progress_sync(): void
    {
        $bookId = DB::table('items')->insertGetId([
            'name' => 'ሥነ ፍጥረት',
            'code' => 'BK-003',
            'kind' => 'digital',
            'domain' => 'timhirt',
            'file_path' => 'private/books/creation.pdf',
            'status' => 'active',
        ]);

        $op = [
            'op_id' => '11111111-2222-3333-4444-555555555555',
            'type' => 'library.progress',
            'payload' => [
                'item_id' => $bookId,
                'page' => 12,
                'page_count' => 50,
                'audio_position_ms' => 12000,
            ],
        ];

        $ops = Sync::ops();
        $handler = $ops['library.progress'][1];
        $res = $handler($this->studentAuth->id, $op['payload']);

        $this->assertTrue($res['changed']);
        $this->assertEquals(12, $res['server']['page']);

        $prog = Library::getProgress($this->studentAuth->id, $bookId);
        $this->assertEquals(12, $prog['page']);
        $this->assertEquals(12000, $prog['audio_position_ms']);
    }

    public function test_f17_copy_code_generation_and_inventory(): void
    {
        $catId = DB::table('library_categories')->insertGetId([
            'name' => 'መጻሕፍተ ብሉያት',
            'code' => 'OT',
            'domain' => 'timhirt',
            'sort_order' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $bookId = DB::table('items')->insertGetId([
            'name' => 'ኦሪት ዘፍጥረት',
            'author' => 'ሙሴ',
            'code' => 'BK-OT-01',
            'kind' => 'physical',
            'domain' => 'timhirt',
            'library_category_id' => $catId,
            'quantity' => 0,
            'available_quantity' => 0,
            'status' => 'active',
        ]);

        $actx = $this->makeActx($this->librarianAuth);

        // Add 2 physical copies
        $copy1 = LibraryCirculation::addCopy($actx, $bookId, ['condition' => 'good', 'location' => 'Shelf A-1']);
        $copy2 = LibraryCirculation::addCopy($actx, $bookId, ['condition' => 'fair', 'location' => 'Shelf A-1']);

        $this->assertEquals(sprintf('LIB-OT-%04d-01', $bookId), $copy1['copy_code']);
        $this->assertEquals(sprintf('LIB-OT-%04d-02', $bookId), $copy2['copy_code']);
        $this->assertEquals('available', $copy1['status']);
        $this->assertEquals('available', $copy2['status']);

        // Check book counts updated
        $book = Library::book($this->studentAuth, $bookId);
        $this->assertEquals(2, $book['quantity']);
        $this->assertEquals(2, $book['available']);

        // Find by code
        $found = LibraryCirculation::findCopyByCode($copy1['copy_code']);
        $this->assertNotNull($found);
        $this->assertEquals($copy1['id'], $found['id']);
    }

    public function test_f17_checkout_with_signature_and_concurrency_protection(): void
    {
        $bookId = DB::table('items')->insertGetId([
            'name' => 'መዝሙረ ዳዊት',
            'code' => 'BK-MZ-01',
            'kind' => 'physical',
            'domain' => 'timhirt',
            'quantity' => 1,
            'available_quantity' => 1,
            'status' => 'active',
        ]);

        $actx = $this->makeActx($this->librarianAuth);
        $copy = LibraryCirculation::addCopy($actx, $bookId, ['condition' => 'good']);

        $dueOn = date('Y-m-d', strtotime('+14 days'));
        // Minimal 1x1 transparent PNG data URL for signature test
        $sigDataUrl = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

        // 1. Checkout copy
        $loan = LibraryCirculation::checkout($actx, [
            'copy_code' => $copy['copy_code'],
            'user_id' => $this->studentAuth->id,
            'due_on' => $dueOn,
            'signature' => $sigDataUrl,
            'condition_out' => 'good',
            'notes' => 'Exam study loan',
        ]);

        $this->assertEquals('active', $loan['status']);
        $this->assertEquals($this->studentAuth->id, $loan['user_id']);
        $this->assertEquals($dueOn, $loan['due_on']);
        $this->assertEquals('Student Abebe', $loan['borrower_name']);

        // Verify copy status is now on_loan
        $cAfter = LibraryCirculation::findCopyByCode($copy['copy_code']);
        $this->assertEquals('on_loan', $cAfter['status']);
        $this->assertNotNull($cAfter['current_loan']);
        $this->assertEquals($this->studentAuth->id, $cAfter['current_loan']['user_id']);

        // 2. Concurrency protection: Second checkout of same copy must fail with COPY_ON_LOAN
        try {
            LibraryCirculation::checkout($actx, [
                'copy_code' => $copy['copy_code'],
                'user_id' => $this->otherStudentAuth->id,
                'due_on' => $dueOn,
                'signature' => $sigDataUrl,
            ]);
            $this->fail('Expected COPY_ON_LOAN exception was not thrown');
        } catch (ApiError $e) {
            $this->assertEquals('COPY_ON_LOAN', $e->errorCode);
        }
    }

    public function test_f17_return_and_condition_tracking(): void
    {
        $bookId = DB::table('items')->insertGetId([
            'name' => 'ዜና ሐዋርያት',
            'code' => 'BK-ACTS-01',
            'kind' => 'physical',
            'domain' => 'timhirt',
            'quantity' => 1,
            'available_quantity' => 1,
            'status' => 'active',
        ]);

        $actx = $this->makeActx($this->librarianAuth);
        $copy = LibraryCirculation::addCopy($actx, $bookId, ['condition' => 'good']);
        $sigDataUrl = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

        $loan = LibraryCirculation::checkout($actx, [
            'copy_code' => $copy['copy_code'],
            'user_id' => $this->studentAuth->id,
            'due_on' => date('Y-m-d', strtotime('+7 days')),
            'signature' => $sigDataUrl,
        ]);

        // Return with condition 'fair'
        $returned = LibraryCirculation::returnCopy($actx, [
            'loan_id' => $loan['id'],
            'condition_in' => 'fair',
            'notes' => 'Returned in good order with slight wear',
        ]);

        $this->assertEquals('returned', $returned['status']);
        $this->assertEquals('fair', $returned['condition_in']);
        $this->assertNotNull($returned['returned_at']);

        // Copy is available again with condition 'fair'
        $copyAfter = LibraryCirculation::findCopyByCode($copy['copy_code']);
        $this->assertEquals('available', $copyAfter['status']);
        $this->assertEquals('fair', $copyAfter['condition']);
        $this->assertNull($copyAfter['current_loan']);

        // Check history
        $history = LibraryCirculation::copyHistory($copy['id']);
        $this->assertCount(1, $history['loans']);
        $this->assertEquals('returned', $history['loans'][0]['status']);
    }

    public function test_f17_offline_circulation_and_conflict_handling(): void
    {
        $bookId = DB::table('items')->insertGetId([
            'name' => 'ድርሳነ ሚካኤል',
            'code' => 'BK-MIK-01',
            'kind' => 'physical',
            'domain' => 'timhirt',
            'quantity' => 1,
            'available_quantity' => 1,
            'status' => 'active',
        ]);

        $actx = $this->makeActx($this->librarianAuth);
        $copy = LibraryCirculation::addCopy($actx, $bookId, ['condition' => 'good']);
        $sigDataUrl = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

        $ops = Sync::ops();
        $checkoutHandler = $ops['library.checkout'][1];

        // 1. First offline checkout succeeds
        $op1 = [
            'op_id' => 'aaaaaaa-1111-2222-3333-444444444444',
            'payload' => [
                'copy_code' => $copy['copy_code'],
                'user_id' => $this->studentAuth->id,
                'due_on' => date('Y-m-d', strtotime('+10 days')),
                'signature' => $sigDataUrl,
            ],
        ];

        $res1 = $checkoutHandler($this->librarianAuth->id, $op1['payload'], $op1, ['actx' => $actx, 'auth' => $this->librarianAuth]);
        $this->assertTrue($res1['changed']);
        $this->assertEquals('active', $res1['server']['status']);

        // 2. Second conflicting offline checkout on same copy records a conflict
        $op2 = [
            'op_id' => 'bbbbbbb-1111-2222-3333-444444444444',
            'payload' => [
                'copy_code' => $copy['copy_code'],
                'user_id' => $this->otherStudentAuth->id,
                'due_on' => date('Y-m-d', strtotime('+10 days')),
                'signature' => $sigDataUrl,
            ],
        ];

        $res2 = $checkoutHandler($this->librarianAuth->id, $op2['payload'], $op2, ['actx' => $actx, 'auth' => $this->librarianAuth]);
        $this->assertTrue($res2['conflict']);
        $this->assertEquals('COPY_ON_LOAN', $res2['code']);
        $this->assertTrue($res2['server']['sent_to_review']);

        // Verify conflict recorded in library_sync_conflicts
        $conflicts = LibraryCirculation::conflicts([], ['limit' => 10, 'offset' => 0]);
        $this->assertCount(1, $conflicts['items']);
        $this->assertEquals('COPY_ON_LOAN', $conflicts['items'][0]['code']);
        $this->assertEquals('pending', $conflicts['items'][0]['status']);

        // Resolve conflict
        $resolve = LibraryCirculation::resolveConflict($actx, $conflicts['items'][0]['id'], 'resolved', 'Assigned copy 2 instead');
        $this->assertTrue($resolve['resolved']);
    }

    public function test_f17_library_report_exports(): void
    {
        $bookId = DB::table('items')->insertGetId([
            'name' => 'መጽሐፈ ቅዳሴ',
            'code' => 'BK-KID-01',
            'kind' => 'physical',
            'domain' => 'timhirt',
            'quantity' => 1,
            'available_quantity' => 0,
            'status' => 'active',
        ]);

        $actx = $this->makeActx($this->librarianAuth);
        $copy = LibraryCirculation::addCopy($actx, $bookId, ['condition' => 'good']);
        $sigDataUrl = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

        // Overdue checkout: due 5 days ago
        $overdueDate = date('Y-m-d', strtotime('-5 days'));
        LibraryCirculation::checkout($actx, [
            'copy_code' => $copy['copy_code'],
            'user_id' => $this->studentAuth->id,
            'due_on' => $overdueDate,
            'signature' => $sigDataUrl,
        ]);

        // Export library-inventory
        $invPdf = ReportExport::export($actx, 'library-inventory', 'pdf', []);
        $this->assertNotEmpty($invPdf[0]);
        $this->assertEquals('application/pdf', $invPdf[1]);

        $invCsv = ReportExport::export($actx, 'library-inventory', 'csv', []);
        $this->assertStringContainsString($copy['copy_code'], $invCsv[0]);
        $this->assertStringContainsString('መጽሐፈ ቅዳሴ', $invCsv[0]);

        // Export library-loans
        $loansCsv = ReportExport::export($actx, 'library-loans', 'csv', []);
        $this->assertStringContainsString($copy['copy_code'], $loansCsv[0]);
        $this->assertStringContainsString('Student Abebe', $loansCsv[0]);

        // Export library-overdue
        $overdueCsv = ReportExport::export($actx, 'library-overdue', 'csv', []);
        $this->assertStringContainsString($copy['copy_code'], $overdueCsv[0]);
    }
}
