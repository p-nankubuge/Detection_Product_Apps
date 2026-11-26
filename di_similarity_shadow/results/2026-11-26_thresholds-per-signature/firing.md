# Firing: per-signature threshold (D-19) vs today, short-term only

Source: `raw/10_tables.txt` (built by `10_build_tables.py` from `raw/`). "Today" = DI's recorded short-term breach (`DI_SHORT_TERM_THRESHOLD_BREACHED_AT_SESSION_CREATED`), Dict 63 included as recorded (today it is exempt in effect). Grid point "m5 f11" = multiplier 5, floor 11. Clean = the session's signature-window (List flag x platform group x matched signature x 40-min `TIME_SLICE`) has < 20% High-risk sessions.

## Figma Registration K2, 20 Nov 2026 (88,608 sessions)

| Rule | Fires | High % | Verified % | Challenged % | Chall. not solved % | Clean fires (% of fires) | New-only | Lost vs today | 12-14 UTC: fires / High % / clean |
|---|---|---|---|---|---|---|---|---|---|
| Today (ST 11) | 381 | 52.8 | 62.7 | 82.7 | 36.7 | 131 (34.4) | | | 25 / 20.0 / 24 |
| m2 f5 | 1,081 | 38.1 | 67.1 | 66.6 | 30.9 | 531 (49.1) | 719 | 19 | 110 / 16.4 / 93 |
| m5 f5 | 942 | 41.4 | 65.2 | 71.1 | 32.5 | 420 (44.6) | 607 | 46 | 102 / 14.7 / 88 |
| m10 f5 | 856 | 42.5 | 63.3 | 72.8 | 34.1 | 360 (42.1) | 547 | 72 | 92 / 16.3 / 79 |
| m20 f5 | 744 | 45.6 | 59.9 | 76.9 | 37.2 | 286 (38.4) | 471 | 108 | 77 / 19.5 / 64 |
| m2 f11 | 362 | 54.4 | 64.9 | 82.6 | 34.5 | 116 (32.0) | 0 | 19 | 25 / 20.0 / 24 |
| m5 f11 | 335 | 56.7 | 65.4 | 84.2 | 34.0 | 96 (28.7) | 0 | 46 | same |
| m10 f11 | 309 | 57.3 | 65.4 | 84.8 | 34.0 | 78 (25.2) | 0 | 72 | same |
| m20 f11 | 273 | 58.2 | 61.2 | 89.4 | 38.1 | 61 (22.3) | 0 | 108 | same |

With floor 11 (= Figma's current threshold) the new rule can only fire where today fires, so it adds nothing on Figma; it removes fires on common signatures.

Skipped (List A/B/C, no new threshold): 1,459 sessions on 20 Nov (A 567, B 9, C 883; today fired 17 of them). Dict -1 (no matched signature): 6 sessions.

### G7 per cell, Figma (clean fires vs today's clean fires in the same cell)

| Rule | Failing cells | Worst cells (new vs today) |
|---|---|---|
| m2 f5 | 17 | 63 Desktop 180 vs 20; 7 Desktop 90 vs 26; 3 Desktop 63 vs 30; 31 Desktop 51 vs 15; 63 Mobile 36 vs 0 |
| m5 f5 | 15 | 63 Desktop 150 vs 20; 7 Desktop 78 vs 26; 31 Desktop 51 vs 15 |
| m10 f5 | 14 | 63 Desktop 136 vs 20; 7 Desktop 61 vs 26; 31 Desktop 51 vs 15 |
| m20 f5 | 14 | 63 Desktop 111 vs 20; 31 Desktop 50 vs 15; 7 Desktop 29 vs 26 |
| m2 / m5 / m10 / m20, f11 | **0** | (subset of today) |

Against today's *effective* Dict 63 (exempt, so 0 fires): the floor-11 points add clean fires in 63 Desktop (13-18) and 63 Linux (14).

Dict 63, all groups: today 202 recorded fires, 59.4% High; m20 f11 171 (56.7%); m2 f11 200 (60.0%); floor 5: 435-599 (40-45% High).

### Dict 63 Linux fleet group (Figma)

| Rule | Fires | High | Verified | Clean |
|---|---|---|---|---|
| Today (recorded, exempt) | 14 | 0 | 12 | 14 |
| any m, floor 5 | 27 | 0 | 24 | 27 |
| any m, floor 11 | 14 | 0 | 12 | 14 |

The multiplier makes no difference here. The cell's signature has (almost) no share in the 7-day base, so the floor decides. This is the Dict 63 Linux cell as a whole; I did not re-check that every fire is the single Firefox 156 / junta de andalucia signature from v2 (v2: 25 fires).

## Blizzard ROW Registration K2, 9-12 Nov 2026 (209,927 sessions, 3 days)

| Rule | Fires | High % | Verified % | Challenged % | Chall. not solved % | Clean fires (%) | New-only | Lost vs today | Nonlegit caught (9 Nov) | Nonlegit only by new rule | G8 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Today (ST 25) | 35,464 | 97.2 | 2.8 | 97.2 | 32.1 | 974 (2.7) | | | 4 | | |
| m2 f5 | 48,464 | 96.5 | 4.7 | 97.4 | 37.5 | 986 (2.0) | 14,048 | 1,048 | 490 | 486 | FAIL (clean 986 > 974) |
| m5 f5 | 47,443 | 97.1 | 3.8 | 98.0 | 37.2 | 790 (1.7) | 13,027 | 1,048 | 488 | 484 | PASS |
| m10 f5 | 46,431 | 97.3 | 3.5 | 98.1 | 36.5 | 730 (1.6) | 12,015 | 1,048 | 483 | 479 | PASS |
| m20 f5 | 45,333 | 97.7 | 3.0 | 98.4 | 36.4 | 605 (1.3) | 10,917 | 1,048 | 477 | 473 | PASS |
| m2 f11 | 39,481 | 99.1 | 1.1 | 99.4 | 35.3 | 194 (0.5) | 5,065 | 1,048 | 141 | 137 | PASS |
| m5 f11 | 39,336 | 99.3 | 0.9 | 99.5 | 35.3 | 173 (0.4) | 4,920 | 1,048 | 141 | 137 | PASS |
| m10 f11 | 39,272 | 99.3 | 0.8 | 99.5 | 35.3 | 172 (0.4) | 4,856 | 1,048 | 141 | 137 | PASS |
| m20 f11 | 39,070 | 99.4 | 0.8 | 99.6 | 35.2 | 158 (0.4) | 4,654 | 1,048 | 141 | 137 | PASS |

- Today ST or LT: 36,725 fires (974 clean). Today's LT also caught none of the 9 Nov Nonlegit labels beyond the 4 the ST caught.
- Lost vs today (1,048 in every grid point) is mostly the Dict 63 "Other" cell: 251 fires on 9 Nov, 0 High, 250 verified, all clean. One very common signature, so its expected count is high. The other days were not broken down by cell.
- Nonlegit caught uses only the 9 Nov labels (3,670 of 5,718). None of today's 4 catches is lost under any grid point.

Skipped on Blizzard, 9 Nov: 851 sessions (A 804, C 47; today fired 28 of them). Dict -1: 1 session.

### G7 per cell, Blizzard (9 Nov only)

Today fires on clean traffic in one cell only (63 Other, 251), so any clean fire elsewhere fails its cell.

| Rule | Failing cells | Largest |
|---|---|---|
| m2 f5 | 15 | 31 Desktop 181; 63 Mobile 59; 7 Desktop 29; 15 Desktop 26 |
| m5 f5 | 13 | 31 Desktop 174; 7 Desktop 25; 15 Desktop 26; 63 Mobile 24 |
| m10 f5 | 13 | 31 Desktop 173; 15 Desktop 26; 7 Desktop 24; 63 Mobile 14 |
| m20 f5 | 13 | 31 Desktop 172; 15 Desktop 26; 7 Desktop 15; 63 Mobile 9 |
| m2 f11 | 6 | 31 Desktop 50; 15 WinRDVM 2; 63 Desktop 2; 63 WinRDVM 2; 7 WinRDVM 1; 63 Mobile 1 |
| m5 / m10 / m20 f11 | 4 | 31 Desktop 50; 15 WinRDVM 2; 63 WinRDVM 2; 7 WinRDVM 1 |

Dict 63 fires on 9 Nov: m20 f11 10 (60% High); m2 f5 282 (59% High). Today: 251 (0% High, all in 63 Other).
