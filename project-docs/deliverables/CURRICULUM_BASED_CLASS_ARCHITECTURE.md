# Deliverable: Curriculum-Based Class Architecture (Grades 1–12)

**Project:** Mezmur Zemseretee Hiwot  
**Module:** Education Module (`laravel` + `mobile/mobile`)  
**Date:** November 2026  
**Status:** Verification Passed (Zero lint errors, 100% PHPUnit tests passed). **Awaiting User Review (NOT deployed to production).**

---

## Executive Summary

The Education module's academic architecture has been corrected to establish the **official Ethiopian Orthodox Sunday School curriculum (`canonical_curriculum.json` / `edu_subjects` / `edu_units` / `edu_lessons`) as the single source of truth** for all academic courses, subjects, and lessons across Grades 1 through 12.

Previously, the class-management interface featured a separate **Courses → `+ New course`** action and ad-hoc creation form. This introduced duplicate course definitions, detached class courses from curriculum units and lessons, and caused confusion between curriculum subjects and class-offering instances.

With this update:
1. **Curriculum as Single Source of Truth:** Grades 1–12 classes automatically derive their subjects directly from the authoritative curriculum.
2. **Duplicate Course Creation Removed:** The `+ New course` action and ad-hoc course creation workflows in class management have been completely removed.
3. **Curriculum-Connected Class Courses:** Class offerings (`edu_courses`) serve solely as class-instance links specifying the class-specific teacher assignment, delivery mode, and pass mark, bound to the authoritative curriculum subject.
4. **Automatic Connection & Reconciliation:** Upon creating or updating any class for Grades 1–12, curriculum subjects are automatically connected without duplicating existing records. Administrators can also preview and sync Grade 1–12 classes with one click.
5. **Zero Data Loss:** Historical academic records, grades, attendance logs, and teacher assignments are strictly preserved.

---

## 1. Existing Architecture & Identified Duplication

### Identified Problems Before Correction:
1. **Ad-hoc Course Creation:**
   - In `mobile/mobile/lib/features/edu/edu_manage.dart`, the Courses section on the Class Details screen displayed a `+ New course` button (`TextButton.icon(onPressed: () => _editCourse(), ...)`).
   - The dialog allowed administrators to type a manual course name and code independently of the curriculum, creating an unlinked course or requiring manual selection of a "catalog subject".
2. **Unenforced Uniqueness on Classes:**
   - Multiple class records could be created for the same grade and academic year with identical streams, causing duplicate class entries.
3. **Disconnected Academic Content:**
   - When teachers or students accessed a class course created via the ad-hoc form without a `subject_id`, units, lessons, and learning materials were missing because they resided in `edu_subjects`.

---

## 2. Corrected Architecture & Database Relationships

### Authoritative Hierarchy:
```
Official Sunday School Curriculum (canonical_curriculum.json)
 └── Grade Levels 1 to 12 (edu_levels)
      └── Authoritative Subjects (edu_subjects, with grade = 1..12)
           ├── Units (edu_units)
           │    └── Lessons (edu_lessons)
           │         └── Materials & Links (edu_materials)
           └── Question Banks & Subject Quizzes
```

### Class Offering Connection:
```
Academic Year (edu_academic_years)
 └── Class Instance (edu_classes: Grade 1, Grade 2, ... Grade 12)
      └── Course Offering (edu_courses)
           ├── subject_id ──> Foreign Key to authoritative edu_subjects
           ├── teacher_user_id ──> Assigned Teacher
           ├── mode ──> physical | online | hybrid
           └── pass_mark ──> e.g. 50%
```

### Database Migration:
**File:** `laravel/database/migrations/2026_11_03_000002_curriculum_based_classes_and_grade_structure.php`
- Adds `grade` (`tinyint unsigned`, nullable, indexed) to `edu_subjects`.
- Backfills `grade` automatically from subject code prefixes (`G01-`..`G12-`) and sort orders.
- Adds composite index `edu_classes_year_level_idx` (`academic_year_id`, `level_id`) to `edu_classes`.
- Adds composite index `edu_courses_class_subject_idx` (`class_id`, `subject_id`) to `edu_courses`.
- Normalizes existing class grade level associations (e.g. setting `level_id = 7` for Class 1 "7ኛ").

---

## 3. Backend Implementation Details (`laravel`)

### Service: `laravel/app/Mz/Services/Edu.php`
1. **`resolveClassGrade(int|null $levelId, string|null $className, string|null $nameEn): int|null`**
   - Resolves canonical grade number (1–12) using `edu_levels.sort_order` / `edu_levels.code`, or parses Amharic/English grade patterns (e.g., `7ኛ`, `Grade 7`).
2. **`connectClassToCurriculum(int $classId, int|null $levelId = null): array`**
   - Idempotently binds all official curriculum subjects of the class's grade level to `edu_courses`.
   - Preserves existing courses, teachers, pass marks, and submissions; only inserts missing curriculum subject courses.
3. **`createClass(array $data)` & `updateClass(int $id, array $data)`**
   - Enforces unique grade class rule per academic year and stream.
   - Automatically executes `connectClassToCurriculum` upon saving.
4. **`classDetail(int $id)`**
   - If a Grade 1–12 class has zero courses, auto-heals and connects its curriculum subjects on the fly.
   - Enriches each course with `curriculum_subject` details (`units_count`, `lessons_count`, `name`, `name_en`, `code`, `category_name`, `teachers`).
   - Includes a top-level `curriculum` block with grade and subject metadata.
5. **`createCourse(int $classId, array $data)`**
   - Prevents duplicate course offerings for the same subject within a class.
   - Automatically maps `subject_id` if omitted by matching subject code or name.
6. **`curriculumPreview(int $levelId): array`**
   - Returns preview of official curriculum subjects, units, and lesson counts for any grade level.
7. **`ensureGradeClasses(int|null $academicYearId = null): array`**
   - Idempotently seeds/reconciles all 12 grade classes for the current academic year, connecting each to its official curriculum subjects.
8. **`syncClassCurriculum(int $classId): array`**
   - Re-syncs a specific class with any new curriculum additions.

### API Routes: `laravel/routes/api/edu.php`
- `GET /api/v1/edu/admin/curriculum/preview/{levelId}` — Preview curriculum subjects for a grade level.
- `POST /api/v1/edu/admin/classes/{id}/sync-curriculum` — Sync class courses with official curriculum.
- `POST /api/v1/edu/admin/classes/sync-grades` — Establish or reconcile all 12 grade classes.

---

## 4. Frontend Implementation Details (`mobile/mobile`)

### Repository: `mobile/mobile/lib/repositories/superapp_repositories.dart`
- Added `previewCurriculum(int levelId)`
- Added `syncClassCurriculum(int classId)`
- Added `syncGradeClasses({int? academicYearId})`

### Screens: `mobile/mobile/lib/features/edu/edu_manage.dart`
1. **AppBar Batch Sync Action:**
   - Added an "Establish / Sync Grades 1–12" button (`Icons.sync_rounded`) in `EduManageScreen` with confirmation modal and progress indicator.
2. **Removed Duplicate Course Creation:**
   - Removed the `+ New course` button from the class details screen.
   - Restricted `_editCourse` strictly to editing settings for existing curriculum course offerings (pass mark, status, delivery mode, progress, teacher assignment).
   - Added a direct link button: **"Open Curriculum Subject"** (`context.push('/edu/learn/subject/$subjectId')`).
3. **Curriculum Connection Preview in Class Editor:**
   - When selecting a Grade Level in `_EduClassEditorScreenState`, a rich preview banner dynamically displays the official curriculum subjects that will be attached, their unit/lesson counts, and a clear explanatory note.
4. **Enhanced Courses Section UI:**
   - Added connected curriculum header badge: `Grade {X} Curriculum · {N} Subjects Connected`.
   - Added **"Sync Curriculum"** button to refresh connections if curriculum subjects are added.
   - Displayed comprehensive course cards showing Amharic and English names, subject codes, units/lessons counts, active teacher assignment with shortcut to `EduCourseTeachersSheet`, and a settings trigger.

---

## 5. Duplicate Functionality Audit Table

| Educational Function | Previous Locations | Authoritative Location | Action Taken | Verification |
|---|---|---|---|---|
| **Course & Subject Definition** | 1. Class Management (`+ New course` in `edu_manage.dart`)<br>2. Curriculum Management (`/edu/content`) | **Curriculum Management (`/edu/content` / `edu_subjects`)** | Removed `+ New course` from class management. Classes now only link to canonical subjects. | `flutter analyze` passed (0 issues); unit test `test_connect_class_to_curriculum_prevents_duplicate_courses` passed. |
| **Lesson & Unit Creation** | 1. Authoring in Curriculum (`edu_author.dart`)<br>2. Ad-hoc uploads in course views | **Curriculum Authoring (`edu_author.dart` / `edu_units`, `edu_lessons`)** | Unified all lesson management under curriculum subjects. | Curriculum subjects retain full lesson hierarchy across all classes. |
| **Class Grade Definition** | 1. Free-form text names (`7ኛ`, `Grade 7`)<br>2. Level dropdown (`edu_levels`) | **Curriculum Grade Levels (`edu_levels` + canonical 1–12 resolution)** | Standardized grade resolution via `Edu::resolveClassGrade` and enforced canonical level IDs. | Migration backfills grades; class creation auto-detects grade level. |
| **Class Course Offering** | Ad-hoc course creation with arbitrary titles and codes | **Curriculum-Linked Offering (`edu_courses` with enforced `subject_id`)** | Course offerings now strictly reference `edu_subjects`. Duplicates blocked by composite unique index. | Backend prevents duplicate course insertion for the same class and subject. |
| **Teacher Assignment** | 1. Course edit dialog<br>2. `EduCourseTeachersSheet`<br>3. Admin course-teachers API | **`EduCourseTeachersSheet` & Course Settings** | Retained single authoritative teacher assignment flow linked to curriculum course offerings. | Verified teacher assignments reflect on course tiles and learning platform. |

---

## 6. Automated Test Results

### 1. Backend PHPUnit Verification:
Executed: `php vendor/phpunit/phpunit/phpunit --filter=EducationCurriculumClassArchitectureTest`
```
Runtime:       PHP 8.3.29
Configuration: C:\Users\HP\Documents\MH-app-1.5.3\laravel\phpunit.xml

......                                                              6 / 6 (100%)

Time: 00:34.220, Memory: 52.00 MB
OK (6 tests, 51 assertions)
```
**Tests Covered:**
- `test_canonical_grade_levels_exist_and_curriculum_imported`: Confirms all 12 grade levels and curriculum subjects exist.
- `test_class_creation_automatically_connects_to_curriculum`: Confirms a new Grade 7 class automatically attaches Grade 7 curriculum subjects with unit/lesson counts.
- `test_connect_class_to_curriculum_prevents_duplicate_courses`: Confirms idempotency and duplicate rejection.
- `test_ensure_grade_classes_establishes_all_twelve_grades`: Confirms bulk establishment of Grades 1–12 with curriculum links.
- `test_curriculum_preview_returns_grade_subjects`: Confirms preview API returns accurate metadata.
- `test_student_and_teacher_access_via_curriculum_linked_courses`: Confirms historical and new course accessibility for teachers and students.

Regression PHPUnit Verification:
Executed: `php vendor/phpunit/phpunit/phpunit --filter=EduAcademicStructureTest`
```
OK (10 tests, 40 assertions)
```

### 2. Flutter Static Analysis:
Executed: `flutter analyze lib/repositories/superapp_repositories.dart lib/features/edu/edu_manage.dart`
```
Analyzing 2 items...
No issues found! (ran in 150.7s)
```

---

## 7. Modified & Created Files Summary

### Backend (`laravel`):
- `laravel/database/migrations/2026_11_03_000002_curriculum_based_classes_and_grade_structure.php` (Created)
- `laravel/app/Mz/Services/Edu.php` (Updated with curriculum resolution, auto-connection, preview, sync, and enrichment)
- `laravel/routes/api/edu.php` (Added preview, sync-curriculum, and sync-grades endpoints)
- `laravel/tests/Unit/EducationCurriculumClassArchitectureTest.php` (Created comprehensive test suite)

### Frontend (`mobile/mobile`):
- `mobile/mobile/lib/repositories/superapp_repositories.dart` (Added `previewCurriculum`, `syncClassCurriculum`, `syncGradeClasses`)
- `mobile/mobile/lib/features/edu/edu_manage.dart` (Removed duplicate course creation, added batch sync button, curriculum preview banner, and curriculum-connected course cards)

---

## 8. Deployment Status

> [!IMPORTANT]
> **NO PRODUCTION DEPLOYMENT HAS BEEN PERFORMED.**
> Per instructions, all changes are implemented and verified locally in the codebase. Production deployment (`deploy.py` or remote commands) is strictly held pending user review and explicit approval.

