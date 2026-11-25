# Crosstab: today's DI dictionary x `ja4_sim_v1` band, layer 1 v2 (Seen-before rules)

Figma Registration K2 (`A207F8A1-ED09-4325-ACE6-C8E26A458FBA`, not a proxy key), sessions created **2026-11-20 12:00-14:00 UTC**, **all 9,156 sessions (no sampling)**. Whitelist = **uncleaned** distinct Dict 63 signatures on this key, sessions created 13 Nov 00:00 to 20 Nov 00:00 UTC (65,959 signatures, 364,042 sessions). Scoring identical to the first layer-1 run; only the "seen before" checks changed (agent file "Seen-before rules"). Query: `q1_crosstab_gates.sql`; raw output: `q1_crosstab_gates_result.txt`.

"Verified" = `sessions_verified > 0`; "High risk" = `latest_risk_band = 'High'`; "Challenged" = `was_challenged > 0`; "Challenged, not solved" = challenged and `sessions_solved = 0`. These are indicators, not ground truth. Bold = same bucket (63→A, 31/15→B, 7→C, 3/1/-1→D); ↑ moved up, ↓ moved down.

## Counts and row % (v2)

| Today | A | B | C | D | No score | Impossible (not applied in standalone) | Total |
|---|---:|---:|---:|---:|---:|---|---:|
| 63 | **4,762 (94.8%)** | 230 (4.6%) ↓ | 2 (0.0%) ↓ | 29 (0.6%) ↓ demoted | 0 | (empty) | 5,023 |
| 31 | 830 (56.5%) ↑ | **512 (34.8%)** | 70 (4.8%) ↓ | 58 (3.9%) ↓ demoted | 0 | (empty) | 1,470 |
| 15 | 375 (35.5%) ↑ | **466 (44.2%)** | 117 (11.1%) ↓ | 97 (9.2%) ↓ demoted | 0 | (empty) | 1,055 |
| 7 | 259 (22.8%) ↑ | 507 (44.6%) ↑ | **169 (14.9%)** | 203 (17.8%) ↓ | 0 | (empty) | 1,138 |
| 3 | 120 (26.9%) ↑ promoted | 173 (38.8%) ↑ promoted | 62 (13.9%) ↑ | **91 (20.4%)** | 0 | (empty) | 446 |
| 1 | 9 (39.1%) ↑ promoted | 6 (26.1%) ↑ promoted | 3 (13.0%) ↑ | **5 (21.7%)** | 0 | (empty) | 23 |
| -1 | 1 (100%) ↑ | 0 | 0 | **0** | 0 | (empty) | 1 |
| **All** | **6,356 (69.4%)** | **1,894 (20.7%)** | **423 (4.6%)** | **483 (5.3%)** | 0 | (empty) | **9,156** |

**Same bucket 6,005 (65.6%) · moved up 2,345 (25.6%) · moved down 806 (8.8%).** (First run: 63.9% / 22.1% / 14.0%.)

## Outcome rates per cell (v2)

| Today | New band | Label | Sessions | Verified | High risk | Challenged | Challenged, not solved | Mean score |
|---|---|---|---:|---:|---:|---:|---:|---:|
| 63 | A | same | 4,762 | 94.1% | 3.4% (162) | 20.7% | 5.0% | 0.989 |
| 63 | B | down | 230 | 93.5% | 4.8% (11) | 21.3% | 6.5% | 0.845 |
| 63 | C | down | 2 | 100% | 0.0% (0) | 50.0% | 0.0% | 0.486 |
| 63 | D | down (demoted) | 29 | 100% | 6.9% (2) | 20.7% | 0.0% | 0.710 |
| 31 | A | up | 830 | 92.5% | 5.2% (43) | 26.9% | 5.5% | 0.895 |
| 31 | B | same | 512 | 94.5% | 5.3% (27) | 23.6% | 4.5% | 0.742 |
| 31 | C | down | 70 | 92.9% | 7.1% (5) | 15.7% | 4.3% | 0.543 |
| 31 | D | down (demoted) | 58 | 98.3% | 3.4% (2) | 10.3% | 1.7% | 0.722 |
| 15 | A | up | 375 | 92.5% | 6.4% (24) | 33.9% | 7.2% | 0.896 |
| 15 | B | same | 466 | 89.7% | 8.6% (40) | 30.7% | 8.4% | 0.758 |
| 15 | C | down | 117 | 83.8% | **14.5% (17)** | 40.2% | 10.3% | 0.530 |
| 15 | D | down (demoted) | 97 | 94.8% | 3.1% (3) | 18.6% | 4.1% | 0.606 |
| 7 | A | up | 259 | 91.5% | 3.9% (10) | 24.3% | 6.9% | 0.909 |
| 7 | B | up | 507 | 87.8% | 4.1% (21) | 28.6% | 9.7% | 0.723 |
| 7 | C | same | 169 | 88.8% | 8.9% (15) | 36.1% | 10.1% | 0.530 |
| 7 | D | down | 203 | 94.6% | 7.4% (15) | 19.7% | 4.9% | 0.511 |
| 3 | A | up (promoted) | 120 | 90.8% | 10.8% (13) | 37.5% | 9.2% | 0.906 |
| 3 | B | up (promoted) | 173 | 93.1% | 3.5% (6) | 33.5% | 5.8% | 0.718 |
| 3 | C | up | 62 | 90.3% | 9.7% (6) | 37.1% | 8.1% | 0.532 |
| 3 | D | same | 91 | 80.2% | 13.2% (12) | 34.1% | 18.7% | 0.559 |
| 1 | A | up (promoted) | 9 | 88.9% | 11.1% (1) | 22.2% | 11.1% | 0.883 |
| 1 | B | up (promoted) | 6 | 66.7% | 16.7% (1) | 50.0% | 33.3% | 0.743 |
| 1 | C | up | 3 | 100% | 0.0% (0) | 33.3% | 0.0% | 0.514 |
| 1 | D | same | 5 | 100% | 0.0% (0) | 60.0% | 0.0% | 0.346 |
| -1 | A | up | 1 | 100% | 0.0% (0) | 0.0% | 0.0% | 0.850 |

Per-dictionary baselines (all bands) are unchanged from the first run (`../2026-11-25_layer-1/crosstab.md`): High risk 63: 3.5%, 31: 5.2%, 15: 8.0%, 7: 5.4%, 3: 8.3%, 1: 8.7%.

## By platform group (v2 band; the platform group is used for every "seen before" lookup)

| Platform group | OS | A | B | C | D | D: High risk |
|---|---|---:|---:|---:|---:|---:|
| Desktop | Windows | 3,800 | 1,144 | 285 | 169 | 10 (5.9%) |
| Desktop | OS X | 1,198 | 301 | 41 | 83 | 1 (1.2%) |
| Desktop | Chrome OS | 95 | 29 | 3 | 6 | 0 |
| Mobile | Android | 631 | 160 | 17 | 91 | 12 (13.2%) |
| Mobile | iOS | 487 | 14 | 0 | 1 | 0 |
| Mobile | iPadOS | 56 | 5 | 0 | 5 | 0 |
| Linux | GNU/Linux | 79 | 28 | 40 | 54 | 0 |
| Linux | Ubuntu | 4 | 8 | 1 | 11 | 0 |
| Windows RD/VM | Windows (Basic Render) | 0 | 197 | 29 | 19 | 0 |
| Other | Windows (software renderer) | 0 | 1 | 2 | 37 | 6 (16.2%) |
| Other | OS X (software renderer) | 0 | 0 | 0 | 4 | **4 (100%)** |
| Other | GNU/Linux (software renderer) | 5 | 7 | 0 | 2 | 1 |
| Other | HarmonyOS / OpenHarmony / Ubuntu | 1 | 0 | 5 | 1 | 0 |

Band D now holds 483 sessions; 44 of them are in the Other group (software renderers), with 11 High risk (25%).

## How Band D arises (v2)

| Group (v2 definition) | Sessions | High risk | Challenged | Challenged, not solved |
|---|---:|---:|---:|---:|
| Desktop-rule groups (Desktop, Linux, Windows RD/VM, Other), passes checks | 7,341 | 4.9% (360) | 24.1% | 5.5% |
| Desktop-rule groups, Band D by checks | 348 | 5.2% (18) | 19.8% | 4.9% |
| Mobile, passes checks | 1,373 | 3.4% (46) | 25.4% | 8.5% |
| Mobile, Band D by checks | 94 | 12.8% (12) | 26.6% | 12.8% |

442 of 483 Band D sessions are D by the check trigger; 41 are D by score (< 0.40).

## No score
0 sessions: every session had an OS and a non-empty device_params. 39 sessions got the UA ½ credit only because both their UA and the closest device's UA failed to parse (see `caveats.md`); scoring was kept identical to the first run on purpose.
