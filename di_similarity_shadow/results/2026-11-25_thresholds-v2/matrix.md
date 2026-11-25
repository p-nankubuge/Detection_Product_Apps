# Threshold matrix v2 (per-key fallback, D-11): Figma Registration K2, per dictionary x platform group

Run 2026-11-25. Key `A207F8A1-ED09-4325-ACE6-C8E26A458FBA`. Base period: sessions created 13 Nov 00:00 to 20 Nov 00:00 UTC (7 days, no sampling, 655,839 sessions). Everything is identical to v1 (`results/2026-11-25_thresholds/`) **except the fallback**. Read `caveats.md` before using these numbers.

Queries: `00_figma_base_key_cells_v1_reused.sql` (v1 per-group key cells, reused unchanged), `01_figma_base_pooled.sql` (new: key x dict pooled across groups), `03_build_matrix_v2.py` (fallback and multipliers).

## How a cell is built (unchanged from v1 unless marked)

- **Counted:** sessions per matched signature (`DI_MATCHED_SIGNATURE_AT_SESSION_CREATED`) per fixed 40-minute bucket (`TIME_SLICE(session_ts, 40, 'MINUTE')`), split by platform group. List A/B/C sessions skipped.
- **Clean:** signature-windows with < 20% `latest_risk_band = 'High'`. **Base** = p99 of sessions per clean signature-window.
- **Minimum volume:** 500 clean signature-windows (unchanged).
- **Fallback (new, D-11):**
  1. key x dict x group cell if >= 500 clean signature-windows ("key");
  2. else **(a)** the same key x dict **pooled across all platform groups** (signature-window = matched signature x bucket, groups merged, which is how DI counts) if >= 500;
  3. else **(b)** the key's current threshold, **ST 11 / LT 660**.
  4. A fallback value is capped at ST 11 / LT 660. Real key cells are not capped. No global cell is used.
- **Multipliers (ESM-6922):** ST 1x (Dict -1/1/3), 1.5x (7), 2x (15/31/63); LT 1x / 2x / 4x / 6x; Win RD/VM capped at 1.5x / 2x. **LT = base x LT multiplier x 60** (v1 assumption, kept).

## Key x dict pooled across groups (new input)

| Dict | Clean sig-windows (pooled) | Pooled p99 | Used as fallback (a)? |
|---|---|---|---|
| -1 | 30 | 7.55 | No (< 500) -> (b) |
| 1 | 652 | 7.49 | Yes |
| 3 | 20,041 | 8 | Yes (Other) |
| 7 | 57,955 | 4 | Yes (Other) |
| 15 | 52,754 | 3 | Yes (Other) |
| 31 | 87,579 | 3 | Yes (Other) |
| 63 | 282,092 | 4 | Yes (Other) |

Sensitivity: pooling as a union of the per-group signature-windows (a signature spanning Desktop and Win RD/VM counted once per group) gives Dict 1 677 windows / p99 7.00 and Dict 3 20,435 / 7.00; other dicts are the same. Variant P (groups merged) is used.

## Figma K2 matrix v2 (after multipliers)

Columns: clean sig-windows in the key cell | key p99 | **source** | base used | ST | LT. Today: ST 11 / LT 660 everywhere. Bold = changed vs v1.

| Dict | Group | Clean sig-windows (key) | Key p99 | Source | Base | ST | LT | v1 ST / LT |
|---|---|---|---|---|---|---|---|---|
| -1 | Desktop | 21 | 8 | **(b) current** | - | **11** | **660** | 68.7 / 4,122 |
| -1 | Mobile | 5 | 1 | **(b) current** | - | **11** | **660** | 68.7 / 4,122 |
| -1 | Linux | 1 | 1 | **(b) current** | - | **11** | **660** | 68.7 / 4,122 |
| -1 | Win RD/VM | 0 | - | **(b) current** | - | **11** | **660** | 68.7 / 4,122 |
| -1 | Other | 5 | 1 | **(b) current** | - | **11** | **660** | 68.7 / 4,122 |
| 1 | Desktop | 413 | 8 | **(a) key pooled** | 7.49 | **7.49** | **449.4** | 35.3 / 2,118 |
| 1 | Mobile | 165 | 3.36 | **(a) key pooled** | 7.49 | **7.49** | **449.4** | 15.9 / 954 |
| 1 | Linux | 65 | 5.08 | **(a) key pooled** | 7.49 | **7.49** | **449.4** | 35.3 / 2,118 |
| 1 | Win RD/VM | 28 | 4.46 | **(a) key pooled** | 7.49 | **7.49** | **449.4** | 35.3 / 2,118 |
| 1 | Other | 6 | 1.95 | **(a) key pooled** | 7.49 | **7.49** | **449.4** | 35.3 / 2,118 |
| 3 | Desktop | 14,359 | 7 | key | 7 | 7 | 420 | same |
| 3 | Mobile | 3,449 | 9 | key | 9 | 9 | 540 | same |
| 3 | Linux | 1,602 | 6 | key | 6 | 6 | 360 | same |
| 3 | Win RD/VM | 969 | 5 | key | 5 | 5 | 300 | same |
| 3 | Other | 56 | 3 | **(a) key pooled** | 8 | **8** | **480** | 68 / 4,080 |
| 7 | Desktop | 50,697 | 4 | key | 4 | 6 | 480 | same |
| 7 | Mobile | 1,743 | 2 | key | 2 | 3 | 240 | same |
| 7 | Linux | 3,087 | 4 | key | 4 | 6 | 480 | same |
| 7 | Win RD/VM | 2,897 | 4 | key | 4 | 6 | 480 | same |
| 7 | Other | 11 | 1 | **(a) key pooled** | 4 | **6** | **480** | 37.5 / 3,000 |
| 15 | Desktop | 39,261 | 3 | key | 3 | 6 | 720 | same |
| 15 | Mobile | 9,791 | 3 | key | 3 | 6 | 720 | same |
| 15 | Linux | 2,198 | 3 | key | 3 | 6 | 720 | same |
| 15 | Win RD/VM | 1,475 | 4 | key | 4 | 6 (1.5x cap) | 480 (2x cap) | same |
| 15 | Other | 43 | 2 | **(a) key pooled** | 3 | **6** | **660 (capped from 720)** | 34 / 4,080 |
| 31 | Desktop | 76,762 | 3 | key | 3 | 6 | 720 | same |
| 31 | Mobile | 5,832 | 2 | key | 2 | 4 | 480 | same |
| 31 | Linux | 2,089 | 3 | key | 3 | 6 | 720 | same |
| 31 | Win RD/VM | 2,977 | 3 | key | 3 | 4.5 | 360 | same |
| 31 | Other | 1 | 1 | **(a) key pooled** | 3 | **6** | **660 (capped from 720)** | 52 / 6,240 |
| 63 | Desktop | 212,242 | 4 | key | 4 | 8 | 1,440 | same |
| 63 | Mobile | 60,986 | 5 | key | 5 | 10 | 1,800 | same |
| 63 | Linux | 2,451 | 3 | key | 3 | 6 | 1,080 | same |
| 63 | Win RD/VM | 6,382 | 4 | key | 4 | 6 | 480 | same |
| 63 | Other | 31 | 1 | **(a) key pooled** | 4 | **8** | **660 (capped from 1,440)** | 33.4 / 6,012 |

**Counts:** 20 key cells (unchanged), **10 cells at step (a)** (all 5 Dict 1 cells; "Other" for Dict 3, 7, 15, 31, 63), **5 cells at step (b)** (all Dict -1). The cap bit only on LT (15 / 31 / 63 Other); no fallback ST value reached 11. Every threshold is now at or below today's 11 / 660 except the real key cells' LT at Dict 15/31 (720) and Dict 63 Desktop / Mobile / Linux (1,080 to 1,800), which are not capped by design.

**What this means.** v1's fallback cells were 1.4x to 6x looser than today; v2's are tighter than or equal to today. Dict 1 goes from 35.3 (v1) to 7.49, below today's 11. Dict 1 Desktop's own p99 (8, 413 windows) is close to the pooled 7.49, so pooling did not distort it. "Other" cells now inherit the key's dict-level p99 (3 to 8), which is tight given Other has 4 to 16 sessions a day.

## Other keys (v2 per-key cells, used only for the known-case replays)

- **Payoneer (L1, G8):** `08_payoneer_key_base.sql`, `09_build_payoneer_matrix_v2.py`. Base 11-18 Nov (7 days, 4.05M sessions, no sampling). Current thresholds: EE844FC3 35 / 2,100; E3EFEFBF 15 / 900; 7CC24C4A 60 / 3,600. Dict 1 cells (where L1 lands): EE844FC3 Mobile key cell 12.0 (1,779 windows), other EE844FC3 Dict 1 cells (a) pooled 12.1; E3EFEFBF all Dict 1 at (b) 15 (pooled 177 windows); 7CC24C4A all Dict 1 at (b) 60 (pooled 26). Note EE844FC3 Dict 3 Desktop's real key cell is 231 and Dict 63 Mobile's is 148.7 (ST 297.4), far above today's 35, because proxy traffic piles many users onto few signatures.
- **Adobe ARP FF K8 (K3):** `11_k3_adobe_key_base_sampled.sql`, `12_build_k3_matrix_v2.py`. Base **sampled by window** (14 whole 40-minute buckets, 11-17 Nov; 2.05M sessions). Current threshold 90 / 5,400. Attack cells: Dict 15 Desktop 14 (key, p99 7), Dict 31 Desktop 22 (key, p99 11), Dict 63 Desktop 34 (key, p99 17). Fallbacks: Dict -1 and Dict 1 at (b) 90 (Dict 1 pooled 423 windows); Dict 3 Linux / Win RD/VM / Other at (a) 181 capped to 90; Dict 7 / 15 / 31 / 63 Other at (a).

## Global cells (cross-check only, not recomputed)

v1's global table (`results/2026-11-25_thresholds/matrix.md`, one weekday, 1-in-16 by signature) is the only global computation; v2 uses it only to compare. It is no longer an input to any key's threshold. Figma's own cells are 2x to 20x below the global ones (e.g. Dict 63 Desktop 4 vs 20, Dict 7 Desktop 4 vs 29), so a global fallback was never a good proxy for this key.

## Top 20 keys

Not done (as in v1). Only Figma has a full matrix; Payoneer and Adobe ARP K8 matrices exist only to replay L1 / K3.
