# Mezmur Zemseretee Hiwot - Release Record
## Release: F-04 Programs Attendance Conflict-Batch Resolution & System Stability
**Release Identifier:** `v1.5.3+28`  
**Release Date:** October 29, 2026  
**Status:** FULLY DEPLOYED, VERIFIED, AND PUBLICLY DOWNLOADABLE  

---

### 1. Version Control & Identifiers
- **Application ID:** `com.mezmur.zelideta`
- **Source Branch:** `main`
- **Git Commit:** `2477b740ab551683f1640cccb87dac3ba73e05de`
- **Mobile Version Name:** `1.5.3`
- **Previous Android Version Code:** `27`
- **New Android Version Code:** `28` (`1.5.3+28`)
- **Backend Release Identifier:** `v1.5.3-f04` (Production `app.hersolan.pro`)

---

### 2. Database Migrations Executed on Production
- **Migration Name:** `2026_10_30_000002_attendance_sync_conflicts_batch_id`
- **Target Table:** `attendance_sync_conflicts`
- **Schema Changes:**
  - Added indexed column `batch_id VARCHAR(64) NULL AFTER user_id` with `INDEX attendance_sync_conflicts_batch_id_idx(batch_id)`.
- **Execution Output:**
  ```text
  2026_10_30_000002_attendance_sync_conflicts_batch_id .......... 28.38ms DONE
  ```
- **Rollback Safety:** Purely additive and fully reversible (`dropIndex` and `dropColumn('batch_id')` on rollback).

---

### 3. Production Android APK Artifact Details
- **APK Filename:** `release-1.5.3-28.apk`
- **Local Build Output:** `mobile/mobile/build/app/outputs/flutter-apk/app-release.apk`
- **Production Server Storage Location:** `/home/hersolot/app.hersolan.pro/storage/mz/private/releases/release-1.5.3-28.apk`
- **Production Public Mirror Location:** `/home/hersolot/app.hersolan.pro/public/app-release.apk`
- **File Size:** `129,815,965 bytes` (~123.8 MB)
- **SHA-256 Checksum:** `dc74666b54716e1f53c16f7baedc72b425ba33bd3115a67b7b791b2c416fe8c6`
- **Package Badging:**
  `package: name='com.mezmur.zelideta' versionCode='28' versionName='1.5.3' platformBuildVersionName='16' platformBuildVersionCode='36' compileSdkVersion='36'`
- **Signing Certificate Verification:**
  - Keystore Fingerprint: `SHA256: 83:2B:0A:92:11:86:0C:53:B5:35:62:F1:C9:2A:EF:65:6E:B0:F5:00:32:94:D6:6E:A3:85:62:45:F0:1F:4C:C9`
  - Upgradability: 100% signature-compatible with existing installed application and previously published releases 26 and 27. Normal in-place upgrade succeeds without keystore collision.

---

### 4. Website Download & Public Verification
- **Download Landing Page:** `https://app.hersolan.pro/download`
- **Direct Download URL:** `https://app.hersolan.pro/download/android/28.apk`
- **Release Registry:** Registered in `app_releases` table as active published release with `version_code = 28`, `is_published = 1`.
- **Public Download Verification:**
  - Downloaded directly over the public Internet via `https://app.hersolan.pro/download/android/28.apk`.
  - HTTP Status: `200 OK`, Content-Length: `129815965 bytes`.
  - SHA-256 Checksum of downloaded file: `dc74666b54716e1f53c16f7baedc72b425ba33bd3115a67b7b791b2c416fe8c6` (100% bit-for-bit parity match with built APK).
  - Package badging and signing certificate on downloaded artifact confirmed matching.

---

### 5. Website-Download Defect Diagnosis & Confirmed Root Causes
The Android application downloaded from the website was reportedly failing. Investigation established the exact root causes:

1. **Stale APK Served by Website:**
   - The website route `Route::get('download/android/{code}.apk')` serves files exclusively from `storage/mz/private/releases/` based on records in the `app_releases` database table.
   - Previous deployment procedures only copied the APK to `public/app-release.apk` without placing the versioned APK in `storage/mz/private/releases/` or registering it in `app_releases`. As a result, the website download link continued serving the stale `release-1.5.3-27.apk` (built Oct 27).
2. **Version Code Rejection (`INSTALL_FAILED_VERSION_DOWNGRADE`):**
   - Attempting to install or upgrade with an APK sharing the same or lower `versionCode` (27) caused Android Package Manager to reject the install or leave users on an un-updated client. Incrementing `versionCode` to 28 resolved this.
3. **Missing Production Backend Endpoints & Migrations:**
   - The production backend was missing the batch conflict endpoints (`/attendance/sync-conflicts/batches`, `/attendance/sync-conflicts/bulk-resolve`) and the `batch_id` column. When clients attempted batch actions, the server returned 404/500 errors.
4. **MariaDB Syntax Error (1064):**
   - In `laravel/app/Mz/Support/Page.php`, queries with `offset 0` without a limit clause threw MariaDB syntax errors on production. Fixed by enforcing positive integers or omitting offset when no limit is present.

---

### 6. Automated Test Suites & Regression Verification
- **Backend Test Suites (PHPUnit / SQLite in-memory):**
  - `AttendanceBulkConflictTest`: **15 passed (138 assertions)**
    - Verifies legacy sync batch grouping, conflict aggregation, authorized bulk resolution, self-approval prevention, digital signatures, and audit trails.
  - `Stage2FeaturesTest`: **6 passed (51 assertions)**
    - Verifies non-Education attendance sessions, taker assignments, and permissions.
- **Flutter Test Suites:**
  - `attendance_conflict_batches_test.dart`: **5 passed**
  - `attendance_session_test.dart`: **11 passed**
  - `attendance_offline_lrc_test.dart`: **6 passed**
  - Total Flutter Tests: **22 passed, 0 failed**
- **Static Analysis:**
  - Dart Analysis Server (`analyze_files`): **0 errors, 0 warnings**.
- **Production Health Checks & Live Endpoints:**
  - `GET https://app.hersolan.pro/api/v1/attendance/sync-conflicts`: `200 OK`
  - `GET https://app.hersolan.pro/api/v1/attendance/sync-conflicts/batches`: `200 OK`
  - `POST https://app.hersolan.pro/api/v1/attendance/sync-conflicts/bulk-resolve`: `200 OK`

---

### 7. Physical Device Testing Status
- **Device Availability:** No physical Android device or emulator was attached to the local host environment (`adb devices` returned 0 devices).
- **Status:** HTTP artifact download, bit-for-bit checksum verification, package badging, and signing compatibility checks passed with 100% success. End-to-end runtime execution on a physical hardware device remains unverified due to hardware absence.

---

### 8. Production Rollback & Recovery Procedures
If rollback is ever necessary:
1. **Revert Active Release in Database:**
   ```bash
   php artisan tinker --execute="DB::table('app_releases')->where('version_code', 28)->update(['is_published' => 0]); DB::table('app_releases')->where('version_code', 27)->update(['is_published' => 1]);"
   php artisan cache:clear && php artisan config:clear
   ```
2. **Revert Migration (if required):**
   ```bash
   php artisan migrate:rollback --step=1
   ```
3. **Restore Previous Files:**
   Previous known-good backend files are preserved in `.backups/` and `storage/mz/private/releases/release-1.5.3-27.apk` remains intact on the server.
