# Sanity test v4 result (run 2026-11-26)

Query: `sanity_test_v4_half.sql` (readable). The version actually executed is `_scripts/sanity_A_executed_min.sql`: the 14 `spec.md`
worked-example rows only, with short row labels and the unused text columns removed (the full 22-row query exceeded the Superset
response cap, which echoes the SQL twice). Cut-offs: every pair cut-off = 0.5 ("HALF" run), so in this 14-row toy whitelist almost
every seen pair is "rare"; this exercises the rare flags. Whitelist: the 14 hand-built rows of v3 (n = 1 each; 9 Desktop, 5 Mobile).

Columns: example | v3 score | v3 band, v4 band | failed checks | warning signs v3 / v4 | v4 warning signs | whitelist sessions in the
platform group: pair counts UAxDP coarse, exact, SCRxDP coarse, exact, SCRxGL, SCRxPG | what-if triggers that fire (a, b, c, X = all)

| Example | Score | v3 v4 | Fails | Warn v3/v4 | v4 warnings | Pair counts | What-ifs | Spec |
|---|---|---|---|---|---|---|---|---|
| Windows 1 everything matches | 1.000 | A A | 0 | 0/4 | UAxDPr SCRxDPr SCRxGLr SCRxPGr | 9: 3,1,1,1,1,3 | b, X | 1.00 A |
| Windows 2 all but UA (same major) | 0.925 | A A | 0 | 0/4 | same | 9: 3,1,1,1,1,3 | b, X | 0.93 A |
| Windows 3 all but JA4, QUIC/TCP | 0.967 | A A | 0 | 0/4 | same | 9: 3,1,1,1,1,3 | b, X | 0.97 A |
| Windows 4 all but JA4, unrelated | 0.900 | A A | 0 | 0/4 | same | 9: 3,1,1,1,1,3 | b, X | 0.90 A |
| Windows 5 all but device_params | 0.700 | B B | 0 | 0/4 | same | 9: 1,1,1,1,1,3 | b, X | 0.70 B |
| Windows 6 all but WebGL | 0.700 | B B | 0 | 0/4 | same | 9: 3,1,1,1,1,3 | b, X | 0.70 B |
| Windows 7 os + JA4 only | 0.100 | D D | 0 | 2/2 | SCRnew DPnew | not applicable | b, X | 0.10 D |
| iOS 1 everything matches | 1.000 | A A | 0 | 0/3 | UAxDPr SCRxDPr SCRxGLr | 5: 2,1,1,1,1,3 | none | 1.00 A |
| iOS 2 all but UA (same major) | 0.850 | A A | 0 | 0/3 | same | 5: 2,1,1,1,1,3 | none | 0.85 A |
| iOS 3 all but JA4, QUIC/TCP | 0.950 | A A | 0 | 0/3 | same | 5: 2,1,1,1,1,3 | none | 0.95 A |
| iOS 4 all but JA4, unrelated | 0.850 | A A | 0 | 0/3 | same | 5: 2,1,1,1,1,3 | none | 0.85 A |
| iOS 5 all but device_params | 0.950 | A A | 0 | 0/3 | same | 5: 1,1,1,1,1,3 | none | 0.95 A |
| iOS 6 all but WebGL | 0.900 | A A | 0 | 0/3 | same | 5: 2,1,1,1,1,3 | none | 0.90 A |
| iOS 7 os + JA4 only | 0.150 | D D | 1 (DPnew) | 0/0 | | not applicable | a, b, c, X (mobile = 1 failed check, unchanged) | 0.15 D |

**Result: pass.** All 14 worked examples reproduce the spec scores and bands under v3 and v4. Rare-pair warnings are counted one per
pair, on both desktop and mobile; with no failed check they never force Band D (the v4 trigger is unchanged), but the what-if
"2+ warnings -> D" (b) would put every desktop example in D at this artificial cut-off, as expected. SCRxPG is rare for Windows
(3 of 9) and common for iOS (3 of 5) at 0.5, as designed. Pair counts were checked by hand against the toy whitelist (e.g. Windows 1
UAxDP coarse = 3: w0, w1, w10 share Chrome/157 and coarse DP Win32/24/8/0/1).

Not run: the 8 extra rows of the v3 sanity test (v2 rows and v3 items 5/6/9). Their logic is unchanged from v3 (verified there); the
real-data regression check in `q1_frequency_bins` (v4 with cut-offs at ~0 must equal v3 on all 9,156 sessions) covers v3 = v4 equality.
