<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\EduReportCard;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EduReportCardTest extends TestCase
{
    private AuthContext $adminAuth;
    private AuthContext $studentAuth;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = new AuthContext();
        $this->adminAuth->id = 1;
        $this->adminAuth->fullName = 'Admin User';
        $this->adminAuth->isAdmin = true;
        $this->adminAuth->permissions = ['education.manage' => true, 'education.reports' => true];

        $this->studentAuth = new AuthContext();
        $this->studentAuth->id = 5;
        $this->studentAuth->fullName = 'Abebe Bikila';
        $this->studentAuth->isAdmin = false;
        $this->studentAuth->permissions = [];

        DB::table('users')->updateOrInsert(['id' => 5], [
            'full_name' => 'Abebe Bikila',
            'member_no' => 'MH-00123',
            'status' => 'active',
            'account_type' => 'user',
            'created_at' => Dates::now(),
            'updated_at' => Dates::now(),
        ]);
    }

    private function setUpSchema(): void
    {
        if (! Schema::hasTable('users')) {
            Schema::create('users', function ($table) {
                $table->id();
                $table->string('full_name');
                $table->string('member_no')->nullable();
                $table->string('member_group')->nullable();
                $table->string('phone')->nullable();
                $table->string('status')->default('active');
                $table->string('account_type')->default('user');
                $table->softDeletes();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_classes')) {
            Schema::create('edu_classes', function ($table) {
                $table->id();
                $table->string('name');
                $table->unsignedTinyInteger('grade')->nullable();
                $table->unsignedInteger('academic_year_id')->nullable();
                $table->unsignedInteger('term_id')->nullable();
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_academic_years')) {
            Schema::create('edu_academic_years', function ($table) {
                $table->id();
                $table->string('name');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_terms')) {
            Schema::create('edu_terms', function ($table) {
                $table->id();
                $table->string('name');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_enrollments')) {
            Schema::create('edu_enrollments', function ($table) {
                $table->id();
                $table->unsignedInteger('class_id');
                $table->unsignedInteger('user_id');
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_courses')) {
            Schema::create('edu_courses', function ($table) {
                $table->id();
                $table->unsignedInteger('class_id')->nullable();
                $table->string('name');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_course_outcomes')) {
            Schema::create('edu_course_outcomes', function ($table) {
                $table->id();
                $table->unsignedInteger('course_id');
                $table->unsignedInteger('user_id');
                $table->decimal('percent', 5, 2)->default(0.00);
                $table->string('result')->default('passed');
                $table->string('status')->default('finalized');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('attendance_edu_classes')) {
            Schema::create('attendance_edu_classes', function ($table) {
                $table->id();
                $table->unsignedInteger('session_id');
                $table->unsignedInteger('class_id');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('attendance')) {
            Schema::create('attendance', function ($table) {
                $table->id();
                $table->unsignedInteger('session_id');
                $table->unsignedInteger('user_id');
                $table->string('status')->default('present');
                $table->timestamps();
            });
        }
    }

    public function test_generate_data_computes_accurate_report_card_metrics(): void
    {
        $yearId = DB::table('edu_academic_years')->insertGetId(['name' => '2019 ዓ.ም.']);
        $termId = DB::table('edu_terms')->insertGetId(['name' => '1ኛ መንፈቀ ትምህርት']);
        $classId = DB::table('edu_classes')->insertGetId([
            'name' => '7ኛ ክፍል',
            'grade' => 7,
            'academic_year_id' => $yearId,
            'term_id' => $termId,
        ]);
        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => 5, 'status' => 'active']);

        $c1 = DB::table('edu_courses')->insertGetId(['class_id' => $classId, 'name' => 'መሠረተ ሃይማኖት']);
        $c2 = DB::table('edu_courses')->insertGetId(['class_id' => $classId, 'name' => 'ክርስቲያናዊ ሥነ ምግባር']);

        DB::table('edu_course_outcomes')->insert([
            ['course_id' => $c1, 'user_id' => 5, 'percent' => 88.00, 'result' => 'passed', 'status' => 'finalized'],
            ['course_id' => $c2, 'user_id' => 5, 'percent' => 92.00, 'result' => 'passed', 'status' => 'finalized'],
        ]);

        $data = EduReportCard::generateData($this->studentAuth, 5);

        $this->assertEquals('Abebe Bikila', $data['full_name']);
        $this->assertEquals('7ኛ ክፍል', $data['class_name']);
        $this->assertEquals(7, $data['grade']);
        $this->assertEquals(2, $data['subject_count']);
        $this->assertEquals(180.0, (float) $data['total_score']);
        $this->assertEquals(90.0, (float) $data['average']);
        $this->assertTrue($data['passed']);
    }

    public function test_generate_pdf_renders_valid_pdf_stream(): void
    {
        $yearId = DB::table('edu_academic_years')->insertGetId(['name' => '2019 ዓ.ም.']);
        $termId = DB::table('edu_terms')->insertGetId(['name' => '1ኛ መንፈቀ ትምህርት']);
        $classId = DB::table('edu_classes')->insertGetId([
            'name' => '7ኛ ክፍል',
            'grade' => 7,
            'academic_year_id' => $yearId,
            'term_id' => $termId,
        ]);
        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => 5, 'status' => 'active']);

        $pdf = EduReportCard::generatePdf($this->studentAuth, 5);
        $this->assertNotEmpty($pdf);
        $this->assertStringStartsWith('%PDF-', $pdf, 'Generated output must be a valid PDF document');
    }
}
