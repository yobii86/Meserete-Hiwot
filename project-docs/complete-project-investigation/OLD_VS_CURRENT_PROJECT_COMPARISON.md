# OLD VS CURRENT PROJECT COMPARATIVE AUDIT
**Current Project:** `C:\Users\HP\Documents\MH-app-1.5.3` (Version `1.5.3`, Build `30`)  
**Old Project (Identified):** `C:\Users\HP\Documents\Downloads\MH-App` (Version `1.4.0`, Build `10`)  
**Alternative Prototype:** `C:\Users\HP\Documents\mezmur` (Pre-migration Node.js prototype)  
**Investigation Date:** November 11, 2026  
**Auditor / Agent:** Antigravity

---

## 1. PROJECT DISCOVERY & CANDIDATE REPORTING
Per instructions to identify and report all possible older source code folders:

1. **`C:\Users\HP\Documents\Downloads\MH-App` (Primary Old Project)**
   - **Version:** `1.4.0+10` (Verified via `mezmur-zelideta-1.4.0+10-release.apk` dated Oct 6, 2026).
   - **Stack:** Laravel Backend + Flutter Mobile.
   - **Scope:** Represents the immediate functional predecessor to `MH-app-1.5.3`.

2. **`C:\Users\HP\Documents\mezmur` (Early Architectural Prototype)**
   - **Date:** September 23–24, 2026.
   - **Stack:** Node.js / Express (`backend/package.json`) + early Flutter app `fnote_tsidk_mezmur`.
   - **Scope:** Proof-of-concept codebase created prior to the Laravel rewrite.

3. **`C:\Users\HP\Documents\Downloads\laravel` (Transitional Snippet)**
   - **Date:** October 9, 2026. Standalone files representing a snapshot of the backend during initial migration.

*The comparative analysis below directly contrasts the primary predecessor (`Downloads/MH-App`, v1.4.0) with the current codebase (`MH-app-1.5.3`, v1.5.3).*

---

## 2. HIGH-LEVEL STATISTICAL COMPARISON

| Dimension | Old Version (1.4.0) | Current Version (1.5.3) | Net Differential |
| :--- | :--- | :--- | :--- |
| **Backend Total Files** | 185 | 322 | **+144 added**, 87 modified, 7 removed |
| **Mobile Total Files** | 260 | 402 | **+143 added**, 125 modified, 1 removed |
| **Database Migrations** | 8 migrations | 45 migrations | **+37 migrations** |
| **Database Schema Tables** | 76 baseline tables | 160 tables | **+84 tables (+110% expansion)** |
| **Backend Route Statements** | 413 routes | 741 routes | **+328 routes (+79% expansion)** |
| **Flutter Route Paths** | 53 paths | 133 paths | **+80 paths (+150% expansion)** |
| **Automated Test Files** | 7 test files | 89 test files (42 PHP + 47 Dart) | **+82 test files** |
| **Android APK Binary Size** | 115,533,679 bytes | 135,211,086 bytes | +19.7 MB (Includes Sinksar, LMS assets) |

---

## 3. FEATURE DIFFERENTIAL MATRIX

### A. Features Available ONLY in the Current Project (New Capabilities Added)

1. **Sinksar (Synaxarium) & Daily Liturgical Readings:**
   - Complete saint commemorations, fasts, feast names, Geez poetry, and Amharic narratives.
   - Background audio narration streaming.
   - Native Android home-screen AppWidgets (`SinksarCompactWidgetProvider`, `SinksarExpandedWidgetProvider`).
   - *Status in Old Project:* **Completely absent.**

2. **Full-Cycle LMS Education Platform (Grades 1–12):**
   - Canonical curriculum synchronization for all 12 grades.
   - Question banks, timed quiz sessions, and randomized draws.
   - Multi-attempt quiz retake governance (`edu_retakes`).
   - Versioned text and file assignment submissions.
   - Semester report cards with weighted GPA calculation.
   - Digitally signed graduation certificate generation with QR code verification.
   - Academic grievances/complaints two-way messaging thread.
   - Sunday School digital magazines archive.
   - *Status in Old Project:* Only a rudimentary course stub (46 routes) with mock units.

3. **Physical Library Circulation Desk & Inventory:**
   - Physical copy inventory tracking with barcodes, accession numbers, and shelf locations.
   - Return condition inspection checklist (Binding, Pages, Water damage).
   - Late fee and damage fine assessment engine.
   - Progressive WebP page viewer for reading books without downloading heavy PDFs.
   - *Status in Old Project:* Only basic title cataloging without physical copy or circulation management.

4. **Contribution Slip Upload & Admin Verification Workflow:**
   - Member bank deposit slip / mobile screenshot upload with automatic client-side image compression.
   - Interactive zoomable slip review screen with approve/reject actions and reason logging.
   - *Status in Old Project:* Only manual database payment entries.

5. **Contextual Guidance & Interactive Tour Engine:**
   - Visual onboarding spotlights targeting specific UI widgets via `GlobalKey`.
   - Contextual help modal sheets on key screens.
   - Searchable Guidance Center catalog.
   - *Status in Old Project:* Completely absent.

6. **System Diagnostics & Self-Healing Telemetry:**
   - Automated client error and crash reporting to backend database.
   - Diagnostic dashboard with system health indicators and cache management.
   - Media migration engine for background PDF-to-WebP conversions.
   - *Status in Old Project:* Completely absent.

7. **Autonomous Imunify360 Bot-Challenge Solver:**
   - Transparent in-app JSFuck arithmetic solver and cookie caching engine.
   - *Status in Old Project:* Absent (caused blocking HTTP 403 errors on external networks).

8. **Liturgical Program Alarms with Custom Audio:**
   - Church bell alarm sounds (`alarm.wav`) triggered before liturgical services.
   - *Status in Old Project:* Basic local notification without custom sound or alarm wake-locks.

---

### B. Features Improved or Redesigned in Current Version
1. **Attendance Tracking:**
   - Redesigned with offline batch synchronization, digital signature capture, and conflict resolution quarantine (`attendance_sync_conflicts`).
2. **Unified Calendar:**
   - Upgraded to support dual Ethiopian and Gregorian calendars simultaneously with astronomical accuracy.
3. **Database Security:**
   - Upgraded from plaintext PII columns to AES-256-GCM authenticated column-level encryption with blind HMAC indexing.
4. **App Shell & Hub:**
   - Redesigned with an Orthodox aesthetic, responsive grid layout, and centralized Hub for quick access to all 15 modules.

---

### C. Features Available ONLY in the Old Version (or Removed)
- **None of the functional application features were lost or removed.**
- The only items removed between v1.4.0 and v1.5.3 were legacy configuration and build files:
  - `package.json` and `vite.config.js` in backend root (remnants of the old Vite asset pipeline, now superseded by pure Flutter web build).
  - `scripts/parity-test.sh` (obsolete bash script from the Node-to-Laravel migration).
  - `ios/Flutter/ephemeral/.swift_pm.lock` (standard build cache).

---

## 4. DATABASE & DATA COMPATIBILITY EVALUATION
- **Migration Safety:** All 37 new migrations were authored as non-destructive forward migrations using `CREATE TABLE IF NOT EXISTS` and `ADD COLUMN`.
- **Reference Data Integrity:** The baseline reference data (departments, roles, initial categories) was untouched.
- **Rollback Risk:** Zero. The production database is operating on migration 45 (`2026_11_09_000001_seed_education_library_categories.php`) without schema anomalies.

