<?php

namespace App\Console\Commands;

use App\Mz\Services\EduCurriculumImport;
use Illuminate\Console\Command;
use Throwable;

class ImportEduCurriculum extends Command
{
    protected $signature = 'edu:curriculum-import 
                            {--dry-run : Validate and simulate import without making persistent database changes}
                            {--file= : Path to custom canonical curriculum JSON file}';

    protected $description = 'Idempotently import the official Ethiopian Orthodox Sunday School curriculum into the education platform';

    public function handle(): int
    {
        $dryRun = (bool) $this->option('dry-run');
        $customFile = $this->option('file');

        $this->info('================================================================');
        $this->info('  OFFICIAL SUNDAY SCHOOL CURRICULUM IMPORT PIPELINE');
        $this->info('  Mezmur Zemseretee Hiwot — Spiritual Education Module');
        $this->info('================================================================');
        $this->line('Mode: ' . ($dryRun ? '<comment>DRY-RUN (Simulation only — zero DB writes)</comment>' : '<info>LIVE LOCAL IMPORT</info>'));

        try {
            $summary = EduCurriculumImport::import($dryRun, $customFile);

            $this->newLine();
            $this->info('--- Import Summary ---');
            $this->table(
                ['Metric', 'Value'],
                [
                    ['Source Document', $summary['source_document']],
                    ['Execution Mode', $summary['dry_run'] ? 'Simulation (Dry-Run)' : 'Committed'],
                    ['Grades Processed', $summary['grades_processed'] . ' of 12'],
                    ['Subjects Created', (string) $summary['subjects_created']],
                    ['Subjects Updated / Reused', (string) $summary['subjects_updated']],
                    ['Units / Chapters Created', (string) $summary['units_created']],
                    ['Units / Chapters Updated / Reused', (string) $summary['units_updated']],
                    ['Lessons / Topics Created', (string) $summary['lessons_created']],
                    ['Lessons / Topics Updated / Reused', (string) $summary['lessons_updated']],
                    ['Legacy Class 1 Courses Mapped', (string) $summary['legacy_courses_mapped']],
                ]
            );

            $this->info('Curriculum import validation completed successfully.');
            return Command::SUCCESS;
        } catch (Throwable $e) {
            $this->error('Curriculum import failed: ' . $e->getMessage());
            return Command::FAILURE;
        }
    }
}
