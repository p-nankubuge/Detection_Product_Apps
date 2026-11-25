# Sanity test v3 result (run 2026-11-25, `sanity_test_v3.sql`)

Run in two calls (old 16 rows, new 6 rows; same 14-row whitelist in both) because one call exceeded the Superset response cap
(the response echoes the SQL twice). The two runs also omit two text columns (`chk_v1`, `reason_v2`) that the sanity output
does not use; band logic is identical to `_core_template_v3.sql`.

Columns: example | v2 score | v3 score | bands v1, v2, S1 (null fix), S2 (+physical screen in scoring), S3 (+physical screen in checks), v3 (+two-level pairs) |
v1 fails, v2 fails, v3 failed checks, v3 warning signs | v3 reason

| Example | v2 score | v3 score | Bands v1 v2 S1 S2 S3 v3 | Fails v1 v2 v3 / v3 warnings | v3 fails / warnings | Spec / expected |
|---|---|---|---|---|---|---|
| Windows 1 everything matches | 1.0000 | 1.0000 | A A A A A A | 0 0 0 / 0 | | 1.00 A |
| Windows 2 all but UA (same major) | 0.9250 | 0.9250 | A A A A A A | 0 0 0 / 0 | | 0.93 A |
| Windows 3 all but JA4, QUIC/TCP variant | 0.9667 | 0.9667 | A A A A A A | 0 0 0 / 0 | | 0.97 A |
| Windows 4 all but JA4, unrelated | 0.9000 | 0.9000 | A A A A A A | 0 0 0 / 0 | | 0.90 A |
| Windows 5 all but device_params | 0.7000 | 0.7000 | B B B B B B | 0 0 0 / 0 | | 0.70 B |
| Windows 6 all but WebGL (hardware) | 0.7000 | 0.7000 | B B B B B B | 0 0 0 / 0 | | 0.70 B |
| Windows 7 os + JA4 only | 0.1000 | 0.1000 | D D D D D D | 1 0 0 / 2 | SCRnew DPnew (D by score) | 0.10 D |
| iOS 1 everything matches | 1.0000 | 1.0000 | A A A A A A | 0 0 0 / 0 | | 1.00 A |
| iOS 2 all but UA (same major) | 0.8500 | 0.8500 | A A A A A A | 0 0 0 / 0 | | 0.85 A |
| iOS 3 all but JA4, QUIC/TCP variant | 0.9500 | 0.9500 | A A A A A A | 0 0 0 / 0 | | 0.95 A |
| iOS 4 all but JA4, unrelated | 0.8500 | 0.8500 | A A A A A A | 0 0 0 / 0 | | 0.85 A |
| iOS 5 all but device_params | 0.9500 | 0.9500 | A A A A A A | 0 0 0 / 0 | | 0.95 A |
| iOS 6 all but WebGL (hardware) | 0.9000 | 0.9000 | A A A A A A | 0 0 0 / 0 | | 0.90 A |
| iOS 7 os + JA4 only | 0.1500 | 0.1500 | D D D D D D | 1 1 1 / 0 | DPnew (mobile fail) | 0.15 D |
| Windows 8 [v2 row] DP never seen (font hash), coarse DP known | 0.7000 | 0.7000 | D B B B B B | 1 0 0 / 1 | DPnew warning | v1 D, v2 B (unchanged in v3) |
| iOS 8 [v2 row] older unseen OS version | 1.0000 | 1.0000 | D A A A A A | 1 0 0 / 0 | | v1 D, v2 A (unchanged in v3) |
| macOS 9 [item 6] window resized: avail size differs, physical size seen | 0.6500 | **1.0000** | B B B **A** A A | 0 0 0 / 0 | | v2 B (screen string differs), v3 A at S2 (scoring) |
| Windows 9 [item 6] resized window + coarse UAxDP failure | 0.7000 | **0.8500** | D D D D **A** A | 1 1 1 / 0 | UAxDP, no warning | v2 D (UAxDP + never-seen full screen); S2 lifts the score; S3 drops the never-seen-screen warning, so 1 failed check alone = no D |
| Windows 10 [item 5] coarse UAxDP fail + exact-only SCRxDP | 0.5500 | 0.5500 | D C C C C **D** | 2 1 1 / 1 | UAxDP + SCRxDPx | v2 C; v3 D at S4 (1 failed check + 1 warning sign) |
| Windows 11 [item 5] two exact-only pair warnings, no failed check | 0.7000 | 0.7000 | D B B B B B | 2 0 0 / 2 | UAxDPx SCRxDPx | stays B: warning signs alone never force D (D-9 option 3) |
| macOS 10 [item 9] all but UA, both UAs unparsed | 0.9000 | **0.8000** | A A **B** B B B | 0 0 0 / 0 | | v2 gave 1/2 UA credit for two unparsed UAs (HASH(NULL)=HASH(NULL)); v3 none, A -> B at S1 |
| Windows 12 [item 9] everything matches, both screens empty (`::`) | 1.0000 | **0.8500** | A A A A A A | 0 0 0 / 1 | SCRnew (warning) | empty screen gets no credit and is never "seen"; score 1.00 -> 0.85 at S1, still A |

**Result: pass.** All 14 `spec.md` worked examples and the 2 v2 extra rows reproduce exactly under every rule set; none of them
changes in v3, because their screens differ only in the physical part (or not at all), their UAs parse, and none relies on an
exact-only pair. The 6 new rows move exactly at the step that should move them. Note on Windows 7: v3 reports 2 warning signs
(never-seen screen and DP) but it is Band D by score anyway; in v1 it was a failed check.
