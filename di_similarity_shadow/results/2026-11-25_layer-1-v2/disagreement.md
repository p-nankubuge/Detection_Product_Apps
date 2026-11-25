# Disagreement report: today's DI vs similarity scoring (layer 1 v2, Seen-before rules)

**Question:** if DI scored sessions by similarity to known real devices instead of exact match, which sessions would move up or down, and why? This re-run keeps everything from the first layer-1 run and changes only how "seen before" is decided (agent file, "Seen-before rules"; `decisions.md` D-1 to D-7). What changed between the two runs is in `compare_v1_v2.md`.

**Scope:** Figma Registration K2 (`A207F8A1-ED09-4325-ACE6-C8E26A458FBA`, not a proxy key). Sessions created 2026-11-20 12:00-14:00 UTC, **all 9,156, no sampling**. Whitelist: distinct Dict 63 signatures on this key, sessions created 13-20 Nov, **uncleaned** (65,959 signatures). Standalone: no List A/B/C, no N-rules, no bad/suspicious lists, so the Impossible column is empty. **No truth data** (no Legit / Nonlegit split). Sanity test passed (`sanity_test_v2_result.md`).

**One line:** same bucket **65.6%** (6,005), moved up **25.6%** (2,345), moved down **8.8%** (806). First run: 63.9% / 22.1% / 14.0%.

## How to read this

Today DI walks a chain (os → JA4 → screen → device_params → UA → WebGL) and reports how far an exact match got (1, 3, 7, 15, 31, 63). The new scoring finds the closest known device of the same OS family and adds up the weights of the fields that match (score 0-1; Band A ≥ 0.85, B ≥ 0.65, C ≥ 0.40, D below). Then consistency checks ask "have we seen these values together before?" Failing them forces Band D (mobile: 1 failure; other groups: 2 failures, or 1 failure plus a never-seen desktop screen or device_params).

What changed in this run: "seen before" is now judged within a **platform group** (Desktop = Windows/macOS/ChromeOS with a real GPU; Mobile = iOS/iPadOS/Android; Linux; Windows RD/VM = Windows with the Basic Render Driver; Other = software renderers and rare OSes), pair checks compare **coarse** values (UA = browser + major version; device_params = platform, colour depth, CPU cores, touch), an old OS version is **reported only**, and a never-seen device_params on desktop is a **warning sign, not a failed check**.

Cell labels: **same bucket** 63→A, 31/15→B, 7→C, 3/1/-1→D. **Moved up**: better band than that. **Moved down**: worse band. Within these, **promoted** = today 1/3 → A/B, **demoted** = today 63/31/15 → D (or Impossible).

Abbreviations: JA4 = different JA4; JA4qt = QUIC/TCP variant of a known JA4 of the same browser (⅔ credit); UA = different UA; UAmaj = same browser and major version (½ credit); SCR = screen; DP = device_params; GL = WebGL; `diff:` alone = exact match; [BRD] = Windows Basic Render (WebGL ignored, max Band B). Checks: UAxDP, SCRxDP, SCRxGL = pair never seen together in the platform group; SCRxPG = screen seen only in another platform group; DPnew(fail) = mobile device_params never seen (failed check); +SCRnew / +DPnew = never-seen desktop screen / device_params (warning signs).

## 1. Comparison table (sessions, row %)

| Today | Band A | Band B | Band C | Band D | No score | Impossible | Total |
|---|---:|---:|---:|---:|---:|---|---:|
| 63 | **4,762 (94.8%)** same | 230 (4.6%) down | 2 (0.0%) down | 29 (0.6%) **demoted** | 0 | (not applied) | 5,023 |
| 31 | 830 (56.5%) up | **512 (34.8%)** same | 70 (4.8%) down | 58 (3.9%) **demoted** | 0 | (not applied) | 1,470 |
| 15 | 375 (35.5%) up | **466 (44.2%)** same | 117 (11.1%) down | 97 (9.2%) **demoted** | 0 | (not applied) | 1,055 |
| 7 | 259 (22.8%) up | 507 (44.6%) up | **169 (14.9%)** same | 203 (17.8%) down | 0 | (not applied) | 1,138 |
| 3 | 120 (26.9%) **promoted** | 173 (38.8%) **promoted** | 62 (13.9%) up | **91 (20.4%)** same | 0 | (not applied) | 446 |
| 1 | 9 (39.1%) **promoted** | 6 (26.1%) **promoted** | 3 (13.0%) up | **5 (21.7%)** same | 0 | (not applied) | 23 |
| -1 | 1 (100%) up | 0 | 0 | **0** | 0 | (not applied) | 1 |

Promoted 308 (3.4%), demoted 184 (2.0%). Outcome rates for every cell are in `crosstab.md`.

## 2. Every moved cell

Rates are within the cell. Top keys: only one key was scored, so every cell's top key is Figma Registration K2 (100%). Reasons: top 5 per cell (`q2_flow_reasons_result.txt`, `RS` rows), with High-risk count. Examples: `examples_result.txt`; counts fetched are stated per cell (20 was not reachable within the response cap, see `caveats.md`).

### Moved down

| Cell | n | Verified | High risk | Challenged | Chall. not solved | Top 5 reasons: n (High) | Examples |
|---|---:|---:|---:|---:|---:|---|---|
| 63→B | 230 | 93.5% | 4.8% | 21.3% | 6.5% | [BRD] exact match capped at B 87 (4) · UA 50 (1) · DP 32 (1) · SCR 24 (4) · JA4+UA 15 (0) | 0 (see first run) |
| 63→C | 2 | 100% | 0% | 50.0% | 0% | [BRD] DP 1 (0) · UA+GL 1 (0) | 0 |
| **63→D demoted** | 29 | 100% | 6.9% | 20.7% | 0% | SCRxDP SCRxGL 14 (0) · SCRxGL 6 (2) · SCRxPG+SCRnew 4 (0) · [BRD] SCRxPG+SCRnew 4 (0) · UAxDP 1 (0) | 10 |
| 31→C | 70 | 92.9% | 7.1% | 15.7% | 4.3% | UA+DP 17 (0) · SCR+GL 7 (4) · UA+GL 6 (1) · JA4+UA+GL 5 (0) · SCR+DP 5 (0) | 0 |
| **31→D demoted** | 58 | 98.3% | 3.4% | 10.3% | 1.7% | SCRxDP SCRxGL 30 (0) · SCRxGL 13 (2) · SCRxPG+SCRnew 5 (0) · SCRxDP 3 (0) · UAxDP SCRxGL 2 (0) | 10 |
| 15→C | 117 | 83.8% | **14.5%** | 40.2% | 10.3% | UA+DP 42 (**13**) · JA4+UA+GL 13 (0) · JA4qt+UA+DP 9 (0) · JA4qt+UA+GL 9 (0) · SCR+DP 9 (0) | 10 |
| **15→D demoted** | 97 | 94.8% | 3.1% | 18.6% | 4.1% | SCRxDP SCRxGL 26 (0) · UAxDP 16 (3) · UAxDP SCRxDP 12 (0) · SCRxGL 9 (0) · SCRxDP 6 (0) | 10 |
| 7→D | 203 | 94.6% | 7.4% | 19.7% | 4.9% | SCRxDP SCRxGL 62 (3) · SCRxGL+DPnew 45 (0) · SCRxPG+SCRnew+DPnew 40 (**6**) · UAxDP SCRxDP SCRxGL 9 (1) · UAxDP SCRxDP 6 (0) | 10 |

What the down cells mean:
- **63→B (230):** mostly not a check: 87 are exact whitelist matches capped at B by the Basic Render rule; the rest differ from their closest known device in one field (a new UA, DP or window size, typically a signature first seen on 20 Nov, after the whitelist window). Unchanged from the first run.
- **Demoted 63/31/15 → D (184, was 361):** what is left is almost all **SCRxDP + SCRxGL** on desktop: a known device_params and GPU with a screen string never seen with them. The screen string includes the available window size (e.g. `2560,1329::2560,1440`), so a resized browser window produces a "new" screen. Examples are Mac M1-M5 and Windows Intel/NVIDIA Chrome sessions, all Low risk and verified. On mobile, a single SCRxGL (Android tablet/foldable sizes, e.g. `1293,582`) is enough. High risk is 0-3 per reason. Small exceptions worth a look: SCRxPG (screen seen only in another platform group) catches a "GNU/Linux" session with an Android device_params (`Linux armv81`, touch 5), an Adreno 610 GPU and an 804×360 screen (63→D), which is the kind of mismatch the check is meant for; and 15→D UAxDP (16 sessions, 3 High), mostly mobile.
- **15→C (117), 14.5% High:** not checks; these score 0.40-0.65 because two fields differ from the closest device. The **UA+DP** group (42, 13 High) contains 8 of the 16 High-risk sessions from the first run's UAxDP+SCRxDP group (see `compare_v1_v2.md` §4). Examples: Windows Chrome 155-158 on RTX 2070 / GTX 750 Ti / RX 7900 XT with new core counts, several Medium risk.
- **7→D (203):** SCRxDP+SCRxGL on desktop window sizes (62, 3 High); SCRxGL plus a never-seen DP (45, 0 High); and **SCRxPG+SCRnew+DPnew (40, 6 High)**: screens seen only in another platform group. The example fetched is Windows + llvmpipe (software renderer, so platform group Other, Medium risk); the Other group holds 37 Windows Band D sessions with 6 High, consistent with most of this reason being software-renderer devices, but that was not checked session by session.

### Moved up

| Cell | n | Verified | High risk | Challenged | Chall. not solved | Top 5 reasons: n (High) | Examples |
|---|---:|---:|---:|---:|---:|---|---|
| 31→A | 830 | 92.5% | 5.2% | 26.9% | 5.5% | JA4qt 301 (11) · UA 275 (**25**) · SCR 195 (7) · GL 19 (0) · DP 15 (0) | 0 (see first run) |
| 15→A | 375 | 92.5% | 6.4% | 33.9% | 7.2% | JA4qt 118 (10) · UA 107 (9) · UAmaj 78 (4) · SCR 27 (0) · DP 19 (0) | 0 |
| 7→A | 259 | 91.5% | 3.9% | 24.3% | 6.9% | JA4qt 123 (8) · SCR 59 (0) · DP 47 (1) · JA4 27 (1) · UAmaj 2 (0) | 0 |
| 7→B | 507 | 87.8% | 4.1% | 28.6% | 9.7% | DP 153 (11) · JA4qt+DP 115 (0) · JA4qt+SCR 50 (0) · JA4qt+UA 35 (3) · JA4+UA 27 (3) | 0 |
| **3→A promoted** | 120 | 90.8% | 10.8% | 37.5% | 9.2% | JA4qt 43 (8) · SCR 31 (1) · UAmaj 24 (3) · JA4 18 (0) · JA4qt+UAmaj 3 (1) | 10 |
| **3→B promoted** | 173 | 93.1% | 3.5% | 33.5% | 5.8% | SCR 62 (2) · JA4qt+SCR 23 (1) · JA4qt+UA 23 (2) · JA4+UA 13 (1) · JA4qt+UA+SCR 7 (0) | 10 |
| 3→C | 62 | 90.3% | 9.7% | 37.1% | 8.1% | SCR+DP 11 (1) · JA4qt+SCR 9 (1) · JA4qt+SCR+DP 4 (0) · SCR+DP+GL 4 (0) · JA4+UA+DP 3 (2) | 0 |
| **1→A promoted** | 9 | 88.9% | 11.1% | 22.2% | 11.1% | JA4 9 (1) | 9 (all) |
| **1→B promoted** | 6 | 66.7% | 16.7% | 50.0% | 33.3% | JA4 2 (1) · [BRD] JA4 1 · JA4+SCR 1 · JA4+UA+DP 1 · JA4qt+SCR 1 | 6 (all) |
| 1→C | 3 | 100% | 0% | 33.3% | 0% | [BRD] JA4+SCR 1 · JA4+SCR+GL 1 · JA4+SCR 1 | 3 (all) |
| -1→A | 1 | 100% | 0% | 0% | 0% | UAmaj 1 | 1 (all) |

What the up cells mean:
- **31/15/7 → A (1,464):** near matches: the closest known device differs only in JA4 transport (QUIC vs TCP of the same browser), the UA (browser update or a different browser on the same hardware) or the window size. Same as the first run, slightly larger because fewer sessions are now forced into D. "UA differs" in 31→A has 25 High of 275 (9.1%), above the Dict 31 baseline (5.2%).
- **7→B (507, was 272):** the largest change. 237 of the 507 came out of Band D (185 through the device_params warning rule, 52 through coarse pairs): a new device_params on otherwise known hardware now keeps its score (0.70, Band B) instead of being forced to D. High risk 4.1%, below the Dict 7 baseline (5.4%).
- **Promoted 3→A/B (293), 1→A/B (15):** as in the first run. 3→A JA4qt carries 8 of 43 High; part of it is no-ALPN JA4s on the uncleaned whitelist (`t13d260900_…` Safari, `t13d100900_…` Mac Chrome). 1→A is still dominated by one `t13d3213h1_3af914e56c9f_cf4b9e61af1f` Windows device (6 of 9), plus `t12d520500_…` and `t12d2605h2_…` JA4s: similarity cannot see JA4 anomalies; that is layer 3's job (List C / N9-N11). 1→B includes 2 GNU/Linux **SwiftShader** sessions (1 High).
- **-1→A (1):** an iOS 17.1 in-app browser (POPO) session; in the first run it was Band D only through the OS-version failed check, which no longer counts.

## 3. Truth data
Not used for this run (as instructed). No Legit / Nonlegit split.

## Files
`crosstab.md`, `compare_v1_v2.md`, `gates.md`, `caveats.md`, `examples_result.txt`, `q1_crosstab_gates.sql` (+ `_result.txt`), `q2_flow_reasons.sql` (+ `_result.txt`), `examples_y1.sql` - `examples_y4.sql`, `sanity_test_v2.sql` (+ `_result.md`), `_core_template_v2.sql`, `whitelist_profile.sql`.
