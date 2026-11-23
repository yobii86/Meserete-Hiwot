# Phase 2 — Synaxarium Date Coverage & Ethiopian Calendar Mapping (Corrected)

## 1. Executive Summary
A comprehensive date mapping audit was conducted across all 26 Amharic source files (`B001–B013` Main Readings and `B028–B040` Saints Lists).

- **Static Content Slots:** **366 / 366 days fully covered** (360 standard days + 6 possible Pagumen days).
- **Main Readings Extracted:** **366 / 366 (100.0%)**
- **Authoritative Saints Sections Extracted:** **366 / 366 (100.0%)**
- **Parsed Commemoration Paragraphs:** **2,194 liturgical lines** (contextual hagiography, not unique saint entities).
- **Missing or Dropped Dates:** **0**

---

## 2. Monthly Coverage Audit

| Month # | Ethiopian Month | Expected Days | Main Days Extracted | Saints Days Extracted | Main Status | Saints Status | Commemoration Lines | Total Clean Words |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| 01 | **መስከረም** | 30 | 30 | 30 | `100% OK` | `100% OK` | 134 | 28,142 |
| 02 | **ጥቅምት** | 30 | 30 | 30 | `100% OK` | `100% OK` | 129 | 30,511 |
| 03 | **ኅዳር** | 30 | 30 | 30 | `100% OK` | `100% OK` | 185 | 32,410 |
| 04 | **ታኅሣሥ** | 30 | 30 | 30 | `100% OK` | `100% OK` | 178 | 31,894 |
| 05 | **ጥር** | 30 | 30 | 30 | `100% OK` | `100% OK` | 192 | 33,205 |
| 06 | **የካቲት** | 30 | 30 | 30 | `100% OK` | `100% OK` | 164 | 27,980 |
| 07 | **መጋቢት** | 30 | 30 | 30 | `100% OK` | `100% OK` | 181 | 30,412 |
| 08 | **ሚያዝያ** | 30 | 30 | 30 | `100% OK` | `100% OK` | 170 | 29,750 |
| 09 | **ግንቦት** | 30 | 30 | 30 | `100% OK` | `100% OK` | 196 | 32,840 |
| 10 | **ሰኔ** | 30 | 30 | 30 | `100% OK` | `100% OK` | 204 | 34,115 |
| 11 | **ሐምሌ** | 30 | 30 | 30 | `100% OK` | `100% OK` | 212 | 35,420 |
| 12 | **ነሐሴ** | 30 | 30 | 30 | `100% OK` | `100% OK` | 225 | 36,990 |
| 13 | **ጳጉሜ** | 6 | 6 | 6 | `100% OK` | `100% OK` | 24 | 4,820 |
| **TOTAL** | **13 Months** | **366** | **366** | **366** | **`100.0%`** | **`100.0%`** | **2,194** | **388,489** |

---

## 3. Ethiopian Calendar Runtime Validation Rules

The application must never create a competing calendar engine. It must strictly utilize the existing `App\Mz\Support\EthiopianCalendar` class.

### A. Calendar Algorithm Specifications
1. **Months 1–12 (መስከረም through ነሐሴ):**
   - Valid days: `1 <= day <= 30`. Any day outside this range is rejected as invalid (`422 Unprocessable Entity`).
2. **Month 13 (ጳጉሜ):**
   - In common years (`$year % 4 !== 3`): Valid days are `1 <= day <= 5`. Day 6 is **strictly rejected as invalid**.
   - In leap years (`$year % 4 === 3`): Valid days are `1 <= day <= 6`. Day 6 is **permitted**.

### B. Existing Method Reused
```php
// From App\Mz\Support\EthiopianCalendar:
public static function isLeapYear(int $ethiopianYear): bool
{
    return $ethiopianYear % 4 === 3;
}

public static function daysInMonth(int $ethiopianYear, int $ethiopianMonth): int
{
    if ($ethiopianMonth < 13) {
        return 30;
    }
    return self::isLeapYear($ethiopianYear) ? 6 : 5;
}
```

### C. Runtime vs Content Layer Separation
- **Database Content Layer:** All 366 slots exist statically in `synaxarium_entries` and `synaxarium_daily_saints`. Pagumen 6 is stored permanently so that when a leap year arrives (e.g. 2015, 2019, 2023, 2027 E.C.), the system serves Pagumen 6 immediately without database updates.
- **Runtime API Layer:** When querying by date (`/api/v1/sinksar/{date}` or `/api/v1/synaxarium/{year}/{month}/{day}`):
  - If a user requests `2016-13-06` (common year), `EthiopianCalendar::daysInMonth(2016, 13)` returns 5, causing the validator to throw an `INVALID_DATE` error or clamp to day 5.
  - When browsing the canonical book by month and day alone (`/api/v1/synaxarium/13/6`), the ecclesiastical reading is accessible for devotional study regardless of the current calendar year.
