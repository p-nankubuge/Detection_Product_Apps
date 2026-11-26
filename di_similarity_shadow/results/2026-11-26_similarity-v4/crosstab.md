# Similarity v4: crosstab (today's dictionary × new band)

Figma Registration K2 (`A207F8A1-ED09-4325-ACE6-C8E26A458FBA`), sessions created 2026-11-20 12:00-14:00 UTC, all 9,156 sessions (no
sampling). Whitelist: uncleaned Dict 63, 13-20 Nov, Figma account production keys (`caveats.md`). Standalone: no List A/B/C, N-rules or
bad lists, so the **Impossible** column is empty by construction.

## v4 (main cut-offs) = v3, cell by cell

The regression rows (`REGX` in `q3_stats_result.txt`, `REG` in `q1_frequency_bins_result.txt`) show 0 sessions with a different band from
v3, so the v4 crosstab, outcome rates and per-platform table are those of `../2026-11-25_layer-1-v3/crosstab.md`:

| Today | A | B | C | D | Impossible | Total |
|---|---:|---:|---:|---:|---:|---:|
| 63 | **4,816 (95.9%)** | 192 (3.8%) | 2 (0.0%) | 13 (0.3%) | 0 | 5,023 |
| 31 | 874 (59.5%) | **481 (32.7%)** | 59 (4.0%) | 56 (3.8%) | 0 | 1,470 |
| 15 | 461 (43.7%) | **406 (38.5%)** | 81 (7.7%) | 107 (10.1%) | 0 | 1,055 |
| 7 | 337 (29.6%) | 486 (42.7%) | **118 (10.4%)** | 197 (17.3%) | 0 | 1,138 |
| 3 | 206 (46.2%) | 110 (24.7%) | 41 (9.2%) | **89 (20.0%)** | 0 | 446 |
| 1 | 11 (47.8%) | 6 (26.1%) | 2 (8.7%) | **4 (17.4%)** | 0 | 23 |
| -1 | 0 | 1 (100%) | 0 | **0** | 0 | 1 |
| **All** | 6,705 (73.2%) | 1,682 (18.4%) | 303 (3.3%) | 466 (5.1%) | 0 | 9,156 |

Bold = agree cell. Platform groups are unchanged from v3 (Desktop: Windows, OS X, Chrome OS; Mobile: Android, iOS, iPadOS; Linux;
Windows RD/VM; Other = software renderers and other OSes); see the v3 file for the band split by platform group and OS.

## What-if: v4 + a + b + c (sessions, High)

| Today | A | B | C | D | Total | D added vs v4 |
|---|---|---|---|---|---:|---:|
| 63 | **4,806 (164 H)** | 192 (6) | 2 (0) | 23 (5) | 5,023 | +10 |
| 31 | 867 (42) | **459 (25)** | 49 (2) | 95 (8) | 1,470 | +39 |
| 15 | 429 (21) | **348 (20)** | 57 (5) | 221 (38) | 1,055 | +114 |
| 7 | 335 (11) | 448 (20) | **93 (10)** | 262 (20) | 1,138 | +65 |
| 3 | 206 (16) | 91 (4) | 22 (1) | **127 (16)** | 446 | +38 |
| 1 | 11 (1) | 6 (1) | 2 (0) | **4 (0)** | 23 | 0 |
| -1 | 0 | 1 (0) | 0 | **0** | 1 | 0 |
| **All** | 6,654 | 1,545 | 225 | 732 (87 H, 11.9%) | 9,156 | +266 (57 H) |

Today's Dict 15 → D grows from 107 (4 High, 3.7%) to 221 (38 High, 17.2%).
