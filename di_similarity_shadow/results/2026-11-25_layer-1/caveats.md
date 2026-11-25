# Caveats: what was sampled, approximated, truncated or not done

## Sampling and coverage
- **No sampling.** All 9,156 sessions created 2026-11-20 12:00-14:00 UTC on Figma Registration K2 were scored (the agent default of 1-in-256 was overridden as instructed). The count matches run 1 exactly.
- Source: `ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY` (window on `session_ts`, pruned on `session_last_timestamp`). Outcome fields (`latest_risk_band`, `sessions_verified`, `was_challenged`, `sessions_solved`) are summary values read on 25 Nov.
- No query timed out. The heavy closest-device query (about 7k distinct session signatures × 66k whitelist signatures, joined within OS family) ran in 11-15 s, on hashed field values, in a single scan.

## Whitelist (uncleaned approximation)
- Whitelist = distinct `DI_HIGHEST_SIGNATURE_AT_SESSION_CREATED` of sessions at Dict 63 on this key, created 13 Nov 00:00 to 20 Nov 00:00 UTC: 65,959 signatures, 364,042 sessions. **Uncleaned:** no List A/B/C, no N-rules, no eligibility, no velocity filter. It contains SwiftShader devices, Basic Render devices and non-browser-looking JA4s that reached Dict 63, and these are trusted.
- It is per key only and 7 days only. It is **not** today's production Dict 63 dictionary, which is built differently (eligibility, recency). Sessions whose Dict 63 signature first appeared on 20 Nov look like near matches, not exact matches.

## Implementation choices (spec gaps filled; please review)
1. **Fields:** split from the dictionary signature `os::os_version || ja4 || screen || device_params || ua || webgl`. Screen = the whole `avail::full` part; device_params = the whole part (platform, flags, cores, colour depth, touch, font hash); WebGL = the whole WebGL block (hash, versions, max dims, vendor, renderer, bits). Equality is exact on these strings.
2. **OS family** = the exact `os` value (`iOS` and `iPadOS` are separate families; `GNU/Linux` and `Ubuntu` are separate). iPadOS uses the iOS weight column. Other OSes (Ubuntu, Fire OS, HarmonyOS, Meta Horizon) use the Linux column and the desktop Band D rule.
3. **JA4 ⅔ credit ("QUIC/TCP variant of the same browser family"):** given when the transports differ (`q` vs `t`), the UA browser family (Chrome / Edge / Opera / Samsung / Firefox / Safari, parsed from the UA) matches the candidate's, **and the session's own JA4 appears on the whitelist with that browser family.** On an uncleaned whitelist this last condition still admits some odd JA4s (e.g. `t13d260900_…` with a Safari UA).
4. **UA ½ credit:** same browser family and major version (parsed from the UA). UAs that don't parse (some in-app browsers) get no partial credit.
5. **Consistency checks** are exact-value pairs, per OS family: UA×device_params (one check, since both directions are the same test on exact pairs), screen×device_params, screen×WebGL (hardware renderers only, i.e. not SwiftShader / llvmpipe / VirtualBox / VMware / Basic Render), and screen×OS family. A pair check fires only when both values are individually seen for this OS family but never together.
6. **screen × OS family** fires when the screen is on the whitelist for another OS family but not this one. The spec defines never-seen as "not in the whitelist for this OS family", so on desktop such a session is also "never-seen screen", and the two together force Band D. This double count follows the spec literally; flagged for review.
7. **Never-seen device_params** counts as a failed check **and** as the never-seen value in the desktop trigger. So on desktop a never-seen device_params alone forces Band D. This also follows the spec literally; flagged (it accounts for the "DPnew" rows in the demoted cells).
8. **OS version check:** accepted if the version is on the whitelist for the OS family, or numerically newer than every whitelisted version. Otherwise it fails. "Never shipped" versions cannot be detected without a release list, so an impossible future version passes as "newer". OS-version failures do not appear among the top-8 reasons of any promoted or demoted cell (not checked beyond the top 8).
9. **Basic Render:** Windows + "Basic Render Driver" in the WebGL block → WebGL weight 0, the other weights divided by 0.70, Band A capped to B.
10. **No score:** OS empty or `--`, or empty device_params (proxy for "no JS fingerprint"). No session in the window met this.
11. **Mobile screen fast track** (3+ customers in 24h): not implemented. It needs cross-key data and would not change any band, since a never-seen mobile screen is neutral.
12. **Closest-device ties** are broken by the match pattern (arbitrary but deterministic). This only affects which differing fields are reported, never the score.
13. **"Impossible" column:** kept empty. List B/C and N1-N8 are not applied in standalone mode.

## Fix made during the run (v1 → v2)
- v1 gave the JA4 ⅔ credit whenever transports differed and the UA browser family matched. Example sessions showed this let non-browser TCP JA4s (`t13d3213h1_…`, `t12d520500_…`) claim ⅔ credit. v2 adds condition 3 above. The sanity test was re-run on v2 (all 14 examples still reproduce, with a whitelist row added that makes the QUIC JA4 a known JA4 of its browser family), and every reported number is from v2.
- Effect: bands barely moved (v1 → v2: 3→A 120 → 119, 3→B 167 → 164, 1→B 7 → 6; Dict 63 row identical), but the stated *reason* for 18 of the 3→A sessions and all 9 1→A sessions changed from "JA4 QUIC/TCP variant" to "JA4 unrelated". They still reach Band A because JA4 weighs only 0.10-0.15. v1 results were not kept.

## Truncated outputs (Superset response-size limit, about 25k tokens per response)
- Top reasons: **top 8 per cell** only (`crosstab_and_drivers_result.txt`).
- Example sessions: 1→A all 9; 1→B all 6; 15→D 20; **63→D 10 of 35; 3→A 10 of 119** (not 20); **3→B and 31→D not fetched.** Re-run `examples.sql` with `CELL_FILTER` set to the cell code to get them.

## Not done
- **Truth data: dropped at the user's request.** No Athena / `truth_data_history` queries were run, and there is no Legit / Nonlegit split.
- G2 (known bad cases): no `known_cases.md` case is on this key/window.
- One key, one 2-hour window, one day. No day-over-day stability check.
