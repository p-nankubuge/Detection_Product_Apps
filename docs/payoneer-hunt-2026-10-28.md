# Payoneer hunt — 2026-10-28 (follow-up to DETCORE-4466)

**Keys:** Registration `7CC24C4A` (Key 1) · Login `EE844FC3` (Key 2) · CLM Registration `E3EFEFBF` (Key 3)
**Source:** `ARK_PROD.events.mini_events_log`, session_setup / game_verify / game_setup, Sep 13 – Oct 27.
**Conventions:** suspicion flags + global TTs live in `SUSPICION_FLAGS`; pressured TTs in `TELLTALE_LIST`.
"Verified" = `game_verify` solved+verified; "challenged" = session reached `game_setup`.
Queries: `queries/payoneer_hunt.sql`.

## 1. Your pair: `g-dp-invalid-resolution` + `g-dp-spoofing-browser-values`

On Payoneer, `g-dp-invalid-resolution` is effectively the whole signal (774/774 on CLM, 621/622 on Login also
carry the spoofing flag). The traffic it tags is one kit:

| attribute | value |
| --- | --- |
| fp_resolution | `[1050,1000]` (94%) |
| fp_available_resolution | `[2560,1392]` (> resolution, which is why `efp-bad-fr` fires) |
| browser | Firefox 151–153 |
| language / country | zh-CN / CN (CN mobile, Unicom, Chinanet) |
| email | outlook.com / hotmail.com |
| webgl | rotating (Generic Renderer, Radeon R9 200, GTX 980, …) |

### 1a. NEW — the same kit with a Chrome UA, which the pair misses

Same `fp_resolution = [1050,1000]`, but `fp_available_resolution = [1050,960]` (consistent), so `efp-bad-fr` /
`g-dp-invalid-resolution` never fire. Chrome 151–156, Windows + OS X, zh-CN, CN, outlook/hotmail, rotating WebGL.

| key | sessions (45d) | verified | challenged |
| --- | --- | --- | --- |
| CLM | 1,493 | 94% | 21% |
| Login | 880 | 97% | 1% |

**It is the variant still running.** After the pair flags went in (Oct 21) the Firefox variant fell to 6 → 3/day on
CLM, while the Chrome variant hit its highest volume on **Oct 26 (97) and Oct 27 (133)** on CLM and 59 → 68 on Login.

Tells it always carries (100%): `g-thr-chrome-tcp-wrong-cipher`, `client-hints-has-not-a-brand-grease`,
`susp-rfc-violation-cdn-header-order-sec-ch-ua-platform-before-user-agent`, `window-tree-index-is-empty`; 56% have
`g-math-fingerprint-mismatch`. **These are too generic on their own** (the three-flag combo matches 9.4M Login
sessions / 30d), so the resolution is the anchor.

`fp_resolution = [1050,1000]` on Payoneer is 99–100% zh-CN + outlook/hotmail on both keys, and 0 on Registration.

## 2. Other missed / low-and-slow actors

| # | actor | sessions by key | verified | challenged | status |
| --- | --- | --- | --- | --- | --- |
| A | **`[830,800]` resolution, Windows, hotmail, fake `en-EN` locale**, JP/CO/KR residential IPs | CLM 4,840 · Login 1,767 (45d) | 98–99% | 2–23% | CLM quiet since Oct 23; **active on Login** (Oct 22: 117, Oct 25: 126, Oct 27: 24) |
| B | **Tencent Cloud (hosting) + outlook, handle pattern 8 chars / 4 letters / 4 digits** (`0804040000`), Chrome 147/148, zh-CN | CLM 2,286 · Login 8,582 · Reg 131 | 97–99% | ~15% | CLM burst Oct 7–19 (peak 370/d) then gone; Login steady ~200/d for 46 days; Reg trickle since Oct 14 |
| C | US outlook, `[3440,1440]`, Chrome 150 Windows — 3 fingerprints over 262 IPs | CLM 397 · Login 57 | 100% | 0% | **new Oct 22, active** |
| D | CN hotmail, Chrome 109 (Win7-era), `[1280,960]` — 1 fingerprint over 102+ IPs | CLM 344 · Login 166 | 100% | 0% | Oct 19–26 |
| E | FR outlook, single fingerprint seen from 25 countries | Login 280 · Reg 99 | 94–98% | 3–19% | ongoing, ~10/d |
| F | NG Chrome 154/155 `[1366,768]` / BD `[1920,1080]` fingerprint reuse | Login 4.7k · CLM 723 · Reg 406 | 85–98% | 1–19% | ongoing — **validate first, may be a common-laptop fingerprint collision** |

Actor A **is** the "reversed-navigator-languages-priority" surge of Oct 15–17 (CO, hotmail, Chrome 154,
`[830,800]`, 98% verified). It fingerprint-rotates on CLM (1,823 FPs / 4,840) but on Login reuses
**66 fingerprints across 1,506 IPs** (residential-proxy rotation). Fits Saul's "moved to Login" observation.

Actor B on Login is broader (more Chrome versions, 19% on the core handle pattern); the core is
Tencent + outlook + 4-letter/4-digit handle. `payoneer-email-pattern-4-lowercase-letters-4-digits-outlook`
already exists as a suspicion flag but carries no pressure (16% custom-TT coverage during the Oct 15–16 surge).

## 3. CLM surge episodes (flag/TT count ≥ 3× trailing-14d mean and ≥ 60/day)

| date | driver flag(s) | sessions | verified | challenged | custom-TT cover | verdict |
| --- | --- | --- | --- | --- | --- | --- |
| Sep 28 | `g-email-domainvolume-highrisk` | 805 | 83% | 89% | 98% | flagged |
| Sep 30–Oct 1 | `g-di-high-risk-signature-exceeding-short-term-threshold` | 1,971 | 80% | 75% | 79% | flagged |
| Sep 30–Oct 5 | `client-hints-sec-ch-ua-unexpected-non-major-version` | 1,195 | 96% | 2% | 23% | benign: Samsung Browser 30 rollout (86%), diverse geo |
| Oct 7–11 | `susp-anomaly-value-spoof` + `g-thr-firefox-tcp-wrong-cipher` + accept-accept | 10,393 | 32% | 50% | 85% | flagged, mitigated well |
| Oct 13–14 | pragma/cache-control header order + `g-email-rule-…mixed-alphanumeric-special-pattern` | 2,287 | 59% | 83% | 91% | flagged |
| Oct 15–17 | `reversed-navigator-languages-priority`, `rare-language-reorder-regex-captcha-ai` | 694 | 98% | 23% | 72% | **missed** → actor A |
| Oct 15–16 | `payoneer-email-pattern-4-lowercase-letters-4-digits-outlook` | 737 | 98% | 15% | 16% | **missed** → actor B |
| Oct 19 | `g-dp-invalid-resolution` | 93 | — | — | — | your pair |
| Oct 21 | `g-ai-muse-agent` | 66 | 100% | 0% | 29% | small, worth a look |
| Oct 27 | `ja4-dict-1-challenger` | 376 | 77% | 79% | 100% | flagged (new, today) |

Pattern: big automated waves get flagged and challenged. Missed waves are **< 400/day, ≥ 96% verified**, and sit
on one odd device constant (resolution, locale) plus outlook/hotmail. They stay under volume alerts and get
through the pressure they do receive.

## 4. Proposed suspicion flags (not created — for review)

Field syntax: existing TTs use both `"[1920, 1080]"` and `"1920,1080"` for `fp_resolution`, so check which one
matches in the TT tester before enabling.

1. `payoneer{e3ef,ee84}-h-dp-resolution-1050x1000` — `fp_resolution == 1050,1000`. Supersedes the pair: covers
   the Firefox **and** Chrome variants (~2.3k CLM + 1.5k Login / 45d, vs 1.4k for the pair).
2. `payoneer{e3ef,ee84}-h-dp-resolution-830x800-windows` — `fp_resolution == 830,800` + `os == Windows`
   (optional: `fp_language IN (en-EN, en)`). Actor A.
3. `payoneer-h-tencent-cloud-4l4d-outlook` — ISP Tencent Cloud + `#INCLUDE
   payoneer-email-pattern-4-lowercase-letters-4-digits-outlook`. Actor B core; also add it to Registration.
4. Watch-only (alert, no pressure yet): actor C (`[3440,1440]` + Chrome 150 + outlook + US) and actor D (Chrome 109 +
   `[1280,960]` + hotmail + CN).

**Durable idea:** the actors keep changing browser/UA but keep **one rare resolution per kit**. A per-key
suspicion flag/alert for "resolution with < N sessions/30d baseline that suddenly carries > X/day, ≥ 90% one
email provider" would have caught 1a, A and C on day one, without fingerprint-level fixes.
