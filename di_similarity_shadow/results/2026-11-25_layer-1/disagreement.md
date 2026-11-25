# Disagreement report: today's DI vs similarity scoring (layer 1, standalone)

**Question:** if DI scored sessions by *similarity to known real devices* instead of *exact match*, which sessions would move up or down, and why?

**Scope**
- Key: Figma Registration K2 (`A207F8A1-ED09-4325-ACE6-C8E26A458FBA`). Not a proxy key, so JA4 keeps its normal weight.
- Sessions: created 2026-11-20 12:00-14:00 UTC. **All 9,156 sessions scored, no sampling** (matches run 1's 9,156).
- Reference ("whitelist"): every distinct signature that reached **Dict 63 on this key** in sessions created 13 Nov 00:00 to 20 Nov 00:00 UTC: **65,959 signatures from 364,042 sessions. Uncleaned**: whatever reached Dict 63 is trusted, including software renderers and odd JA4s. No List A/B/C, no N-rules, no eligibility rules.
- Source: `ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY`. The six dictionary fields come from `DI_HIGHEST_SIGNATURE_AT_SESSION_CREATED` (the session's own full signature, even when it matched below 63).
- Rules: `spec.md` section 2 (weights, partial credit, consistency checks, never-seen rules, bands, Windows Basic Render rule). Anchor = OS family only; OS version is a check, not a weight. Implementation details and approximations are in `caveats.md`.
- Sanity test: all 14 worked examples in `spec.md` reproduce (`sanity_test.sql`).
- Truth data: **dropped at the user's request for this run.** There is no Legit / Nonlegit split below.

## How to read this

Today DI walks a chain, os → JA4 → screen → device_params → UA → WebGL, and reports how far an exact match got (1, 3, 7, 15, 31, 63). The new scoring instead finds the closest known device with the same OS family and adds up the weights of the fields that match: score 0 to 1, Band A ≥ 0.85, B ≥ 0.65, C ≥ 0.40, D below that. It then runs **consistency checks**: is this UA ever seen with this device_params? This screen with this device_params? This screen with this GPU? Is the OS version one we have seen? Failing them forces Band D (mobile: 1 failure; desktop: 2, or 1 plus a never-seen screen or device_params).

Cell labels:
- **agree:** 63→A, 31/15→B, 7→C, 3/1/-1→D. Both systems put the session in the same place.
- **promoted:** today 1/3 → new A/B. Today's exact match stopped early, but the session is very close to a known device (one or two fields drifted).
- **demoted:** today 63/31/15 → new D (or Impossible). Today matched deep, but a consistency check fails.
- **other move:** everything else (e.g. 31→A, 7→D, 63→B).
- **Impossible:** kept as a column but **empty, not applied in standalone mode** (no List B/C, no N1-N8). So in this run demotions can only come from low similarity, failed consistency checks or never-seen values. In practice they all came from the checks.

## 1. Comparison table (session counts, row %)

| Today's dict | Band A | Band B | Band C | Band D | No score | Impossible (not applied) | Row total |
|---|---|---|---|---|---|---|---|
| 63 | 4,759 (94.7%) *agree* | 228 (4.5%) *other* | 1 (0.0%) *other* | **35 (0.7%) *demoted*** | 0 | (empty) | 5,023 |
| 31 | 811 (55.2%) *other* | 484 (32.9%) *agree* | 55 (3.7%) *other* | **120 (8.2%) *demoted*** | 0 | (empty) | 1,470 |
| 15 | 370 (35.1%) *other* | 426 (40.4%) *agree* | 53 (5.0%) *other* | **206 (19.5%) *demoted*** | 0 | (empty) | 1,055 |
| 7 | 224 (19.7%) *other* | 272 (23.9%) *other* | 55 (4.8%) *agree* | 587 (51.6%) *other* | 0 | (empty) | 1,138 |
| 3 | **119 (26.7%) *promoted*** | **164 (36.8%) *promoted*** | 41 (9.2%) *other* | 122 (27.4%) *agree* | 0 | (empty) | 446 |
| 1 | **9 (39.1%) *promoted*** | **6 (26.1%) *promoted*** | 3 (13.0%) *other* | 5 (21.7%) *agree* | 0 | (empty) | 23 |
| -1 | 0 | 0 | 0 | 1 (100%) *agree* | 0 | (empty) | 1 |
| **All** | **6,292 (68.7%)** | **1,580 (17.3%)** | **208 (2.3%)** | **1,076 (11.8%)** | 0 | (empty) | **9,156** |

"No score" is empty because every session in the window had an OS and a JS fingerprint.

Totals: **agree 5,852 (63.9%)**, **promoted 298 (3.3%)**, **demoted 361 (3.9%)**, other moves 2,645 (28.9%). The large "other" share is mostly 31/15/7 → A (similarity is generous on near matches) and 7 → D (checks).

## 2. Promoted and demoted cells

Rates within the cell. The baseline is the same dictionary row overall (see `crosstab.md`). "Top keys" is a single key, since only one key was scored. Field abbreviations: JA4 = JA4 unrelated to the closest device's; JA4qt = QUIC/TCP variant of a known JA4 of the same browser family (⅔ credit); UAmaj = same browser and major version (½ credit); SCR = screen; DP = device_params; GL = WebGL; [BRD] = Windows + Microsoft Basic Render Driver (WebGL ignored, max Band B). Checks: UAxDP, SCRxDP, SCRxGL, SCRxOS = pair never seen together on the whitelist; DPnew = device_params never seen for this OS family; SCRnew = desktop screen never seen (warning).

| Cell | Sessions | Verified | High risk | Challenged | Challenged, not solved | Mean score | Row baseline High risk |
|---|---|---|---|---|---|---|---|
| promoted 1→A | 9 | 88.9% | 11.1% (1) | 22.2% | 11.1% | 0.88 | 8.7% |
| promoted 1→B | 6 | 66.7% | 16.7% (1) | 50.0% | 33.3% | 0.74 | 8.7% |
| promoted 3→A | 119 | 90.8% | 10.9% (13) | 37.8% | 9.2% | 0.91 | 8.3% |
| promoted 3→B | 164 | 93.3% | 3.7% (6) | 32.3% | 5.5% | 0.72 | 8.3% |
| demoted 15→D | 206 | 91.3% | 8.7% (18) | 25.2% | 5.3% | 0.60 | 8.0% |
| demoted 31→D | 120 | 97.5% | 1.7% (2) | 13.3% | 2.5% | 0.71 | 5.2% |
| demoted 63→D | 35 | 94.3% | 5.7% (2) | 31.4% | 5.7% | 0.71 | 3.5% |
| Impossible (any row) | not applied in standalone mode | | | | | | |

### Promoted 1→A (9 sessions)
- **What it means:** today only the OS matched, but apart from the JA4 the session is identical to a known Dict 63 device.
- **Field that caused the move:** JA4 in all 9 (an unrelated JA4, no partial credit). With JA4 weighted 0.10 on Windows and 0.15 on macOS, everything else matching gives 0.90 / 0.85, which is Band A.
- **Examples (all 9 in `examples_result.txt`):** 6 are Windows Chrome/Edge 157-158 with JA4 `t13d3213h1_3af914e56c9f_cf4b9e61af1f` (32 ciphers, ALPN h1: the run 1 N10 pattern) on one screen / device_params / Intel UHD 630 set. The other 3: `t12d520500_…` (no ALPN, the N9 pattern), `t12d2605h2_…` on Safari 26.6.2 (TLS 1.2, the N11 pattern), and `t13d2417h2_…` on Mac Chrome 152.
- **Reading:** this is how similarity is designed to behave (spec: "Never anything × JA4"). It cannot see JA4 anomalies; catching them is the job of layer 3 (List C / N9-N11). The repeated identical device with one non-browser JA4 is *consistent with* one setup behind a TLS-altering client or proxy. That is not proven; 1 of 9 is High risk and 8 of 9 verified.

### Promoted 1→B (6 sessions)
- **Fields:** JA4 (2), [BRD] JA4 (1), JA4qt+SCR (1), JA4+SCR (1), JA4+UA+DP (1).
- **Examples:** 2 GNU/Linux Chrome sessions with **SwiftShader** renderers (`t13d1517h2_…`, `t13d1519h2_…`; one High risk, neither verified). They are similar to SwiftShader devices that reached Dict 63, which shows the uncleaned whitelist at work: List A would cap or remove them in layer 3. Also a Windows Basic Render Edge session with `t12d520500_…`, and Chrome OS sessions with no-ALPN JA4s (`t13d381100_…`, `t13d370700_…`).

### Promoted 3→A (119 sessions)
- **What it means:** today OS + JA4 matched but the screen didn't, so the chain stopped at 3. Similarity finds a known device that differs in one field.
- **Fields:** JA4qt 43, SCR 31, UAmaj 23, JA4 18, JA4qt+UAmaj 3, JA4qt+GL 1. **115 of 119 (97%) differ in a single field.**
- **Wait, JA4 differs but today matched JA4 at Dict 3?** Yes. Dict 3 means the session's OS+JA4 pair is on today's dictionary, but its *closest full device* on the whitelist uses a different JA4 (typically the QUIC vs TCP form of the same browser).
- **High risk 10.9%, above the Dict 3 baseline (8.3%), and concentrated in the JA4qt group (8 of 43 = 18.6%).** In the examples, part of the JA4qt group carries no-ALPN JA4s (`t13d260900_…` on Safari, `t13d100900_…` on Mac Chrome) that are on the uncleaned whitelist with that browser's UA. This is consistent with the run 2 finding that such JA4s reach Dict 63 via corporate TLS-inspection proxies, but not proven here.
- **Examples:** 10 of 119 in `examples_result.txt` (10 rather than 20, see caveats).

### Promoted 3→B (164 sessions)
- **Fields:** SCR 62, JA4qt+UA 23, JA4qt+SCR 21, JA4+UA 13, [BRD] SCR 9, JA4qt+GL 6, [BRD] JA4qt+SCR 5, UA 5 (top 8 = 144 of 164). Single-field (SCR, UA, [BRD] SCR): 76 of the 144 listed.
- **High risk 3.7%**, below the Dict 3 baseline and close to Dict 63 (3.5%). Consistent with genuine drift (mostly a new window size on an otherwise known device).
- **Examples:** not fetched in this run (see caveats); re-run `examples.sql` with `CELL_FILTER = 'P3B'`.

### Demoted 15→D (206 sessions)
- **What it means:** today matched os + JA4 + screen + device_params, but at least two consistency checks fail (desktop) or one (mobile).
- **Checks that caused the move:** UAxDP+SCRxDP 51, SCRxDP+SCRxGL 37, DPnew 32, UAxDP+SCRxGL 20, UAxDP+SCRxDP+SCRxGL 18, SCRxGL 10, SCRxDP 9, SCRxOS+SCRnew 6 (top 8 = 183 of 206).
- **The UAxDP+SCRxDP group stands out: 16 of 51 High risk (31%), 36 of 51 verified (71%), 29 challenged and 8 challenged-not-solved.** The rest of the cell is mostly Low risk and verified: 2 High in the other 155.
- **Examples (20 in `examples_result.txt`):** mostly ordinary-looking Windows/macOS Chrome, Edge and Firefox with hardware GPUs (RTX 2070/4070, RX 580, Apple M-series), usually Low risk and verified. This is consistent with the exact-value pair checks being too strict on a whitelist where a given UA and device_params combination may simply not have occurred in 7 days (see caveats).

### Demoted 31→D (120 sessions)
- **Checks:** SCRxDP+SCRxGL 49, DPnew 38, SCRxGL 13, SCRxDP 5, SCRxOS+SCRnew 4, UAxDP+SCRxDP 4, [BRD] DPnew 3, UAxDP+SCRxGL 2.
- **High risk 1.7% (2 of 120), verified 97.5%: lower risk than the Dict 31 baseline (5.2%).** On these indicators the demotion looks like false positives of the checks rather than bad devices.
- **Examples:** not fetched (see caveats).

### Demoted 63→D (35 sessions)
- **Checks:** SCRxDP+SCRxGL 14, DPnew 7, SCRxGL 6, SCRxOS+SCRnew 4, plus singles.
- **High risk 5.7% (2), verified 94.3%.**
- **How can a Dict 63 session fail?** Its exact signature was not on the 7-day whitelist (no score-1.0 sessions in this cell), for example a new Dict 63 signature first seen on 20 Nov. Its values are known individually but never in this combination.
- **Examples (10 of 35):** Mac Chrome 157 on Apple M1/M5 with a new screen size (SCRxDP+SCRxGL), Samsung Internet on Android with a tablet-like screen (SCRxGL, mobile = 1 failure is enough), Ubuntu Firefox with a new device_params, and one GNU/Linux session with an Android-like device_params (`Linux armv81`, touch) and a 804x360 screen (SCRxOS). That last one is the kind of mismatch the check is meant to catch.

## 3. Other moves worth knowing about (not promoted/demoted by definition)
- **63→B, 228 sessions:** 87 are exact whitelist matches (score 1.0) capped at B by the Windows Basic Render Driver rule; the rest differ in UA (50), DP (28), SCR (24) or JA4+UA (15). The whitelist window ends 20 Nov 00:00, so newer Dict 63 signatures look like near matches.
- **31→A (811) and 15→A (370):** near matches scored ≥ 0.85 (e.g. only UA or JA4 differs). High risk 5.3% and 7.3%, close to the row baselines.
- **7→D, 587 sessions (52% of Dict 7):** almost all via the check trigger. High risk 6.1% vs the Dict 7 baseline of 5.4%.

## 4. Truth data
Dropped at the user's request for this run. No Athena or `truth_data_history` queries were run, and there is no Legit / Nonlegit / unlabelled split.

## Files
- `crosstab.md`: full table with outcome rates per cell
- `gates.md`: G1-G5
- `caveats.md`: what was approximated, not done or truncated, and the v1→v2 fix
- `examples_result.txt`: example sessions per cell
- `_core_template.sql`, `sanity_test.sql`, `crosstab_and_drivers.sql`, `examples.sql`, `whitelist_and_window.sql`: every query
- `crosstab_and_drivers_result.txt`: raw output behind the tables
