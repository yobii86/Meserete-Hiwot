<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Library;
use App\Mz\Services\LibraryCirculation;
use App\Mz\Support\ApiError;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EducationLibraryAndCatalogTest extends TestCase
{
    private AuthContext $adminAuth;
    private array $adminActx;
    private AuthContext $memberAuth;
    private array $memberActx;

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
            'items.manage' => true,
            'library.circulate' => true,
            'borrowing.manage' => true,
        ];

        $this->adminActx = [
            'auth' => $this->adminAuth,
            'ip' => '127.0.0.1',
            'userAgent' => 'PHPUnit',
            'requestId' => 'req-' . uniqid(),
            'source' => 'web',
            'offset' => 0,
        ];

        $this->memberAuth = new AuthContext();
        $this->memberAuth->id = 2;
        $this->memberAuth->fullName = 'Student Yohannes';
        $this->memberAuth->status = 'active';
        $this->memberAuth->accountType = 'user';
        $this->memberAuth->tokenVersion = 1;
        $this->memberAuth->mustChangePassword = false;
        $this->memberAuth->isAdmin = false;
        $this->memberAuth->isSystem = false;
        $this->memberAuth->isMemberStaff = false;
        $this->memberAuth->level = 10;
        $this->memberAuth->permissions = [];

        $this->memberActx = [
            'auth' => $this->memberAuth,
            'ip' => '127.0.0.1',
            'userAgent' => 'PHPUnit',
            'requestId' => 'req-' . uniqid(),
            'source' => 'web',
            'offset' => 0,
        ];
    }

    private function setUpSchema(): void
    {
        Schema::dropIfExists('library_loans');
        Schema::dropIfExists('library_copies');
        Schema::dropIfExists('library_requests');
        Schema::dropIfExists('library_favorites');
        Schema::dropIfExists('library_progress');
        Schema::dropIfExists('borrowings');
        Schema::dropIfExists('items');
        Schema::dropIfExists('library_categories');
        Schema::dropIfExists('audit_logs');
        Schema::dropIfExists('settings');
        Schema::dropIfExists('users');

        DB::statement('CREATE TABLE settings (
            `key` VARCHAR(100) PRIMARY KEY,
            `value` TEXT NULL,
            `created_at` DATETIME NULL,
            `updated_at` DATETIME NULL
        )');

        DB::statement('CREATE TABLE audit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            actor_id INTEGER NULL,
            is_hidden BOOLEAN NOT NULL DEFAULT 0,
            action VARCHAR(100) NOT NULL,
            entity_type VARCHAR(50) NOT NULL,
            entity_id INTEGER NOT NULL,
            metadata TEXT NULL,
            ip VARCHAR(45) NULL,
            user_agent VARCHAR(255) NULL,
            created_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name VARCHAR(150) NOT NULL,
            phone VARCHAR(30) NULL,
            member_no INTEGER NULL,
            member_group VARCHAR(10) NULL,
            deleted_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE borrowings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            status VARCHAR(30) NOT NULL DEFAULT "active"
        )');

        DB::statement('CREATE TABLE library_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            parent_id INTEGER NULL,
            domain VARCHAR(32) NULL DEFAULT "timhirt",
            name VARCHAR(200) NOT NULL,
            name_en VARCHAR(200) NULL,
            code VARCHAR(32) NULL,
            category_type VARCHAR(20) NOT NULL DEFAULT "both",
            description TEXT NULL,
            is_active BOOLEAN NOT NULL DEFAULT 1,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(200) NOT NULL,
            subtitle VARCHAR(200) NULL,
            author VARCHAR(150) NULL,
            publisher VARCHAR(150) NULL,
            publication_year INTEGER NULL,
            language VARCHAR(20) NOT NULL DEFAULT "am",
            category VARCHAR(100) NULL,
            library_category_id INTEGER NULL,
            kind VARCHAR(30) NOT NULL DEFAULT "physical",
            domain VARCHAR(32) NOT NULL DEFAULT "timhirt",
            code VARCHAR(64) NOT NULL UNIQUE,
            status VARCHAR(30) NOT NULL DEFAULT "active",
            quantity INTEGER NOT NULL DEFAULT 0,
            available_quantity INTEGER NOT NULL DEFAULT 0,
            condition VARCHAR(50) NULL,
            location VARCHAR(100) NULL,
            notes TEXT NULL,
            description TEXT NULL,
            image VARCHAR(255) NULL,
            file_path VARCHAR(255) NULL,
            file_mime VARCHAR(100) NULL,
            file_size INTEGER NULL,
            narration_path VARCHAR(255) NULL,
            narration_mime VARCHAR(100) NULL,
            narration_duration INTEGER NULL,
            downloads INTEGER NOT NULL DEFAULT 0,
            created_by INTEGER NULL,
            updated_by INTEGER NULL,
            deleted_at DATETIME NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE library_copies (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_id INTEGER NOT NULL,
            copy_no INTEGER NOT NULL,
            copy_code VARCHAR(64) NOT NULL UNIQUE,
            condition VARCHAR(30) NOT NULL DEFAULT "good",
            location VARCHAR(100) NULL,
            status VARCHAR(30) NOT NULL DEFAULT "available",
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE library_loans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            copy_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            status VARCHAR(30) NOT NULL DEFAULT "active",
            checked_out_at DATETIME NULL,
            due_on DATE NULL,
            returned_at DATETIME NULL,
            condition_out VARCHAR(30) NOT NULL DEFAULT "good",
            condition_in VARCHAR(30) NULL,
            issued_by INTEGER NOT NULL,
            received_by INTEGER NULL,
            signature_path VARCHAR(255) NULL,
            notes TEXT NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE library_requests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            item_id INTEGER NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            note TEXT NULL,
            needed_on DATE NULL,
            status VARCHAR(30) NOT NULL DEFAULT "requested",
            review_note TEXT NULL,
            reviewed_by INTEGER NULL,
            reviewed_at DATETIME NULL,
            borrowing_id INTEGER NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE library_favorites (
            user_id INTEGER NOT NULL,
            item_id INTEGER NOT NULL,
            created_at DATETIME NULL,
            PRIMARY KEY (user_id, item_id)
        )');

        DB::statement('CREATE TABLE library_progress (
            user_id INTEGER NOT NULL,
            item_id INTEGER NOT NULL,
            page INTEGER NOT NULL DEFAULT 1,
            page_count INTEGER NULL,
            audio_position_ms INTEGER NOT NULL DEFAULT 0,
            updated_at DATETIME NULL,
            PRIMARY KEY (user_id, item_id)
        )');
    }

    public function test_categories_and_unclassified_filtering(): void
    {
        // 1. Create two categories
        $theoCat = Library::saveCategory($this->adminActx, [
            'name' => 'ትምህርተ ሃይማኖት',
            'code' => 'THEO',
            'domain' => 'timhirt',
            'sort_order' => 1,
        ]);
        $bibleCat = Library::saveCategory($this->adminActx, [
            'name' => 'መጽሐፍ ቅዱስ ጥናት',
            'code' => 'BIBLE',
            'domain' => 'timhirt',
            'sort_order' => 2,
        ]);

        // 2. Create books under categories
        $theoBook = Library::saveDigitalBook($this->adminActx, [
            'name' => 'ሃይማኖተ አበው',
            'author' => 'ሊቃውንተ ቤተክርስቲያን',
            'library_category_id' => $theoCat['id'],
            'domain' => 'timhirt',
        ]);
        DB::table('items')->where('id', $theoBook['id'])->update(['file_path' => 'private/books/theo.pdf']);

        $bibleBook = Library::saveDigitalBook($this->adminActx, [
            'name' => 'የኦሪት ዘፍጥረት ትርጓሜ',
            'author' => 'ዮሐንስ አፈወርቅ',
            'library_category_id' => $bibleCat['id'],
            'domain' => 'timhirt',
        ]);
        DB::table('items')->where('id', $bibleBook['id'])->update(['file_path' => 'private/books/bible.pdf']);

        // 3. Create unclassified book
        $unclassBook = Library::saveDigitalBook($this->adminActx, [
            'name' => 'አጠቃላይ መንፈሳዊ ጽሑፍ',
            'author' => 'ያልታወቀ ደራሲ',
            'domain' => 'timhirt',
        ]);
        DB::table('items')->where('id', $unclassBook['id'])->update(['file_path' => 'private/books/gen.pdf']);

        // 4. Verify categories count
        $cats = Library::categories('timhirt', false);
        $this->assertCount(2, $cats);
        $this->assertSame(1, $cats[0]['books_count']);
        $this->assertSame(1, $cats[1]['books_count']);

        // 5. Filter by specific category
        $theoList = Library::books($this->memberAuth, ['category_id' => $theoCat['id'], 'domain' => 'timhirt'], ['page' => 1, 'per_page' => 10]);
        $this->assertCount(1, $theoList['items']);
        $this->assertSame('ሃይማኖተ አበው', $theoList['items'][0]['title']);

        // 6. Filter by unclassified (category_id = -1)
        $unclassList = Library::books($this->memberAuth, ['category_id' => -1, 'domain' => 'timhirt'], ['page' => 1, 'per_page' => 10]);
        $this->assertCount(1, $unclassList['items']);
        $this->assertSame('አጠቃላይ መንፈሳዊ ጽሑፍ', $unclassList['items'][0]['title']);
        $this->assertNull($unclassList['items'][0]['category_id']);
    }

    public function test_admin_book_catalog_draft_and_status_visibility(): void
    {
        // 1. Create a draft digital book (no PDF uploaded yet)
        $draftBook = Library::saveDigitalBook($this->adminActx, [
            'name' => 'ረቂቅ ዲጂታል መጽሐፍ',
            'author' => 'መጋቤ ሐዲስ',
            'domain' => 'timhirt',
            'status' => 'active',
        ]);

        // 2. Create an inactive physical book
        $inactiveBook = Library::savePhysicalBook($this->adminActx, [
            'name' => 'ያልነቃ የታተመ መጽሐፍ',
            'author' => 'ዲ/ን ሄኖክ',
            'domain' => 'timhirt',
            'status' => 'inactive',
            'quantity' => 2,
        ]);

        // Member cannot see draft (no PDF) nor inactive book
        $memberView = Library::books($this->memberAuth, ['domain' => 'timhirt'], ['page' => 1, 'per_page' => 10]);
        $this->assertCount(0, $memberView['items']);

        // Admin with include_drafts and status=all sees both!
        $adminView = Library::books($this->adminAuth, [
            'domain' => 'timhirt',
            'include_drafts' => true,
            'status' => 'all',
        ], ['page' => 1, 'per_page' => 10]);
        $this->assertCount(2, $adminView['items']);

        // Admin can fetch inactive book directly by ID
        $fetched = Library::book($this->adminAuth, $inactiveBook['id']);
        $this->assertSame('inactive', $fetched['status']);
    }

    public function test_physical_book_copies_management(): void
    {
        // 1. Create a physical book
        $physBook = Library::savePhysicalBook($this->adminActx, [
            'name' => 'ሥርዓተ ቤተክርስቲያን መማሪያ',
            'author' => 'መልአከ ሰላም',
            'domain' => 'timhirt',
            'quantity' => 1,
        ]);

        // 2. Add two copies
        $copy1 = LibraryCirculation::addCopy($this->adminActx, $physBook['id'], [
            'condition' => 'good',
            'location' => 'Shelf A-1',
        ]);
        $copy2 = LibraryCirculation::addCopy($this->adminActx, $physBook['id'], [
            'condition' => 'fair',
            'location' => 'Shelf A-2',
        ]);

        $this->assertStringStartsWith('LIB-', $copy1['copy_code']);
        $this->assertSame('Shelf A-1', $copy1['location']);

        // 3. Update copy location & condition
        $updatedCopy1 = LibraryCirculation::updateCopy($this->adminActx, $copy1['id'], [
            'condition' => 'poor',
            'location' => 'Reserve Shelf R-1',
        ]);
        $this->assertSame('poor', $updatedCopy1['condition']);
        $this->assertSame('Reserve Shelf R-1', $updatedCopy1['location']);

        // 4. Delete copy2
        $del = LibraryCirculation::deleteCopy($this->adminActx, $copy2['id']);
        $this->assertTrue($del['deleted']);

        // Copies count should now be 1
        $copiesList = LibraryCirculation::copies(['item_id' => $physBook['id']], ['page' => 1, 'per_page' => 10]);
        $this->assertCount(1, $copiesList['items']);
        $this->assertSame($copy1['id'], $copiesList['items'][0]['id']);
    }

    public function test_migration_seed_and_idempotency_preserves_existing_and_unrelated_domains(): void
    {
        // 1. Create unrelated domain category (mezmur)
        $mezmurCatId = DB::table('library_categories')->insertGetId([
            'domain' => 'mezmur',
            'name' => 'የመዝሙር መጽሐፍት',
            'name_en' => 'Hymnbooks',
            'code' => 'MEZ-HYMN',
            'category_type' => 'both',
            'description' => 'Unrelated domain category',
            'sort_order' => 99,
            'is_active' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // 2. Create existing category with NULL domain and existing custom description
        $legacyNullId = DB::table('library_categories')->insertGetId([
            'domain' => null,
            'name' => 'የቀደመ ያልተመደበ ምድብ',
            'code' => 'LEGACY',
            'category_type' => 'both',
            'sort_order' => 50,
            'is_active' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $customTheoId = DB::table('library_categories')->insertGetId([
            'domain' => 'timhirt',
            'name' => 'ትምህርተ ሃይማኖት',
            'code' => 'THEO',
            'category_type' => 'both',
            'description' => 'Custom pre-existing description preserved',
            'sort_order' => 1,
            'is_active' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // 3. Execute migration up()
        $migration = require database_path('migrations/2026_11_09_000001_seed_education_library_categories.php');
        $migration->up();

        // 4. Verify unrelated domain was NOT changed
        $mezmurCat = DB::table('library_categories')->where('id', $mezmurCatId)->first();
        $this->assertSame('mezmur', $mezmurCat->domain);
        $this->assertSame('Unrelated domain category', $mezmurCat->description);

        // 5. Verify NULL domain was normalized to timhirt
        $legacyCat = DB::table('library_categories')->where('id', $legacyNullId)->first();
        $this->assertSame('timhirt', $legacyCat->domain);

        // 6. Verify custom description on existing THEO was preserved
        $theoCat = DB::table('library_categories')->where('id', $customTheoId)->first();
        $this->assertSame('Custom pre-existing description preserved', $theoCat->description);

        // 7. Test Idempotency: execute migration up() a second time
        $migration->up();

        // Count categories with code THEO: MUST still be exactly 1
        $theoCount = DB::table('library_categories')->where('code', 'THEO')->count();
        $this->assertSame(1, $theoCount);

        // Standard 9 categories are present
        $totalStandard = DB::table('library_categories')->where('domain', 'timhirt')->whereIn('code', [
            'THEO', 'BIBLE', 'HIST', 'LIT', 'ETHIC', 'KIDS', 'REF', 'HYMN', 'MAG'
        ])->count();
        $this->assertSame(9, $totalStandard);
    }

    public function test_book_editing_and_soft_delete_preserves_data_integrity(): void
    {
        // 1. Create a physical book
        $initial = Library::savePhysicalBook($this->adminActx, [
            'name' => 'የቀዳሚት ሰንበት ሥርዓት',
            'author' => 'መጋቤ ምስጢር',
            'publisher' => 'ተንሣኤ ማተሚያ ቤት',
            'publication_year' => 2012,
            'domain' => 'timhirt',
            'quantity' => 3,
        ]);
        $bookId = $initial['id'];

        // 2. Edit the book in-place
        $edited = Library::savePhysicalBook($this->adminActx, [
            'name' => 'የሰንበት ሥርዓተ ቅዳሴና ታሪክ',
            'author' => 'መጋቤ ምስጢር ዳዊት',
            'publisher' => 'ማኅበረ ቅዱሳን',
            'publication_year' => 2015,
            'domain' => 'timhirt',
            'quantity' => 3,
        ], $bookId);

        // Must preserve the exact same ID
        $this->assertSame($bookId, $edited['id']);
        $this->assertSame('የሰንበት ሥርዓተ ቅዳሴና ታሪክ', $edited['title']);
        $this->assertSame('መጋቤ ምስጢር ዳዊት', $edited['author']);

        // Verify total items count did NOT increase (no duplication)
        $itemsCount = DB::table('items')->where('domain', 'timhirt')->count();
        $this->assertSame(1, $itemsCount);

        // 3. Soft delete the book
        \App\Mz\Services\Items::remove($this->adminActx, $bookId);

        // Row remains in table with deleted_at set and status='retired'
        $deletedRow = DB::table('items')->where('id', $bookId)->first();
        $this->assertNotNull($deletedRow->deleted_at);
        $this->assertSame('retired', $deletedRow->status);
    }

    public function test_cannot_delete_physical_copy_on_active_loan(): void
    {
        // 1. Create a physical book and copy
        $physBook = Library::savePhysicalBook($this->adminActx, [
            'name' => 'ድርሳነ ሚካኤል',
            'author' => 'ሊቃውንት',
            'domain' => 'timhirt',
            'quantity' => 0,
        ]);
        $copy = LibraryCirculation::addCopy($this->adminActx, $physBook['id'], [
            'condition' => 'good',
            'location' => 'Main Shelf 1',
        ]);

        // 2. Record an active loan for this copy
        $loanId = DB::table('library_loans')->insertGetId([
            'copy_id' => $copy['id'],
            'user_id' => $this->memberAuth->id,
            'status' => 'active',
            'checked_out_at' => now(),
            'due_on' => now()->addDays(14)->toDateString(),
            'condition_out' => 'good',
            'issued_by' => $this->adminAuth->id,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // 3. Attempting to delete copy while on active loan must fail
        $failed = false;
        try {
            LibraryCirculation::deleteCopy($this->adminActx, $copy['id']);
        } catch (ApiError $e) {
            $failed = true;
            $this->assertSame('COPY_ON_LOAN', $e->errorCode);
        }
        $this->assertTrue($failed, 'Expected ApiError with COPY_ON_LOAN when attempting to delete loaned copy');

        // Copy still exists
        $this->assertNotNull(DB::table('library_copies')->where('id', $copy['id'])->first());

        // 4. Return loan
        DB::table('library_loans')->where('id', $loanId)->update([
            'status' => 'returned',
            'returned_at' => now(),
            'condition_in' => 'good',
        ]);

        // 5. Deleting copy now succeeds and decrements item quantity
        $del = LibraryCirculation::deleteCopy($this->adminActx, $copy['id']);
        $this->assertTrue($del['deleted']);
        $this->assertNull(DB::table('library_copies')->where('id', $copy['id'])->first());

        $item = DB::table('items')->where('id', $physBook['id'])->first();
        $this->assertSame(0, $item->quantity);
    }

    public function test_authorization_matrix_and_circulation_boundary(): void
    {
        // 1. Inactive book created by admin
        $inactiveBook = Library::savePhysicalBook($this->adminActx, [
            'name' => 'የተደበቀ መጽሐፍ',
            'author' => 'የማይታወቅ',
            'domain' => 'timhirt',
            'status' => 'inactive',
        ]);

        // 2. Student cannot fetch inactive book
        $studentDenied = false;
        try {
            Library::book($this->memberAuth, $inactiveBook['id']);
        } catch (ApiError $e) {
            $studentDenied = true;
            $this->assertSame('BOOK_NOT_FOUND', $e->errorCode);
        }
        $this->assertTrue($studentDenied, 'Ordinary student must not be able to fetch inactive book');

        // 3. Teacher without items.manage or education.manage cannot fetch inactive book
        $teacherAuth = new AuthContext();
        $teacherAuth->id = 3;
        $teacherAuth->fullName = 'Teacher Dawit';
        $teacherAuth->status = 'active';
        $teacherAuth->accountType = 'user';
        $teacherAuth->tokenVersion = 1;
        $teacherAuth->mustChangePassword = false;
        $teacherAuth->isAdmin = false;
        $teacherAuth->isSystem = false;
        $teacherAuth->isMemberStaff = false;
        $teacherAuth->level = 20;
        $teacherAuth->permissions = ['education.classes.teach' => true];

        $teacherDenied = false;
        try {
            Library::book($teacherAuth, $inactiveBook['id']);
        } catch (ApiError $e) {
            $teacherDenied = true;
            $this->assertSame('BOOK_NOT_FOUND', $e->errorCode);
        }
        $this->assertTrue($teacherDenied, 'Teacher without catalog manage permissions must not fetch inactive book');

        // 4. Authorized Education Administrator CAN fetch inactive book
        $eduAdminAuth = new AuthContext();
        $eduAdminAuth->id = 4;
        $eduAdminAuth->fullName = 'Edu Admin Aster';
        $eduAdminAuth->status = 'active';
        $eduAdminAuth->accountType = 'admin';
        $eduAdminAuth->tokenVersion = 1;
        $eduAdminAuth->mustChangePassword = false;
        $eduAdminAuth->isAdmin = false;
        $eduAdminAuth->isSystem = false;
        $eduAdminAuth->isMemberStaff = false;
        $eduAdminAuth->level = 80;
        $eduAdminAuth->permissions = ['education.manage' => true];

        $eduAdminBook = Library::book($eduAdminAuth, $inactiveBook['id']);
        $this->assertSame('inactive', $eduAdminBook['status']);
        $this->assertSame('የተደበቀ መጽሐፍ', $eduAdminBook['title']);
    }
}
