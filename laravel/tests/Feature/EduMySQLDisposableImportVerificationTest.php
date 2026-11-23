<?php

namespace Tests\Feature;

use App\Mz\Services\EduCurriculumImport;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use PDO;
use Tests\TestCase;

/**
 * Real MySQL / MariaDB compatibility test running against a strictly disposable database.
 *
 * SAFETY GUARANTEES:
 * 1. Connects to 127.0.0.1:3306 and creates a unique temporary database: `mh_disposable_edu_verif_test`.
 * 2. Never connects to or mutates `hersolot_mh_prod`, `mh_app_test`, or production.
 * 3. Tears down and drops `mh_disposable_edu_verif_test` cleanly after test execution.
 */
class EduMySQLDisposableImportVerificationTest extends TestCase
{
    private const DISPOSABLE_DB = 'mh_disposable_edu_verif_test';
    private static ?PDO $rootPdo = null;

    protected function setUp(): void
    {
        parent::setUp();

        // 1. Check if local MySQL daemon is accessible
        try {
            self::$rootPdo = new PDO('mysql:host=127.0.0.1;port=3306', 'root', '', [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::MYSQL_ATTR_INIT_COMMAND => 'SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci',
            ]);
        } catch (\Throwable $e) {
            $this->markTestSkipped('Local MySQL/MariaDB server unavailable: ' . $e->getMessage());
        }

        // 2. Safely create disposable database (and ensure it does not touch existing DBs)
        self::$rootPdo->exec('CREATE DATABASE IF NOT EXISTS `' . self::DISPOSABLE_DB . '` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');

        // 3. Configure Laravel connection to use ONLY the disposable database
        config([
            'database.connections.mysql_disposable' => [
                'driver' => 'mysql',
                'host' => '127.0.0.1',
                'port' => '3306',
                'database' => self::DISPOSABLE_DB,
                'username' => 'root',
                'password' => '',
                'charset' => 'utf8mb4',
                'collation' => 'utf8mb4_unicode_ci',
                'prefix' => '',
                'strict' => null,
            ],
        ]);
        DB::purge('mysql_disposable');
        DB::setDefaultConnection('mysql_disposable');

        // 4. Initialize schema on disposable database
        $this->setUpMySQLSchema();
    }

    protected function tearDown(): void
    {
        // Disconnect and drop disposable database
        try {
            DB::purge('mysql_disposable');
            DB::setDefaultConnection('sqlite');
            if (self::$rootPdo) {
                self::$rootPdo->exec('DROP DATABASE IF EXISTS `' . self::DISPOSABLE_DB . '`');
            }
        } catch (\Throwable) {
            // Ignore cleanup errors
        }

        parent::tearDown();
    }

    private function setUpMySQLSchema(): void
    {
        // edu_categories
        DB::statement("CREATE TABLE IF NOT EXISTS edu_categories (
            id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
            name varchar(150) NOT NULL,
            name_en varchar(150) DEFAULT NULL,
            description varchar(2000) DEFAULT NULL,
            icon_key varchar(50) DEFAULT NULL,
            sort_order int NOT NULL DEFAULT 0,
            created_at datetime NOT NULL DEFAULT current_timestamp(),
            updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

        // edu_subjects (Real schema matching MySQL migration 2026_10_18_000001)
        DB::statement("CREATE TABLE IF NOT EXISTS edu_subjects (
            id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
            category_id int unsigned DEFAULT NULL,
            name varchar(150) NOT NULL,
            name_en varchar(150) DEFAULT NULL,
            code varchar(30) DEFAULT NULL,
            description varchar(4000) DEFAULT NULL,
            objectives text DEFAULT NULL,
            cover_image varchar(255) DEFAULT NULL,
            visibility enum('enrolled','members') NOT NULL DEFAULT 'enrolled',
            sequential tinyint(1) NOT NULL DEFAULT 0,
            status enum('draft','published','archived') NOT NULL DEFAULT 'draft',
            sort_order int NOT NULL DEFAULT 0,
            grade tinyint unsigned DEFAULT NULL,
            created_by int unsigned DEFAULT NULL,
            updated_by int unsigned DEFAULT NULL,
            created_at datetime NOT NULL DEFAULT current_timestamp(),
            updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
            KEY edu_subjects_category (category_id, status, sort_order),
            CONSTRAINT edu_subjects_cat_fk FOREIGN KEY (category_id) REFERENCES edu_categories (id) ON DELETE SET NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

        // edu_units (Foreign key to edu_subjects)
        DB::statement("CREATE TABLE IF NOT EXISTS edu_units (
            id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
            subject_id int unsigned NOT NULL,
            title varchar(200) NOT NULL,
            description varchar(2000) DEFAULT NULL,
            sort_order int NOT NULL DEFAULT 0,
            status enum('draft','published') NOT NULL DEFAULT 'published',
            created_at datetime NOT NULL DEFAULT current_timestamp(),
            updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
            KEY edu_units_subject (subject_id, sort_order),
            CONSTRAINT edu_units_subj_fk FOREIGN KEY (subject_id) REFERENCES edu_subjects (id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

        // edu_lessons (Foreign key to edu_units & edu_subjects)
        DB::statement("CREATE TABLE IF NOT EXISTS edu_lessons (
            id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
            subject_id int unsigned NOT NULL,
            unit_id int unsigned NOT NULL,
            title varchar(200) NOT NULL,
            body longtext DEFAULT NULL,
            sort_order int NOT NULL DEFAULT 0,
            status enum('draft','published') NOT NULL DEFAULT 'published',
            created_at datetime NOT NULL DEFAULT current_timestamp(),
            updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
            KEY edu_lessons_unit (unit_id, sort_order),
            KEY edu_lessons_subject (subject_id),
            CONSTRAINT edu_lessons_subj_fk FOREIGN KEY (subject_id) REFERENCES edu_subjects (id) ON DELETE CASCADE,
            CONSTRAINT edu_lessons_unit_fk FOREIGN KEY (unit_id) REFERENCES edu_units (id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

        // edu_classes (Legacy baseline schema with level_id)
        DB::statement("CREATE TABLE IF NOT EXISTS edu_classes (
            id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
            name varchar(150) NOT NULL,
            description varchar(500) DEFAULT NULL,
            term varchar(50) DEFAULT NULL,
            level_id int unsigned DEFAULT NULL,
            status enum('active','archived') NOT NULL DEFAULT 'active',
            created_at datetime NOT NULL DEFAULT current_timestamp(),
            updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

        // edu_courses (Linked to class and subject)
        DB::statement("CREATE TABLE IF NOT EXISTS edu_courses (
            id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
            class_id int unsigned NOT NULL,
            subject_id int unsigned DEFAULT NULL,
            name varchar(150) NOT NULL,
            created_at datetime NOT NULL DEFAULT current_timestamp(),
            updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

        // edu_enrollments
        DB::statement("CREATE TABLE IF NOT EXISTS edu_enrollments (
            id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
            class_id int unsigned NOT NULL,
            user_id int unsigned NOT NULL,
            program enum('regular','distance') NOT NULL DEFAULT 'regular',
            status enum('active','withdrawn','completed') NOT NULL DEFAULT 'active',
            created_at datetime NOT NULL DEFAULT current_timestamp(),
            updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

        // attendance
        DB::statement("CREATE TABLE IF NOT EXISTS attendance (
            id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
            user_id int unsigned NOT NULL,
            class_id int unsigned DEFAULT NULL,
            date date NOT NULL,
            status varchar(20) NOT NULL DEFAULT 'present',
            created_at datetime NOT NULL DEFAULT current_timestamp(),
            updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

        // Seed 7 standard church categories
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
            DB::table('edu_categories')->insert($cat);
        }

        // Seed Class 1 (7ኛ) and its 6 courses from hersolot_mh_prod.sql
        DB::table('edu_classes')->insert([
            'id' => 1,
            'name' => '7ኛ',
            'description' => 'ወጣቶች',
            'term' => '2019',
            'level_id' => 7,
            'status' => 'active',
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
            DB::table('edu_courses')->insert($c);
        }

        DB::table('edu_enrollments')->insert([
            ['id' => 1, 'class_id' => 1, 'user_id' => 1, 'program' => 'distance', 'status' => 'active'],
            ['id' => 2, 'class_id' => 1, 'user_id' => 18, 'program' => 'regular', 'status' => 'active'],
        ]);

        DB::table('attendance')->insert([
            ['id' => 1, 'user_id' => 1, 'class_id' => 1, 'date' => '2026-10-04', 'status' => 'present'],
            ['id' => 2, 'user_id' => 18, 'class_id' => 1, 'date' => '2026-10-04', 'status' => 'present'],
        ]);
    }

    public function test_mysql_disposable_database_curriculum_import_full_lifecycle(): void
    {
        $serverVersion = self::$rootPdo->getAttribute(PDO::ATTR_SERVER_VERSION);
        $this->assertNotEmpty($serverVersion);

        // --- STEP 1: Dry-Run Import (Zero DB writes) ---
        $dryRunSummary = EduCurriculumImport::import(true);
        $this->assertTrue($dryRunSummary['dry_run']);
        $this->assertEquals(12, $dryRunSummary['grades_processed']);
        $this->assertEquals(81, $dryRunSummary['subjects_created']);
        $this->assertEquals(415, $dryRunSummary['units_created']);
        $this->assertEquals(2951, $dryRunSummary['lessons_created']);

        // Assert 0 rows in MySQL database tables after dry run
        $this->assertEquals(0, DB::table('edu_subjects')->count(), 'Dry-run must not write to MySQL edu_subjects');
        $this->assertEquals(0, DB::table('edu_units')->count(), 'Dry-run must not write to MySQL edu_units');
        $this->assertEquals(0, DB::table('edu_lessons')->count(), 'Dry-run must not write to MySQL edu_lessons');

        // --- STEP 2: Live Local MySQL Import ---
        $importSummary = EduCurriculumImport::import(false);
        $this->assertFalse($importSummary['dry_run']);
        $this->assertEquals(12, $importSummary['grades_processed']);
        $this->assertEquals(81, $importSummary['subjects_created']);
        $this->assertEquals(415, $importSummary['units_created']);
        $this->assertEquals(2951, $importSummary['lessons_created']);
        $this->assertEquals(6, $importSummary['legacy_courses_mapped']);

        // Assert exact persisted counts in MySQL tables
        $this->assertEquals(81, DB::table('edu_subjects')->count(), 'MySQL edu_subjects count must be exactly 81');
        $this->assertEquals(415, DB::table('edu_units')->count(), 'MySQL edu_units count must be exactly 415');
        $this->assertEquals(2951, DB::table('edu_lessons')->count(), 'MySQL edu_lessons count must be exactly 2,951');

        // --- STEP 3: MySQL Foreign Key and Structural Integrity ---
        $orphanedUnits = DB::table('edu_units as u')
            ->leftJoin('edu_subjects as s', 's.id', '=', 'u.subject_id')
            ->whereNull('s.id')
            ->count();
        $this->assertEquals(0, $orphanedUnits, 'Zero orphaned units in MySQL');

        $orphanedLessons = DB::table('edu_lessons as l')
            ->leftJoin('edu_units as u', 'u.id', '=', 'l.unit_id')
            ->whereNull('u.id')
            ->count();
        $this->assertEquals(0, $orphanedLessons, 'Zero orphaned lessons in MySQL');

        // --- STEP 4: Amharic / Ethiopic Unicode Encoding Integrity in MySQL ---
        $subj1 = DB::table('edu_subjects')->where('sort_order', 7)->where('name', 'like', '%መሠረተ ሃይማኖት%')->first();
        $this->assertNotNull($subj1, 'Grade 7 መሠረተ ሃይማኖት must exist in MySQL');
        $this->assertStringNotContainsString('?', $subj1->name, 'Amharic text must not be corrupted to question marks in MySQL');

        $histSubj = DB::table('edu_subjects')->where('sort_order', 7)->where('name', 'like', '%የቤተ ክርስቲያን ታሪክ%')->first();
        $this->assertNotNull($histSubj, 'Grade 7 Church History must exist in MySQL');
        $this->assertStringNotContainsString('?', $histSubj->name);

        // --- STEP 5: Idempotency (Second Run on Populated MySQL Database) ---
        $secondSummary = EduCurriculumImport::import(false);
        $this->assertEquals(0, $secondSummary['subjects_created'], 'Zero new subjects created on second run');
        $this->assertEquals(81, $secondSummary['subjects_updated'], 'All 81 subjects updated/reused on second run');
        $this->assertEquals(0, $secondSummary['units_created'], 'Zero new units created on second run');
        $this->assertEquals(415, $secondSummary['units_updated'], 'All 415 units updated/reused on second run');
        $this->assertEquals(0, $secondSummary['lessons_created'], 'Zero new lessons created on second run');
        $this->assertEquals(2951, $secondSummary['lessons_updated'], 'All 2,951 lessons updated/reused on second run');

        // Assert counts remain identical
        $this->assertEquals(81, DB::table('edu_subjects')->count(), 'MySQL edu_subjects count stable after 2nd run');
        $this->assertEquals(415, DB::table('edu_units')->count(), 'MySQL edu_units count stable after 2nd run');
        $this->assertEquals(2951, DB::table('edu_lessons')->count(), 'MySQL edu_lessons count stable after 2nd run');

        // --- STEP 6: Legacy Class 1 (7ኛ) and 6 Course Mapping Verification ---
        $courses = DB::table('edu_courses')->where('class_id', 1)->orderBy('id')->get();
        $this->assertCount(6, $courses, 'Class 1 must have exactly 6 courses');
        foreach ($courses as $c) {
            $this->assertNotNull($c->subject_id, "Course {$c->id} ({$c->name}) must be mapped to subject_id in MySQL");
            $mappedSubj = DB::table('edu_subjects')->where('id', $c->subject_id)->first();
            $this->assertNotNull($mappedSubj, "Mapped subject must exist in MySQL");
            $subjGrade = $mappedSubj->grade ?? $mappedSubj->sort_order;
            $this->assertEquals(7, (int) $subjGrade, "Course {$c->name} must map to Grade 7 subject, got Grade {$subjGrade}");
        }

        // --- STEP 7: Existing Records Untouched ---
        $class1 = DB::table('edu_classes')->where('id', 1)->first();
        $this->assertEquals('7ኛ', $class1->name);
        $this->assertEquals(2, DB::table('edu_enrollments')->where('class_id', 1)->count());
        $this->assertEquals(2, DB::table('attendance')->where('class_id', 1)->count());
    }
}
