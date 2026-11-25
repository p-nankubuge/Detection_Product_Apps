# Caveats: what was sampled, approximated, truncated or not done (layer 1 v3)

## Rules used
- **These results use the "Seen-before rules" of `.claude/agents/similarity-scorer.md`** (as updated 25 Nov) on top of `spec.md` §2:
  platform groups for every seen-before lookup (platform group shown in every OS breakdown, `crosstab.md`), screen x platform group,
  two-level pair checks (item 5), screen = physical size everywhere (item 6), OS version per OS line with the frozen test (reported only,
  D-1), device_params never seen on desktop = warning sign (D-6), empty / unparsed values never match (item 9, D-10), software
  renderers -> Other (D-7). Decisions D-1 to D-12 read fresh on 25 Nov.
- Kept identical to v2: key, window, weights, partial credit (incl. JA4 2/3 browser-family fix), bands, Basic Render rule (WebGL
  weight 0, rescale, max B), platform groups, closest device per exact OS family (D-4), OS-version rules and frozen test.
- Standalone: no List A/B/C, N-rules, eligibility or bad/suspicious lists; Impossible column empty. Mobile screen fast track not applied.

## Sampling and coverage
- No sampling: all 9,156 sessions of Figma Registration K2 created 20 Nov 12:00-14:00 UTC (`PROD_INT_SESSION_SUMMARY`, outcome fields
  read 25 Nov). No query timed out (6-25 s each).
- No truth data (as instructed).

## Whitelist (D-12; uncleaned approximation)
- Account dictionary `23454` (Figma). Production keys used: **Registration Production K2 `A207F8A1-...`: 364,042 Dict 63 sessions,
  65,959 signatures**; **Login Production 1 `955D26AF-E956-4106-A4EF-2F63304776D9`: 1 Dict 63 session, 1 signature** (the key stopped
  on 1 Nov, as expected). Development keys `98F60B6F-...` and `4193E70F-...` excluded. Session counts by key from `q0`.
- Uncleaned: software-renderer and odd-JA4 devices are trusted. Not today's production Dict 63 dictionary. The whitelist differs from
  v2 by the one Login signature; the recomputed v2 bands still match the published v2 crosstab exactly.
- The account membership was taken from the brief and `spec.md` "Confirmed field names" (19 Nov check); `vw_events.account_id` was not
  re-queried in this run.

## Implementation choices (spec gaps filled; please review)
1. **Physical screen** = the part after `::` in the screen field, accepted only if it parses as `digits,digits`; otherwise it is
   "unparsed" (31 whitelist sessions have an empty screen `::`; no window session does).
2. **Item 9 (null fix):** a field gets no credit, full or partial, and is never "seen", when it is empty or unparsed. Implemented as
   session-side guards on every hashed comparison (a non-empty session value can only hash-match the same non-empty whitelist value).
   In this window only the UA browser/major parse failed (67 sessions); v2 gave 39 of them ½ UA credit from two unparsed UAs; v3 gives 0.
   **Interpretation:** an unparsed UA that is *identical* (full string) to a whitelisted UA still gets full UA credit (29 sessions), since
   the raw value is present; only the derived browser/major is unparsed. A stricter reading ("no credit at all for an unparsed UA")
   would lower those 29 scores; not run.
3. **Two-level pairs.** UA x DP: coarse = (browser/major, DP positions 1,4,5,10,11), exact = (full UA, full DP). Screen x DP: coarse =
   (w,h, coarse DP), exact = (w,h, full DP). Screen x WebGL: single level (w,h, full WebGL block), because the screen is the physical
   size at both levels. Coarse UA falls back to the full UA if browser/major cannot be parsed (as v2).
4. **"Never both" preconditions** (as v2, extended): a pair check runs only if the screen (physical) and DP are each seen exactly in the
   platform group and the UA is seen at the coarse level. The exact-level warning also needs the exact UA seen, so a never-seen exact UA
   (neutral) is not turned into a UAxDPx warning.
5. **Warning-sign counting.** Desktop (non-Mobile groups): never-seen physical screen + never-seen DP + UAxDPx + SCRxDPx; each counts 1.
   Mobile: only UAxDPx/SCRxDPx are counted, reported, never trigger D. OS-version-older-unseen is reported separately (2 iOS sessions)
   and never counts (D-1).
6. **Screen x platform group** on desktop still also implies a never-seen screen warning, so it forces D alone (same double count as v1/v2).
7. **Sequential attribution** v2 -> v3: null fix -> physical screen in scoring -> physical screen in checks -> two-level pairs. 4 sessions
   changed at two steps. A different order would move some sessions between causes.
8. **OS version** (unchanged from v2): frozen lines Android 99.34% "10", Chrome OS 100% "14541.0.0", Linux 100% empty, Windows 100% "10"
   -> skipped; iOS+iPadOS (top 22.6%) and macOS (top 68.3% "10.15.7") checked. 566 iOS+iPadOS seen, 2 older-unseen (warning, reported
   only), 0 newer than newest; macOS 1,627 all seen. No never-shipped version candidates observed. v3 adds an empty-version guard
   (no effect here: Linux is skipped as frozen).
9. Seen-before lookups are 25 hashed keys per whitelist row (v2's 20 plus 5 physical-screen keys); hash collisions are negligible.
10. The closest-device CTE was restructured (per-candidate match codes computed once, three packed maxima). v2's arithmetic is unchanged;
    the recomputed v2 crosstab and G3 match the published v2 exactly.

## Truncated or not done
- **Examples: 5 per moved cell, not the 20 targeted**, and only for 8 of 19 moved cells (31->A, 15->A, 7->A, 7->B, 31->D, 15->C,
  15->D, 7->D). Each example row costs ~550 tokens of response (rows are returned twice); 40- and 30-row calls exceeded the 25k cap.
  `examples_e2.sql` (3->A, 3->B, 3->C, 1->A, 1->B) and `examples_e3.sql` (1->C, -1->B, 63->B, 63->C, 63->D, 31->C) are saved, not run.
- Top reasons: top 5 per moved cell (`q3a`), top 8 reason pairs per cause (`q3b`), top 22 check combinations per mobile/desktop.
- G4 (new mobile screens) not recomputed for v3. G2 not testable (no known bad case in this key/window).
- The sanity test was run in two calls (old 16 rows / new 6 rows, same whitelist) and without two text columns it does not output;
  band logic identical.
- Response-size workaround: queries sent as `EXECUTE IMMEDIATE $$<minified query>$$` (comments and whitespace stripped by
  `_scripts/build.py`); the saved `.sql` files are the readable versions. Read-only throughout. `q1` was run without the v1 crosstab
  rows (response cap); the saved `q1_crosstab_gates.sql` is the version that ran.
- `_scripts/` holds the generators used to build the queries (Python; they read `_core_template_v3.sql`). They were run from the
  session scratchpad, so paths inside may need adjusting to re-run.
- One key, one 2-hour window, one day. "High risk" and "verified" are indicators, not ground truth.
