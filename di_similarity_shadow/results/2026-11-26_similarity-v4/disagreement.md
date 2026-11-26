# Disagreement report: today's DI vs similarity v4

**Same bucket 64.6%, moved up 27.7%, moved down 7.7%** (9,156 sessions, Figma Registration K2, 20 Nov 12:00-14:00 UTC).

## Main result: identical to v3

With the measured cut-offs, v4 puts every session in the same band as v3 (0 differences, `REGX` in `q3_stats_result.txt`). Every cell of
the comparison table, its label (agree / moved up / moved down / promoted / demoted), its verify, High-risk and challenge rates, its top
reasons and its example sessions are therefore those of `../2026-11-25_layer-1-v3/disagreement.md`; they were not re-queried. The only
change v4 makes is in the warning signs it **reports** on mobile (88 sessions now carry a frequency-graded rare screen pair; mobile warning
signs never move a band). Truth data: not used (as in v3).

How to read the cells, for a reader new to DI: rows are today's dictionary match (63 = all six signature fields match a known device; 1 = only
the OS matches; -1 = nothing); columns are the similarity band (A = very close to a known device ... D = far from any known device, or failed
consistency checks). "Agree" = 63→A, 31/15→B, 7→C, 3/1/-1→D. "Moved up" = similarity trusts the session more than today; "moved down" = less.
"Promoted" = today 1/3 → A/B (today's DI misses a known device, usually because one field drifted); "demoted" = today 63/31/15 → D.

## What-if a + b + c: the cells that change (vs v4)

Only Band D grows (no session leaves D, because sessions freed by c stay in D through b). Added sessions by today's dictionary:

| Today → D | v4 | v4 + a + b + c | Added | Label | High in added (approx.) |
|---|---:|---:|---:|---|---|
| 63 → D | 13 (1 H) | 23 (5 H) | +10 | moved down / demoted | 4 of 10 |
| 31 → D | 56 (3 H) | 95 (8 H) | +39 | moved down / demoted | 5 of 39 |
| 15 → D | 107 (4 H) | 221 (38 H) | +114 | moved down / demoted | 34 of 114 (30%) |
| 7 → D | 197 (11 H) | 262 (20 H) | +65 | moved down | 9 of 65 |
| 3 → D | 89 (11 H) | 127 (16 H) | +38 | agree (was A/B/C) | 5 of 38 |

"High in added" = High in the what-if cell minus High in the v4 cell (no session leaves D, so the difference is the added sessions).
Demoted (63/31/15 → D) rises from 176 to 339; promoted (1/3 → A/B) falls from 333 to 314. Reasons for the added sessions: trigger a (coarse
UA × device_params never seen) 163 sessions, 38 High; trigger b (2+ warning signs, mostly the exact UA×DP + screen×DP pair) 103, 19 High
(counts from the `FL` rows; a session can carry both). 12 example sessions: `q4_examples_result.txt` (IN rows); 20 not reached (response cap).
Verify and challenge rates for the what-if cells were not queried.
