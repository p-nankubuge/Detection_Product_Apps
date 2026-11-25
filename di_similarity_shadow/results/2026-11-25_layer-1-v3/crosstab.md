# Layer 1 v3: crosstab (today's dictionary x new band)

Figma Registration K2 (`A207F8A1-ED09-4325-ACE6-C8E26A458FBA`), sessions created 2026-11-20 12:00-14:00 UTC, **all 9,156 sessions (no sampling)**.
Whitelist: uncleaned Dict 63 signatures, 13-20 Nov, Figma account production keys (see `caveats.md`). Standalone mode: no List A/B/C,
N-rules or bad/suspicious lists, so the **Impossible** column is empty by construction. Rules: `spec.md` §2 plus the agent file's
"Seen-before rules" (items 5, 6 and 9 as updated 25 Nov). Source: `q1_crosstab_gates_result.txt` (X3 rows).

## Sessions (row %)

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

Bold = "agree" cell. No session lacked a JS fingerprint or OS (no-score column = 0).

## High risk / verified / challenged / challenged-not-solved per cell

| Today | Band | n | High | Verified | Challenged | Ch. not solved | Mean v3 score |
|---|---|---:|---:|---:|---:|---:|---:|
| 63 | A | 4,816 | 168 (3.5%) | 94.1% | 20.7% | 5.0% | 0.992 |
| 63 | B | 192 | 6 (3.1%) | 94.3% | 20.3% | 5.7% | 0.861 |
| 63 | C | 2 | 0 | 100% | 50.0% | 0% | 0.486 |
| 63 | D | 13 | 1 (7.7%) | 92.3% | 23.1% | 7.7% | 0.730 |
| 31 | A | 874 | 42 (4.8%) | 92.7% | 26.0% | 5.5% | 0.915 |
| 31 | B | 481 | 27 (5.6%) | 94.6% | 23.5% | 4.4% | 0.746 |
| 31 | C | 59 | 5 (8.5%) | 91.5% | 16.9% | 5.1% | 0.542 |
| 31 | D | 56 | 3 (5.4%) | 98.2% | 19.6% | 1.8% | 0.742 |
| 15 | A | 461 | 25 (5.4%) | 93.5% | 32.5% | 6.3% | 0.915 |
| 15 | B | 406 | 39 (9.6%) | 88.4% | 30.5% | 9.4% | 0.762 |
| 15 | C | 81 | 16 (19.8%) | 77.8% | 49.4% | 13.6% | 0.547 |
| 15 | D | 107 | 4 (3.7%) | 95.3% | 19.6% | 3.7% | 0.576 |
| 7 | A | 337 | 11 (3.3%) | 92.6% | 23.7% | 5.9% | 0.923 |
| 7 | B | 486 | 23 (4.7%) | 87.2% | 30.9% | 10.3% | 0.725 |
| 7 | C | 118 | 16 (13.6%) | 87.3% | 38.1% | 10.2% | 0.531 |
| 7 | D | 197 | 11 (5.6%) | 93.9% | 17.3% | 6.1% | 0.537 |
| 3 | A | 206 | 16 (7.8%) | 92.2% | 33.5% | 6.8% | 0.942 |
| 3 | B | 110 | 5 (4.5%) | 90.9% | 33.6% | 8.2% | 0.738 |
| 3 | C | 41 | 5 (12.2%) | 87.8% | 39.0% | 9.8% | 0.528 |
| 3 | D | 89 | 11 (12.4%) | 82.0% | 39.3% | 18.0% | 0.593 |
| 1 | A / B / C / D | 11 / 6 / 2 / 4 | 1 / 1 / 0 / 0 | | | | |
| -1 | B | 1 | 0 | 100% | 0% | 0% | 0.700 |

(Mean score of Band D cells is above 0.40 because most Band D sessions are D by the check trigger, not by score.)

## By platform group and OS (v3 band; n, High)

| Platform group | OS | A | B | C | D |
|---|---|---|---|---|---|
| Desktop | Windows | 3,860 (160 H) | 1,109 (83 H) | 209 (39 H) | 220 (9 H) |
| Desktop | OS X | 1,466 (41 H) | 126 (3 H) | 7 (0) | 24 (0) |
| Desktop | Chrome OS | 101 (17 H) | 25 (0) | 3 (0) | 4 (0) |
| Linux | GNU/Linux | 92 (0) | 28 (1 H) | 35 (0) | 46 (0) |
| Linux | Ubuntu | 4 (0) | 8 (0) | 0 | 12 (0) |
| Mobile | Android | 666 (21 H) | 126 (4 H) | 15 (0) | 92 (11 H) |
| Mobile | iOS | 454 (21 H) | 46 (0) | 1 (0) | 1 (0) |
| Mobile | iPadOS | 56 (0) | 5 (1 H) | 0 | 5 (0) |
| Windows RD/VM | Windows | 0 (capped at B) | 201 (7 H) | 25 (2 H) | 19 (0) |
| Other | Windows (software renderer) | 0 | 1 (1 H) | 4 (1 H) | 35 (5 H) |
| Other | OS X (software renderer) | 0 | 0 | 0 | 4 (4 H) |
| Other | GNU/Linux (software renderer) | 5 (3 H) | 7 (1 H) | 0 | 2 (1 H) |
| Other | Ubuntu / HarmonyOS / OpenHarmony | 1 (0) | 0 | 4 (0) | 2 (0) |

Source: `q2_flow_warnings_result.txt` (PG rows).
