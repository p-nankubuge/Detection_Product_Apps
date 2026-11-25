# Gates (G1-G5) for layer 1 v3

Figma Registration K2, 20 Nov 12:00-14:00 UTC, all 9,156 sessions, uncleaned account whitelist, standalone mode, no truth data.
"High risk" = `latest_risk_band = 'High'` (an indicator, not ground truth).

| Gate | v3 result | v2 | Verdict |
|---|---|---|---|
| **G1 drift recovery** | 333 of 469 Dict 1/3 sessions (71.0%) score A/B (v2: 308, 65.7%). Single-field drift in the top reasons: Dict 3->A: JA4 QUIC/TCP variant 70, other JA4 21, physical screen size 25, UA major 13; exact match 67. Dict 1->A: JA4 only 11. High risk of 3->A 7.8%, 1->A 9.1% (Dict 3 baseline in agree cell D: 12.4%) | 65.7% | Pass on volume; drift is mainly JA4 transport variant and exact matches |
| **G2 trust inflation** | No `known_cases.md` bad case on this key/window | n/a | Not testable here |
| **G3 consistency checks** | Desktop: D-by-check 11/316 = 3.5% High vs passing 367/7,373 = 5.0% (**0.70x**). Mobile: 11/95 = 11.6% vs 47/1,372 = 3.4% (**3.4x**) | 1.05x / 3.8x | **Fail on desktop** (D-by-check is now lower risk than passing); mobile borderline-pass on small n |
| **G4 new mobile screens** | Not recomputed in v3 (no query for mobile never-seen physical screen x UAxDP). Mobile screen never-seen stays neutral and the fast track is not applied in standalone mode | see v2 | Not done |
| **G5 easy majority** | Clean Dict 63 -> A: 4,816 / 5,023 = 95.9% (v2 94.8%). Total non-match (-1): 1 session, scored B (UA differs only) | 94.8% | Pass for Dict 63; -1 not testable (n = 1) |

## G3 detail and what drives it

Desktop Band D by the trigger is dominated by screen x WebGL combinations (SCRxDP+SCRxGL 83 sessions 2 High; SCRxGL+SCRxDPx 53 / 2;
SCRxGL+DPnew 43 / 0). The two desktop groups with the highest High-risk rates are **not** in Band D:
- coarse UAxDP failure alone, no warning sign: 163 sessions, 38 High (23.3%);
- two exact-only pair warnings (UAxDPx + SCRxDPx), no failed check: 64 sessions, 17 High (26.6%).

Both are outside the trigger by design (1 failed check needs a warning sign; warning signs alone never force D, D-9 option 3).
See `compare_v2_v3.md` §6 for the full table.
