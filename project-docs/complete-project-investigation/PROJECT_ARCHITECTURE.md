# PROJECT ARCHITECTURE & SYSTEM DESIGN AUDIT
**Project:** Mezmur Zemseretee Hiwot  
**Target:** `C:\Users\HP\Documents\MH-app-1.5.3`  
**Investigation Date:** November 11, 2026  
**Auditor / Agent:** Antigravity

---

## 1. HIGH-LEVEL TOPOLOGY
The application follows a decoupled client-server architecture engineered for high fault tolerance, offline capability, and low latency across mobile devices operating in bandwidth-constrained environments (specifically Ethiopia).

```
                      +---------------------------------------+
                      |           Client Tier                 |
                      |  Flutter Mobile (Android/iOS) & Web   |
                      +-------------------+-------------------+
                                          |
                        HTTPS (REST JSON) | Imunify360 Bot Challenge Handling
                                          v
                      +---------------------------------------+
                      |         Web & Security Tier           |
                      |  Imunify360 WebShield Reverse Proxy   |
                      |         LiteSpeed Web Server          |
                      +-------------------+-------------------+
                                          |
                               FastCGI    v
                      +---------------------------------------+
                      |          Backend Application          |
                      |     Laravel 11.x (PHP 8.3 CLI/FPM)    |
                      |       Domain Services (app/Mz)        |
                      +-------------------+-------------------+
                                          |
                          MySQL Protocol  v
                      +---------------------------------------+
                      |             Data Tier                 |
                      |       MySQL 8 (hersolot_appdb)        |
                      |       160 Tables / Encrypted Columns  |
                      +---------------------------------------+
```

---

## 2. FRONTEND ARCHITECTURE (`mobile/mobile`)

### A. Core Technologies & Dependencies
- **Framework:** Flutter 3.24+ / Dart 3.5+
- **Navigation:** `go_router` (v14.x) configuring **133 unique routes** structured hierarchically with modal sheets and sub-routes.
- **State Management:** Riverpod (`flutter_riverpod`) coupled with custom `ChangeNotifier` / `StateNotifier` stores for global services (e.g. `AudioPlayerService`, `SyncService`, `FavoritesService`, `BookVault`).
- **HTTP & Networking:**
  - `Dio` client wrapped inside [`ApiClient`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/core/network/api_client.dart).
  - Integrated with [`ImunifySolver`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/core/network/imunify_solver.dart), which intercepts HTTP 403 / challenge HTML responses, extracts JS arithmetic, computes `wsidchk`, obtains `wssplashchk` cookie, caches it in persistent storage, and transparently retries requests.
- **Local Persistence & Offline Storage:**
  - [`LocalDb`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/core/storage/local_db.dart): High-performance SQLite database managing offline hymns, attendance logs, educational progress, local cache, and sync queue.
  - [`SecureStore`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/core/storage/secure_store.dart): Encrypted storage via `flutter_secure_storage` storing JWT access tokens, refresh tokens, active session IDs, user credentials, and Imunify verification cookies.
  - [`BookVault`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/services/book_vault.dart): Encrypted filesystem storage for downloaded PDFs and educational digital books.
- **Audio & Media Streaming:**
  - `just_audio` with `audio_session` for robust background audio playback, lock screen media controls, playlist management, and local file playback.
- **Native Android Platform Integrations:**
  - Native Kotlin AppWidget implementation in `android/app/src/main/kotlin/com/mezmur/zelideta/widget/`:
    - `SinksarCompactWidgetProvider.kt`
    - `SinksarExpandedWidgetProvider.kt`
    - `SinksarWidgetManager.kt`
    - `EthiopianCalendarHelper.kt`
  - Updates home screen widgets with daily EOTC feast days, fasting rules, and saint narratives directly from synced local SQLite data.

---

## 3. BACKEND ARCHITECTURE (`laravel`)

### A. Architectural Innovation: The `app/Mz` Domain Engine
Unlike generic Laravel applications that heavily rely on Eloquent ORM (which incurs substantial object-hydration overhead and memory penalties), Mezmur Zemseretee Hiwot uses a purpose-built domain engine located in `app/Mz/`:

1. **Database Access Tier (`app/Mz/Db/`):**
   - [`MzBuilder.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Db/MzBuilder.php): Custom query builder wrapping PDO with fluent SQL generation, strict parameter binding, automated soft-delete handling, and column-level encryption hooks.
   - [`MzConnection.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Db/MzConnection.php): High-throughput transaction manager with dead-lock retries and query profiling.
   - [`Locks.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Db/Locks.php): Atomic advisory locking for attendance sync, quiz submission evaluation, and book checkout races.

2. **Column-Level Cryptography (`app/Mz/Crypto/`):**
   - [`DataEncryptor.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Crypto/DataEncryptor.php) & [`EncryptedColumns.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Crypto/EncryptedColumns.php):
   - Sensitive personal information (phone numbers, full names, national IDs, emergency contacts) is encrypted at rest in the database using AES-256-GCM.
   - A cryptographic blind index (HMAC-SHA256) allows indexed lookups (e.g. searching by phone number or national ID) without storing plaintext.

3. **Authentication & Session Authority (`app/Mz/Auth/`):**
   - Stateless JWT architecture using dual key rotation:
     - Access tokens: Short-lived (15 minutes), HMAC-SHA256.
     - Refresh tokens: Stored in `refresh_tokens` database table with device footprint tracking.
   - Token revocation lists (`revoked_access_tokens`) allowing instant server-side revocation on logout, password change, or admin account lockout.
   - Granular RBAC (`app/Mz/Services/Permissions.php`, `UserAdmin.php`, `ModuleGate.php`).

4. **Dedicated Domain Services (`app/Mz/Services/`):**
   - 52 distinct domain services encapsulate all business rules, validation, transactions, notifications, and data formatting.
   - Controllers in `app/Http/Controllers/` remain lean, delegating request payloads directly to domain services.

---

## 4. DATABASE TOPOLOGY & PHYSICAL STORAGE
- **Engine:** MySQL 8.0 on `hersolan.pro`.
- **Charset / Collation:** `utf8mb4` / `utf8mb4_unicode_ci` ensuring full support for Ge'ez script (ፊደል), Amharic text, emojis, and international characters.
- **Schema Volume:** **160 tables** organized into 14 cohesive relational domains.
- **File & Media Storage:**
  - Public Assets: `storage/mz/public/` (accessible via symlink `/public/files`).
  - Private Assets: `storage/mz/private/` (protected documents, certificates, user uploads, digital books, and APK releases served via authorized controller streams).
  - Media Conversions: Background generation of lightweight WebP pages (`pdf_document_pages`, `media_conversions`) for instant in-app reading without downloading 50MB PDF files.

---

## 5. EXTERNAL INTEGRATIONS
1. **Firebase Cloud Messaging (FCM):** Push notifications for announcements, assignment deadlines, attendance alerts, and reminder broadcasts (`app/Mz/Notifications/Fcm.php`).
2. **Telegram Bot Integration:** Dedicated webhook integration (`app/Mz/Notifications/Telegram.php`, `app/Console/Commands/RegisterTelegramWebhook.php`) communicating with `@Mezmure_Zelideta_bot` for system alerts, password resets, and admin notifications.
3. **Imunify360 WebShield:** Handled by client-side autonomous solver and server-level whitelisted operational routes.

