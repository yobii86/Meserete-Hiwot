# USER ROLES & PERMISSIONS AUDIT
**Project:** Mezmur Zemseretee Hiwot  
**Target:** `C:\Users\HP\Documents\MH-app-1.5.3`  
**Investigation Date:** November 11, 2026  
**Auditor / Agent:** Antigravity

---

## 1. ACCESS CONTROL ARCHITECTURE
Mezmur Zemseretee Hiwot implements a multi-tier, hierarchical Role-Based Access Control (RBAC) model augmented with **Department-Scoped Administration** and **Explicit Granular Revocations**.

The system is defined across four layers:
1. **User Type (`users.user_type`):** High-level identity category (`super_admin`, `admin`, `teacher`, `student`, `member`, `guest`).
2. **System Roles (`roles`, `role_permissions`):** Fixed capability bundles.
3. **User Permission Overrides (`user_permissions`, `user_permission_revocations`):** Granular capability grants or explicit denials for specific users.
4. **Department Administration (`department_admins`):** Scopes administrative privileges to specific parish departments (e.g. Choir, Sunday School, Finance).

---

## 2. SYSTEM ROLES & ACCESS MATRIX

| Role Identifier | Intended Audience | Core Capabilities & Scopes |
| :--- | :--- | :--- |
| **`super_admin`** | Head Parish Administrators & Technical Officers | Complete system access across all modules, departments, diagnostics, database management, app release publishing, and audit logs. Bypasses all gate checks. |
| **`admin`** | General Parish Council Officers | User account management, program scheduling, member profile verification, announcement broadcasts, and general parish reporting. |
| **`dept_admin`** | Department Heads (Choir, Sunday School, Finance, Charity) | Administratively scoped strictly to their assigned department. Cannot modify other departments' records. |
| **`teacher`** | Sunday School Clergy & Teachers | Manage assigned curriculum classes, create lesson content, configure quizzes, grade assignments, review student grievances, and record class attendance. |
| **`student`** | Sunday School Learners | Access enrolled courses, submit assignments, take timed quiz attempts, view report cards, download graduation certificates, and file grievances. |
| **`member`** | Regular Church Congregation | Browse and stream hymns, read daily Sinksar, unified calendar, borrow library books, upload contribution receipts, and participate in direct member chat. |
| **`guest`** | Unauthenticated Visitors | Browse public hymns, view today's feast day banner, inspect basic church information, and initiate registration. |

---

## 3. PERMISSION RESOLUTION ENGINE
Implemented in [`app/Mz/Services/Permissions.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/Permissions.php) and enforced via [`app/Mz/Http/ModuleGate.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Http/ModuleGate.php):

```
                        [User Request Incoming]
                                  |
                                  v
                      Is User 'super_admin'?
                        /                \
                     (Yes)               (No)
                      |                    |
                  [ALLOW]      Is Permission in 'user_permission_revocations'?
                                 /                \
                              (Yes)               (No)
                               |                    |
                            [DENY]      Is Permission in 'user_permissions'?
                                          /                \
                                       (Yes)               (No)
                                        |                    |
                                     [ALLOW]    Is Permission in 'role_permissions'?
                                                  /                \
                                               (Yes)               (No)
                                                |                    |
                                             [ALLOW]    Is Scoped in 'department_admins'?
                                                          /                \
                                                       (Yes)               (No)
                                                        |                    |
                                                     [ALLOW]              [DENY]
```

### Critical Security Rule:
**Denials take absolute precedence over grants.** If a user has an explicit entry in `user_permission_revocations` for a specific capability (e.g. `library.borrow`), they are denied access even if their assigned role or department grant includes that permission.

---

## 4. GRANULAR CAPABILITY PERMISSIONS INVENTORY

### Education Module (`edu.*`)
- `edu.manage_curriculum`: Create and edit academic years, subjects, grades, and classes.
- `edu.assign_teachers`: Assign teachers to specific courses and classes.
- `edu.create_content`: Author units, lessons, and upload materials.
- `edu.manage_quizzes`: Author quizzes, question banks, and adjust scoring weights.
- `edu.grade_submissions`: Evaluate assignment submissions and adjust marks.
- `edu.issue_certificates`: Sign and issue official graduation certificates.
- `edu.manage_complaints`: Investigate and respond to student grade grievances.
- `edu.publish_magazines`: Upload and publish Sunday School digital magazines.

### Library & Circulation (`library.*`, `borrowing.*`)
- `library.catalog_manage`: Add, edit, or archive book records and categories.
- `library.copy_manage`: Register physical copies, barcode numbers, and shelf locations.
- `library.checkout`: Authorize book checkout to members.
- `library.checkin`: Inspect returned books, assess damage/late fines, and close loans.
- `library.override_limits`: Allow borrowing beyond standard maximum active loan limits.

### Attendance Module (`attendance.*`)
- `attendance.create_session`: Open a new formal attendance gathering.
- `attendance.take`: Mark members Present, Late, Excused, or Absent.
- `attendance.sign`: Affix digital cryptographic signature to completed session.
- `attendance.resolve_conflicts`: Resolve offline sync collisions and batch discrepancies.
- `attendance.close`: Officially close and lock attendance sessions from further edits.

### Finance & Contributions (`contributions.*`, `payments.*`)
- `contributions.view_ledger`: View parish-wide financial contributions.
- `contributions.review_receipt`: Approve or reject member-uploaded deposit slips.
- `contributions.set_rates`: Configure pledge rate tiers and mandatory member dues.

### Project Management (`projects.*`)
- `projects.create`: Initiate new church construction or outreach projects.
- `projects.manage_tasks`: Assign tasks, set milestones, and update progress states.
- `projects.manage_budget`: Allocate funds, approve line adjustments, and record expenses.
- `projects.decisions`: Log binding committee resolutions and audit timesheets.

---

## 5. FRONTEND AUTHORIZATION ENFORCEMENT
In Flutter, route guarding and UI element visibility are strictly enforced:
- **Router Guarding:** [`lib/app/router.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/app/router.dart) redirects non-authorized users attempting to deep-link to `/admin/*`, `/attendance/*`, or `/circulation` back to `/home` or `/login`.
- **Dynamic Action Visibility:** Administrative buttons, edit icons, and approval sheets use conditional rendering based on `ref.watch(currentUserProvider)` and `user.hasPermission('...')`.
- **Security Parity:** Frontend UI hiding is never solely relied upon; the backend API rejects unauthorized requests with `HTTP 403 Forbidden` (`INSUFFICIENT_PERMISSIONS`).

