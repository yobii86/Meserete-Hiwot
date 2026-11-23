# RISK, COMPATIBILITY & REGRESSION ANALYSIS REPORT
**Project:** Mezmur Zemseretee Hiwot (`MH-app-1.5.3`)  
**Phase:** Investigation & Technical Design Deliverable 5  
**Document Status:** Complete Risk Assessment & Backward Compatibility Architecture  
**Scope:** API Versioning, Legacy Clients, Database Integrity, RBAC Access, Concurrency, and Rollback Protocols

---

## 1. Executive Summary

This report evaluates technical, operational, and data integrity risks associated with the proposed architectural improvements. The Mezmur Zemseretee Hiwot platform currently has active students, teachers, choir members, and administrators interacting with live databases and mobile devices. 

Our core architectural directive requires:
1. **Zero destructive migrations:** Never drop tables or delete historic records.
2. **Absolute backward compatibility:** Existing deployed mobile builds (versions 1.5.0–1.5.2) must continue functioning without breaking contract changes.
3. **Fail-safe permissions:** Strict curriculum controls must never lock out authorized teachers, administrators, transferred students, or unenrolled learners.
4. **Resilient background processing:** FFmpeg media conversions and attendance offline synchronizations must not exhaust server memory or CPU resources.

---

## 2. Comprehensive Risk Assessment Matrix

| Risk ID | Risk Description | Severity | Probability | Impact Area | Primary Mitigation Strategy |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **RSK-01** | **API Contract Breakdown on Older Mobile Clients:** Renaming or restructuring payloads breaks v1.5.0–1.5.2 app builds. | **HIGH** | Medium | Mobile App / Student Experience | Payload normalization (return dual keys `id` & `assessment_id`), additive-only schema evolution. |
| **RSK-02** | **Over-Restricted Curriculum Gate:** Strict `canOpen` checks accidentally block teachers, admins, or choir students from accessing materials. | **HIGH** | Medium | Curriculum Access / Education | Multi-tier RBAC override in `canOpen` giving unconditional access to administrators and assigned instructors. |
| **RSK-03** | **Student Quiz History Loss (Question Bank Deprecation):** Deprecating question banks corrupts previous test scores or attempt logs. | **CRITICAL**| Low | Student Records / Grading | Zero database drops. Preserve `edu_question_banks` rows. Direct quiz attempts decouple from banks entirely. |
| **RSK-04** | **Cache Stampede on Dashboard Invalidation:** Evicting dashboard cache during school hours causes massive simultaneous DB query spikes. | **MEDIUM** | Medium | Server Database / Redis | Probabilistic early expiration or Redis mutex locking (`Cache::lock`) during cache recomputation. |
| **RSK-05** | **Offline Attendance Record Conflicts:** Teacher takes attendance offline while admin marks attendance online, creating conflicting marks. | **HIGH** | Medium | Attendance Ledger / Signatures | Deterministic "Server-Timestamp-Wins" conflict resolution with audit logging in `attendance_sync_conflicts`. |
| **RSK-06** | **Server CPU Exhaustion during FFmpeg Transcoding:** Spawning multiple concurrent FFmpeg processes locks up server audio playback. | **HIGH** | Low | System Availability / Media | Queue worker pinned to `--concurrency=1` and dedicated per-file process timeout (180s) with micro-batching fallback. |
| **RSK-07** | **Unenrolled Student Frustration:** Students with no active class record receive a dead-end blank screen. | **MEDIUM** | High | User Experience | Friendly orientation UI with clear Sunday school contact details and open access to public spiritual publications. |

---

## 3. Deep Risk Analysis & Detailed Mitigations

### 3.1 API Backward Compatibility & Legacy Client Support

#### The Threat
Older mobile app builds (v1.5.0 through v1.5.2) are currently deployed on user devices across various Android and iOS versions. If the backend changes payload structures (e.g., removing legacy fields, strictly changing `assessment_id` to `id`, or nesting dashboard fields), un-updated devices will crash with deserialization errors.

#### Architectural Safeguards
1. **Dual-Key Response Normalization:**
   In `routes/api/edu_learning.php` and `EduQuizzesController`:
   ```php
   // Legacy clients expect 'assessment_id', modern clients expect 'id'
   return response()->json([
       'id' => $assessment->id,
       'assessment_id' => $assessment->id, // Preserved for legacy clients
       'title' => $assessment->title,
       'status' => $assessment->status,
       'created_at' => $assessment->created_at->toIso8601String(),
   ]);
   ```
2. **Additive-Only Schema Changes:**
   New fields (such as `context_type`, `supervisor_signature_path`, `explainability_tag`) are added with default values or marked nullable. No existing columns are renamed or dropped in production migrations.
3. **API Route Deprecation Grace Period:**
   Endpoints marked for deprecation (such as the 7 Question Bank endpoints) return HTTP 200 with empty mock collections or HTTP 410 Gone with explicit localized error messages, rather than throwing unhandled 404/500 exceptions.

---

### 3.2 Curriculum Scoping & Access Control Safety

#### The Threat
Enforcing strict class curriculum access could inadvertently lock out legitimate users in non-standard situations:
- Students who transferred mid-year between classes.
- Students enrolled in multiple classes (e.g., regular Sunday school class + liturgical choir class).
- Volunteer teachers who are also enrolled as students in higher spiritual courses.
- Students without active class enrollments (newly registered or pending admin assignment).

#### Architectural Safeguards
1. **Role-Aware Evaluation Hierarchy:**
   The `EduLearning::canOpen()` authorization gate evaluates permissions in a strict hierarchical order:
   ```
   [1. Super Admin / Education Director] ➔ Always Allow (Global read/write)
   [2. Course Assigned Teacher]           ➔ Allow for assigned course & subject
   [3. Student Active Enrollment]        ➔ Allow if class_subjects contains subject
   [4. Historical Completed Student]     ➔ Read-only access to previous year materials
   [5. Public Content]                   ➔ Allow if subject has is_public = true
   [6. Unenrolled Student]               ➔ Block grade subjects; redirect to orientation
   ```
2. **The Unenrolled User Experience:**
   Rather than presenting a forbidden error (`403 FORBIDDEN`), the Flutter app intercepts unenrolled status and renders a welcoming orientation screen:
   `"እንኳን ደህና መጡ! በ2017 ዓ.ም. የትምህርት ዘመን እስካሁን ክፍል አልተመደበልዎትም። እባክዎ አስተዳዳሪውን ያነጋግሩ።"`
   Students retain full access to public hymns, daily readings (Synaxarium), and Seleda magazine.

---

### 3.3 Question Bank Deprecation & Score Integrity

#### The Threat
A critical concern during the investigation was ensuring that deprecating the Question Bank feature would not delete or corrupt historical exam results, student grades, or active course quizzes.

#### Forensic Verification & Evidence
* Direct course quizzes and closing exams link questions using `edu_quiz_questions.quiz_id`.
* The question bank feature utilized a separate mechanism: `edu_question_banks` -> `edu_quiz_draws` -> `edu_quiz_questions.bank_id`.
* When a student takes an exam, their answers and marks are stored in `edu_quiz_attempts` and `edu_quiz_answers`. During attempt initiation, the question text and options are snapshot into the attempt record.

#### Safe Deprecation Guarantees
1. **Table Preservation:** The tables `edu_question_banks` and `edu_quiz_draws` will **NOT** be dropped. They will remain intact in the database in read-only status.
2. **Quiz Execution Isolation:** In `EduQuizzes::start()`, the logic simply bypasses the draw engine and directly loads all active questions matching `quiz_id = :quizId`.
3. **Audit Trail Immutability:** Historical student certificates, pass marks, and GPA rankings will suffer zero disruption.

---

### 3.4 Concurrency, Caching & Resource Protection

#### The Threat
1. **Cache Stampede (Dog-Piling):** If the education dashboard cache expires during Sunday morning peak usage (when hundreds of students log in simultaneously), hundreds of database queries could execute at once, degrading database responsiveness.
2. **FFmpeg Resource Monopolization:** Transcoding high-bitrate WAV/MP3 files to AAC utilizes intensive CPU instructions. If multiple transcode jobs run simultaneously, server response times for general API requests could degrade.

#### Architectural Safeguards
1. **Redis Mutex Locking on Dashboard Cache:**
   ```php
   // In EduDashboard::forUser
   $cacheKey = "edu:user:{$userId}:dashboard:v1";
   return Cache::remember($cacheKey, 900, function () use ($userId, $cacheKey) {
       // Acquire 5-second atomic lock to prevent dog-piling
       return Cache::lock("lock:{$cacheKey}", 5)->get(function () use ($userId) {
           return self::computeDashboardPayload($userId);
       });
   });
   ```
2. **Strict Queue Concurrency for FFmpeg:**
   The background queue worker dedicated to media migration runs with `--concurrency=1`:
   ```bash
   php artisan queue:work --queue=media-migration --concurrency=1 --timeout=180
   ```
   This guarantees that only one audio transcoding process executes at any given instant, keeping CPU usage predictable (< 25% of server capacity) and leaving plenty of headroom for API requests.

---

### 3.5 Offline Attendance Synchronization & Conflict Resolution

#### The Threat
In church compounds or remote parishes with intermittent connectivity, attendance records might be marked on multiple devices simultaneously, or synced hours after a session ends.

#### Conflict Resolution Protocol
1. **Idempotent Session Identification:**
   Sessions are identified deterministically by the composite key: `(program_id, schedule_id, session_date)`. Multiple clients synchronizing attendance for the same session resolve to the exact same `attendance_session_id`.
2. **Server-Timestamp-Wins Policy:**
   When an offline batch arrives from a mobile device:
   ```php
   // In Attendance::syncOfflineRecord
   $existing = DB::table('attendance_records')
       ->where('session_id', $sessionId)
       ->where('member_id', $record['member_id'])
       ->first();

   if ($existing) {
       if (Carbon::parse($record['client_recorded_at'])->gt(Carbon::parse($existing->updated_at))) {
           // Client update is newer; apply update and log conflict
           self::updateRecordWithAudit($existing->id, $record, 'OFFLINE_SYNC_OVERWRITE');
       } else {
           // Server record is newer; discard client change and record audit
           self::logConflict($sessionId, $record['member_id'], 'SERVER_RECORD_PRESERVED');
       }
   } else {
       // Clean insert
       self::insertRecord($sessionId, $record);
   }
   ```
3. **Audit Trail Preservation:**
   Every conflict or manual edit creates an immutable entry in `attendance_audit_logs`, tracking the user ID, device UUID, previous status, new status, and timestamp.

---

## 4. Rollback Protocols & Disaster Recovery

Every implementation phase includes an isolated rollback procedure to ensure business continuity in the event of unforeseen regressions.

```
PHASE ROLLBACK CONTINGENCY MAP
═════════════════════════════════════════════════════════════════════════
Phase 1: Bug Fixes        ➔ Revert specific controller lines; no DB impact.
Phase 2: Performance     ➔ Disable Cache::remember via CACHE_DRIVER=array.
Phase 3: Quiz Builder    ➔ Reactivate legacy dialog via FeatureFlag.
Phase 4: Attendance Hub  ➔ Fallback to standalone attendance screens.
Phase 5: Media Queue     ➔ Switch back to micro-batching synchronous mode.
═════════════════════════════════════════════════════════════════════════
```

### 4.1 Phase-Specific Rollback Procedures

#### Phase 1 Rollback (Bug Fixes)
- **Trigger:** Regression in quiz creation or calendar loading.
- **Procedure:** Revert the Git commit for `quizzes_admin.dart` and `routes/api/edu_learning.php`. Because payload normalization is purely additive, reverting does not require any database rollback.

#### Phase 2 Rollback (Performance & Curriculum Access)
- **Trigger:** False-positive 403 errors reported by students or cache staleness issues.
- **Fast Kill-Switch:** Set environment variable `EDU_STRICT_CURRICULUM_GATE=false` and `CACHE_EDU_DASHBOARD=false`.
- **Code Action:** `EduLearning::canOpen()` immediately falls back to the legacy `visibility === 'members'` check, restoring wide access while the rule definition is tuned.

#### Phase 3 Rollback (Unified Quiz Builder)
- **Trigger:** Unexpected validation error preventing publication of magazine quizzes.
- **Fast Kill-Switch:** Feature flag in Flutter app `AppFeatures.useUnifiedQuizEditor = false`.
- **Code Action:** Automatically re-routes magazine quiz editing back to the legacy `EduMagazineQuizEditorDialog` in `magazine_admin.dart`.

#### Phase 4 Rollback (Admin Attendance Hub)
- **Trigger:** Mobile camera scanner fails on specific older Android camera hardware.
- **Code Action:** The user simply taps the `"📝 በእጅ መዝግብ (Manual Roster)"` tab within the same screen. The standalone legacy `AttendanceManagementScreen` remains accessible via the secondary menu.

#### Phase 5 Rollback (Media Migration Queue)
- **Trigger:** Background queue worker daemon crashes or Redis becomes unavailable.
- **Fast Kill-Switch:** The mobile client detects queue unavailable and automatically appends `?sync=true&limit=1` to migration requests, falling back to the 1-by-1 synchronous micro-batch mode.

---

## 5. Compatibility Verification Sign-Off Checklist

Before any phase is marked as production-ready, the following compatibility checkpoints must be formally verified:

- [ ] **Dual-Key Payload Check:** All assessment creation endpoints return both `id` and `assessment_id`.
- [ ] **Legacy App Smoke Test:** Test APK of app v1.5.0 successfully loads Education Home, displays subjects, and fetches quizzes against the updated backend.
- [ ] **Curriculum Role Check:** Verify that Super Admins and Teachers can inspect courses across all grades (1–12) while Grade 7 students are strictly restricted to Grade 7.
- [ ] **Historical Quiz Records:** Validate that previously completed student quizzes, grades, and answers from 2016 E.C. remain completely intact.
- [ ] **Signature File Security:** Verify that signature PNG files cannot be accessed via public web URLs without an authenticated session having `manage_attendance` permission.
- [ ] **FFmpeg Resource Ceiling:** Profile server during an audio migration batch to confirm CPU utilization stays below 30% and API requests maintain < 150ms latency.
- [ ] **Offline Sync Ledger:** Simulate 20 offline attendance marks in airplane mode, reconnect, and confirm 100% synchronization into `attendance_records` without duplicate primary key collisions.

---

## 6. Deliverable Completion Notice

All 5 core engineering deliverables for this investigation and technical design phase have now been compiled and permanently committed to `project-docs/deliverables/`:

1. [Current_System_Investigation.md](file:///c:/Users/HP/Documents/MH-app-1.5.3/project-docs/deliverables/Current_System_Investigation.md)  
   *Comprehensive forensic audit of existing code, root causes, line numbers, and schemas.*
2. [Proposed_UI_UX_Architecture.md](file:///c:/Users/HP/Documents/MH-app-1.5.3/project-docs/deliverables/Proposed_UI_UX_Architecture.md)  
   *Complete UI/UX design specifications, wireframes, component breakdowns, and loading state designs.*
3. [Proposed_Functional_Architecture.md](file:///c:/Users/HP/Documents/MH-app-1.5.3/project-docs/deliverables/Proposed_Functional_Architecture.md)  
   *Deep functional specifications, caching tiers, 8-step recommendation algorithm, security model, and async queues.*
4. [Implementation_Roadmap.md](file:///c:/Users/HP/Documents/MH-app-1.5.3/project-docs/deliverables/Implementation_Roadmap.md)  
   *5-phase sequential execution roadmap, work package specifications, and test matrices.*
5. [Risk_and_Compatibility_Report.md](file:///c:/Users/HP/Documents/MH-app-1.5.3/project-docs/deliverables/Risk_and_Compatibility_Report.md)  
   *Risk assessment matrix, backward compatibility safeguards, offline sync conflict rules, and rollback procedures.*
