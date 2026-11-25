# Caveats: what was sampled, approximated, truncated or not done (layer 1 v2)

## Rules used
- **These results use the "Seen-before rules"** of `.claude/agents/similarity-scorer.md` (added 25 Nov) on top of `spec.md` §2: platform groups for every seen-before lookup, coarse pair values, OS-version check per OS line with the frozen test (reported only), device_params never seen on desktop = warning sign. Platform group is shown in every OS breakdown (`crosstab.md`).
- Everything else is identical to the first layer-1 run (`../2026-11-25_layer-1/`): same key, window, uncleaned whitelist, weights, partial credit (incl. the JA4 ⅔ browser-family fix), bands, Basic Render rule, closest device per exact OS family. The scoring CTE (`best`) is copied verbatim; the v1 bands were recomputed in the same query and match the first run exactly in every cell (and in G3).

## Sampling and coverage
- No sampling: all 9,156 sessions. Source `ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY`; outcome fields read on 25 Nov.
- No query timed out (10-18 s each). One sanity-test call returned an MCP-side 60 s timeout once and succeeded on retry.

## Whitelist (uncleaned approximation)
- Same as the first run: 65,959 distinct Dict 63 signatures from 364,042 sessions, 13-20 Nov, this key only. No List A/B/C, N-rules, eligibility or velocity filtering; software-renderer and odd-JA4 devices are trusted. Not today's production Dict 63 dictionary.

## Implementation choices (spec gaps filled; please review)
1. **Platform group** from OS + WebGL block: software renderer (SwiftShader, llvmpipe, VirtualBox, VMware) → Other (D-7); Basic Render Driver → Windows RD/VM on Windows, Other elsewhere; Windows/OS X/Chrome OS → Desktop; iOS/iPadOS/Android → Mobile; GNU/Linux/Ubuntu → Linux; anything else (Fire OS, HarmonyOS, OpenHarmony, Meta Horizon) → Other. Whitelist devices are grouped the same way. The Band D trigger uses the group (Mobile = 1 failed check; all other groups = desktop rule).
2. **Coarse device_params key** = positions **1, 4, 5, 10, 11** of the 13 `::` values: navigator.platform, colour depth (24/30/32), CPU cores, max touch points (0/1/2/5/10), touch flag (0/1). Chosen from the whitelist value distributions (`whitelist_profile.sql`). Note: `spec.md` "Confirmed field names" says touch points are the 11th value; the data shows position 10 holds the counts (0/5/10) and position 11 a 0/1 flag, so both were kept. Dropped: positions 2, 3, 6-9, 12 (0/1 flags, assumed storage/cookie/feature flags, not individually confirmed) and 13 (font hash).
3. **Coarse UA** = browser family + major version (same parser as the ½ credit). Unparsed UAs (some in-app browsers) fall back to the full UA string.
4. **"Never both" precondition for pair checks:** a pair check runs only if the screen and device_params are each seen **exactly** in the platform group (their never-seen counts as a signal, so the pair is not checked too), and the UA is seen at the **coarse** level (a never-seen exact UA is neutral, so it does not pre-empt the pair). WebGL is exact (full WebGL block, as in v1). This lets coarse UAxDP fire where v1 skipped it because the exact UA was new: 20 sessions entered Band D this way (17 mobile `UAxDP`, 3 High).
5. **Screen × platform group** fires when the screen is on the whitelist in another group but not this one. On desktop such a session also has a never-seen screen (warning), so the one check forces Band D (same double count as v1's screen × OS family; flagged again).
6. **OS version:** per OS line (iOS + iPadOS together; Android; Windows; macOS; ChromeOS; Linux = GNU/Linux + Ubuntu). Other OSes have no line and are skipped. Frozen test on whitelist **sessions** (not signatures): Android 99.34% "10", ChromeOS 100% "14541.0.0", Linux 100% empty, Windows 100% "10" → skipped. iOS+iPadOS top value 22.6% (26.6.1) and macOS 68.3% (10.15.7) → checked. In the window: iOS+iPadOS 566 seen, **2 older-unseen (warning, reported only)**, 0 newer than newest; macOS 1,627 all seen. No version above the newest seen, so no "never shipped" candidates were observed. Android 16 / 17 values exist on the whitelist (0.3% / 0.1%), which may be the freeze fix rolling out (D-2); not investigated.
7. **"Seen before" lookups implemented as hashed keys:** each whitelist row emits 20 64-bit `HASH` keys (one per lookup type); a session looks up its own keys. A hash collision could mark an unseen value as seen; at ~1.3M keys the chance is negligible.
8. **Attribution is sequential** (platform grouping → coarse pairs → OS version → device_params warning). No session changed band at more than one step, so the order does not affect the counts here.

## Issue found in the unchanged v1 scoring (kept for comparability)
- In Snowflake `HASH(NULL) = HASH(NULL)`. The v1 UA ½ credit compares `HASH(ua_bm)`, so **two unparsed UAs get ½ credit against each other** (contrary to first-run caveat 4). This affects 39 sessions' closest-device choice/score in both runs. Not fixed, to keep the score identical; fix before layer 2 (e.g. `ua_bm IS NOT NULL AND ...`).

## Truncated or not done
- **Examples: fewer than 20 per cell.** Each Superset response echoes the full SQL twice, which left room for ~35 example rows per call. Fetched: **10** each for 15→D, 63→D, 31→D, 7→D, 15→C, 3→A, 3→B; **all** for 1→A (9), 1→B (6), 1→C (3), -1→A (1). **0** for 63→B, 63→C, 31→A, 31→C, 15→A, 7→A, 7→B, 3→C (`examples_y4.sql` is saved, not run; examples for most of these reasons are in the first run's `examples_result.txt`). No examples were fetched for the Dict 15 UAxDP+SCRxDP subgroup.
- **Top reasons:** top 5 per moved cell; G1 single-field counts are therefore a lower bound.
- **Response-size workaround:** queries were sent as `EXECUTE IMMEDIATE $$<query>$$` so the echoed SQL is not reformatted (the saved `.sql` files are the plain queries; the run used a whitespace-minified copy without comments). Read-only either way.
- `q1_crosstab_gates.sql` was generated before a reporting-only column (`scr_seen_pg`, for G4) was added to `_core_template_v2.sql`; the column changes no band.
- Truth data: not used (as instructed). G2: no known bad case on this key/window. One key, one 2-hour window, one day.
