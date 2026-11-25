# Firing replay: new per-dictionary x platform thresholds vs today's, Figma Registration K2

Replay day: sessions created **20 Nov 2026 00:00-24:00 UTC**, 88,608 sessions with a dict (6 with NULL dict excluded). No sampling. Thresholds are from `matrix.md`. Queries: `05_replay_figma_20nov.sql` (day) and `06_replay_figma_20nov_1200_1400.sql` (slice). No truth data was used.

**How to read it.** Both sides use DI's own recorded counts per session (`DI_SHORT_TERM_COUNT_AT_SESSION_CREATED`, `DI_LONG_TERM_COUNT_AT_SESSION_CREATED`), so only the threshold differs.
- **Today** = `DI_SHORT_TERM_THRESHOLD_BREACHED_AT_SESSION_CREATED` (ST count > 11 on this key; checked: the flag matches count > 11 on every session). Also shown: ST ratio at least 2x and 4x, and LT breached (`..._LONG_TERM_..._BREACHED`).
- **New** = ST count > the cell's new ST threshold **or** LT count > the new LT threshold.

Fire stats are shown as **count / High% / verified% / challenged% / challenged-not-solved%**. "Clean" = the session is in a signature-window of the replay day with under 20% High risk (81,054 sessions).

**Dict 63 today:** DI records the breach at Dict 63 (202 sessions), but Dict 63 is exempt, so these fires have no effect today (`di_is_suspicious` is false at 63). The "today" Dict 63 numbers below are the recorded breaches. Today's **effective** Dict 63 firing is 0.

## Summary, full day

| | Fires | High % | Verified % | Challenged % | Chall. not solved % | Fires on clean traffic |
|---|---|---|---|---|---|---|
| Today, ST breached (all dicts, incl. exempt Dict 63) | 381 | 52.8 | 62.7 | 82.7 | 36.7 | 118 (0.15% of clean) |
| Today, effective (Dict 63 exempt) | 179 | | | | | 84 |
| **New** (ST or LT) | **696** | 44.5 | 65.8 | 72.4 | 32.3 | **300 (0.37%)** |
| New only (not fired today) | 332 | 34.0 | 66.6 | 61.7 | 30.1 | |
| Today only (not fired by new) | 17 | 23.5 | 11.8 | 94.1 | 88.2 | |

Key baseline: 5.9% High, 91.1% verified. LT: **0 fires today and 0 new** (LT counts never reach 660 or the new LT values). Today's ST ratio at least 2x: 101 sessions, at least 4x: 4 (all Dict 63 Desktop). All 17 "today only" fires are **List A sessions** (software renderer), which the new design takes out of the thresholds: 2 at Dict 3, 13 at Dict 15, 2 at Dict 31.

So the new thresholds fire **1.8x as often** as today's recorded breaches, or **3.9x** today's effective fires. The extra fires are less risky than today's (34% High for new-only vs 52.8%), but still about 6x the key's 5.9% baseline.

## Per cell, full day

Cells with no fire on either side (all of Dict -1 and Dict 1; 3 Other; 7 Other and Win RD/VM; 15 Linux, Mobile and Other; 31 Linux; 63 Other and Win RD/VM) are omitted. Columns: **Sessions** (High %) | **Today ST** | **New** | **New only** (count / High %) | **Clean fire rate today → new**.

| Dict | Group | Sessions (High %) | New ST thr | Today ST | New | New only | Clean: today → new |
|---|---|---|---|---|---|---|---|
| 3 | Desktop | 3,227 (8.2) | 7 | 40 / 37.5 / 50.0 / 80.0 / 50.0 | 62 / 30.6 / 56.5 / 67.7 / 43.5 | 22 / 18.2 | 30 → 47 of 2,874 (1.04% → 1.64%) |
| 3 | Linux | 323 (6.5) | 6 | 0 | 5 / 0 / 20 / 80 / 80 | 5 / 0 | 0 → 5 of 294 |
| 3 | Mobile | 770 (5.3) | 9 | 0 | 2 / 0 / 100 / 0 / 0 | 2 / 0 | 0 → 2 of 701 |
| 3 | Win RD/VM | 194 (18.0) | 5 | 1 / 0 / 100 / 0 / 0 | 9 / 11.1 / 33.3 / 88.9 / 66.7 | 8 / 12.5 | 1 → 8 of 155 |
| 7 | Desktop | 9,086 (8.1) | 6 | 45 / 28.9 / 80.0 / 33.3 / 20.0 | 103 / 25.2 / 71.8 / 35.9 / 27.2 | 58 / 22.4 | 26 → 71 of 8,230 (0.32% → 0.86%) |
| 7 | Linux | 497 (2.6) | 6 | 0 | 6 / 0 / 50 / 100 / 33.3 | 6 / 0 | 0 → 6 of 481 |
| 7 | Mobile | 283 (10.6) | 3 | 0 | 6 / 66.7 / 0 / 100 / 83.3 | 6 / 66.7 | 0 → 2 of 252 |
| 15 | Desktop | 7,392 (8.8) | 6 | 28 / 71.4 / 60.7 / 71.4 / 35.7 | 67 / 58.2 / 64.2 / 65.7 / 29.9 | 39 / 48.7 | 8 → 22 of 6,676 (0.12% → 0.33%) |
| 15 | Win RD/VM | 313 (8.9) | 6 | 4 / 0 / 25 / 100 / 75 | 5 / 0 / 20 / 100 / 80 | 1 / 0 | 4 → 5 of 285 |
| 31 | Desktop | 12,889 (7.6) | 6 | 44 / 65.9 / 36.4 / 93.2 / 63.6 | 89 / 55.1 / 53.9 / 83.1 / 44.9 | 45 / 44.4 | 15 → 36 of 11,787 (0.13% → 0.31%) |
| 31 | Mobile | 817 (3.1) | 4 | 0 | 2 / 0 / 0 / 100 / 100 | 2 / 0 | 0 → 2 of 791 |
| 31 | Win RD/VM | 604 (13.6) | 4.5 | 0 | 7 / 14.3 / 85.7 / 28.6 / 14.3 | 7 / 14.3 | 0 → 6 of 519 |
| 63 | Desktop | 35,571 (4.4) | 8 | 183 / 63.4 / 70.5 / 92.3 / 29.0 (exempt) | 299 / 55.9 / 70.2 / 81.9 / 28.1 | 116 / 44.0 | 20 → 62 of 33,541 (0.06% → 0.18%) |
| 63 | Linux | 387 (3.6) | 6 | 14 / 0 / 85.7 / 100 / 14.3 (exempt) | 25 / 0 / 92.0 / 100 / 8.0 | 11 / 0 | 14 → 25 of 370 (6.8%) |
| 63 | Mobile | 10,787 (3.1) | 10 | 5 / 80 / 100 / 80 / 0 (exempt) | 9 / 44.4 / 100 / 44.4 / 0 | 4 / 0 | 0 → 1 of 10,352 |

Per-dictionary totals (today ST → new; High % of the new fires): Dict 3 **43 → 78** (25.6%); Dict 7 **45 → 115** (26.1%); Dict 15 **45 → 72** (54.2%); Dict 31 **46 → 98** (51.0%); Dict 63 **202 recorded / 0 effective → 333** (51.4%).

Skipped List A/B/C sessions on the replay day: **1,459** (1.6%). List A 567 (17 of them breach today), List B 9, List C 883 (none breach today).

## Removing the Dict 63 exemption

- **With today's thresholds** (11 / 660), removing the exemption would turn on the **202** recorded Dict 63 breaches: 59.4% High, 72.3% verified, 92.6% challenged, 27.2% challenged-not-solved. That is 14x Dict 63's 4.2% High baseline.
- **With the new thresholds**, Dict 63 fires **333**: 51.4% High, 72.7% verified, 82.3% challenged, 25.8% challenged-not-solved. That is 12x the baseline. 131 of these don't fire under today's threshold, and those are 38.9% High.
- **Where the fires land:** Dict 63 Desktop has 299 (55.9% High). **Dict 63 Linux has 25 fires at 0% High and 92% verified**, 19 of them in the 12:00-14:00 slice. These look like one or a few busy clean Linux signatures against a threshold of 6. Examples were not pulled, so the cause is not shown.

## Slice 12:00-14:00 UTC (layer-1 window, 9,156 sessions, 4.8% High)

| | Fires | High % | Verified % | Challenged % | Chall. not solved % | On clean traffic |
|---|---|---|---|---|---|---|
| Today ST (incl. exempt Dict 63) | 25 | 20.0 | 72.0 | 96.0 | 28.0 | 24 |
| New | 70 | 18.6 | 72.9 | 74.3 | 22.9 | 61 |
| New only | 45 | 17.8 | | | | |

By cell (today → new): 7 Desktop 4 → 20 (new fires 15% High); 7 Linux 0 → 4 (0%); 15 Desktop 0 → 9 (55.6%); 31 Desktop 0 → 4 (25%); 63 Desktop 7 → 12 (25%); **63 Linux 13 → 19 (0% High, 89.5% verified)**; 63 Mobile 1 → 2. No fires in Dict -1, 1 or 3 in this slice, and no LT fires. In this window the new fires are only slightly riskier than the slice baseline (18.6% vs 4.8% High). Most of them (61 of 70) are on clean signature-windows.

## Known cases

- **K3, Adobe ARP K8 (`07_known_case_K3_adobe_arp_k8.sql`)**, 18 Nov 00:00-07:00, attack IP `2a03:4000:6:cc79:%`. 2,075 sessions, 100% High: 75% Dict 31, 15% Dict 63, 10% Dict 15, all Desktop. **Fires: yes.** Dict 31: all 1,565 fire under the new global-cell threshold (ST 54; the attack's ST counts run 130-229). Today all 1,565 also fire (threshold 90 on this key; 810 at 2x or more). The new thresholds also catch 200 of 203 at Dict 15 (today 32) and 126 of 307 at Dict 63 (today 0, and exempt). Overall 1,891 (91.1%) new vs 1,597 (77.0%) today. Caveat: these are **global** cells. The key's own 7-day cells timed out.
- **L1, Payoneer (`08_known_case_L1_payoneer.sql`)**, 18 Nov 10:00-14:00 peak, 3 proxy keys, 123,297 sessions, 1.3% High, 96.2% verified. **Thresholds still fire en masse:** new 112,383 (91.1%) vs today 110,947 ST breaches (90.0%). Nearly all of it is Dict 1, where the matched signature is just the OS, and the JA4 change put every session there. ST counts reach 1,054, far above any threshold (global Dict 1: 15.9 Mobile, 35.3 others). Thresholds cannot fix this. The fix has to come from the similarity layer (JA4 weight 0 on proxy keys), not from velocity. Per key: EE844FC3 96,967 → 98,778; E3EFEFBF 12,719 → 12,199; 7CC24C4A 1,261 → 1,406. Caveat: global cells. The Payoneer keys' own cells were not computed.

## Gates (spec §5)

**G7 (threshold firing): FAIL on Figma for the clean-traffic part; the Dict 63 part passes in aggregate.**
- *Per cell, clean-traffic firing at or below today's per-dict rate.* Today's clean-traffic rates per dict: Dict 3 0.77%, Dict 7 0.27%, Dict 15 0.14%, Dict 31 0.11%, Dict 63 0.075% (recorded, 0% effective). The new thresholds exceed these in **14 cells**: 3 Desktop, Linux and Win RD/VM; 7 Desktop, Linux and Mobile; 15 Desktop and Win RD/VM; 31 Desktop, Mobile and Win RD/VM; 63 Desktop and Linux. They also exceed them in 3 Mobile and 63 Mobile against today's *effective* rate. The cells at or below are the ones with no fires: all of Dict -1 and Dict 1, the "Other" cells, 7 Win RD/VM, 15 Linux and Mobile, 31 Linux, 63 Win RD/VM. Overall, clean firing rises from 118 to 300 sessions (0.15% → 0.37%). The cause is that Figma's own p99 per signature is 2-9, below today's flat 11.
- *Dict 63 fires concentrate on High risk.* **Yes in aggregate**: 51.4% High vs a 4.2% baseline (12x). **But not in the Linux cell**: 25 fires, 0% High.

**G8 (proxy keys, Payoneer firing at or below today): FAIL, marginally.** 112,383 new vs 110,947 today (+1.3%) in the L1 peak window, using global cells. Firing is already en masse today, and the new thresholds neither help nor make it much worse. Per-key cells might differ, but they were not computed.
