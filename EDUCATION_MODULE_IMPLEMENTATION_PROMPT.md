# Implementation Prompt --- Mezmur Zemseretee Hiwot Education Module

## Mission

You are working in the existing **Mezmur Zemseretee Hiwot** application
repository. Implement the agreed Education-module improvements using the
current codebase and the inspection report as evidence, while preserving
working functionality and valid historical data.

This is a church/Sunday-school education module, not a generic
learning-management product and not a mezmur-study module.

**Primary inputs** - `EDUCATION_MODULE_INSPECTION_REPORT.md` --- inspect
the report in the repository and re-verify its findings against the
current checkout. - `EDUCATION_MODULE_INSPECTION_SPEC.md` --- inspection
coverage and expectations. - The official curriculum source
`ሥርዓተ ትምህርት በክፍል(2).docx`, previously supplied in the conversation.
Search the repository, supplied files, and accessible project assets. If
it is unavailable to the coding environment, state that clearly and
request that the file be placed in the project. Do not invent or
substitute curriculum content. - The requirements below, consolidated
from the product-owner discussion.

## Non-negotiable operating rules

1.  **Inspect the current build first.** Check current Git status,
    branch/commit, app version, relevant code, routes, schemas,
    migrations, tests, local configuration and actual current behavior.
    The audit report describes a snapshot; it may be stale. Reconfirm
    every finding before changing it.
2.  **Do not assume a listed defect is still present or that a listed
    feature works.** Verify it in the current source and with safe
    tests. If already fixed, do not reimplement it; record the evidence
    and continue.
3.  Keep a clear task checklist. Implement only missing or defective
    items, not duplicates. Preserve working UI, navigation, APIs, shared
    services and data.
4.  Do not make broad unrelated UI changes or remove the existing Mezmur
    or Education bottom navigation. Keep Education settings separated
    from unrelated Mezmur settings. Use the existing app language
    setting.
5.  Never delete member records, historical academic records, assignment
    history, quiz attempts, marks, attendance history, circulation
    history or audit history. Prefer archive/soft-delete and
    deactivation/restriction.
6.  Do not silently overwrite, merge, drop, or guess conflicting data.
    Preserve both histories and flag ambiguous cases for authorized
    review. Auto-resolve offline conflicts only when resolution is
    clearly safe.
7.  No destructive commands, live data mutations, production migrations
    or production deployment during initial implementation/testing.
    First test migrations on a staging/backup copy and verify counts,
    relationships, history and integrity.
8.  **Do not deploy until automated tests pass, critical workflows are
    verified, migration/recovery checks pass, and the product owner
    explicitly approves deployment.** Stop and report blockers rather
    than bypassing tests or inventing success.
9.  Do not expose secrets or real student personal data in logs, reports
    or test fixtures.
10. If a requirement cannot be completed safely, do not fake it.
    Document the gap, risk, dependency and recommended next action.
11. Use the current language/framework and existing architecture found
    in the repository. Do not assume or replace the stack.
12. Keep changes focused and reversible. Before a schema migration,
    produce a clear mapping and backup/rollback plan. Never drop the
    legacy submission table before validated backfill and explicit
    approval of the migration plan.
13. First deliver an implementation plan based on re-inspection, then
    proceed with safe code changes in the phases below. Do not stop for
    approval for ordinary reversible code changes, but stop and ask for
    approval where a product decision, destructive risk, curriculum
    ambiguity or production action requires it.

## A. Findings from the inspection report to re-verify

The audit snapshot reported: - Flutter assignment routes/HTTP verbs
differ from Laravel routes, causing assignment
detail/submission/grading/release calls to fail. - `edu_submissions` and
`edu_submission_versions` coexist with a later
`edu_assignment_submissions` table; `EduAssignments::submit()` uses an
upsert that may overwrite prior submission history. - Announcement
client endpoints differ from backend routes. - A direct-material link
endpoint is called by Flutter but appears absent in Laravel routes. - An
obsolete `/edu/attendance/:id` screen remains accessible despite direct
Education attendance being retired and returning HTTP 410. - Assignment
feedback is hidden together with the numerical score before score
release, contrary to the agreed requirement that saved formative
feedback can be visible while marks remain unreleased. -
Grade/subject-targeted announcements may resolve no recipients if there
is no class/course ID. - One Flutter `edu_learning_test.dart` test
failed because an expected empty-registration card was not found in the
configured viewport. Diagnose whether this is only a test setup issue or
a real accessibility/UX issue; do not merely enlarge the viewport to
mask a defect. - The curriculum hierarchy appears inverted: categories
represent disciplines while subjects are used as grades;
`edu_direct_materials` bypasses lessons. - A student-facing Amharic
report-card PDF is missing; current exports are reported to be
administrative CSV/Excel. - The report states the quiz creation bug
caused by a missing `allow_retake` field was fixed, and reports core
quiz, academic-calendar, certificate, scoring and shared-attendance
tests passing. Re-test current behavior and retain working engines. -
Audit test summary reported 60 PHPUnit tests passing and 27 Flutter
tests passing with one failure. Re-run relevant tests and report current
results.

These are leads, not permission to trust stale claims without
verification.

## B. Required delivery workflow

### Phase 0 --- Re-inspection and implementation plan

-   Inspect the current branch and uncommitted changes. Do not overwrite
    user work.
-   Read both inspection documents and relevant implementation files.
-   Reconcile each inspection finding with the current repository and
    classify it as: already fixed, confirmed defect, partly fixed, not
    reproducible, or blocked/unverified.
-   Map the current flow for each critical feature: Flutter UI →
    repository/API request → Laravel route/controller/service →
    authorization → database → response/UI.
-   Inventory relevant tables, unique keys, foreign keys, migrations,
    indexes and all callers before proposing schema changes.
-   Check available safe test/staging environment. Do not connect to or
    change production.
-   Produce a concise plan with dependencies, risk, files likely to
    change, tests and migration/recovery approach. Continue with safe
    implementation once the plan is internally consistent. Ask the
    product owner only for decisions that cannot be safely inferred from
    the agreed requirements.

### Phase 1 --- Critical API contracts and data integrity

1.  Reconcile assignment API URLs and HTTP verbs between Flutter
    repositories and Laravel route registrations. Pick one canonical
    contract and update all clients/routes/tests consistently.
2.  Ensure student assignment detail, submission, teacher submission
    listing, grading, feedback and grade release work end to end with
    real route dispatch---not only direct service tests or mocked
    clients.
3.  Restore immutable submission history. Every
    draft/submission/resubmission must preserve the previous version,
    text, attachments, status and timestamps. Do not use an upsert that
    destroys prior history.
4.  Inspect both `edu_submissions` / `edu_submission_versions` and
    `edu_assignment_submissions` usage across all routes, services and
    screens. Design a non-destructive migration/backfill; retain both
    source tables until counts, relationships and version history have
    been validated on a staging/backup copy. Do not drop a table as a
    shortcut.
5.  Reconcile announcement client/backend routes and test student feed,
    detail, teacher/admin creation and recipient resolution.
6.  Repair the direct-material link operation if still needed by current
    UI; validate URL, file/link format and permissions. Do not expand
    the direct-material workaround as a replacement for the proper
    curriculum hierarchy.
7.  Ensure saved teacher feedback is visible when permitted even if
    numerical scores are unreleased. Continue hiding unreleased marks
    and answer keys.
8.  Ensure grade-targeted and subject-targeted announcements resolve the
    intended enrolled recipients, avoid duplicates and respect
    notification permissions.
9.  Use HTTP integration tests that exercise actual route dispatch and
    authorization. Test correct status codes, request validation and
    response payloads.

### Phase 2 --- Attendance, permissions and user workflow safety

1.  Preserve the existing shared church attendance system as the only
    attendance source of truth. Preserve required Education attendance
    summaries, bridge/API data, offline sync and service-scoring
    integration.
2.  Remove, redirect or replace the obsolete Education attendance entry
    point so it never queues retired 410-failing operations. Where
    appropriate, provide read-only attendance history and clear
    navigation to the authorized church attendance workflow.
3.  Enforce authorization server-side and in the UI. A hidden button is
    not a security boundary.
4.  Keep Education Administrator permissions limited to Education. Do
    not automatically grant Library administration or full app-wide
    administration.
5.  Students see only their own records and released Education results;
    teachers see only assigned classes and authorized students; Library
    and Saleda permissions remain separate.
6.  Student self-registration must be a request requiring administrator
    approval and must be enable/disable configurable. Administrators can
    register/enroll existing app accounts.
7.  Teacher assignment, lesson publication approval, teacher
    material-access requests, transfers, promotion, repetition and
    completion must follow the agreed approval boundaries.
8.  Preserve session/account policy unless inspection proves a necessary
    correction. Deactivation restricts access but retains history.

### Phase 3 --- Curriculum and learning model

**Canonical structure:**
`Grade Level (1–12) → Subject → Unit → Lesson → Learning Materials`.

1.  Validate the official DOCX against the current schema and existing
    data before creating a curriculum import or migration plan. Extract
    the actual grade/subject/unit/lesson hierarchy from the source; do
    not invent content or infer missing mappings.
2.  If the DOCX is not available to the current coding environment,
    continue independent fixes, document this blocker, and do not
    finalize curriculum mapping or perform a speculative schema
    migration.
3.  Preserve existing grade/class/course/enrollment/lesson/material
    identifiers or maintain explicit mapping tables where necessary.
    Preserve history and references to old curriculum versions.
4.  Design a non-destructive migration from the current
    category-first/direct-material arrangement to the canonical
    structure. Include pre-migration counts, mappings, unmapped records
    report, duplicate handling plan, post-migration validation and
    rollback procedure. Test on a staging/backup copy first.
5.  Support grades 1--12, Ethiopian-calendar academic years and
    configurable terms, sections such as Grade 4A/4B, and member groups
    children/youth/married/distance learners.
6.  Preserve the existing rule: one active grade/section enrollment per
    student per academic year, with additional subject/course enrollment
    only when required.
7.  Only Education Administrators may alter curriculum structure/order.
    Teachers cannot create lessons; they attach materials to existing
    lessons. Education Administrator approval is required before lessons
    are published.
8.  Lessons support text, PDF, images and audio; external video links
    only where supported. Multiple materials can be attached to a
    lesson.
9.  All enrolled students can download all materials allowed for their
    grade. Teachers requesting broader material access require
    administrator approval.
10. Upload size and format limits must be configurable by
    administrators; validate file type/content and reject invalid or
    unsupported uploads.
11. Version curriculum changes; preserve historical curriculum
    references and read-only student access to previous reports, marks
    and completed work.
12. Do not introduce a separate lesson-progress analytics system. Record
    lesson completion only as required for completion behavior.
13. Recommended lesson completion defaults:

-   Text: explicit "Mark Complete" action.
-   PDF/images: lesson/material confirmation; do not infer completion
    merely from opening.
-   Audio: playback-end detection if reliable, otherwise confirmation.
-   External video: verified playback completion only when genuinely
    supported; otherwise student confirmation.
-   Multi-material lesson: complete only after every material designated
    required is completed.
-   Sequential gating: off by default; Education Administrator may
    enable it.

14. Preserve the existing app's language setting. Amharic content and
    Fidel script must render correctly.

### Phase 4 --- Assignments, quizzes, grading and reports

#### Assignments

-   Teachers can target whole classes, selected students or selected
    groups.
-   Students submit text and files; teachers can return work for
    correction.
-   Keep immutable submission versions and attachment history.
-   Deadlines/grace periods are configurable; teacher-approved late
    exceptions are recorded.
-   Missing work remains incomplete until graded or resolved by an
    authorized user.
-   Offline drafts/submissions queue where supported and expose
    synchronization time for teacher deadline review.
-   Notifications cover assignments, deadlines and returned work.

#### Assessments and quizzes

-   Support quiz, midterm, final, assignment, project and classwork.
-   Marks are out of 100.
-   Objective quiz items are auto-scored; written answers and
    examinations are manually graded.
-   Authorized staff configure assessment types/weights; weights must
    total exactly 100%.
-   Passing marks are configurable overall and optionally by
    grade/subject.
-   Retake eligibility/limits are configurable; teachers schedule
    authorized retakes.
-   Highest retake mark counts, but every attempt remains in history.
-   Optional per-quiz timer and configurable attempt limits; enforce
    sensitive rules server-side.
-   Offline quizzes require internet to start and submit.
-   Feedback may be shown when saved; numerical marks/objective scores
    remain hidden until authorized release.
-   Releasing/correcting released marks follows an authorized reopen →
    correct → re-release workflow with audit history.
-   Never expose correct answers or unpublished marks through APIs,
    logs, stale caches or offline data.

#### Report cards and progression

-   Provide student-facing report cards in Amharic only, printable and
    exportable as a properly rendered PDF. Include subject marks,
    totals/averages, pass status, attendance summary, teacher comments
    and promotion decision, subject to approved product design.
-   Use real grading configuration; do not invent marks, thresholds or
    spiritual evaluations.
-   Promotion eligibility is guided by configured marks/required-subject
    criteria, but the administrator makes the final approval.
-   Attendance appears in reports but never changes academic marks or
    promotion eligibility.
-   Transfers preserve old enrollment and results and create a new
    enrollment separately; teacher/admin can initiate and administrator
    approves.
-   Academic-year rollover is opened manually by an administrator.
-   Students retain read-only access to previous reports, marks and
    completed work.
-   Education report exports are limited to Education Administrators and
    teachers for their assigned classes.

### Phase 5 --- UI, notifications, offline sync and connected modules

1.  Preserve the existing visual language and navigation where
    functional. Reference palette: `#650D20`, `#FFF8E9`, `#C6A044`,
    `#FFFFFF`. Do not redesign unrelated app areas.
2.  Student home should be learning-first and permission-aware:
    continue/next lessons, upcoming assignments, released results,
    academic overview and quick access. Hide empty sections and avoid
    fake counts or placeholder data.
3.  Teacher dashboard must show only assigned classes/students and
    relevant lesson-material, assignment, assessment, feedback and
    report workflows.
4.  Education Administrator dashboard must expose Education-only
    management and approvals.
5.  Provide clear loading, empty, offline, error, retry and success
    states. Ensure accessible text, scalable fonts, contrast,
    screen-reader labels and usable touch targets.
6.  Support in-app and mobile push notifications where configured:
    assignment/deadline/returned work, released marks/report
    cards/progression, library due dates/overdues/reservations, magazine
    issues/quizzes, admin announcements and approval requests. Keep
    previews privacy-safe.
7.  Preserve cross-module search for Education content, Library books
    and Saleda issues, with existing permission filters.
8.  Offline-first where feasible without weakening authentication,
    permissions, result release or data integrity:
    -   Cache available lesson content/materials where technically
        feasible.
    -   Students can read cached content offline.
    -   Queue supported assignment drafts/submissions and record sync
        time.
    -   Previously downloaded digital books remain offline until the
        user removes them, with no default expiry.
    -   Authorized library staff may issue/return physical books offline
        if the existing design supports it, then sync safely.
    -   Quizzes require internet to start and submit.
    -   Use idempotent action identifiers and safe retries. Interrupted
        connections/repeated sync must not duplicate actions.
    -   Preserve both histories for ambiguous conflicts and flag them
        for authorized review. Auto-resolve only clearly safe cases.
    -   Do not leak unreleased marks through offline caches.
9.  Library is its own domain: digital books, physical copies,
    loans/returns, reservations/waitlists, borrowing history, overdue
    fines, lost/damaged handling, inventory audits, role permissions,
    offline reading/circulation and reports. Preserve existing working
    Library implementation; fix integration conflicts rather than
    creating a second source of truth.
10. Saleda is the monthly church magazine: multiple articles per monthly
    issue, text/PDF/images, publisher-managed quizzes, multiple-choice
    only, one attempt per participant, open for one week, immediate
    score, no pass/fail threshold, searchable issue/quiz archive. A
    higher-level administrator approves each issue and quiz before
    publication. Preserve existing working functionality; do not rebuild
    the magazine unless inspection proves it necessary.

### Phase 6 --- Security, audit, backup and operations

-   Important-action audit logs: marks, approvals, enrollment,
    transfers/progression, circulation, fines, permissions and
    publishing. Do not log every trivial event.
-   Preserve the existing audit retention policy after inspection.
-   No member data deletion; deactivate/restrict instead.
    Archive/soft-delete content by default while preserving academic
    references.
-   Make backup frequency and retention configurable where supported.
-   Inspect actual hosting limits and propose realistic recovery-time
    and acceptable-data-loss targets for owner approval. Do not promise
    capabilities that hosting cannot support.
-   Require backup restore verification, not just backup-file existence.
-   Protect uploads/downloads, validate input, enforce authorization and
    guard against path traversal, executable uploads and
    direct-object-reference access.
-   Inspect sessions/tokens, deactivation behavior, error handling, rate
    limits and secret handling.
-   Exports: PDF, Excel-compatible spreadsheet, CSV and print-friendly
    pages where appropriate; validate totals, filters, Amharic rendering
    and access scope.

## C. Required testing and acceptance criteria

Run available automated tests and add tests for any fixed or new
behavior. Use disposable/staging data, not production. Do not report
tests as passing unless executed.

Minimum critical acceptance tests: 1. Assignment endpoints match actual
Laravel route dispatch and work through the real HTTP client. 2.
Submit/resubmit preserves every version, attachment, timestamp and
status; no destructive overwrite. 3. Grade release hides scores until
authorized release while saved feedback remains visible when allowed. 4.
Announcement feed/create/detail routes work; grade/subject targeting
notifies correct enrolled users without duplicates. 5. Direct material
link endpoint works if retained in current UI. 6. Obsolete Education
attendance route never dispatches retired operations; shared attendance
summaries still work. 7. Student registration request → admin approval →
enrollment works. 8. Teacher can access only assigned classes/students;
student cannot access another student's records via direct API/deep
link. 9. Curriculum mapping and migration preserve record counts, links,
history and version references; unmapped data is reported, not guessed.
10. Lesson publication and curriculum-order permissions are enforced
server-side. 11. Assignment return/resubmission history and
deadline/offline timestamp behavior work. 12. Objective quiz scoring,
written grading, timer/attempt limits, retakes and highest-mark rule
work; all attempts are preserved. 13. Reopen/correct/re-release marks is
authorized and audited. 14. Amharic report card renders correct marks,
totals, attendance summary and progression; no invented values. 15.
Attendance never affects marks or promotion eligibility. 16. Offline
queue/reconnect/retry/conflict handling avoids lost/duplicate actions.
17. Download permissions, upload validation and privacy of unreleased
marks are tested. 18. Library and Saleda permissions stay separated from
Education permissions. 19. Backup restore is verified in a safe
environment. 20. All relevant PHPUnit, Flutter tests, static
analysis/lint and build checks pass, or failures are documented and
fixed before release approval.

Fix the failing `edu_learning_test.dart` for the correct reason. Do not
merely change test dimensions to conceal broken content visibility. Run
API integration tests against the actual router; mocked UI tests alone
are insufficient.

## D. Migration and deployment safeguards

Before any production migration: 1. Produce a table-by-table migration
map and before-counts. 2. Create/verify a restorable backup and perform
a restore test. 3. Run migration on a staging/backup copy. 4. Validate
counts, foreign-key relationships, enrollment references,
submissions/versions, quiz attempts, marks, attendance, and historical
curriculum references. 5. Compare before/after data and report
unmapped/duplicate/conflicting records. 6. Confirm rollback/recovery
steps. 7. Stop on any critical failure. Do not bypass it.

Do not deploy until the owner has reviewed the work report and
explicitly approved deployment. After approval, deploy only the verified
build, then smoke-test health, authentication, critical Education
workflows, permissions, key data and logs. Report deployment status
honestly.

## E. Required final deliverables

Create/update documentation under the project's appropriate
documentation/deliverables directory: 1.
`EDUCATION_IMPLEMENTATION_PLAN.md` --- current findings confirmed,
scope, phases, dependencies, risks and acceptance tests. 2.
`EDUCATION_IMPLEMENTATION_REPORT.md` --- changes made, files touched,
fixed/already-fixed findings, tests and exact results, migration counts,
preserved data/history, permissions, backup/restore evidence, remaining
gaps, deployment status and next steps. 3. Update
`EDUCATION_MODULE_INSPECTION_REPORT.md` only if evidence shows it needs
correction; preserve the original audit findings/history and mark stale
findings clearly rather than silently rewriting history.

Final response must state: - What was changed and what was deliberately
retained. - Which audit findings were already fixed vs fixed now. -
Tests actually run and exact outcomes. - Data migration/backup/restore
results and limitations. - Outstanding blockers, product decisions and
unverified items. - Whether deployment occurred (it must not occur
without explicit owner approval).

**Start with re-inspection and a plan. Then implement safe, agreed work
in dependency order. Preserve working features, avoid duplicate systems,
protect all existing data, and do not deploy without explicit
approval.**
