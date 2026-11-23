<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * 1. Adds explicit `grade` column to `edu_subjects` (with composite index for fast grade-curriculum lookups).
     * 2. Adds composite indexes on `edu_classes` (academic_year_id, level_id) and `edu_courses` (class_id, subject_id).
     * 3. Populates `grade` on all existing curriculum subjects based on their code prefix (G01–G12) or sort_order.
     * 4. Idempotently maps existing class courses to authoritative curriculum subjects, preserving historical records.
     */
    public function up(): void
    {
        // 1. edu_subjects: explicit grade column & index
        if (Schema::hasTable('edu_subjects')) {
            if (! Schema::hasColumn('edu_subjects', 'grade')) {
                Schema::table('edu_subjects', function (Blueprint $table) {
                    $table->unsignedTinyInteger('grade')->nullable()->after('category_id');
                    $table->index(['grade', 'status', 'sort_order'], 'edu_subjects_grade_idx');
                });
            }

            // Populate grade for existing subjects from code (e.g. G07-S01 -> 7) or sort_order
            $subjects = DB::table('edu_subjects')->get();
            foreach ($subjects as $s) {
                $g = null;
                if (! empty($s->code) && preg_match('/^G(\d{1,2})-/i', $s->code, $m)) {
                    $g = (int) $m[1];
                } elseif (! empty($s->code) && preg_match('/^G(\d{1,2})$/i', $s->code, $m)) {
                    $g = (int) $m[1];
                } elseif (isset($s->sort_order) && (int) $s->sort_order >= 1 && (int) $s->sort_order <= 12) {
                    $g = (int) $s->sort_order;
                }

                if ($g !== null && empty($s->grade)) {
                    DB::table('edu_subjects')->where('id', $s->id)->update(['grade' => $g]);
                }
            }
        }

        // 2. edu_classes: index on academic_year_id and level_id
        if (Schema::hasTable('edu_classes')) {
            try {
                Schema::table('edu_classes', function (Blueprint $table) {
                    $table->index(['academic_year_id', 'level_id'], 'edu_classes_year_level_idx');
                });
            } catch (\Throwable $e) {
                // Index may already exist
            }

            // Ensure Level 7 is set for Class 1 ("7ኛ") if null
            DB::table('edu_classes')
                ->whereNull('level_id')
                ->where(function ($q) {
                    $q->where('name', 'like', '%7ኛ%')
                      ->orWhere('name', 'like', '%7%')
                      ->orWhere('name_en', 'like', '%Grade 7%');
                })
                ->update(['level_id' => 7]);
        }

        // 3. edu_courses: index on class_id and subject_id
        if (Schema::hasTable('edu_courses')) {
            try {
                Schema::table('edu_courses', function (Blueprint $table) {
                    $table->index(['class_id', 'subject_id'], 'edu_courses_class_subject_idx');
                });
            } catch (\Throwable $e) {
                // Index may already exist
            }
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasTable('edu_subjects') && Schema::hasColumn('edu_subjects', 'grade')) {
            try {
                Schema::table('edu_subjects', function (Blueprint $table) {
                    $table->dropIndex('edu_subjects_grade_idx');
                    $table->dropColumn('grade');
                });
            } catch (\Throwable $e) {}
        }

        if (Schema::hasTable('edu_classes')) {
            try {
                Schema::table('edu_classes', function (Blueprint $table) {
                    $table->dropIndex('edu_classes_year_level_idx');
                });
            } catch (\Throwable $e) {}
        }

        if (Schema::hasTable('edu_courses')) {
            try {
                Schema::table('edu_courses', function (Blueprint $table) {
                    $table->dropIndex('edu_courses_class_subject_idx');
                });
            } catch (\Throwable $e) {}
        }
    }
};

