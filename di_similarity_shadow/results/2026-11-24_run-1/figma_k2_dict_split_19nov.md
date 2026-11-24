# Figma Registration K2: sessions by DI dictionary, 19 Nov vs 20 Nov

- **Key:** `A207F8A1-ED09-4325-ACE6-C8E26A458FBA` (Figma Registration K2)
- **Windows:** 12:00–14:00 UTC on 2026-11-19 and 2026-11-20 (game_verify joined to 15:00)
- **Source:** `ARK_PROD.events.vw_events`, Superset `database_id` 14
- **Sampling:** none (19 Nov: 11,571 sessions; 20 Nov: 9,156)
- **Query:** `figma_k2_dict_split_19nov.sql` (identical to `figma_k2_dict_split.sql` except the dates)

## 19 Nov

| Dict | Sessions | % of sessions | Reached verify | Verified | Verify rate (all) | Verify rate (reached) |
|---:|---:|---:|---:|---:|---:|---:|
| -1 | 1 | 0.01% | 0 | 0 | 0.00% | n/a |
| 1 | 46 | 0.40% | 37 | 37 | 80.43% | 100.00% |
| 3 | 650 | 5.62% | 580 | 574 | 88.31% | 98.97% |
| 7 | 1,421 | 12.28% | 1,256 | 1,247 | 87.76% | 99.28% |
| 15 | 1,181 | 10.21% | 1,059 | 1,055 | 89.33% | 99.62% |
| 31 | 1,867 | 16.14% | 1,696 | 1,689 | 90.47% | 99.59% |
| 63 | 6,405 | 55.35% | 6,086 | 6,057 | 94.57% | 99.52% |

## Comparison with 20 Nov

| Dict | 19 Nov % | 20 Nov % | 19 Nov verify (reached) | 20 Nov verify (reached) |
|---:|---:|---:|---:|---:|
| -1 | 0.01% | 0.01% | n/a | 100.00% |
| 1 | 0.40% | 0.25% | 100.00% | 100.00% |
| 3 | 5.62% | 4.87% | 98.97% | 99.75% |
| 7 | 12.28% | 12.43% | 99.28% | 99.61% |
| 15 | 10.21% | 11.52% | 99.62% | 98.76% |
| 31 | 16.14% | 16.06% | 99.59% | 99.21% |
| 63 | 55.35% | 54.86% | 99.52% | 99.77% |

## Observations

- Volume was ~26% higher on 19 Nov, but dictionary shares moved by at most ~1.3 points. The 20 Nov window is typical.
- Same pattern both days: ~99% of sessions that reach a challenge pass it; the lower "all sessions" rate at low dictionaries comes from fewer sessions reaching a challenge.
- Dict 1 was 46 sessions on 19 Nov vs 23 on 20 Nov; both are small counts.

## Not done

- Only two days compared; no longer-term baseline.
