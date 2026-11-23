<?php

namespace App\Mz\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use RuntimeException;
use Throwable;

class EduCurriculumImport
{
    /**
     * Map subject name to canonical category ID.
     */
    public static function resolveCategoryId(string $title): int
    {
        $t = trim($title);
        if (str_contains($t, 'ሃይማኖት') || str_contains($t, 'ስብከት')) {
            return 1; // ትምህርተ ሃይማኖት (Theology & Doctrine)
        }
        if (str_contains($t, 'መጽሐፍ ቅዱስ') || str_contains($t, 'ሐዲሳት') || str_contains($t, 'መጻሕፍት') || str_contains($t, 'ሊቃውንት')) {
            return 4; // የመጽሐፍ ቅዱስ ጥናት (Bible Study)
        }
        if (str_contains($t, 'ሥነ ምግባር') || str_contains($t, 'ሥነምግባር') || str_contains($t, 'ጾታ') || str_contains($t, 'ሥነ ልቡና') || str_contains($t, 'ሕይወት')) {
            return 5; // ክርስቲያናዊ ሥነምግባር (Christian Ethics)
        }
        if (str_contains($t, 'ሥርዓተ ቤተ') || str_contains($t, 'ሥርዐተ ቤተ') || str_contains($t, 'ምሥጢራተ') || str_contains($t, 'ምስጢራተ') || str_contains($t, 'ሥርዓተ ቅዳሴ') || str_contains($t, 'አስተዳደር') || str_contains($t, 'ሥራ አመራር') || str_contains($t, 'ዕወቅ') || str_contains($t, 'እወቅ')) {
            return 6; // ሥርዓተ ቤተ ክርስቲያን (Church Order & Rites)
        }
        if (str_contains($t, 'ታሪክ') || str_contains($t, 'በዓላት') || str_contains($t, 'ፍልስፍና') || str_contains($t, 'ምርምር')) {
            return 3; // የቤተክርስትያን ታሪክ (Church History)
        }
        if (str_contains($t, 'ግእዝ')) {
            return 7; // ልሳነ ግእዝ (Geez Language)
        }
        if (str_contains($t, 'ዜማ') || str_contains($t, 'መዝሙር')) {
            return 8; // ዜማ (Zema / Sacred Hymnody)
        }
        return 1;
    }

    /**
     * Import or validate canonical curriculum from JSON intermediate artifact.
     *
     * @param bool $dryRun If true, performs validation and dry-run simulation without persistent DB changes.
     * @param string|null $jsonPath Optional custom path to canonical_curriculum.json.
     * @return array Audit summary containing counts, mappings, and validation results.
     */
    public static function import(bool $dryRun = false, ?string $jsonPath = null): array
    {
        $path = $jsonPath ?? database_path('data/canonical_curriculum.json');
        if (! file_exists($path)) {
            throw new RuntimeException("Canonical curriculum intermediate JSON not found at: {$path}");
        }

        $raw = file_get_contents($path);
        $data = json_decode($raw, true);
        if (! is_array($data) || ! isset($data['grades']) || count($data['grades']) !== 12) {
            throw new RuntimeException("Invalid canonical curriculum payload: exactly 12 grades required.");
        }

        $summary = [
            'dry_run' => $dryRun,
            'source_document' => $data['source_document'] ?? 'ሥርዓተ ትምህርት በክፍል (2).docx',
            'grades_processed' => 0,
            'subjects_created' => 0,
            'subjects_updated' => 0,
            'units_created' => 0,
            'units_updated' => 0,
            'lessons_created' => 0,
            'lessons_updated' => 0,
            'legacy_courses_mapped' => 0,
            'errors' => [],
        ];

        // Ensure database tables exist before proceeding
        if (! Schema::hasTable('edu_subjects')) {
            throw new RuntimeException("Target table edu_subjects does not exist.");
        }

        $hasGradeCol = Schema::hasColumn('edu_subjects', 'grade');

        DB::beginTransaction();
        try {
            foreach ($data['grades'] as $gradeData) {
                $g = (int) $gradeData['grade'];
                $gradeName = $gradeData['grade_name'] ?? "{$g}ኛ ክፍል";
                $summary['grades_processed']++;

                foreach ($gradeData['subjects'] as $sIdx => $s) {
                    $title = trim($s['title']);
                    $catId = self::resolveCategoryId($title);
                    $code = $s['code'] ?? sprintf('G%02d-S%02d', $g, $sIdx + 1);
                    $objText = ! empty($s['objectives']) ? implode("\n", $s['objectives']) : null;
                    $desc = $s['subtitle'] ?? "{$gradeName} — {$title}";

                    // Search for existing subject
                    $query = DB::table('edu_subjects');
                    if ($hasGradeCol) {
                        $existingSubject = $query->where('grade', $g)->where('name', $title)->first();
                    } else {
                        $existingSubject = $query->where('sort_order', $g)->where('name', $title)->first();
                    }

                    $subjectId = null;
                    if ($existingSubject) {
                        $subjectId = $existingSubject->id;
                        if (! $dryRun) {
                            $updateData = [
                                'category_id' => $catId,
                                'code' => $code,
                                'description' => $desc,
                                'objectives' => $objText,
                                'sort_order' => $g,
                                'status' => 'published',
                                'updated_at' => now(),
                            ];
                            if ($hasGradeCol) {
                                $updateData['grade'] = $g;
                            }
                            DB::table('edu_subjects')->where('id', $subjectId)->update($updateData);
                        }
                        $summary['subjects_updated']++;
                    } else {
                        if (! $dryRun) {
                            $insertData = [
                                'category_id' => $catId,
                                'name' => $title,
                                'name_en' => "Grade {$g} — {$title}",
                                'code' => $code,
                                'description' => $desc,
                                'objectives' => $objText,
                                'visibility' => 'members',
                                'sequential' => 0,
                                'status' => 'published',
                                'sort_order' => $g,
                                'created_at' => now(),
                                'updated_at' => now(),
                            ];
                            if ($hasGradeCol) {
                                $insertData['grade'] = $g;
                            }
                            $subjectId = DB::table('edu_subjects')->insertGetId($insertData);
                        } else {
                            $subjectId = 999000 + ($g * 100) + $sIdx; // Simulated ID for dry-run
                        }
                        $summary['subjects_created']++;
                    }

                    // Process Chapters / Units
                    if (Schema::hasTable('edu_units') && ! empty($s['chapters'])) {
                        foreach ($s['chapters'] as $cIdx => $chap) {
                            $chapTitle = trim($chap['chapter_title'] ?? "ምዕራፍ " . ($cIdx + 1));
                            $unitOrder = $cIdx + 1;

                            $existingUnit = DB::table('edu_units')
                                ->where('subject_id', $subjectId)
                                ->where('sort_order', $unitOrder)
                                ->first();

                            $unitId = null;
                            if ($existingUnit) {
                                $unitId = $existingUnit->id;
                                if (! $dryRun) {
                                    DB::table('edu_units')->where('id', $unitId)->update([
                                        'title' => $chapTitle,
                                        'updated_at' => now(),
                                    ]);
                                }
                                $summary['units_updated']++;
                            } else {
                                if (! $dryRun) {
                                    $unitId = DB::table('edu_units')->insertGetId([
                                        'subject_id' => $subjectId,
                                        'title' => $chapTitle,
                                        'description' => null,
                                        'sort_order' => $unitOrder,
                                        'status' => 'published',
                                        'created_at' => now(),
                                        'updated_at' => now(),
                                    ]);
                                } else {
                                    $unitId = 888000 + $unitOrder;
                                }
                                $summary['units_created']++;
                            }

                            // Process Lessons / Topics
                            if (Schema::hasTable('edu_lessons') && ! empty($chap['lessons'])) {
                                foreach ($chap['lessons'] as $lIdx => $lessonText) {
                                    $lOrder = $lIdx + 1;
                                    $lTitle = mb_substr(trim($lessonText), 0, 190);

                                    $existingLesson = DB::table('edu_lessons')
                                        ->where('subject_id', $subjectId)
                                        ->where('unit_id', $unitId)
                                        ->where('sort_order', $lOrder)
                                        ->first();

                                    if ($existingLesson) {
                                        if (! $dryRun) {
                                            DB::table('edu_lessons')->where('id', $existingLesson->id)->update([
                                                'title' => $lTitle,
                                                'updated_at' => now(),
                                            ]);
                                        }
                                        $summary['lessons_updated']++;
                                    } else {
                                        if (! $dryRun) {
                                            DB::table('edu_lessons')->insert([
                                                'subject_id' => $subjectId,
                                                'unit_id' => $unitId,
                                                'title' => $lTitle,
                                                'body' => $lessonText,
                                                'sort_order' => $lOrder,
                                                'status' => 'published',
                                                'created_at' => now(),
                                                'updated_at' => now(),
                                            ]);
                                        }
                                        $summary['lessons_created']++;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Legacy Mapping Verification: Ensure Class 1 (7ኛ) courses link stably
            if (Schema::hasTable('edu_courses') && Schema::hasTable('edu_classes')) {
                $class7 = DB::table('edu_classes')->where('id', 1)->first();
                if ($class7) {
                    $legacyCourseMap = [
                        'ትምህርተ ሃይማኖት' => 'መሠረተ ሃይማኖት',
                        'የቤተክርስቲያን ታሪክ' => 'የቤተ ክርስቲያን ታሪክ',
                        'የመጽሐፍ ቅዱስ ጥናት' => 'የመጽሐፍ ቅዱስ ዝርዝር አከፋፈል 1',
                        'ክርስቲያናዊ ሥነምግባር' => 'ክርስቲያናዊ ሥነ ምግባር',
                        'ሥርዓተ ቤተክርስቲያን' => 'ሥርዐተ ቤተክርስቲያን',
                        'ልሳነ ግእዝ' => 'ግእዝ',
                    ];

                    $classGrade = 7;
                    if (isset($class7->grade) && (int) $class7->grade >= 1 && (int) $class7->grade <= 12) {
                        $classGrade = (int) $class7->grade;
                    } elseif (isset($class7->level_id) && (int) $class7->level_id >= 1 && (int) $class7->level_id <= 12) {
                        $classGrade = (int) $class7->level_id;
                    } elseif (preg_match('/(\d{1,2})ኛ/u', $class7->name ?? '', $m)) {
                        $classGrade = (int) $m[1];
                    }

                    $hasSubjectIdCol = Schema::hasColumn('edu_courses', 'subject_id');
                    $courses = DB::table('edu_courses')->where('class_id', 1)->get();
                    foreach ($courses as $c) {
                        $cName = trim($c->name ?? $c->title ?? '');
                        $targetSubjName = $legacyCourseMap[$cName] ?? null;
                        if ($targetSubjName) {
                            $match = DB::table('edu_subjects')
                                ->when($hasGradeCol, fn ($q) => $q->where('grade', $classGrade), fn ($q) => $q->where('sort_order', $classGrade))
                                ->where('name', 'like', "%{$targetSubjName}%")
                                ->first();

                            if (! $match) {
                                $match = DB::table('edu_subjects')
                                    ->where('name', 'like', "%{$targetSubjName}%")
                                    ->first();
                            }

                            if ($match && ! $dryRun && $hasSubjectIdCol) {
                                DB::table('edu_courses')->where('id', $c->id)->update([
                                    'subject_id' => $match->id,
                                ]);
                            }
                            $summary['legacy_courses_mapped']++;
                        }
                    }
                }
            }

            if ($dryRun) {
                DB::rollBack();
            } else {
                DB::commit();
            }

            return $summary;
        } catch (Throwable $e) {
            DB::rollBack();
            throw $e;
        }
    }
}
