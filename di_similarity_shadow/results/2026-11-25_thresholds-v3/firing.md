# Firing replay v3 (D-13 sensitivity): four base variants vs today, Figma Registration K2 and known cases

Replay day: sessions created **20 Nov 2026 00:00-24:00 UTC** (88,608 sessions with a dict, no sampling) and the 12:00-14:00 slice (9,156). Same method as v2 `firing.md`: both sides use DI's own recorded counts; today = `DI_SHORT_TERM_THRESHOLD_BREACHED_AT_SESSION_CREATED` (count > 11); new = ST count > new ST **or** LT count > new LT; clean = session in a replay-day signature-window with < 20% High (81,054 sessions). Stats: **n / High% / verified% / challenged% / challenged-not-solved%**. Queries: `05_replay_figma_20nov_v3.sql`, `06_replay_figma_20nov_1200_1400_v3.sql` (all four variants in one scan each), `07_g7_per_cell.py`; outputs in `raw/`. **V0 reproduces v2 exactly** (698 fires, 301 clean, 44.4% High; slice 70 / 61). **V3 replays identically to V2 on Figma** (only threshold difference, Dict 31 Mobile 8.34 vs 10, has no session above 8.34). No truth data used. High risk and verified are indicators, not ground truth.

## Summary, 20 Nov full day

| | Fires | High % | Verified % | Challenged % | Chall. not solved % | On clean traffic (n, % of 81,054) | New-only (High %) | Today-only |
|---|---|---|---|---|---|---|---|---|
| Today, ST breached (recorded, incl. exempt Dict 63) | 381 | 52.8 | 62.7 | 82.7 | 36.7 | 118 (0.15%) | | |
| Today, effective (Dict 63 exempt) | 179 | | | | | 84 (0.10%) | | |
| **V0** p99 (= v2) | 698 | 44.4 | 65.9 | 72.3 | 32.2 | 301 (0.37%) | 334 (33.8) | 17 |
| **V1** max(p99, 5) | 500 | 47.6 | 65.0 | 76.6 | 34.0 | 203 (0.25%) | 136 (30.1) | 17 |
| **V2** p99.9 | 218 | 46.8 | 63.8 | 82.1 | 35.8 | 83 (0.10%) | 5 (0.0) | 168 |
| **V3** max(p99.9, 5) | 218 | 46.8 | 63.8 | 82.1 | 35.8 | 83 (0.10%) | 5 (0.0) | 168 |

Key baseline 5.9% High, 91.1% verified. LT: 0 fires today and 0 in every variant. Today-only for V0/V1 = 17 List A sessions (skipped by design). Today-only for V2/V3 = 168: 111 Dict 63 (exempt today, so not real fires), 17 List A, and **40 real losses vs today's effective firing** (Dict 3 Desktop 6, Dict 7 Desktop 6, Dict 15 Desktop 19, Dict 31 Desktop 9) where the V2 key cell (12-16) is above today's 11. Their risk profile was not broken out (not done).

New-only under V2/V3 is 5 sessions (Dict 3 Linux 2, Dict 3 Win RD/VM 3), all 0% High. So V2/V3's 218 fires are, apart from those 5, a subset of what today's flat 11 already breaches (recorded); what they add over today's *effective* behaviour is enforcement on 91 Dict 63 sessions (52.7% High) that are exempt today.

## Per cell, full day (cells with any fire today or in any variant)

| Dict | Group | Sessions (High %) | Clean sessions | Today ST fires / clean | V0 fires n / High / ver / chall / chall-not-solved | V0 new-only / clean | V1 fires | V1 new-only / clean | V2 = V3 fires | V2 new-only / clean |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Desktop | 109 (4.6) | 96 | 0 / 0 | 2 / 0.0 / 100.0 / 50.0 / 0.0 | 2 / 1 | 2 / 0.0 / 100.0 / 50.0 / 0.0 | 2 / 1 | 0 | - / - |
| 3 | Desktop | 3227 (8.2) | 2874 | 40 / 30 | 62 / 30.6 / 56.5 / 67.7 / 43.5 | 22 / 47 | 62 / 30.6 / 56.5 / 67.7 / 43.5 | 22 / 47 | 34 / 35.3 / 52.9 / 82.4 / 47.1 | 0 / 27 |
| 3 | Linux | 323 (6.5) | 294 | 0 / 0 | 5 / 0.0 / 20.0 / 80.0 / 80.0 | 5 / 5 | 5 / 0.0 / 20.0 / 80.0 / 80.0 | 5 / 5 | 2 / 0.0 / 50.0 / 50.0 / 50.0 | 2 / 2 |
| 3 | Mobile | 770 (5.3) | 701 | 0 / 0 | 2 / 0.0 / 100.0 / 0.0 / 0.0 | 2 / 2 | 2 / 0.0 / 100.0 / 0.0 / 0.0 | 2 / 2 | 0 | - / - |
| 3 | SKIP_A | 58 (46.6) | 0 | 2 / 0 | 0 | 0 / 0 | 0 | 0 / 0 | 0 | 0 / 0 |
| 3 | Win RD/VM | 194 (18.0) | 155 | 1 / 1 | 9 / 11.1 / 33.3 / 88.9 / 66.7 | 8 / 8 | 9 / 11.1 / 33.3 / 88.9 / 66.7 | 8 / 8 | 4 / 0.0 / 25.0 / 75.0 / 75.0 | 3 / 4 |
| 7 | Desktop | 9086 (8.1) | 8230 | 45 / 26 | 103 / 25.2 / 71.8 / 35.9 / 27.2 | 58 / 71 | 84 / 26.2 / 72.6 / 35.7 / 27.4 | 39 / 56 | 39 / 30.8 / 82.1 / 33.3 / 17.9 | 0 / 21 |
| 7 | Linux | 497 (2.6) | 481 | 0 / 0 | 6 / 0.0 / 50.0 / 100.0 / 33.3 | 6 / 6 | 4 / 0.0 / 50.0 / 100.0 / 25.0 | 4 / 4 | 0 | - / - |
| 7 | Mobile | 283 (10.6) | 252 | 0 / 0 | 6 / 66.7 / 0.0 / 100.0 / 83.3 | 6 / 2 | 0 | - / - | 0 | - / - |
| 15 | Desktop | 7392 (8.8) | 6676 | 28 / 8 | 67 / 58.2 / 64.2 / 65.7 / 29.9 | 39 / 22 | 33 / 72.7 / 57.6 / 72.7 / 39.4 | 5 / 9 | 9 / 77.8 / 66.7 / 77.8 / 22.2 | 0 / 2 |
| 15 | SKIP_A | 74 (32.4) | 0 | 13 / 0 | 0 | 0 / 0 | 0 | 0 / 0 | 0 | 0 / 0 |
| 15 | Win RD/VM | 313 (8.9) | 285 | 4 / 4 | 5 / 0.0 / 20.0 / 100.0 / 80.0 | 1 / 5 | 4 / 0.0 / 25.0 / 100.0 / 75.0 | 0 / 4 | 4 / 0.0 / 25.0 / 100.0 / 75.0 | 0 / 4 |
| 31 | Desktop | 12889 (7.6) | 11787 | 44 / 15 | 89 / 55.1 / 53.9 / 83.1 / 44.9 | 45 / 36 | 48 / 64.6 / 41.7 / 93.8 / 58.3 | 4 / 17 | 35 / 65.7 / 31.4 / 94.3 / 68.6 | 0 / 12 |
| 31 | Mobile | 817 (3.1) | 791 | 0 / 0 | 2 / 0.0 / 0.0 / 100.0 / 100.0 | 2 / 2 | 0 | - / - | 0 | - / - |
| 31 | SKIP_A | 26 (69.2) | 0 | 2 / 0 | 0 | 0 / 0 | 0 | 0 / 0 | 0 | 0 / 0 |
| 31 | Win RD/VM | 604 (13.6) | 519 | 0 / 0 | 7 / 14.3 / 85.7 / 28.6 / 14.3 | 7 / 6 | 3 / 0.0 / 100.0 / 33.3 / 0.0 | 3 / 3 | 0 | - / - |
| 63 | Desktop | 35571 (4.4) | 33541 | 183 / 20 | 299 / 55.9 / 70.2 / 81.9 / 28.1 | 116 / 62 | 218 / 62.8 / 69.7 / 91.3 / 28.9 | 35 / 29 | 80 / 60.0 / 75.0 / 98.8 / 25.0 | 0 / 0 |
| 63 | Linux | 387 (3.6) | 370 | 14 / 14 | 25 / 0.0 / 92.0 / 100.0 / 8.0 | 11 / 25 | 17 / 0.0 / 88.2 / 100.0 / 11.8 | 3 / 17 | 11 / 0.0 / 81.8 / 100.0 / 18.2 | 0 / 11 |
| 63 | Mobile | 10787 (3.1) | 10352 | 5 / 0 | 9 / 44.4 / 100.0 / 44.4 / 0.0 | 4 / 1 | 9 / 44.4 / 100.0 / 44.4 / 0.0 | 4 / 1 | 0 | 0 / 0 |

| Dict | Today ST (recorded) | V0 fires (High %) | V1 fires (High %) | V2 = V3 fires (High %) | Clean: today -> V0 / V1 / V2 |
|---|---|---|---|---|---|
| -1 | 0 | 0 | 0 | 0 | 0 -> 0 / 0 / 0 |
| 1 | 0 | 2 (0.0) | 2 (0.0) | 0 | 0 -> 1 / 1 / 0 |
| 3 | 43 | 78 (25.6) | 78 (25.6) | 40 (30.0) | 31 -> 62 / 62 / 33 |
| 7 | 45 | 115 (26.1) | 88 (25.0) | 39 (30.8) | 26 -> 79 / 60 / 21 |
| 15 | 45 | 72 (54.2) | 37 (64.9) | 13 (53.8) | 12 -> 27 / 13 / 6 |
| 31 | 46 | 98 (51.0) | 51 (60.8) | 35 (65.7) | 15 -> 44 / 20 / 12 |
| 63 | 202 | 333 (51.4) | 244 (57.8) | 91 (52.7) | 34 -> 88 / 47 / 11 |

## Slice 12:00-14:00 UTC (9,156 sessions, 4.8% High)

| | Fires | High % | Verified % | Challenged % | Chall. not solved % | Clean | New-only |
|---|---|---|---|---|---|---|---|
| Today ST | 25 | 20.0 | 72.0 | 96.0 | 28.0 | 24 | |
| V0 | 70 | 18.6 | 72.9 | 74.3 | 22.9 | 61 | 45 (17.8% High) |
| V1 | 43 | 16.3 | 67.4 | 83.7 | 30.2 | 40 | 18 (11.1% High) |
| V2 = V3 | 13 | 7.7 | 69.2 | 100.0 | 30.8 | 13 | 0 |

V2/V3 slice fires: Dict 63 Linux 11 (the managed-fleet signature, 0% High) and Dict 7 Desktop 2 (1 High). In this slice the remaining fires are dominated by the Dict 63 Linux group, so High % among fires drops to 7.7%.

## G7 per cell (clean-traffic firing <= today's per-dict clean rate)

Today's per-dict clean rates (recorded): Dict 1 0%, Dict 3 0.768% (31 / 4,037), Dict 7 0.275% (26 / 9,459), Dict 15 0.136% (12 / 8,824), Dict 31 0.112% (15 / 13,357), Dict 63 0.075% (34 / 45,236; **0% effective**, exempt). Per-cell detail in `raw/07_g7_per_cell.txt`.

| Variant | Failing cells (vs recorded rate) | + vs Dict 63 effective (0) | Cells |
|---|---|---|---|
| V0 | 14 | +1 (63 Mobile) = 15, as v2 | 1 Desktop; 3 Desktop / Linux / Win RD/VM; 7 Desktop / Linux / Mobile; 15 Desktop / Win RD/VM; 31 Desktop / Mobile / Win RD/VM; 63 Desktop / Linux |
| V1 | 11 | +1 (63 Mobile) = 12 | 1 Desktop; 3 Desktop / Linux / Win RD/VM; 7 Desktop / Linux; 15 Win RD/VM; 31 Desktop / Win RD/VM; 63 Desktop / Linux |
| V2 = V3 | **4** | +0 | 3 Desktop (27 / 2,874 = 0.94%), 3 Win RD/VM (4 / 155 = 2.6%), 15 Win RD/VM (4 / 285 = 1.4%), 63 Linux (11 / 370 = 3.0%) |

Reading the V2/V3 failures against **today's same-cell** clean fires (not the gate's definition, shown for context): 3 Desktop 27 vs today 30 (lower); 15 Win RD/VM 4 vs 4 (equal, same sessions); 3 Win RD/VM 4 vs 1 (higher); 63 Linux 11 vs 14 recorded but exempt (higher than effective 0). So two of the four cells fail only because the gate compares a cell with its dict's average and those cells already fire more than average today.

**Dict 63 fires concentrate on High risk:** V0 333 (51.4%), V1 244 (57.8%), V2/V3 91 (52.7%) vs a Dict 63 baseline of 4.2%: yes in aggregate in every variant. Not in the Linux cell (0% High in every variant).

## Dict 63 Linux group (one signature, Firefox 156 / Linux, junta de andalucia NAT; 25 fires under v2)

| | Today (recorded, exempt) | V0 | V1 | V2 = V3 |
|---|---|---|---|---|
| Threshold ST | 11 | 6 | 10 | 13.1 |
| Fires | 14 | 25 | 17 | **11** |
| High % | 0 | 0 | 0 | 0 |

The burst reached an ST count of 24 (see v2 `06_dict63_linux_examples.sql`), so no variant tested here removes it; only a threshold above 24 or a fleet / IP-diversity exception would. All Dict 63 Linux fires in every variant are this signature (any session above a higher threshold also fires at 6, and v2 showed all 25 were one signature). The reading of this group as identically imaged managed PCs is v2's interpretation, not verified.

## Known cases

### K3: Adobe ARP K8, 18 Nov 00:00-07:00, attack IP `2a03:4000:6:cc79:%` (should fire)

2,084 sessions, 100% High. Adobe's own key cells under each variant (base sampled by window, as v2). `09_replay_K3_adobe_v3.sql`, `raw/09_replay_K3_adobe_v3.txt`.

| Cell (ST counts p10 / p50 / max) | Today | V0 = V1 (thr) | V2 = V3 (thr) |
|---|---|---|---|
| Dict 15 Desktop, 203 (38 / 85 / 97) | 32 | 203 (14) | 202 (24) |
| Dict 31 Desktop, 1,565 (130 / 185 / 229) | 1,565 | 1,565 (22) | 1,565 (52) |
| Dict 63 Desktop, 307 (23 / 26 / 44) | 0 (exempt) | 132 (34) | **0** (104) |
| **Total** | 1,597 (76.6%) | **1,900 (91.2%)** | **1,767 (84.8%)** |

K3 fires under every variant, above today. V2/V3 lose the Dict 63 Desktop part (Adobe's Dict 63 Desktop p99.9 is 52, so ST 104). Rest of the Adobe key in the same window (context, not a gate): V0 61,179 fires at 55.9% High; V2 26,144 at 92.7% High; today 131,170 (91.3% High, incl. List C Dict 63 sessions now skipped).

### G8: Payoneer L1, 18 Nov 10:00-14:00 (should not fire en masse)

123,297 sessions, 1.3% High. `08_replay_L1_payoneer_v3.sql`, `raw/08_replay_L1_payoneer_v3.txt`.

| | Fires | vs today 110,947 | High % | Verified % | EE844FC3 | E3EFEFBF | 7CC24C4A |
|---|---|---|---|---|---|---|---|
| Today ST | 110,947 | | | | 96,967 | 12,719 | 1,261 |
| V0 = V1 | 113,595 | +2.4% | 1.0 | 96.4 | 99,725 | 12,611 | 1,259 |
| V2 = V3 | 111,639 | **+0.6%** | 1.0 | 96.4 | 97,769 | 12,611 | 1,259 |

**G8 fails marginally in every variant.** Only EE844FC3's Dict 1 thresholds change (12 -> 25.2-25.8 under p99.9) and the L1 ST counts (median 477-746) are far above any of them. As in v2, this is a similarity-layer problem (JA4 weight 0 on proxy keys), not a threshold-level one. Non-Dict-1 cells were kept at V0 values for all variants (they carry 3 fires), so V1-V3 figures are exact to within those 3.
