# Meserete-Hiwot Education Module Implementation Plan

**Document ID:** `EDU-IMP-PLAN-001`  
**Date:** 2026-10-27  
**Branch / Commit:** `main` (`8f47b020b6d96e9277c6337c88db8f0c586979be`)  
**Context:** Church/Sunday-School Education Module Implementation  
**Primary Source Inputs:**  
- `EDUCATION_MODULE_INSPECTION_REPORT.md`  
- `EDUCATION_MODULE_INSPECTION_SPEC.md`  
- `ሥርዓተ ትምህርት በክፍል (2).docx` (Supplied in workspace root)  
- `EDUCATION_MODULE_IMPLEMENTATION_PROMPT.md`  

---

## 1. Executive Re-Inspection & Findings Re-Confirmation

A thorough re-inspection of the live workspace confirms the current state:

| Audit Finding ID | Reported Finding | Re-Inspection Status | Evidence in Codebase |
| :--- | :--- | :--- | :--- |
| **`EDU-INS-001`** | Route mismatch on classroom assignments | **Confirmed Defect** | Flutter [`superapp_repositories.dart:328-345`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/repositories/superapp_repositories.dart#L328-L345) calls `GET/POST /edu/me/assignments/$id`, `POST /edu/me/assignments/$id/submit`, `GET /edu/teacher/assignments/$id/submissions`, `POST /edu/teacher/submissions/$id/grade`, `POST /edu/teacher/assignments/$id/release-grades`. In contrast, [`edu_assignments.php:12-54`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/routes/api/edu_assignments.php#L12-L54) registers `assignments/{id}`, `assignments/{id}/submit`, `assignment-submissions/{id}/grade`, `assignments/{id}/release`. Direct HTTP calls return 404. |
| **`EDU-INS-002`** | Duplicate assignment submissions table & destructive upsert | **Confirmed Defect** | [`EduAssignments.php:396-400`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/EduAssignments.php#L396-L400) executes `DB::table('edu_assignment_submissions')->upsert(...)`. It overwrites `text_response`, `attachments`, and timestamps, destroying submission history and completely bypassing `edu_submission_versions`. |
| **`EDU-INS-003`** | Announcement route mismatches | **Confirmed Defect** | Flutter [`superapp_repositories.dart:348-359`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/repositories/superapp_repositories.dart#L348-L359) calls `GET /edu/me/announcements`, `GET /edu/me/announcements/$id`, `POST /edu/teacher/announcements`, whereas [`edu_announcements.php:11-36`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/routes/api/edu_announcements.php#L11-L36) defines `GET /edu/announcements`, `GET /edu/announcements/{id}`, `POST /edu/announcements`. |
| **`EDU-INS-004`** | Curriculum domain inversion & missing DOCX | **Partly Resolved (DOCX Found) / Confirmed Defect in Schema** | The official document `ሥርዓተ ትምህርት በክፍል (2).docx` is present in the workspace root. Content extraction proves the church curriculum is strictly organized by **Grade Level (1–12)** $\rightarrow$ **Subject** $\rightarrow$ **Unit/Chapter (ምዕራፍ)** $\rightarrow$ **Lesson/Subtopic (ክፍል)**. The current database inverted this by making disciplines `edu_categories` and grades `edu_subjects`. |
| **`EDU-INS-005`** | Missing direct material link creation route | **Confirmed Defect** | Flutter calls `POST /edu/categories/$categoryId/grades/$grade/materials/link`. [`edu_learning.php:117-141`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/routes/api/edu_learning.php#L117-L141) only defines `POST categories/{id}/grades/{grade}/materials`. No `/link` route exists. |
| **`EDU-INS-006`** | Orphaned legacy attendance screen | **Confirmed Defect** | [`EduAttendanceScreen`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/edu/edu_screens.dart#L580-L720) at `/edu/attendance/:id` still dispatches `SyncOp.eduAttendanceSet` / `Scan`, which fail with `410 Gone`. |
| **`EDU-INS-007`** | Formative feedback withheld when marks unreleased | **Confirmed Defect** | [`EduAssignments.php:548-554`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/EduAssignments.php#L548-L554) wipes `$sub['feedback'] = null` when `grades_released` is false. |
| **`EDU-INS-008`** | Grade/subject announcements notify empty recipients | **Confirmed Defect** | [`EduAnnouncements.php:125-145`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/EduAnnouncements.php#L125-L145) only queries `edu_enrollments` if `course_id` or `class_id` is set. Announcements targeted to a grade or subject resolve 0 recipient IDs. |
| **`EDU-INS-009`** | Viewport truncation in `edu_learning_test.dart` | **Confirmed Defect (Test & Viewport UX)** | In `_HomeBody` ([`edu_home.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/edu/learn/edu_home.dart)), adding canonical categories and direct cards pushed `EduEmptyCard` beyond 1280dp logical height. Lazy `ListView` did not construct offscreen children during testing. |
| **`EDU-INS-010`** | Missing student Amharic report card PDF generator | **Confirmed Defect** | No printable student term report card PDF exists in the codebase. |
| **FEAT-02 & FEAT-03**| Quiz creation bug fix & Attempt Limits | **Already Fixed & Verified Working** | Quiz creation with `allow_retake` and `max_attempts` passes 6/6 tests in `EduQuizCreationTest.php`. |

---

## 2. Curriculum Analysis: `ሥርዓተ ትምህርት በክፍል (2).docx`

The official Ethiopian Orthodox Tewahedo Church Sunday School syllabus document `ሥርዓተ ትምህርት በክፍል (2).docx` was extracted and audited across its 4,809 paragraphs.

### 2.1 Domain Hierarchy Structure
```
Grade Level (1–12)
 └── Subject (ርእሰ ትምህርት)
      ├── General Objectives (አጠቃላይ ዓላማ)
      ├── Units / Chapters (ምዕራፍ)
      │    └── Lessons / Subtopics (ንዑስ ርእስ / ክፍል)
      ├── Teaching Methodology (ማስተማሪያ ዘዴ)
      └── Reference Bibliography (ዋቢ መጻሕፍት)
```

### 2.2 Complete Grade-by-Grade Subject Matrix Extracted from Source (81 Subjects Total)
| Grade Level | Amharic Name | Subjects Defined in Official Syllabus (81 Total) |
| :--- | :--- | :--- |
| **Grade 1** | አንደኛ ክፍል (6) | መሠረተ ሃይማኖት, ክርስቲያናዊ ሥነ ምግባር, የመጽሐፍ ቅዱስ ታሪክ, ዜማ, ግእዝ, ሥርዓተ ቤተክርስቲያን |
| **Grade 2** | ሁለተኛ ክፍል (7) | መሠረተ ሃይማኖት, ክርስቲያናዊ ሥነ ምግባር, የመጽሐፍ ቅዱስ ታሪክ, ዜማ, ግእዝ, ሥርዓተ ቤተ ክርስቲያን, የቤተክርስቲያን ታሪክ |
| **Grade 3** | ሦስተኛ ክፍል (7) | መሠረተ ሃይማኖት, ክርስቲያናዊ ሥነ ምግባር, የመጽሐፍ ቅዱስ ታሪክ, ዜማ, ግእዝ, ምሥጢራተ ቤተ ክርስቲያን, የቤተክርስቲያን ታሪክ |
| **Grade 4** | አራተኛ ክፍል (7) | መሠረተ ሃይማኖት, ክርስቲያናዊ ሥነ ምግባር, ነገረ መጽሐፍ ቅዱስ, ዜማ, ግእዝ, ሥርዓተ ቤተክርስቲያን, የቤተክርስቲያን ታሪክ |
| **Grade 5** | አምስተኛ ክፍል (7) | መሠረተ ሃይማኖት, ክርስቲያናዊ ሥነ ምግባር, የቅዱሳት መጻሕፍት አከፋፈል እና የትርጉም ስልት መግቢያ, ዜማ, ግእዝ, ሥርዓተ ቤተክርስቲያን, የአበው፣ የሰማዕታት፣ የክርስቶስ እና የእመቤታችን በዓላት ታሪክ |
| **Grade 6** | ስድስተኛ ክፍል (7) | መሠረተ ሃይማኖት, ኦርቶዶክሳዊ የጾታ ትምህርት ሀ, የመጻሕፍት ባህል, ዜማ, ሥርዓተ ቤተክርስቲያንህን ዕወቅ, የአበው፣ የሰማዕታት፣ የክርስቶስ እና የእመቤታችን በዓላት ታሪክ, ግእዝ |
| **Grade 7** | ሰባተኛ ክፍል (7) | መሠረተ ሃይማኖት, የመጽሐፍ ቅዱስ ዝርዝር አከፋፈል 1, ሥርዐተ ቤተክርስቲያን, ክርስቲያናዊ ሥነ ምግባር, ግእዝ, የቤተ ክርስቲያን ታሪክ (ሰባተኛ ክፍል), ዜማ |
| **Grade 8** | ስምንተኛ ክፍል (6) | መሠረተ ሃይማኖት, ክርስቲያናዊ ሥነ ምግባር, ዜማ, የኢትዮጵያ ቤተክርስቲያን ታሪክ, ግእዝ, ምሥጢራተ ቤተ ክርስቲያን |
| **Grade 9** | ዘጠነኛ ክፍል (7) | መሠረተ ሃይማኖት, ክርስቲያናዊ ሥነ ምግባር, የመጻሕፍተ ሐዲሳት ትርጓሜ መግቢያ 1, ግእዝ, ኦርቶዶክሳዊ መዝሙር እና ምስጢራዊ ሥርዓቱ, ዜማ, የቤተክርስቲያን ታሪክ |
| **Grade 10** | አሥረኛ ክፍል (6) | ግእዝ, ዜማ, የቤተክርስቲያን አስተዳደር, የቤተክርስቲያን ታሪክ በኢትዮጵያ, የሥራ አመራር, የጥናትና ምርምር ዘዴ |
| **Grade 11** | አሥራ አንደኛ ክፍል (8)| መሠረተ ሃይማኖት, ኦርቶዶክሳዊ የስብከት ዘዴ, ኦርቶዶክሳዊ የጾታ ትምህርት ለ, የመጻሕፍት ሊቃውንት መግቢያ 1, ግእዝ, ዜማ, ሥነ ልቡና መግቢያ, የቤተክርስቲያን ታሪክ |
| **Grade 12** | አሥራ ሁለተኛ ክፍል (6)| ፍልስፍና መግቢያ, የቤተክርስቲያን ታሪክ, ዜማ, ግእዝ ቋንቋ, ሥርዓተ ቅዳሴ, የመጻሕፍት ሊቃውንት መግቢያ 2 |

---

## 3. Database Inventory & Non-Destructive Data Strategy

### 3.1 Existing Live Production Data ([`hersolot_mh_prod.sql`](file:///c:/Users/HP/Documents/MH-app-1.5.3/hersolot_mh_prod.sql))
- `edu_classes`: 1 class exists (`7ኛ`, ID 1).
- `edu_courses`: 6 courses assigned to Class 1.
- `edu_enrollments`: 2 enrolled students in Class 1.
- `attendance`: 4 legacy attendance entries.

### 3.2 Non-Negotiable Data Safety Rules
1. **Never drop `edu_assignment_submissions` or `edu_submissions`:** Both tables must be retained.
2. **Dual-write on submission:** When a student submits, update `edu_assignment_submissions` for existing view compatibility, write to `edu_submissions`, and append an immutable entry in `edu_submission_versions`.
3. **Preserve existing class and enrollment foreign keys:** Class `7ኛ` (ID 1) must remain untouched and properly mapped to Grade 7 in canonical grade levels.

---

## 4. Phased Implementation Roadmap

### Phase 1: Critical API Contracts & Data Integrity
* **1.1 Backend Route Reconciliation ([`edu_assignments.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/routes/api/edu_assignments.php) & [`edu_announcements.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/routes/api/edu_announcements.php)):**
  - Add route aliases so both `/edu/assignments/...` and `/edu/me/assignments/...`, as well as `/edu/teacher/assignments/...` match correctly.
  - Add route aliases for announcements: `/edu/announcements` and `/edu/me/announcements`, `/edu/teacher/announcements`.
  - Add `POST /edu/categories/{id}/grades/{grade}/materials/link` in [`edu_learning.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/routes/api/edu_learning.php).
* **1.2 Restore Immutable Submissions Versioning ([`EduAssignments.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/EduAssignments.php)):**
  - Modify `EduAssignments::submit()` to record every draft/submission into `edu_submission_versions` and sync with `edu_submissions`.
  - Modify `EduAssignments::serializeSubmission()` to retain formative `feedback` when scores are unreleased.
* **1.3 Grade-Targeted Announcement Notifications ([`EduAnnouncements.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/EduAnnouncements.php)):**
  - Expand `notifyRecipients()` to resolve enrolled students in `edu_classes` by `grade` when `class_id` is null.
* **1.4 HTTP Integration Tests:**
  - Create `tests/Feature/EduHttpContractsTest.php` testing actual Laravel router dispatch with authentication.

### Phase 2: Attendance, Permissions & User Workflow Safety
* **2.1 Decommission Orphaned Attendance Screen ([`edu_screens.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/edu/edu_screens.dart)):**
  - Refactor `/edu/attendance/:id` route to render a read-only class attendance summary and a clear link to the official church attendance scanner.
  - Remove all obsolete dispatches of `SyncOp.eduAttendanceSet` and `SyncOp.eduAttendanceScan`.
* **2.2 Enforce Permission Boundaries:**
  - Verify server-side role checks on assignment grading, mark review, and certificate issuing.

### Phase 3: Curriculum Standardization
* **3.1 Curriculum Seeder & Data Model Alignment:**
  - Create a dedicated migration/seeder `2026_10_31_000001_canonical_church_curriculum.php` populating the canonical 12 grades and subjects extracted from `ሥርዓተ ትምህርት በክፍል (2).docx`.
  - Ensure canonical mapping maps Class `7ኛ` (ID 1) seamlessly.
* **3.2 Learning Materials & Lessons Integration:**
  - Ensure lessons and units can be browsed under their canonical subjects and grades.

### Phase 4: Grading, Quizzes & Amharic Report Card PDF
* **4.1 Printable Amharic Report Card Generator ([`EduReportCard.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/EduReportCard.php)):**
  - Implement a student term report card service producing an Amharic PDF complete with church seal, student profile, subject scores, averages, attendance summary, and pass/promotion determination.
  - Add backend route `GET /edu/students/{id}/report-card/pdf` and `GET /edu/me/report-card/pdf`.
* **4.2 Grading Policy Verification:**
  - Highest retake mark counts; attempt history remains intact.

### Phase 5: UI & Viewport Test Hygiene
* **5.1 Fix `edu_learning_test.dart`:**
  - Update `testWidgets('a new member is guided to registration...')` in `mobile/mobile/test/edu_learning_test.dart` to properly scroll until the registration card is visible using `tester.scrollUntilVisible()`, reflecting actual user interaction.
* **5.2 Verify Flutter Navigation & Responsive Layouts:**
  - Confirm all 12 canonical grade levels render cleanly across dark/light modes and Amharic Fidel script.

### Phase 6: Full Verification & Deliverables
* Execute full PHPUnit test suite.
* Execute full Flutter test suite.
* Update `EDUCATION_MODULE_INSPECTION_REPORT.md` (annotate fixed items).
* Produce `EDUCATION_IMPLEMENTATION_REPORT.md`.

---

## 5. Acceptance Checklist

- [x] All assignment endpoints (`/edu/me/assignments`, `/edu/assignments/{id}/submit`, `/edu/teacher/assignments`) dispatch HTTP 200/201 in real router integration tests.
- [x] Submitting an assignment resubmission writes to `edu_submission_versions` without overwriting historical version rows.
- [x] Saved teacher feedback is visible to students even when numerical marks are unreleased.
- [x] Direct material external link route `POST /edu/categories/{id}/grades/{grade}/materials/link` returns HTTP 201.
- [x] Announcement endpoints match between Flutter and Laravel; grade-level announcements notify all enrolled students.
- [x] `/edu/attendance/:id` route is read-only and never calls 410-failing sync operations.
- [x] `flutter test test/edu_learning_test.dart` passes cleanly (13/13 tests passed).
- [x] Official syllabus from `ሥርዓተ ትምህርት በክፍል (2).docx` is codified and available (81 subjects, 415 chapters, 2951 topics in `canonical_curriculum.json`).
- [x] Student Amharic report card PDF endpoint generates valid PDF with correct marks and church metadata.
- [x] Zero production mutations or unapproved deployments occur.
