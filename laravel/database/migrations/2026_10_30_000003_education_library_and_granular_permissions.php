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
     * 1. Add category_type ('physical','digital','both'), description, and is_active to library_categories.
     * 2. Ensure detailed book metadata fields exist on items (subtitle, publisher, publication_year, language).
     * 3. Seed granular education permissions and assign to edu_admin role.
     */
    public function up(): void
    {
        // 1. library_categories enhancements
        if (Schema::hasTable('library_categories')) {
            Schema::table('library_categories', function (Blueprint $table) {
                if (! Schema::hasColumn('library_categories', 'category_type')) {
                    $table->string('category_type', 32)->default('physical')->after('domain');
                    $table->index('category_type');
                }
                if (! Schema::hasColumn('library_categories', 'description')) {
                    $table->text('description')->nullable()->after('name_en');
                }
                if (! Schema::hasColumn('library_categories', 'is_active')) {
                    $table->boolean('is_active')->default(true)->after('sort_order');
                    $table->index('is_active');
                }
            });
        }

        // 2. items detailed book fields
        if (Schema::hasTable('items')) {
            Schema::table('items', function (Blueprint $table) {
                if (! Schema::hasColumn('items', 'subtitle')) {
                    $table->string('subtitle', 255)->nullable()->after('name');
                }
                if (! Schema::hasColumn('items', 'publisher')) {
                    $table->string('publisher', 200)->nullable()->after('author');
                }
                if (! Schema::hasColumn('items', 'publication_year')) {
                    $table->unsignedSmallInteger('publication_year')->nullable()->after('publisher');
                }
                if (! Schema::hasColumn('items', 'language')) {
                    $table->string('language', 64)->default('am')->after('publication_year');
                }
            });
        }

        // 3. Seed granular education permissions
        $permissions = [
            ['education.view', 'education', 'View education dashboard and overview'],
            ['education.classes', 'education', 'Manage classes and student enrollments'],
            ['education.curriculum', 'education', 'Manage curriculum structure, canonical grades, and courses'],
            ['education.lessons', 'education', 'Manage units, lessons, and lesson topics'],
            ['education.materials', 'education', 'Create and manage learning materials'],
            ['education.materials_approve', 'education', 'Review, approve and publish learning materials'],
            ['education.quizzes', 'education', 'Create and manage course and lesson quizzes'],
            ['education.exams', 'education', 'Create, configure and manage closing/final exams'],
            ['education.assessments', 'education', 'Manage course assessments, rubrics and assignment guidelines'],
            ['education.marks', 'education', 'Enter grades, score assessments and publish report cards'],
            ['education.attendance_view', 'education', 'View education attendance rosters and statistics (HR records)'],
            ['education.settings', 'education', 'Configure academic year, terms and education settings'],
        ];

        if (Schema::hasTable('permissions')) {
            foreach ($permissions as [$key, $group, $desc]) {
                try {
                    $exists = DB::table('permissions')->where('key', $key)->exists();
                    if (! $exists) {
                        DB::table('permissions')->insert([
                            'key' => $key,
                            'group_key' => $group,
                            'description' => $desc,
                            'created_at' => now(),
                            'updated_at' => now(),
                        ]);
                    }
                } catch (\Throwable) {
                    // Ignore on partial or non-standard DB engines
                }
            }

            // Assign to edu_admin role if present
            if (Schema::hasTable('roles') && Schema::hasTable('role_permissions')) {
                try {
                    $eduRoleId = DB::table('roles')->where('slug', 'edu_admin')->value('id');
                    if ($eduRoleId) {
                        foreach ($permissions as [$key, $group, $desc]) {
                            $permId = DB::table('permissions')->where('key', $key)->value('id');
                            if ($permId) {
                                $alreadyHas = DB::table('role_permissions')
                                    ->where('role_id', $eduRoleId)
                                    ->where('permission_id', $permId)
                                    ->exists();
                                if (! $alreadyHas) {
                                    DB::table('role_permissions')->insert([
                                        'role_id' => $eduRoleId,
                                        'permission_id' => $permId,
                                    ]);
                                }
                            }
                        }
                    }
                } catch (\Throwable) {
                    // Role table assignment fallback
                }
            }
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasTable('library_categories')) {
            Schema::table('library_categories', function (Blueprint $table) {
                $cols = array_filter(['category_type', 'description', 'is_active'], fn ($c) => Schema::hasColumn('library_categories', $c));
                if (! empty($cols)) {
                    $table->dropColumn($cols);
                }
            });
        }

        if (Schema::hasTable('items')) {
            Schema::table('items', function (Blueprint $table) {
                $cols = array_filter(['subtitle', 'publisher', 'publication_year', 'language'], fn ($c) => Schema::hasColumn('items', $c));
                if (! empty($cols)) {
                    $table->dropColumn($cols);
                }
            });
        }

        if (Schema::hasTable('permissions')) {
            $keys = [
                'education.view',
                'education.classes',
                'education.curriculum',
                'education.lessons',
                'education.materials',
                'education.materials_approve',
                'education.quizzes',
                'education.exams',
                'education.assessments',
                'education.marks',
                'education.attendance_view',
                'education.settings',
            ];
            DB::table('permissions')->whereIn('key', $keys)->delete();
        }
    }
};
