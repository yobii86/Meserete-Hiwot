# Phase 2 — Synaxarium Database Schema & Mapping Proposal (Corrected)

## 1. Architectural Strategy & Safety Boundaries
The Synaxarium database integration is strictly designed as an **additive, non-destructive extension**.

Key safety principles:
1. **No Overwriting Legacy Tables:** `sinksar_daily` and `sinksar_narratives` will not be altered or wiped out.
2. **Editorial Verification Policy:** All imported entries will default to `is_editorially_verified = false` and `editorial_status = 'imported'`. No imported religious content will be marked as verified without authorized ecclesiastical review.
3. **Authoritative Saints Preservation:** Complete daily saints sections (from `B028–B040`) are preserved as the primary authoritative text. The 2,194 extracted lines represent liturgical commemoration paragraphs and commentary, not verified individual saint records.

---

## 2. Proposed Table Definitions

### A. `synaxarium_months` (Static Reference — 13 Rows)
```sql
CREATE TABLE `synaxarium_months` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `month_number` tinyint unsigned NOT NULL,
  `name_am` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name_geez` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name_en` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `days_count` tinyint unsigned NOT NULL,
  `season_am` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `synaxarium_months_month_number_unique` (`month_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### B. `synaxarium_sources` (Ingestion Audit Trail — 26 Rows)
```sql
CREATE TABLE `synaxarium_sources` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `book_id` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `classification` enum('main_reading','saints_list') COLLATE utf8mb4_unicode_ci NOT NULL,
  `month_number` tinyint unsigned NOT NULL,
  `source_filename` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `file_size_bytes` int unsigned NOT NULL,
  `sha256_checksum` char(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `total_entries` int unsigned NOT NULL DEFAULT '0',
  `import_status` enum('pending','imported','failed') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `imported_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `synaxarium_sources_book_id_unique` (`book_id`),
  KEY `synaxarium_sources_month_number_foreign` (`month_number`),
  CONSTRAINT `synaxarium_sources_month_number_foreign` FOREIGN KEY (`month_number`) REFERENCES `synaxarium_months` (`month_number`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### C. `synaxarium_entries` (Daily Liturgical Readings — 366 Rows)
```sql
CREATE TABLE `synaxarium_entries` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `month` tinyint unsigned NOT NULL,
  `day` tinyint unsigned NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_book_id` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `original_chapter` int unsigned NOT NULL,
  `source_heading` text COLLATE utf8mb4_unicode_ci,
  `summary` text COLLATE utf8mb4_unicode_ci,
  `body_am` mediumtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `raw_content` mediumtext COLLATE utf8mb4_unicode_ci,
  `char_count` int unsigned NOT NULL DEFAULT '0',
  `word_count` int unsigned NOT NULL DEFAULT '0',
  `editorial_status` enum('imported','in_review','verified') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'imported',
  `is_editorially_verified` tinyint(1) NOT NULL DEFAULT '0',
  `editorial_notes` text COLLATE utf8mb4_unicode_ci,
  `verified_by` bigint unsigned DEFAULT NULL,
  `verified_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_synax_month_day` (`month`,`day`),
  KEY `synaxarium_entries_source_book_id_foreign` (`source_book_id`),
  CONSTRAINT `synaxarium_entries_month_foreign` FOREIGN KEY (`month`) REFERENCES `synaxarium_months` (`month_number`) ON DELETE RESTRICT,
  CONSTRAINT `synaxarium_entries_source_book_id_foreign` FOREIGN KEY (`source_book_id`) REFERENCES `synaxarium_sources` (`book_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### D. `synaxarium_daily_saints` (Complete Authoritative Daily Saints Section — 366 Rows)
```sql
CREATE TABLE `synaxarium_daily_saints` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `entry_id` int unsigned NOT NULL,
  `month` tinyint unsigned NOT NULL,
  `day` tinyint unsigned NOT NULL,
  `source_book_id` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `section_text_clean` mediumtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `section_text_raw` mediumtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `commemoration_lines_count` int unsigned NOT NULL DEFAULT '0',
  `editorial_status` enum('imported','in_review','verified') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'imported',
  `is_editorially_verified` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_synax_saints_month_day` (`month`,`day`),
  KEY `synaxarium_daily_saints_entry_id_foreign` (`entry_id`),
  KEY `synaxarium_daily_saints_source_book_id_foreign` (`source_book_id`),
  CONSTRAINT `synaxarium_daily_saints_entry_id_foreign` FOREIGN KEY (`entry_id`) REFERENCES `synaxarium_entries` (`id`) ON DELETE CASCADE,
  CONSTRAINT `synaxarium_daily_saints_source_book_id_foreign` FOREIGN KEY (`source_book_id`) REFERENCES `synaxarium_sources` (`book_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## 3. Explanation of the 2,194 Commemoration Records

### What They Actually Represent
The 2,194 records extracted from `B028–B040` are **liturgical commemoration lines and commentary paragraphs**, including:
1. **Feast Titles & Translations:** e.g., *«መስከረም 1-ሐዋርያው ቅዱስ በርተሎሜዎስ ዕረፍቱ ነው።»*
2. **Hagiographical Excerpts:** e.g., narratives describing miracles and martyrdoms.
3. **Covenant Promises (ቃል ኪዳን):** e.g., numbered quotations like *«2. ‹‹…ከሚበላውና ከሚጠጣው ከፍሎ በስምህ ለነዳያን ለሰጠ...»*.
4. **Historical Annotations:** e.g., references to monastery publications and liturgical traditions.

### Storage Strategy
- **Authoritative Source:** The full, unbroken daily saints text is stored in `synaxarium_daily_saints.section_text_clean` (366 days).
- **No False Atomization:** Individual saint entities are NOT blindly split into a distinct entity table. Creating individual saint records will occur only when ecclesiastical name boundaries (`ቅዱስ ...`, `አባ ...`, `ቅድስት ...`) are validated through an authorized classification filter.

---

## 4. Import Repeatability & Rollback Safety

1. **Idempotent Imports (`updateOrInsert`):**
   Repeated runs of the Artisan import command will identify records by `[month, day]` and update them in place, guaranteeing that row counts never exceed 366 for entries and 366 for daily saints.
2. **Per-Month Database Transactions:**
   Each month is imported inside `DB::transaction()`. If any parsing or database error occurs during Month 7 (Megabit), all changes for Month 7 are rolled back immediately without leaving partial records.
3. **Rollback Migration (`down`):**
   ```php
   public function down(): void
   {
       Schema::dropIfExists('synaxarium_daily_saints');
       Schema::dropIfExists('synaxarium_entries');
       Schema::dropIfExists('synaxarium_sources');
       Schema::dropIfExists('synaxarium_months');
   }
   ```
   The `down()` method strictly drops only the newly created `synaxarium_*` tables, leaving `sinksar_daily` and `sinksar_narratives` untouched.
