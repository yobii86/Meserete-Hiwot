<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('programs')) {
            Schema::table('programs', function (Blueprint $table) {
                if (! Schema::hasColumn('programs', 'ordinal_weeks')) {
                    $table->string('ordinal_weeks', 60)->nullable()->after('monthly_rule');
                }
                if (! Schema::hasColumn('programs', 'recurring_weekdays')) {
                    $table->string('recurring_weekdays', 60)->nullable()->after('ordinal_weeks');
                }
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('programs')) {
            Schema::table('programs', function (Blueprint $table) {
                if (Schema::hasColumn('programs', 'recurring_weekdays')) {
                    $table->dropColumn('recurring_weekdays');
                }
                if (Schema::hasColumn('programs', 'ordinal_weeks')) {
                    $table->dropColumn('ordinal_weeks');
                }
            });
        }
    }
};

