# Crosstab: today's DI dictionary x `ja4_sim_v1` band (standalone / layer 1)

Figma Registration K2 (`A207F8A1-ED09-4325-ACE6-C8E26A458FBA`), sessions created **2026-11-20 12:00-14:00 UTC**, **all 9,156 sessions (no sampling)**. Whitelist = **uncleaned** distinct Dict 63 signatures on this key, 13-20 Nov (65,959 signatures). Query: `crosstab_and_drivers.sql`; raw result: `crosstab_and_drivers_result.txt`.

Rates are session rates within each cell. "Verified" = `sessions_verified > 0`; "High risk" = `latest_risk_band = 'High'`; "Challenged" = `was_challenged > 0`; "Challenged, not solved" = challenged and `sessions_solved = 0`. "Exact match" = score 1.0 (the session's full signature is on the whitelist).

## Counts and row %

| Today's dict | Band A | Band B | Band C | Band D | No score | Impossible (not applied in standalone mode) | Row total |
|---|---|---|---|---|---|---|---|
| 63 | 4,759 (94.7%) *agree* | 228 (4.5%) *other* | 1 (0.0%) *other* | 35 (0.7%) *demoted* | 0 | (empty) | 5,023 |
| 31 | 811 (55.2%) *other* | 484 (32.9%) *agree* | 55 (3.7%) *other* | 120 (8.2%) *demoted* | 0 | (empty) | 1,470 |
| 15 | 370 (35.1%) *other* | 426 (40.4%) *agree* | 53 (5.0%) *other* | 206 (19.5%) *demoted* | 0 | (empty) | 1,055 |
| 7 | 224 (19.7%) *other* | 272 (23.9%) *other* | 55 (4.8%) *agree* | 587 (51.6%) *other* | 0 | (empty) | 1,138 |
| 3 | 119 (26.7%) *promoted* | 164 (36.8%) *promoted* | 41 (9.2%) *other* | 122 (27.4%) *agree* | 0 | (empty) | 446 |
| 1 | 9 (39.1%) *promoted* | 6 (26.1%) *promoted* | 3 (13.0%) *other* | 5 (21.7%) *agree* | 0 | (empty) | 23 |
| -1 | 0 (0.0%) *other* | 0 (0.0%) *other* | 0 (0.0%) *other* | 1 (100.0%) *agree* | 0 | (empty) | 1 |
| **All** | **6,292 (68.7%)** | **1,580 (17.3%)** | **208 (2.3%)** | **1,076 (11.8%)** | 0 | (empty) | **9,156** |

## Outcome rates per cell

| Today's dict | New band | Label | Sessions | Verified | High risk | Challenged | Challenged, not solved | Exact match (score 1.0) | Mean score |
|---|---|---|---|---|---|---|---|---|---|
| 63 | A | agree | 4,759 | 94.1% | 3.4% | 20.7% | 5.0% | 4,255 | 0.989 |
| 63 | B | other | 228 | 94.3% | 4.8% | 20.2% | 5.7% | 87 | 0.848 |
| 63 | C | other | 1 | 100.0% | 0.0% | 0.0% | 0.0% | 0 | 0.400 |
| 63 | D | demoted | 35 | 94.3% | 5.7% | 31.4% | 5.7% | 0 | 0.710 |
| 31 | A | other | 811 | 92.5% | 5.3% | 26.8% | 5.5% | 4 | 0.895 |
| 31 | B | agree | 484 | 94.2% | 5.6% | 24.6% | 4.8% | 22 | 0.746 |
| 31 | C | other | 55 | 92.7% | 9.1% | 16.4% | 3.6% | 0 | 0.548 |
| 31 | D | demoted | 120 | 97.5% | 1.7% | 13.3% | 2.5% | 0 | 0.710 |
| 15 | A | other | 370 | 91.6% | 7.3% | 34.1% | 7.8% | 1 | 0.896 |
| 15 | B | agree | 426 | 89.9% | 7.5% | 31.0% | 8.2% | 0 | 0.764 |
| 15 | C | other | 53 | 84.9% | 13.2% | 47.2% | 13.2% | 0 | 0.540 |
| 15 | D | demoted | 206 | 91.3% | 8.7% | 25.2% | 5.3% | 0 | 0.604 |
| 7 | A | other | 224 | 91.5% | 4.0% | 26.3% | 7.1% | 1 | 0.916 |
| 7 | B | other | 272 | 91.5% | 2.6% | 26.8% | 6.6% | 0 | 0.744 |
| 7 | C | agree | 55 | 85.5% | 16.4% | 40.0% | 12.7% | 0 | 0.534 |
| 7 | D | other | 587 | 89.1% | 6.1% | 26.4% | 9.0% | 0 | 0.610 |
| 3 | A | promoted | 119 | 90.8% | 10.9% | 37.8% | 9.2% | 0 | 0.907 |
| 3 | B | promoted | 164 | 93.3% | 3.7% | 32.3% | 5.5% | 0 | 0.719 |
| 3 | C | other | 41 | 87.8% | 12.2% | 36.6% | 9.8% | 0 | 0.545 |
| 3 | D | agree | 122 | 83.6% | 10.7% | 36.1% | 15.6% | 0 | 0.562 |
| 1 | A | promoted | 9 | 88.9% | 11.1% | 22.2% | 11.1% | 0 | 0.883 |
| 1 | B | promoted | 6 | 66.7% | 16.7% | 50.0% | 33.3% | 0 | 0.743 |
| 1 | C | other | 3 | 100.0% | 0.0% | 33.3% | 0.0% | 0 | 0.514 |
| 1 | D | agree | 5 | 100.0% | 0.0% | 60.0% | 0.0% | 0 | 0.346 |
| -1 | D | agree | 1 | 100.0% | 0.0% | 0.0% | 0.0% | 0 | 0.850 |

Per-dictionary baseline (all bands):

| Today's dict | Sessions | Share | Verified | High risk | Challenged | Challenged, not solved |
|---|---|---|---|---|---|---|
| 63 | 5,023 | 54.86% | 94.1% | 3.5% | 20.7% | 5.0% |
| 31 | 1,470 | 16.06% | 93.5% | 5.2% | 24.6% | 5.0% |
| 15 | 1,055 | 11.52% | 90.5% | 8.0% | 31.8% | 7.8% |
| 7 | 1,138 | 12.43% | 90.0% | 5.4% | 27.2% | 8.3% |
| 3 | 446 | 4.87% | 89.5% | 8.3% | 35.2% | 9.6% |
| 1 | 23 | 0.25% | 87.0% | 8.7% | 39.1% | 13.0% |
| -1 | 1 | 0.01% | 100.0% | 0.0% | 0.0% | 0.0% |

The dictionary shares match the run 1 baseline exactly (63: 54.9%, 31: 16.1%, 15: 11.5%, 7: 12.4%, 3: 4.9%, 1: 0.25%, -1: 0.01%).

## How Band D arises

1,073 of the 1,076 Band D sessions are Band D because of the **consistency-check trigger** (failed pair checks / never-seen device_params), not a low score. Only 3 sessions are Band D by score < 0.40. Mean score of Band D sessions is 0.62, i.e. most of them would be Band B/C on similarity alone.

| Group | Sessions | High risk | Challenged | Challenged, not solved |
|---|---|---|---|---|
| Desktop, passes checks | 6,713 | 4.7% | 23.6% | 5.1% |
| Desktop, Band D by checks | 976 | 6.3% | 26.1% | 7.9% |
| Mobile, passes checks | 1,370 | 3.5% | 25.4% | 8.6% |
| Mobile, Band D by checks | 97 | 10.3% | 26.8% | 11.3% |
