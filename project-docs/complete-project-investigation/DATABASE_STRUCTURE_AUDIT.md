# DATABASE STRUCTURE & SCHEMA AUDIT
**Project:** Mezmur Zemseretee Hiwot  
**Target:** `C:\Users\HP\Documents\MH-app-1.5.3\laravel\database`  
**Investigation Date:** November 11, 2026  
**Auditor / Agent:** Antigravity

---

## 1. DATABASE METRICS & CHARACTERISTICS
- **Database Engine:** MySQL 8.0 (Database: `hersolot_appdb`)
- **Total Tables in Production:** **160 tables**
- **Baseline Tables:** 76 tables (from initial baseline migration)
- **Tables Added via Migrations:** **84 tables** across 45 sequential migration files
- **Character Set / Collation:** `utf8mb4` / `utf8mb4_unicode_ci` (Full Ge'ez script / Amharic / Ethiopic numeral support)
- **Encryption at Rest:** Selective Column-Level AES-256-GCM encryption with HMAC-SHA256 blind indexing for PII

---

## 2. COMPREHENSIVE RELATIONAL DOMAIN BREAKDOWN

### DOMAIN 1: AUTHENTICATION, SESSIONS & SECURITY (11 Tables)
1. `users`: Core identity table (phone, email, password_hash, user_type, status, last_login_at).
2. `refresh_tokens`: Active refresh tokens, client user-agent hash, IP, expiry timestamp.
3. `revoked_access_tokens`: JTI blacklist for immediately terminated JWT access tokens.
4. `password_resets`: Temporary reset tokens, verification OTPs, attempt counts, expiration.
5. `device_history`: Historical device footprints, hardware identifiers, OS versions.
6. `fcm_tokens`: Firebase Cloud Messaging push tokens mapped to user devices.
7. `roles`: System roles (`super_admin`, `admin`, `teacher`, `student`, `member`, `guest`).
8. `permissions`: System capability flags (e.g. `edu.create_course`, `library.checkout`).
9. `role_permissions`: Many-to-many role-to-permission mapping.
10. `user_permissions`: Granular user-specific permission overrides.
11. `user_permission_revocations`: Explicit capability restrictions overriding role permissions.

### DOMAIN 2: MEMBER PROFILES & DIRECTORY (7 Tables)
1. `member_profiles`: Personal demographic data (baptismal name, DOB, gender, blood type, address, emergency contact).
2. `profile_change_requests`: Pending user modifications to identity data awaiting admin review.
3. `profile_change_history`: Audit trail of demographic edits.
4. `member_groups`: Sub-community and fellowship circles within the parish.
5. `professions`: Catalog of member professional vocations (Doctor, Engineer, Lawyer, Artisan).
6. `id_sequences`: Atomic sequential counter for generating unique Member ID numbers.
7. `user_preferences`: Theme preferences, notification options, audio playback settings.

### DOMAIN 3: DEPARTMENTS & ORGANIZATIONAL UNITS (5 Tables)
1. `departments`: Church departments (Choir, Sunday School, Charity, Development, Clergy).
2. `department_admins`: Scoped administrative authority mapped to specific departments.
3. `department_participation`: Active department membership records.
4. `department_participation_history`: Historical logs of member transfers and roles.
5. `user_departments`: Active linkage between users and departments.

### DOMAIN 4: MEZMURS (HYMNS) & LITURGICAL CONTENT (6 Tables)
1. `categories`: Hierarchical liturgical categories (St. Mary, Resurrection, Epiphany, etc.).
2. `mezmurs`: Hymn catalog (title, lyrics, audio URL, melody, author, composer, language).
3. `tags`: Liturgical classification tags.
4. `mezmur_tags`: Relational link between hymns and tags.
5. `favorites`: User-bookmarked hymns and educational content.
6. `user_preferred_categories`: Preferred liturgical seasons for personalized home feed.

### DOMAIN 5: EDUCATION — ACADEMIC HIERARCHY & CURRICULUM (6 Tables)
1. `edu_academic_years`: EOTC Sunday School academic cycles (e.g. 2017 E.C.).
2. `edu_terms`: Academic terms/semesters within an academic year.
3. `edu_levels`: Grade divisions (Primary, Junior, Senior, Adult).
4. `edu_subjects`: Canonical theological subjects (መጽሐፍ ቅዱስ ጥናት, ሥርዓተ ቤተክርስቲያን, ታሪክ...).
5. `edu_categories`: Education subject categories and grouping domains.
6. `edu_classes`: Physical or virtual classroom cohorts for a grade level.

### DOMAIN 6: EDUCATION — COURSES, UNITS & LESSONS (9 Tables)
1. `edu_courses`: Subject courses taught within an academic year/class.
2. `edu_course_enrollments`: Student enrollments into courses.
3. `edu_course_teachers`: Assigned teachers and instructors for courses.
4. `edu_units`: Thematic unit sections inside a course.
5. `edu_lessons`: Individual lesson articles with text, audio, and attachments.
6. `edu_lesson_materials`: Supplementary PDF slides, audio recordings, or reference sheets.
7. `edu_lesson_progress`: Student reading and completion state per lesson.
8. `edu_featured`: Featured promotional courses highlighted on the education dashboard.
9. `edu_journey`: Gamified learning path milestone checkpoints.

### DOMAIN 7: EDUCATION — QUIZZES & QUESTION BANKS (9 Tables)
1. `edu_quizzes`: Quiz configurations (time limit, pass percentage, max attempts).
2. `edu_question_banks`: Repository of assessment questions categorized by subject.
3. `edu_quiz_questions`: Individual questions with multiple-choice options and correct keys.
4. `edu_quiz_draws`: Specific set of randomized questions drawn for a student attempt.
5. `edu_quiz_attempts`: Student attempt session records, elapsed time, submitted timestamp.
6. `edu_quiz_answers`: Individual submitted answers with score per item.
7. `edu_retakes`: Admin/Teacher authorized retake tokens for missed or failed assessments.
8. `edu_score_history`: Audit trail of score calculations and teacher adjustments.
9. `edu_assessments`: Formal mid-term and final examination records.

### DOMAIN 8: EDUCATION — ASSIGNMENTS & GRADING (6 Tables)
1. `edu_assignments`: Homework, essays, and term projects with due dates and rubrics.
2. `edu_assignment_submissions`: Student submission records.
3. `edu_submission_versions`: Revision history for resubmitted work.
4. `edu_submissions`: Legacy assignment submission link table.
5. `edu_scores`: Cumulative subject score records (Quiz + Assignment + Exam = Total).
6. `edu_course_outcomes`: Final course completion verdict (Pass, Fail, Distinction, Incomplete).

### DOMAIN 9: EDUCATION — CERTIFICATES, GRIEVANCES & MAGAZINES (7 Tables)
1. `edu_certificates`: Cryptographically verifiable graduation certificates with QR hash.
2. `edu_requests`: Formal student academic requests (leave of absence, transfer).
3. `edu_complaints`: Grievances filed by students disputing grades or attendance.
4. `edu_complaint_messages`: Two-way conversation thread between student and reviewing teacher.
5. `edu_announcements`: Course and grade-level broadcast notices.
6. `edu_magazines`: Sunday School periodic publications and youth magazines.
7. `edu_class_staff`: Teaching assistants, proctors, and parent liaisons.

### DOMAIN 10: ATTENDANCE MANAGEMENT & AUDIT (8 Tables)
1. `attendance_sessions`: Formal attendance gathering events with start/close timestamps.
2. `attendance`: Individual member check-in records (Present, Late, Excused, Absent).
3. `attendance_closures`: Official administrative closure and lock on attendance sessions.
4. `attendance_corrections`: Rectification records for erroneous marks with reviewer audit.
5. `attendance_signatures`: Digital signature image files and verification hashes from takers.
6. `attendance_sync_conflicts`: Isolated records flagged during offline batch sync collisions.
7. `attendance_edu_classes`: Linkage between general church attendance and academic class attendance.
8. `program_attendance_takers`: Parish members designated as authorized attendance takers.

### DOMAIN 11: PROGRAMS & LITURGICAL CALENDAR (8 Tables)
1. `programs`: Liturgical events, prayer services, and fellowship meetings.
2. `program_categories`: Event categorization (Feast, Vigils, Youth Fellowship, Charity).
3. `program_participants`: Assigned speakers, deacons, choir coordinators, and chairpersons.
4. `program_occurrence_overrides`: Exceptions and cancellations for recurring church events.
5. `program_reminder_choices`: User notification lead-time preferences (15m, 1h, 1d before).
6. `program_edu_classes`: Church programs linked directly to Sunday School schedules.
7. `program_edu_courses`: Specific curriculum tie-ins for church conferences.
8. `reminders`: User alarm schedules and custom audio notifications.

### DOMAIN 12: SINKSAR (SYNAXARIUM) (2 Tables)
1. `sinksar_daily`: Daily saint commemorations, scripture readings, and fasting status per Ethiopian calendar day.
2. `sinksar_narratives`: Full Amharic and Ge'ez spiritual biographies and audio narration references.

### DOMAIN 13: LIBRARY & PHYSICAL CIRCULATION (13 Tables)
1. `items`: Catalog of book titles (digital and physical).
2. `item_categories`: General classification schema for physical property.
3. `library_categories`: Multi-level library categories (Theology, Patristics, History, Language).
4. `library_copies`: Physical book copies with barcodes, accession numbers, and shelf locations.
5. `library_loans`: Active borrowing records with checkout dates, due dates, and return condition.
6. `library_requests`: Member requests to reserve or borrow physical copies.
7. `library_favorites`: User-bookmarked library titles.
8. `library_progress`: Digital book reading bookmarks and page progress.
9. `library_sync_conflicts`: Collisions during offline circulation checkout.
10. `borrowing_batches`: Group borrowing sessions for class study sets.
11. `borrowing_signatures`: Digital signatures of borrowers agreeing to condition terms.
12. `borrowings`: Core borrowing ledger.
13. `return_conditions`: Inspection checklist on return (Binding, Pages, Water damage).

### DOMAIN 14: CONTRIBUTIONS & FINANCIAL GOVERNANCE (3 Tables)
1. `payments`: Ledger of recorded member monthly contribution transactions.
2. `payment_rates`: Established pledge tiers and donation types.
3. `contribution_receipts`: Bank deposit slip image proofs, status (`pending`, `approved`, `rejected`), and review notes.

### DOMAIN 15: PARISH PROJECT MANAGEMENT (17 Tables)
1. `projects`: Church construction, renovation, and outreach projects.
2. `project_members`: Project steering committee and team assignments.
3. `project_milestones`: Major phase milestones with target deadlines.
4. `project_tasks`: Actionable tasks and work packages.
5. `project_task_assignees`: Volunteer members responsible for task completion.
6. `project_timesheets`: Volunteer service hours logged per task.
7. `project_budget_categories`: Financial budget groupings (Materials, Labor, Permits).
8. `project_budget_lines`: Approved line-item spending caps.
9. `project_budget_adjustments`: Formal requests to reallocate funds between lines.
10. `project_expenses`: Actual financial disbursements with attached receipts.
11. `project_files`: Architectural drawings, contracts, and municipal permits.
12. `project_decisions`: Committee voting records and signed resolutions.
13. `project_issues`: Risks, delays, and blocker tracking.
14. `project_comments`: Team discussion threads per project.
15. `project_suggestions`: Parishioner feedback and proposals.
16. `project_progress_reports`: Periodic milestone audit reports submitted to parish council.
17. `project_recognitions`: Certificates of appreciation and honors for volunteers.

### DOMAIN 16: CHOIR GOVERNANCE, SELECTIONS & WEDDINGS (8 Tables)
1. `choir_eligibility`: Qualification rules and compliance status for choir members.
2. `choir_selections`: Recruitment campaigns and candidate rosters.
3. `selection_config_versions`: Evaluator rubric versions.
4. `selection_evaluators`: Appointed panel judges for candidate auditions.
5. `selection_scores`: Candidate scoring across pitch, spiritual discipline, and service.
6. `selection_reviews`: Qualitative evaluation notes from panel judges.
7. `selection_results`: Final committee admission decisions.
8. `selection_feedback`: Constructive feedback returned to applicants.
9. `holiday_selections`: Choir allocations for major holiday liturgies.
10. `wedding_services`: Holy matrimony service bookings.
11. `wedding_service_members`: Choir members designated to sing at specific weddings.

### DOMAIN 17: COMMUNICATIONS & SYSTEM TELEMETRY (14 Tables)
1. `chat_messages`: 1-on-1 direct messages between church members.
2. `chat_reads`: Delivery and read receipts for chat messages.
3. `notifications`: In-app notification center inbox.
4. `notification_broadcasts`: Mass notifications broadcast to departments or the entire parish.
5. `scheduled_notifications`: Timed notifications queued for future delivery.
6. `telegram_link_tokens`: Temporary verification tokens to bind user accounts with Telegram.
7. `telegram_state`: State machine context for interactive Telegram bot sessions.
8. `guidance_articles`: Knowledge base articles and tour instructions.
9. `user_guidance_progress`: Tracking completed onboarding tours.
10. `media_conversions`: Queue and log of PDF-to-WebP image conversions.
11. `pdf_document_pages`: WebP page index for instantaneous book rendering.
12. `diagnostic_reports`: Client crash reports and unhandled exception logs.
13. `activity_logs`: User activity timeline.
14. `audit_logs`: Immutable security audit log tracking administrative modifications.
15. `settings`: Global application key-value configuration.
16. `sync_receipts`: Client-server sync reconciliation tokens.
17. `app_releases`: Mobile APK release repository (version code, hash, file path, min supported code).
18. `downloads`: User download tracking for books and offline packs.
19. `pages`: Static institutional information pages (About Us, History, Clergy).
20. `page_images`: Assets attached to static pages.
21. `advertisements`: Church announcement flyers and feast day banners.
22. `ad_attachments`: Graphics attached to advertisements.
23. `migrations`: Laravel migration registry.

---

## 3. COLUMN-LEVEL CRYPTOGRAPHY & PII PROTECTION
The database utilizes custom column-level encryption implemented in [`app/Mz/Crypto/EncryptedColumns.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Crypto/EncryptedColumns.php):
- **Encrypted Columns:**
  - `users.phone`
  - `member_profiles.first_name`, `last_name`, `christian_name`, `emergency_phone`, `national_id`
- **Algorithm:** AES-256-GCM with authenticated tags (`tag`) preventing tampering.
- **Blind Indexing:** For searchable fields (like phone numbers), an HMAC-SHA256 hash of the normalized string is stored in a dedicated `phone_bidx` column. This enables exact-match `WHERE phone_bidx = ?` queries without exposing plaintext phone numbers in database dumps or query logs.

