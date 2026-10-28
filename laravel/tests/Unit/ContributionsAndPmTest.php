<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Projects\DecisionService;
use App\Mz\Projects\MilestoneService;
use App\Mz\Projects\Pm;
use App\Mz\Projects\ProgressReportService;
use App\Mz\Projects\RecognitionService;
use App\Mz\Projects\TimesheetService;
use App\Mz\Services\CalendarService;
use App\Mz\Services\ContributionReceipts;
use App\Mz\Services\Payments;
use App\Mz\Support\Dates;
use App\Mz\Support\Ethiopian;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class ContributionsAndPmTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        \App\Mz\Projects\Access::reset();

        // Ensure database tables exist in sqlite/in-memory or active connection for testing
        if (! Schema::hasTable('users')) {
            Schema::create('users', function ($table) {
                $table->increments('id');
                $table->string('username', 50)->nullable();
                $table->string('full_name', 150);
                $table->string('phone', 30)->nullable();
                $table->string('email', 150)->nullable();
                $table->string('member_no', 30)->nullable();
                $table->string('member_group', 30)->default('youth_adult');
                $table->string('member_type', 30)->nullable();
                $table->string('account_type', 30)->default('user');
                $table->unsignedInteger('role_id')->nullable();
                $table->string('status', 30)->default('active');
                $table->string('membership_status', 30)->default('active');
                $table->string('profile_image', 255)->nullable();
                $table->timestamps();
                $table->softDeletes();
            });
        }

        if (! Schema::hasTable('payment_rates')) {
            Schema::create('payment_rates', function ($table) {
                $table->increments('id');
                $table->string('member_type', 30);
                $table->decimal('monthly_amount', 12, 2);
                $table->string('currency', 8)->default('ETB');
                $table->date('effective_from');
                $table->unsignedInteger('created_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('payments')) {
            Schema::create('payments', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('user_id');
                $table->string('period', 7);
                $table->unsignedInteger('months')->default(1);
                $table->string('coverage_end', 7);
                $table->string('member_type', 30)->nullable();
                $table->decimal('monthly_rate', 12, 2)->nullable();
                $table->decimal('amount', 12, 2);
                $table->string('currency', 8)->default('ETB');
                $table->string('method', 30)->default('cash');
                $table->string('reference', 120)->nullable();
                $table->date('paid_on');
                $table->string('receipt', 255)->nullable();
                $table->string('note', 500)->nullable();
                $table->string('status', 30)->default('recorded');
                $table->unsignedInteger('recorded_by')->nullable();
                $table->unsignedInteger('verified_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('contribution_receipts')) {
            Schema::create('contribution_receipts', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('user_id');
                $table->string('period', 7);
                $table->unsignedInteger('months')->default(1);
                $table->string('coverage_end', 7);
                $table->decimal('expected_amount', 12, 2);
                $table->decimal('submitted_amount', 12, 2);
                $table->string('currency', 8)->default('ETB');
                $table->string('method', 30)->default('bank');
                $table->string('reference', 120)->nullable();
                $table->date('paid_on');
                $table->string('receipt_path', 255);
                $table->text('member_note')->nullable();
                $table->string('status', 30)->default('submitted');
                $table->text('review_note')->nullable();
                $table->unsignedInteger('reviewed_by')->nullable();
                $table->dateTime('reviewed_at')->nullable();
                $table->unsignedInteger('payment_id')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('departments')) {
            Schema::create('departments', function ($table) {
                $table->increments('id');
                $table->string('name', 100);
                $table->string('name_en', 100)->nullable();
                $table->boolean('is_active')->default(true);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('department_admins')) {
            Schema::create('department_admins', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('user_id');
                $table->unsignedInteger('department_id');
                $table->unsignedInteger('role_id')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('user_departments')) {
            Schema::create('user_departments', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('user_id');
                $table->unsignedInteger('department_id');
                $table->string('role', 30)->default('member');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('audit_logs')) {
            Schema::create('audit_logs', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('actor_id')->nullable();
                $table->string('actor_type', 50)->nullable();
                $table->string('action', 100);
                $table->string('entity_type', 50)->nullable();
                $table->unsignedInteger('entity_id')->nullable();
                $table->boolean('is_hidden')->default(false);
                $table->text('metadata')->nullable();
                $table->string('ip', 45)->nullable();
                $table->string('user_agent', 255)->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('projects')) {
            Schema::create('projects', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('department_id');
                $table->string('title', 200);
                $table->text('description')->nullable();
                $table->unsignedInteger('leader_id')->nullable();
                $table->date('start_date')->nullable();
                $table->dateTime('deadline')->nullable();
                $table->string('status', 30)->default('planning');
                $table->string('priority', 30)->default('medium');
                $table->unsignedTinyInteger('progress')->default(0);
                $table->string('progress_mode', 30)->default('tasks');
                $table->text('notes')->nullable();
                $table->boolean('allow_late_tasks')->default(false);
                $table->string('currency', 8)->default('ETB');
                $table->decimal('proposed_budget', 14, 2)->nullable();
                $table->decimal('approved_budget', 14, 2)->nullable();
                $table->unsignedInteger('budget_approved_by')->nullable();
                $table->dateTime('budget_approved_at')->nullable();
                $table->dateTime('completed_at')->nullable();
                $table->unsignedInteger('created_by')->nullable();
                $table->unsignedInteger('updated_by')->nullable();
                $table->timestamps();
                $table->softDeletes();
            });
        }

        if (! Schema::hasTable('project_members')) {
            Schema::create('project_members', function ($table) {
                $table->unsignedInteger('project_id');
                $table->unsignedInteger('user_id');
                $table->string('role', 20)->default('member');
                $table->unsignedInteger('added_by')->nullable();
                $table->dateTime('created_at')->nullable();
                $table->primary(['project_id', 'user_id']);
            });
        }

        if (! Schema::hasTable('project_task_assignees')) {
            Schema::create('project_task_assignees', function ($table) {
                $table->unsignedInteger('task_id');
                $table->unsignedInteger('user_id');
                $table->unsignedInteger('assigned_by')->nullable();
                $table->dateTime('created_at')->nullable();
                $table->primary(['task_id', 'user_id']);
            });
        }

        if (! Schema::hasTable('project_tasks')) {
            Schema::create('project_tasks', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('project_id');
                $table->unsignedInteger('department_id');
                $table->string('title', 200);
                $table->text('description')->nullable();
                $table->date('start_date')->nullable();
                $table->dateTime('deadline')->nullable();
                $table->string('priority', 30)->default('medium');
                $table->string('status', 30)->default('not_started');
                $table->string('status_reason', 500)->nullable();
                $table->string('pending_reason', 50)->nullable();
                $table->unsignedTinyInteger('progress')->default(0);
                $table->unsignedSmallInteger('weight')->default(1);
                $table->text('notes')->nullable();
                $table->unsignedInteger('issue_id')->nullable();
                $table->unsignedInteger('program_id')->nullable();
                $table->unsignedInteger('suggestion_id')->nullable();
                $table->dateTime('completed_at')->nullable();
                $table->unsignedInteger('completed_by')->nullable();
                $table->string('completion_note', 1000)->nullable();
                $table->boolean('deliverable_achieved')->nullable();
                $table->string('completion_evidence', 255)->nullable();
                $table->text('review_feedback')->nullable();
                $table->unsignedInteger('reviewed_by')->nullable();
                $table->dateTime('reviewed_at')->nullable();
                $table->unsignedInteger('version')->default(1);
                $table->unsignedInteger('created_by')->nullable();
                $table->timestamps();
                $table->softDeletes();
            });
        }

        if (! Schema::hasTable('project_milestones')) {
            Schema::create('project_milestones', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('project_id');
                $table->string('title', 200);
                $table->text('description')->nullable();
                $table->date('due_date');
                $table->string('status', 30)->default('planned');
                $table->dateTime('completed_at')->nullable();
                $table->unsignedInteger('created_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('project_timesheets')) {
            Schema::create('project_timesheets', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('user_id');
                $table->unsignedInteger('project_id');
                $table->unsignedInteger('task_id')->nullable();
                $table->date('work_date');
                $table->unsignedInteger('duration_minutes');
                $table->text('description');
                $table->string('status', 30)->default('submitted');
                $table->unsignedInteger('reviewed_by')->nullable();
                $table->dateTime('reviewed_at')->nullable();
                $table->text('review_note')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('project_progress_reports')) {
            Schema::create('project_progress_reports', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('project_id');
                $table->string('reporting_period', 30);
                $table->text('work_completed');
                $table->text('planned_work');
                $table->unsignedTinyInteger('progress_percent')->default(0);
                $table->text('blockers')->nullable();
                $table->text('next_steps')->nullable();
                $table->string('status', 30)->default('submitted');
                $table->unsignedInteger('submitted_by');
                $table->unsignedInteger('reviewed_by')->nullable();
                $table->dateTime('reviewed_at')->nullable();
                $table->text('review_notes')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('project_recognitions')) {
            Schema::create('project_recognitions', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('nominee_id');
                $table->unsignedInteger('nominator_id');
                $table->unsignedInteger('project_id')->nullable();
                $table->unsignedInteger('task_id')->nullable();
                $table->string('category', 100);
                $table->text('description');
                $table->text('supporting_evidence')->nullable();
                $table->string('status', 30)->default('nominated');
                $table->unsignedInteger('reviewed_by')->nullable();
                $table->dateTime('reviewed_at')->nullable();
                $table->text('review_note')->nullable();
                $table->date('award_date')->nullable();
                $table->text('certificate_note')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('project_decisions')) {
            Schema::create('project_decisions', function ($table) {
                $table->increments('id');
                $table->unsignedInteger('department_id');
                $table->unsignedInteger('project_id')->nullable();
                $table->string('title', 200);
                $table->text('description');
                $table->date('decision_date');
                $table->unsignedInteger('decision_maker_id');
                $table->text('meeting_minutes')->nullable();
                $table->longText('follow_up_actions')->nullable();
                $table->string('status', 30)->default('draft');
                $table->unsignedInteger('reviewed_by')->nullable();
                $table->dateTime('reviewed_at')->nullable();
                $table->unsignedInteger('created_by');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('settings')) {
            Schema::create('settings', function ($table) {
                $table->string('key')->primary();
                $table->text('value');
                $table->unsignedInteger('updated_by')->nullable();
                $table->timestamps();
            });
        }
    }

    private function makeAuth(int $userId, string $accountType = 'user', array $perms = []): AuthContext
    {
        $a = new AuthContext();
        $a->id = $userId;
        $a->fullName = 'Test User';
        $a->status = 'active';
        $a->accountType = $accountType;
        $a->tokenVersion = 1;
        $a->deviceId = null;
        $a->mustChangePassword = false;
        $a->isAdmin = $accountType === 'admin';
        $a->isSystem = false;
        $a->isMemberStaff = false;
        $a->role = ['id' => 1, 'slug' => $accountType === 'admin' ? 'high_admin' : 'member', 'name' => 'Role', 'level' => $accountType === 'admin' ? 100 : 10];
        $a->level = $accountType === 'admin' ? 100 : 10;
        $a->permissions = array_fill_keys($perms, true);
        return $a;
    }

    public function test_ethiopian_calendar_correctness(): void
    {
        // 1. Pagume has 6 days in a leap year (e.g. 2015 E.C. leap year -> 2015 % 4 == 3)
        $this->assertTrue(Ethiopian::isLeapYear(2015));
        $this->assertEquals(6, Ethiopian::daysInMonth(2015, 13));

        // 2016 E.C. is common year -> 5 days
        $this->assertFalse(Ethiopian::isLeapYear(2016));
        $this->assertEquals(5, Ethiopian::daysInMonth(2016, 13));

        // 2. Month boundaries: Month 1 (Meskerem 1) to Gregorian
        $greg = Ethiopian::fromEthiopian(2017, 1, 1);
        $this->assertEquals('2024-09-11', $greg);

        // Bijective round-trip
        $eth = Ethiopian::ethiopianOfDate('2024-09-11');
        $this->assertEquals(2017, $eth['year']);
        $this->assertEquals(1, $eth['month']);
        $this->assertEquals(1, $eth['day']);

        // Year boundary navigation: add 3 months from 2016-11 -> 2017-02
        $next = Ethiopian::addMonths('2016-11', 3);
        $this->assertEquals('2017-02', $next);
    }

    public function test_contribution_receipt_expected_amount_calculation(): void
    {
        // Insert test user and rates
        $userId = DB::table('users')->insertGetId([
            'full_name' => 'Kidanemariam Test',
            'member_type' => 'worker',
            'member_group' => 'youth_adult',
            'status' => 'active',
            'membership_status' => 'active',
        ]);

        DB::table('payment_rates')->insert([
            'member_type' => 'worker',
            'monthly_amount' => 150.00,
            'currency' => 'ETB',
            'effective_from' => '2020-01-01',
        ]);

        // Calculate for 3 months
        $calc = ContributionReceipts::calculateExpected($userId, '2017-01', 3);
        $this->assertEquals('2017-01', $calc['period']);
        $this->assertEquals(3, $calc['months']);
        $this->assertEquals('2017-03', $calc['coverage_end']);
        $this->assertEquals(450.00, $calc['expected_amount']);
        $this->assertCount(3, $calc['breakdown']);

        // Children must be exempt
        $childId = DB::table('users')->insertGetId([
            'full_name' => 'Child Test',
            'member_type' => 'student',
            'member_group' => 'children',
        ]);

        $this->expectException(\App\Mz\Support\ApiError::class);
        ContributionReceipts::calculateExpected($childId, '2017-01', 1);
    }

    public function test_contribution_receipt_review_and_approval_workflow(): void
    {
        $userId = DB::table('users')->insertGetId([
            'full_name' => 'Alemayehu Tester',
            'member_type' => 'worker',
            'member_group' => 'youth_adult',
            'status' => 'active',
            'membership_status' => 'active',
        ]);
        $reviewerId = DB::table('users')->insertGetId([
            'full_name' => 'Reviewer Finance',
            'account_type' => 'admin',
        ]);

        DB::table('payment_rates')->insert([
            'member_type' => 'worker',
            'monthly_amount' => 200.00,
            'currency' => 'ETB',
            'effective_from' => '2020-01-01',
        ]);

        $actx = [
            'auth' => $this->makeAuth($reviewerId, 'admin', ['payments.manage', 'contributions.review']),
            'source' => 'app',
            'ip' => '127.0.0.1',
            'userAgent' => 'PHPUnit',
        ];

        // Insert pending submission
        $subId = DB::table('contribution_receipts')->insertGetId([
            'user_id' => $userId,
            'period' => '2017-01',
            'months' => 2,
            'coverage_end' => '2017-02',
            'expected_amount' => 400.00,
            'submitted_amount' => 400.00,
            'currency' => 'ETB',
            'method' => 'telebirr',
            'reference' => 'TB-998811',
            'paid_on' => '2024-10-01',
            'receipt_path' => 'private/receipts/test.jpg',
            'status' => 'submitted',
        ]);

        // Prior to approval, months are NOT marked as paid in payments
        $this->assertEquals(0, DB::table('payments')->where('user_id', $userId)->count());

        // Reviewer approves the submission
        $reviewed = ContributionReceipts::review($actx, $subId, [
            'status' => 'approved',
            'review_note' => 'Payment verified on telebirr statement',
        ]);

        $this->assertEquals('approved', $reviewed['status']);
        $this->assertNotNull($reviewed['payment_id']);

        // Check that a verified payment record was created
        $payment = DB::table('payments')->where('id', $reviewed['payment_id'])->first();
        $this->assertNotNull($payment);
        $this->assertEquals($userId, $payment->user_id);
        $this->assertEquals('2017-01', $payment->period);
        $this->assertEquals('2017-02', $payment->coverage_end);
        $this->assertEquals(2, $payment->months);
        $this->assertEquals(400.00, (float) $payment->amount);
        $this->assertEquals('verified', $payment->status);
    }

    public function test_contribution_receipt_prevents_overlap(): void
    {
        $userId = DB::table('users')->insertGetId([
            'full_name' => 'Overlap Test User',
            'member_type' => 'worker',
            'member_group' => 'youth_adult',
            'status' => 'active',
            'membership_status' => 'active',
        ]);

        DB::table('payment_rates')->insert([
            'member_type' => 'worker',
            'monthly_amount' => 150.00,
            'currency' => 'ETB',
            'effective_from' => '2020-01-01',
        ]);

        // Recorded payment for 2017-01
        DB::table('payments')->insert([
            'user_id' => $userId,
            'period' => '2017-01',
            'months' => 1,
            'coverage_end' => '2017-01',
            'member_type' => 'worker',
            'monthly_rate' => 150.00,
            'amount' => 150.00,
            'paid_on' => '2024-10-01',
            'status' => 'verified',
        ]);

        $this->expectException(\App\Mz\Support\ApiError::class);
        $dummyFile = UploadedFile::fake()->create('receipt.jpg', 100);
        ContributionReceipts::submit([
            'auth' => $this->makeAuth($userId, 'user', []),
            'source' => 'app',
        ], [
            'period' => '2017-01',
            'months' => 1,
        ], $dummyFile);
    }

    public function test_project_milestones_and_timesheets(): void
    {
        $deptId = DB::table('departments')->insertGetId(['name' => 'ዝማሬ እና ኪነ-ጥበብ']);
        $userId = DB::table('users')->insertGetId([
            'full_name' => 'Choir Member',
            'account_type' => 'admin',
        ]);
        $projId = DB::table('projects')->insertGetId([
            'department_id' => $deptId,
            'title' => 'Meskel Festival Preparation',
            'leader_id' => $userId,
            'status' => 'in_progress',
        ]);

        $actx = [
            'auth' => $this->makeAuth($userId, 'admin', ['projects.manage', 'projects.view', 'projects.all_departments']),
            'source' => 'app',
        ];

        // 1. Milestone
        $m = MilestoneService::create($actx, $projId, [
            'title' => 'First Rehearsal',
            'due_date' => '2026-11-01',
            'status' => 'planned',
        ]);
        $this->assertEquals('First Rehearsal', $m['title']);
        $this->assertEquals('planned', $m['status']);

        // 2. Timesheet
        $ts = TimesheetService::record($actx, [
            'project_id' => $projId,
            'duration_minutes' => 120,
            'work_date' => '2026-10-22',
            'description' => '2 hours vocal harmony practice',
        ]);
        $this->assertEquals(120, $ts['duration_minutes']);
        $this->assertEquals(2.0, $ts['hours']);
        $this->assertEquals('submitted', $ts['status']);

        // Leader reviews timesheet
        $reviewed = TimesheetService::review($actx, $ts['id'], [
            'status' => 'approved',
            'review_note' => 'Confirmed rehearsal attendance',
        ]);
        $this->assertEquals('approved', $reviewed['status']);
    }

    public function test_project_recognitions_and_decisions(): void
    {
        $deptId = DB::table('departments')->insertGetId(['name' => 'ትምህርት እና ሥልጠና']);
        $leaderId = DB::table('users')->insertGetId(['full_name' => 'Leader Deacon', 'account_type' => 'admin']);
        $volunteerId = DB::table('users')->insertGetId(['full_name' => 'Dedicated Volunteer', 'account_type' => 'user']);

        $actx = [
            'auth' => $this->makeAuth($leaderId, 'admin', ['pm.recognitions.manage', 'pm.decisions.manage', 'projects.all_departments']),
            'source' => 'app',
        ];

        // 1. Nominate for recognition
        $nom = RecognitionService::nominate($actx, [
            'nominee_id' => $volunteerId,
            'category' => 'exceptional_service',
            'description' => 'Taught 40 Sunday school children faithfully every week',
        ]);
        $this->assertEquals('nominated', $nom['status']);

        // Review & award recognition
        $awarded = RecognitionService::review($actx, $nom['id'], [
            'status' => 'approved',
            'award_date' => '2026-10-22',
            'certificate_note' => 'Certificate of faithful Sunday school instruction',
        ]);
        $this->assertEquals('approved', $awarded['status']);
        $this->assertEquals('2026-10-22', $awarded['award_date']);

        // 2. Leadership Decision
        $dec = DecisionService::create($actx, [
            'department_id' => $deptId,
            'title' => 'Sunday School Curricula 2019 Approval',
            'description' => 'Unanimously approved textbooks for Grades 1-6',
            'decision_date' => '2026-10-22',
            'decision_maker_id' => $leaderId,
            'meeting_minutes' => 'Meeting opened with prayer. Discussed book revisions.',
            'follow_up_actions' => [
                ['action' => 'Print 200 copies', 'responsible_person_id' => $volunteerId, 'deadline' => '2026-11-15', 'status' => 'pending'],
            ],
            'status' => 'draft',
        ]);
        $this->assertEquals('draft', $dec['status']);
        $this->assertCount(1, $dec['follow_up_actions']);

        $published = DecisionService::publish($actx, $dec['id']);
        $this->assertEquals('published', $published['status']);
    }
}
