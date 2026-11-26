# Caveats: what was sampled, approximated, truncated or not done (similarity v4)

## Rules used
- These results use the "Seen-before rules" of the similarity-scorer agent file (platform groups for every seen-before lookup, physical
  screen size, null fix, OS-version rules with the frozen test, device_params never seen = desktop warning, software renderers → Other) on
  top of `spec.md` §2, exactly as v3, plus the 26 Nov design alignment for pair grading (D-18). Phase scope (user, 26 Nov): matching on the
  dictionary DI uses today; no pooled vertical whitelist (D-17 deferred). Decisions D-1 to D-19 read on 26 Nov; `spec.md` and
  `decisions.md` not edited.
- Kept identical to v3: key, window, all 9,156 sessions, whitelist scope, weights, partial credit, bands, Basic Render rule, closest device per
  exact OS family, OS-version handling (frozen lines Android, Chrome OS, Linux, Windows skipped; iOS+iPadOS and macOS checked).
- Standalone: no List A/B/C, N-rules, eligibility or bad/suspicious lists; Impossible column empty. Mobile screen fast track not applied.

## What v4 changes (implementation choices; please review)
1. **Pair frequency** = whitelist sessions with the pair ÷ whitelist sessions in the session's platform group, for UA×DP and screen×DP at the
   coarse and exact level, screen×WebGL (one level: screen is already the physical size) and screen×platform group (the screen's own
   frequency in the group). Computed from the same hashed lookup keys as v3 (sum of whitelist session counts per key instead of seen / not seen).
2. **Grading:** coarse never = failed check (unchanged); rare = coarse frequency < cut-off, or exact frequency < cut-off (exact never seen
   included) → **one** warning sign per pair (a pair that is rare at both levels counts once); common = pass. Same "never both" preconditions
   as v3; the exact level is graded only where the coarse pair is seen and (for UA×DP) the exact UA is seen.
3. **Main cut-offs** (chosen from step 1): desktop groups, all checks: exact-never only (implemented as cut-off 1e-12); mobile: screen×DP coarse
   < 1e-4 and screen×platform group < 1e-4. On desktop this is v3's rule, so v4 = v3 there by construction; checked on the data (0 differences).
4. **Warning signs:** desktop = rare pairs + never-seen screen + never-seen device_params (as v3); mobile = rare pairs, reported only.
   Screen × platform group failure on desktop still implies a never-seen-screen warning (same double count as v1-v3).
5. **What-if triggers** (desktop groups only; mobile trigger unchanged in all of them): a = v4 trigger OR coarse UA×DP failure; b = v4 trigger
   OR 2+ warning signs; c = a screen×WebGL failure is moved from failed checks to warning signs; a+b+c = all three together (with c applied
   first, so a freed SCRxGL counts as a warning toward b).
6. **Sensitivity variants** "uniform 1e-4 / 1e-3": one cut-off for every pair and level on desktop and mobile, v4 trigger.
7. The frequency denominators differ a lot by platform group (Desktop 272,232; Mobile 80,573; Windows RD/VM 8,032; Linux 2,842; Other 364),
   so the same frequency means a different session count per group. The "desktop" rows pool these groups (Desktop dominates).

## Sampling and coverage
- No sampling: all 9,156 sessions created 20 Nov 12:00-14:00 UTC (`PROD_INT_SESSION_SUMMARY`, read 26 Nov). Truth data not used.
- Whitelist as v3: Registration Production K2 364,042 Dict 63 sessions + Login Production 1 session (13-20 Nov), uncleaned (software
  renderers and odd JA4s are trusted). Not today's production Dict 63 dictionary; `account_id` membership not re-queried.

## Checks
- **Sanity test:** the 14 `spec.md` worked examples reproduce under v3 and v4 (`sanity_test_v4_result.md`), run with an artificial cut-off of
  0.5 to exercise the rare flags. The 8 extra v3 sanity rows were not re-run (logic unchanged; covered by the regression check).
- **Regression:** with all cut-offs ~0, v4 = v3 on every session (A 6,705 / B 1,682 / C 303 / D 466; v2 D 483 and v1 D 1,076 also
  reproduce); with the main cut-offs, 0 band differences and 0 desktop warning-count differences. v1 and v3 G3, shares and the Dict 15 group
  reproduce the published v3 figures.

## Truncated, approximated or not done
- **Queries were hand-reduced before running** to stay under the Superset response cap (~25k tokens; the response echoes the SQL twice):
  the saved `.sql` files are the full readable versions built from `_core_template_v4.sql`; the executed versions drop columns a query does
  not use (v2 and S1-S3 intermediate steps, OS-version status, v1 where not needed; unused lookup keys replaced by constants in q4) and
  split or trim the output rows. Logic for every reported column is unchanged; regression rows confirm it. Generated (pre-trim) minified texts are in `_scripts/` (`q1_generated_min.sql`,
  `q2_executed_partA_min.sql` = q2 with v2 removed, before the final SELECT was cut to the SH / G3 / D15 / FL rows); q3 (stats) and q4 executed texts were edited by hand from the saved queries and not saved
  separately.
- **q1 timed out once** (unpivot written as 6 UNION ALL scans); re-run with one FLATTEN unpivot, 13 s.
- **q2:** v2 was dropped from the run (published v2 figures used); the X4 / WF4 / RARE / G4 rows moved to q3.
- **Examples: 12 per cell, not 20** (three cells: newly in D under a+b+c, newly out of D under c, mobile rare-pair sessions). 20 per cell
  exceeded the response cap twice. Session IDs truncated to 18 characters, UA to 48, WebGL renderer to 28.
- Disagreement per-cell details (top keys, reasons, verify / challenge rates, examples) are v3's, since bands are identical; for the what-if
  cells only counts, High risk and trigger reasons were computed.
- Frequency bins count a session once per check, so the six checks overlap; High risk per bin is not adjusted for other checks.
- One key, one 2-hour window, one day, account whitelist only. The mobile cut-off rests on 10 High sessions. Re-measure on the pooled
  vertical whitelist (next phase) and on truth data (20 Nov labels should be complete by early December).
- `_scripts/` generators write minified copies to the directory in the `SCRATCH` environment variable (default `/tmp/`); run them from
  `_scripts/`.
