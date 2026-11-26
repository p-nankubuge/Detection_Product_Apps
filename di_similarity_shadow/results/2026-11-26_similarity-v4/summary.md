# Similarity v4 (pairs graded common / rare / never): summary

- **Measured first, as asked:** on desktop, pairs that were seen together but only rarely are **no riskier than common ones** (every
  frequency bin 0.4-1.3x the 4.9% High-risk baseline). The risk is in pairs **never** seen together: UA × device_params 18.4% High (coarse)
  and 10.3% (exact), screen × device_params exact 9.3%.
- **Proposed cut-off:** desktop, no frequency cut-off ("rare" = coarse pair seen, exact pair never seen, i.e. v3's warning). Mobile:
  screen × device_params and screen × platform group seen in fewer than 1e-4 of mobile whitelist sessions (~2x baseline, on 10 High sessions
  only). One cut-off does not fit all checks.
- **v4 with those cut-offs gives exactly v3's bands** (all 9,156 sessions; 0 differences): same 64.6% / up 27.7% / down 7.7%; G3 desktop
  still 0.70x, mobile 3.4x. Grading by frequency alone does not fix the desktop Band D problem.
- **The trigger is what matters.** Adding "coarse UA × device_params never seen alone → D" (a), "2+ warning signs → D" (b) and "screen ×
  WebGL failure counts as a warning" (c) together lifts desktop G3 from 0.70x to **2.77x** (D-by-check 12.0% High vs 4.3% passing), puts all
  16 High sessions of the v1 Dict 15 group into D, at a cost of +266 sessions in D (57 High) and G1 71.0% → 67.0%.
- **Recommendation for the spec owner (not applied):** keep v3 pair grading on desktop, and test the a + b + c trigger on a second window and
  on truth data before deciding (D-9 revisit condition is met). Mobile cut-off 1e-4 is reported only (mobile warnings never trigger D).

## Terms

- **Signature:** the six fields DI fingerprints a session by: OS (+version), JA4 (TLS fingerprint), screen size, device_params (platform,
  CPU cores, colour depth, touch, flags, font hash), User-Agent, WebGL renderer.
- **Whitelist:** today's Dict 63 signatures on the Figma account (13-20 Nov), uncleaned. "Seen" means present in it.
- **Pair:** two fields checked together, e.g. "this User-Agent with these device_params". **Coarse** = simplified values (browser + major
  version; device_params positions 1, 4, 5, 10, 11); **exact** = full values. Screen is the physical size (`w,h`).
- **Never / rare / common:** a pair never seen together (coarse) is a **failed check**; seen but below the cut-off (or exact pair never seen)
  is **rare** = one **warning sign**; otherwise **common** = pass. Frequency = share of the platform group's whitelist sessions.
- **Band D:** the lowest trust band (like Dict 1/3). A session is in D if its similarity score is < 0.40, or by the **trigger**: desktop =
  2 failed checks, or 1 failed check + 1 warning sign; mobile = 1 failed check.
- **High risk:** `latest_risk_band = 'High'`, Arkose's own risk label. An indicator, not ground truth. **G3** = High rate of sessions put in
  D by the trigger ÷ High rate of the rest.

## v1-v4 and what-if triggers (Figma K2, 20 Nov 12:00-14:00 UTC, 9,156 sessions)

| Version | Same bucket | Moved up | Moved down | Promoted (1/3 → A/B) | Demoted (63/31/15 → D) | Band D (High %) | Not D High % | G1 | G5 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| v1 | 63.9% | 22.1% | 14.0% | 298 | 361 | 1,076 (6.6%) | 4.5% | 63.5% | 94.7% |
| v2 (published) | 65.6% | 25.6% | 8.8% | 308 | 184 | 483 | | 65.7% | 94.8% |
| v3 | 64.6% | 27.7% | 7.7% | 333 | 176 | 466 (6.4%) | 4.7% | 71.0% | 95.9% |
| **v4** (main cut-offs) | **64.6%** | **27.7%** | **7.7%** | 333 | 176 | 466 (6.4%) | 4.7% | 71.0% | 95.9% |
| v4 + a | 63.9% | 26.9% | 9.2% | 328 | 299 | 629 (10.8%) | 4.3% | 69.9% | 95.7% |
| v4 + b | 64.5% | 27.2% | 8.4% | 319 | 216 | 569 (8.6%) | 4.5% | 68.0% | 95.9% |
| v4 + c | 65.1% | 28.1% | 6.8% | 338 | 128 | 339 (8.0%) | 4.6% | 72.1% | 95.9% |
| v4 + a + b + c | 63.8% | 26.4% | 9.8% | 314 | 339 | 732 (11.9%) | 4.1% | 67.0% | 95.7% |
| uniform cut-off 1e-4 (sensitivity) | 64.2% | 26.7% | 9.1% | 326 | 277 | 624 (7.2%) | 4.6% | 69.5% | 95.8% |
| uniform cut-off 1e-3 (sensitivity) | 63.6% | 26.2% | 10.1% | 325 | 360 | 723 (8.3%) | 4.5% | 69.3% | 95.5% |

G1 = Dict 1/3 sessions scored A/B (of 469). G5 = Dict 63 → A (of 5,023). The one Dict -1 session is B in v2-v4 (D in v1).

## G3: Band D by the trigger vs passing (High risk)

| Version | Desktop D-by-check | Desktop passing | Desktop ratio | Mobile D-by-check | Mobile passing | Mobile ratio |
|---|---|---|---:|---|---|---:|
| v1 | 61/976 = 6.2% | 317/6,713 = 4.7% | 1.32x | 10/97 = 10.3% | 48/1,370 = 3.5% | 2.9x |
| v2 (published) | 5.2% | 4.9% | 1.05x | 12.8% | 3.4% | 3.8x |
| v3 = v4 | 11/316 = 3.5% | 367/7,373 = 5.0% | **0.70x** | 11/95 = 11.6% | 47/1,372 = 3.4% | 3.4x |
| v4 + a | 49/479 = 10.2% | 329/7,210 = 4.6% | 2.24x | same | same | 3.4x |
| v4 + b | 33/430 = 7.7% | 345/7,259 = 4.8% | 1.61x | same | same | 3.4x |
| v4 + c | 8/183 = 4.4% | 370/7,506 = 4.9% | 0.89x | same | same | 3.4x |
| **v4 + a + b + c** | **71/593 = 12.0%** | 307/7,096 = 4.3% | **2.77x** | same | same | 3.4x |
| uniform 1e-4 | 26/474 = 5.5% | 352/7,215 = 4.9% | 1.12x | same | same | 3.4x |
| uniform 1e-3 | 41/574 = 7.1% | 337/7,115 = 4.7% | 1.51x | same | same | 3.4x |

Flow vs v3 (sessions into / out of D, High): a +163 in (38 High, 23.3%); b +103 in (19, 18.4%); c 127 out (3 High, 2.4%); a+b+c +266 in
(57, 21.4%), 0 out (sessions freed by c stay in D through b when they also have another warning); uniform 1e-4 +158 (15, 9.5%); 1e-3 +257 (30, 11.7%).

## High risk by failed checks × warning signs (v4; desktop identical to v3)

| Failed checks | Warnings | Desktop n | Desktop High | Mobile n | Mobile High |
|---|---|---:|---:|---:|---:|
| 0 | 0 | 5,964 | 4.2% | 1,320 | 3.6% |
| 0 | 1 | 954 | 5.8% | 27 | 0 |
| 0 | 2 | 114 | **19.3%** | 25 | 0 |
| 1 | 0 | 341 | **12.0%** (not D) | 46 | 8.7% (D) |
| 1 | 1 | 149 | 2.0% (D) | 17 | 23.5% (D) |
| 1 | 2 | 47 | 12.8% (D) | 12 | 25.0% (D) |
| 2+ | 0-1 | 120 | 1.7% (D) | 20 | 0 (D) |

On mobile, v4 now counts frequency-rare screen pairs as warnings (88 sessions with one): with no failed check 0 of 52 are High; with a
failed check 7 of 36 (19%). Mobile warnings are reported only.

## Where the v1 Dict 15 group lands (53 sessions, 16 High; Dict 15 today, Band D in v1 by UA×DP + screen×DP)

| Version | A | B | C | D |
|---|---|---|---|---|
| v3 = v4 = v4 + c | 3 | 23 (8 High) | 20 (8 High) | 7 (0 High) |
| v4 + a; uniform 1e-4 / 1e-3 | 3 | 21 (8) | 19 (8) | 10 (0) |
| v4 + b | 3 | 8 (0) | 6 (0) | **36 (16 High)** |
| v4 + a + b + c | 3 | 6 (0) | 5 (0) | **39 (16 High)** |

All 16 High sessions carry two exact-only pair warnings (UA×DP and screen×DP) and no failed check, so only trigger b reaches them.

## Examples (12 per cell, not 20: response cap; `q4_examples_result.txt`)

- **Newly in D under a + b + c (12):** 6 by trigger a (coarse UA×DP never seen, e.g. Chrome 130 / Firefox 153 with device_params never seen
  with that browser version), 6 by b (2 warnings: exact UA×DP + screen×DP never seen, or never-seen screen + never-seen device_params). 1
  High, 1 Medium, 10 Low. Two Linux sessions report `Linux armv81` platform and a mobile GPU (Mali, PowerVR) with a desktop UA.
- **Newly out of D under c (12):** all Windows, all Low; screen × WebGL never seen with one other warning (e.g. ultrawide 3440×1440 or
  5120×1440 with a common NVIDIA GPU; 1366×768 laptops).
- **Rare-pair sessions (12, mobile):** all Android, mostly the frozen `Android 10; K` UA, screens seen with that device_params in 1-8
  whitelist sessions; 1 High, 2 Medium, 9 Low. 7 of the 12 are A/B and unchanged.

## Proposed spec rows (not edited, per instructions)

| Where | Proposed text |
|---|---|
| §2 Design alignment, pair grading (D-18) | "Measured cut-off (Figma K2, 20 Nov, account whitelist): desktop groups, no frequency cut-off; rare = coarse pair seen, exact pair never seen. Mobile: screen × device_params (coarse) and screen × platform group < 1e-4 of the group's whitelist sessions = rare. Re-measure on the pooled vertical whitelist (D-17)." |
| §2 Band D trigger (candidate, not decided) | "Desktop: 2 failed checks; or 1 failed check + 1 warning sign; or a coarse UA × device_params failure alone; or 2+ warning signs. Screen × WebGL never seen = warning sign, not a failed check." |

Files: `frequency_bins.md` (step 1), `crosstab.md`, `disagreement.md`, `gates.md`, `caveats.md`, raw results `q*_result.txt`, queries `*.sql`,
`_core_template_v4.sql`, `_scripts/`.
