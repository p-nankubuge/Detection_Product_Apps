# Caveats v2: what was sampled, approximated, timed out or not done (thresholds v2, 25 Nov)

All v1 caveats (`results/2026-11-25_thresholds/caveats.md`) still apply: fixed 40-minute buckets vs DI's two-bucket count (not like-for-like), LT = base x LT multiplier x 60 is an assumption, platform-group rules, group mixing below Dict 63, List C is my implementation of C1-C3, High risk and verified are indicators only, no truth data. Below is what is new or different in v2.

## Inputs reused, not re-run
- Figma per-group key cells are v1's `01_figma_base.sql` output (copied as `00_figma_base_key_cells_v1_reused.sql`), not recomputed. The new pooled query (`01_figma_base_pooled.sql`) scanned the same base and its Dict 63 pooled counts match v1's per-group sums exactly; Dict -1 / 1 / 3 / 7 / 15 / 31 differ slightly because pooling merges a signature across groups.
- Global cells are v1's, used only as a cross-check. Not recomputed.
- v1's `04_build_matrix.py` was not used (scratchpad path); `03_build_matrix_v2.py` re-implements the matrix from the recorded numbers and prints the VALUES list.

## Definitions chosen for D-11
- **Pooled cell (step a)** = signature-window of matched signature x bucket with groups **merged** (one signature spanning Desktop and Win RD/VM counts once, as DI counts). The alternative (union of per-group windows) is reported as a sensitivity: Dict 1 p99 7.00 instead of 7.49, Dict 3 7 instead of 8; no replay effect on Figma (Dict 1 max ST count 8 either way fires at 7.00 and 7.49).
- **Minimum** 500 clean signature-windows for both the key cell and the pooled cell (same as v1).
- **Cap** applied to the fallback value **after** multipliers (ST <= 11, LT <= 660 on Figma). Applied separately to ST and LT. Bit only on LT for 15 / 31 / 63 Other. Real key cells are not capped (LT 720 at Dict 15 / 31 and 1,080-1,800 at Dict 63 exceed today's 660).
- **Current threshold** = count / ratio median over the window. Figma: 11 / 660 on every session. Payoneer: 35 / 2,100 (EE844FC3), 15 / 900 (E3EFEFBF), 60 / 3,600 (7CC24C4A), over the base week. Adobe ARP K8: the base-week median was 100 / 6,000 but every session on 17 Nov 04:00 and 18 Nov 03:00 had 90 / 5,400, so the threshold changed during the week; the **live value at replay (90 / 5,400)** is used for step (b) and the cap.

## Known cases (new in v2: per-key cells instead of global)
- **L1 Payoneer:** each key's own cells from a 7-day base (11-18 Nov 00:00, 4.05M sessions, no sampling, 29 s). The JA4 change started 17 Nov 21:00, so the last 3 hours of the base (21:00-24:00) already include the new JA4 at Dict 1. Those windows are clean (1% High) and enter Dict 1 cells; the effect was not isolated. List C not applied (proxy keys), as v1.
- **K3 Adobe ARP K8:** base **sampled by window**: 14 whole 40-minute buckets (04:00 and 16:00 UTC, 11-17 Nov), 2.05M sessions. Whole buckets keep per-signature-window counts unbiased, but the p99 rests on 14 of 252 windows, and the two times of day may not represent the rest. Sessions lasting more than 2 h after their bucket start were missed (`session_last_timestamp` filter). The base week includes the attack (ramped 12 Nov); attack windows are 100% High so they are excluded as not clean. Replay attack cohort is 2,084 sessions vs v1's 2,075 (rows arrived since v1).
- K3 and L1 each use one window, not a whole day (as v1).

## Dict 63 Linux examples
- 20 of the 25 fires are listed (first 20 by time); the summary row covers all 25. Screen and device_params come from `DI_HIGHEST_SIGNATURE_AT_SESSION_CREATED`; ASN, ISP, organization, connection type and VPN fields from `vw_events` (`session_setup`, first value per session).
- The IP-intel query (`07` part b) covers **all** session_setup events from 185.197.91.x on the key 09:40-13:40 (55 sessions), not only the 25 fires.
- The first combined IP-intel + history query **timed out** and was split; the split versions ran (28 s, 4.7 s).
- The reading ("consistent with identically imaged managed Linux PCs behind one public-sector NAT") is an interpretation of the fields, not a verified cause. The customer was not contacted and no truth data was checked.

## Not done
- No top-20-keys matrix (as v1).
- Global cells not recomputed; no global fallback anywhere.
- No sensitivity on the minimum volume (500) in v2. Note: with minimum 400, Dict 1 Desktop would use its own p99 8 and its 2 fires (count 8) would not fire.
- No truth-data check of the v2 fires.
- Read-only throughout; no file outside this folder was edited.
