# Spec: rules to evaluate

Distilled from the two one-pagers (sources in `CLAUDE.md`). If this file and Confluence disagree, flag it in the result file and follow this file.

## Confirmed field names

*Fill in as they are confirmed from `INFORMATION_SCHEMA` (column name, table, example value).*

| Concept | Column | Confirmed by / date |
|---|---|---|
| OS family | `os` | |
| OS version | ? | |
| JA4 | `cdn__ja4_hash` | |
| Screen size | ? | |
| device_params (platform, CPU cores, colour depth, touch, storage/cookie flags, font hash) | ? | |
| navigator.platform | ? | |
| User-Agent | `ua` | |
| WebGL renderer | `webgl_unmasked_renderer` | |
| Browser name / version | `browser_name` / ? | |
| Risk band | `latest_risk_band`? | |

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
| screen × OS family | Few fail, nearly all bad |
| **Never** anything × JA4 | Points the wrong way (bots copy Chrome TLS + Chrome UA pairs) |

**Band D trigger:** mobile (iOS, iPadOS, Android) = 1 failed check. Desktop (Windows, macOS, ChromeOS, Linux) = 2 failed checks, or 1 failed check + a never-seen screen or device_params.

### Never-seen values (not in the whitelist for this OS family)

| Field | Treatment |
|---|---|
| UA, JA4, OS version (newer) | Neutral |
| screen, mobile | Neutral (flagged: needs more testing) |
| screen, desktop | One warning sign |
| device_params | Counts as a failed check |
| WebGL (hardware) | Neutral |

**Mobile screen fast track:** a never-seen mobile screen seen at 3+ distinct customers (accounts, not keys) within 24h, on sessions passing UA × device_params, is treated as whitelisted.

### Bands

| Band | Score | ≈ today |
|---|---|---|
| A | ≥ 0.85 | Dict 63 |
| B | 0.65–0.85 | Dict 31 / 15 |
| C | 0.40–0.65 | Dict 7 |
| D | < 0.40, or the Band D trigger above | Dict 1 / 3 |

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
1. **Base** per key × dict × group = p99 sessions per signature per 40 min on **clean traffic** (signature-windows with < 20% High-risk sessions), rolling 7 days, recomputed daily. Fall back to the global cell when the key has too little volume.
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
