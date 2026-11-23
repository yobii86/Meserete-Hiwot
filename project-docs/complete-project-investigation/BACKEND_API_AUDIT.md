# BACKEND API & ROUTING AUDIT (`laravel`)
**Project:** Mezmur Zemseretee Hiwot  
**Target:** `C:\Users\HP\Documents\MH-app-1.5.3\laravel`  
**Investigation Date:** November 11, 2026  
**Auditor / Agent:** Antigravity

---

## 1. ROUTING ARCHITECTURE & METRICS
The Laravel backend exposes **741 total routes** (with **729 API endpoints**) organized into 34 modular route declaration files under `routes/api/` and `routes/web/`.

Every API endpoint adheres to a standardized JSON response contract:
```json
{
  "success": true,
  "code": "OK",
  "message": "Human readable status message",
  "data": { ... },
  "errors": []
}
```
In case of errors:
```json
{
  "success": false,
  "code": "ERROR_CODE_STRING",
  "message": "Validation or execution error description",
  "data": null,
  "errors": [ ... ]
}
```

---

## 2. API ROUTE BREAKDOWN BY DOMAIN MODULE

### 1. `routes/api/auth.php` (Authentication & Security)
- `POST /api/v1/auth/login`: Phone and PIN verification; returns JWT access token + refresh token.
- `POST /api/v1/auth/register`: New user registration with profile details.
- `POST /api/v1/auth/refresh`: Issues a new 15-minute access token using an active refresh token.
- `POST /api/v1/auth/logout`: Revokes active refresh token and blacklists access token in `revoked_access_tokens`.
- `POST /api/v1/auth/forgot-password`: Generates password reset token and sends OTP (or simulated).
- `POST /api/v1/auth/reset-password`: Validates OTP and updates user PIN.
- `POST /api/v1/auth/system-login`: High-authority administrator emergency access with IP restriction.

### 2. `routes/api/me.php` & `routes/api/personal.php` (User Profile & Account)
- `GET /api/v1/me`: Returns current user object, assigned roles, permissions, and department memberships.
- `PUT /api/v1/me/profile`: Submits profile modification request (requires admin review if sensitive).
- `GET /api/v1/me/favorites`: Returns user's saved hymns, lessons, and books.
- `GET /api/v1/me/scores`: Returns current student's grades and report card summaries across enrolled terms.
- `GET /api/v1/me/attendance`: Personal attendance history across church programs and classes.
- `GET /api/v1/personal/sessions`: List active login devices and IPs.
- `DELETE /api/v1/personal/sessions/{id}`: Terminate a specific remote session.
- `GET /api/v1/personal/payments`: View contribution pledge amount, payment rates, and receipt statuses.
- `POST /api/v1/personal/contribution-receipts`: Upload bank deposit slip with image proof and transaction ref.
- `GET /api/v1/personal/borrowings`: View currently borrowed library books, due dates, and return condition.

### 3. `routes/api/content.php` (Mezmurs & Hymnology)
- `GET /api/v1/content/categories`: Hierarchical category tree with hymn count.
- `GET /api/v1/content/mezmurs`: Paginated hymn list with filters (`category_id`, `tag`, `fasting_season`).
- `GET /api/v1/content/mezmurs/{id}`: Full hymn detail including lyrics, audio URL, melody type, author, and scripture.
- `GET /api/v1/content/search`: Full-text search across titles and lyrics.
- `GET /api/v1/content/tags`: All liturgical tags (e.g. ቅዱስ ሚካኤል, ልደት, ፋሲካ).
- `POST /api/v1/content/admin/mezmurs` (Admin): Create or update hymn records and upload audio files.

### 4. `routes/api/edu*.php` (Education & Learning Management System) — 240 Routes
The education API suite is partitioned into five specialized route files:
- **`edu_academics.php` (27 routes):**
  - `GET /api/v1/edu/academic-years`: List academic cycles and active status.
  - `GET /api/v1/edu/grades/{grade}/subjects`: Curriculum subjects mapped to specific grade levels.
  - `GET /api/v1/edu/classes`: Classes running in the parish with student rosters and assigned teachers.
  - `POST /api/v1/edu/classes/{id}/students`: Bulk student enrollment.
- **`edu_learning.php` (89 routes):**
  - `GET /api/v1/edu/courses`: Available and enrolled student courses.
  - `GET /api/v1/edu/courses/{id}/units`: Course curriculum organized into sequential units.
  - `GET /api/v1/edu/lessons/{id}`: Complete lesson content, attachments, and reading state.
  - `POST /api/v1/edu/lessons/{id}/complete`: Record lesson completion and update student progress %.
  - `GET /api/v1/edu/continue-learning`: Resumes the user's most recent incomplete lesson.
  - `GET /api/v1/edu/quizzes/{id}`: Quiz metadata, question count, and time limit.
  - `POST /api/v1/edu/quizzes/{id}/attempt`: Start a timed quiz session (locks questions via `edu_quiz_draws`).
  - `POST /api/v1/edu/quizzes/{id}/submit`: Submit answers; calculates score, pass/fail, and attempts left.
  - `POST /api/v1/edu/quizzes/{id}/request-retake`: File a retake request for failed or missed quizzes.
- **`edu_assignments.php` (20 routes):**
  - `GET /api/v1/edu/assignments`: Active homework and term assignments.
  - `POST /api/v1/edu/assignments/{id}/submit`: Submit assignment (text notes or file upload).
  - `POST /api/v1/edu/assignments/{id}/grade` (Teacher): Grade submission with numeric marks and feedback.
- **`edu_announcements.php` (10 routes):**
  - Academic notifications and deadlines broadcast by teachers to class members.
- **`edu.php` (94 routes):**
  - Admin management endpoints: curriculum synchronization, teacher assignments, report cards, graduation certificate issuance, complaints, and digital magazines.

### 5. `routes/api/library.php` & `routes/api/borrowing.php` (Library & Circulation)
- `GET /api/v1/library/categories`: Book categories with domain filtering (`spiritual`, `education`, `history`).
- `GET /api/v1/library/books`: Book catalog with format filter (`digital`, `physical`, `both`).
- `GET /api/v1/library/books/{id}`: Book details, digital PDF download URL, WebP page count, and physical copy inventory.
- `GET /api/v1/library/books/{id}/pages/{page}`: Serves individual WebP page image for instant online reading.
- `POST /api/v1/borrowing/request`: Member requests to borrow a physical book copy.
- `POST /api/v1/borrowing/{id}/checkout` (Librarian): Issues physical copy by scanning barcode/copy number.
- `POST /api/v1/borrowing/{id}/return` (Librarian): Records return condition (Good, Damaged, Lost) and calculates fines.

### 6. `routes/api/programs.php` (Liturgical Calendar & Programs)
- `GET /api/v1/programs`: Program listings with recurrence schedules and category badges.
- `GET /api/v1/programs/{id}`: Program schedule, venue, assigned speakers, and attendance takers.
- `POST /api/v1/programs/{id}/attendance-taker`: Designate church members authorized to take attendance.
- `POST /api/v1/programs/{id}/override`: Add an exception to a recurring church program.

### 7. `routes/api/sinksar.php` (Synaxarium / Daily Commemorations)
- `GET /api/v1/sinksar/today`: Returns today's Ethiopian calendar date, feast names, fasting rule, and saint list.
- `GET /api/v1/sinksar/date/{date}`: Sinksar readings for any Ethiopian date (`YYYY-MM-DD`).
- `GET /api/v1/sinksar/narratives/{id}`: Full Amharic narrative and audio recitation file URL.

### 8. `routes/api/guidance.php` (Contextual Help & Tours)
- `GET /api/v1/guidance/articles`: Instruction articles grouped by module key.
- `POST /api/v1/guidance/articles/{id}/progress`: Tracks user completion of tours and guides.

### 9. `routes/api/projects.php` (Parish Project Management) — 53 Routes
- `GET /api/v1/projects`: Active development and charity projects.
- `POST /api/v1/projects`: Create project with objectives, start/end dates, and budget ceiling.
- `GET /api/v1/projects/{id}/tasks`: Work breakdown tasks with assignees and status (Todo, InProgress, Done).
- `POST /api/v1/projects/{id}/budgets`: Set budget category limits.
- `POST /api/v1/projects/{id}/expenses`: Log expenditure with invoice/receipt attachment.
- `POST /api/v1/projects/{id}/decisions`: Record committee resolutions and vote counts.
- `POST /api/v1/projects/{id}/timesheets`: Log volunteer service hours.

### 10. `routes/api/org.php` & `routes/api/admins.php` (Parish Governance)
- `GET /api/v1/org/departments`: Parish departments (Choir, Sunday School, Charity, Development, Clergy).
- `GET /api/v1/org/members`: Searchable parish member roster with privacy-masked contacts.
- `POST /api/v1/org/attendance/sessions`: Open attendance session with session code and taker signature.
- `POST /api/v1/org/attendance/sync`: Bulk offline sync with conflict detection.
- `GET /api/v1/org/contribution-receipts`: Finance committee pending receipt review inbox.
- `POST /api/v1/org/contribution-receipts/{id}/review`: Approve/Reject contribution bank receipts.

### 11. `routes/api/diagnostics.php` & `routes/api/media_migration.php` (System Health)
- `POST /api/v1/diagnostics/report`: Receives automated crash/error logs from mobile clients.
- `GET /api/v1/diagnostics/summary`: System health telemetry for server administrators.
- `POST /api/v1/media-migration/convert-pdf`: Background conversion of large PDFs into WebP pages.

### 12. `routes/api/app.php` & `routes/api/releases.php` (Release Distribution)
- `GET /api/v1/app/version`: Check latest version, mandatory update status, release notes, and download URL.
- `GET /api/v1/app/releases`: Archive of published APK releases.

---

## 3. MIDDLEWARE & API SECURITY PIPELINE

1. **`Mz\Http\SecurityHeaders`:** Enforces HSTS (`max-age=31536000`), `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, and robust Content Security Policy.
2. **`Mz\Http\Throttle`:** Dynamic rate limiter preventing brute-force attacks on auth endpoints (max 5 attempts/minute on PIN login; 60 requests/minute on standard API).
3. **`Mz\Http\Middleware` (`jwt.auth`):** Validates JWT bearer tokens, checks expiration, decrypts user claims, and rejects tokens present in `revoked_access_tokens`.
4. **`Mz\Http\ModuleGate`:** Verifies whether the requesting user has the necessary departmental permissions or administrative roles before executing controller logic.

