<?php

namespace App\Console\Commands;

use App\Mz\Services\Synaxarium;
use App\Mz\Support\EthiopianCalendar;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Throwable;
use ZipArchive;

class ImportSynaxarium extends Command
{
    protected $signature = 'synaxarium:import 
                            {path? : Absolute path to senkisar.zip or directory} 
                            {--force : Force overwrite existing entries} 
                            {--sync-legacy : Also sync unverified narratives into legacy sinksar_narratives table}';

    protected $description = 'Import Amharic Synaxarium (ስንክሳር) books and saints lists from source';

    public function handle(): int
    {
        $startTime = microtime(true);
        $this->info('============================================================');
        $this->info('  ETHIOPIAN ORTHODOX SYNAXARIUM (ስንክሳር) IMPORTER');
        $this->info('============================================================');

        $inputPath = $this->argument('path') 
            ?: 'c:\\Users\\HP\\Documents\\Downloads\\senkisar.zip';

        if (!file_exists($inputPath)) {
            $altPath = storage_path('app/synaxarium/senkisar.zip');
            if (file_exists($altPath)) {
                $inputPath = $altPath;
            } else {
                $this->error("Source file not found at: {$inputPath}");
                return Command::FAILURE;
            }
        }

        $this->info("Source: {$inputPath} (" . number_format(filesize($inputPath)) . " bytes)");

        // 1. Seed Months (13)
        $this->seedMonths();

        // 2. Open Zip Archive
        $zip = new ZipArchive();
        if ($zip->open($inputPath) !== true) {
            $this->error("Failed to open ZIP archive at: {$inputPath}");
            return Command::FAILURE;
        }

        // 3. Process Amharic Main Books (B001 - B013)
        $mainReport = $this->importMainBooks($zip);

        // 4. Process Amharic Saints Lists (B028 - B040)
        $saintsReport = $this->importSaintsLists($zip);

        $zip->close();

        // 5. Sync to Legacy Table ONLY IF explicitly requested via CLI option
        if ($this->option('sync-legacy')) {
            $this->syncLegacyNarratives();
        }

        $elapsed = round(microtime(true) - $startTime, 2);

        $this->newLine();
        $this->info('============================================================');
        $this->info('  IMPORT COMPLETED SUCCESSFULLY');
        $this->info('============================================================');
        $this->line("  Months Seeded:         13");
        $this->line("  Main Sources Processed:13 (B001 - B013)");
        $this->line("  Main Entries Imported: {$mainReport['imported']} / 366");
        $this->line("  Saints Sources:        13 (B028 - B040)");
        $this->line("  Daily Saints Sections: {$saintsReport['daily_saints_saved']} / 366");
        $this->line("  Saints Records Saved:  {$saintsReport['saints_saved']}");
        $this->line("  Execution Time:        {$elapsed}s");
        $this->info('============================================================');

        return Command::SUCCESS;
    }

    private function seedMonths(): void
    {
        $this->line('Seeding 13 Ethiopian months...');
        $months = Synaxarium::defaultMonthsData();
        foreach ($months as $m) {
            DB::table('synaxarium_months')->updateOrInsert(
                ['month_number' => $m['month_number']],
                [
                    'name_am' => $m['name_am'],
                    'name_en' => $m['name_en'],
                    'name_geez' => $m['name_geez'],
                    'days_count' => $m['days_count'],
                    'order_index' => $m['order_index'],
                    'season_am' => $m['season_am'] ?? null,
                    'updated_at' => now(),
                    'created_at' => now(),
                ]
            );
        }
    }

    private function importMainBooks(ZipArchive $zip): array
    {
        $this->newLine();
        $this->info('Processing 13 Amharic Main Books (B001 - B013)...');

        $months = Synaxarium::defaultMonthsData();
        $importedCount = 0;

        foreach ($months as $m) {
            $mNum = $m['month_number'];
            $mName = $m['name_am'];
            $maxDays = $m['days_count'];

            $fnPrefix = sprintf('B%03d_', $mNum);
            $zipEntryName = $this->findZipEntry($zip, $fnPrefix);

            if (!$zipEntryName) {
                $this->warn("  Warning: No zip entry starting with {$fnPrefix} found.");
                continue;
            }

            $rawContent = $zip->getFromName($zipEntryName);
            if ($rawContent === false) {
                $this->warn("  Warning: Could not read {$zipEntryName} from zip.");
                continue;
            }

            // Remove UTF-8 BOM if present
            $rawContent = preg_replace('/^\xEF\xBB\xBF/', '', $rawContent);
            $sha256 = hash('sha256', $rawContent);
            $bookId = sprintf('B%03d', $mNum);

            // Per-month atomic transaction
            DB::transaction(function () use ($bookId, $mNum, $mName, $maxDays, $zipEntryName, $rawContent, $sha256, &$importedCount) {
                // Register Source
                DB::table('synaxarium_sources')->updateOrInsert(
                    ['book_id' => $bookId],
                    [
                        'classification' => 'main_reading',
                        'month_number' => $mNum,
                        'filename' => $zipEntryName,
                        'collection' => 'C12_Synaxarium_Senkisar',
                        'group' => 'Sinksar_Amharic',
                        'title' => "ስንክሳር ዘወርኀ {$mName}",
                        'language' => 'am',
                        'total_chapters' => $maxDays,
                        'file_size' => strlen($rawContent),
                        'checksum' => $sha256,
                        'import_status' => 'imported',
                        'imported_at' => now(),
                        'updated_at' => now(),
                        'created_at' => now(),
                    ]
                );

                // Split chapters
                $chSplits = preg_split('/=== ምዕራፍ (\d+) ===/', $rawContent, -1, PREG_SPLIT_DELIM_CAPTURE);
                $monthEntries = 0;

                for ($i = 1; $i < count($chSplits); $i += 2) {
                    $chNum = (int) $chSplits[$i];
                    $chBody = trim($chSplits[$i + 1] ?? '');
                    $day = $chNum;

                    if ($day < 1 || $day > $maxDays) {
                        continue;
                    }

                    // Parse annual feasts list
                    $annualFeasts = $this->extractFeasts($chBody, 'annual');
                    // Parse monthly feasts list
                    $monthlyFeasts = $this->extractFeasts($chBody, 'monthly');

                    // Extract title
                    $title = "ስንክሳር ዘወርኀ {$mName} " . $this->ethiopianNumeral($day);
                    if (preg_match('/---\s*(?:\\\\bd\s*)?(ስንክሳር ዘወርኀ [^\n\r-]+?)(?:\\\\bd\*)?\s*---/u', $chBody, $tm)) {
                        $cleanedTitle = trim(preg_replace('/\\\\[a-z*]+/i', '', $tm[1]));
                        if ($cleanedTitle) {
                            $title = $cleanedTitle;
                        }
                    }

                    // Extract verses (ሰላም ለክሙ / ሰላም ለከ) if present at end
                    $verses = null;
                    if (preg_match('/(ሰላም ለ[^\n\r]+[\s\S]+)$/u', $chBody, $vm)) {
                        $verses = $this->cleanAmharicText($vm[1]);
                    }

                    $cleanBody = $this->cleanAmharicText($chBody);

                    // Summary: First 250 characters of clean reading
                    $summary = mb_substr(preg_replace('/\s+/u', ' ', $cleanBody), 0, 250) . '...';
                    $uniqueCode = sprintf('%02d-%02d', $mNum, $day);

                    $charCount = mb_strlen($cleanBody);
                    $wordCount = count(array_filter(preg_split('/\s+/u', $cleanBody)));

                    DB::table('synaxarium_entries')->updateOrInsert(
                        ['month' => $mNum, 'day' => $day],
                        [
                            'unique_code' => $uniqueCode,
                            'title' => $title,
                            'date_heading' => "{$mName} " . $this->ethiopianNumeral($day),
                            'summary' => $summary,
                            'body_am' => $cleanBody,
                            'raw_content' => $chBody,
                            'annual_feasts' => !empty($annualFeasts) ? json_encode($annualFeasts, JSON_UNESCAPED_UNICODE) : null,
                            'monthly_feasts' => !empty($monthlyFeasts) ? json_encode($monthlyFeasts, JSON_UNESCAPED_UNICODE) : null,
                            'verses' => $verses,
                            'source_book_id' => $bookId,
                            'chapter_number' => $chNum,
                            'char_count' => $charCount,
                            'word_count' => $wordCount,
                            'editorial_status' => 'imported',
                            'is_editorially_verified' => false,
                            'editorial_notes' => null,
                            'updated_at' => now(),
                            'created_at' => now(),
                        ]
                    );

                    $importedCount++;
                    $monthEntries++;
                }

                $this->line("  ✓ {$mName} (Month {$mNum}): {$monthEntries} / {$maxDays} days saved.");
            });
        }

        return ['imported' => $importedCount];
    }

    private function importSaintsLists(ZipArchive $zip): array
    {
        $this->newLine();
        $this->info('Processing 13 Amharic Monthly Saints Lists (B028 - B040)...');

        $months = Synaxarium::defaultMonthsData();
        $totalDailySaintsSaved = 0;
        $totalSaintsSaved = 0;

        foreach ($months as $m) {
            $mNum = $m['month_number'];
            $mName = $m['name_am'];
            $maxDays = $m['days_count'];

            $sBookId = sprintf('B%03d', $mNum + 27);
            $fnPrefix = "{$sBookId}_";
            $zipEntryName = $this->findZipEntry($zip, $fnPrefix);

            if (!$zipEntryName) {
                $this->warn("  Warning: No zip entry starting with {$fnPrefix} found.");
                continue;
            }

            $rawContent = $zip->getFromName($zipEntryName);
            if ($rawContent === false) {
                continue;
            }

            $rawContent = preg_replace('/^\xEF\xBB\xBF/', '', $rawContent);
            $sha256 = hash('sha256', $rawContent);

            DB::transaction(function () use ($sBookId, $mNum, $mName, $maxDays, $zipEntryName, $rawContent, $sha256, &$totalDailySaintsSaved, &$totalSaintsSaved) {
                DB::table('synaxarium_sources')->updateOrInsert(
                    ['book_id' => $sBookId],
                    [
                        'classification' => 'saints_list',
                        'month_number' => $mNum,
                        'filename' => $zipEntryName,
                        'collection' => 'C12_Synaxarium_Senkisar',
                        'group' => 'Sinksar_Others',
                        'title' => "በ{$mName} ወር ታስበው የሚውሉ ቅዱሳን",
                        'language' => 'am',
                        'total_chapters' => $maxDays,
                        'file_size' => strlen($rawContent),
                        'checksum' => $sha256,
                        'import_status' => 'imported',
                        'imported_at' => now(),
                        'updated_at' => now(),
                        'created_at' => now(),
                    ]
                );

                $dayRegex = '/---\s*(?:(?:በ)?[^\s]+\s*)?(\d+)\s*ታስበው የሚውሉ ቅዱሳን\s*---/u';
                $splits = preg_split($dayRegex, $rawContent, -1, PREG_SPLIT_DELIM_CAPTURE);

                $dayCountForMonth = 0;

                for ($idx = 1; $idx < count($splits); $idx += 2) {
                    $dayStr = $splits[$idx];
                    $body = isset($splits[$idx + 1]) ? trim($splits[$idx + 1]) : '';

                    if (!is_numeric($dayStr)) {
                        continue;
                    }

                    $day = (int) $dayStr;
                    if ($day < 1 || $day > $maxDays) {
                        continue;
                    }

                    $dayCountForMonth++;

                    // Find corresponding entry_id in synaxarium_entries
                    $entry = DB::table('synaxarium_entries')->where('month', $mNum)->where('day', $day)->first(['id']);
                    $entryId = $entry ? (int) $entry->id : null;

                    // Clean the daily saints section text
                    $cleanSectionText = $this->cleanAmharicText($body);

                    // Extract individual saint commemorations from section headings: "--- {Saint Name} ---"
                    $subHeadings = preg_split('/---\s*([^\n\r-]+?)\s*---/u', $body, -1, PREG_SPLIT_DELIM_CAPTURE);
                    $commemorationCount = 0;

                    // Clear previous saints for this month & day if re-importing
                    DB::table('synaxarium_saints')->where('month', $mNum)->where('day', $day)->delete();

                    if (count($subHeadings) > 1) {
                        // Preamble paragraph before first heading
                        $preamble = trim($subHeadings[0] ?? '');
                        if (mb_strlen($preamble) > 50) {
                            $commemorationCount++;
                            $saintName = $this->extractSaintNameFromText($preamble, $mName, $day);
                            DB::table('synaxarium_saints')->insert([
                                'entry_id' => $entryId,
                                'month' => $mNum,
                                'day' => $day,
                                'order_index' => $commemorationCount,
                                'name' => $saintName,
                                'type' => $this->detectSaintType($saintName),
                                'feast_type' => 'annual',
                                'biography' => $this->cleanAmharicText($preamble),
                                'source_reference' => "ስንክሳር {$mName} {$day}",
                                'raw_content' => $preamble,
                                'source_book_id' => $sBookId,
                                'editorial_status' => 'imported',
                                'is_editorially_verified' => false,
                                'created_at' => now(),
                                'updated_at' => now(),
                            ]);
                            $totalSaintsSaved++;
                        }

                        for ($s = 1; $s < count($subHeadings); $s += 2) {
                            $rawName = trim($subHeadings[$s]);
                            $saintBio = isset($subHeadings[$s + 1]) ? trim($subHeadings[$s + 1]) : '';
                            $commemorationCount++;

                            $cleanName = trim(preg_replace('/[#?\.።]+$/u', '', $rawName));
                            if (empty($cleanName)) {
                                $cleanName = "ቅዱሳን መታሰቢያ";
                            }

                            DB::table('synaxarium_saints')->insert([
                                'entry_id' => $entryId,
                                'month' => $mNum,
                                'day' => $day,
                                'order_index' => $commemorationCount,
                                'name' => $cleanName,
                                'type' => $this->detectSaintType($cleanName),
                                'feast_type' => 'annual',
                                'biography' => $this->cleanAmharicText($saintBio),
                                'source_reference' => "ስንክሳር {$mName} {$day}",
                                'raw_content' => $saintBio,
                                'source_book_id' => $sBookId,
                                'editorial_status' => 'imported',
                                'is_editorially_verified' => false,
                                'created_at' => now(),
                                'updated_at' => now(),
                            ]);
                            $totalSaintsSaved++;
                        }
                    } else {
                        // Single body without subheadings
                        $commemorationCount++;
                        $saintName = $this->extractSaintNameFromText($body, $mName, $day);
                        DB::table('synaxarium_saints')->insert([
                            'entry_id' => $entryId,
                            'month' => $mNum,
                            'day' => $day,
                            'order_index' => $commemorationCount,
                            'name' => $saintName,
                            'type' => $this->detectSaintType($saintName),
                            'feast_type' => 'annual',
                            'biography' => $this->cleanAmharicText($body),
                            'source_reference' => "ስንክሳር {$mName} {$day}",
                            'raw_content' => $body,
                            'source_book_id' => $sBookId,
                            'editorial_status' => 'imported',
                            'is_editorially_verified' => false,
                            'created_at' => now(),
                            'updated_at' => now(),
                        ]);
                        $totalSaintsSaved++;
                    }

                    // Save complete authoritative daily saints section in synaxarium_daily_saints
                    DB::table('synaxarium_daily_saints')->updateOrInsert(
                        ['month' => $mNum, 'day' => $day],
                        [
                            'entry_id' => $entryId,
                            'source_book_id' => $sBookId,
                            'title' => "በ{$mName} {$day} ታስበው የሚውሉ ቅዱሳን",
                            'section_text_clean' => $cleanSectionText,
                            'section_text_raw' => $body,
                            'commemoration_lines_count' => $commemorationCount,
                            'editorial_status' => 'imported',
                            'is_editorially_verified' => false,
                            'created_at' => now(),
                            'updated_at' => now(),
                        ]
                    );

                    $totalDailySaintsSaved++;
                }

                $this->line("  ✓ Saints {$mName} (Month {$mNum}): {$dayCountForMonth} / {$maxDays} days parsed.");
            });
        }

        return [
            'daily_saints_saved' => $totalDailySaintsSaved,
            'saints_saved' => $totalSaintsSaved,
        ];
    }

    private function syncLegacyNarratives(): void
    {
        if (!Schema::hasTable('sinksar_narratives')) {
            return;
        }

        $this->newLine();
        $this->info('Explicit sync requested: syncing Synaxarium entries into legacy sinksar_narratives table...');

        $entries = DB::table('synaxarium_entries')->get();
        $synced = 0;

        foreach ($entries as $e) {
            // Do NOT overwrite existing records that may have been verified or customized
            $exists = DB::table('sinksar_narratives')
                ->where('ethiopian_month', $e->month)
                ->where('ethiopian_day', $e->day)
                ->where('title', $e->title)
                ->exists();

            if (!$exists) {
                DB::table('sinksar_narratives')->insert([
                    'ethiopian_month' => $e->month,
                    'ethiopian_day' => $e->day,
                    'title' => $e->title,
                    'source' => $e->source_book_id ?? 'ስንክሳር',
                    'summary' => $e->summary,
                    'body' => $e->body_am,
                    'verified' => false, // STRICT: Default to false
                    'updated_at' => now(),
                    'created_at' => now(),
                ]);
                $synced++;
            }
        }

        $this->line("  ✓ Inserted {$synced} new unverified narratives into sinksar_narratives (existing custom records untouched).");
    }

    private function extractFeasts(string $text, string $type): array
    {
        $feasts = [];
        $pattern = ($type === 'annual')
            ? '/---\s*(?:.+? ቀን የሚከበሩ )?ዓመታዊ(?: የቅዱሳን)? በዓላት\s*---([\s\S]*?)(?:---|\z)/u'
            : '/---\s*ወርኀዊ በዓላት\s*---([\s\S]*?)(?:---|\z)/u';

        if (preg_match($pattern, $text, $m)) {
            $lines = preg_split('/\r\n|\r|\n/u', trim($m[1]));
            foreach ($lines as $line) {
                $line = trim($line);
                if (empty($line) || str_starts_with($line, '---') || str_starts_with($line, '===') || mb_strlen($line) > 100) {
                    continue;
                }
                // Strip leading numerals: ፩. ፪. 1. 2. etc.
                $clean = trim(preg_replace('/^[\d፩-፱፲-፺]+[\.\s\-]+/u', '', $line));
                $clean = trim(preg_replace('/\\\\[a-z*]+/i', '', $clean));
                $clean = trim(preg_replace('/\b(?:dit\*?|d\*?)\b/u', '', $clean));
                if ($clean && mb_strlen($clean) > 2) {
                    $feasts[] = $clean;
                }
            }
        }

        return $feasts;
    }

    private function cleanAmharicText(string $text): string
    {
        if (empty($text)) {
            return '';
        }

        // Strip formatting tags and rubrication artifacts (dit*, d*, etc.)
        $t = $text;
        $t = preg_replace('/\\\\[a-z*]+/i', '', $t);
        $t = str_replace(['dit*', 'd*', 'n***', 'n*'], '', $t);

        // Normalize multiple spaces/tabs per line
        $lines = preg_split('/\r\n|\r|\n/u', $t);
        $cleanLines = [];
        $blankCount = 0;

        foreach ($lines as $line) {
            $line = trim(preg_replace('/[ \t]+/u', ' ', $line));
            if ($line === '') {
                $blankCount++;
                if ($blankCount <= 2) {
                    $cleanLines[] = '';
                }
            } else {
                $blankCount = 0;
                $cleanLines[] = $line;
            }
        }

        return trim(implode("\n", $cleanLines));
    }

    private function extractSaintNameFromText(string $text, string $monthName, int $day): string
    {
        // Try pattern: "መስከረም 1-ሐዋርያው ቅዱስ በርተሎሜዎስ ዕረፍቱ ነው።"
        if (preg_match('/(?:' . preg_quote($monthName, '/') . '\s*\d+\s*[-–]\s*)([^\n\r።]+?)(?:ዕረፍቱ|ሰማዕት|በዓለ|የተሾመበት|ተአምር|ነው)/u', $text, $m)) {
            $name = trim($m[1]);
            if ($name && mb_strlen($name) > 2 && mb_strlen($name) < 100) {
                return $name;
            }
        }

        // First non-empty line
        $lines = preg_split('/\r\n|\r|\n/u', trim($text));
        foreach ($lines as $l) {
            $l = trim(preg_replace('/^አንድ አምላክ.+?አሜን።?/u', '', $l));
            if ($l && mb_strlen($l) > 4 && mb_strlen($l) < 100) {
                return $l;
            }
        }

        return "የ{$monthName} {$day} ቅዱሳን";
    }

    private function detectSaintType(string $name): string
    {
        if (mb_strpos($name, 'ሐዋርያ') !== false) return 'ሐዋርያ';
        if (mb_strpos($name, 'ሰማዕት') !== false) return 'ሰማዕት';
        if (mb_strpos($name, 'ጻድቅ') !== false || mb_strpos($name, 'ጻድቁ') !== false) return 'ጻድቅ';
        if (mb_strpos($name, 'ነቢይ') !== false || mb_strpos($name, 'ነቢዩ') !== false) return 'ነቢይ';
        if (mb_strpos($name, 'መላእክት') !== false || mb_strpos($name, 'መልአክ') !== false) return 'መልአክ';
        if (mb_strpos($name, 'ጳጳስ') !== false || mb_strpos($name, 'ኤጲስቆጶስ') !== false) return 'ሊቀ ጳጳስ';
        if (mb_strpos($name, 'አቡነ') !== false || mb_strpos($name, 'አባ') !== false) return 'አባት';
        if (mb_strpos($name, 'እግዝእትነ') !== false || mb_strpos($name, 'ማርያም') !== false) return 'እመቤታችን';
        if (mb_strpos($name, 'ቅድስት') !== false) return 'ቅድስት';
        return 'ቅዱስ';
    }

    private function ethiopianNumeral(int $num): string
    {
        $map = [
            1=>'፩', 2=>'፪', 3=>'፫', 4=>'፬', 5=>'፭', 6=>'፮', 7=>'፯', 8=>'፰', 9=>'፱', 10=>'፲',
            11=>'፲፩', 12=>'፲፪', 13=>'፲፫', 14=>'፲፬', 15=>'፲፭', 16=>'፲፮', 17=>'፲፯', 18=>'፲፰', 19=>'፲፱', 20=>'፳',
            21=>'፳፩', 22=>'፳፪', 23=>'፳፫', 24=>'፳፬', 25=>'፳፭', 26=>'፳፮', 27=>'፳፯', 28=>'፳፰', 29=>'፳፱', 30=>'፴'
        ];
        return $map[$num] ?? (string) $num;
    }

    private function findZipEntry(ZipArchive $zip, string $prefix): ?string
    {
        for ($i = 0; $i < $zip->numFiles; $i++) {
            $name = $zip->getNameIndex($i);
            if (str_starts_with($name, $prefix) && str_ends_with($name, '.txt')) {
                return $name;
            }
        }
        return null;
    }
}
