# Mezmur Zemseretee Hiwot --- Existing Education Module Inspection Specification

**Purpose:** Inspect the existing Education module thoroughly before any
implementation or redesign.\
**Mode:** READ-ONLY AUDIT. Do not modify code, database, configuration,
data, routes, or production.\
**Expected result:** A detailed Markdown inspection report grounded in
the actual repository and current database/migrations where available.

## 1. Mission and rules

Inspect the existing Education module end to end, determine what
genuinely works, what is incomplete, what is broken, what is duplicated,
and what is missing against this specification.

### Mandatory rules

1.  Inspect the current repository and current implementation first. Do
    not assume old reports, mockups, previous builds, or this
    specification accurately describe the current code.
2.  **Do not implement, refactor, redesign, migrate, delete, seed,
    deploy, or change configuration.** This task is inspection and
    reporting only.
3.  Do not infer that a feature works because a screen, route, model,
    button, API endpoint, or test exists. Trace the user action through
    UI → API/service → authorization → database → response/UI, and run
    safe tests where possible.
4.  Do not claim a test passed unless it was actually run and the result
    was observed. Clearly label tests not run and explain why.
5.  Preserve the existing app's architecture and naming in the report.
    Do not assume a particular language/framework until verified.
6.  Separate findings into **Verified working**, **Partially working**,
    **Broken**, **Missing**, **Not verified**, and **Risk**.
7.  Identify the exact evidence for each important finding: file path,
    class/function/method, route/API endpoint, migration/table/column,
    test name, and relevant line numbers when available.
8.  Do not expose secrets. Redact credentials, tokens, private keys,
    database passwords, and personal data from logs and report examples.
9.  Do not run destructive commands or tests against production. Do not
    change production data. If environment access is uncertain, inspect
    statically and mark runtime verification as not performed.
10. If the project is too large to inspect fully in one pass, report
    coverage and remaining areas honestly. Do not claim a complete audit
    when any major area was skipped.
11. Avoid duplicate features and parallel sources of truth. Identify
    legacy/newer implementations that overlap and establish which one is
    actually used by current routes and screens.
12. No implementation prompt or code changes should be produced as part
    of this inspection report.

## 2. Product context and scope

The app is **Mezmur Zemseretee Hiwot**, a church and Sunday-school app.
The Education module is for structured Sunday-school education, not a
general-purpose education platform and not a mezmur-study module.

The intended Education system supports: - Grades 1--12 and the church's
actual curriculum. - Ethiopian-calendar academic years and configurable
terms. - Classes/sections, student enrollment, teachers and assignments
of teachers to classes. - Curriculum hierarchy: subjects → units →
lessons → learning materials. - Student lessons, assignments, quizzes,
assessments, marks, feedback, report cards, progression, transfers and
historical records. - The existing shared church attendance system,
without creating a competing attendance database. - Offline access and
safe synchronization wherever feasible. - Role-based access, approvals,
notifications, audit logs and reports. - Education settings separated
from unrelated Mezmur settings. - Integration with existing Library and
monthly **ሰሌዳ መጽሄት (Saleda magazine)** capabilities without duplicating
those systems.

Existing UI palette reference, if relevant to current implementation:
burgundy `#650D20`, cream `#FFF8E9`, gold `#C6A044`, white `#FFFFFF`.
This is reference context, not a request to change the UI during this
audit.

A curriculum source file was previously supplied:
`ሥርዓተ ትምህርት በክፍል(2).docx`. It must be treated as the source to validate
against, not as proof that the curriculum is already imported correctly.
Identify whether it is present in the repository or available workspace;
do not invent missing grade/subject/lesson content.

## 3. Required repository and environment inventory

Document: - Repository root and current branch/commit if available. -
Main application architecture and languages/frameworks actually found. -
Education-related folders, screens, components, state management,
models, repositories, services, APIs, controllers, policies, jobs,
migrations, tests and documentation. - Current app version/build
identifiers where discoverable. - Education entry points and navigation,
including whether Education has its own bottom navigation and whether
global navigation remains separate. - Runtime environments available:
local, staging, test database, device/emulator, production. Do not
connect to or modify production unless explicitly authorized; this audit
does not authorize deployment. - Commands actually used and their
outcomes. - Areas not accessible and resulting limitations.

Provide a short architecture map and list the main Education-related
files with one-line responsibilities.

## 4. Role and permission audit

Inspect actual authorization enforcement in both UI and backend/API.
Hiding a button is not sufficient.

Expected roles and boundaries: - **Student:** access own enrollment,
available lessons/materials, assignments, permitted quizzes, released
results, own academic progress and report cards, and appropriate
attendance summaries. - **Teacher:** access only assigned classes and
their authorized students; attach materials to existing lessons;
create/assign and grade permitted assessments; provide feedback; request
broader materials access when needed. - **Education Administrator:**
manage Education-only classes, curriculum records, academic years/terms,
enrollment, teacher assignment, assessments, releases, reports and
progression. This role must not automatically gain Library
administration or full app-wide administration. - **Higher-level
administrator:** retains the app's existing higher-level
approval/oversight responsibilities where required. - **Library staff /
Saleda publisher:** their separate domain permissions must not be
accidentally granted by Education roles.

Verify: - Student self-registration is a request requiring administrator
approval, and administrators can enable/disable self-registration. -
Admin registration and enrollment of existing app accounts. - Teacher
assignment and class/student scoping. - Broader teacher materials access
request and approval workflow. - Lesson publication approval by
Education Administrator. - Only Education Administrators can alter
curriculum hierarchy/order. - Promotion, repetition, transfer and
completion require manual administrator approval. - Teachers cannot
create curriculum lessons; they can attach materials to existing
lessons. - Students cannot see another student's records, unreleased
marks, private personal data or unauthorized class records. -
API/server-side checks cover direct requests, changed identifiers, deep
links, offline queues and alternate routes. - Permission checks remain
effective offline and after synchronization. - Deactivation preserves
records and appropriately restricts access. - Existing account/session
policy is identified and retained unless a verified defect is found.

For each role, produce a permissions matrix with **Allowed / Denied /
Conditional / Not verified** and cite evidence. Include any privilege
escalation or insecure direct object reference risks.

## 5. Academic year, terms, classes and enrollment

Inspect data model, validation, UI, APIs and reports for: - Grades
1--12. - Classes/sections such as Grade 4A and Grade 4B. - Member
groups: children, youth, married, distance learners. -
Admin-configurable Ethiopian-calendar academic years and terms,
including configurable number, names and dates of terms. - One active
grade/section enrollment per student per academic year, with additional
subject/course enrollment only when needed. - Self-registration request
and approval; administrator registration; enrollment of existing member
accounts. - Teacher assignment to classes and access limited to assigned
classes. - Transfer initiated by teacher or administrator and approved
by administrator. - Transfer history preserving old enrollment, marks
and records; new enrollment recorded separately. - Promotion, repetition
and completion decisions with administrator approval. - Academic-year
rollover through administrator-created year and manual opening of
classes/enrollment. - Deactivation without deleting historical
records. - Date/time and calendar handling, including Ethiopian calendar
display and unambiguous storage/ordering of dates.

Identify orphaned, duplicated, inconsistent or incomplete academic
records. Report counts only from an actual safe query or clearly label
them as migration/source-code estimates. Do not expose student names or
personally identifying data in the report.

## 6. Curriculum and lesson structure

Inspect the real curriculum structure and compare it to the supplied
curriculum source if accessible.

Expected hierarchy: **Grade → subject → unit → lesson → learning
materials.**

Check: - Whether grade/subject/unit/lesson records are linked correctly
rather than existing as disconnected lists. - Curriculum mapping to
grades 1--12 and the actual source document. - Lesson ordering and
whether only Education Administrators can change it. - Curriculum
versioning and whether historical records retain references to the
version used at the time. - Missing grades, subjects, units, lessons,
order numbers, references or materials. - Duplicate titles, duplicate
records and language/Amharic text integrity. - Whether a lesson can be
published only after Education Administrator approval. - Whether
students can access only content appropriate to their enrollment and
permissions. - Whether the student's prior-year lessons/reports remain
available read-only. - Whether lesson completion is recorded only after
a meaningful completion action, not simply on opening a lesson. -
Whether no separate lesson-progress analytics system has been introduced
contrary to scope.

Do not fill gaps with generic curriculum. List gaps requiring review
against the source DOCX.

## 7. Lesson content and materials

Inspect support for: - Text, PDF, images and audio. - Video through
supported external links only; do not assume external playback can be
tracked. - Multiple materials within a lesson, including
required/optional designation if implemented. - All enrolled students
being able to download all permitted materials for their grade. -
Teachers attaching materials only to existing lessons and only within
their authorization. - Admin-configurable upload size and allowed
formats. - Server-side MIME/content validation, invalid-file rejection,
filename safety, storage location, authorization on download, and
protection against path traversal or executable uploads. -
Preview/download behavior for large files. - Material
replacement/version history and the effect on existing student access. -
Offline caching of available lesson content where technically
feasible. - Sync behavior and stale content handling.

For each content type, verify the actual completion method and identify
limitations: - Text: a deliberate completion action is recommended over
assuming that scrolling to the bottom proves learning. - PDF/images:
completion confirmation or verified viewer completion; do not infer
completion merely from opening. - Audio: playback-end detection where
reliable, with a confirmation fallback. - External video: verified
playback completion only if genuinely supported; otherwise student
confirmation. - Multi-material lesson: completion after all materials
designated as required are complete. - Sequential access: report whether
it is currently enforced. Recommended default is **no hard gate**, with
optional administrator-configurable sequential completion if
pedagogically required.

## 8. Assignments and submission history

Trace complete flows for teacher creation, student access, offline
drafting, submission, return for correction, resubmission and grading.

Expected behavior: - Teacher targets whole class, selected students or
selected groups. - Student submits text and/or files. - Teacher can
return work for correction. - Prior submissions are preserved as
versions; a new submission must not silently overwrite history. -
Deadlines, configurable grace periods and teacher-approved late
exceptions. - Offline work is saved and clearly records synchronization
time for teacher review against deadlines. - Missing work remains
incomplete until marked or resolved by an authorized person. -
Notifications for assignments, approaching deadlines and returned
work. - Teacher access limited to assigned classes/students. - File
validation and upload permissions match section 7. - Duplicate
submissions and repeated synchronization do not create duplicate
records. - Status transitions and audit history are consistent across
UI/API/database.

Test and report the "assignment saved but UI says error" and similar
inconsistent outcomes if present. Identify the root cause only when
evidence supports it.

## 9. Quizzes, examinations, grading and result release

Inspect every assessment type and its end-to-end workflow: - Quiz,
midterm, final, assignment, project and classwork. - Marks out of 100. -
Objective quiz questions auto-scored; written quiz answers and
examinations manually graded. - Authorized configuration of assessment
types and weights; weights must total 100%. - Passing marks configurable
overall and optionally by grade/subject. - Retake eligibility/limits
configured by authorized staff; teachers schedule approved retakes. -
Highest retake attempt mark counts while all attempts remain
preserved. - Per-quiz optional timer and configurable attempt limit. -
Missing work remains incomplete until authorized resolution. - Quiz
results and objective scores hidden until authorized release. - Feedback
becomes visible when saved even if marks have not been released. -
Student sees marks only after authorized teacher/admin release. -
Released marks can be corrected only through an authorized reopen →
correct → re-release workflow. - Report card includes subject marks,
totals/averages, pass status, attendance summary, teacher comments and
promotion decision. - Report cards are Amharic only. - Promotion
eligibility follows configured mark/required-subject criteria;
administrator makes final decision. - Attendance is reported but does
not affect marks or promotion eligibility. - Offline quizzes require
internet to start and submit. - Audit trail records grading, changes,
reopen/release actions and the responsible authorized user.

Pay particular attention to the known historical issue where quiz
creation displayed "Something is wrong." Trace the current error path
from UI to API, validation, server logs if safely available, and
database transaction. Do not assume the old issue still exists; verify
current status.

Create a workflow table showing each assessment path and status
transitions. Inspect security around answer keys, correct answers,
unpublished marks, retake manipulation, timer enforcement, duplicate
submission and unauthorized result release.

## 10. Attendance integration

The app has a shared church attendance system. Do not create a competing
attendance database.

Inspect: - Existing attendance sources of truth and relationships to
member/class/program. - Education attendance summaries and reports. -
`edu_attendance` data/API/offline-sync/service-scoring references, if
still present. - Whether attendance entry points have been removed from
Education UI while required data/API/sync/reporting remain intact. -
Whether attendance is incorrectly included in grading or promotion
rules. - Access to own attendance vs class-wide records. - Offline event
duplication and conflict handling.

Report any duplicate attendance tables, conflicting APIs or parallel
flows.

## 11. Student and teacher UI / navigation

Inspect actual screens and routes rather than relying on screenshots or
mockups.

Student experience: - Role-appropriate, learning-first home screen. -
Continue/next learning, upcoming assignments, released results, academic
overview and quick access as appropriate. - Hide empty sections and
respect permissions. - Lessons/materials, assignments, quizzes, results,
report cards and previous-year read-only access. - Clear loading, empty,
offline, error, retry and success states. - Accessible text, scalable
fonts, contrast, screen-reader labels and touch controls. - App language
follows existing language settings.

Teacher experience: - Assigned classes/students only. - Existing lessons
and attachment workflows. - Assignment creation/review/return,
assessment grading, feedback, release permissions and relevant
reports. - No unauthorized curriculum creation or editing.

Education Administrator experience: - Education-only management
dashboard and settings. - Academic years/terms, grades/classes/sections,
enrollment, curriculum, teacher assignment, publication approvals,
assessment settings, report cards, transfers/progression and reports. -
No accidental access to unrelated Library or global administration
unless independently authorized.

Navigation: - Verify Education's own bottom navigation and its routes. -
Verify global Hub navigation remains separate and follows the existing
intended behavior. - Check Android back behavior, deep links, route
guards, empty/error states, and consistency across app language
settings. - Compare actual implementation with prior design assets only
if those assets are present; do not assume mockups equal implementation.

## 12. Offline behavior and synchronization

Inspect implementation, not just offline UI indicators.

Expected: - Cache available lesson content/materials wherever
technically feasible. - Student can read previously cached content
offline. - Assignment drafts/submissions can queue offline, with
synchronization timestamp visible to teachers. - Quizzes require
internet to start and submit. - Downloaded digital library books remain
offline until user removes them, with no default expiry. - Library staff
can issue/return physical books offline and sync later. - Conflicts
preserve both histories and are flagged for authorized review; only
clearly safe conflicts may auto-resolve. - Interrupted connections,
retries and repeated sync must not lose or duplicate actions. -
Authentication and authorization must not be weakened by offline
behavior. - Unreleased results must not become visible offline due to
stale cache or unauthorized cache access. - Sync queues must handle
token expiry, partial success, retry/backoff if implemented,
idempotency, conflict state, and user-visible recovery.

Map each offline-capable feature to its local storage, queue, sync
endpoint, conflict logic, and tests. Clearly mark unsupported behavior
and untested assumptions.

## 13. Notifications, reports, audit logs and search

Notifications should support in-app and mobile push where configured.
Inspect categories: - Assignments/deadlines/returned work. - Released
marks/report cards/progression. - Library due dates, overdue notices and
reservation availability. - Magazine issue publication and quiz
deadlines. - Admin announcements and approval requests. - Other
configurable role-appropriate events.

Check notification privacy: previews must not reveal sensitive student
marks or personal data to unauthorized viewers.

Reports expected: - Academic performance, report cards and
progression. - Enrollment, class lists and transfers. - Shared
attendance/service-scoring summaries. - Library inventory, loans, fines,
reservations and audits. - Important audit logs.

Export options: PDF, Excel-compatible spreadsheet, CSV and
print-friendly pages. Education report exports must be limited to
Education Administrators and teachers for assigned classes. Inspect
formulas, date ranges, filters, totals, encoding and Amharic rendering.

Search should span Education content, Library books and magazine issues
while preserving existing authorization. Inspect whether cross-module
search leaks unpublished or restricted content.

Audit logs should cover important actions only, including marks,
approvals, enrollment, circulation, fines, permissions and publishing.
Inspect retention policy and whether logs are protected from
unauthorized modification.

## 14. Data integrity, migration and legacy overlap

Inventory actual tables/models and map relationships. Look specifically
for: - Duplicate or disconnected curriculum, subjects, classes,
enrollment, assignments, submissions, assessments, marks and attendance
structures. - Legacy and newer implementations simultaneously used by
different screens/routes. - Foreign-key gaps, missing indexes, nullable
fields, invalid status values and inconsistent identifiers. - Data
overwritten by resubmission, retake, transfer, sync or migration. -
Missing audit/history links. - Invalid or orphaned records and duplicate
actions. - Migrations that have not been applied, fail on clean install,
or assume production-only state. - Unsafe destructive migrations, schema
drift and incomplete rollback/recovery strategy. - Conflicts between
Education and Library/magazine shared components.

Preservation requirements: - Do not delete member data or historical
academic records. - Deactivation/restriction is preferred to deletion. -
Archive/soft-delete content by default; preserve academic references and
history. - Valid existing records should be migrated if a future
implementation is approved. - Records needing correction must be
reported rather than silently guessed or merged. - Any migration must
first be tested on a staging/backup copy and validate counts,
relationships, history and data integrity before production.

For this audit, do not execute migrations. Report the migration plan and
risks from static inspection. If a safe non-production database is
explicitly available, read-only queries may be used; document the source
and timestamp of counts.

## 15. Security, privacy, accessibility and operations

Inspect: - Server-side authorization, input validation, output escaping
and sensitive-data exposure. - File access controls, upload restrictions
and download authorization. - Rate limiting and abuse controls for
registration, quiz submissions and file endpoints where appropriate. -
Session/token policy and logout/deactivation behavior. - Secrets in
source, logs or configuration; report location without reproducing
values. - Audit log integrity. - Backup frequency and retention
configurability. - Recovery/restore procedure and evidence that restores
are verified. - Hosting limitations that affect achievable recovery time
and acceptable data-loss targets. Recommend realistic targets for later
approval; do not invent hosting capabilities. - App/API health checks,
exception logging and monitoring. - Accessibility across Education
screens and workflows. - Amharic support in UI, generated report cards,
PDFs, exports and stored content.

No user/member data should be deleted. Do not expose real student
information in the audit report.

## 16. Testing and verification

Inventory existing automated tests and execute safe, relevant checks
where possible: - Static analysis/linting. - Unit and integration
tests. - API/controller/policy tests. - Migration tests against
disposable/staging copies only. - UI/widget tests. - End-to-end smoke
tests where environment is available. - Device verification only if a
test device is available and no production risk is introduced.

Critical workflows to test or mark not run: 1. Student registration
request → admin approval → enrollment. 2. Admin opens academic
year/terms/classes and assigns teachers. 3. Teacher sees only assigned
classes/students. 4. Curriculum subject/unit/lesson visibility and
publication approval. 5. Student opens lesson and accesses/downloads
permitted materials. 6. Lesson completion behavior by content type. 7.
Assignment creation → offline draft where supported → submission →
return → resubmission → history preserved. 8. Quiz creation → objective
scoring/written grading → release controls. 9. Retake → highest mark
counts and all attempts remain. 10. Reopen/correct/re-release marks with
audit history. 11. Report card accuracy and Amharic rendering. 12.
Transfer/promotion approval and historical record preservation. 13.
Shared attendance summaries with no competing attendance store. 14.
Offline queue → reconnect → sync → conflict handling → retry without
duplicates. 15. Direct API attempts to access another student or an
unassigned class. 16. Upload invalid/oversized files and attempt
unauthorized download. 17. Deactivation restricts access but preserves
history. 18. Education, Library and Saleda permissions remain separated.
19. Search and notifications respect permissions/privacy. 20. App
navigation, loading/empty/error states and accessibility checks.

## 17. Required report file and structure

Create **`EDUCATION_MODULE_INSPECTION_REPORT.md`** in the repository's
appropriate documentation/deliverables directory. Do not edit other
files.

The report must contain:

1.  **Executive summary** --- current state, readiness, major blockers.
2.  **Inspection scope and limitations** --- what was inspected, what
    was not, environment and test constraints.
3.  **Repository/architecture map** --- real files, routes, services,
    APIs and database entities.
4.  **Feature status matrix** --- Verified working / Partially working /
    Broken / Missing / Not verified / Risk.
5.  **Role-permission matrix** --- expected vs actual, with evidence.
6.  **Workflow traceability** --- UI → API/service → authorization →
    database → UI response.
7.  **Curriculum/data model review** --- actual hierarchy, source-DOCX
    alignment, missing/duplicate/orphan records.
8.  **Assessment and quiz review** --- scoring, attempts, release,
    history, known error status.
9.  **Assignment/submission review** --- versions, deadlines, offline
    behavior.
10. **Attendance integration review** --- shared source of truth and
    retained Education summaries.
11. **Offline/sync review** --- queues, endpoints, conflicts,
    idempotency and risks.
12. **UI/navigation/accessibility review** --- actual screens, route
    behavior and gaps.
13. **Security/privacy review** --- evidence-based risks, severity and
    affected roles.
14. **Migration/data preservation review** --- legacy overlap,
    preservation risks and safe future migration notes.
15. **Tests executed** --- exact commands, result summaries, failures
    and tests not run.
16. **Prioritized findings** --- severity P0 critical, P1 high, P2
    medium, P3 low; include evidence and user impact.
17. **Recommended implementation phases** --- dependency-aware phases,
    not code changes.
18. **Open decisions** --- items requiring product-owner approval, with
    a recommended default where appropriate.
19. **Acceptance checklist** --- measurable checks for later
    implementation and verification.
20. **Final verdict** --- what can be retained, repaired, rebuilt, or
    needs more investigation.

Each finding should use this format:

-   **ID:** EDU-INS-###
-   **Area:**
-   **Status:** Verified working / Partially working / Broken / Missing
    / Not verified / Risk
-   **Severity:** P0 / P1 / P2 / P3
-   **Evidence:** exact file, symbol, route, schema/table, test, or
    observed runtime result
-   **Expected behavior:**
-   **Actual behavior:**
-   **User/business impact:**
-   **Recommended action:** inspection recommendation only; do not
    implement
-   **Dependencies / migration risk:**
-   **Verification needed:**

Do not pad the report with generic statements. If evidence is absent,
say **"Not verified --- evidence unavailable"** and state what is needed
to verify it.

## 18. Final response after inspection

When finished, provide: - The exact path to
`EDUCATION_MODULE_INSPECTION_REPORT.md`. - A concise summary of the most
important findings. - Tests actually run and results. - Areas not
inspected or not verified. - Any product decisions that still need
approval.

**Stop after reporting. Do not implement anything, do not deploy, and do
not generate the final implementation prompt yet.** The inspection
report will be reviewed alongside the agreed requirements before a
separate implementation prompt is prepared.
