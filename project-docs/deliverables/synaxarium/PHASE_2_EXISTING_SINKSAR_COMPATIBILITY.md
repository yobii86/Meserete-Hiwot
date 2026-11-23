# Phase 2 — Existing Sinksar Compatibility & Integration Audit (Corrected)

## 1. Executive Summary & Compatibility Status
This document provides the definitive technical audit of the existing Sinksar implementation across the Laravel backend, Flutter mobile client, and Android home-screen widget.

> [!IMPORTANT]
> **Compatibility Status: PROPOSED ARCHITECTURE ONLY (Unverified at Runtime)**  
> During Phase 2, **no code changes or database migrations were executed**. Any fallback adapter or integration bridge described herein is an architectural design. Backward compatibility **cannot and will not be claimed as 100% verified** until implementation in Phase 3 passes rigorous regression tests in Phase 4 against the established API contract.

---

## 2. Actual Existing Database Schemas (Inspected)

### A. Existing `sinksar_narratives` Table (from Migration `2026_10_29_000001_sinksar_and_alarms.php`)
```sql
CREATE TABLE `sinksar_narratives` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `ethiopian_month` int NOT NULL,
  `ethiopian_day` int NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `summary` text COLLATE utf8mb4_unicode_ci,
  `body` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `verified` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `sinksar_narratives_ethiopian_month_index` (`ethiopian_month`),
  KEY `sinksar_narratives_ethiopian_day_index` (`ethiopian_day`),
  KEY `sinksar_narratives_title_index` (`title`),
  KEY `sinksar_narratives_ethiopian_month_ethiopian_day_index` (`ethiopian_month`,`ethiopian_day`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### B. Existing `sinksar_daily` Table (from Migration `2026_10_29_000001_sinksar_and_alarms.php`)
```sql
CREATE TABLE `sinksar_daily` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `gregorian_date` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ethiopian_date` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ethiopian_year` int NOT NULL,
  `ethiopian_month` int NOT NULL,
  `ethiopian_day` int NOT NULL,
  `month_name_am` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `weekday_am` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `weekday_en` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_fasting` tinyint(1) NOT NULL DEFAULT '0',
  `fasting_reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `annual_feasts` json DEFAULT NULL,
  `monthly_feasts` json DEFAULT NULL,
  `summary` text COLLATE utf8mb4_unicode_ci,
  `full_text_available` tinyint(1) NOT NULL DEFAULT '0',
  `raw_payload` json DEFAULT NULL,
  `notification_sent` tinyint(1) NOT NULL DEFAULT '0',
  `refreshed_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `sinksar_daily_gregorian_date_unique` (`gregorian_date`),
  KEY `sinksar_daily_ethiopian_date_index` (`ethiopian_date`),
  KEY `sinksar_daily_ethiopian_year_index` (`ethiopian_year`),
  KEY `sinksar_daily_ethiopian_month_index` (`ethiopian_month`),
  KEY `sinksar_daily_ethiopian_day_index` (`ethiopian_day`),
  KEY `sinksar_daily_notification_sent_index` (`notification_sent`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## 3. Actual Existing API JSON Contract (`/api/v1/sinksar/today`)

The exact output produced by `Sinksar::formatRecord()` in [Sinksar.php](file:///c:/Users/HP/Documents/MH-app-1.5.3/laravel/app/Mz/Services/Sinksar.php) lines 257–285 is structured as follows:

```json
{
  "id": 142,
  "gregorian_date": "2026-11-14",
  "ethiopian_date": "2019-03-05",
  "ethiopian_year": 2019,
  "ethiopian_month": 3,
  "ethiopian_day": 5,
  "month_name_am": "ኅዳር",
  "weekday_am": "ቅዳሜ",
  "weekday_en": "Saturday",
  "formatted_date": "ኅዳር 5 ቀን 2019 ዓ.ም",
  "formatted_full": "ኅዳር 5 ቀን 2019 ዓ.ም · ቅዳሜ",
  "is_fasting": false,
  "fasting_reason": null,
  "featured_title": "አቡነ ገብረ መንፈስ ቅዱስ (ጴጥሮስ ወጳውሎስ)",
  "summary": "ወርኀዊ መታሰቢያ፦ አቡነ ገብረ መንፈስ ቅዱስ (ጴጥሮስ ወጳውሎስ)",
  "annual_feasts": [],
  "monthly_feasts": [
    {
      "id": "mf_5",
      "title": "አቡነ ገብረ መንፈስ ቅዱስ (ጴጥሮስ ወጳውሎስ)",
      "sourceText": "አቡነ ገብረ መንፈስ ቅዱስ (ጴጥሮስ ወጳውሎስ)"
    }
  ],
  "full_text_available": true,
  "narratives": [
    {
      "id": 1,
      "title": "ስንክሳር ዘወርኀ ኅዳር ፭",
      "source": "B003",
      "summary": "የአቡነ ገብረ መንፈስ ቅዱስ ወርኀዊ መታሰቢያ",
      "body": "አንድ አምላክ በሚሆን በአብ በወልድ በመንፈስ ቅዱስ ስም ኅዳር አምስት በዚች ቀን...",
      "verified": false
    }
  ],
  "has_narratives": true,
  "refreshed_at": "2026-11-14 06:00:00"
}
```

> [!CRITICAL]
> In accordance with user feedback, the narrative's `verified` boolean **MUST DEFAULT TO `false`**. Imported text must never be represented as editorially verified until an authorized church reviewer explicitly verifies it.

---

## 4. Exact Client Model Requirements (Inspected)

### A. Flutter `SinksarDay` Model ([models/sinksar.dart](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/models/sinksar.dart))
| JSON Key | Dart Type | Nullable / Required | Usage in UI |
| :--- | :--- | :--- | :--- |
| `gregorian_date` | `String` | Required (`""` fallback) | Calendar key & date picker sync |
| `ethiopian_date` | `String` | Required (`""` fallback) | Display & cache indexing |
| `ethiopian_year` | `int` | Required (`0` fallback) | Calendar navigation |
| `ethiopian_month` | `int` | Required (`0` fallback) | Month grouping & banner |
| `ethiopian_day` | `int` | Required (`0` fallback) | Day badge |
| `month_name_am` | `String` | Required (`""` fallback) | Header typography |
| `weekday_am` | `String` | Required (`""` fallback) | Header subtitle |
| `weekday_en` | `String` | Required (`""` fallback) | English fallback |
| `formatted_date`| `String` | Required (`""` fallback) | Screen app bar title |
| `formatted_full`| `String` | Required (`""` fallback) | Hero card header |
| `is_fasting` | `bool` | Required | Fasting icon & banner badge |
| `fasting_reason`| `String?` | Nullable | Tooltip / description |
| `featured_title`| `String` | Required (`'የዕለቱ ቅዱሳን'` fallback) | Top banner headline |
| `summary` | `String?` | Nullable | Sub-headline |
| `annual_feasts` | `List<FeastItem>` | Required (default `[]`) | Annual feasts list view |
| `monthly_feasts`| `List<FeastItem>` | Required (default `[]`) | Monthly commemorations list |
| `full_text_available` | `bool` | Required (default `false`) | Read narrative CTA button |
| `narratives` | `List<SinksarNarrative>` | Required (default `[]`) | Expandable narrative cards |
| `has_narratives`| `bool` | Required (default `false`) | Controls narrative card visibility |

### B. Flutter `SinksarNarrative` Model ([models/sinksar.dart](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/models/sinksar.dart))
| JSON Key | Dart Type | Nullable / Required | Usage in UI |
| :--- | :--- | :--- | :--- |
| `id` | `int` | Required (`0` fallback) | Identity & expansion tile key |
| `title` | `String` | Required (`""` fallback) | Section title |
| `source` | `String?` | Nullable | Source reference badge |
| `summary` | `String?` | Nullable | Reading overview |
| `body` | `String` | Required (`""` fallback) | Full Amharic reading text |
| `verified` | `bool` | Required (`false` fallback) | Verification checkmark icon |

### C. Android Home-Screen Widget Payload ([sinksar_widget_service.dart](file:///c:/Users/HP/Documents/MH-app-1.5.3/mobile/mobile/lib/services/sinksar_widget_service.dart))
Transmitted over `MethodChannel('mezmur/sinksar_widget')` via method `updateWidgetData`:
```dart
final map = <String, dynamic>{
  'gregorian_date': day.gregorianDate,     // String: "YYYY-MM-DD"
  'ethiopian_date': day.ethiopianDate,     // String: "YYYY-MM-DD"
  'formatted_date': day.formattedDate,     // String: "ኅዳር 5 ቀን 2019 ዓ.ም"
  'formatted_full': day.formattedFull,     // String: "ኅዳር 5 ቀን 2019 ዓ.ም · ቅዳሜ"
  'featured_title': day.featuredTitle,     // String
  'annual_feasts': day.annualFeasts.map((f) => {'title': f.title}).toList(),
  'monthly_feasts': day.monthlyFeasts.map((f) => {'title': f.title}).toList(),
  'summary': day.summary ?? '',            // String
  'is_fasting': day.isFasting,             // bool
  'fasting_reason': day.fastingReason,     // String?
};
```
> [!NOTE]
> The Android widget does NOT consume the `narratives` array or the heavy `body` text directly; it displays the featured feast, date, fasting state, and summaries. As long as `Sinksar::forToday()` produces these exact fields, the home-screen widget will continue functioning without requiring native Kotlin changes.

---

## 5. Proposed Bridge Architecture (To Be Implemented & Tested in Phase 3 & 4)

Rather than directly replacing or modifying existing database tables:
1. **Isolated New Schema:** All imported Amharic content will reside in newly created, normalized tables:
   - `synaxarium_months`
   - `synaxarium_sources`
   - `synaxarium_entries`
   - `synaxarium_daily_saints`
2. **Read Adapter in `Sinksar.php`:**
   When `sinksar_narratives` does not contain a record for the requested `(ethiopian_month, ethiopian_day)`, `Sinksar::formatRecord()` will query `synaxarium_entries`:
   ```php
   if ($narratives->isEmpty() && Schema::hasTable('synaxarium_entries')) {
       $entry = DB::table('synaxarium_entries')
           ->where('month', $r->ethiopian_month)
           ->where('day', $r->ethiopian_day)
           ->first();
       if ($entry) {
           $narratives = collect([
               (object) [
                   'id' => (int) $entry->id,
                   'title' => $entry->title,
                   'source' => $entry->source_book_id,
                   'summary' => $entry->summary,
                   'body' => $entry->body_am,
                   'verified' => (bool) $entry->is_editorially_verified, // strictly FALSE by default
               ]
           ]);
       }
   }
   ```
3. **No Destructive Overwriting:** The legacy tables `sinksar_daily` and `sinksar_narratives` will remain intact. No data in `sinksar_narratives` will be truncated or overwritten during the import.

---

## 6. Phase 4 Regression Test Plan

Prior to deployment, the following test suite must pass in `tests/Unit/SynaxariumTest.php`:
1. `test_legacy_api_response_structure_remains_identical`: Asserts all 20 required keys in `/api/v1/sinksar/today` match existing types.
2. `test_editorial_verification_defaults_to_false`: Asserts `verified === false` for newly imported narratives.
3. `test_android_widget_payload_contract_compatibility`: Asserts `SinksarWidgetService` required map keys are present and typed correctly.
4. `test_pagumen_bounds_enforcement`: Tests common year (Pagumen 6 returns 422 or clamps) vs leap year (Pagumen 6 returns 200).
5. `test_behase_15_and_16_split_integrity`: Confirms distinct narratives for Nehase 15 and 16.
