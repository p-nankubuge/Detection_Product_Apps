# Layer 1 notes: similarity scoring vs today's DI (Figma Registration K2)

- **Run:** similarity-scorer, standalone mode. All 9,156 sessions created 2026-11-20 12:00–14:00 UTC, no sampling.
- **Whitelist:** distinct Dict 63 signatures on Figma K2, sessions created 13–19 Nov (65,959 signatures, 364,042 sessions). **Uncleaned.**
- **Truth data:** not used (dropped by request).
- **Reasons for every moved cell:** `followup_drivers_all_moves.sql` (same scoring as `crosstab_and_drivers.sql`; its numbers reproduce the agent's for the cells the agent reported).

"Same bucket" = 63→A, 31/15→B, 7→C, 3/1/-1→D (the agreement mapping in the agent file).

## Shift table (sessions, row %)

| Today | A | B | C | D | Total |
|---|---:|---:|---:|---:|---:|
| 63 | **4,759 (94.7%)** | 228 (4.5%) ↓ | 1 (0.0%) ↓ | 35 (0.7%) ↓ | 5,023 |
| 31 | 811 (55.2%) ↑ | **484 (32.9%)** | 55 (3.7%) ↓ | 120 (8.2%) ↓ | 1,470 |
| 15 | 370 (35.1%) ↑ | **426 (40.4%)** | 53 (5.0%) ↓ | 206 (19.5%) ↓ | 1,055 |
| 7 | 224 (19.7%) ↑ | 272 (23.9%) ↑ | **55 (4.8%)** | 587 (51.6%) ↓ | 1,138 |
| 3 | 119 (26.7%) ↑ | 164 (36.8%) ↑ | 41 (9.2%) ↑ | **122 (27.4%)** | 446 |
| 1 | 9 (39.1%) ↑ | 6 (26.1%) ↑ | 3 (13.0%) ↑ | **5 (21.7%)** | 23 |
| -1 | 0 | 0 | 0 | **1 (100%)** | 1 |

| Summary | Sessions | Share |
|---|---:|---:|
| Same bucket | 5,852 | 63.9% |
| Moved up | 2,019 | 22.1% |
| Moved down | 1,285 | 14.0% |

## Why sessions moved

**Up (field that differed from the closest known device):**

| Move | n | Top reasons |
|---|---:|---|
| 31→A | 811 | JA4 QUIC↔TCP 301 · UA 275 · screen 181 · WebGL 19 · UA same major 12 |
| 15→A | 370 | JA4 QUIC↔TCP 118 · UA 107 · UA same major 78 · screen 25 · JA4 14 |
| 7→B | 272 | JA4 QUIC↔TCP + device_params 65 · + screen 43 · + UA 35 · JA4 + UA 26 · screen 20 |
| 7→A | 224 | JA4 QUIC↔TCP 123 · screen 55 · JA4 27 · device_params 16 |
| 3→B | 164 | screen 62 · JA4 QUIC↔TCP + UA 23 · + screen 21 · JA4 + UA 13 · [Basic Render] screen 9 |
| 3→A | 119 | JA4 QUIC↔TCP 43 · screen 31 · UA same major 23 · JA4 18 |
| 3→C | 41 | JA4 QUIC↔TCP + screen 9, then small groups |
| 1→A/B/C | 18 | JA4 in every top reason |

**Down:**

| Move | n | Top reasons |
|---|---:|---|
| 7→D | 587 | device_params never seen 294 (21 High) · screen×DP + screen×WebGL 93 · screen×WebGL + DP never seen 50 · UA×DP + screen×DP 49 |
| 63→B | 228 | Basic Render cap (exact match) 87 · UA 50 · device_params 28 · screen 24 · JA4 + UA 15 |
| 15→D | 206 | UA×DP + screen×DP 51 (**16 High, 31%**) · screen×DP + screen×WebGL 37 · DP never seen 32 · UA×DP + screen×WebGL 20 |
| 31→D | 120 | screen×DP + screen×WebGL 49 (0 High) · DP never seen 38 (0 High) · screen×WebGL 13 |
| 31→C / 15→C | 108 | two fields differ (UA + DP, UA + WebGL, screen + WebGL) |
| 63→D | 35 | screen×DP + screen×WebGL 14 · DP never seen 7 · screen×WebGL 6 |

## What made sense

- **Drift recovery works.** The commonest upward reason is a JA4 switching between QUIC and TCP: same browser, different connection. Today this drops a device several dictionaries; similarity keeps it in A/B. Other upward reasons are single-field changes (screen, browser update).
- **Dict 63 mostly stays A (94.7%).** Of the 228 that drop to B, 87 are exact matches capped by the Windows Basic Render rule, as the spec intends.
- **Sanity test passed** (14/14 worked examples) before real traffic was scored.
- **One real signal:** Dict 15 sessions failing both UA×device_params and screen×device_params are 31% High risk (16/51).

## What didn't make sense

- **Demotions are dominated by exact-value checks.** "device_params never seen" alone forces Band D on desktop (spec §2) and is the largest single cause of moving down (294 of 587 in 7→D). Pair checks (screen×DP, screen×WebGL) are next. Most demoted sessions have normal or low High risk (31→D: 2 of 120). Consistent with the checks over-firing against a 7-day, single-key whitelist.
- **"Seen before" is checked per exact OS family**, not per platform group (spec §4: Desktop pools Windows, macOS, ChromeOS; Mobile pools iOS, iPadOS, Android). A screen seen on macOS counts as never seen on Windows, and iPadOS is separate from iOS.
- **Uncleaned whitelist + low JA4 weight lets non-browser JA4s reach Band A** (1→A: 6 of 9 are one `t13d3213h1_…` device). Expected for layer 1; later layers must catch it.
- **"Different UA" still reaches A** (31→A: 275, 9.1% High risk vs 5.2% for Dict 31 overall). UA weighs 0.15–0.20, so a fully different browser on otherwise identical hardware stays A.

## What the agent got wrong or left out

1. **Only explained the agent file's "promoted" and "demoted" cells** (Dict 1/3 up, 63/31/15 to D = 7.2% of sessions). The 28.9% labelled "other move" (31→A 811, 7→D 587, 15→A 370, 7→A/B 496, 63→B 228) went unexplained. That follows the agent file's definition, so the **file** needs fixing: report every moved cell.
2. **First scoring version had a bug** (JA4 ⅔ credit too loose). The agent caught and fixed it itself and said so; reported numbers are from the fixed version.
3. **Example sessions incomplete:** none for 3→B and 31→D; 10 instead of 20 for 3→A and 63→D (Superset response cap).
4. **"No score" = 0 in every row** is not checked. Plausible for Figma (all sessions carry a fingerprint) but worth confirming.
5. **My own summary** (main session) called 3.3% "promoted" using the narrow label; across all cells 22.1% moved up and 14.0% down.

## Next

- Group "seen before" by **platform group** instead of OS family, and re-run layer 1. Expected to help never-seen screens (screen shared across desktop OSes). Probably **won't** fix "device_params never seen", which is OS-specific (navigator.platform is its first value) and high-cardinality.
- Decide whether "device_params never seen" alone should force D on desktop, or count as one warning sign.
- Next agent: velocity-thresholds (platform groups per spec §4).
