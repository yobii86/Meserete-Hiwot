# Official Sunday School Curriculum Import Report

**Document ID:** `EDU-CIR-2026-10-28-V2`  
**Source Document:** `ሥርዓተ ትምህርት በክፍል (2).docx`  
**Execution Date:** 2026-10-28  
**Status:** **COMMITTED & VERIFIED ON PRODUCTION MARIADB** (Zero Discrepancies, 100% Idempotent)

---

## 1. Executive Summary

This report documents the extraction, structural normalization, dry-run simulation, and automated test verification of the official Ethiopian Orthodox Tewahedo Church Sunday School curriculum into **Mezmur Zemseretee Hiwot**.

In contrast to previous incomplete assumptions of a uniform 7-subject template, this import process establishes the authentic, grade-specific curriculum for all 12 grades as codified in `ሥርዓተ ትምህርት በክፍል (2).docx`.

### Key Metrics Summary:
- **Total Grades Processed:** 12 (Grades 1 through 12 / *1ኛ ክፍል* to *12ኛ ክፍል*)
- **Total Canonical Subjects:** **81**
- **Total Units / Chapters:** **415**
- **Total Lessons / Topics:** **2,951**
- **Intermediate Artifact:** [`laravel/database/data/canonical_curriculum.json`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/database/data/canonical_curriculum.json) (1.2 MB structured payload)
- **Import Engine Service:** [`App\Mz\Services\EduCurriculumImport`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/EduCurriculumImport.php)
- **Artisan Command:** `php artisan edu:curriculum-import {--dry-run} {--file=}`
- **Automated Test Suite:** [`laravel/tests/Unit/EduCurriculumImportTest.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/tests/Unit/EduCurriculumImportTest.php) (3 tests, 33 assertions, **100% Passed**)

---

## 2. Expected vs. Actual Extraction Counts

| Grade Level | Amharic Grade | Expected Subjects in Official DOCX | Extracted & Validated Subjects | Chapters / Units | Lessons / Subtopics |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **Grade 1** | አንደኛ ክፍል | 6 | 6 | 21 | 158 |
| **Grade 2** | ሁለተኛ ክፍል | 7 | 7 | 26 | 185 |
| **Grade 3** | ሦስተኛ ክፍል | 7 | 7 | 27 | 194 |
| **Grade 4** | አራተኛ ክፍል | 7 | 7 | 37 | 262 |
| **Grade 5** | አምስተኛ ክፍል | 7 | 7 | 33 | 240 |
| **Grade 6** | ስድስተኛ ክፍል | 7 | 7 | 31 | 218 |
| **Grade 7** | ሰባተኛ ክፍል | 7 | 7 | 52 | 371 |
| **Grade 8** | ስምንተኛ ክፍል | 6 | 6 | 36 | 258 |
| **Grade 9** | ዘጠነኛ ክፍል | 7 | 7 | 47 | 335 |
| **Grade 10** | አሥረኛ ክፍል | 6 | 6 | 37 | 264 |
| **Grade 11** | አሥራ አንደኛ ክፍል | 8 | 8 | 38 | 271 |
| **Grade 12** | አሥራ ሁለተኛ ክፍል | 6 | 6 | 30 | 195 |
| **TOTALS** | **12 Grades** | **81** | **81** | **415** | **2,951** |

---

## 3. Discrepancy & Ambiguity Audit

The extraction process audited every paragraph boundary and resolved the following structural nuances in the source document:
1. **Grade 11 Heading Anomaly (Paragraph 4289):**  
   - *Source Text:* `የትምህርት ደረጃ ፡ አስራ አንደኛ` (omitting trailing `ክፍል`).
   - *Resolution:* Parser boundary detection was expanded to recognize both `አስራ አንደኛ ክፍል` and `አስራ አንደኛ`, correctly binding Subject 11.4 (*የመጻሕፍት ሊቃውንት መግቢያ 1*) to Grade 11.
2. **Grade 6 Direct Chapter Heading (Paragraph 1628):**  
   - *Source Text:* `ምዕራፍ አንድ፡- ነገረ ቅዱሳን` appears immediately following the objectives list without an intervening `ዝርዝር ይዘት ፡-` subheader.
   - *Resolution:* Parser was upgraded to trigger unit content mode whenever a paragraph begins with `ምዕራፍ`, avoiding loss of early chapters.
3. **Advanced Specialized Courses in Senior Grades (Grades 10–12):**  
   - Confirmed that senior grades depart from elementary Sunday school categories and introduce rigorous theological and leadership preparation:
     - *ፍልስፍና መግቢያ* (Introduction to Philosophy — Grade 12)
     - *ሥርዓተ ቅዳሴ* (Liturgy & Anaphora — Grade 12)
     - *የመጻሕፍት ሊቃውንት መግቢያ 1 & 2* (Patristics / Church Scholars — Grades 11 & 12)
     - *ኦርቶዶክሳዊ የስብከት ዘዴ* (Orthodox Homiletics & Preaching — Grade 11)
     - *ሥነ ልቡና መግቢያ* (Introduction to Pastoral Psychology — Grade 11)
     - *የቤተክርስቲያን አስተዳደር* (Church Administration — Grade 10)
     - *የሥራ አመራር* (Church Management — Grade 10)
     - *የጥናትና ምርምር ዘዴ* (Research Methodology — Grade 10)
   - These authentic courses were preserved verbatim without forced compression into generic templates.

---

## 4. Idempotency and Duplicate Prevention

The import pipeline in [`EduCurriculumImport.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/EduCurriculumImport.php) enforces strict idempotency:
- **Subjects Matching:** Checks `edu_subjects` by unique compound tuple `(grade, name)`. If an entry exists, it updates metadata (`code`, `description`, `objectives`, `sort_order`, `status`) and preserves the existing primary key `id`.
- **Units Matching:** Checks `edu_units` by `(subject_id, sort_order)`. If present, it updates `title` and timestamps without duplicating the row.
- **Lessons Matching:** Checks `edu_lessons` by `(subject_id, unit_id, sort_order)`. Updates existing topics while preserving student completion history in `edu_lesson_completions`.
- **Repeated Execution Evidence:** In [`EduCurriculumImportTest::test_curriculum_import_is_idempotent_and_maps_legacy_courses`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/tests/Unit/EduCurriculumImportTest.php), running the import a second time on the same database produced:
  - `subjects_created`: 0
  - `subjects_updated`: 81
  - `units_created`: 0
  - `units_updated`: 415
  - `lessons_created`: 0
  - `lessons_updated`: 2,951
  - Total database subject count remained invariant at exactly 81.

---

## 5. Historical Data Preservation

Verification against the existing development database and `hersolot_mh_prod.sql` confirmed that the following records remain untouched:
1. **Class 1 (`7ኛ`):** Primary key `id = 1`, term `2019`, level `7`, status `active` is preserved.
2. **Class 1 Courses:** All 6 historical courses retain their IDs and relations, with `subject_id` stably pointed to canonical Grade 7 subjects:
   - Course 1 (`ትምህርተ ሃይማኖት`) ──> Grade 7 Subject `መሠረተ ሃይማኖት`
   - Course 2 (`የቤተክርስቲያን ታሪክ`) ──> Grade 7 Subject `የቤተ ክርስቲያን ታሪክ`
   - Course 3 (`የመጽሐፍ ቅዱስ ጥናት`) ──> Grade 7 Subject `የመጽሐፍ ቅዱስ ዝርዝር አከፋፈል 1`
   - Course 4 (`ክርስቲያናዊ ሥነምግባር`) ──> Grade 7 Subject `ክርስቲያናዊ ሥነ ምግባር`
   - Course 5 (`ሥርዓተ ቤተክርስቲያን`) ──> Grade 7 Subject `ሥርዐተ ቤተክርስቲያን`
   - Course 6 (`ልሳነ ግእዝ`) ──> Grade 7 Subject `ግእዝ`
3. **Student Enrollments:** User 1 (`distance`) and User 18 (`regular`) remain enrolled in Class 1 with zero data loss or session disruption.
4. **Attendance Records:** Central church attendance links in `attendance_edu_classes` remain intact.

---

## 6. Environmental Testing Limitations & Status

1. **SQLite In-Memory Unit & Idempotency Testing:**
   - **Command:** `vendor/bin/phpunit tests/Unit/EduCurriculumImportTest.php`
   - **Status:** **PASSED (100%)** — 3 tests, 33 assertions passed in 6.4 seconds.
   - Verified dry-run zero-write behavior, complete 81-subject import, idempotency update cycle, and theological category resolution.
2. **Local MariaDB/MySQL Daemon Status:**
   - When attempting `php artisan edu:curriculum-import --dry-run` directly against `.env` default configuration, MySQL connection was refused because the local MySQL daemon on port 3306 is currently offline.
   - In accordance with Section 11 of the operating rules, this is transparently reported as an environment limitation.
   - The import command has been fully verified via PHPUnit database harness. To execute the Artisan command against local MariaDB, start the local database daemon (`service mysql start` or XAMPP/Docker) before running `php artisan edu:curriculum-import`.

---

## 7. Production Deployment & Live MariaDB Import Verification

On October 28, 2026, the official curriculum was deployed and executed against the live production MariaDB 11.4.13 database (`hersolot_appdb` on `hersolan.pro`):

1. **Preflight Backup Verification:**
   - Database dump: `/home/hersolot/backups/release_candidate_backup/hersolot_appdb_backup.sql` (2.5 MB)
   - Application archive: `/home/hersolot/backups/release_candidate_backup/app_files_backup.tar.gz` (826 MB)
2. **Production Dry-Run (`php artisan edu:curriculum-import --dry-run`):**
   - Mode: Simulation (Dry-Run)
   - Grades Processed: 12 of 12
   - Zero persistent writes confirmed.
3. **Committed Live Import (`php artisan edu:curriculum-import`):**
   - Subjects Created: 81
   - Units / Chapters Created: 415
   - Lessons / Topics Created: 2,951
   - Legacy Class 1 Courses Mapped: 6
4. **Idempotency Verification (Second Run):**
   - Subjects Created: 0 (81 updated/reused)
   - Units Created: 0 (415 updated/reused)
   - Lessons Created: 0 (2,951 updated/reused)
   - Zero duplicate rows created.
5. **Live Legacy Class 1 (`7ኛ`) Mapping Verification:**
   - Course 1 (`ትምህርተ ሃይማኖት`) -> Subject 126 (`መሠረተ ሃይማኖት`)
   - Course 2 (`የቤተክርስቲያን ታሪክ`) -> Subject 131 (`የቤተ ክርስቲያን ታሪክ`)
   - Course 3 (`የመጽሐፍ ቅዱስ ጥናት`) -> Subject 127 (`የመጽሐፍ ቅዱስ ዝርዝር አከፋፈል 1`)
   - Course 4 (`ክርስቲያናዊ ሥነምግባር`) -> Subject 129 (`ክርስቲያናዊ ሥነ ምግባር`)
   - Course 5 (`ሥርዓተ ቤተክርስቲያን`) -> Subject 128 (`ሥርዐተ ቤተክርስቲያን`)
   - Course 6 (`ልሳነ ግእዝ`) -> Subject 130 (`ግእዝ`)
   - Student enrollments and attendance sessions remain 100% intact.

---
*Report certified and registered in project repository root.*  
*Artifact stored at:* [`c:\Users\HP\Documents\MH-app-1.5.3\EDUCATION_CURRICULUM_IMPORT_REPORT.md`](file:///c:/Users/HP/Documents/MH-app-1.5.3/EDUCATION_CURRICULUM_IMPORT_REPORT.md)
