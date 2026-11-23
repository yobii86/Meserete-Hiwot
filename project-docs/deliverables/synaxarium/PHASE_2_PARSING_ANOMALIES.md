# Phase 2 — Synaxarium Parsing Anomalies & Resolution Report

## 1. Overview
During the exhaustive parsing of all 26 Amharic source files, structural and markup irregularities were identified, analyzed, and solved. This document provides a complete audit of every anomaly encountered and verifies that zero unexplained discrepancies remain.

---

## 2. The Critical B039 (Nehase Saints) Chapter Anomaly

### Discovery & Symptom
- File: `B039_በነሐሴ ወር ታስበው የሚውሉ ቅዱሳን.txt`
- Total Chapter Headings (`=== ምዕራፍ N ===`): **29**
- Expected Calendar Days for Nehase: **30**
- If a parser naively assumed `Chapter Number == Day Number`, Nehase 16 would disappear, and Chapters 16 through 29 would erroneously be mapped to Days 16 through 29, leaving Day 30 missing and every day after Day 15 shifted by one day.

### Root Cause in Source Text
Inside Chapter 15 (`=== ምዕራፍ 15 ===`), the source text contains **two distinct date headings**:
```text
=== ምዕራፍ 15 ===
--- ነሐሴ 15 ታስበው የሚውሉ ቅዱሳን ---
[Commemorations for Nehase 15: ቅዱስ ቂርቆስና እናቱ ኢየሉጣ ...]

--- 16 ታስበው የሚውሉ ቅዱሳን ---
[Commemorations for Nehase 16: ኪዳነ ምሕረት ...]

=== ምዕራፍ 16 ===
--- 17 ታስበው የሚውሉ ቅዱሳን ---
[Commemorations for Nehase 17: ቅዱስ እስጢፋኖስ ...]
```

### Resolution in Phase 2 Parser
- The parser relies on **actual day heading extraction** rather than chapter numbers.
- Regex delimiter: `r'---\s*(?:(?:በ)?[^\s]+\s*)?(\d+)\s*ታስበው\s*የሚውሉ\s*ቅዱሳን\s*---'`
- Outcome: Both **Nehase 15** and **Nehase 16** are cleanly separated and assigned their respective liturgical commemorations. Subsequent days (17 through 30) align with 100% calendar accuracy.

---

## 3. Ecclesiastical Markup Tokens (`\bd`, `dit`, `d`, `d*`)

### Token Frequency Audit
Across the 26 Amharic source files, the following markup tokens appear:
- `d` / `d*`: **9,597 occurrences** (9,288 opening `d`, 309 explicit `d*`)
- `dit` / `dit*`: **2,109 occurrences**
- `\bd` / `\bd*`: **62 occurrences** (31 pairs)

### Ecclesiastical & Semantic Meaning
- `d ... d*` represents **ደማቅ / ቀይ ቀለም (Rubricated Red Text)** in traditional Orthodox manuscripts. It designates Divine Names (God, Trinity), feast titles, and initial liturgical formulas.
- `dit ... dit*` designates italicized sacred names (e.g. `dit ማርያም dit*`, `dit ኢየሱስ dit* dit ክርስቶስ dit*`).
- `\bd ... \bd*` designates bold title headers in the digitized text.

### Content Preservation Strategy
- **Display Cleaned Text (`body_am`):** Strips markup delimiters without altering sacred names, Ethiopian punctuation, or grammar.
- **Raw Archive (`raw_content`):** Stored intact in the database so that a future UI update can render true manuscript-grade red-ink text for holy names without re-importing.

---

## 4. Pre-Chapter Metadata Headers

### Anomaly
All 13 Main books begin with a catalog header block before `=== ምዕራፍ 1 ===`:
```text
# ስንክሳር ዘወርኀ መስከረም
Collection: C12_Synaxarium_Senkisar (C12)
Group: Sinksar_Amharic
Source: ...
```

### Resolution
The parser cleanly isolates text before the first `=== ምዕራፍ 1 ===` delimiter. Metadata is parsed into file inventory records and excluded from Day 1's liturgical reading text.

---

## 5. Pagumen 6 Calendar Boundary

### Anomaly
Pagumen (ጳጉሜ) has 6 days in the source files, but only occurs once every four years in the calendar.

### Resolution
Pagumen 6 is fully captured and indexed as `month=13, day=6`. In common years, `EthiopianCalendar.php` returns 5 days for Pagumen, ensuring the application remains faithful to the living liturgical calendar while retaining the complete source corpus in the database.

---

## 6. Saints Text Classification (The 2,194 Commemoration Lines)

### Anomaly / Risk
- Naive line-splitting of `B028–B040` yields 2,194 parsed lines.
- **Risk:** Assuming each line represents an individual, discrete saint entity would cause misattribution. The text actually contains compound paragraphs, monastery publication notices, miracle descriptions, and covenant promises (*ቃል ኪዳን*).

### Resolution
- The **complete daily saints section text** is preserved as the authoritative primary source for each of the 366 days in `synaxarium_daily_saints`.
- The 2,194 extracted lines are documented as liturgical commemoration paragraphs, not unique database saint entities.

---

## 7. Audit Conclusion
- [x] All structural quirks and numbering anomalies identified and resolved.
- [x] Zero silent text truncation.
- [x] Zero shifted calendar dates.
- [x] Zero data loss.
- [x] Strict editorial verification policy enforced (`is_editorially_verified = false`).