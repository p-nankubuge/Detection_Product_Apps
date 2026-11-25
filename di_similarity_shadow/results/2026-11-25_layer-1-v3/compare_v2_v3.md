# Layer 1: v1 vs v2 vs v3

Same key (Figma Registration K2), window (20 Nov 12:00-14:00 UTC, all 9,156 sessions), weights, partial credit, bands, Basic Render
rule, JA4 2/3 fix and platform groups in all three. v1 and v2 numbers are from `../2026-11-25_layer-1/` and `../2026-11-25_layer-1-v2/`;
the v2 bands were also **recomputed inside the v3 queries and match the published v2 crosstab cell by cell** (X2 rows in
`q1_crosstab_gates_result.txt`), and G3 v1/v2 match too, so the v2 -> v3 differences below come from the v3 rule changes plus the
whitelist scope change (one extra Login Production Dict 63 session; see `caveats.md`).

What changed in v3: (1) **null fix** (item 9 / D-10), (2) **physical screen in scoring** (item 6 / D-8), (3) **physical screen in the
checks**, (4) **two-level pair checks** (item 5 / D-9). Unlike v1 -> v2, scores change in v3: 984 sessions (10.7%) got a different
score (947 up, 37 down), all through (1) and (2).

## 1. Crosstabs side by side (sessions, row %)

| Today | v1 A | v2 A | v3 A | v1 B | v2 B | v3 B | v1 C | v2 C | v3 C | v1 D | v2 D | v3 D | Total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 63 | **4,759** (94.7%) | **4,762** (94.8%) | **4,816** (95.9%) | 228 | 230 | 192 | 1 | 2 | 2 | 35 | 29 | 13 | 5,023 |
| 31 | 811 | 830 | 874 (59.5%) | **484** (32.9%) | **512** (34.8%) | **481** (32.7%) | 55 | 70 | 59 | 120 | 58 | 56 | 1,470 |
| 15 | 370 | 375 | 461 (43.7%) | **426** (40.4%) | **466** (44.2%) | **406** (38.5%) | 53 | 117 | 81 | 206 | 97 | 107 | 1,055 |
| 7 | 224 | 259 | 337 (29.6%) | 272 | 507 | 486 | **55** (4.8%) | **169** (14.9%) | **118** (10.4%) | 587 | 203 | 197 | 1,138 |
| 3 | 119 | 120 | 206 (46.2%) | 164 | 173 | 110 | 41 | 62 | 41 | **122** (27.4%) | **91** (20.4%) | **89** (20.0%) | 446 |
| 1 | 9 | 9 | 11 | 6 | 6 | 6 | 3 | 3 | 2 | **5** | **5** | **4** | 23 |
| -1 | 0 | 1 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | **1** | **0** | **0** | 1 |
| **All** | 6,292 (68.7%) | 6,356 (69.4%) | 6,705 (73.2%) | 1,580 (17.3%) | 1,894 (20.7%) | 1,682 (18.4%) | 208 (2.3%) | 423 (4.6%) | 303 (3.3%) | 1,076 (11.8%) | 483 (5.3%) | 466 (5.1%) | 9,156 |

| Share | v1 | v2 | v3 |
|---|---:|---:|---:|
| Same bucket | 63.9% | 65.6% | **64.6%** (5,914) |
| Moved up | 22.1% | 25.6% | **27.7%** (2,535) |
| Moved down | 14.0% | 8.8% | **7.7%** (707) |
| Promoted (1/3 -> A/B) | 298 | 308 | **333** |
| Demoted (63/31/15 -> D) | 361 | 184 | **176** |
| Band D total | 1,076 | 483 | **466** |

"Same bucket" falls slightly in v3 because physical-screen scoring lifts many Dict 31/15 sessions from B to A (counted as "moved up").

## 2. Flow v2 -> v3, by cause

**716 of 9,156 sessions (7.8%) changed band.** Attribution is sequential in the order null fix -> physical screen in scoring ->
physical screen in checks -> two-level pairs; the step at which the band changed is the cause. 4 sessions changed at two steps
(listed separately). Source: `q2_flow_warnings_result.txt` (FL rows), `q3b_flow_checks_result.txt` (FC rows).

| Cause | Direction | Sessions | High risk | Verified | Challenged | Ch. not solved |
|---|---|---:|---:|---:|---:|---:|
| Null fix | one band down (A->B 32, B->C 1, -1: A->B 1) | 34 | 0 | 97.1% | 11.8% | 2.9% |
| Physical screen in scoring | up (B->A 312, C->B 59, C->A 16) | 387 | 10 (2.6%) | 95.3% | 24.5% | 4.1% |
| Physical screen in scoring | out of D (D->C/B by score) | 5 | 0 | 80.0% | 0% | 0% |
| Physical screen in checks | out of D | 151 | 7 (4.6%) | 96.7% | 21.2% | 2.6% |
| Physical screen in checks | into D | 47 | 0 | 93.6% | 31.9% | 6.4% |
| Two-level pairs | into D | 88 | 3 (3.4%) | 96.6% | 20.5% | 3.4% |
| Scoring + checks / scoring + two-level | into D | 4 | 0 | | | |
| **All** | | **716** | **20 (2.8%)** | 95.7% | 23.0% | 3.8% |

What each change did (top reason pairs, FC rows):
- **Null fix (34):** all 34 had `diff:UAmaj` in v2, i.e. ½ UA credit from two unparsed UAs (`HASH(NULL)=HASH(NULL)`); now `diff:UA`,
  score −0.075 to −0.10, one band down. 0 High. In v2, 39 sessions' closest device used this credit; 37 changed score, 34 changed band.
- **Physical screen in scoring (392):** sessions whose screen differed from the closest device only in the available (window) size now
  get full screen credit: `diff:SCR => exact` (75), `diff:UA => exact` (65, a different closest device), `JA4qt+SCR => JA4qt` (28).
  Mostly B->A. 10 High (2.6%).
- **Physical screen in checks, out of D (151):** v2 Band D by `SCRxDP SCRxGL` (or `SCRxPG +SCRnew`) on a never-seen full screen string;
  the physical size has been seen with that DP / WebGL, so the checks pass (e.g. `chk:SCRxDP SCRxGL => exact`, 42). 7 High.
- **Physical screen in checks, into D (47):** in v2 the full screen string was never seen, so (by "never both") no screen pair check
  ran and the session only had a warning; with the physical size seen, the pair checks now run and fail (`diff:SCR => chk:SCRxDP SCRxGL`).
  0 High.
- **Two-level pairs, into D (88):** desktop sessions with one coarse failure (almost always `SCRxGL`) plus an exact-only pair warning
  (`SCRxDPx` or `UAxDPx`), which now completes the desktop trigger (1 failed check + 1 warning sign). 3 High (3.4%).

## 3. Sessions that moved vs did not (v2 -> v3)

| Group | Sessions | High risk | Verified | Challenged | Ch. not solved |
|---|---:|---:|---:|---:|---:|
| Moved | 716 | 2.8% (20) | 95.7% | 23.0% | 3.8% |
| Did not move | 8,440 | 4.9% (416) | 92.6% | 24.2% | 6.2% |
| (Moved into D) | 139 | 2.2% (3) | 95.7% | 24.5% | 4.3% |
| (Moved out of D) | 156 | 4.5% (7) | 96.2% | 20.5% | 2.6% |
| (Other moves) | 421 | 2.4% (10) | 95.5% | 23.5% | 4.0% |

The sessions v3 moves are lower risk than average traffic. The 139 sessions v3 adds to Band D are 2.2% High (below the 4.9% of
unmoved sessions), so the new D entries do not concentrate risk.

## 4. The v1 Dict 15 group (UAxDP + SCRxDP failures)

Sessions today at Dict 15 that were Band D in v1 by exactly `UAxDP SCRxDP`. The query finds **53 sessions, 16 High**; the v2 report
says 51 but its own table sums to 53 (16 High in both).

| v3 band | v3 failed checks | v3 warning signs | Sessions | High | Verified | Challenged | Ch. not solved |
|---|---|---|---:|---:|---:|---:|---:|
| A | none | UAxDPx | 3 | 0 | 3 | 0 | 0 |
| B | none | **UAxDPx + SCRxDPx** | 15 | **8** | 9 | 9 | 5 |
| B | none | UAxDPx | 5 | 0 | 4 | 1 | 1 |
| B | UAxDP | none | 2 | 0 | 2 | 0 | 0 |
| B | none | DPnew | 1 | 0 | 1 | 0 | 0 |
| C | none | **UAxDPx + SCRxDPx** | 14 | **8** | 7 | 10 | 1 |
| C | none | UAxDPx / DPnew / (UAxDP fail) | 6 | 0 | 5 | 4 | 1 |
| D | UAxDP + SCRxDP (coarse) | none | 7 | 0 | 7 | 5 | 0 |

**All 16 High-risk sessions are outside Band D in v3 (8 B, 8 C), as in v2.** In v3 every one of them carries **both** exact-only pair
warnings (UAxDPx and SCRxDPx) and **no failed check**, so under D-9 option 3 (chosen) they cannot reach Band D. 8 of 29 sessions with
that warning pattern in this group are High (28%). The 7 that stay in D (coarse failures) are all Low/Medium.

## 5. G3: High-risk rate, Band D by check trigger vs passing

| | v1 D by checks | v1 passes | v1 ratio | v2 D by checks | v2 passes | v2 ratio | v3 D by checks | v3 passes | v3 ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Desktop (all non-Mobile groups) | 61/976 = 6.2% | 317/6,713 = 4.7% | 1.3x | 18/348 = 5.2% | 360/7,341 = 4.9% | 1.05x | 11/316 = 3.5% | 367/7,373 = 5.0% | **0.70x** |
| Mobile | 10/97 = 10.3% | 48/1,370 = 3.5% | 2.9x | 12/94 = 12.8% | 46/1,373 = 3.4% | 3.8x | 11/95 = 11.6% | 47/1,372 = 3.4% | **3.4x** |

(v1 uses the v1 OS-family mobile flag; v2/v3 the platform group.) On desktop, sessions that v3 puts in Band D by the check trigger are
*less* often High risk than sessions that pass. Mobile is still about 3.4x, on 95 sessions.

## 6. High risk by number of failed checks and warning signs (evidence for D-9)

Scored sessions. Desktop = all non-Mobile groups; desktop warning signs = never-seen screen + never-seen DP + exact-only UAxDP +
exact-only SCRxDP. Mobile warning signs = the two exact-only pair mismatches only (reported, never trigger D). Source: WF / WX rows.

**All warning signs:**

| Failed checks | Warnings | Desktop n | Desktop High | Mobile n | Mobile High |
|---|---|---:|---:|---:|---:|
| 0 | 0 | 5,964 | 249 (4.2%) | 1,360 | 47 (3.5%) |
| 0 | 1 | 954 | 55 (5.8%) | 9 | 0 |
| 0 | 2 | 114 | **22 (19.3%)** | 3 | 0 |
| 0 | 3+ | 0 | | 0 | |
| 1 | 0 | 341 | **41 (12.0%)** (not D) | 72 | 10 (13.9%) (D) |
| 1 | 1 | 149 | 3 (2.0%) (D) | 1 | 0 (D) |
| 1 | 2 | 47 | 6 (12.8%) (D) | 2 | 1 (D) |
| 2+ | 0 | 109 | 2 (1.8%) (D) | 20 | 0 (D) |
| 2+ | 1 | 11 | 0 (D) | 0 | |

**Exact-only pair warnings only (UAxDPx, SCRxDPx):**

| Failed checks | Exact-pair warnings | Desktop n | Desktop High | Mobile n | Mobile High |
|---|---|---:|---:|---:|---:|
| 0 | 0 | 6,543 | 280 (4.3%) | 1,360 | 47 (3.5%) |
| 0 | 1 | 425 | 29 (6.8%) | 9 | 0 |
| 0 | 2 | 64 | **17 (26.6%)** | 3 | 0 |
| 1 | 0 | 437 | 47 (10.8%) | 72 | 10 (13.9%) |
| 1 | 1 | 83 | 2 (2.4%) | 1 | 0 |
| 1 | 2 | 17 | 1 (5.9%) | 2 | 1 |
| 2+ | 0 / 1 | 115 / 5 | 2 / 0 | 20 / 0 | 0 |

By check combination (desktop, FW rows, `q3b_flow_checks_result.txt`):

| Desktop combination | v3 band | n | High |
|---|---|---:|---:|
| **UAxDP (coarse) alone, no warning** | not D | 163 | **38 (23.3%)** |
| **UAxDPx + SCRxDPx, no failed check** | not D | 64 | **17 (26.6%)** |
| UAxDPx alone, no failed check | not D | 280 | 23 (8.2%) |
| SCRxDPx alone, no failed check | not D | 128 | 5 (3.9%) |
| SCRxGL alone, no warning | not D | 144 | 3 (2.1%) |
| SCRxDP + SCRxGL | D | 83 | 2 (2.4%) |
| SCRxGL + SCRxDPx | D | 53 | 2 (3.8%) |
| SCRxGL + DPnew | D | 43 | 0 |
| SCRxPG + SCRnew + DPnew (mostly Other / software renderer) | D | 27 | 5 (18.5%) |
| UAxDP + SCRxDP (+SCRxGL) | D | 24 | 0 |

Reading (indicative, one key, one 2-hour window, "High risk" is not ground truth):
- Two exact-only pair warnings with no failed check: 17 of 64 desktop sessions High (26.6%, vs 4.3% with none). This group contains the
  16 High sessions of the v1 Dict 15 group. This matches the D-9 revisit condition ("2+ warning signs and no failed check have clearly
  higher High risk"). On mobile there are only 3 such sessions.
- One exact-only warning: 6.8% High (425 sessions), close to the baseline.
- The desktop trigger as built fires mostly on SCRxGL combinations, which are about 2-4% High. Meanwhile the highest-risk single
  check, coarse UAxDP alone (23.3% High, 163 sessions), stays out of D because it needs a second check or a warning sign.
- What-if arithmetic from the counts above (not run as a rule): adding "desktop UAxDP alone" and "2 exact-only warnings" to Band D would
  give 543 desktop D-by-check sessions with 66 High (12.2%) vs 4.4% passing (about 2.8x). Changing the rule is a decision for the
  spec owner (D-9); this run reports only.
