# Layer 1: first run (v1) vs Seen-before rules (v2)

Same key, window, whitelist, weights, partial credit, bands and Basic Render rule in both runs. **The similarity score of every session is identical in v1 and v2** (the closest-device search did not change), so every v1 → v2 move is a session entering or leaving Band D through the check trigger. The v1 numbers below were recomputed inside the same query (`q1_crosstab_gates.sql`, `X1` rows) and match the first run's published numbers exactly, cell by cell, including G3.

"v1" = the first layer-1 run (`../2026-11-25_layer-1/`), not the JA4 ⅔-credit fix inside it (that fix is kept in both).

## 1. Crosstabs side by side (sessions, row %)

| Today | v1 A | v2 A | v1 B | v2 B | v1 C | v2 C | v1 D | v2 D | Total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 63 | **4,759 (94.7%)** | **4,762 (94.8%)** | 228 (4.5%) | 230 (4.6%) | 1 (0.0%) | 2 (0.0%) | 35 (0.7%) | 29 (0.6%) | 5,023 |
| 31 | 811 (55.2%) | 830 (56.5%) | **484 (32.9%)** | **512 (34.8%)** | 55 (3.7%) | 70 (4.8%) | 120 (8.2%) | 58 (3.9%) | 1,470 |
| 15 | 370 (35.1%) | 375 (35.5%) | **426 (40.4%)** | **466 (44.2%)** | 53 (5.0%) | 117 (11.1%) | 206 (19.5%) | 97 (9.2%) | 1,055 |
| 7 | 224 (19.7%) | 259 (22.8%) | 272 (23.9%) | 507 (44.6%) | **55 (4.8%)** | **169 (14.9%)** | 587 (51.6%) | 203 (17.8%) | 1,138 |
| 3 | 119 (26.7%) | 120 (26.9%) | 164 (36.8%) | 173 (38.8%) | 41 (9.2%) | 62 (13.9%) | **122 (27.4%)** | **91 (20.4%)** | 446 |
| 1 | 9 (39.1%) | 9 (39.1%) | 6 (26.1%) | 6 (26.1%) | 3 (13.0%) | 3 (13.0%) | **5 (21.7%)** | **5 (21.7%)** | 23 |
| -1 | 0 | 1 (100%) | 0 | 0 | 0 | 0 | **1 (100%)** | **0** | 1 |
| **All** | 6,292 (68.7%) | 6,356 (69.4%) | 1,580 (17.3%) | 1,894 (20.7%) | 208 (2.3%) | 423 (4.6%) | 1,076 (11.8%) | 483 (5.3%) | 9,156 |

| Share | v1 | v2 |
|---|---:|---:|
| Same bucket | 5,852 (63.9%) | 6,005 (65.6%) |
| Moved up | 2,019 (22.1%) | 2,345 (25.6%) |
| Moved down | 1,285 (14.0%) | 806 (8.8%) |
| Promoted (1/3 → A/B) | 298 | 308 |
| Demoted (63/31/15 → D) | 361 | 184 |
| Band D total | 1,076 | 483 |

## 2. Flow table: sessions whose band changed between v1 and v2

**671 of 9,156 sessions (7.3%) changed band; 632 left Band D, 39 entered it.** Attribution is sequential (rules applied in the order platform grouping → coarse pairs → OS version → device_params warning; the step at which the band changed is the cause). No session changed band at more than one step.

| Today | v1 → v2 | Platform grouping | Coarse pairs | OS version | device_params warning | Total | High risk |
|---|---|---:|---:|---:|---:|---:|---:|
| 63 | D → A / B / C | | 2 / 0 / 0 | | 1 / 6 / 1 | 10 | 0 |
| 63 | B → D | 4 | | | | 4 | 0 |
| 31 | D → A / B / C | | 20 / 4 / 4 | | 2 / 27 / 11 | 68 | 0 |
| 31 | A / B → D | 3 / 3 | | | | 6 | 0 |
| 15 | D → A / B / C | | 5 / 31 / 51 | | 4 / 17 / 14 | 122 | 18 (14.8%) |
| 15 | A / B / C → D | | 4 / 8 / 1 | | | 13 | 3 (23.1%) |
| 7 | D → A / B / C | | 14 / 52 / 44 | | 22 / 185 / 75 | 392 | 22 (5.6%) |
| 7 | A / B / C → D | 1 / 2 / 3 | 0 / 0 / 2 | | | 8 | 1 |
| 3 | D → A / B / C | | 0 / 11 / 6 | 1 / 1 / 0 | 0 / 4 / 16 | 39 | 1 |
| 3 | B / C → D | 3 / 0 | 4 / 1 | | | 8 | 0 |
| -1 | D → A | | | 1 | | 1 | 0 |
| **All** | | **19** (all into D) | **264** (244 out, 20 into D) | **3** (out of D) | **385** (out of D) | **671** | **45 (6.7%)** |

By rule change:

| Rule change | Sessions moved | Direction | High risk | Verified | Challenged | Challenged, not solved |
|---|---:|---|---:|---:|---:|---:|
| device_params never seen on desktop → warning only | 385 | out of D | 19 (4.9%) | 88.1% | 28.8% | 10.4% |
| Coarse pair values | 244 | out of D | 22 (9.0%) | 86.5% | 32.0% | 9.0% |
| Coarse pair values | 20 | into D | 3 (15.0%) | 80.0% | 30.0% | 15.0% |
| Platform grouping | 19 | into D | 1 (5.3%) | 84.2% | 31.6% | 15.8% |
| OS version rule | 3 | out of D | 0 | 100% | 0% | 0% |

What each rule did (top combinations from `q2_flow_reasons_result.txt`, `FC` rows):
- **device_params warning (385):** sessions that were D in v1 only because "DP never seen" counted as a failed check plus the never-seen extra. Now they keep their score band: mostly B (DP differs from the closest device; 208 sessions, 11 High), JA4qt+DP 48 (0 High), SCR+DP 25.
- **Coarse pairs, out of D (244):** v1 failures of the exact pairs UAxDP + SCRxDP (50 sessions, **16 High**) and SCRxDP + SCRxGL (49 sessions, 0 High) now pass because the coarse (platform, depth, cores, touch) device_params or browser/major UA was seen with that screen / UA.
- **Coarse pairs, into D (20):** mostly mobile sessions where v1 skipped UAxDP because the exact UA was never seen; v2 checks it at browser/major level and it fails (17 sessions `chk:UAxDP`, 3 High). Plus 4 Dict 15 sessions that were Band A in v1 (3 High).
- **Platform grouping (19, all into D):** because Windows + Basic Render now forms its own group (Windows RD/VM), a screen seen on hardware-GPU Windows but never on a Basic Render device fails screen × platform group (8 sessions `[BRD]chk:SCRxPG +SCRnew`, 0 High); the rest are pair checks that v1 satisfied with whitelist devices of the same OS family that now sit in a different group (e.g. a Basic Render or software-renderer Windows device), so they no longer count (6 `SCRxDP SCRxGL`, 0 High). 1 of 19 is High risk.
- **OS version (3):** 3 sessions (2 iOS with older unseen versions, 1 Dict -1 iOS 17.1 session) were D in v1 only because of the OS version failed check.

## 3. Sessions that moved vs did not

| Group | Sessions | High risk | Verified | Challenged | Challenged, not solved |
|---|---:|---:|---:|---:|---:|
| Moved between v1 and v2 | 671 | **6.7%** (45) | 87.2% | 30.0% | 10.1% |
| Did not move | 8,485 | 4.6% (391) | 93.3% | 23.7% | 5.7% |
| (Moved out of D) | 632 | 6.5% (41) | 87.5% | 29.9% | 9.8% |
| (Moved into D) | 39 | 10.3% (4) | 82.1% | 30.8% | 15.4% |

The sessions released from Band D are somewhat riskier than average traffic (6.5% vs 4.6% High, 87.5% vs 93.3% verified), mainly because of the coarse-pair releases on Dict 15 (below). The device_params-warning releases (4.9% High) are close to the key's average.

## 4. The v1 Dict 15 subgroup: UAxDP + SCRxDP (51 sessions, 16 High = 31%)

| v2 band | v2 reason | Sessions | High risk | Verified | Challenged | Challenged, not solved |
|---|---|---:|---:|---:|---:|---:|
| A | DP differs | 1 | 0 | 1 | 0 | 0 |
| B | DP differs (score 0.70) | 14 | **8** | 8 | 9 | 5 |
| B | other (JA4qt+DP, UA+DP, UA+SCR) | 6 | 0 | 6 | 0 | 0 |
| C | UA + DP differ | 16 | **8** | 9 | 11 | 1 |
| C | other | 6 | 0 | 4 | 3 | 2 |
| D | still UAxDP + SCRxDP (coarse) | 9 | 0 | 9 | 5 | 0 |
| D | SCRxPG + SCRnew + DPnew | 1 | 0 | 1 | 1 | 0 |

**All 16 High-risk sessions left Band D** (8 to B, 8 to C); the 10 that stay in D are all Low/Medium. The move is caused by the coarse pair values: once device_params is reduced to platform / colour depth / cores / touch and the UA to browser/major, these sessions' pairs have been seen before. Whatever separated them in v1 sat in the parts the coarse key drops (font hash, storage/cookie flags) or in the exact UA string. This is consistent with the coarse key losing the one check signal v1 had, but 16 sessions is too few to conclude; examples of this subgroup were not fetched (see `caveats.md`).

## 5. G3: do the checks separate risk? (High-risk rate, Band D by checks vs passing)

| | v1 D by checks | v1 passes | v1 ratio | v2 D by checks | v2 passes | v2 ratio |
|---|---:|---:|---:|---:|---:|---:|
| Desktop (v1: Windows, macOS, ChromeOS, Linux, other OS; v2: Desktop, Linux, Windows RD/VM, Other groups) | 61/976 = 6.2% | 317/6,713 = 4.7% | 1.3x | 18/348 = 5.2% | 360/7,341 = 4.9% | **1.05x** |
| Mobile (v1: iOS, iPadOS, Android; v2: Mobile group) | 10/97 = 10.3% | 48/1,370 = 3.5% | 2.9x | 12/94 = 12.8% | 46/1,373 = 3.4% | **3.8x** |
| Challenged-not-solved, desktop | 7.9% | 5.1% | | 4.9% | 5.5% | |
| Challenged-not-solved, mobile | 11.3% | 8.6% | | 12.8% | 8.5% | |

- **Desktop:** v2 fires 64% less (348 vs 976 sessions) but separates risk less (1.05x vs 1.3x). The desktop checks that remain are mostly SCRxDP + SCRxGL on new window sizes (0-3 High per cell). The pocket that did carry risk on desktop is now the **Other** group (software renderers on Windows / OS X, 11 of 44 D sessions High), not the pair checks.
- **Mobile:** slightly better separation (3.8x), on 94 sessions. Mobile rules barely changed (DP never seen is still a failed check on mobile).
- G3 still fails for desktop and stays borderline for mobile (small n). "Several times more often bad" is not met on desktop.
