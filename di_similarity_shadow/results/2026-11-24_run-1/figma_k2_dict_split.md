# Figma Registration K2: sessions by DI dictionary

- **Key:** `A207F8A1-ED09-4325-ACE6-C8E26A458FBA` (Figma Registration K2)
- **Window:** 2026-11-20 12:00–14:00 UTC (session_setup); game_verify joined to 15:00
- **Source:** `ARK_PROD.events.vw_events`, Superset `database_id` 14
- **Sampling:** none (all 9,156 sessions)
- **Query:** `figma_k2_dict_split.sql`

| Dict | Sessions | % of sessions | Reached verify | Verified | Verify rate (all) | Verify rate (reached) |
|---:|---:|---:|---:|---:|---:|---:|
| -1 | 1 | 0.01% | 1 | 1 | 100.00% | 100.00% |
| 1 | 23 | 0.25% | 20 | 20 | 86.96% | 100.00% |
| 3 | 446 | 4.87% | 400 | 399 | 89.46% | 99.75% |
| 7 | 1,138 | 12.43% | 1,028 | 1,024 | 89.98% | 99.61% |
| 15 | 1,055 | 11.52% | 967 | 955 | 90.52% | 98.76% |
| 31 | 1,470 | 16.06% | 1,384 | 1,373 | 93.40% | 99.21% |
| 63 | 5,023 | 54.86% | 4,737 | 4,726 | 94.09% | 99.77% |

## Method notes

- One row per session: dictionary taken from the session's earliest `session_setup` row (`MIN_BY`).
- "Reached verify" = session has at least one `game_verify` row; "verified" = at least one row with `verified = 1`.
- Verify rate (all) = verified / all sessions; verify rate (reached) = verified / reached verify.
- `timestamp` is `TIMESTAMP_NTZ`; confirmed UTC (latest event vs `SYSDATE()` differed by 0 minutes).

## Observations

- Dict 63 is 55% of traffic; Dict -1 and 1 together are only 24 sessions (rates not meaningful).
- Among sessions that reached verify, the rate is 98.8–100% at every dictionary, so "verified" does not separate dictionaries on this key in this window.
- The verify rate over all sessions rises with dictionary (87% → 94%), driven by the share reaching `game_verify` (~90% at Dict 3–15 vs ~94% at Dict 63), not by pass rate.

## Not done

- No comparison with the same hours the day before (19 Nov) yet.
- No truth-data join yet (Figma TD is in Athena, `starfleet_production.truth_data_history`).
- Did not investigate why sessions without a `game_verify` row stopped (abandoned, not challenged, or other).
