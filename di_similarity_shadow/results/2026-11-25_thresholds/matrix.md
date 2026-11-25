# Threshold matrix: Figma Registration K2, per dictionary x platform group

Run 2026-11-25. Key `A207F8A1-ED09-4325-ACE6-C8E26A458FBA`. Base period: sessions created 13 Nov 00:00 to 20 Nov 00:00 UTC (7 days, no sampling, 655,839 sessions). Queries: `01_figma_base.sql` (key cells), `03_global_cells_19nov.sql` (global cells), `04_build_matrix.py` (fallbacks and multipliers). Read `caveats.md` before using these numbers.

## How a cell is built

- **What is counted:** sessions per **matched signature** (`DI_MATCHED_SIGNATURE_AT_SESSION_CREATED`, the signature prefix at the matched dictionary level), the same key today's DI counts on (checked in `00_verify_counting.sql`), split by platform group.
- **Window:** fixed 40-minute buckets (`TIME_SLICE(session_ts, 40, 'MINUTE')`), 252 buckets in 7 days. One "signature-window" = one matched signature x group x bucket with at least one session.
- **Clean:** signature-windows where fewer than 20% of sessions are `latest_risk_band = 'High'`.
- **Base:** p99 of sessions per clean signature-window.
- **Minimum volume:** a cell uses its own (key) p99 only if it has **at least 500 clean signature-windows** (so at least 5 windows sit above the p99). Otherwise it falls back to the **global cell** (same rule, at least 500), then to the **global dictionary pooled across groups**, then (Dict -1 only) to the **global Dict -1 + Dict 1 pool**.
- **Multipliers (ESM-6922):** short-term (ST) 1x for Dict -1/1/3, 1.5x for 7, 2x for 15/31/63; long-term (LT) 1x, 2x, 4x, 6x. Win RD/VM capped at 1.5x ST and 2x LT.
- **LT threshold = base x LT multiplier x 60.** The spec gives only a 40-minute base. Today's LT threshold on this key is 60 times its ST threshold (660 vs 11), so that ratio is kept. This is an assumption (see caveats).
- **Platform groups:** the table in `.claude/agents/similarity-scorer.md`, "Seen-before rules" item 1. List A/B/C sessions are skipped (8,536 in the base period, 1.3%).

## Figma K2 matrix (after multipliers)

Columns: clean signature-windows on the key | key p99 | base used (and where it came from) | ST threshold | LT threshold. **Today's thresholds on this key: ST 11 and LT 660 in every cell** (implied from count / ratio, `00_verify_counting.sql`).

| Dict | Group | Clean sig-windows (key) | Key p99 | Base used | ST | LT |
|---|---|---|---|---|---|---|
| -1 | all groups | 1-21 | 1-8 | **68.7, global -1+1 pool** | 68.7 | 4,122 |
| 1 | Desktop | 413 | 8 | **35.3, global Dict 1 pooled** (global Desktop cell had 496) | 35.3 | 2,118 |
| 1 | Mobile | 165 | 3.36 | **15.9, global cell** | 15.9 | 954 |
| 1 | Linux | 65 | 5.08 | **35.3, global Dict 1 pooled** | 35.3 | 2,118 |
| 1 | Win RD/VM | 28 | 4.46 | **35.3, global Dict 1 pooled** | 35.3 | 2,118 |
| 1 | Other | 6 | 1.95 | **35.3, global Dict 1 pooled** | 35.3 | 2,118 |
| 3 | Desktop | 14,359 | 7 | 7, key | 7 | 420 |
| 3 | Mobile | 3,449 | 9 | 9, key | 9 | 540 |
| 3 | Linux | 1,602 | 6 | 6, key | 6 | 360 |
| 3 | Win RD/VM | 969 | 5 | 5, key | 5 | 300 |
| 3 | Other | 56 | 3 | **68, global Dict 3 pooled** | 68 | 4,080 |
| 7 | Desktop | 50,697 | 4 | 4, key | 6 | 480 |
| 7 | Mobile | 1,743 | 2 | 2, key | 3 | 240 |
| 7 | Linux | 3,087 | 4 | 4, key | 6 | 480 |
| 7 | Win RD/VM | 2,897 | 4 | 4, key | 6 | 480 |
| 7 | Other | 11 | 1 | **25, global Dict 7 pooled** | 37.5 | 3,000 |
| 15 | Desktop | 39,261 | 3 | 3, key | 6 | 720 |
| 15 | Mobile | 9,791 | 3 | 3, key | 6 | 720 |
| 15 | Linux | 2,198 | 3 | 3, key | 6 | 720 |
| 15 | Win RD/VM | 1,475 | 4 | 4, key | 6 (1.5x cap) | 480 (2x cap) |
| 15 | Other | 43 | 2 | **17, global Dict 15 pooled** | 34 | 4,080 |
| 31 | Desktop | 76,762 | 3 | 3, key | 6 | 720 |
| 31 | Mobile | 5,832 | 2 | 2, key | 4 | 480 |
| 31 | Linux | 2,089 | 3 | 3, key | 6 | 720 |
| 31 | Win RD/VM | 2,977 | 3 | 3, key | 4.5 | 360 |
| 31 | Other | 1 | 1 | **26, global Dict 31 pooled** | 52 | 6,240 |
| 63 | Desktop | 212,242 | 4 | 4, key | 8 | 1,440 |
| 63 | Mobile | 60,986 | 5 | 5, key | 10 | 1,800 |
| 63 | Linux | 2,451 | 3 | 3, key | 6 | 1,080 |
| 63 | Win RD/VM | 6,382 | 4 | 4, key | 6 | 480 |
| 63 | Other | 31 | 1 | **16.7, global cell** | 33.4 | 6,012 |

**What this means.** On Figma, a single matched signature rarely has more than 3 to 9 clean sessions in a 40-minute bucket, so the key's own cells come out **well below today's flat 11** (ST 3 to 10 after multipliers). The cells that fall back to global (Dict -1, Dict 1, and "Other" everywhere) come out well **above** 11, because global volume per signature is much higher than Figma's. Fell back: 5 Dict -1 cells, all 5 Dict 1 cells, and the 5 "Other" cells for Dict 3 to 63 (15 of 35 cells). Dict 1 Desktop missed the minimum narrowly (413 key, 496 global), so it fell to the pooled 35.3. Its key p99 is 8.

Key p99 values are small integers. Many cells sit at exactly 3 or 4, so they can't tell the groups apart. A 7-day window on one key is too coarse for p99 to separate Desktop from Mobile at Dict 15/31.

## Global cells vs spec §4 indicative table (p99 per 40 min, clean)

Sample: one weekday (19 Nov), all keys except the synthetics key and 13 single-JA4 keys (3 Payoneer + 10 others, `02_proxy_keys_19nov.sql`). It is a **1-in-16 sample by signature** (`MOD(ABS(HASH(public_key, matched_signature)), 16) = 0`): 5.50M sessions, 342 keys, 325k signatures. Format: **measured** (spec). Clean signature-windows in brackets where under 500.

| Dict | Desktop | Mobile | Linux | Win RD/VM | Other |
|---|---|---|---|---|---|
| 1 | 79.3 (69) [496] | 15.9 (26) | 19.2 (19) [91] | 10.5 (pooled) [47] | 30.6 (pooled) [50] |
| 3 | 104 (66) | 21 (36) | 16.6 (45) | 16.4 (62) | 11.4 (78) [163] |
| 7 | 29 (20) | 7 (12) | 30.8 (18) | 10 (14) | 10.2 (9) [96] |
| 15 | 13 (11) | 21 (26) | 10.1 (13) | 7 (8) | 6.4 (23) [259] |
| 31 | 27 (15) | 18 (11) | 66.5 (18) | 7 (8) | 7.1 (25) [33] |
| 63 | 20 (19) | 72 (58) | 13 (30) | 20 (19) | 16.7 (32) |

Pooled across groups: Dict 1 35.3, Dict 3 68.0, Dict 7 25.0, Dict 15 17.0, Dict 31 26.0, Dict 63 37.0; Dict -1 134.2 (145 windows) and Dict -1 + 1 68.7.

**Reading.** Dict 63 Desktop / Win RD/VM and Dict 15 Desktop / Win RD/VM match the spec within 1-2. The measured values are higher than the spec for Desktop Dict 3 (104 vs 66), Dict 7 (29 vs 20) and Dict 31 (27 vs 15), Linux Dict 31 (66.5 vs 18) and Mobile Dict 63 (72 vs 58). They are lower for Mobile Dict 1/3/7/15, Win RD/VM Dict 3 (16 vs 62) and most "Other" cells. The sample is one day and one in 16 signatures, so a few very large signatures decide whether they land in the sample. Mobile Dict 63 has one 40-minute signature-window of 19,659 sessions, and Desktop Dict 7 has 530k sampled sessions at 35% High risk. Treat differences under about 2x as noise. The spec's method (window, sample, period) isn't recorded, so the comparison is indicative only.
