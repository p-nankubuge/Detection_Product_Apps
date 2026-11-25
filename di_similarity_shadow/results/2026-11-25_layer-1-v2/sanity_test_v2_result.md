# Sanity test v2 result (run 2026-11-25, `sanity_test_v2.sql`)

Columns: example | score | band under v1, S1 (platform grouping), S2 (+coarse pairs), S3 (+OS version rule), v2 (+device_params warning) | failed checks v1, v2 | v2 reason

| Example | Score | Bands v1 S1 S2 S3 v2 | Fails v1 v2 | v2 reason | Spec expects |
|---|---|---|---|---|---|
| Windows 1 everything matches | 1.0000 | A A A A A | 0 0 | exact | 1.00 A |
| Windows 2 all but UA (same major) | 0.9250 | A A A A A | 0 0 | UAmaj | 0.93 A |
| Windows 3 all but JA4, QUIC/TCP variant | 0.9667 | A A A A A | 0 0 | JA4qt | 0.97 A |
| Windows 4 all but JA4, unrelated | 0.9000 | A A A A A | 0 0 | JA4 | 0.90 A |
| Windows 5 all but device_params | 0.7000 | B B B B B | 0 0 | DP | 0.70 B |
| Windows 6 all but WebGL (hardware) | 0.7000 | B B B B B | 0 0 | GL | 0.70 B |
| Windows 7 os + JA4 only | 0.1000 | D D D D D | 1 0 | UA+SCR+DP+GL (D by score in v2) | 0.10 D |
| iOS 1 everything matches | 1.0000 | A A A A A | 0 0 | exact | 1.00 A |
| iOS 2 all but UA (same major) | 0.8500 | A A A A A | 0 0 | UAmaj | 0.85 A |
| iOS 3 all but JA4, QUIC/TCP variant | 0.9500 | A A A A A | 0 0 | JA4qt | 0.95 A |
| iOS 4 all but JA4, unrelated | 0.8500 | A A A A A | 0 0 | JA4 | 0.85 A |
| iOS 5 all but device_params | 0.9500 | A A A A A | 0 0 | DP | 0.95 A |
| iOS 6 all but WebGL (hardware) | 0.9000 | A A A A A | 0 0 | GL | 0.90 A |
| iOS 7 os + JA4 only | 0.1500 | D D D D D | 1 1 | chk: DPnew(fail) (mobile) | 0.15 D |
| Windows 8 [new rule] DP never seen (font hash), coarse DP known | 0.7000 | D D D D **B** | 1 0 | DP; never-seen desktop DP is now a warning only | v1 D, v2 B |
| iOS 8 [new rule] older unseen OS version (18.0) | 1.0000 | D D D **A A** | 1 0 | exact; old version reported only | v1 D, v2 A |

**Result: pass.** All 14 worked examples reproduce exactly under every rule set. None of the spec examples changes under
the new rules: the examples model single-field drift against a whitelist where every drifted value is already seen in
consistent pairs, so no seen-before check fires either way (the only check-driven rows, Windows 7 and iOS 7, are Band D by
score anyway). The two added rows move exactly at the rule step that should move them (S4 for the desktop DP warning,
S3 for the OS version rule).
