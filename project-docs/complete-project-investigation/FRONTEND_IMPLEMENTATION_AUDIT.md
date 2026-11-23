# FRONTEND IMPLEMENTATION AUDIT (`mobile/mobile`)
**Project:** Mezmur Zemseretee Hiwot  
**Target:** `C:\Users\HP\Documents\MH-app-1.5.3\mobile\mobile`  
**Investigation Date:** November 11, 2026  
**Auditor / Agent:** Antigravity

---

## 1. FRONTEND ARCHITECTURE & DESIGN SYSTEM

The frontend is a production Flutter application (`mobile/mobile`) targeting Android (primary platform), Web, and iOS.

### Key Specifications:
- **Flutter SDK:** 3.24+ / Dart 3.5+
- **Application ID:** `com.mezmur.mezmur_zelideta` (Version `1.5.3`, Build `30`)
- **Navigation:** `go_router` 14.x configuring **133 route paths**
- **State Management:** Riverpod (`flutter_riverpod: ^2.5.1`) with service-layer `ChangeNotifier` / `StateNotifier`
- **Networking:** `dio` 5.4+ with custom interceptors and `ImunifySolver`
- **Local Database:** `sqflite` (Android/iOS) + `sqflite_common_ffi_web` / `sqlite3.wasm` (Web)
- **Audio Engine:** `just_audio: ^0.9.36` + `audio_session: ^0.1.18`
- **Secure Persistence:** `flutter_secure_storage: ^9.0.0`

---

## 2. NAVIGATION SHELL & ROUTING TOPOLOGY

### A. Navigation Shell (`lib/app/shell.dart`)
The app uses an adaptive `StatefulShellRoute` with an Ethiopian Orthodox aesthetic (gold `#C69214`, deep green `#1E4D2B`, royal burgundy `#5B1425`).

Primary navigation destinations docked in bottom bar:
1. **Home (`/home`):** Daily feast day, quick actions, hymn highlights, continuing education lesson, recent news.
2. **Mezmurs (`/categories`):** Hymn library, categories, lyrics viewer, offline downloads.
3. **Education (`/edu`):** Learning dashboard, Grade 1–12 subjects, quizzes, assignments, report cards.
4. **Programs (`/programs`):** Unified liturgical calendar, church programs, alarms.
5. **Library (`/library`):** Digital library books, physical copies inventory, borrowing requests.
6. **Hub / More (`/hub`):** Central dashboard linking to Sinksar, Guidance, Finance/Contributions, Project Management, Choir Selections, Member Directory, Chat, and Administration.

---

## 3. SCREEN & FEATURE DIRECTORY AUDIT

### 1. `features/auth/`
- [`auth_screens.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/auth/auth_screens.dart):
  - `LoginScreen`: Phone & PIN input, remembered phone, toggle visibility, forgot password link.
  - `RegisterScreen`: Multi-step form with full Amharic validation, baptismal name, gender, profession picker, and department selector.
  - `ForgotPasswordScreen`: Phone number entry, OTP verification, and new PIN establishment.
- [`session.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/auth/session.dart): Global auth state provider, token refresh listener, and session expiration coordinator.

### 2. `features/home/`
- [`home_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/home/home_screen.dart):
  - Liturgical feast day banner ([`holy_day_banner.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/sinksar/holy_day_banner.dart)).
  - Fasting tracker (e.g. ጾመ ነቢያት, አጽዋማት).
  - "Continue Learning" card resuming the last accessed lesson.
  - Quick action buttons: My Attendance, Hymn Player, Digital Library, Sinksar.

### 3. `features/mezmurs/` & `features/player/`
- [`categories_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/mezmurs/categories_screen.dart): Grid/List of liturgical categories with counters.
- [`mezmur_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/mezmurs/mezmur_screen.dart): Lyrics viewer, font size resizing, stanza highlighting, audio playback trigger, favorite toggling, and offline saving.
- [`search_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/mezmurs/search_screen.dart): Live search debounced at 300ms across titles and lyrics.
- [`player_parts.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/player/player_parts.dart): Docked mini-player bar, full-screen playback screen with seek slider, loop modes, and speed toggle (0.75x to 1.5x).

### 4. `features/edu/` (Learning Management System)
- **Home & Academics:**
  - [`edu_home.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/edu/learn/edu_home.dart): Grade selector (Grade 1–12), enrolled courses, curriculum overview, continue learning shortcut.
  - [`edu_academic_calendar.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/edu/edu_academic_calendar.dart): Academic terms, semester dates, and holiday recesses.
- **Course Content & Lessons:**
  - [`learn_screens.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/edu/learn/learn_screens.dart): Unit expansion tile, lesson reader with embedded audio/video player and PDF reader.
  - [`materials_admin.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/edu/learn/materials_admin.dart): Upload lesson notes, audio lectures, slides.
- **Quizzes & Assessments:**
  - [`quiz_screens.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/edu/learn/quiz_screens.dart): Timed quiz execution, multiple-choice options, progress bar, instant submission, score summary, and answer review.
  - [`quizzes_admin.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/edu/learn/quizzes_admin.dart): Quiz creation wizard, question bank drawer, passing mark setting, timer configuration.
- **Assignments:**
  - [`assignments_screens.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/edu/assignments/assignments_screens.dart): Assignment brief, text submission editor, file attachment picker, submission status badge, version history, and teacher evaluation comments.
- **Grades, Report Cards & Certificates:**
  - [`edu_scores_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/edu/edu_scores_screen.dart): Semester scores table, weighted GPA calculation, pass/fail status.
  - [`progress_more.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/edu/learn/progress_more.dart): Academic grievances/complaints thread, retake requests, certificate download with PDF verification.
- **Education Administration:**
  - [`edu_admin_panel.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/edu/edu_admin_panel.dart): Central education command center for managing grades, curriculum, teachers, classes, and registration requests.
  - [`edu_book_catalog_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/edu/admin/edu_book_catalog_screen.dart): Admin catalog for managing textbooks, curriculum references, and digital copies.

### 5. `features/programs/` & `features/sinksar/`
- [`programs_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/programs/programs_screen.dart): Program cards with category badges, times, attendance taker names.
- [`unified_calendar_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/programs/calendar/unified_calendar_screen.dart): Interactive monthly grid supporting dual Ethiopian & Gregorian dates, event indicators, and fasting markers.
- [`alarm_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/programs/alarm_screen.dart): Program alarm dismissal and snooze interface playing Orthodox church bells.
- [`sinksar_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/sinksar/sinksar_screen.dart): Daily saint commemorations, Geez poetry, Amharic narrative reader, and audio narration playback.

### 6. `features/library/`
- [`books_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/library/books_screen.dart): Category browsing chips, digital vs physical tabs, search, and book cards with cover previews.
- [`book_detail_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/library/book_detail_screen.dart): Summary, author, publisher, copy availability counter, borrowing request button, and digital reading launcher.
- [`circulation_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/library/circulation_screen.dart): Librarian checkout interface, barcode/copy assignment, due date picker, return condition checklist, and fine assessment.
- [`webp_pdf_viewer.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/widgets/webp_pdf_viewer.dart): Progressive WebP page viewer for reading books with low RAM consumption and instant page flips.

### 7. `features/contributions/`
- [`submit_receipt_dialog.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/contributions/submit_receipt_dialog.dart): Camera/Gallery image picker, automated image compression via [`image_compressor.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/core/utils/image_compressor.dart), transaction reference input, and upload progress bar.

### 8. `features/projects/`
- [`projects_home.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/projects/projects_home.dart): Active projects, health badges, progress percentages.
- [`project_detail.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/projects/project_detail.dart): Milestones, tasks, budget overview, decisions log, and risk issues.
- [`budget_screens.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/projects/budget_screens.dart): Category budget lines, adjustments, expense ledger with receipt viewing.

### 9. `features/guidance/`
- [`tour_engine.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/guidance/tour_engine.dart): Custom overlay painter rendering transparent spotlight holes over targeted widgets with tooltips.
- [`guidance_center_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/guidance/guidance_center_screen.dart): Searchable articles explaining app features.

### 10. `features/admin/`
- [`admin_home.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/admin/admin_home.dart): Tile dashboard with badges for pending requests, receipts, complaints, and sync conflicts.
- [`receipt_review_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/admin/receipt_review_screen.dart): Side-by-side receipt image inspection and approval/rejection.
- [`attendance_take.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/admin/attendance_take.dart): Fast attendance register with search, status toggles (Present, Late, Excused, Absent), and digital sign-off canvas.
- [`diagnostics_admin_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/admin/diagnostics_admin_screen.dart): System health overview, exception logs, connectivity testing, cache clearing.
- [`media_migration_screen.dart`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/features/admin/media_migration_screen.dart): Admin tool to trigger background WebP conversions for PDFs and covers.

---

## 4. LOCAL STORAGE & OFFLINE INFRASTRUCTURE

| Component | Storage Engine | Managed Entities |
| :--- | :--- | :--- |
| [`LocalDb`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/core/storage/local_db.dart) | SQLite (`app_cache.db`) | Mezmurs, lyrics, categories, attendance sessions, offline queue, sync log |
| [`SecureStore`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/core/storage/secure_store.dart) | Android Keystore / iOS Keychain | JWT access token, refresh token, user ID, Imunify challenge cookie |
| [`BookVault`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/services/book_vault.dart) | Application Documents Directory | Encrypted downloaded PDF books, textbook chapters |
| [`FavoritesService`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/services/favorites_service.dart) | SQLite + In-Memory Cache | Starred hymns, bookmarked lessons, favorite books |
| [`OfflinePack`](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/services/offline_pack.dart) | SQLite + Local Assets | Batch offline bundle containing all text lyrics and Sinksar |

---

## 5. LOCALIZATION & GE'EZ SCRIPT HANDLING
- **Locales Supported:** Amharic (`am` - Default), English (`en`).
- **Translation Resource Files:**
  - `lib/l10n/app_am.arb`: 600+ localized UI keys covering all ecclesiastical, academic, and administrative terminology.
  - `lib/l10n/app_en.arb`: English translation parity.
- **Typography:** Custom font fallback to Noto Sans Ethiopic ensuring Ge'ez diacritics and numerals (፩, ፪, ፫...) render flawlessly across all Android OEM skins.

