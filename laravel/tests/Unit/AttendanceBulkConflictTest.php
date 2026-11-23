<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Attendance;
use App\Mz\Services\AttendanceSessions;
use App\Mz\Services\Sync;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class AttendanceBulkConflictTest extends TestCase
{
    private AuthContext $takerAuth;
    private AuthContext $hrAuth;
    private array $takerActx;
    private array $hrActx;
    private string $testDate;
    private int $programId;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->testDate = Dates::toDateOnly(Dates::now());

        // Users: Taker (5), HR Resolver (2), Members (10, 11, 12)
        $this->takerAuth = $this->makeAuth(5, 'Taker Dawit', ['attendance.manage' => true]);
        $this->hrAuth = $this->makeAuth(2, 'HR Coordinator', ['attendance.override' => true, 'attendance.correction.approve' => true]);

        $this->takerActx = ['auth' => $this->takerAuth, 'ip' => '127.0.0.1', 'userAgent' => 'MH-TestClient'];
        $this->hrActx = ['auth' => $this->hrAuth, 'ip' => '127.0.0.1', 'userAgent' => 'MH-TestClient'];

        $this->seedTestData();
    }

    private function makeAuth(int $id, string $name, array $perms = []): AuthContext
    {
        $auth = new AuthContext();
        $auth->id = $id;
        $auth->fullName = $name;
        $auth->status = 'active';
        $auth->accountType = ! empty($perms) ? 'admin' : 'user';
        $auth->tokenVersion = 1;
        $auth->mustChangePassword = false;
        $auth->isAdmin = ! empty($perms);
        $auth->isSystem = false;
        $auth->isMemberStaff = false;
        $auth->level = ! empty($perms) ? 100 : 10;
        $auth->permissions = $perms;
        return $auth;
    }

    private function setUpSchema(): void
    {
        if (! Schema::hasTable('users')) {
            Schema::create('users', function ($table) {
                $table->id();
                $table->string('full_name');
                $table->string('phone')->nullable();
                $table->string('member_no')->nullable();
                $table->string('member_type')->nullable();
                $table->string('member_group')->nullable();
                $table->string('account_type')->default('user');
                $table->string('status')->default('active');
                $table->string('membership_status')->default('active');
                $table->string('profile_image')->nullable();
                $table->unsignedBigInteger('role_id')->nullable();
                $table->softDeletes();
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

        if (! Schema::hasTable('programs')) {
            Schema::create('programs', function ($table) {
                $table->id();
                $table->string('title');
                $table->string('type')->default('regular');
                $table->string('audience')->default('all');
                $table->string('recurrence')->default('once');
                $table->string('monthly_rule')->nullable();
                $table->date('recurrence_until')->nullable();
                $table->string('ethiopian_days')->nullable();
                $table->dateTime('starts_at');
                $table->dateTime('ends_at');
                $table->unsignedBigInteger('category_id')->nullable();
                $table->boolean('requires_attendance')->default(true);
                $table->string('member_groups')->nullable();
                $table->boolean('is_additional')->default(false);
                $table->boolean('counts_for_selection')->default(true);
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('program_occurrence_overrides')) {
            Schema::create('program_occurrence_overrides', function ($table) {
                $table->id();
                $table->unsignedBigInteger('program_id');
                $table->date('occurrence_date');
                $table->string('action');
                $table->dateTime('starts_at')->nullable();
                $table->dateTime('ends_at')->nullable();
                $table->string('reason')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('program_attendance_takers')) {
            Schema::create('program_attendance_takers', function ($table) {
                $table->id();
                $table->unsignedBigInteger('program_id');
                $table->unsignedBigInteger('user_id');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('attendance_sessions')) {
            Schema::create('attendance_sessions', function ($table) {
                $table->id();
                $table->unsignedBigInteger('program_id');
                $table->date('occurrence_date');
                $table->unsignedBigInteger('taker_id')->nullable();
                $table->unsignedBigInteger('assigned_by')->nullable();
                $table->dateTime('assigned_at')->nullable();
                $table->string('status')->default('scheduled');
                $table->dateTime('started_at')->nullable();
                $table->unsignedBigInteger('started_by')->nullable();
                $table->string('start_source')->nullable();
                $table->dateTime('client_started_at')->nullable();
                $table->char('client_uuid', 36)->nullable();
                $table->dateTime('ended_at')->nullable();
                $table->unsignedBigInteger('ended_by')->nullable();
                $table->string('end_reason')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('attendance')) {
            Schema::create('attendance', function ($table) {
                $table->id();
                $table->unsignedBigInteger('program_id');
                $table->date('occurrence_date');
                $table->unsignedBigInteger('session_id')->nullable();
                $table->unsignedBigInteger('user_id');
                $table->string('status');
                $table->dateTime('attended_at')->nullable();
                $table->dateTime('client_captured_at')->nullable();
                $table->dateTime('received_at')->nullable();
                $table->integer('elapsed_seconds')->nullable();
                $table->string('time_source')->nullable();
                $table->string('via')->default('manual');
                $table->unsignedBigInteger('signature_id')->nullable();
                $table->boolean('signature_exempt')->default(false);
                $table->string('source')->nullable();
                $table->char('client_event_id', 36)->nullable();
                $table->string('notes')->nullable();
                $table->unsignedBigInteger('recorded_by')->nullable();
                $table->unsignedBigInteger('updated_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('attendance_signatures')) {
            Schema::create('attendance_signatures', function ($table) {
                $table->id();
                $table->unsignedBigInteger('attendance_id')->nullable();
                $table->unsignedBigInteger('user_id');
                $table->string('path');
                $table->char('sha256', 64);
                $table->dateTime('signed_at');
                $table->unsignedBigInteger('captured_by')->nullable();
                $table->char('client_event_id', 36)->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('attendance_closures')) {
            Schema::create('attendance_closures', function ($table) {
                $table->id();
                $table->unsignedBigInteger('program_id');
                $table->date('occurrence_date');
                $table->dateTime('closed_at');
                $table->unsignedBigInteger('closed_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('attendance_sync_conflicts')) {
            Schema::create('attendance_sync_conflicts', function ($table) {
                $table->id();
                $table->string('kind');
                $table->string('code', 60);
                $table->unsignedBigInteger('program_id')->nullable();
                $table->unsignedBigInteger('class_id')->nullable();
                $table->date('occurrence_date');
                $table->unsignedBigInteger('user_id')->nullable();
                $table->unsignedBigInteger('submitted_by');
                $table->char('client_event_id', 36)->nullable();
                $table->char('batch_id', 36)->nullable()->index('attendance_sync_conflicts_batch');
                $table->dateTime('client_captured_at')->nullable();
                $table->dateTime('captured_at')->nullable();
                $table->text('payload')->nullable();
                $table->string('signature_path')->nullable();
                $table->char('signature_sha256', 64)->nullable();
                $table->string('status')->default('open');
                $table->unsignedBigInteger('resolved_by')->nullable();
                $table->dateTime('resolved_at')->nullable();
                $table->string('resolution_note', 1000)->nullable();
                $table->unsignedBigInteger('attendance_id')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('sync_receipts')) {
            Schema::create('sync_receipts', function ($table) {
                $table->unsignedBigInteger('user_id');
                $table->char('op_id', 36);
                $table->string('status');
                $table->text('result')->nullable();
                $table->primary(['user_id', 'op_id']);
            });
        }

        if (! Schema::hasTable('audit_logs')) {
            Schema::create('audit_logs', function ($table) {
                $table->id();
                $table->unsignedBigInteger('actor_id')->nullable();
                $table->boolean('is_hidden')->default(false);
                $table->string('action');
                $table->string('entity_type')->nullable();
                $table->string('entity_id')->nullable();
                $table->text('metadata')->nullable();
                $table->string('ip')->nullable();
                $table->string('user_agent')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_classes')) {
            Schema::create('edu_classes', function ($table) {
                $table->id();
                $table->string('name');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('activity_logs')) {
            Schema::create('activity_logs', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id')->nullable();
                $table->string('action');
                $table->string('entity_type')->nullable();
                $table->unsignedBigInteger('entity_id')->nullable();
                $table->text('metadata')->nullable();
                $table->char('client_event_id', 36)->nullable();
                $table->dateTime('occurred_at')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('settings')) {
            Schema::create('settings', function ($table) {
                $table->string('key')->primary();
                $table->text('value')->nullable();
                $table->timestamps();
            });
        }
    }

    private function seedTestData(): void
    {
        DB::table('users')->truncate();
        DB::table('users')->insert([
            ['id' => 2, 'full_name' => 'HR Coordinator', 'account_type' => 'admin', 'status' => 'active', 'membership_status' => 'active', 'member_group' => 'choir', 'created_at' => now()->subDays(10), 'updated_at' => now()],
            ['id' => 5, 'full_name' => 'Taker Dawit', 'account_type' => 'admin', 'status' => 'active', 'membership_status' => 'active', 'member_group' => 'choir', 'created_at' => now()->subDays(10), 'updated_at' => now()],
            ['id' => 10, 'full_name' => 'Member Abebe', 'account_type' => 'user', 'status' => 'active', 'membership_status' => 'active', 'member_group' => 'choir', 'created_at' => now()->subDays(10), 'updated_at' => now()],
            ['id' => 11, 'full_name' => 'Member Kebede', 'account_type' => 'user', 'status' => 'active', 'membership_status' => 'active', 'member_group' => 'choir', 'created_at' => now()->subDays(10), 'updated_at' => now()],
            ['id' => 12, 'full_name' => 'Member Chala', 'account_type' => 'user', 'status' => 'active', 'membership_status' => 'active', 'member_group' => 'choir', 'created_at' => now()->subDays(10), 'updated_at' => now()],
        ]);

        DB::table('programs')->truncate();
        $this->programId = DB::table('programs')->insertGetId([
            'title' => 'Sunday Weekly Rehearsal',
            'type' => 'regular',
            'audience' => 'all',
            'recurrence' => 'once',
            'starts_at' => $this->testDate . ' 00:00:00',
            'ends_at' => $this->testDate . ' 23:59:59',
            'requires_attendance' => true,
            'member_groups' => 'choir',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Assign Taker Dawit (5) as default taker
        DB::table('program_attendance_takers')->truncate();
        DB::table('program_attendance_takers')->insert([
            'program_id' => $this->programId,
            'user_id' => 5,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Create and start session covering the day
        DB::table('attendance_sessions')->truncate();
        DB::table('attendance_sessions')->insert([
            'program_id' => $this->programId,
            'occurrence_date' => $this->testDate,
            'taker_id' => 5,
            'status' => 'active',
            'started_at' => $this->testDate . ' 00:01:00',
            'started_by' => 5,
            'start_source' => 'server',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('attendance')->truncate();
        DB::table('attendance_sync_conflicts')->truncate();
        DB::table('sync_receipts')->truncate();
        DB::table('audit_logs')->truncate();
    }

    /**
     * Test 1: Legacy offline bulk-present operation decomposes into individual operations,
     * preserves original batch_id on each conflict row, and quarantines unsigned marks.
     */
    public function test_legacy_bulk_present_decomposes_with_batch_id_and_records_conflicts(): void
    {
        $batchOpId = '11111111-2222-4333-8444-555555555555';
        $operations = [
            [
                'op_id' => $batchOpId,
                'type' => 'attendance.bulk',
                'payload' => [
                    'program_id' => $this->programId,
                    'user_ids' => [10, 11, 12],
                    'status' => 'present',
                    'date' => $this->testDate,
                ],
                'captured_at' => $this->testDate . 'T08:30:00Z',
            ],
        ];

        // Apply offline queue from Taker
        $result = Sync::apply($this->takerAuth, $operations, $this->takerActx);

        $this->assertArrayHasKey('results', $result);
        $opResult = $result['results'][0];
        $this->assertEquals('applied', $opResult['status']);
        $this->assertEquals(3, $opResult['server']['sent_to_hr']);
        $this->assertEquals($batchOpId, $opResult['server']['batch_id']);

        // Check conflicts in database
        $conflicts = DB::table('attendance_sync_conflicts')->orderBy('user_id')->get();
        $this->assertCount(3, $conflicts);

        foreach ($conflicts as $c) {
            $this->assertEquals('record', $c->kind);
            $this->assertEquals('SIGNATURE_REQUIRED', $c->code);
            $this->assertEquals($batchOpId, $c->batch_id);
            $this->assertEquals(5, $c->submitted_by);
            $this->assertEquals('open', $c->status);

            $payload = json_decode((string) $c->payload, true);
            $this->assertEquals($batchOpId, $payload['batch_id']);
            $this->assertEquals('attendance.bulk', $payload['batch_type']);
            $this->assertEquals(3, $payload['batch_total']);
        }

        // Verify NO attendance was written directly (unsigned attendance must NOT be silently written)
        $this->assertEquals(0, DB::table('attendance')->count());
    }

    /**
     * Test 2: Idempotency on retry — re-submitting the same batch operation produces no duplicate rows.
     */
    public function test_idempotent_retry_avoids_duplicate_conflicts(): void
    {
        $batchOpId = '22222222-3333-4444-8555-666666666666';
        $operations = [
            [
                'op_id' => $batchOpId,
                'type' => 'attendance.bulk',
                'payload' => [
                    'program_id' => $this->programId,
                    'user_ids' => [10, 11],
                    'status' => 'present',
                    'date' => $this->testDate,
                ],
                'captured_at' => $this->testDate . 'T08:30:00Z',
            ],
        ];

        // First submission
        Sync::apply($this->takerAuth, $operations, $this->takerActx);
        $this->assertEquals(2, DB::table('attendance_sync_conflicts')->count());

        // Clear sync_receipts to simulate client resending queue
        DB::table('sync_receipts')->truncate();

        // Retry same operations
        Sync::apply($this->takerAuth, $operations, $this->takerActx);
        $this->assertEquals(2, DB::table('attendance_sync_conflicts')->count(), 'Duplicate conflicts should not be created on retry');
    }

    /**
     * Test 3: Conflict batches grouping query (AttendanceSessions::conflictBatches).
     */
    public function test_conflict_batches_query_returns_aggregates(): void
    {
        $batchOpId = '33333333-4444-4555-8666-777777777777';
        $operations = [
            [
                'op_id' => $batchOpId,
                'type' => 'attendance.bulk',
                'payload' => [
                    'program_id' => $this->programId,
                    'user_ids' => [10, 11, 12],
                    'status' => 'present',
                    'date' => $this->testDate,
                ],
                'captured_at' => $this->testDate . 'T08:30:00Z',
            ],
        ];
        Sync::apply($this->takerAuth, $operations, $this->takerActx);

        $batches = AttendanceSessions::conflictBatches(['status' => 'open'], Page::params());

        $this->assertCount(1, $batches['items']);
        $b = $batches['items'][0];
        $this->assertEquals($batchOpId, $b->batch_id);
        $this->assertEquals('Sunday Weekly Rehearsal', $b->program_title);
        $this->assertEquals('Taker Dawit', $b->submitted_by_name);
        $this->assertEquals(3, $b->total_conflicts);
        $this->assertEquals(3, $b->open_count);
        $this->assertEquals(0, $b->accepted_count);
        $this->assertEquals(0, $b->rejected_count);
        $this->assertEquals('open', $b->status);
        $this->assertEquals('SIGNATURE_REQUIRED', $b->primary_code);

        // Filter individual conflicts by batch_id
        $items = AttendanceSessions::conflicts(['batch_id' => $batchOpId], Page::params());
        $this->assertCount(3, $items['items']);
        $this->assertEquals($batchOpId, $items['items'][0]->batch_id);
    }

    /**
     * Test 4: Self-approval prohibition — submitter cannot resolve own batch conflicts.
     */
    public function test_submitter_cannot_bulk_resolve_own_batch(): void
    {
        $batchOpId = '44444444-5555-4666-8777-888888888888';
        $operations = [
            [
                'op_id' => $batchOpId,
                'type' => 'attendance.bulk',
                'payload' => [
                    'program_id' => $this->programId,
                    'user_ids' => [10, 11],
                    'status' => 'present',
                    'date' => $this->testDate,
                ],
                'captured_at' => $this->testDate . 'T08:30:00Z',
            ],
        ];
        Sync::apply($this->takerAuth, $operations, $this->takerActx);

        // Submitter (Taker Dawit, user 5) attempts to bulk resolve their own batch
        $this->expectException(ApiError::class);
        try {
            AttendanceSessions::bulkResolveConflicts($this->takerActx, [
                'batch_id' => $batchOpId,
                'decision' => 'accept',
                'note' => 'I verified these members were present',
            ]);
        } catch (ApiError $e) {
            $this->assertEquals('SELF_APPROVAL_FORBIDDEN', $e->errorCode);
            $this->assertEquals(403, $e->status);
            throw $e;
        }

        // Ensure status remained open
        $openCount = DB::table('attendance_sync_conflicts')->where('batch_id', $batchOpId)->where('status', 'open')->count();
        $this->assertEquals(2, $openCount);
    }

    /**
     * Test 5: Safe Bulk Resolution by HR (decision = 'accept').
     * Applying accepted conflicts writes valid attendance records, updates status, and audits.
     */
    public function test_hr_can_bulk_accept_conflicts_and_write_attendance(): void
    {
        $batchOpId = '55555555-6666-4777-8888-999999999999';
        $operations = [
            [
                'op_id' => $batchOpId,
                'type' => 'attendance.bulk',
                'payload' => [
                    'program_id' => $this->programId,
                    'user_ids' => [10, 11, 12],
                    'status' => 'present',
                    'date' => $this->testDate,
                ],
                'captured_at' => $this->testDate . 'T08:30:00Z',
            ],
        ];
        Sync::apply($this->takerAuth, $operations, $this->takerActx);

        // HR Coordinator (user 2) resolves the batch
        $res = AttendanceSessions::bulkResolveConflicts($this->hrActx, [
            'batch_id' => $batchOpId,
            'decision' => 'accept',
            'note' => 'Verified on paper roster by HR',
        ]);

        $this->assertTrue($res['success']);
        $this->assertEquals('accept', $res['decision']);
        $this->assertEquals(3, $res['total']);
        $this->assertEquals(3, $res['resolved']);
        $this->assertEquals(3, $res['accepted']);
        $this->assertEquals(0, $res['rejected']);
        $this->assertEquals(0, $res['skipped']);

        // Check conflicts status
        $conflicts = DB::table('attendance_sync_conflicts')->where('batch_id', $batchOpId)->get();
        foreach ($conflicts as $c) {
            $this->assertEquals('accepted', $c->status);
            $this->assertEquals(2, $c->resolved_by);
            $this->assertEquals('Verified on paper roster by HR', $c->resolution_note);
            $this->assertNotNull($c->attendance_id);
        }

        // Check attendance records created
        $records = DB::table('attendance')->where('program_id', $this->programId)->where('occurrence_date', $this->testDate)->get();
        $this->assertCount(3, $records);
        foreach ($records as $r) {
            $this->assertEquals('present', $r->status);
            $this->assertEquals(5, $r->recorded_by); // Taker who submitted
            $this->assertEquals('offline', $r->source);
        }

        // Check audit log
        $batchAudit = DB::table('audit_logs')->where('action', 'attendance.conflict_bulk_resolve')->first();
        $this->assertNotNull($batchAudit);
        $details = json_decode((string) $batchAudit->metadata, true);
        $this->assertEquals($batchOpId, $details['batch_id']);
        $this->assertEquals('accept', $details['decision']);
        $this->assertEquals(3, $details['resolved_count']);
    }

    /**
     * Test 6: Safe Bulk Resolution by HR (decision = 'reject').
     */
    public function test_hr_can_bulk_reject_conflicts_without_writing_attendance(): void
    {
        $batchOpId = '66666666-7777-4888-8999-000000000000';
        $operations = [
            [
                'op_id' => $batchOpId,
                'type' => 'attendance.bulk',
                'payload' => [
                    'program_id' => $this->programId,
                    'user_ids' => [10, 11],
                    'status' => 'present',
                    'date' => $this->testDate,
                ],
                'captured_at' => $this->testDate . 'T08:30:00Z',
            ],
        ];
        Sync::apply($this->takerAuth, $operations, $this->takerActx);

        $res = AttendanceSessions::bulkResolveConflicts($this->hrActx, [
            'batch_id' => $batchOpId,
            'decision' => 'reject',
            'note' => 'Unconfirmed marks rejected',
        ]);

        $this->assertTrue($res['success']);
        $this->assertEquals('reject', $res['decision']);
        $this->assertEquals(2, $res['resolved']);
        $this->assertEquals(2, $res['rejected']);
        $this->assertEquals(0, $res['accepted']);

        // Check no attendance created
        $this->assertEquals(0, DB::table('attendance')->count());

        // Check conflicts status
        $conflicts = DB::table('attendance_sync_conflicts')->where('batch_id', $batchOpId)->get();
        foreach ($conflicts as $c) {
            $this->assertEquals('rejected', $c->status);
            $this->assertEquals(2, $c->resolved_by);
            $this->assertNull($c->attendance_id);
        }
    }

    /**
     * Test 7: Resolving already-decided conflicts skips them safely.
     */
    public function test_bulk_resolve_skips_already_decided_conflicts(): void
    {
        $batchOpId = '77777777-8888-4999-8000-111111111111';
        $operations = [
            [
                'op_id' => $batchOpId,
                'type' => 'attendance.bulk',
                'payload' => [
                    'program_id' => $this->programId,
                    'user_ids' => [10],
                    'status' => 'present',
                    'date' => $this->testDate,
                ],
                'captured_at' => $this->testDate . 'T08:30:00Z',
            ],
        ];
        Sync::apply($this->takerAuth, $operations, $this->takerActx);

        // First resolution
        AttendanceSessions::bulkResolveConflicts($this->hrActx, [
            'batch_id' => $batchOpId,
            'decision' => 'accept',
            'note' => 'First review',
        ]);

        // Second resolution on same batch
        $res = AttendanceSessions::bulkResolveConflicts($this->hrActx, [
            'batch_id' => $batchOpId,
            'decision' => 'reject',
            'note' => 'Second attempt',
        ]);

        $this->assertEquals(0, $res['resolved']);
        $this->assertEquals(1, $res['skipped']);
    }

    /**
     * Test 8: Critical security gate — an unsigned record that originally failed with
     * SIGNATURE_REQUIRED is NOT represented as digitally signed or cryptographically verified after HR accepts it.
     */
    public function test_security_gate_unsigned_records_have_no_digital_signature_after_hr_accept(): void
    {
        $batchOpId = '88888888-9999-4000-8111-222222222222';
        $operations = [
            [
                'op_id' => $batchOpId,
                'type' => 'attendance.bulk',
                'payload' => [
                    'program_id' => $this->programId,
                    'user_ids' => [10],
                    'status' => 'present',
                    'date' => $this->testDate,
                ],
                'captured_at' => $this->testDate . 'T08:30:00Z',
            ],
        ];
        Sync::apply($this->takerAuth, $operations, $this->takerActx);

        // HR accepts the unsigned conflict
        AttendanceSessions::bulkResolveConflicts($this->hrActx, [
            'batch_id' => $batchOpId,
            'decision' => 'accept',
            'note' => 'HR verified attendance by paper roster',
        ]);

        $att = DB::table('attendance')->where(['program_id' => $this->programId, 'occurrence_date' => $this->testDate, 'user_id' => 10])->first();
        $this->assertNotNull($att);
        $this->assertEquals('present', $att->status);

        // Security assertion: signature_id is NULL and signature_exempt is 0
        $this->assertNull($att->signature_id, 'Unsigned attendance must NOT have a signature_id attached');
        $this->assertEquals(0, $att->signature_exempt, 'Unsigned attendance must NOT be flagged as signature_exempt');

        // Security assertion: Calling signatureFile on this attendance throws SIGNATURE_NOT_FOUND
        $this->expectException(ApiError::class);
        try {
            Attendance::signatureFile($att->id);
        } catch (ApiError $e) {
            $this->assertEquals('SIGNATURE_NOT_FOUND', $e->errorCode);
            throw $e;
        }
    }

    /**
     * Test 9: Unauthorized roles cannot view or resolve conflicts without attendance.override.
     */
    public function test_unauthorized_user_cannot_bulk_resolve_or_resolve_conflicts(): void
    {
        $unauthorizedAuth = $this->makeAuth(99, 'Unauthorized User', []);
        $unauthorizedActx = ['auth' => $unauthorizedAuth, 'ip' => '127.0.0.1', 'userAgent' => 'MH-TestClient'];

        $this->expectException(ApiError::class);
        try {
            AttendanceSessions::bulkResolveConflicts($unauthorizedActx, [
                'batch_id' => 'any-batch',
                'decision' => 'accept',
                'note' => 'Attempting unauthorized resolve',
            ]);
        } catch (ApiError $e) {
            $this->assertEquals('FORBIDDEN', $e->errorCode);
            $this->assertEquals(403, $e->status);
            throw $e;
        }
    }

    /**
     * Test 10: Mixed valid (open) and already-resolved conflict IDs produce accurate, auditable outcomes.
     */
    public function test_mixed_conflict_ids_resolves_open_and_skips_decided(): void
    {
        $batchOpId = '99999999-0000-4111-8222-333333333333';
        $operations = [
            [
                'op_id' => $batchOpId,
                'type' => 'attendance.bulk',
                'payload' => [
                    'program_id' => $this->programId,
                    'user_ids' => [10, 11, 12],
                    'status' => 'present',
                    'date' => $this->testDate,
                ],
                'captured_at' => $this->testDate . 'T08:30:00Z',
            ],
        ];
        Sync::apply($this->takerAuth, $operations, $this->takerActx);

        $conflicts = DB::table('attendance_sync_conflicts')->where('batch_id', $batchOpId)->orderBy('id')->get();
        $this->assertCount(3, $conflicts);

        // Pre-resolve conflict 1
        AttendanceSessions::resolveConflict($this->hrActx, (int) $conflicts[0]->id, 'reject', 'Individual rejection');

        // Now bulk-resolve with all 3 IDs
        $res = AttendanceSessions::bulkResolveConflicts($this->hrActx, [
            'conflict_ids' => [(int) $conflicts[0]->id, (int) $conflicts[1]->id, (int) $conflicts[2]->id],
            'decision' => 'accept',
            'note' => 'Accept remaining open items',
        ]);

        $this->assertEquals(3, $res['total']);
        $this->assertEquals(2, $res['resolved']);
        $this->assertEquals(2, $res['accepted']);
        $this->assertEquals(1, $res['skipped']);
        $this->assertEquals([(int) $conflicts[1]->id, (int) $conflicts[2]->id], $res['resolved_ids']);
        $this->assertEquals([(int) $conflicts[0]->id], $res['skipped_ids']);

        // Check conflict 1 remained rejected with original note
        $c0 = DB::table('attendance_sync_conflicts')->where('id', $conflicts[0]->id)->first();
        $this->assertEquals('rejected', $c0->status);
        $this->assertEquals('Individual rejection', $c0->resolution_note);
    }

    /**
     * Test 11: Transaction rollback on failure ensures no partial state or orphan records remain.
     */
    public function test_atomic_rollback_on_self_approval_preserves_conflict_states(): void
    {
        $batchOpId = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
        $operations = [
            [
                'op_id' => $batchOpId,
                'type' => 'attendance.bulk',
                'payload' => [
                    'program_id' => $this->programId,
                    'user_ids' => [10, 11],
                    'status' => 'present',
                    'date' => $this->testDate,
                ],
                'captured_at' => $this->testDate . 'T08:30:00Z',
            ],
        ];
        Sync::apply($this->takerAuth, $operations, $this->takerActx);

        try {
            AttendanceSessions::bulkResolveConflicts($this->takerActx, [
                'batch_id' => $batchOpId,
                'decision' => 'accept',
                'note' => 'Self approval attempt',
            ]);
        } catch (ApiError) {
            // expected
        }

        // Both conflicts must still be open
        $openCount = DB::table('attendance_sync_conflicts')->where('batch_id', $batchOpId)->where('status', 'open')->count();
        $this->assertEquals(2, $openCount);
        $this->assertEquals(0, DB::table('attendance')->count());
    }

    /**
     * Test 12: The current mobile client's existing "excused" bulk-attendance workflow still works.
     */
    public function test_existing_excused_bulk_attendance_workflow_preserved(): void
    {
        $batchOpId = 'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff';
        $operations = [
            [
                'op_id' => $batchOpId,
                'type' => 'attendance.bulk',
                'payload' => [
                    'program_id' => $this->programId,
                    'user_ids' => [10, 11],
                    'status' => 'excused',
                    'date' => $this->testDate,
                    'notes' => 'Choir rehearsal leave granted',
                ],
                'captured_at' => $this->testDate . 'T08:30:00Z',
            ],
        ];

        $res = Sync::apply($this->takerAuth, $operations, $this->takerActx);

        $this->assertEquals('applied', $res['results'][0]['status']);
        $this->assertEquals(0, DB::table('attendance_sync_conflicts')->where('program_id', $this->programId)->count());

        $excused = DB::table('attendance')->where(['program_id' => $this->programId, 'status' => 'excused'])->count();
        $this->assertEquals(2, $excused);
    }

    /**
     * Test 13: Migration and rollback safety on attendance_sync_conflicts table.
     */
    public function test_batch_id_migration_and_rollback_safety(): void
    {
        $migration = require base_path('database/migrations/2026_10_30_000002_attendance_sync_conflicts_batch_id.php');

        // Test down() removes column safely
        $migration->down();
        $this->assertFalse(Schema::hasColumn('attendance_sync_conflicts', 'batch_id'));

        // Insert conflict with batch_id in payload
        $id = DB::table('attendance_sync_conflicts')->insertGetId([
            'kind' => 'record',
            'code' => 'SIGNATURE_REQUIRED',
            'program_id' => $this->programId,
            'occurrence_date' => $this->testDate,
            'submitted_by' => 5,
            'payload' => json_encode(['batch_id' => 'test-backfill-uuid', 'status' => 'present']),
            'status' => 'open',
        ]);

        // Test up() adds column and backfills payload batch_id
        $migration->up();
        $this->assertTrue(Schema::hasColumn('attendance_sync_conflicts', 'batch_id'));

        $row = DB::table('attendance_sync_conflicts')->where('id', $id)->first();
        $this->assertEquals('test-backfill-uuid', $row->batch_id);
    }

    /**
     * Test 14: Concurrent or subsequent resolution attempts cannot produce duplicate or contradictory decisions.
     */
    public function test_concurrent_or_contradictory_resolution_attempts_prevent_duplicate_decisions(): void
    {
        $batchOpId = 'cccccccc-dddd-4eee-8fff-000000000000';
        $operations = [
            [
                'op_id' => $batchOpId,
                'type' => 'attendance.bulk',
                'payload' => [
                    'program_id' => $this->programId,
                    'user_ids' => [10, 11],
                    'status' => 'present',
                    'date' => $this->testDate,
                ],
                'captured_at' => $this->testDate . 'T08:30:00Z',
            ],
        ];
        Sync::apply($this->takerAuth, $operations, $this->takerActx);

        // First HR resolution: Accept
        $res1 = AttendanceSessions::bulkResolveConflicts($this->hrActx, [
            'batch_id' => $batchOpId,
            'decision' => 'accept',
            'note' => 'First acceptance',
        ]);
        $this->assertEquals(2, $res1['resolved']);
        $this->assertEquals(2, $res1['accepted']);

        // Second concurrent/racing resolution: Reject attempt
        $res2 = AttendanceSessions::bulkResolveConflicts($this->hrActx, [
            'batch_id' => $batchOpId,
            'decision' => 'reject',
            'note' => 'Contradictory rejection racing call',
        ]);
        $this->assertEquals(0, $res2['resolved']);
        $this->assertEquals(2, $res2['skipped']);

        // Verify status remained accepted, never contradicted or overwritten
        $conflicts = DB::table('attendance_sync_conflicts')->where('batch_id', $batchOpId)->get();
        foreach ($conflicts as $c) {
            $this->assertEquals('accepted', $c->status);
            $this->assertEquals('First acceptance', $c->resolution_note);
        }
        $this->assertEquals(2, DB::table('attendance')->where('program_id', $this->programId)->count());
    }

    /**
     * Test 15: Signed individual attendance workflow is fully preserved without generating conflicts.
     */
    public function test_signed_individual_attendance_records_successfully(): void
    {
        $pngBase64 = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
        $opId = 'dddddddd-eeee-4fff-8000-111111111111';

        $operations = [
            [
                'op_id' => $opId,
                'type' => 'attendance.record',
                'payload' => [
                    'program_id' => $this->programId,
                    'user_id' => 10,
                    'status' => 'present',
                    'date' => $this->testDate,
                    'signature' => $pngBase64,
                    'via' => 'manual',
                    'captured_offline' => true,
                ],
                'captured_at' => $this->testDate . 'T09:00:00Z',
            ],
        ];

        $res = Sync::apply($this->takerAuth, $operations, $this->takerActx);

        $this->assertEquals('applied', $res['results'][0]['status']);
        $this->assertFalse($res['results'][0]['conflict'] ?? false);

        // Zero conflicts created
        $this->assertEquals(0, DB::table('attendance_sync_conflicts')->where('client_event_id', $opId)->count());

        // Attendance written with valid signature
        $att = DB::table('attendance')->where(['program_id' => $this->programId, 'occurrence_date' => $this->testDate, 'user_id' => 10])->first();
        $this->assertNotNull($att);
        $this->assertEquals('present', $att->status);
        $this->assertNotNull($att->signature_id);

        $sig = DB::table('attendance_signatures')->where('id', $att->signature_id)->first();
        $this->assertNotNull($sig);
        $this->assertEquals(10, $sig->user_id);
        $this->assertEquals(5, $sig->captured_by);
    }
}


