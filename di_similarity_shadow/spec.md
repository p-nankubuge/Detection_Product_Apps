# Spec: rules to evaluate

Distilled from the two one-pagers (sources in `CLAUDE.md`). If this file and Confluence disagree, flag it in the result file and follow this file.

## Confirmed field names

*Fill in as they are confirmed from `INFORMATION_SCHEMA` (column name, table, example value).*

| Concept | Column | Confirmed by / date |
|---|---|---|
| OS family | `os` | |
| OS version | `os_version_at_session_created` (summary); also the part after `::` in the first field of the DI signature (e.g. `iOS::26.6.1`, `Windows::10`, `GNU/Linux::` empty) | similarity-scorer layer 1, 2026-11-25 (Figma K2) |
| JA4 | `cdn__ja4_hash` | |
| Screen size | 3rd `\|\|` part of `DI_HIGHEST_SIGNATURE_AT_SESSION_CREATED` (`avail_w,avail_h::w,h`, e.g. `1920,1032::1920,1080`); `LATEST_FP_RESOLUTION` (ARRAY, latest not at-create) in the summary | similarity-scorer layer 1, 2026-11-25 |
| device_params (platform, CPU cores, colour depth, touch, storage/cookie flags, font hash) | 4th `\|\|` part of `DI_HIGHEST_SIGNATURE_AT_SESSION_CREATED`, 13 `::`-separated values, e.g. `Win32::0::1::24::8::1::1::0::1::0::0::0::7EC6D` (platform 1st, colour depth 4th, CPU cores 5th, **max touch points 10th** (0/1/2/5/10), touch flag 11th (0/1), font hash 13th; other positions are 0/1 flags not individually confirmed. Corrected 25 Nov by layer 1 v2: touch points were listed as 11th) | similarity-scorer layer 1, 2026-11-25 |
| navigator.platform | First value of device_params (e.g. `Win32`, `MacIntel`, `iPhone`, `Linux armv81`); `LATEST_FP_NAVIGATOR_PLATFORM` in the summary | similarity-scorer layer 1, 2026-11-25 |
| User-Agent | `ua` | |
| WebGL renderer | `webgl_unmasked_renderer` | |
| Browser name / version | `browser_name` / ?; summary: `BROWSER_NAME_AT_SESSION_CREATED`, `BROWSER_VERSION_AT_SESSION_CREATED` | similarity-scorer layer 1, 2026-11-25 (summary columns via INFORMATION_SCHEMA) |
| Risk band | `latest_risk_band`? | |
| Risk band (session summary) | `latest_risk_band` in `ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY`; values `Low` / `Medium` / `High` (and a few `''`) | impossible-combos, 2026-11-24 (Figma K2, Oct 2026) |
| JA4 / UA / OS (session summary) | `cdn__ja4_hash_at_session_created`, `ua_at_session_created`, `os_at_session_created` (e.g. `Windows`, `OS X`, `Android`, `iOS`, `GNU/Linux`, `Chrome OS`, `iPadOS`, `Ubuntu`), `os_version_at_session_created` in `PROD_INT_SESSION_SUMMARY` (Snowflake) and `starfleet_production.prod_session_summary` (Athena) | impossible-combos, 2026-11-24 |
| Brave flag | `latest_browser_detection_brave` (BOOLEAN) in `PROD_INT_SESSION_SUMMARY` / Athena `prod_session_summary` (Brave UA is identical to Chrome) | impossible-combos, 2026-11-24 |
| Session create time (summary) | `session_ts` (TIMESTAMP_NTZ). Snowflake prunes on `session_last_timestamp`; Athena `prod_session_summary` has **no year/month/day partitions** and prunes only on `session_ts` (1 h ≈ 27 s, ≥ 6 h times out) | impossible-combos, 2026-11-24 |
| Full DI signature (summary) | `DI_HIGHEST_SIGNATURE_AT_SESSION_CREATED` = the session's own six fields even below Dict 63: `os::os_version\|\|ja4\|\|screen\|\|device_params\|\|ua\|\|webgl_block`; WebGL block = `hash::version::glsl::max_dims::unmasked_vendor::unmasked_renderer::bits`. `DI_MATCHED_SIGNATURE_AT_SESSION_CREATED` = the matched prefix only | similarity-scorer layer 1, 2026-11-25 (every one of 9,156 Figma K2 sessions on 20 Nov has 6 parts) |
| Outcomes (summary) | `SESSIONS_VERIFIED`, `SESSIONS_VERIFY_ATTEMPTED`, `WAS_CHALLENGED`, `SESSIONS_SOLVED` (NUMBER; use `> 0`) | similarity-scorer layer 1, 2026-11-25 |
| DI dictionary group (whitelist scope) | `di_dictionary_used` in `vw_events` (TEXT): the shared dictionary a key matches against, an account ID or a vertical ID (e.g. Figma K2 → `23454` = Figma account; only that key was active on it on 20 Nov 12:00–13:00). Account name: `dict_keys_account_name`. Not found in `PROD_INT_SESSION_SUMMARY` | main session, 2026-11-25 |
| Velocity signature (what today's DI counts) | `DI_MATCHED_SIGNATURE_AT_SESSION_CREATED` (summary) / `di_matched_signature` (`vw_events`): same-key sessions with the same matched signature over a trailing window; recount fits the recorded ST count best at 30-40 min (corr 0.94) | velocity-thresholds, 2026-11-25 (Figma K2, `results/2026-11-25_thresholds/00_verify_counting.sql`) |
| Velocity counts / thresholds (summary) | `DI_SHORT_TERM_COUNT_AT_SESSION_CREATED`, `DI_LONG_TERM_COUNT_AT_SESSION_CREATED`, `DI_SHORT_TERM_THRESHOLD_RATIO_…`, `DI_SHORT_TERM_THRESHOLD_BREACHED_…` (BOOLEAN), same for `LONG_TERM`, `DI_SHORT_TERM_PERCENT_…`. Threshold = count / ratio (Figma: ST 11, LT 660 for every dict); breached = count > threshold; recorded at Dict 63 too (exempt) | velocity-thresholds, 2026-11-25 |
| Velocity buckets (`vw_events`) | `di_short_term_count` = `di_short_term_current_bucket_count` + `di_short_term_previous_bucket_count` (same for long term); bucket length not confirmed (fit suggests 20 min) | velocity-thresholds, 2026-11-25 |
| User IP (summary) | `USER_IP_AT_SESSION_CREATED`, `LATEST_USER_IP` | velocity-thresholds, 2026-11-25 |
| IP intel | `vpn_proxy_description` / `vpn_proxy_type` exist in `vw_events` only (not in `PROD_INT_SESSION_SUMMARY`) | impossible-combos, 2026-11-24 |

## 1. Current dictionary (for reference)

Chain, each level requires all previous fields: **os (Dict 1) → +JA4 (3) → +screen (7) → +device_params (15) → +UA (31) → +WebGL (63)**. `-1` = no match. `di_is_suspicious` is true below 63 only.

## 2. Similarity scoring (`ja4_sim_v1`)

### Steps
1. **Candidates:** whitelisted Dict 63 devices with the same OS family. Sessions with no JS fingerprint, or no OS reported, get **no score**.
2. **Score** = sum of weights of matching fields (with partial credit below).
3. **Closest device** = candidate with the highest score.
4. Check every differing field (consistency checks, never-seen rules).
5. **Band** from the score unless step 4 forces Band D.

### Weights per platform

| Field | Windows | macOS | Linux | ChromeOS | Android | iOS | Partial credit |
|---|---|---|---|---|---|---|---|
| JA4 | 0.10 | 0.15 | 0.25 | 0.15 | 0.05 | 0.15 | ⅔ for the QUIC/TCP variant of the same browser family |
| screen_size | 0.15 | 0.35 | 0.20 | 0.20 | 0.30 | 0.40 | none |
| device_params | 0.30 | 0.15 | 0.25 | 0.25 | 0.05 | 0.05 | none |
| User-Agent | 0.15 | 0.20 | 0.15 | 0.15 | 0.20 | 0.30 | ½ if browser and major version match |
| WebGL | 0.30 | 0.15 | 0.15 | 0.25 | 0.40 | 0.10 | none |

- **OS version:** not weighted. Same, or a newer released version of the same OS family seen on whitelisted devices = accepted. Older, or never seen in real traffic = **failed check**.
- **Windows Basic Render Driver** (remote desktop / VM): WebGL weight 0, rescale the rest to 1.0, **max Band B**.
- **List A renderers:** scored without WebGL, **max Band B**. **List B / C:** no score.
- **Proxy keys:** JA4 weight 0, rescale.
- **Other platforms** (Fire OS, consoles, TVs): use the Linux column.

### Consistency checks (a value fails if it is normal on its own but never seen with the paired field on whitelisted devices)

| Check | Notes |
|---|---|
| UA × device_params (both directions) | Strongest |
| screen × device_params | |
| screen × WebGL | Hardware GPUs only |
| screen × platform group | Few fail, nearly all bad (was screen × OS family) |
| **Never** anything × JA4 | Points the wrong way (bots copy Chrome TLS + Chrome UA pairs) |

**Band D trigger:** mobile (iOS, iPadOS, Android) = 1 failed check. Desktop (Windows, macOS, ChromeOS, Linux) = 2 failed checks, or 1 failed check + a never-seen screen or device_params.

**Updated 25 Nov** (details in `.claude/agents/similarity-scorer.md`, "Seen-before rules"; options considered in `decisions.md`): every "seen before" lookup is per **platform group** (§4), not per exact OS; pair checks are **two-level** (coarse pair never seen = failed check; coarse seen but exact never seen = one warning sign; coarse UA = browser + major version, coarse device_params = positions 1, 4, 5, 10, 11); screen is compared on **physical size only** (`w,h`, not the available window size); empty or unparsed values never match each other; OS version is checked only within one OS line (iOS + iPadOS together), skipped where the version is frozen, and an older unseen version does not count toward Band D.

### Never-seen values (not in the whitelist for this platform group)

| Field | Treatment |
|---|---|
| UA, JA4, OS version (newer) | Neutral |
| screen, mobile | Neutral (flagged: needs more testing) |
| screen, desktop | One warning sign |
| device_params, desktop | One warning sign (was: a failed check; changed 25 Nov, `decisions.md` D-6) |
| device_params, mobile | Counts as a failed check |
| WebGL (hardware) | Neutral |

**Mobile screen fast track:** a never-seen mobile screen seen at 3+ distinct customers (accounts, not keys) within 24h, on sessions passing UA × device_params, is treated as whitelisted.

### Bands

| Band | Score | ≈ today |
|---|---|---|
| A | ≥ 0.85 | Dict 63 |
| B | 0.65–0.85 | Dict 31 / 15 |
| C | 0.40–0.65 | Dict 7 |
| D | < 0.40, or the Band D trigger above | Dict 1 / 3 |

### Bad and suspicious lists (the "deny" side of the dictionary)

Design agreed 24 Nov. The new DI keeps **three** reference lists, not one:

| List | What goes in | Effect |
|---|---|---|
| **Good** (whitelist) | Signatures that pass every impossible-combination check and meet eligibility | Similarity scores against it (as above) |
| **Definitely bad** | Signatures that break a **hard** rule: a combination no legitimate setup can produce (List B, C1, an OS version that never shipped) | Hard override (below) |
| **Suspicious** | Signatures that break a **soft** rule: impossible for a browser but explainable by something legitimate (TLS-inspection proxies, old embedded clients), or rules with a measured false-positive rate (today C2, C3, N9–N11, see run 2) | Weighted penalty (below) |

Every bad or suspicious entry records its **culprit**: the field-value pair(s) that break the rule, e.g. `os = iOS` + `webgl_renderer ~ SwiftShader`, or `os = Windows` + `ja4 cipher hash = a09f3c656075`. The culprit is usually a **pair**, not a single value: SwiftShader alone is fine on Linux (List A cap only), and a Safari JA4 alone is fine on a Mac.

**How a session is judged:**
1. **Carries a culprit from the Definitely-bad list** → Band D (or no score), **even if** its similarity to a good device is high.
2. **Carries a culprit from the Suspicious list** → subtract the culprit fields' weights (per-platform weights table) from its good score, then band it. A culprit on a heavily weighted field (e.g. WebGL on Windows, 0.30) moves it further than one on a light field (e.g. JA4 on Android, 0.05).
3. **Closer to a bad entry than to any good one** (closest-bad score ≥ closest-good score, and ≥ 0.85) → Band D if the bad entry is Definitely bad, Suspicious flag if it is Suspicious. This catches near-copies of known-bad setups that differ in one field.

**Exclusions before an entry is listed** (from run 2: C2/C3/N9 hits on Figma are consistent with corporate proxies, not proven; on 15 Oct, 58% of N9 hits came from `cloud-security` IPs, which carry 3.8% of traffic, and 37% from ordinary IPs; see `results/2026-11-24_run-2/followup_already_challenged.md`): proxy keys; sessions from `vpn_proxy_description = 'cloud-security'` IPs; JA4s seen at Dict 63 on many keys with normal High-risk rates (likely middleboxes). Entries hit mainly by such traffic go to Suspicious, never Definitely bad.

**Existing Dict 63 is not trusted by default.** The cleaner pass checks today's Dict 63 (and 31 / 15) signatures against the rules; anything that breaks one is moved to the Definitely-bad or Suspicious list. Example: SwiftShader on iOS/macOS at Dict 63 should not exist.

### Worked examples to reproduce (sanity tests)

| Device | Windows | iOS |
|---|---|---|
| Everything matches | 1.00 A | 1.00 A |
| All but UA (same major) | 0.93 A | 0.85 A |
| All but JA4, QUIC/TCP variant | 0.97 A | 0.95 A |
| All but JA4, unrelated | 0.90 A | 0.85 A |
| All but device_params | 0.70 B | 0.95 A |
| All but WebGL (hardware) | 0.70 B | 0.90 A |
| os + JA4 only | 0.10 D | 0.15 D |

## 3. Impossible combinations

Effect for Lists B and C: session = no match (`-1`) at every level; signature never eligible. List A: never whitelisted with WebGL.

### List A: renderers never eligible (`webgl_unmasked_renderer`)
SwiftShader (incl. `ANGLE (Google, Vulkan … SwiftShader Device (Subzero) …)`, `Google SwiftShader`), llvmpipe (Mesa), VirtualBox, VMware SVGA.

### List B: impossible OS × renderer

| OS | Impossible renderer |
|---|---|
| iOS, iPadOS, macOS, Android | SwiftShader, llvmpipe |
| Windows | llvmpipe |
| Any non-Windows OS | Microsoft Basic Render Driver |
| No OS reported (`--`) with a JS fingerprint | Any WebGL renderer |

Windows + Microsoft Basic Render Driver is **not** impossible (remote desktop / VDI).

### List C: impossible TLS (JA4) × OS / browser
Skip on proxy keys and sessions with no JA4.

| # | Rule |
|---|---|
| C1 | Apple TLS cipher hash `a09f3c656075` or `2802a3db6c62` (TCP JA4s only, not `q13…`) with OS Windows, Linux or ChromeOS |
| C2 | Chromium UA (Chrome, Edge, Opera, Brave) with JA4 ALPN `h1` |
| C3 | Chromium UA version 70+ with JA4 TLS version `t12` |
| C4 (phase 2) | JA4 from a browser build range that doesn't match the claimed version (needs a JA4 family map) |

### New checks to design and test (this project)

Each must be measured on clean traffic for false positives before being proposed.

| # | Idea | Example |
|---|---|---|
| N1 | UA OS ≠ reported `os` | UA says iPhone, `os` says Windows |
| N2 | UA OS version ≠ reported OS version, or a version that never shipped | iOS 19.x in UA when no such release exists |
| N3 | Browser version impossible for OS version | Safari 26 on iOS 15 |
| N4 | Screen impossible for OS / device class | Desktop resolution on an "iPhone"; phone resolution on Windows desktop with no touch |
| N5 | navigator.platform ≠ OS | `Win32` on iOS; `MacIntel` on Android |
| N6 | Mobile OS with no touch support | Android/iOS with `maxTouchPoints = 0` |
| N7 | App UA with an implausibly old WebView | `BingSapphire/26` with `Chrome/1xx` < 140 (gtop100 fleet) |
| N8 | Chromium UA with Safari JA4 or vice versa (overlaps C1) | |
| N9 | Browser UA with a JA4 offering **no ALPN** (`00` at the end of JA4 part a) | `t12d520500_…` claiming Windows browser (Figma run 1) |
| N10 | Browser UA with a cipher or extension count **outside any real browser's range** (part a digits) | `t13d3213h1_…`: 32 ciphers + h1 claiming Windows (Figma run 1). Derive the real-browser ranges from Dict 63 traffic per browser family first |
| N11 | Any modern browser UA (Chrome, Edge, Firefox, Safari, Opera, Brave, Samsung) with JA4 max TLS version **1.2 or lower** (`t12`, `t11`, `t10`; QUIC is always 1.3) | `t12d2605h2_…` on OS X at Dict 1 (Figma run 1; UA not yet checked) |

**About N11:** it broadens C3 (Chromium + `t12`) to all browsers and to TLS 1.1 / 1.0. Every major browser has offered TLS 1.3 since 2018–2020. **Expected false-positive sources to measure:** corporate TLS-inspection proxies that re-terminate TLS (the JA4 is the proxy's), old Android WebViews / embedded app clients, smart TVs. Report hits by `vpn_proxy_description` (e.g. cloud-security) and by OS version.

**Reading JA4 part a** (e.g. `t13d1516h2`): `t`/`q` = TCP or QUIC; `13`/`12` = highest TLS version; `d`/`i` = SNI present (domain) or IP; next 2 digits = cipher count; next 2 = extension count; last 2 = ALPN (`h2`, `h1`, `h3`, `00` = none). QUIC JA4s (`q13d03…h3`) always offer 3 ciphers; that is normal, not a bot sign.

## 4. Per-dictionary × platform velocity thresholds

### Platform groups (from OS + renderer)

| Group | Rule |
|---|---|
| Desktop | Windows, macOS, ChromeOS with a hardware GPU |
| Mobile | iOS, iPadOS, Android with a mobile GPU |
| Linux | Linux with a hardware GPU |
| Windows RD/VM | Windows with Microsoft Basic Render Driver |
| Other | TVs, consoles, Fire OS, anything else |

List A/B/C sessions need no group.

### Rule
1. **Base** per key × dict × group = p99 sessions per signature per 40 min on **clean traffic** (signature-windows with < 20% High-risk sessions), rolling 7 days, recomputed daily. **Thresholds are always per key.** When a key's cell has too little clean volume, fall back **within the same key**: key × dict across all platform groups → the key's current threshold. A fallback value never exceeds the key's current threshold. Global (all-keys) cells are a cross-check against the table below, never a fallback (`decisions.md` D-11).
2. **Multipliers** (ESM-6922):

| Dict | Short-term | Long-term |
|---|---|---|
| 1, 3 | 1x | 1x |
| 7 | 1.5x | 2x |
| 15, 31 | 2x | 4x |
| 63 | 2x | 6x |

3. Windows RD/VM: max 1.5x short-term, 2x long-term.
4. **Remove the Dict 63 exemption.**

### Indicative global p99 (per 40 min) to compare against

| Dict | Desktop | Mobile | Linux | Win RD/VM | Other |
|---|---|---|---|---|---|
| 1 | 69 | 26 | 19 | pooled | pooled |
| 3 | 66 | 36 | 45 | 62 | 78 |
| 7 | 20 | 12 | 18 | 14 | 9 |
| 15 | 11 | 26 | 13 | 8 | 23 |
| 31 | 15 | 11 | 18 | 8 | 25 |
| 63 | 19 | 58 | 30 | 19 | 32 |

## 5. Gates

| # | Gate |
|---|---|
| G1 | **Drift recovery:** share of today's Dict 1/3 sessions scoring Band A/B, concentrated in single-field drift |
| G2 | **No trust inflation:** on confirmed-bad traffic (`known_cases.md`), Band A/B rate ≤ today's Dict 15+ rate |
| G3 | **Consistency checks hold:** Band D via failed checks is several times more often bad than passes, mobile and desktop separately |
| G4 | **New mobile screens:** never-seen screen + consistent UA × device_params stays near normal High-risk rate |
| G5 | **Easy majority:** clean Dict 63 → Band A; total non-matches → Band D |
| G6 | **Lists A/B/C precision:** moved-down sessions have High-risk rate well above their current dict baseline |
| G7 | **Threshold firing:** per cell, clean-traffic firing ≤ today's per-dict rate; Dict 63 fires concentrate on High risk |
| G8 | **Proxy keys:** Payoneer firing at or below today |
