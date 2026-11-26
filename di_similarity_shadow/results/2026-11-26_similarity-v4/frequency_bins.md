# Step 1: pair frequency vs High risk (and proposed cut-offs)

Figma Registration K2, sessions created 2026-11-20 12:00-14:00 UTC, all 9,156 sessions; uncleaned account whitelist (Dict 63, 13-20 Nov,
364,043 sessions). Source: `q1_frequency_bins_result.txt`. "Desktop" = all non-Mobile platform groups (Desktop, Linux, Windows RD/VM, Other).

**Pair frequency** = whitelist sessions that have the session's pair ÷ whitelist sessions in the session's platform group. Whitelist sessions
per group: Desktop 272,232; Mobile 80,573; Windows RD/VM 8,032; Linux 2,842; Other 364. So on Desktop one whitelist session = 3.7e-6, on
Mobile 1.2e-5 (the "< 1e-5" bin is empty on mobile). A session counts in a check only where v3 runs that check (both values seen on their own;
the exact level only where the coarse pair is seen). Sessions appear in several checks, so the rows are not independent.

**Baseline High risk:** desktop 378 / 7,689 = **4.9%**; mobile 58 / 1,467 = **4.0%**. "x" = High rate ÷ baseline.

## Desktop (n sessions, High %, x baseline)

| Bin | UA×DP coarse | UA×DP exact | Screen×DP coarse | Screen×DP exact | Screen×WebGL | Screen×platform group |
|---|---|---|---|---|---|---|
| never (0) | 207, **18.4%, 3.7x** | 406, **10.3%, 2.1x** | 146, 1.4%, 0.3x | 269, **9.3%, 1.9x** | 377, 2.1%, 0.4x | 57, **10.5%, 2.1x** |
| < 1e-5 | 112, 6.3%, 1.3x | 185, 3.2%, 0.7x | 71, 4.2%, 0.9x | 191, 2.1%, 0.4x | 136, 5.9%, 1.2x | 43, 2.3%, 0.5x |
| 1e-5 - 1e-4 | 396, 5.8%, 1.2x | 702, 6.3%, 1.3x | 307, 4.9%, 1.0x | 592, 5.4%, 1.1x | 737, 5.3%, 1.1x | 122, 3.3%, 0.7x |
| 1e-4 - 1e-3 | 942, 6.4%, 1.3x | 1,216, 4.2%, 0.9x | 851, 4.2%, 0.9x | 1,284, 4.8%, 1.0x | 1,749, 6.6%, 1.3x | 149, 4.0%, 0.8x |
| 1e-3 - 1e-2 | 1,955, 4.2%, 0.9x | 2,216, 4.0%, 0.8x | 1,876, 4.2%, 0.9x | 2,463, 5.0%, 1.0x | 3,206, 4.1%, 0.8x | 657, 5.9%, 1.2x |
| ≥ 1e-2 | 3,499, 3.8%, 0.8x | 2,078, 3.3%, 0.7x | 3,737, 5.5%, 1.1x | 2,043, 4.6%, 0.9x | 873, 3.4%, 0.7x | 6,500, 4.8%, 1.0x |

By raw whitelist count (desktop, the smallest bins): UA×DP coarse seen in exactly 1 whitelist session 88 sessions, 8 High (9.1%, 1.9x);
2-4: 108, 4.6%; 5-19: 343, 3.2%. UA×DP exact 1: 144, 1.4%. Screen×DP exact 1: 170, 0.6%. Screen×WebGL 1: 87, 4.6%. Screen×PG 1: 62, 6.5%.

## Mobile (n sessions, High %, x baseline)

| Bin | UA×DP coarse | UA×DP exact | Screen×DP coarse | Screen×DP exact | Screen×WebGL | Screen×platform group |
|---|---|---|---|---|---|---|
| never (0) | 34, 8.8%, 2.2x | 12, 8.3% | 31, 6.5%, 1.6x | 8, 12.5% | 44, 9.1%, 2.3x | 1, 0 |
| 1e-5 - 1e-4 (1-8 sessions) | 32, 3.1%, 0.8x | 47, 4.3%, 1.1x | 65, **9.2%, 2.3x** | 77, 7.8%, 2.0x | 122, 3.3%, 0.8x | 43, **9.3%, 2.4x** |
| 1e-4 - 1e-3 | 102, 2.9% | 108, 4.6% | 112, 0.9% | 113, 0.9% | 319, 4.4% | 87, 3.4% |
| 1e-3 - 1e-2 | 205, 3.4% | 281, 2.5% | 298, 5.4% | 292, 5.1% | 410, 3.2% | 297, 4.7% |
| ≥ 1e-2 | 1,044, 4.0% | 871, 4.0% | 922, 3.3% | 907, 3.3% | 518, 4.1% | 1,008, 3.6% |

Mobile by raw count: screen×DP coarse seen once 21 sessions, 3 High (14%); screen×PG seen once 13 sessions, 4 High (31%). Very small numbers.

## What the bins show

1. **On desktop, "seen but infrequent" carries no extra risk for any check.** No bin above "never" reaches 1.5x baseline; the highest is
   1.3x (UA×DP coarse < 1e-3, screen×WebGL 1e-4 - 1e-3). Risk is flat from the rarest seen pairs to the most common ones.
2. **The risk sits in "never seen":** UA×DP coarse never 18.4% (3.7x), UA×DP exact never 10.3% (2.1x), screen×DP exact never 9.3% (1.9x),
   screen×PG never 10.5% (2.1x, n = 57).
3. **Two "never" checks point the wrong way on desktop:** screen×DP coarse never 1.4% and screen×WebGL never 2.1%, below baseline. These are
   the checks that fill v3's desktop Band D (G3 0.70x).
4. **Mobile:** a weak rise at 1-8 whitelist sessions (< 1e-4) for screen×DP (coarse 9.2%, exact 7.8%) and screen×PG (9.3%), about 2x
   baseline, on 4-6 High sessions per bin. UA×DP and screen×WebGL show no rise.

## Proposed cut-offs (rare vs common)

| Check | Desktop groups | Mobile | Evidence |
|---|---|---|---|
| UA × device_params | **No frequency cut-off.** Rare = coarse pair seen, exact pair never seen (as v3's exact-only warning) | No cut-off (exact never only) | Desktop: seen bins 0.8-1.3x; exact never 2.1x. Mobile: flat |
| screen × device_params | **No frequency cut-off.** Rare = exact pair never seen | **Coarse < 1e-4** (fewer than ~8 of 80,573 mobile whitelist sessions) | Desktop: seen bins 0.4-1.1x; exact never 1.9x. Mobile: < 1e-4 is 2.3x (6 of 65) |
| screen × WebGL | **None** | None | No seen bin ≥ 1.5x on either |
| screen × platform group | **None** | **< 1e-4** | Mobile < 1e-4 is 2.4x (4 of 43); desktop flat |

**One cut-off for all checks? No.** On desktop the data supports no frequency cut-off at all (graded "rare" collapses to v3's "exact pair
never seen"); only mobile shows a weak signal, at 1e-4, for the two screen pairs. If a single number is needed for the spec, 1e-4 is the
only candidate, and only for mobile. The mobile evidence rests on 10 High sessions in total; it needs a second window or truth data.

Sensitivity (`q2_v4_results_result.txt`, `q3_stats_result.txt`): applying one uniform cut-off of 1e-4 (or 1e-3) to every pair and level, on
desktop and mobile, adds 158 (257) sessions to Band D at 9.5% (11.7%) High, and desktop sessions with no failed check show 4.2% / 5.0% /
7.3% / 4.4% High with 0 / 1 / 2 / 3 rare pairs at 1e-4 (5,040 / 1,211 / 645 / 136 sessions): rare-at-1e-4 is close to baseline.
