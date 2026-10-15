# Impossible OS / OS version / browser / UA / device combinations

Query: [`queries/impossible_device_combos.sql`](../queries/impossible_device_combos.sql)
Data: `arkoselabs.events_faster`, `location = 'session_setup'`, 2026-10-14 14:00–16:00 UTC
(~7.65M sessions, 354 public keys).

## Key point: compare the UA against an *independent* signal

`os`, `os_version`, `device_type`, `browser_name` and `browser_engine` are all parsed
from the **same User-Agent string**, so they almost never contradict each other —
`os × device_type` alone looks clean (e.g. `iOS|smartphone`, `Windows|desktop`).

The "Linux on iOS" you saw comes from comparing the UA against a field that a spoofer has
to fake separately:

| Signal | Field | Where it comes from |
|---|---|---|
| UA-parsed OS / browser / device | `os`, `os_version`, `browser_name`, `browser_version`, `device_type` | User-Agent string |
| JS platform | `fp_navigator_platform` | `navigator.platform` in the fingerprint |
| Client Hints | `sec_ch_ua_platform`, `sec_ch_ua_mobile`, `user_agent_data_mobile` | Chromium only — **no browser on iOS sends them** (all iOS browsers are WebKit) |
| Vendor support matrix | `browser_version` vs `os_version` | e.g. Chrome 109 was the last build for Windows 7/8.1 |

## Results (2h)

`pct fp_has_fake_os` = how much of each rule the existing flag already catches.

### Hard rules (H) — impossible on a genuine device

| Rule | What it means | Sessions | Keys | % already `fp_has_fake_os` |
|---|---|---:|---:|---:|
| H01 iOS UA + non-Apple `navigator.platform` | **the "Linux on iOS" case** — iPhone UA but platform `Linux x86_64` / `Win32` | 11,685 | 33 | 38.9 |
| H02 iOS UA + Client Hints present | Chromium (or hand-built headers) wearing an iOS UA *(numbers here are pre-split, see 5-day section)* | 20,317 | 44 | 22.2 |
| H04 Android UA + `Win32`/`MacIntel`/`iPhone` platform | Android platform is always `Linux …` | 4,931 | 40 | 21.3 |
| H05 Windows UA + Linux/Mac/iPhone platform | Linux/Mac box with a Windows UA (largest bucket) | 54,855 | 93 | 35.0 |
| H06 macOS UA + Win/Linux/iPhone platform | | 6,310 | 62 | 88.7 |
| H07 Linux/ChromeOS UA + Win/Mac/iPhone platform | | 649 | 20 | 77.2 |
| H08 CH platform ≠ UA OS | e.g. `sec-ch-ua-platform: "macOS"` with a Windows UA | 44,542 | 80 | 16.7 |
| H09 Non-standard CH platform value | values Chromium never emits (`"iPhone"`, `"Mac OS X"`, lowercase `"ios"`) | 1,436 | 27 | 21.2 |
| H10 `Sec-CH-UA-Mobile: ?1` on a desktop OS UA | | 1,789 | 51 | 78.9 |
| H11 macOS/Windows UA with phone `device_type` | | 89 | 17 | 0.0 |
| H12 Safari on Android/Windows | Safari for Windows died at 5.1.7 | 234 | 5 | 0.0 |
| H13 Chrome/Edge ≥110 on Win 7/8/8.1/XP/Vista | last supported build was 109 | 500 | 36 | 5.6 |
| H14 Firefox ≥116 on Win 7/8 or macOS <10.15 | 115 ESR was the last | 132 | 18 | 12.1 |
| H15 Chrome ≥117 on macOS <10.15 | Chrome also freezes the UA at `10_15_7` | 170 | 16 | 50.6 |
| H16 Chrome ≥120 on Android <7 | | 194 | 17 | 0.0 |
| **Any H rule** | | **91,557 (≈1.2%)** | **142** | **34.1** |

**About two-thirds (~60K sessions in 2h) break a hard rule but are *not* flagged by
`fp_has_fake_os`.** `ua_mismatch` was false on every flagged row, so it doesn't catch these
either.

Notable concentrations (single hour):
- Windows UA + `MacIntel` platform + CH `macOS`: ~4.4K/h on 6 keys, only 5 flagged by
  `fp_has_fake_os`. This is a Mac with its UA overridden to Windows.
- iOS / iPadOS Mobile Safari UA + `Win32` platform: ~3.4K/h, mostly unflagged; one key
  accounts for ~1.7K.
- Windows Chrome UA + `Linux x86_64` platform: classic headless-Linux-pretending-Windows.
  It's mostly caught already when CH also says Windows, but only about half when CH says Linux.

### Review tier (M) — unusual, but has legitimate explanations

| Rule | Why it's not "impossible" | Sessions | Keys |
|---|---|---:|---:|
| M01 iPhone UA + `MacIntel`/`iPad` platform | iPhone-only apps on iPad, odd webviews | 6,205 | 103 |
| M02 macOS UA version ≥11 (or bogus like `77.7.7`) | mainstream browsers freeze at 10.15; some in-app browsers don't | 634 | 35 |
| M03 Android phone UA + `Sec-CH-UA-Mobile: ?0` | | 9,613 | 106 |
| M04 iOS + non-WebKit `browser_engine` | `browser_engine` is **inferred from the browser name** (iOS Brave → "Blink"), so most hits are parser artifacts | 2,386 | 94 |
| M05 Android WebView with foreign platform / CH | host apps can inject JS / set UA metadata; Android apps on ChromeOS send CH=Android | 10,134 | 9 |

## False positives removed during validation

- **Smart TVs as "Safari"**: Tizen / webOS / embedded Linux (`armv7l`, `mips`) browsers carry a
  `Safari/537.36` token and the parser labels them Safari. H12 now only fires on Android and
  Windows, and excludes `device_type = 'tv'`.
- **Brave/Chrome on iOS labelled "Blink"**: this is a parser inference, not an observed
  engine. Moved to M04.
- **Android WebViews and ChromeOS ARC apps**: moved out of H04/H08 into M05.
- **Android Chrome "Request desktop site"**: sends a Linux UA with CH `Android`. Explicitly
  allowed in H08.
- **iPad desktop mode** reports `MacIntel`. Allowed for iOS/iPadOS in H01.

## 5-day run (2026-10-05 01:00 → 2026-10-10 00:59 UTC)

Run by the analyst with the original rule set. Note: `ymdh` values are `YYYY/MM/DD/HH`, so a bound
like `'2026/10/05/00:00:00.000'` excludes hour 00 of the first day and includes hour 00 of the
day after the end. Use `'2026/10/05/00'`.

| Rule | Sessions | Keys | % already `fp_has_fake_os` | ≈ not flagged |
|---|---:|---:|---:|---:|
| H01 iOS + non-Apple platform | 889,468 | 124 | 26.4 | 655K |
| H02 iOS + Client Hints *(pre-split)* | 1,213,620 | 158 | 18.7 | 987K |
| H04 Android + non-Linux platform | 497,956 | 155 | 14.5 | 426K |
| H05 Windows + foreign platform | 1,452,992 | 192 | 76.9 | 336K |
| H06 macOS + foreign platform | 355,270 | 161 | 84.7 | 54K |
| H07 Linux/ChromeOS + foreign platform | 49,248 | 80 | 45.4 | 27K |
| H08 CH platform ≠ UA OS | 1,073,032 | 164 | 32.1 | 729K |
| H09 Non-standard CH platform | 72,709 | 84 | 20.4 | 58K |
| H10 Mobile hint on desktop OS | 77,594 | 124 | 77.0 | 18K |
| H11 Desktop OS, phone device type | 3,898 | 89 | 1.2 | 4K |
| H12 Safari on Android/Windows | 16,662 | 15 | 3.5 | 16K |
| H13 Chrome/Edge too new for Windows | 37,396 | 97 | 4.5 | 36K |
| H14 Firefox too new for OS | 11,798 | 70 | 12.7 | 10K |
| H15 Chrome too new for macOS | 8,976 | 61 | 45.8 | 5K |
| H16 Chrome too new for Android | 12,406 | 77 | 3.0 | 12K |
| **Any H rule** | **4,187,000** (1.18%) | **265 / 549** | **42.1** | **≈2.4M** |
| M01 iPhone UA + Mac/iPad platform | 108,116 | 195 | 1.1 | |
| M02 macOS unfrozen/bogus version | 84,534 | 125 | 38.0 | |
| M03 Android phone, mobile hint ?0 | 631,383 | 187 | 1.5 | |
| M04 iOS non-WebKit engine label | 126,129 | 161 | 1.7 | |
| M05 Android WebView mismatch | 892,127 | 37 | 0.6 | |

## Drill-down (2026-10-07 12:00–18:00 UTC)

### H02 is two different things, so it's now split

iOS sessions with Client Hints (`CH`), `Sec-CH-UA-Mobile` (`CHM`), or JS `userAgentData` (`UDM`):

| Leg | Sessions | Keys | % `fp_has_fake_os` | % with genuine Apple platform |
|---|---:|---:|---:|---:|
| UDM only | 41,805 | 25 | 8.4 | 23.7 |
| CH + CHM + UDM | 7,598 | 45 | 82.9 | 13.7 |
| CH + CHM, no UDM | 7,166 | 19 | 1.1 | 98.5 |
| CHM + UDM | 623 | 7 | 46.4 | 53.6 |

- Normal Chrome on iOS sends no Client Hints (274K sessions across 177 keys, none).
  Client Hints on a genuine `iPhone` platform are confined to 4–15 keys with 0% `fp_has_fake_os`,
  so this is probably integration-specific. **It's moved to M06.**
- Client Hints + a non-Apple platform is clear spoofing: Chromium (Win32, `userAgentData.mobile = false`)
  wearing an iPhone UA, including ancient "Chrome iOS 89–97" UAs.
  **H02 now only fires in this case.**
- Roughly a third of the original H02 volume in this window was the Apple-platform (ambiguous) case.

### H01 / H04 are dominated by one key: `56938EF5`

| Rule | Sessions (6h) | Keys | Top key share | % `fp_has_fake_os` |
|---|---:|---:|---:|---:|
| H01 | 39,462 | 49 | **74.6%** (`56938EF5`) | 26.5 |
| H04 | 22,103 | 55 | **78.8%** (`56938EF5`) | 17.4 |

Excluding `56938EF5`, `fp_has_fake_os` already catches ~97% of H01 and ~72% of H04.
Most of the "≈2.4M not flagged" headline is this one key.

`56938EF5`, impossible combos vs the rest of the same key (iOS + Android UAs):

| | Impossible | Rest of key |
|---|---:|---:|
| Sessions | 78,061 | 201,867 |
| Sessions per IP | **4.9** | 1.9 |
| Hosting / proxy-VPN IPs | **35%** | 13% |
| Unique `init_fingerprint` | 76,905 (≈1 per session) | 115,220 |
| Unique JA4 | **39** | 180 |
| Countries | 119 | 195 |

This is a bot farm signature: UA and platform are randomised per session (iOS UA on Win32,
Android UA on iPhone), fingerprints are fresh per session, and a narrow set of TLS stacks sits
behind it. `fp_has_fake_os` misses ~97% of it.

## Caveats / next steps

- 2-hour, all-keys snapshot. Before turning any rule into a telltale, check per-key
  concentration and outcomes (solve rates, downstream fraud labels).
- M06 (iOS + Client Hints on a genuine Apple platform) is concentrated on a few keys. Confirm
  with those customers' integrations before promoting it to H or discarding it.
- `56938EF5`: pull outcomes (solve / fail / suppression) for the impossible-combo cohort to see
  whether it is getting through today. H01/H04/H02 against `fp_navigator_platform` are a cheap
  global telltale for it.
- The version-support rules (H13–H16) depend on vendor end-of-support dates. Revisit them
  when a vendor drops another OS version.
