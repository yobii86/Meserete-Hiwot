# FRONTEND-BACKEND INTEGRATION REPORT
**Project:** Mezmur Zemseretee Hiwot  
**Target:** `mobile/mobile` ↔ `laravel`  
**Investigation Date:** November 11, 2026  
**Auditor / Agent:** Antigravity

---

## 1. INTEGRATION ARCHITECTURE & CONTRACT

The client-server integration couples a Flutter cross-platform client with a Laravel 11 REST API engine. The contract is strictly typed, JSON-serialized, and governed by uniform envelope structures.

```
+-----------------------------------------------------------------------------------+
| Flutter Mobile Client (Dio 5.4 + ImunifySolver)                                  |
|   1. Serializes request model -> JSON payload                                     |
|   2. Intercepts request -> Injects 'Authorization: Bearer <jwt>' + Imunify Cookie|
|   3. Dispatches via HTTPS                                                         |
+----------------------------------------+------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| Laravel Backend Gateway (Mz\Http\Middleware)                                     |
|   1. SecurityHeaders -> Throttle -> ModuleGate -> JWT Authentication              |
|   2. Deserializes payload -> Validates against Mz\Support\V rules                |
|   3. Executes Mz\Services Domain Logic inside DB Transaction                     |
|   4. Returns standard response envelope: { success, code, message, data, errors }|
+----------------------------------------+------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| Client Response Interceptor                                                       |
|   - If HTTP 200: Deserializes `data` to Dart Domain Model (`Model.fromJson`)     |
|   - If HTTP 401: Triggers token refresh flow or redirects to `/login`             |
|   - If HTTP 403 (Imunify): Automatically solves challenge and retries request     |
|   - If HTTP 422: Maps validation errors to UI form field highlights               |
+-----------------------------------------------------------------------------------+
```

---

## 2. KEY INTEGRATION PIPELINES

### A. Authentication & Token Exchange
1. **Initial Login:**
   - Client sends `POST /api/v1/auth/login` with `{ identifier, password }`.
   - Server returns `{ access_token, refresh_token, user }`.
   - Client persists `access_token` and `refresh_token` in [`SecureStore`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/core/storage/secure_store.dart).
2. **Proactive Background Refresh:**
   - In [`session.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/auth/session.dart), a timer fires every 12 minutes (before the 15-minute access token expires) to call `POST /api/v1/auth/refresh`.
   - This eliminates token-expiration interruptions during user operations.
3. **Reactive Interception:**
   - If an endpoint returns `HTTP 401 UNAUTHORIZED`, `ApiClient` queues pending requests, issues a single refresh request, updates the token, and replays the original requests.

### B. Imunify360 Challenge Resilience
1. **Detection:**
   - `ApiClient` inspects outgoing responses. If a `403 Forbidden` response is received with the message `"Access denied by Imunify360 bot-protection"`, or if HTML containing `sfvwann4hz1h` is detected, the challenge handler triggers.
2. **Execution:**
   - Calls `dio.httpClientAdapter.close(force: true)` to flush dead TCP socket pools.
   - Invokes [`ImunifySolver.solve()`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/core/network/imunify_solver.dart).
   - Extracts JS arithmetic, computes `wsidchk`, obtains `wssplashchk` cookie via isolated client.
   - Saves cookie to `SecureStore`.
   - Sets `dio.options.headers['Cookie'] = 'wssplashchk=$cookie'`.
3. **Retry:**
   - Transparently re-executes the failed API call. The user experiences zero failure banners.

### C. Data Model Mapping & Serialization Parity

| Flutter Model (`lib/models/`) | Laravel Schema / Entity | Serialization Parity |
| :--- | :--- | :--- |
| [`User`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/models/user.dart) | `users`, `member_profiles` | Verified. Handles encrypted columns seamlessly. |
| [`LibraryBook`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/models/library.dart) | `items`, `library_categories`, `library_copies` | Verified. Normalizes categories and copy counts. |
| `EduCourse`, `EduLesson` | `edu_courses`, `edu_lessons`, `edu_lesson_materials` | Verified. Tracks mandatory lesson flags and progress %. |
| `Quiz`, `QuizAttempt` | `edu_quizzes`, `edu_quiz_attempts`, `edu_quiz_answers` | Verified. Strict mapping of timer, questions, and scores. |
| `AttendanceSession` | `attendance_sessions`, `attendance` | Verified. Maps status flags (`P`, `L`, `E`, `A`) and signatures. |
| [`SinksarDay`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/models/sinksar.dart) | `sinksar_daily`, `sinksar_narratives` | Verified. Feasts, fasting rules, and audio recitation URLs. |
| `Project`, `ProjectTask` | `projects`, `project_tasks`, `project_milestones` | Verified. Progress % and assignee IDs. |

### D. File Upload & Binary Streaming Protocols
1. **Contribution Receipts & Photos:**
   - Mobile client invokes [`ImageCompressor.compressForUpload()`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/core/utils/image_compressor.dart), resizing to max 1920x1080 and 80% JPEG quality.
   - Transmitted via `FormData` multipart request with upload progress stream.
   - Stored on server in protected directory `storage/mz/private/receipts/`.
2. **WebP Educational Book Streaming:**
   - Client requests individual page images: `GET /api/v1/library/books/{id}/pages/{page}`.
   - Server streams pre-rendered WebP images (avg 45KB/page) from `pdf_document_pages`.
   - Client renders pages instantly via cached network image provider.

### E. Offline Synchronization Engine
- Controlled by [`SyncService`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/services/sync_service.dart) and [`LocalDb`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/core/storage/local_db.dart).
- **Queued Operations:** Attendance records taken offline are written to SQLite table `local_attendance_queue`.
- **Reconciliation:** Upon internet connectivity restoration, the sync service flushes the queue to `POST /api/v1/org/attendance/sync`. If conflicts are detected on the server, they are isolated in `attendance_sync_conflicts` while cleanly merged records are committed.

### F. Deep Linking Integration
- Configured in [`lib/app/deep_links.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/app/deep_links.dart) and Android `AndroidManifest.xml`.
- Supports URI schemes:
  - `https://app.hersolan.pro/mezmur/{id}` → Launches hymn viewer.
  - `https://app.hersolan.pro/learn/lesson/{id}` → Launches lesson reader.
  - `https://app.hersolan.pro/sinksar/{date}` → Launches day's Sinksar narrative.

