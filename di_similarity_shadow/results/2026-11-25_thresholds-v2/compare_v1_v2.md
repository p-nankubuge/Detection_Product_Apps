# v1 vs v2: global fallback vs per-key fallback (D-11), Figma Registration K2

v1 = `results/2026-11-25_thresholds/` (fallback to global cells). v2 = this folder (fallback within the key: (a) key x dict pooled across groups, (b) key's current threshold ST 11 / LT 660, fallbacks capped at 11 / 660). Everything else identical: base 13-20 Nov, replay 20 Nov (+ 12:00-14:00), 40-minute fixed buckets, clean < 20% High, minimum 500 clean signature-windows, ESM-6922 multipliers, LT = base x LT mult x 60, Dict 63 exemption removed, List A/B/C skipped.

## The 15 cells that fell back to global in v1

| Dict | Group | v1 source | v1 ST / LT | v2 step | v2 ST / LT | Change |
|---|---|---|---|---|---|---|
| -1 | Desktop | global -1+1 pool | 68.7 / 4,122 | (b) current (pooled 30 windows) | 11 / 660 | 6.2x tighter |
| -1 | Mobile | global -1+1 pool | 68.7 / 4,122 | (b) current | 11 / 660 | 6.2x tighter |
| -1 | Linux | global -1+1 pool | 68.7 / 4,122 | (b) current | 11 / 660 | 6.2x tighter |
| -1 | Win RD/VM | global -1+1 pool | 68.7 / 4,122 | (b) current | 11 / 660 | 6.2x tighter |
| -1 | Other | global -1+1 pool | 68.7 / 4,122 | (b) current | 11 / 660 | 6.2x tighter |
| 1 | Desktop | global Dict 1 pooled | 35.3 / 2,118 | (a) key pooled (652 windows, p99 7.49) | 7.49 / 449.4 | 4.7x tighter; below today's 11 |
| 1 | Mobile | global cell | 15.9 / 954 | (a) key pooled | 7.49 / 449.4 | 2.1x tighter |
| 1 | Linux | global Dict 1 pooled | 35.3 / 2,118 | (a) key pooled | 7.49 / 449.4 | 4.7x tighter |
| 1 | Win RD/VM | global Dict 1 pooled | 35.3 / 2,118 | (a) key pooled | 7.49 / 449.4 | 4.7x tighter |
| 1 | Other | global Dict 1 pooled | 35.3 / 2,118 | (a) key pooled | 7.49 / 449.4 | 4.7x tighter |
| 3 | Other | global Dict 3 pooled | 68 / 4,080 | (a) key pooled (p99 8) | 8 / 480 | 8.5x tighter |
| 7 | Other | global Dict 7 pooled | 37.5 / 3,000 | (a) key pooled (p99 4) | 6 / 480 | 6.3x tighter |
| 15 | Other | global Dict 15 pooled | 34 / 4,080 | (a) key pooled (p99 3) | 6 / 660 (LT capped from 720) | 5.7x tighter |
| 31 | Other | global Dict 31 pooled | 52 / 6,240 | (a) key pooled (p99 3) | 6 / 660 (LT capped from 720) | 8.7x tighter |
| 63 | Other | global cell | 33.4 / 6,012 | (a) key pooled (p99 4) | 8 / 660 (LT capped from 1,440) | 4.2x tighter |

10 cells at (a), 5 at (b). The 20 real key cells are unchanged.

## Replay fires per changed cell, 20 Nov full day (n / High% / verified% / challenged% / challenged-not-solved%)

| Dict | Group | Sessions | Max ST count | Today ST | v1 | v2 |
|---|---|---|---|---|---|---|
| -1 | Desktop | 4 | 2 | 0 | 0 | 0 |
| -1 | Mobile | 2 | 1 | 0 | 0 | 0 |
| -1 | Linux / Win RD/VM / Other | 0 | - | - | - | - |
| 1 | **Desktop** | 109 | 8 | 0 | 0 | **2 / 0 / 100 / 50 / 0** (1 on clean traffic) |
| 1 | Mobile | 24 | 4 | 0 | 0 | 0 |
| 1 | Linux | 21 | 4 | 0 | 0 | 0 |
| 1 | Win RD/VM | 2 | 4 | 0 | 0 | 0 |
| 1 | Other | 0 | - | - | - | - |
| 3 | Other | 16 | 2 | 0 | 0 | 0 |
| 7 | Other | 4 | 3 | 0 | 0 | 0 |
| 15 | Other | 8 | 2 | 0 | 0 | 0 |
| 31 | Other | 0 | - | - | - | - |
| 63 | Other | 5 | 1 | 0 | 0 | 0 |

LT: no LT fires in any changed cell (max LT count 185 vs v2 LT 449.4). 12:00-14:00 slice: no fires in any changed cell, v1 or v2.

## Totals

| | Today ST | v1 new | v2 new |
|---|---|---|---|
| Full day fires | 381 / 52.8 / 62.7 / 82.7 / 36.7 | 696 / 44.5 / 65.8 / 72.4 / 32.3 | **698 / 44.4 / 65.9 / 72.3 / 32.2** |
| New only | | 332 (34.0% High) | 334 (33.8% High) |
| On clean traffic | 118 (0.15%) | 300 (0.37%) | 301 (0.37%) |
| Slice 12:00-14:00 | 25 (20.0% High) | 70 (18.6% High) | 70 (18.6% High) |

## Gates

**G7 (per cell, clean-traffic firing <= today's per-dict rate; Dict 63 fires concentrate on High risk)**
- v1: FAIL. 14 cells above today's per-dict clean rate (3 Desktop / Linux / Win RD/VM; 7 Desktop / Linux / Mobile; 15 Desktop / Win RD/VM; 31 Desktop / Mobile / Win RD/VM; 63 Desktop / Linux), plus 3 Mobile and 63 Mobile vs today's effective rate. Dict 63: 51.4% High in aggregate (12x baseline), but Linux 0%.
- v2: **FAIL, one cell worse.** The same 14 cells, **plus Dict 1 Desktop** (1 clean fire of 96 clean sessions vs today's Dict 1 clean rate of 0). Dict 63 unchanged: 333 fires, 51.4% High; Linux cell 25 fires at 0% High. The cause is unchanged too: Figma's own p99 per signature is 2-9, below today's flat 11. The per-key fallback removes the only cells that were looser than today, which made Dict 1 slightly tighter than today rather than 3x looser.

**G8 (Payoneer firing at or below today)**, L1 peak 18 Nov 10:00-14:00, 123,297 sessions
- v1 (global cells): FAIL, 112,383 vs today 110,947 (+1.3%).
- v2 (each Payoneer key's own cells, `08` to `10`): **FAIL, 113,595 vs 110,947 (+2.4%)**; 1.0% High, 96.4% verified among the fires. EE844FC3 96,967 -> 99,725 (v1 98,778): its Dict 1 cells are 12.0 (Mobile key cell) and 12.1 (pooled), below today's 35, against ST counts of 477-746 (median). E3EFEFBF and 7CC24C4A have too little Dict 1 history, so every Dict 1 cell is at (b) = today's threshold and fires exactly as today (12,719 -> 12,611 and 1,261 -> 1,259; the small drops are List A sessions skipped). Per-key fallback cannot fix L1: the JA4 change dumped the whole proxy population into Dict 1 (OS-only signature), so median ST counts are roughly 10-60x the keys' own Dict 1 p99 (7-12). As in v1, the fix has to come from the similarity layer (JA4 weight 0 on proxy keys).

**K3 (Adobe ARP K8, should fire)**: v1 1,891 of 2,075 (global cells); v2 **1,900 of 2,084 (91.2%)** with the key's own cells (base sampled by window): Dict 31 Desktop 1,565 / 1,565 (thr 22), Dict 15 203 / 203 (thr 14), Dict 63 132 / 307 (thr 34). Today: 1,597. Fires: yes.
