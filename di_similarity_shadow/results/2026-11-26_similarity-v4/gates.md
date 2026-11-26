# Gates (G1-G5), similarity v4

Figma Registration K2, 20 Nov 12:00-14:00 UTC, all 9,156 sessions, uncleaned account whitelist, standalone, no truth data. "High risk" =
`latest_risk_band = 'High'` (indicator only). v4 = main cut-offs (bands identical to v3); what-ifs on top of v4.

| Gate | v4 | What-if a + b + c | v3 | Verdict |
|---|---|---|---|---|
| **G1 drift recovery** (Dict 1/3 → A/B) | 333 / 469 = 71.0% | 314 / 469 = 67.0% | 71.0% | Pass on volume (drift detail as v3: JA4 QUIC/TCP variant, exact matches, screen) |
| **G2 trust inflation** | no known bad case on this key/window | | | Not testable |
| **G3 desktop** (D-by-check vs passing) | 3.5% vs 5.0% = **0.70x** | 12.0% vs 4.3% = **2.77x** | 0.70x | v4 **fails**; what-if passes |
| **G3 mobile** | 11.6% vs 3.4% = 3.4x (95 sessions) | same | 3.4x | Borderline pass, small n |
| **G4 new mobile screens** | never-seen physical screen + UA×DP consistent: 29 sessions, 1 High (3.4%) vs mobile baseline 4.0%; 3 with UA×DP failure or rare, 0 High | | not done in v3 | Pass, small n |
| **G5 easy majority** | Dict 63 → A 4,816 / 5,023 = 95.9%; the one Dict -1 session → B | 4,806 = 95.7% | 95.9% | Pass for Dict 63; -1 not testable (n = 1) |

Other what-ifs, G3 desktop: a 2.24x, b 1.61x, c 0.89x; uniform rare cut-off 1e-4 1.12x, 1e-3 1.51x (`summary.md`).
