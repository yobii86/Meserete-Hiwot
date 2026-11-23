<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Add batch_id to attendance_sync_conflicts to group legacy bulk-present
     * operations and other batch offline sync entries for HR review (F-04).
     */
    public function up(): void
    {
        if (Schema::hasTable('attendance_sync_conflicts') && ! Schema::hasColumn('attendance_sync_conflicts', 'batch_id')) {
            Schema::table('attendance_sync_conflicts', function (Blueprint $table) {
                $table->char('batch_id', 36)->nullable()->after('client_event_id')->index('attendance_sync_conflicts_batch');
            });

            // Backfill existing records if any have batch_id stored in json payload
            try {
                $conflicts = DB::table('attendance_sync_conflicts')
                    ->whereNull('batch_id')
                    ->whereNotNull('payload')
                    ->get(['id', 'payload']);

                foreach ($conflicts as $row) {
                    $data = json_decode((string) $row->payload, true);
                    if (! empty($data['batch_id']) && is_string($data['batch_id'])) {
                        DB::table('attendance_sync_conflicts')
                            ->where('id', $row->id)
                            ->update(['batch_id' => substr($data['batch_id'], 0, 36)]);
                    }
                }
            } catch (\Throwable) {
                // Ignore backfill errors on partial or mock databases
            }
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('attendance_sync_conflicts') && Schema::hasColumn('attendance_sync_conflicts', 'batch_id')) {
            Schema::table('attendance_sync_conflicts', function (Blueprint $table) {
                $table->dropIndex('attendance_sync_conflicts_batch');
                $table->dropColumn('batch_id');
            });
        }
    }
};
