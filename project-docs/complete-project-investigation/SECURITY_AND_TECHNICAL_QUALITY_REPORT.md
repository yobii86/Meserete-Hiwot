# SECURITY & TECHNICAL QUALITY AUDIT
**Project:** Mezmur Zemseretee Hiwot  
**Target:** `C:\Users\HP\Documents\MH-app-1.5.3`  
**Investigation Date:** November 11, 2026  
**Auditor / Agent:** Antigravity

---

## 1. SECURITY POSTURE OVERVIEW

The application demonstrates an enterprise security posture adhering to modern standards of confidentiality, data integrity, and resilience against common web and mobile threat vectors.

```
+---------------------------------------------------------------------------------+
|                               Security Defense Layers                            |
+---------------------------------------------------------------------------------+
| Layer 1: Edge & Network      | Imunify360 WebShield + TLS 1.3 + Rate Limiting   |
| Layer 2: HTTP Headers        | HSTS, CSP, X-Frame-Options, X-Content-Type       |
| Layer 3: Identity & Tokens   | JWT 15-min TTL + Refresh Tokens + Revocation DB  |
| Layer 4: Authorization       | RBAC + Department Scoping + Denial Precedence    |
| Layer 5: Data Integrity      | Parameterized SQL + Validator V + Atomic Locks   |
| Layer 6: Data at Rest        | AES-256-GCM Column-Level Encryption + Blind Idx  |
+---------------------------------------------------------------------------------+
```

---

## 2. IN-DEPTH TECHNICAL SECURITY CONTROLS

### A. Cryptography & Data at Rest
- **Mechanism:** Implemented in [`app/Mz/Crypto/DataEncryptor.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Crypto/DataEncryptor.php) and [`EncryptedColumns.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Crypto/EncryptedColumns.php).
- **Cipher:** AES-256-GCM with authenticated 128-bit integrity tag.
- **Key Rotation Support:** Supports primary active key (`DATA_ENCRYPTION_KEY`) and fallback legacy keys (`DATA_ENCRYPTION_OLD_KEYS`) enabling zero-downtime key rotation.
- **Blind Indexing:** Searchable confidential attributes (e.g. member mobile phone numbers) are indexed via HMAC-SHA256 (`phone_bidx`). This guarantees that SQL query filters can match records without exposing plaintext phone numbers in database query logs or binary dumps.

### B. Authentication & Token Architecture
- **Stateless Tokens:** Access tokens are signed JWTs with short 15-minute lifespans, minimizing the window of vulnerability in the event of client-side token capture.
- **Server-Side Token Revocation:** Implemented via table `revoked_access_tokens`. On user logout, password reset, or administrative suspension, the token's JTI is inserted into the revocation list, causing immediate rejection on subsequent requests.
- **Credential Storage:** User PINs and passwords are protected using standard Bcrypt with 12 rounds (`BCRYPT_ROUNDS=12`).

### C. Input Validation & Injection Defenses
- **SQL Injection Defenses:** The data tier uses [`MzBuilder`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Db/MzBuilder.php) and PDO with strict positional and named parameter bindings. Raw SQL concatenation with user input is strictly prohibited across the codebase.
- **Validation Engine:** Request payloads are checked against [`app/Mz/Support/V.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Support/V.php) before execution, rejecting malformed types, unexpected keys, and invalid phone formats.
- **Cross-Site Scripting (XSS):** All user text rendering in Flutter uses native text widgets that do not interpret HTML/JS. In Flutter Web, input is sanitized, and the server serves strict `Content-Security-Policy` headers.

### D. Rate Limiting & Denial of Service Defenses
- Implemented via [`app/Mz/Http/Throttle.php`](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Http/Throttle.php).
- Sensitive authentication routes (`/api/v1/auth/*`) are restricted to a maximum of **5 attempts per minute per IP**, mitigating brute-force PIN guessing.
- General API routes are throttled to **60 requests per minute per IP**.

### E. Error Handling & Information Leakage
- In production (`.env`):
  - `APP_ENV=production`
  - `APP_DEBUG=false`
  - `LOG_LEVEL=error`
- In the event of backend exceptions, stack traces are withheld from clients; only standardized sanitized error JSON envelopes are returned. Detailed traces are logged internally to `storage/logs/laravel.log`.

---

## 3. ANDROID BUILD & MOBILE SECURITY CONFIGURATION
- **Package Name:** `com.mezmur.mezmur_zelideta`
- **Code Shrinking & Obfuscation:** Enabled via R8 and custom Proguard rules ([`mobile/mobile/android/app/proguard-rules.pro`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/android/app/proguard-rules.pro)).
- **Permissions:** Strict minimal Android permissions declared in `AndroidManifest.xml`:
  - `INTERNET`: Network API access.
  - `FOREGROUND_SERVICE`: Persistent audio playback for hymn streaming.
  - `SCHEDULE_EXACT_ALARM` & `USE_EXACT_ALARM`: Punctual liturgical program alarms.
  - `RECEIVE_BOOT_COMPLETED`: Rescheduling alarms upon phone reboot.
  - `POST_NOTIFICATIONS`: In-app notification delivery.
- **Hardware Storage Security:** Sensitive keys and auth tokens are persisted via `flutter_secure_storage` backed by the Android Keystore (encrypted with AES-256).

---

## 4. DEPENDENCY HEALTH & VULNERABILITY ASSESSMENT
- **PHP Dependencies (`laravel/composer.json`):**
  - Laravel Framework: `^11.0`
  - PHP requirement: `^8.2` (Running on PHP `8.3.29`)
  - No legacy or abandoned packages in vendor tree.
- **Flutter Dependencies (`mobile/mobile/pubspec.yaml`):**
  - All core dependencies (`dio`, `go_router`, `flutter_riverpod`, `just_audio`, `sqflite`) are actively maintained mainstream packages.
  - No critical vulnerabilities or deprecated dependency warnings identified during build verification.

