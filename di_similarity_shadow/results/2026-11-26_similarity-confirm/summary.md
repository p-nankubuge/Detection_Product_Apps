# Similarity confirmation: does the desktop Band D fix (D-20) hold on another day, with truth data?

Written by the main session from the agent's report (the agent's own report files were blocked: "Subagents should return findings as text"). Raw tables: `analysis_output.txt`, `q1_main_result.txt`.

## In short

- **The fix (T1) is not confirmed.** It makes desktop Band D somewhat riskier by Arkose's own High-risk rating (G3 1.81× → 2.02×), but against Figma's own labels it **doubles the share of genuine users put in Band D** (3.3% → 7.3% of Legit labels) while catching only a few more fraudsters (7.6% → 12.1% of Nonlegit).
- **Part (a), "browser doesn't fit the hardware → Band D", is the problem.** Most of what it adds is consistent with a **new Chrome release** (Chrome 157 rolled out on Figma from about 4 Nov; the whitelist week had very few Chrome 157 devices), not fraud. It leans Legit (26 Legit, 13 Nonlegit).
- **Part (b), "2+ warning signs → Band D", is the part with label support** (15 Nonlegit vs 6 Legit), but the counts are small.
- **Warning signs carry real signal on desktop:** with no failed check, the Nonlegit share of labelled sessions rises from 38% (0 warnings) to 56% (1) to 65% (2).
- **On this day the current rule (T0) already works:** desktop G3 1.81× (vs 0.70× on 20 Nov 12:00–14:00), so the 20 Nov window may have been unusual.

## Terms

- **Band D:** the new scoring's "not a known real device" band (like today's Dict 1/3).
- **T0:** current rule (desktop D = 2 failed checks, or 1 failed check + 1 warning). **T1:** D-20: also (a) coarse UA × device_params never seen together, alone; (b) 2+ warning signs; (c) screen × WebGL failure counts as a warning.
- **Legit / Nonlegit labels:** Figma's own after-the-fact judgement of a session; only ~1.7% of verified sessions are labelled, and the labels are a selected sample.
- **False positive here:** a Legit-labelled session put in Band D.
- **G3:** High-risk rate of Band D (by checks) divided by that of passing sessions.

## Run

- Figma Registration K2, all 91,613 sessions created 6 Nov 2026 00:00–24:00 UTC, no sampling (six windows).
- Whitelist: Dict 63, 30 Oct → 6 Nov, Figma account production keys: Registration K2 369,208 sessions / 78,099 signatures; Login Production 3 sessions (its Dict 63 traffic on the summary table stops after 29 Oct, earlier than the 1 Nov 10:13 last session found by the main session on all dictionaries).
- Labels: 1,427 (807 Legit, 620 Nonlegit), all verified, match rate 100%, completeness 1.7% of verified sessions. 49.5% of Nonlegit labels are High risk vs 3.1% of Legit.
- Sanity test: 14 / 14 worked examples reproduce under T0 and T1.

## Results

| Measure | T0 (6 Nov) | T1 (6 Nov) | 20 Nov 12–14h T0 / T1 |
|---|---|---|---|
| Same / up / down | 65.3 / 27.3 / 7.5% | 64.3 / 25.8 / 9.9% | 64.6/27.7/7.7 ; 63.8/26.4/9.8 |
| Sessions in D | 3,875 (4.2%) | 6,626 (7.2%) | 466 ; 732 |
| High% in D vs not D | 10.9 vs 6.0% | 11.4 vs 5.8% | 6.4 vs 4.7 ; 11.9 vs 4.1 |
| G3 desktop | 1.81× | 2.02× | 0.70× ; 2.77× |
| G3 mobile | 1.62× | 1.62× | 3.4× ; 3.4× |
| **Legit in D** (false positives) | **3.3%** (27) | **7.3%** (59) | no labels |
| **Nonlegit in D** (catch) | **7.6%** (47) | **12.1%** (75) | no labels |
| G1 (Dict 1/3 → A/B) | 70.2% | 67.9% | 71.0 ; 67.0 |
| G5 (Dict 63 → A) | 95.3% | 95.2% | 95.9 ; 95.7 |

Labels per band (Legit / Nonlegit): T0 A 540/358, B 204/139, C 36/76, D 27/47; T1 A 535/356, B 183/127, C 30/62, D 59/75. Today's DI puts 14.3% of Legit labels at Dict 1/3 vs 8.1% of Nonlegit.

**What T1 adds to Band D:** 2,751 desktop sessions (12.1% High): 32 Legit, 28 Nonlegit, 2,691 unlabelled. Labelled added sessions are 47% Nonlegit vs 43% across all labels (no enrichment).

| Part | Sessions | High | Legit | Nonlegit |
|---|---:|---:|---:|---:|
| (a) coarse UA × DP never seen, alone | 1,957 | 14.2% | 26 | 13 |
| (b) 2+ warnings | 794 | 7.1% | 6 | 15 |

## Why part (a) fires (consistent with, not proven)

9 of 13 part-(a) examples claim Chrome 157 with ordinary Windows device_params. Chrome 157 had 2,209 Dict 63 desktop sessions in the whitelist week vs 160k+ for Chrome 156, and 9,835 desktop sessions on 6 Nov. The coarse UA key is browser + **major version**, so a brand-new major version has never been seen with any device_params: a browser release looks like "doesn't fit the hardware". This is the browser-release case (L5) where a new version should be neutral.

## Suggested next step (not applied)

Drop part (a) until the coarse UA key treats a **newer** browser major version as neutral (like newer OS versions), then re-test (b) + (c) and a version-safe (a) on another labelled day.

## Caveats

- SQL was pasted into the tool per window; two attempts hit the response cap and one a GROUP BY error, all re-run. Outputs were slimmed (unused columns dropped).
- Results and labels were extracted from the agent's transcript by `_scripts/extract_*.py`.
- The whitelist was rescanned per window (six times).
- 5-session difference vs an earlier count (91,613 vs 91,618).
- Not done: full per-cell disagreement detail; 20 examples only for the T1-added cell (18–24 h window).
- One key, one day, uncleaned account whitelist, standalone (no List A/B/C).
- `labels_2026-11-06.csv` (customer truth-data labels per session) is kept locally and **not committed** pending a decision on storing label data in the repo.
