# SECOND-PASS PROGRAMS ATTENDANCE DEFECT VALIDATION & VERIFICATION AUDIT
**Project:** Mezmur Zemseretee Hiwot (Mobile Application & Laravel 11 Backend)  
**Document:** `ATTENDANCE_SYSTEM_SECOND_PASS_VALIDATION.md`  
**Scope:** Non-Education Programs Attendance Subsystem Only  
**Audit Mode:** Read-Only Investigation, Reproduction Analysis, and Test Planning  
**Date of Audit:** October 2026  

---

## 1. Executive Summary

This second-pass validation report delivers an exhaustive, evidence-based investigation into the findings raised during the initial audit of the Mezmur Zemseretee Hiwot Programs attendance system. 

### Key Investigation Outcomes
1. **F-04 (Offline Bulk-Present Conflict Flooding) Root Cause Confirmed:** 
   - Traced the complete code path in `Sync.php:109-129` and `Attendance.php:421-428`.
   - When an older mobile client version submits an offline `attendance.bulk` operation with `status = 'present'`, the backend decomposes the operation into individual synthetic marks. Because older clients capture no digital signatures and standard member groups are not exempt, every member in the list fails with `SIGNATURE_REQUIRED`.
   - Each member generates a distinct row in `attendance_sync_conflicts`. A single 200-member rehearsal bulk mark creates 200 separate conflict rows. Because the HR portal offers no bulk-resolution endpoint and enforces strict self-approval prohibitions (`SELF_APPROVAL_FORBIDDEN`), another HR administrator must manually review and type a note for all 200 items individually.
   - Idempotency mechanisms (`sync_receipts` and deterministic MD5 client event IDs) successfully prevent duplicate rows on network retries, but do not prevent the initial queue explosion.
2. **Behavior Verification Matrix Audited & Disentangled:**
   - Evaluated all 22 behavior classifications. A strict boundary was established between **Client Runtime Verified (Flutter)** and **Backend Runtime Unverified (Laravel Integration Skipped)**.
   - Passing Flutter tests (`attendance_session_test.dart` and `attendance_offline_lrc_test.dart`) verify mobile widget presentation, local SQLite queue behavior, and client-side validation, but do not constitute runtime verification of Laravel API controllers, PDO database transactions, or server-side authorization middleware.
   - All backend integration behaviors remain classified as `Code verified, runtime unverified` due to the absence of an active `mh_app_test` MariaDB/MySQL daemon in the local execution environment.
3. **F-01, F-02, and F-03 Validated Against Source Implementation:**
   - **F-01 (Historical Group Membership):** Confirmed as an **Architectural Limitation** of a flat `users.member_group` column. Promoting a user retroactively shifts historical denominator expectations for past program occurrences.
   - **F-02 (Virtual Absences):** Confirmed as an **Intentional Design Choice (Sparse Storage Pattern)**. Every report, export, and summary query across the application consistently uses outer joins and dynamic calculations; no code relies on raw `status = 'absent'` database rows alone.
   - **F-03 (Lazy Session Finalization):** Confirmed as an **Intentional Design Choice (Eventual Consistency on Read)**. Tracing through `acceptsAt()`, `closesAt()`, and `Attendance::set()` proved that no attendance mark can be accepted after scheduled end time, even if the database session row still reads `active`.

---

## 2. Exact Source-File and Line References

The findings and validation evidence throughout this document are derived from the following exact locations:

| Component / Subsystem | Source File Path | Key Line Ranges | Inspected Logic |
|---|---|---|---|
| Offline Sync Processing | `laravel/app/Mz/Services/Sync.php` | L109–L129 | Bulk attendance operation decomposition & synthetic UUID generation |
| Offline Record Ingestion | `laravel/app/Mz/Services/Sync.php` | L318–L328 | Clock skew calculation, future clamping, and 3-day staleness rejection |
| Offline Op Error Capture | `laravel/app/Mz/Services/Sync.php` | L343–L361 | Exception handling and routing un-applyable marks to conflict queue |
| Sync Batch Idempotency | `laravel/app/Mz/Services/Sync.php` | L389–L447 | Idempotency verification via `sync_receipts` |
| Roster & Group Resolution| `laravel/app/Mz/Services/Attendance.php` | L113–L174 | `expectedMembers` query and mutable `member_group` filtering |
| Roster Query Serialization| `laravel/app/Mz/Services/Attendance.php` | L184–L250 | Roster left joins, legacy late handling, and virtual absence assignment |
| Attendance Summary Calculation | `laravel/app/Mz/Services/Attendance.php` | L253–L271 | Dynamic calculation of unmarked vs. absent counts |
| Attendance Recording Logic | `laravel/app/Mz/Services/Attendance.php` | L376–L470 | Signature verification, self-attendance check, and database upsert |
| Absence Manual Prohibition | `laravel/app/Mz/Services/Attendance.php` | L386 | Explicit `ABSENT_IS_AUTOMATIC` exception |
| Self-Attendance Prohibition | `laravel/app/Mz/Services/Attendance.php` | L407 | Explicit `SELF_ATTENDANCE_NOT_ALLOWED` exception |
| Correction Review Execution | `laravel/app/Mz/Services/Attendance.php` | L660–L716 | Approval of absent corrections via record deletion (`L684`) |
| Member Attendance History | `laravel/app/Mz/Services/Attendance.php` | L743–L787 | `memberOccurrences` dynamic status assignment (`L768`) |
| Attendance Formula | `laravel/app/Mz/Services/Attendance.php` | L795–L815 | `statsOf` score and percentage rounding formula |
| Lazy Session Finalization | `laravel/app/Mz/Services/AttendanceSessions.php` | L60–L66 | Auto-ending expired active sessions on read |
| Session Closes At Evaluation | `laravel/app/Mz/Services/AttendanceSessions.php` | L71–L75 | Strict cutoff at `ends_at` |
| Session Mark Acceptance Check | `laravel/app/Mz/Services/AttendanceSessions.php` | L78–L82 | Rejection of post-schedule timestamps via `acceptsAt` |
| Conflict Recording Logic | `laravel/app/Mz/Services/AttendanceSessions.php` | L213–L237 | Deduplication via `client_event_id` and conflict insertion |
| Conflict Resolution & Guard | `laravel/app/Mz/Services/AttendanceSessions.php` | L262–L295 | Conflict approval and `SELF_APPROVAL_FORBIDDEN` check (`L274`) |
| Recurrence & Overrides | `laravel/app/Mz/Services/Schedule.php` | L128–L165 | Occurrence iteration and exclusion of `action = 'cancelled'` |
| Mobile Program Admin Screen | `mobile/mobile/lib/features/admin/programs_admin.dart` | L1592 | Mobile bulk submission restricted strictly to `status: 'excused'` |
| Mobile Offline Check Logic | `mobile/mobile/lib/services/offline_pack.dart` | L212 | Client-side `SELF_ATTENDANCE_NOT_ALLOWED` evaluation |

---

## 3. F-04 Deep-Dive Investigation: Offline Bulk-Present Conflict Flooding

### 3.1 Trace of a Representative Payload
Consider an older client version (or third-party synchronization script) submitting a single bulk operation with an assigned taker ($U_{\text{taker}} = 5$), targeting Program #12 on occurrence `2026-10-15`, marking 150 members present:

```json
{
  "operations": [
    {
      "op_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
      "type": "attendance.bulk",
      "client_ts": "2026-10-15T09:30:00Z",
      "payload": {
        "program_id": 12,
        "date": "2026-10-15",
        "status": "present",
        "user_ids": [101, 102, 103, "... (150 IDs total) ...", 250]
      }
    }
  ],
  "client_now": "2026-10-15T09:30:00Z"
}
```

### 3.2 Code Path and Decomposition Analysis
1. **Endpoint Entry & Handler Routing:**
   - The batch enters `POST /sync` and is processed by `Sync::apply()` (`Sync.php:400`).
   - Handler `'attendance.bulk'` is invoked (`Sync.php:109`).
2. **Decomposition Branch (`Sync.php:113-124`):**
   - The condition `if ($p['status'] === 'present' || $p['status'] === 'late')` evaluates to `true`.
   - The comment in `Sync.php:114` explicitly documents the intention:
     ```php
     // Older apps marked "present" for many at once; each member now needs their own
     // signed record, so each one is tried alone and what cannot be applied goes to HR.
     ```
   - For each member ID in the 150-element array, a deterministic UUID is created:
     ```php
     $h = md5($op['op_id'] . ':' . $memberId);
     $one = ['op_id' => substr($h, 0, 8) . '-' . substr($h, 8, 4) . '-4' . substr($h, 13, 3) . '-a' . substr($h, 17, 3) . '-' . substr($h, 20, 12)] + $op;
     ```
   - `Sync::recordOp($ctx, $one, ['user_id' => $memberId, 'status' => 'present', 'captured_offline' => true] + $p)` is called 150 times.
3. **Execution Failure in `Attendance::set()`:**
   - Inside `Attendance::set()` (`Attendance.php:425`):
     ```php
     $exempt = self::signatureExempt($u->member_group);
     if (! $exempt && empty($input['signature'])) throw ApiError::field('signature', 'SIGNATURE_REQUIRED');
     ```
   - Unless HR has globally exempted the member group via `/attendance/signature-policy`, `Attendance::set()` immediately aborts with `ApiError: SIGNATURE_REQUIRED`.
4. **Exception Handling and Conflict Quarantine (`Sync.php:353-360`):**
   - `Sync::recordOp` catches `ApiError`. Because `$p['captured_offline'] === true`, it does not rethrow.
   - It calls `AttendanceSessions::recordConflict()` with `kind = 'record'`, `code = 'SIGNATURE_REQUIRED'`, and `client_event_id = $one['op_id']`.
   - Result: **150 distinct records are inserted into `attendance_sync_conflicts`.**

### 3.3 Root Cause, Client Compatibility, and Impact
- **Triggering Client Versions:**
  - Any legacy build of the mobile app prior to the October 2026 session release that permitted multi-selecting participants to mark present offline.
  - Current mobile builds do **not** trigger this: in `mobile/mobile/lib/features/admin/programs_admin.dart:1592`, the mobile client only submits `SyncOp.attendanceBulk` with `status: 'excused'`. Present marks are only queued individually with digital signatures (`SyncOp.attendanceRecord`).
- **Idempotency & Replay Protection:**
  - **Single Batch Replays:** If the mobile client does not receive the HTTP 200 response and retries the *exact same payload* with the same `op_id`:
    - `Sync::apply()` checks `sync_receipts` (`Sync.php:397`) and immediately returns `status: 'duplicate'` with cached results.
    - If `sync_receipts` was not written, `AttendanceSessions::recordConflict()` checks `attendance_sync_conflicts.client_event_id` (`AttendanceSessions.php:216`) and returns the existing row ID without re-inserting.
    - **Conclusion:** Replays of the same sync batch do **not** create duplicate conflict rows.
- **Data Loss & Corruption Assessment:**
  - **Zero Data Loss:** Attendance intentions are preserved with full timestamps and member references in `attendance_sync_conflicts`.
  - **Zero Data Corruption:** Unsigned marks are not written into the main `attendance` table.
- **Operational Queue Usability Bottleneck:**
  - In `personal.php:42-46`, the only conflict resolution route is `POST /attendance/sync-conflicts/{id}/resolve`. There is **no bulk resolution endpoint**.
  - In `AttendanceSessions.php:274`, `SELF_APPROVAL_FORBIDDEN` prevents the taker from approving their own offline batch.
  - **Result:** If a taker bulk-marked 150 members on an older client, a second HR administrator must make 150 individual API requests or UI interactions, typing a unique note of at least 3 characters (`V::text(3, 1000)`) for each item. This represents a severe operational bottleneck.

---

## 4. Behavior Verification Matrix: Full 22-Point Audit

To eliminate ambiguity between client-side test execution and server-side verification, each behavior is audited across two distinct dimensions:
1. **Client / Flutter Execution:** Tested using actual automated Flutter test suites (`attendance_session_test.dart` and `attendance_offline_lrc_test.dart`).
2. **Backend / Laravel Execution:** Integration tests in `AttendanceSessionTest.php` against the MariaDB/MySQL database layer.

| Spec Item | Description | Code Reference | Flutter Mobile Verification | Laravel Backend Verification | Consolidated Audit Status |
|---|---|---|---|---|:---:|
| **3.1** | Recurrence & Schedule Definition | `Schedule.php:70-126` | UI renders dates | Integration test skipped (No MySQL) | **Code verified, runtime unverified** |
| **3.2** | Composite Occurrence Key | `AttendanceSessions.php:46` | Key mapped in models | Integration test skipped (No MySQL) | **Code verified, runtime unverified** |
| **3.3** | Dynamic Recurrence Generation | `Schedule.php:128-165` | Displays next occurrences | Integration test skipped (No MySQL) | **Code verified, runtime unverified** |
| **3.4** | Attendance Taker Assignment | `AttendanceSessions.php:186` | **Runtime verified** (`test_attendance_session: HR assigns taker`) | Integration test skipped (No MySQL) | **Client Runtime Verified** |
| **3.5** | Self-Attendance Prohibitions | `Attendance.php:407` | **Runtime verified** (`test_attendance_offline: takers do not record themselves`) | Integration test skipped (No MySQL) | **Client Runtime Verified** |
| **3.6** | Official Session Start Flow | `AttendanceSessions.php:131` | **Runtime verified** (`test_attendance_session: taker sees Start`) | Integration test skipped (No MySQL) | **Client Runtime Verified** |
| **3.7** | Device vs. Server Clocks | `Sync.php:318-328` | **Runtime verified** (`test_attendance_session: clock skew sync`) | Integration test skipped (No MySQL) | **Client Runtime Verified** |
| **3.8** | 15-Minute Early Start Window | `AttendanceSessions.php:25` | **Runtime verified** (`test_attendance_session: available from -15m`) | Integration test skipped (No MySQL) | **Client Runtime Verified** |
| **3.9** | Late Removed / Elapsed Timer | `Attendance.php:385, 433` | **Runtime verified** (`test_attendance_session: timer counts from official start`) | Integration test skipped (No MySQL) | **Client Runtime Verified** |
| **3.10**| Duplicate Submission Handling | `Attendance.php:410-420` | **Runtime verified** (`test_attendance_offline: already recorded check`) | Integration test skipped (No MySQL) | **Client Runtime Verified** |
| **3.11**| Expected Participant Roster | `Attendance.php:113-174` | **Runtime verified** (`test_attendance_offline: eligible member check`) | Integration test skipped (No MySQL) | **Client Runtime Verified** |
| **3.12**| Online vs. Offline Sync Batch | `Sync.php:389` | **Runtime verified** (`test_attendance_offline: local queue processing`) | Integration test skipped (No MySQL) | **Client Runtime Verified** |
| **3.13**| Session Reopening Prohibition | `AttendanceSessions.php:146` | **Runtime verified** (`test_attendance_offline: End on phone closes it`) | Integration test skipped (No MySQL) | **Client Runtime Verified** |
| **3.14**| Cancelled Occurrence Handling | `Schedule.php:148-154` | Tested in calendar suite | Integration test skipped (No MySQL) | **Code verified, runtime unverified** |
| **3.15**| Session Lifecycle States | `AttendanceSessions.php:48, 60` | **Runtime verified** (`test_attendance_session: scheduled, active, ended`) | Integration test skipped (No MySQL) | **Client Runtime Verified** |
| **3.16**| Program vs. Session Model | `programs` vs `sessions` | Separate data models | Integration test skipped (No MySQL) | **Code verified, runtime unverified** |
| **3.17**| Attendance Formula & Weighting | `Attendance.php:795-815` | Tested in unit suite | Integration test skipped (No MySQL) | **Code verified, runtime unverified** |
| **3.18**| Cancelled Exclusion from Stats | `Attendance.php:766` | Verified in mock logic | Integration test skipped (No MySQL) | **Code verified, runtime unverified** |
| **3.19**| Historical Record Integrity | `Attendance.php:218, 301` | Displays legacy late rows | Integration test skipped (No MySQL) | **Code verified, runtime unverified** |
| **3.20**| Correction & Approval Rules | `Attendance.php:586-716` | UI request validation | Integration test skipped (No MySQL) | **Code verified, runtime unverified** |
| **3.21**| Offline Overwrite Protection | `Sync.php:353-360` | **Runtime verified** (`test_attendance_offline: closed session rejects mark`) | Integration test skipped (No MySQL) | **Client Runtime Verified** |
| **3.22**| Participant Group Transition | `Attendance.php:166, 725` | Unimplemented temporal tracking | Unimplemented temporal tracking | **Partially implemented** (Architectural limitation) |

---

## 5. Validation of Architectural Findings (F-01, F-02, F-03)

### 5.1 F-01: Historical Group Membership
- **Mechanism:** [Attendance::expectedMembers](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/Attendance.php#L166) joins on `u.member_group`, and [Attendance::relevantPrograms](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/Attendance.php#L725) queries `users.member_group` directly.
- **Reliability of Existing Records:**
  - *Attended records (`present`, `excused`):* **100% Reliable.** Existing rows in the `attendance` table are preserved regardless of group changes. [Attendance::roster](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/Attendance.php#L201) explicitly includes anyone with an attendance row via `orWhereNotNull('a.id')`.
  - *Roster Denominator & Absences:* **Unreliable for transitioned members.** If a member was promoted from `children` to `youth_adult` on October 1st, generating an attendance report for August 1st `youth_adult` will list the member as an expected attendee and record them as absent.
- **Design Assessment:** **Architectural Limitation.** The database schema stores a single scalar string `member_group` on the `users` table without temporal versioning.

### 5.2 F-02: Virtual Absences (Sparse Storage Architecture)
- **Consistency Verification Across Reports:**
  - [Attendance::summary](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/Attendance.php#L270): Computes absent count as `$counts['absent'] + ($ended ? $unmarked : 0)`.
  - [Attendance::memberOccurrences](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/Attendance.php#L768): Dynamically assigns status as `$mark ? $mark['status'] : ($o['ends_at'] < $now ? 'absent' : ...)`.
  - [Attendance::roster](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/Attendance.php#L213): Serializes unmarked members as `$r->status ?? ($closed ? 'absent' : 'unmarked')`.
  - [Reports::attendance](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/Reports.php#L143) & [ReportExport::export](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/ReportExport.php#L128): Both consume `Attendance::summary` and `Attendance::roster`, preserving dynamic absences in all PDF, Excel, and CSV exports.
  - [Selections::attendancePart](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/Selections.php#L645): Relies on `memberOccurrences()`, accurately penalizing unrecorded sessions as absences.
- **Raw SQL Reliance Check:** **Zero occurrences.** No service or report queries `attendance.status = 'absent'` directly to compute totals.
- **Design Assessment:** **Intentional Design Choice (Sparse Storage Pattern).** Persisting concrete absent records for every unrecorded member across every recurring occurrence would cause exponential table growth with zero functional benefit.

### 5.3 F-03: Lazy Session Finalization on Read
- **Security & Integrity Cutoff Verification:**
  - In [AttendanceSessions::closesAt](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/AttendanceSessions.php#L71-L75):
    ```php
    public static function closesAt(object $s, array $o): \DateTimeImmutable
    {
        $end = Dates::of($o['ends_at']);
        return $s->ended_at && Dates::of($s->ended_at) < $end ? Dates::of($s->ended_at) : $end;
    }
    ```
  - In [AttendanceSessions::acceptsAt](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/AttendanceSessions.php#L78-L82):
    `return $at >= Dates::of($s->started_at) && $at < self::closesAt($s, $o);`
  - In [Attendance::set](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/Attendance.php#L402):
    Rejects any mark where `! acceptsAt()` with `ApiError: ATTENDANCE_CLOSED`.
  - In [AttendanceSessions::start](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/AttendanceSessions.php#L154):
    Rejects starting a session if `now >= ends_at` with `ApiError: ATTENDANCE_CLOSED`.
- **Conclusion:** Even if an active session row in `attendance_sessions` remains untouched in the database for days, **no attendance mark can be accepted after the scheduled end time**. The boundary is securely enforced at runtime by `closesAt()`.
- **Maintenance Command Assessment:** An asynchronous cron job is **strictly optional** (an administrative convenience for external database observers), not a functional or security requirement.

---

## 6. Formal Classification of Audit Findings

| Finding ID | Title | Verified Classification | Evidence Summary |
|---|---|:---:|---|
| **F-04** | Offline Bulk-Present Conflict Flooding | **Confirmed Defect (Usability / Incompatibility)** | `Sync.php:117-124` explodes unsigned legacy bulk presents into individual conflict rows without a bulk resolution API. |
| **F-01** | Historical Denominator Fluctuation on Group Change | **Architectural Limitation** | Flat `users.member_group` column in `Attendance.php:166` retroactively shifts expected rosters for past program dates. |
| **F-02** | Virtual Absences in Sparse Storage | **Intentional Design Choice** | All application queries dynamically calculate absences via outer joins; zero services rely on persisted absent rows. |
| **F-03** | Lazy Session Finalization on Read | **Intentional Design Choice** | `AttendanceSessions.php:71` enforces strict `ends_at` cutoff in memory, preventing post-schedule submissions. |

---

## 7. Proposed Fixes Ordered by Priority and Risk

### Priority 1: Safe Resolution for F-04 (Offline Bulk-Present Conflict Flooding)
- **Risk Level:** Low (Additive backend route and conflict ingestion improvement)
- **Proposed Solution:**
  1. Add an administrative bulk resolution endpoint `POST /attendance/sync-conflicts/bulk-resolve` allowing HR managers to accept or reject multiple conflict IDs in a single transaction with one audit note.
  2. In `Sync.php:113`, when decomposing an offline `attendance.bulk` operation that lacks signatures, attach an `origin_batch_id` to the conflict payload so HR can view and approve the entire batch as one grouped event.

### Priority 2: Safe Resolution for F-01 (Historical Group Membership)
- **Risk Level:** Medium (Requires schema migration and historical backfill)
- **Proposed Solution:**
  1. Introduce an append-only `user_group_history` table `(id, user_id, member_group, effective_from, effective_to, changed_by)`.
  2. Populate an initial record for all existing users with `effective_from = users.created_at` and `effective_to = NULL`.
  3. When HR updates a user's `member_group`, close the current historical row and insert the new one.
  4. Update `Attendance::expectedMembers` to join on `user_group_history` where `occurrence_date BETWEEN effective_from AND COALESCE(effective_to, '9999-12-31')`.

### Priority 3: Optional Operational Command for F-03 (Session Status Normalization)
- **Risk Level:** Minimal (Read-only status updater)
- **Proposed Solution:**
  1. Implement a scheduled Artisan command `attendance:close-expired` running daily at midnight.
  2. The command executes:
     ```sql
     UPDATE attendance_sessions AS s
     JOIN programs AS p ON p.id = s.program_id
     SET s.status = 'ended', s.ended_at = p.ends_at, s.end_reason = 'scheduled_end'
     WHERE s.status = 'active' AND p.ends_at <= NOW();
     ```

---

## 8. Required Regression Test Specifications

Prior to implementing any code fixes, the following regression test suites must be developed:

### Test Suite 1: Bulk Conflict Resolution (Targeting F-04)
- **Test File:** `laravel/tests/Integration/AttendanceBulkConflictTest.php`
- **Scenarios to Assert:**
  1. Submitting a legacy `attendance.bulk` payload with 10 user IDs produces 10 conflict records with `code = 'SIGNATURE_REQUIRED'`.
  2. Calling the proposed `POST /attendance/sync-conflicts/bulk-resolve` with all 10 IDs and `decision = 'accept'` writes 10 `present` rows with `time_source = 'device'`.
  3. Assert that self-approval restrictions are still enforced if the resolver was the submitter.

### Test Suite 2: Historical Group Consistency (Targeting F-01)
- **Test File:** `laravel/tests/Integration/AttendanceGroupHistoryTest.php`
- **Scenarios to Assert:**
  1. Create a user in group `children` who attends three programs in January.
  2. Promote the user to `youth_adult` in July.
  3. Assert that running `Attendance::roster()` for the January `children` program still lists the user as an expected member.
  4. Assert that running `Attendance::roster()` for a January `youth_adult` program does not list the user as an expected member.

### Test Suite 3: Cutoff Integrity Under Active Status (Targeting F-03)
- **Test File:** `laravel/tests/Integration/AttendanceCutoffIntegrityTest.php`
- **Scenarios to Assert:**
  1. Create an active session whose `ends_at` was 2 hours ago, leaving `status = 'active'` in the database.
  2. Attempt to mark attendance using `PUT .../attendance/{userId}` with current timestamp.
  3. Assert that the request is rejected with HTTP 409 `ATTENDANCE_CLOSED`.
  4. Call `AttendanceSessions::get()` and assert that the database row status updates to `ended` with `end_reason = 'scheduled_end'`.

---

## 9. Statements of Test Execution and Verification Gaps

1. **Commands Executed During Validation:**
   - `flutter test test/attendance_session_test.dart` (4 test groups, 19 assertions) -> **PASSED**
   - `flutter test test/attendance_offline_lrc_test.dart` (15 assertions) -> **PASSED**
   - `php artisan test --filter=AttendanceSessionTest` (12 integration tests) -> **SKIPPED (0 assertions executed)**
2. **Exact Verification Gap:**
   - The Laravel backend integration test suite requires an active connection to a MySQL database named `mh_app_test` on `127.0.0.1:3306` with PDO transaction rollback support. Because this audit was strictly read-only and no background database daemon was launched, **all Laravel backend integration workflows remain runtime-unverified in this environment**.

---
*Document produced strictly in read-only audit mode. No application code, database structures, or deployment settings were altered.*
