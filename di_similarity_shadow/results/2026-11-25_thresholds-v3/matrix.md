# Threshold matrix v3 (D-13 sensitivity): Figma Registration K2, four base variants

Run 2026-11-25. Key `A207F8A1-ED09-4325-ACE6-C8E26A458FBA`. Everything is identical to thresholds v2 (`results/2026-11-25_thresholds-v2/`) except the **base statistic**:

| Variant | Base per cell (key cell and pooled fallback cell alike) |
|---|---|
| V0 | p99 (= v2) |
| V1 | max(p99, 5), floor applied before multipliers |
| V2 | p99.9 |
| V3 | max(p99.9, 5) |

Unchanged from v2: base = sessions created 13 Nov 00:00 to 20 Nov 00:00 UTC (no sampling); signature = `DI_MATCHED_SIGNATURE_AT_SESSION_CREATED`; fixed 40-minute `TIME_SLICE` buckets; clean = signature-window with < 20% High; List A/B/C skipped; platform groups; per-key fallback (key cell if >= 500 clean signature-windows, else (a) key x dict pooled across groups if >= 500, else (b) the key's current threshold ST 11 / LT 660; fallback values capped at 11 / 660 after multipliers; real key cells not capped); multipliers ST 1 / 1 / 1.5 / 2 / 2 / 2 and LT 1 / 1 / 2 / 4 / 4 / 6 (Dict 1, 3, 7, 15, 31, 63), Win RD/VM capped at 1.5x / 2x; **LT = base x LT multiplier x 60** (v1 assumption); Dict 63 exemption removed.

Inputs: `01_figma_base_histogram.sql` (3 day-chunks, histograms in `base_histograms/figma_*.txt`), `02_build_matrices_v3.py figma` (output `raw/02_matrix_figma.txt`). Percentiles = PERCENTILE_CONT linear interpolation computed from the merged histograms. **Check:** all 35 key cells and 7 pooled cells reproduce v2's clean-window counts and p99 exactly (e.g. Dict 63 Desktop 212,242 / 4; Dict 1 pooled 652 / 7.49), and V0 reproduces v2's matrix value for value.

Source codes: `key` = key cell; `(a)` = key x dict pooled; `(a,capped)` = pooled value hit the cap (11 ST and/or 660 LT); `(b)` = current threshold. Today: ST 11 / LT 660 in every cell.

## Figma K2 matrix, all variants

| Dict | Group | Clean sig-win (key) | p99 / p99.9 (key) | Pooled sig-win | p99 / p99.9 (pooled) | Source V0 / V1 / V2 / V3 | V0 ST / LT | V1 ST / LT | V2 ST / LT | V3 ST / LT |
|---|---|---|---|---|---|---|---|---|---|---|
| -1 | Desktop | 21 | 8.0 / 8.9 | 30 | 7.55 / 8.86 | (b) / (b) / (b) / (b) | 11 / 660 | 11 / 660 | 11 / 660 | 11 / 660 |
| -1 | Mobile | 5 | 1.0 / 1.0 | 30 | 7.55 / 8.86 | (b) / (b) / (b) / (b) | 11 / 660 | 11 / 660 | 11 / 660 | 11 / 660 |
| -1 | Linux | 1 | 1.0 / 1.0 | 30 | 7.55 / 8.86 | (b) / (b) / (b) / (b) | 11 / 660 | 11 / 660 | 11 / 660 | 11 / 660 |
| -1 | Win RD/VM | 0 | None / None | 30 | 7.55 / 8.86 | (b) / (b) / (b) / (b) | 11 / 660 | 11 / 660 | 11 / 660 | 11 / 660 |
| -1 | Other | 5 | 1.0 / 1.0 | 30 | 7.55 / 8.86 | (b) / (b) / (b) / (b) | 11 / 660 | 11 / 660 | 11 / 660 | 11 / 660 |
| 1 | Desktop | 413 | 8.0 / 15.29 | 652 | 7.49 / 15.09 | (a) / (a) / (a,capped) / (a,capped) | 7.49 / 449.4 | 7.49 / 449.4 | 11 / 660 | 11 / 660 |
| 1 | Mobile | 165 | 3.36 / 5.67 | 652 | 7.49 / 15.09 | (a) / (a) / (a,capped) / (a,capped) | 7.49 / 449.4 | 7.49 / 449.4 | 11 / 660 | 11 / 660 |
| 1 | Linux | 65 | 5.08 / 6.81 | 652 | 7.49 / 15.09 | (a) / (a) / (a,capped) / (a,capped) | 7.49 / 449.4 | 7.49 / 449.4 | 11 / 660 | 11 / 660 |
| 1 | Win RD/VM | 28 | 4.46 / 4.95 | 652 | 7.49 / 15.09 | (a) / (a) / (a,capped) / (a,capped) | 7.49 / 449.4 | 7.49 / 449.4 | 11 / 660 | 11 / 660 |
| 1 | Other | 6 | 1.95 / 2.0 | 652 | 7.49 / 15.09 | (a) / (a) / (a,capped) / (a,capped) | 7.49 / 449.4 | 7.49 / 449.4 | 11 / 660 | 11 / 660 |
| 3 | Desktop | 14359 | 7.0 / 12.0 | 20041 | 8.0 / 12.0 | key / key / key / key | 7.0 / 420.0 | 7.0 / 420.0 | 12.0 / 720.0 | 12.0 / 720.0 |
| 3 | Mobile | 3449 | 9.0 / 12.0 | 20041 | 8.0 / 12.0 | key / key / key / key | 9.0 / 540.0 | 9.0 / 540.0 | 12.0 / 720.0 | 12.0 / 720.0 |
| 3 | Linux | 1602 | 6.0 / 9.4 | 20041 | 8.0 / 12.0 | key / key / key / key | 6.0 / 360.0 | 6.0 / 360.0 | 9.4 / 564.0 | 9.4 / 564.0 |
| 3 | Win RD/VM | 969 | 5.0 / 7.0 | 20041 | 8.0 / 12.0 | key / key / key / key | 5.0 / 300.0 | 5.0 / 300.0 | 7.0 / 420.0 | 7.0 / 420.0 |
| 3 | Other | 56 | 3.0 / 3.0 | 20041 | 8.0 / 12.0 | (a) / (a) / (a,capped) / (a,capped) | 8.0 / 480.0 | 8.0 / 480.0 | 11 / 660 | 11 / 660 |
| 7 | Desktop | 50697 | 4.0 / 8.0 | 57955 | 4.0 / 8.0 | key / key / key / key | 6.0 / 480.0 | 7.5 / 600 | 12.0 / 960.0 | 12.0 / 960.0 |
| 7 | Mobile | 1743 | 2.0 / 6.52 | 57955 | 4.0 / 8.0 | key / key / key / key | 3.0 / 240.0 | 7.5 / 600 | 9.78 / 782.4 | 9.78 / 782.4 |
| 7 | Linux | 3087 | 4.0 / 6.91 | 57955 | 4.0 / 8.0 | key / key / key / key | 6.0 / 480.0 | 7.5 / 600 | 10.37 / 829.2 | 10.37 / 829.2 |
| 7 | Win RD/VM | 2897 | 4.0 / 9.1 | 57955 | 4.0 / 8.0 | key / key / key / key | 6.0 / 480.0 | 7.5 / 600 | 13.65 / 1092.0 | 13.65 / 1092.0 |
| 7 | Other | 11 | 1.0 / 1.0 | 57955 | 4.0 / 8.0 | (a) / (a) / (a,capped) / (a,capped) | 6.0 / 480.0 | 7.5 / 600 | 11 / 660 | 11 / 660 |
| 15 | Desktop | 39261 | 3.0 / 8.0 | 52754 | 3.0 / 7.0 | key / key / key / key | 6.0 / 720.0 | 10 / 1200 | 16.0 / 1920.0 | 16.0 / 1920.0 |
| 15 | Mobile | 9791 | 3.0 / 5.0 | 52754 | 3.0 / 7.0 | key / key / key / key | 6.0 / 720.0 | 10 / 1200 | 10.0 / 1200.0 | 10.0 / 1200.0 |
| 15 | Linux | 2198 | 3.0 / 5.0 | 52754 | 3.0 / 7.0 | key / key / key / key | 6.0 / 720.0 | 10 / 1200 | 10.0 / 1200.0 | 10.0 / 1200.0 |
| 15 | Win RD/VM | 1475 | 4.0 / 6.0 | 52754 | 3.0 / 7.0 | key / key / key / key | 6.0 / 480.0 | 7.5 / 600 | 9.0 / 720.0 | 9.0 / 720.0 |
| 15 | Other | 43 | 2.0 / 2.0 | 52754 | 3.0 / 7.0 | (a,capped) / (a,capped) / (a,capped) / (a,capped) | 6.0 / 660 | 10 / 660 | 11 / 660 | 11 / 660 |
| 31 | Desktop | 76762 | 3.0 / 7.0 | 87579 | 3.0 / 7.0 | key / key / key / key | 6.0 / 720.0 | 10 / 1200 | 14.0 / 1680.0 | 14.0 / 1680.0 |
| 31 | Mobile | 5832 | 2.0 / 4.17 | 87579 | 3.0 / 7.0 | key / key / key / key | 4.0 / 480.0 | 10 / 1200 | 8.34 / 1000.8 | 10 / 1200 |
| 31 | Linux | 2089 | 3.0 / 5.91 | 87579 | 3.0 / 7.0 | key / key / key / key | 6.0 / 720.0 | 10 / 1200 | 11.82 / 1418.4 | 11.82 / 1418.4 |
| 31 | Win RD/VM | 2977 | 3.0 / 8.02 | 87579 | 3.0 / 7.0 | key / key / key / key | 4.5 / 360.0 | 7.5 / 600 | 12.03 / 962.4 | 12.03 / 962.4 |
| 31 | Other | 1 | 1.0 / 1.0 | 87579 | 3.0 / 7.0 | (a,capped) / (a,capped) / (a,capped) / (a,capped) | 6.0 / 660 | 10 / 660 | 11 / 660 | 11 / 660 |
| 63 | Desktop | 212242 | 4.0 / 9.0 | 282092 | 4.0 / 9.0 | key / key / key / key | 8.0 / 1440.0 | 10 / 1800 | 18.0 / 3240.0 | 18.0 / 3240.0 |
| 63 | Mobile | 60986 | 5.0 / 8.0 | 282092 | 4.0 / 9.0 | key / key / key / key | 10.0 / 1800.0 | 10.0 / 1800.0 | 16.0 / 2880.0 | 16.0 / 2880.0 |
| 63 | Linux | 2451 | 3.0 / 6.55 | 282092 | 4.0 / 9.0 | key / key / key / key | 6.0 / 1080.0 | 10 / 1800 | 13.1 / 2358.0 | 13.1 / 2358.0 |
| 63 | Win RD/VM | 6382 | 4.0 / 8.0 | 282092 | 4.0 / 9.0 | key / key / key / key | 6.0 / 480.0 | 7.5 / 600 | 12.0 / 960.0 | 12.0 / 960.0 |
| 63 | Other | 31 | 1.0 / 1.0 | 282092 | 4.0 / 9.0 | (a,capped) / (a,capped) / (a,capped) / (a,capped) | 8.0 / 660 | 10 / 660 | 11 / 660 | 11 / 660 |

## What changes between variants

- **V1 (floor 5)** only moves cells whose p99 is below 5: Dict 7 all groups (6 -> 7.5; Mobile 3 -> 7.5), Dict 15 / 31 (6 -> 10; Win RD/VM 4.5-6 -> 7.5), Dict 63 Desktop / Linux / Win RD/VM / Other (6-8 -> 7.5-10). Dict 1 (pooled 7.49), Dict 3 (5-9) and Dict 63 Mobile (5) do not move.
- **V2 (p99.9)** moves every key cell up by 1.3x to 3.3x (p99.9 / p99): e.g. Dict 63 Desktop 8 -> 18, Dict 15 Desktop 6 -> 16, Dict 31 Desktop 6 -> 14, Dict 7 Desktop 6 -> 12, Dict 3 Desktop 7 -> 12, Dict 63 Linux 6 -> 13.1. Pooled fallback cells (Dict 1 all groups, Dict 3 / 7 / 15 / 31 / 63 Other) reach the cap: Dict 1 pooled p99.9 = 15.09 -> capped at 11 = today.
- **V3 = V2 everywhere except Dict 31 Mobile** (p99.9 4.17 -> floor 5 -> ST 10 instead of 8.34). That cell has no fire on 20 Nov under either value, so V2 and V3 replay identically on Figma.
- Several V2 / V3 key cells now exceed today's 11 (Dict 3 Desktop / Mobile 12, Dict 7 Desktop 12, Win RD/VM 13.65, Dict 15 Desktop 16, Dict 31 Desktop 14, Win RD/VM 12.03, Linux 11.82, Dict 63 Desktop 18, Mobile 16, Linux 13.1, Win RD/VM 12). Allowed by D-11 (only fallback cells are capped).

## Other keys (used only for the known-case replays)

**Adobe ARP FF K8 (K3)**, `04_k3_adobe_key_base_sampled_p999.sql`, base sampled by window exactly as v2 (14 whole 40-minute buckets, 04:00 and 16:00 UTC, 11-17 Nov; 2,051,505 sessions). Current threshold 90 / 5,400. Full matrix in `raw/02_matrix_adobe.txt`. Attack cells:

| Cell | Clean sig-win | p99 / p99.9 | V0 = V1 ST / LT | V2 = V3 ST / LT |
|---|---|---|---|---|
| Dict 15 Desktop (key) | 69,830 | 7 / 12 | 14 / 1,680 | 24 / 2,880 |
| Dict 31 Desktop (key) | 95,565 | 11 / 26 | 22 / 2,640 | 52 / 6,240 |
| Dict 63 Desktop (key) | 240,373 | 17 / 52 | 34 / 6,120 | **104** / 18,720 (above today's 90; key cell, not capped) |

On Adobe the floor never binds in a key cell (all p99 >= 5 except cells that fall back), so V1 = V0 and V3 = V2.

**Payoneer (L1 / G8)**: only the EE844FC3 Dict 1 cells were recomputed (`03c_payoneer_dict1_base_p99_p999.sql`; the full Payoneer base timed out, see `caveats.md`). Current 35 / 2,100.

| EE844FC3 Dict 1 cell | Clean sig-win | p99 / p99.9 | V0 = V1 | V2 = V3 |
|---|---|---|---|---|
| Mobile (key) | 1,779 | 12.0 / 25.22 | 12.0 / 720 | 25.22 / 1,513.2 |
| Desktop, Linux, Win RD/VM, Other ((a) pooled) | 2,192 | 12.09 / 25.81 | 12.1 / 726 | 25.81 / 1,548.6 (below cap 35) |

E3EFEFBF and 7CC24C4A Dict 1 cells stay at (b) = today's threshold (15 and 60) in every variant (pooled 177 / 26 clean windows < 500). All other Payoneer cells kept at v2 (V0) values in the replay (an upper bound for V1-V3).

## Global cells and top 20 keys

Not done (as in v1 and v2). Global cells are a cross-check only and were not recomputed; no top-20-keys matrix.
