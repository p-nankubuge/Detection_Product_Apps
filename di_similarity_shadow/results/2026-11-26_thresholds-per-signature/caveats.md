# Caveats: per-signature threshold (D-19) test, 26 Nov

## What was not done
- **Long-term (LT) not tested.** Short-term only. "Today" is DI's recorded ST breach; Blizzard's ST-or-LT totals are given alongside.
- **Blizzard Nonlegit labels: 3,670 of 5,718 scored (9 Nov only; 64%).** The 10 Nov (981) and 11 Nov (1,067) labels were **not scored**.
  - Labels and session IDs can only pass between Athena and Snowflake through the tool responses, and each ID list costs about 25k tokens.
  - The full label export was ~73k tokens and was rejected by the response cap.
  - The 3-day Snowflake export of fired verified sessions timed out twice, so it was run per day. Only 9 Nov was completed before stopping for context budget.
  - To finish: run `07b_` for 10 and 11 Nov (change the dates) and `08_` with those groups.
- **Blizzard G7 per cell uses 9 Nov only.** The 3-day per-cell query (`09_`) timed out. The 3-day totals (fires, clean fires, High %) are complete.
- **Figma truth data not used.** Figma's Legit / Nonlegit labels could give a false-positive rate. Not requested and not run.
- **Fleet group not re-identified.** The Dict 63 Linux cell is reported as a whole. I did not check that every fire is the single Firefox 156 / junta de andalucia signature from v2.
- **Not profiled:** the 50 clean fires in Blizzard Dict 31 Desktop at floor 11; the 108 Figma fires lost at m20 f11; the 1,048 Blizzard fires lost on 10-11 Nov (on 9 Nov, 251 of 279 are the Dict 63 Other cell).
- No K3 (Adobe) replay. Not requested for this run; K3's current threshold (90) is above both floors.
- No global or top-20-keys matrix (see `matrix.md`).

## Approximations and definitions
- **Volume** = the key's sessions in the previous 20-min `TIME_SLICE` plus the current one **up to and including** this session (what DI could know at `session_setup`). The brief says "same current + previous buckets", which could also mean the full current bucket. The full-bucket version was not run; it would raise expected counts a little and lower fires.
- **Share** = non-High sessions with the signature over the 7 days / all non-High sessions of the key. Signatures with no history get share 0. Volume counts all sessions (any risk, any dict, List A/B/C included), so expected is a little higher on keys with many High sessions.
- **High** = `latest_risk_band` (the latest band, not the band at creation), as in v1-v3.
- **Clean window** = List flag x platform group x matched signature x **fixed** 40-min `TIME_SLICE` (as v3), not DI's rolling two-bucket window.
- **Count** = DI's recorded `DI_SHORT_TERM_COUNT_AT_SESSION_CREATED`; not recomputed.
- No Windows RD/VM multiplier cap. The spec's 1.5x cap belongs to the per-cell design; D-19 does not mention it.
- **Label join.** Labels were joined on a shortened session-ID key.
  - The 10-digit part after the dot ends in a 2-digit code (01-05; not random). So the key is the first 8 (or 7) random digits plus the last digit.
  - Expected false matches: about 0.005 per day (8 digits, 1,010 IDs) and about 0.1 (7 digits, 56 IDs).
  - Observed: 490 matched rows = 490 distinct labels, so no duplicates.
- **Label coverage.** 20 of 20 sampled label sessions exist in `PROD_INT_SESSION_SUMMARY` and are verified there. Labels whose session is not verified in Snowflake would be counted as "not fired". The sample found none.
- **Label completeness** (Nonlegit labels / verified sessions in the summary): 9 Nov 3,670 / 45,407 = 8.1%; 10 Nov 981 / 41,323 = 2.4%; 11 Nov 1,067 / 45,243 = 2.4%.
  - Labels arrived 9 Nov 17:10 to 23 Nov 17:18. Partitions were read to 26 Nov.
  - Blizzard is selective (gmail, KR and iOS are rarely labelled). "Not labelled" is not "legit".
- Blizzard `vw_events` session_setup rows per day (51k-137k, 2-11 Nov) are much higher than the "~19k/day" in `known_cases.md`. Summary sessions: 64k-73k per replay day.

## Failures
- Timeouts: the 3-day fired-set export (twice: with cross join, then without) and the 3-day per-cell G7 query. Single-day versions of the same SQL ran in ~17 s.
- One MCP connection drop (retried, succeeded).
- The first 9 Nov ID export was capped at 5 rows by the `limit` parameter. This was caught (1,010 of 1,066), and the remaining 56 IDs were fetched separately.
- `01_blizzard_checks.sql` was changed before it ran (thresholds only where count > 0). The saved file matches what ran.

## Read-only
Only SELECTs were run. Files were written only to this folder and the session scratchpad. Nothing was committed. `spec.md` and `decisions.md` were not edited.
