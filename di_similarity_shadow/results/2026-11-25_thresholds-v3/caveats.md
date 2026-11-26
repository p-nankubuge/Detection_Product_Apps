# Caveats v3: what was sampled, approximated, timed out or not done (thresholds v3, D-13 sensitivity)

All v1 and v2 caveats still apply (`results/2026-11-25_thresholds/caveats.md`, `results/2026-11-25_thresholds-v2/caveats.md`): fixed 40-minute buckets vs DI's own two-bucket count, LT = base x LT multiplier x 60 is an assumption, platform-group rules, List C as implemented, High risk and verified are indicators only, no truth data. New or different in v3:

## Figma base (exact, computed differently)
- The one-scan p99 + p99.9 query (`01_figma_base_p99_p999.sql`) **timed out twice** on 25 Nov (v1's similar query ran in 22 s; the warehouse seemed slower). It was replaced by `01_figma_base_histogram.sql`: histograms of clean signature-window sizes in 3 day-chunks (13-15, 15-17, 17-20 Nov). 40-minute `TIME_SLICE` buckets never cross a UTC day, so the chunks add up exactly. p99 / p99.9 were computed in `02_build_matrices_v3.py` with PERCENTILE_CONT's linear interpolation. Check: all 42 cells reproduce v2's window counts and p99 exactly.
- One small difference in the `session_last_timestamp` filter: each chunk uses [chunk start, 20 Nov 06:00), the same upper bound as v2. Sessions created in a chunk but with a last timestamp before the chunk start cannot exist, so this matches v2's single filter.

## Payoneer (G8): partial recomputation
- The full Payoneer base with p99.9 **timed out twice** (`03_`). Chunked histograms (`03b_`) ran, but even with p98-cut tails and bucketing, one 2-day chunk returned ~20k tokens because of long-tailed proxy cells (EE844FC3 Dict 63 / 15 / 3 Mobile, up to 1,008 sessions per window). The remaining chunks were **not run**, and `03b_`'s output was not used.
- Instead only the **EE844FC3 Dict 1** cells were recomputed exactly over the full 7 days (`03c_`). Justification: in the L1 window 113,592 of 113,595 V0 fires are Dict 1, and every variant's threshold is >= V0's in every cell, so non-Dict-1 cells can only lose fires (at most 3). E3EFEFBF and 7CC24C4A Dict 1 cells are at step (b) in every variant (window counts do not depend on the variant).
- In the L1 replay, non-Dict-1 cells use v2 (V0) values for all variants, so V1-V3 totals are exact to within 3 sessions (an upper bound).
- No full Payoneer matrix for V1-V3 exists.

## Adobe (K3)
- Base **sampled by window**, as in v2 (14 whole 40-minute buckets, 04:00 and 16:00 UTC, 11-17 Nov). p99.9 on a sample of 14 of 252 windows is less stable than p99. The attack-cell results depend on Dict 15 / 31 / 63 Desktop p99.9 = 12 / 26 / 52.
- The current threshold used for (b) and the cap is the live 90 / 5,400, as in v2.

## Figma replay
- V3 was not a separate scan: one query evaluates all four variants. V3's rows are identical to V2's in the output; `raw/05_` stores the V3 rows as a copy of V2 with a note.
- `06_` (slice) groups only by (variant, dict, group) and (variant); the saved SQL matches what ran.
- G7 uses the per-dict rate as in v1 / v2. v1 stated "14 cells" but listed 13; under the v3 script, V0 gives 14 (13 + Dict 1 Desktop), or 15 counting Dict 63 Mobile against today's effective rate. That matches v2's "15".
- The 40 sessions that today fires and V2/V3 do not ("today-only", excluding exempt Dict 63 and List A) were counted but **not profiled** for risk.

## Process
- An API spend limit interrupted the run after `matrix.md`. Nothing was re-run on resume: the L1 and K3 outputs were saved to `raw/08_` / `raw/09_` from the results obtained before the interruption.

## Not done
- No top-20-keys matrix; global cells not recomputed (as v1 / v2).
- Untested D-13 options: floor at today's threshold, larger minimum volume, IP-diversity / fleet exception for Dict 63 Linux.
- No sensitivity on the minimum volume (500), the clean rule or the LT assumption.
- No truth-data check of any variant's fires.
- Read-only throughout; nothing outside this folder edited; nothing committed.
