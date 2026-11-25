# Gates G1-G5, layer 1 v2 (Seen-before rules, uncleaned whitelist)

Figma Registration K2, sessions created 2026-11-20 12:00-14:00 UTC, all 9,156 sessions. Numbers from `q1_crosstab_gates_result.txt` and `q2_flow_reasons_result.txt`. High risk and verified are indicators, not ground truth. No truth data. First-run values in brackets.

| Gate | Result | Verdict |
|---|---|---|
| **G1 drift recovery** | 308 of 469 Dict 1/3 sessions (65.7%) score A/B [298, 63.5%]. Single-field differences among them (lower bound, top-5 reasons per cell only): screen 93, JA4 QUIC/TCP variant 43, JA4 unrelated 30, UA same major 24; at least 190 of 308 (62%). | Recovers drift as before. Same caveat: JA4-only promotions include non-browser JA4s (`t13d3213h1_…`, `t12d520500_…`, `t12d2605h2_…`) because the whitelist is uncleaned. |
| **G2 no trust inflation** | Not evaluable: no `known_cases.md` bad case on this key/window. | Not evaluated. |
| **G3 checks separate risk** | Desktop-rule groups: D by checks 18/348 = **5.2%** High vs 360/7,341 = 4.9% passing (**1.05x**) [6.2% vs 4.7%, 1.3x]. Mobile: 12/94 = **12.8%** vs 46/1,373 = 3.4% (**3.8x**) [10.3% vs 3.5%, 2.9x]. | **Desktop fails, worse than v1**: the checks fire 64% less but what remains (SCRxDP + SCRxGL on new window sizes) is not riskier than passing traffic. The v1 desktop signal (Dict 15 UAxDP+SCRxDP, 16/51 High) was lost with the coarse pair values. **Mobile borderline-pass** (3.8x, n = 94). |
| **G4 new mobile screens** | Mobile sessions with a screen never seen in the Mobile group and passing UAxDP / DP: 1/53 High (1.9%); failing: 0/4; mobile with known screens: 57/1,410 (4.0%). | Passes (small n). 3-customer fast track not implemented (it would not change bands; a never-seen mobile screen is neutral). |
| **G5 easy majority** | Dict 63 → A: 4,762/5,023 = **94.8%** [94.7%]. Dict -1 (1 session) → **A** (score 0.85; it was D in v1 only through the OS-version failed check). Dict 1 → D: 5/23. | Dict 63 → A holds. Non-match side too small to judge; the single Dict -1 session (iOS 17.1 in-app browser) no longer goes to D. |

G6-G8 (Lists A/B/C, thresholds, proxy keys) are out of scope for layer 1.
