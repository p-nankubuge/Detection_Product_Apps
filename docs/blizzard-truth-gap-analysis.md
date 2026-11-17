# Blizzard truth-data gap analysis: Registration K2 and Login K5

**Status:** DRAFT · **Date:** 2026-11-05 · **Scope:** Blizzard ROW Registration Key 2 (`E8A75615-1CBA-5DFF-8032-D16BCF234E10`) and ROW Login Key 5 (`CF5C61EE-F062-45DF-A32F-E9398E2B4E0D`)

Related: [IP Intelligence Q4 2026 Phase 1 one-pager](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4758208671) · [`login-velocity-detection.md`](login-velocity-detection.md)

---

## TL;DR

1. **The truth data is a list of fraud that got through.** Blizzard truth (`starfleet_production.truth_data_history`) is only on Registration K2: 270k `Nonlegit` sessions, 7 Aug to 2 Nov. **99.99% of them verified.** Login K5 has **no truth data**.
2. **About 27% of that fraud had no telltale** (≈50% in the 21 Oct sample window). The other 73% had telltales and **still verified**. So for most of it the gap is **score and pressure**, not detection.
3. **There is a stable suspicion-flag fingerprint for the missed fraud.** Rule **B**, all four of: `never-seen-before-fp-no-pressure`, `g-suspicious-extension-count-ja4-hash`, `github747b-h-email-free-domains` (free-mail, not gmail), and **no** `dx-ip-user-ip-mismatch`. On two separate windows it catches **66–87% of the fraud and 81–95% of the fraud that had no TT**, at a **3.3–4.2× lift** over the base rate.
4. **IP and subnet signals don't see this attack.** It's a residential-proxy spread at ~1 session per IP. **0%** of fraud sessions are over 0.5× IP velocity, subnet velocity (`rta__sdv_*`) never goes over 1, the ASN risk band is never High or Medium, and connection-type thresholds are **missing on 100% of Key 2**. The attack's concentration is on **JA4**, not on IP: 2 JA4s carry 87% of the 21 Oct wave across 630 distinct /24s.
5. **Login K5 is mostly unscored.** 86% of login sessions carry no telltale. Data Exchange flags never fire there (`dx-*` = 0%), subnet velocity isn't computed (100% null), and the only subnet TT is a static Ensemble list of Tor-exit /24s (0.17% of traffic).

---

## 1. Data and method

| Item | Detail |
| --- | --- |
| Truth | `starfleet_production.truth_data_history`: per-session `is_legit`, `is_verified`, `telltale_list`, `suspicion_flags` |
| Events | `arkoselabs.events_faster` (Athena, partition `ymdh = 'YYYY/MM/DD/HH'`), `session_setup` for flags and IP fields, `game_verify` for verified |
| Population | **Verified** sessions only, so fraud is compared like for like (all truth sessions verified) |
| "Good" | Verified sessions **not** in truth. This is *unlabeled*, not confirmed legit: Blizzard only reports a subset of fraud, so precision figures below are a **lower bound** |
| Windows | W1 = 21 Oct 00:00–06:00 UTC (peak wave) · W2 = 27 Oct 12:00–18:00 UTC (later, to check drift). 6-hour windows because of the Superset/Athena timeout |
| Query | [`queries/blizzard_truth_flag_lift.sql`](../queries/blizzard_truth_flag_lift.sql) |

Weekly truth volume on K2 (Nonlegit only; `no TT` = nothing other than `g-sdc-enable`):

| Week of | Fraud sessions | Verified | No TT |
| --- | --- | --- | --- |
| 3 Aug | 36,726 | 36,723 | 11,172 (30%) |
| 10 Aug | 58,625 | 58,617 | 19,737 (34%) |
| 31 Aug | 38,341 | 38,335 | 4,701 (12%) |
| 12 Oct | 7,360 | 7,360 | 2,452 (33%) |
| 19 Oct | 21,714 | 21,714 | 9,901 (46%) |
| 26 Oct | 10,121 | 10,121 | 2,995 (30%) |

## 2. What fires on the missed fraud (Registration K2)

### 2.1 Telltales are fragmented

From 12 Oct onwards (39k fraud sessions) no single telltale covers more than ~15%:
`g-email-patternvolume-lowrisk` 15%, `g-email-intel-ml-score-high-confidence` 10%, `blizzard2-h-email-domainvolume-lowrisk` 9.5%, `g-reputation-hosting` 5%, `g-email-rule-char-repetition-transitions` 4.8%, `g-email-intel-ml-score-very-high-confidence` 4.7%. These are followed by a long tail of `blizzard2-h-td-*` combos and hundreds of auto-generated `blizzard2-e-aaa-*-mats-*` audit and tagging TTs at <2% each.

### 2.2 Suspicion flags that separate fraud (lift = fraud rate ÷ unlabeled rate)

| Flag | W1 fraud | W1 other | W2 fraud | W2 other | Stable? |
| --- | --- | --- | --- | --- | --- |
| `g-suspicious-extension-count-ja4-hash` | 90.8% | 28.0% | 79.4% | 23.5% | ✅ core |
| `never-seen-before-fp-no-pressure` | 91.5% | 31.5% | 73.5% | 27.6% | ✅ core |
| `github747b-h-email-free-domains` (free mail, not gmail) | 94.9% | 42.3% | 89.5% | 38.5% | ✅ core |
| `dx-ip-user-ip-mismatch` (**absent** on fraud) | 6.5% | 37.3% | 9.1% | 34.5% | ✅ core (negative) |
| `email-c-possible-attack-from-gmail-customer-id-x` (**absent**) | – | – | 6.0% | 26.2% | ✅ negative |
| `g-ip-residential-proxy-dx-user-ip` | 31.6% | 15.2% | 22.4% | 11.7% | ✅ add-on (~2×) |
| `fingerprint-age-old` | 20.3% | 6.4% | 10.3% | 3.8% | ✅ add-on |
| `g-h-old-suspicious-chrome` | 8.1% | 1.8% | 6.2% | 1.4% | ✅ add-on, small |
| `email-c-possible-attack-from-outlook-customer-id-x` | 6.4% | 2.1% | 7.4% | 1.7% | ✅ add-on, small |
| `cdn-header-order-ends-with-te` | 3.0% | 1.0% | 10.3% | 1.5% | ⚠️ grew in W2 |
| `g-thr-firefox-tcp-wrong-cipher` | – | – | 6.6% | 1.0% | ⚠️ W2 only |
| `g-spoofing-webgl-dimensions` / `rare-languages` | 6.7% / 13.6% | 0.8% / 2.3% | – | – | ⚠️ W1 only |
| `g-page-level-biometrics-empty-or-null`, `fp-touch-0-0-0` | 97.6% / 88.0% | 74.4% / 56.2% | no lift | no lift | ❌ drifted |

Reading: the fraud is a **fresh fingerprint** with a **bot-like JA4 extension count**, signing up with a **non-gmail free mailbox** (hotmail, outlook and others), through a proxy where the **DX IP and request IP match**. The whole browser tunnels through one exit, whereas real users often show an IPv4/IPv6 or DX mismatch.

### 2.3 Candidate rules (verified sessions; "precision" is against unlabeled traffic, so a lower bound)

| Rule | W1 recall | W1 no-TT recall | W1 precision | W2 recall | W2 no-TT recall | W2 precision |
| --- | --- | --- | --- | --- | --- | --- |
| Base rate | – | – | 10.4% | – | – | 4.9% |
| **A** = core-3 (no email) + biometrics empty + touch 0-0-0 | 81% | 89% | 47% | 41% | 36% | 23% |
| A + fraud JA4 family | 80% | 88% | 50% | 29% | 32% | 25% |
| **B** = 4-flag core | **87%** | **95%** | 35% | **66%** | **81%** | 21% |
| B + (res-proxy OR email-attack OR device anomaly) | 61% | 45% | 33% | 39% | 38% | 21% |

**B is the one to build.** A and the JA4-family variant score better on the 21 Oct wave but break when the attacker changes tooling (W2). B keeps a 3–4× lift and catches most of the fraud that has *no* TT, so it's the right base for a new key-level TT. Adding the extra signals as an AND lowers recall without raising precision, so use them as **separate, additive** TTs instead.

## 3. IP and subnet: what the one-pager signals can and can't do here

Fraud vs other, verified, W1:

| Signal | Fraud | Other | Takeaway |
| --- | --- | --- | --- |
| Distinct IPs / sessions | 751 / 946 | – | ~1 session per IP, per-IP velocity is blind |
| Distinct /24s | 692 | – | No subnet concentration |
| Distinct ASNs / countries | 266 / 38 | – | Global residential spread (US, UA, CL, HK, AR, JP) |
| IP short/long velocity > 0.5 | **0%** | 0.5% | 2a/2b/2c/4/5 fallbacks won't fire |
| Connection-type threshold present | **0%** | 0% | **K2 has no connection-type thresholds** (add to action 9) |
| `rta__sdv_*` present / ratio > 1 | 69% / **0%** | 54% / 1.9% | Subnet-distributed velocity doesn't trigger |
| ASN band High/Medium | 0% | 0% | 4 / 4b can't fire on Blizzard (W2: Medium 4.1% vs 0.7%, small) |
| Harvested proxy | **31%** | 12% | Best IP signal, about 2.7× |
| DE `hosting` | 2.1% | 4.6% | Datacenter flags (2a/2d/2e) are low value on registration |
| No IP data | 0.1% | 0.0% | 2j/2l are not relevant |
| Distinct JA4 | **32** | 115 | **The concentration is on JA4** |

The two fraud JA4s in W1:

| JA4 | Fraud | Other | Fraud share | Distinct /24s (fraud) |
| --- | --- | --- | --- | --- |
| `t13d1516h2_8daaf6152771_d8a2da3f94cd` | 552 | 1,934 | 22% | 426 |
| `t13d1516h2_8daaf6152771_806a8c22fdea` | 274 | 604 | 31% | 204 |

Chrome on GNU/Linux (40% fraud) and Chrome on macOS (34%) are heavily over-represented against a 10% base.

**"Subnet attack" reframed:** this isn't many sessions from a few subnets. It's **one client stack fanned out across hundreds of subnets**. The pivot that works is **JA4 (or JA4 + browser build) → distinct /24s per hour**, not IP → velocity. The existing Ensemble `Ja4SubnetVelocityDetector` output (`blizzard5-e-cf5c61ee-ja4-subnet-velocity-distributed-*`, risk 65 on Login K5) emits **static (subnet, JA4) pairs** for Tor exits (`185.220.101/24`, `109.70.100/24`, `192.42.116/24`, `204.8.96/24`) and iCloud Relay IPv6. Structurally, that can't catch a 692-subnet residential spread, and it **doesn't exist on Registration K2**.

## 4. Login K5 (no truth)

Session setup on 4 Nov, 12:00–15:00 UTC, 38k sessions:

- **86% of login sessions have no telltale** (21 Oct sample).
- `dx-ip-user-ip-mismatch` and `g-ip-residential-proxy-dx-user-ip` fire on **0%**: DX doesn't feed this key, so any rule ported from K2 must use the `user_ip` variants (e.g. `g-ip-residential-proxy-user-ip`).
- `rta__sdv_*` (subnet velocity) is **100% null**, so no subnet velocity is computed on login.
- Connection-type thresholds exist (98%). IP velocity > 1 on 1.2%.
- **DE `hosting` = 13.4% of login traffic** (vs ~4.6% on registration). The one-pager's datacenter flags **2d / 2e / 2a** are relevant here, unlike on K2.
- Harvested proxy 4.1%. `g-suspicious-extension-count-ja4-hash` 10%. `never-seen-before-fp` 4.9%. Fraud-family JA4s 1.3%.
- Bridging by device is weak: the 935 fraud fingerprints from W1 registration showed up on only 25 login sessions (7 fingerprints) in 3h, 23 of them with no TT. Fraud fingerprints are near-unique per session.

## 5. Recommendations

### 5.1 New custom TTs (Registration K2), shadow at risk 0 first

| # | Name (proposed) | Definition (pseudo, validate with `validate_telltale`) | Expected |
| --- | --- | --- | --- |
| K2-1 | `blizzard2-h-fresh-fp-bot-ja4-nongmail-free-mail-ip-consistent` | `public_key = K2` AND `location = session_setup` AND `#INCLUDE never-seen-before-fp-no-pressure` AND `#INCLUDE g-suspicious-extension-count-ja4-hash` AND `#INCLUDE github747b-h-email-free-domains` AND NOT (`dx-ip-user-ip-mismatch` condition) | 66–87% of fraud, 81–95% of no-TT fraud, 3–4× lift. Fires on 16–26% of verified traffic, so use **moderate score / pressure uplift, not block** |
| K2-2 | `…-K2-1-plus-harvested-proxy` | K2-1 AND `ip_intel__is_proxy_harvested = true` (or `#INCLUDE g-ip-residential-proxy-dx-user-ip`) | Higher-confidence tier for escalating pressure |
| K2-3 | `…-K2-1-plus-fp-age-old` | K2-1 AND `#INCLUDE fingerprint-age-old` | Same, a stable add-on |

Keep the *volatile* signals (`cdn-header-order-ends-with-te`, `g-thr-firefox-tcp-wrong-cipher`, `g-spoofing-webgl-dimensions`, `rare-languages`, the fraud JA4 list) as **separate short-TTL TTs** that stack on K2-1, so the base rule doesn't break when the tooling rotates.

### 5.2 Add confidence to the custom TTs that already fire

73% of the missed fraud *had* a TT and still verified. Most of the email-family and `blizzard2-h-td-*` TTs only see 1–15% of the fraud each and are too weak alone. The cheapest win is **co-occurrence uplift**: when any of the top firing TTs (`blizzard2-h-email-patternvolume-lowrisk`, `blizzard2-h-email-domainvolume-lowrisk`, `g-email-intel-ml-score-high-confidence`, `g-reputation-hosting`, `blizzard2-h-td-reputation-hosting-susp-ext-count-ja4-hash-creation-full`, `blizzard2-e-http-accept-language-validator`) fires **together with K2-1**, raise risk or pressure.

Next step: replay that on truth to set the exact weights. The lift query needs a `telltale_list` join, and the per-TT counts are in §2.1.

### 5.3 IP and subnet items (feed into the IP Intelligence one-pager)

1. **Action 9:** K2 has **no connection-type thresholds at all**. Add it to the list, alongside AT&T K3. Expect little against this specific attack, but it closes the blind spot.
2. **Phase 2 / Ensemble:** change `Ja4SubnetVelocityDetector` (or add a sibling) to emit a **JA4-dispersion** signal (JA4 seen across ≥N distinct /24s in a rolling hour, with a high never-seen-fingerprint share) rather than static subnet lists. Enable it on **K2**. W1 numbers: the top fraud JA4 spanned 426 /24s in 6h.
3. **Subnet velocity coverage:** `rta__sdv_*` is null on 100% of Login K5 and 31–46% of K2. Ask why before relying on it.
4. **ASN reputation (changes 4 / 4b):** the band is never High on Blizzard keys, so don't count on it here.
5. **Login K5:** score the one-pager's **2e** (`g-ip-datacenter-no-fingerprint`) and review **2d / 2a** on K5, since hosting is 13% of login. Use `user_ip` variants, because DX flags are dead on this key.

### 5.4 Data asks

- **Login truth** from Blizzard for K5, even a few thousand labelled ATO / credential-stuffing sessions. Without it, every login recommendation here is inferred from registration.
- Confirm with Blizzard that truth is **all reported fraud** and not a sample, so recall numbers are meaningful.

## 6. Traffic impact on all created sessions (FP check)

"Mitigated" means the session never verified. "Verified, not in truth" is the FP ceiling: some of it is unreported fraud. Quiet day = 11 Oct 12:00–18:00 UTC, with 43 truth sessions all day.

| Rule | Quiet day: % of created | W1 (21 Oct): % of created | W2 (27 Oct): % of created | W1 recall / W2 recall | W1 verified not in truth (% of created) | W2 verified not in truth (% of created) |
| --- | --- | --- | --- | --- | --- | --- |
| B (core-4) | **15.1%** | 29.8% | 22.8% | 87% / 65% | 1,999 (15.6%) | 1,416 (8.0%) |
| B + no biometrics + no touch | 8.4% | 19.2% | 11.7% | 81% / 41% | 1,170 (9.1%) | 729 (4.1%) |
| B + Linux/macOS | 4.6% | 8.1% | 4.9% | 43% / 16% | 524 (4.1%) | 324 (1.8%) |
| **C = B + (res-proxy OR fp-age-old)** | **1.3%** | 14.4% | 8.8% | 43% / 25% | 1,012 (7.9%) | 583 (3.3%) |

- **B alone is too broad:** it flags 15% of created sessions on a quiet day.
- **C is the rule to ship.** It sits at about 1% of traffic on a normal day and jumps 7–11× during an attack, so it tracks the attack rather than a slice of the population. The res-proxy and fp-age flags were firing on 11 Oct (2.8% and 1.5% of sessions) but rise to 16.9% and 8.7% in the 21 Oct wave.
- Expected FP from C at baseline is about 1.1% of created sessions (verified ones). On W1, C left 1,012 verified sessions outside truth against about 140 expected from baseline. The ~870 excess is likely **unreported fraud**; this is an inference, not confirmed.
- C's mitigated share: 23% (W1) and 54% (W2) of its hits were already stopped.
- The biometrics and Linux/macOS variants sit at a steady 5–8% of traffic on quiet days, so they're population filters. They'd carry a steady FP cost.

## 7. Caveats

- "Precision" is against unlabeled traffic, which includes unreported fraud, so true precision is higher.
- 6-hour windows were chosen because of query timeouts. W1 (peak wave) and W2 (later) disagree on the volatile flags; the core-4 rule is the part that held.
- Suspicion flags were read at `session_setup`; telltales that fire later in the session aren't reflected in the flag-lift tables.

## 8. DI dictionary matches, full week 21–27 Oct 2026 (Registration K2)

`DI_DICTIONARY_NUM_MATCHED` takes the values -1, 1, 3, 7, 15, 31, 63. Created sessions are taken at session setup in Athena `events_faster`, joined to Blizzard truth in twelve-hour chunks. Verified counts are from Snowflake `PROD_INT_SESSION_SUMMARY` (`SESSIONS_VERIFIED > 0`).

| Dict | All created | Share of all | Truth fraud | Share of truth | Fraud rate in bucket | Rule C created | Rule C verified | Truth in rule C | Truth share of rule C verified |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 3 | 35,173 | 8.5% | 1,014 | 4.2% | 2.9% | 3,445 | 1,363 | 226 | 17% |
| **7** | 126,530 | 30.6% | **14,146** | **59.3%** | **11.2%** | 29,882 | 9,047 | 4,268 | 47% |
| **15** | 74,297 | 18.0% | **6,689** | **28.0%** | **9.0%** | 12,727 | 6,128 | 2,909 | 47% |
| 31 | 61,672 | 14.9% | 918 | 3.8% | 1.5% | 656 | 341 | 155 | 45% |
| 63 | 112,068 | 27.1% | 1,050 | 4.4% | 0.9% | 6 | ~5 | 0 | – |
| Total | 413,189 | | 23,872 | | 5.8% | 46,764 | ~16.9k | 7,565 | 45% |

- **Dict 7 and 15 hold 87% of the reported fraud.** By day the share ranges from 76% to 91%, so it holds across the whole week. These two buckets are 49% of all traffic. Dict 63, the commonest value for other traffic (27%), holds 4% of the fraud.
- **Rule C's weak bucket is dict 3.** Only 17% of rule C's verified sessions at dict 3 are confirmed fraud, against 45–47% at dict 7, 15 and 31. Dropping dict 3 from rule C removes 3,445 created sessions (7% of rule C) and 1,363 verified, but only 226 truth sessions (3% of rule C's catch).
- **Refinement:** rule C AND dict matched ≥ 7.
- **Gap:** for the week, rule C catches 7,565 of 23,872 reported fraud sessions (32%). The 13,658 fraud sessions at dict 7 or 15 that rule C misses are the next target.

## 9. Login-ID velocity Layers 1–3 applied to Registration K2 (23 Oct 2026)

Rules from the [Real-time Velocity on Customer Login ID one-pager](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4728487955), run on Blizzard registration with the email as the identifier.

- **Identifier:** `customer_id_1` is a plain email (100% of sessions). `customer_id_2` is an IPv4 address (66% equal to our `user_ip`), not an account ID.
- **Baseline:** 7 days instead of 28, because the 28-day query timed out in Superset.
- **Key threshold:** P99 = 6 sessions per email per day.
- **History:** 94% of emails appear on a single day, which is expected for registration.

| Layer / group (23 Oct, Snowflake) | Emails | Sessions | Verified sessions | Emails also in rule C (dict ≥ 7) |
| --- | --- | --- | --- | --- |
| L1: new email, more than 6 sessions | 253 | 2,502 | 885 | 3 |
| L2: known email, more than 2× own max | 81 | 466 | 146 | 19 |
| Known email, under threshold | 4,986 | 5,737 | 2,342 (41%) | **2,243 (45%)** |
| New email, under threshold | 42,573 | 50,265 | 38,347 (76%) | 4,763 (11%) |
| L3: linked variant cluster of 2–4 | 460 | 685 | 443 | 4 |
| L3: linked variant cluster of 5+ | 163 (15 stems) | 232 | 138 | 0 |

**Truth check** (Athena, 23 Oct):

| Group | Emails | Reported fraud |
| --- | --- | --- |
| Email with 7+ sessions in 00–12 UTC (L1 proxy) | 104 | 2 (1.9%) |
| Email with 2–6 sessions | 2,148 | 77 (3.6%) |
| Email with a single session | 18,710 | 1,727 (9.2%) |
| L3 clusters of 5+ (full day) | 232 sessions | 1 (0.4%) |

**Reading:**
- On this key the fraud is one session per unique, unlinked email.
- Layers 1–2 catch retry loops: one email, many sessions, low fraud.
- Layer 3 finds small groups of linked variants that are not in Blizzard's fraud labels.
- None of the three layers recovers the wave.
- The one lead is "known" emails, those already seen on Key 2 earlier in the week: 45% are in rule C against 11% of new emails. That group needs a truth check with an email-history join.

## 10. Cross-platform device anchor applied to the October wave (23 Oct 00:00–03:00 UTC)

Rules from [Detection Idea: Cross-Platform Device Identity Signal](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4683071547). The anchor is `fp_canvas_fp + audio_fingerprint + cdn__ja4_hash + di__challenger_matched_signature + webgl_hash_webgl + init_window_hash`. Data is from `arkoselabs.events_faster` at session setup, joined to Blizzard truth.

**Window:** 6,811 sessions, 449 of them reported fraud (6.6%). 6,600 sessions carry all six anchor fields, including all 449 fraud sessions. Those 6,600 sessions fall into 5,789 distinct anchors, so the anchor is close to unique per session.

| Rule | Sessions flagged | Reported fraud |
| --- | --- | --- |
| Anchor session velocity, 10+ in the window | 187 | **0** |
| Email dimension MEDIUM (6–14 emails per anchor) | 142 | **0** |
| Email dimension HIGH (15–24) | 0 | 0 |
| Email dimension CRITICAL (25+) | 39 | **0** |
| Low-entropy key `init_window_hash + JA4`, 6–24 emails | 1,390 | 105 (7.6%) |
| Low-entropy key, 25–99 emails | 2,212 | 155 (7.0%) |
| Low-entropy key, 100+ emails | 1,665 | 142 (8.5%) |

**Reading:**
- The October wave uses a fresh device profile per session, so the six-field anchor never repeats and none of the anchor rules catch any of it. This matches `never-seen-before-fp-no-pressure` firing on 74–92% of the wave.
- The low-entropy fallback key does group the fraud, but only at 1.1–1.3× the base rate, because the common browser builds dominate it.
- The anchor rules flag a different population: 18 anchors at MEDIUM or above in 3 hours, none of them labelled as fraud. That's consistent with the August finding that CRITICAL is unchallenged and unlabelled.
- The anchor rules are complementary to rule C and the dict ≥ 7 split, not a replacement for them on this wave.

## 11. Missed attack by free-email domain, 5 Nov 2026 00:00–06:00 UTC

- **Data:** `arkoselabs.events_faster`, flags at session setup, verified = `verified` true at `game_verify`, joined to Blizzard truth.
- **Window:** 39,311 created registrations, 33,104 verified, 544 reported fraud. All 544 verified, and Blizzard has reported no Legit sessions.
- **Scope:** one 6-hour window, so treat the numbers as directional.

### By domain family

| Family | Created | Reported fraud (rate) | Verified | Email ML ≥ 80 | Email-plus flag (fraud) | SDV ratio ≥ 1 (fraud) |
| --- | --- | --- | --- | --- | --- | --- |
| gmail | 23,737 | 131 (0.55%) | 93% | 1,805 | 368 (0) | 422 (5) |
| hotmail / outlook / live | 8,153 | **358 (4.4%)** | 64% | 848 | 284 (16) | 145 (20) |
| other / corporate | 2,212 | 24 | 78% | 296 | 138 (1) | 92 (0) |
| yahoo | 1,436 | 4 | 94% | 17 | 1 | 22 |
| **naver / daum / hanmail (KR)** | 1,356 | **0** | 87% | **941 (69%)** | 130 (0) | 31 |
| no email | 604 | 0 | 4% | 0 | 0 | 521 |
| qq / foxmail | 318 | 11 (3.5%) | 96% | 0 | 0 | 18 |
| 163 / 126 / sina | 257 | 7 (2.7%) | 79% | 16 | 11 (1) | 0 |

### Findings

- **Hotmail/Outlook is where the reported fraud is**: 66% of truth at 8× Gmail's rate. Its attack profile (`never-seen-before-fp-no-pressure` + `g-suspicious-extension-count-ja4-hash` + dict 7/15) covers 1,877 sessions and 171 of the 358 truth sessions (48%), at a 9.1% fraud rate. Of the profile, 1,250 sessions were mitigated and **456 verified without being in truth**, which is likely unreported attack.
- **Gmail fraud has two shapes that the Hotmail profile does not cover** (only 5 of 131 match it):
  - **G1:** datacenter or hosting IP plus a country/timezone mismatch. 632 sessions, 3.0% fraud, 80% verified.
  - **G2:** Battle.net launcher + `client-hints-pure-chromium` + fraud-farm or sweatshop country. 497 sessions, 5.4% fraud (10× the Gmail base), **92% verified**. Mostly getting through.
  - G1 or G2 together: 1,121 sessions, 45 of 131 Gmail truth (34%), 908 verified and not in truth.
- **`blizzard2-e-email-plus-suspicion-flag` is weak on this key:** 937 sessions, 18 truth (1.9%, 1.4× base), 69% verified, and 0 truth on its 368 Gmail hits. Its email ML ≥ 80 gate over-fires on Korean domains, which are 130 of its hits.
- **Korean free mail is very likely legitimate, not a missed attack:**
  - 98% of these sessions are in Korea and 77% are on mobile.
  - Fingerprints repeat (571 across 1,356 sessions), and only 3.5% are never-seen-before.
  - Dict matched is mostly 31 or more, and residential proxies are almost absent (2 sessions).
  - The email ML score is median 86 here against 41 for Gmail. That's a model bias on Korean handles, and anything gated on ML ≥ 80 inherits it.
- **Chinese domains (qq, 163, 126, sina) are low volume but 5–6× Gmail's fraud rate.** None match the Hotmail profile, and 4 of qq's 11 truth sessions had no telltale. Too few in one window to build a rule.
- **Spoofing flags** (device-parameter, client-hints platform, `efp-bad-fos`, OS spoofing, SwiftShader, headless VM, webdriver): on Hotmail, 317 sessions, 49 truth (15%), 102 verified and not in truth. On "other", 575 sessions with 7 verified, so already stopped.
- **SDV:** the gate (ratio ≥ 1) is mostly no-email API traffic that is already stopped (521 sessions, 23 verified). On Hotmail it is 145 sessions at 14% fraud. Volume is small, consistent with the SDV page (ratio ≥ 4 catches 3.4% of Blizzard truth).

## 12. Hotmail/Outlook attack, full week 4–10 Nov 2026 (Registration K2)

Method: Athena in 12h chunks, with 10 Nov 00–12 UTC split into two 6h chunks because the 12h query exhausted Athena resources. Flags and email fields come from `session_setup`. Verified means `verified` is true at `game_verify`. The domain test is `email__raw_email_domain` matching hotmail, outlook, live or msn.

All 4–10 Nov is covered. Truth for 10 Nov is still sparse (856 sessions against 1.6–5.2k on other days), so treat 10 Nov as a lower bound. Per-chunk data: `full_week.csv` in the scratchpad (one row per chunk).

### 12.1 Scale

| | Sessions |
|---|---:|
| Created on the key | 714,841 |
| Verified | 463,059 |
| Truth (Nonlegit) | 21,337 |
| Hotmail-family created | 173,533 |
| Hotmail-family truth | **16,271 (76% of all truth)** |

### 12.2 Do the names look legitimate? Yes, by design

`email__handle_pattern` is a 10-digit code: `LL AA DD SS 00`, meaning length, letters, digits and specials. Separators (`.` and `_`) are not counted, so `first.last99` and `firstlast99` get the same code.

- **83% of Hotmail truth has `di_dictionary_num_matched` ≥ 7** (13,448 of 16,271). The handles are built from dictionary words and real names, not random strings.
- The attacker **rotates a handle template per wave**. Each template gets its own distinctive code and is gone within hours:

| Wave | Template (handle_pattern) | Example shape | Truth | Verified, not truth | Unverified, not truth |
|---|---|---|---:|---:|---:|
| F1: 4 Nov 00–12 UTC | 15–24 letters + **exactly 1 digit** (`1918010000`, `2019010000`, …) | `aaaaaaaaaaaaaaaaaa9` | 894 for the week, 812 of them in this window | 189 | 376 |
| F2: 4 Nov 12 – 6 Nov 12 UTC | 5+ letters + **8–10 digits** (`1707100000`, `2012080000`, …) | `aaaaaaa9999999999` | 956 | 423 | 610 |
| 9 Nov | 15–20 letters, **0 digits** (`1515000000` … `2020000000`), plus letters + 4 digits | `aaaaaaaaaaaaaaaaa` | covered by LONG, see 12.4 | | |

Across the full week, F1 plus F2 on Hotmail caught 1,850 truth sessions (11% of Hotmail truth) at **75% precision among verified sessions**. Outside its own wave each template is close to zero: from 6 Nov 12:00 to 10 Nov, F1 plus F2 caught 20 truth sessions in total. A static template rule only works for the wave it was built on.

### 12.3 IP Intelligence Phase 1 flags (live, risk 0)

Hotmail truth, 4–10 Nov (16,271 sessions):

| Flag | Truth hits | Note |
|---|---:|---|
| 2d `g-ip-datacenter` | 743 (4.6%) | always co-fires with 2f |
| 2f `g-ip-datacenter-with-fingerprint` | 743 (4.6%) | Group B, context only |
| Group A/C abuse (2a/2b/2c/2e/2i/4/4b/5) | **21 (0.1%)** | 440 hits on non-truth Hotmail, so no separation |
| 2j/2l no-IP-data | 0 | |
| Residential proxy (`g-ip-residential-proxy-*`) | 2,994 (18%) | |
| `never-seen-before-fp-no-pressure` | 4,016 (25%) | |

The attack mostly runs on residential or clean IPs. Datacenter accounts for about 5% of it, and the new abuse flags are effectively absent.

### 12.4 Combinations tested

**LONG + dict, full week, per 12h chunk** (Hotmail AND letters ≥ 15 AND digits ∈ {0, 1, ≥ 8} AND specials = 0 AND dict ≥ 7):

| Chunk (UTC) | Hotmail truth | Truth caught | Verified, not truth | Unverified, not truth |
|---|---:|---:|---:|---:|
| 4 Nov 00 | 1,713 | 911 | 263 | 769 |
| 4 Nov 12 | 1,732 | 166 | 318 | 49 |
| 5 Nov 00 | 1,599 | 62 | 493 | 213 |
| 5 Nov 12 | 2,691 | 336 | 326 | 251 |
| 6 Nov 00 | 993 | 358 | 436 | 354 |
| 6 Nov 12 | 1,538 | 245 | 216 | 577 |
| 7 Nov 00 | 668 | 311 | 133 | 243 |
| 7 Nov 12 | 924 | 81 | 202 | 953 |
| 8 Nov 00 | 486 | 193 | 141 | 260 |
| 8 Nov 12 | 456 | 80 | 211 | 174 |
| 9 Nov 00 | 1,431 | 431 | 98 | 818 |
| 9 Nov 12 | 1,673 | 502 | 113 | 256 |
| 10 Nov (00–24, sparse truth) | 367 | 13 | 236 | 293 |
| **Week** | **16,271** | **3,689 (23%)** | **3,186** | **5,210** |

Week totals: the rule fires on 12,085 sessions (1.7% of created). Precision among verified sessions is **54%**, ranging from 11% (5 Nov 00) to 82% (9 Nov 00).

**Other combinations** (one 12h chunk each, Hotmail only):

| Rule | Chunk | Truth | Verified, not truth |
|---|---|---:|---:|
| `never-seen-before-fp-no-pressure` AND dict ≥ 7 | 4 Nov 00 | 182 | 985 |
| (same) | 5 Nov 00 | 769 | 1,584 |
| residential proxy AND dict ≥ 7 (not nsb / F1 / F2) | 4–7 Nov | 865 | 1,842 |
| LONG AND dict ≥ 7 AND (rp OR nsb OR datacenter) | 9 Nov 12 | 73 | 39 |
| LONG AND dict ≥ 7, **all domains** | 9 Nov 12 | 515 | 1,878 |

Takeaways:
- Device and IP conditions on Hotmail hit 2–3× more verified non-truth than truth.
- The handle shape is the strongest field for this attack. As a static rule it gives 23% recall at 54% verified precision for the week.
- Adding device or IP flags removes most of the recall.
- Widening the rule past Hotmail floods it with legitimate traffic.

### 12.5 Recommendation

1. **Custom TT, wave-adaptive (preferred).** Hotmail-family domain AND `email__handle_pattern` ∈ a *hot-pattern list*: patterns whose Registration-K2 share in the last 1–6h is far above the trailing 7-day baseline, for example ≥ 5× and ≥ 30 per hour. This targets F1, F2 and the 9 Nov template without per-wave tuning; F1/F2 alone ran at about 75% precision during their waves. `email__short_term__handle_pattern_count` may already supply the velocity, but it has not been validated, so check it against the baseline first.
2. **Static fallback TT, run at risk 0 first.** The LONG + dict rule above: 23% of Hotmail truth over the week, 54% verified precision, and 1.7% of created sessions flagged. It is too noisy to block on alone. Use it as a step-up or score contributor, or combine it with the hot-pattern list.
3. **Don't build on the IP Phase 1 abuse flags for this attack.** They hit 21 truth sessions in 7 days. Keep 2d/2f as context only, as the SOC guide says.
4. **Keep all of these scoped to the Hotmail family.** The same templates are common in legitimate traffic on other free-mail domains.

Queries: `queries/blizzard_hotmail_handle_pattern.sql`.

### 12.6 Pattern-velocity fields with the datacenter flags

**The fields:**
- `email__short_term__handle_pattern_count` (hpc): requests on the key with the same handle pattern in the last 6h.
- `email__handle_pattern_relative_usage_factor` (ruf): short-term usage of the pattern relative to its long-term usage. The data dictionary text describes domain usage, which looks copy-pasted. The observed values are centred near 1: on 4 Nov 00–06, verified non-truth Hotmail has median 1.4 and p90 4.1, against truth median 3.1, p75 19 and p90 128.
- 2d `g-ip-datacenter` and 2f `g-ip-datacenter-with-fingerprint` were identical on every Hotmail session tested.

**Tests**, Hotmail only unless noted, 6h windows (truth / verified, not truth / unverified, not truth):

| Rule | 4 Nov 00 (F1 wave) | 5 Nov 12 (F2 wave) | 7 Nov 12 (quiet) | 9 Nov 12 |
|---|---|---|---|---|
| Hotmail truth in window | 1,408 | 1,885 | 757 | 1,578 |
| ruf ≥ 5 | 473 / 98 / 161 | 90 / 345 / 426 | 17 / 230 / 2,661 | 42 / 158 / 189 |
| **ruf ≥ 10 AND hpc ≥ 20** | **350 / 28 / 57** | 20 / 34 / 154 | 3 / 33 / **1,630** | 0 / 1 / 43 |
| same rule, all domains | 350 / 28 / 57 | 21 / 34 / 155 | 3 / 33 / 1,630 | 0 / 3 / 43 |
| datacenter (2d = 2f) | 20 / 49 / 90 | 29 / 84 / 44 | **124 / 37 / 213** | 24 / 45 / 43 |
| datacenter AND ruf ≥ 3 | 4 / 10 / 4 | 1 / 33 / 13 | 8 / 11 / 97 | 2 / 17 / 26 |

**Reading:**
- **Burst rule (ruf ≥ 10 AND hpc ≥ 20):**
  - Precision 93% among verified sessions in the F1 wave. It catches 25% of that window's Hotmail truth.
  - It adds at most about 34 verified non-truth per 6h.
  - On quiet 7 Nov it fired on 1,630 unverified sessions, a burst that was already mitigated (so not in truth). That is consistent with it marking attack traffic.
  - It did **not** catch the F2 (8–10 digit) or 9 Nov (letters-only) templates. Those patterns are already common, so their ratio never spikes.
  - All-domain numbers equal Hotmail-only ones, so these bursts live on Hotmail.
- **Datacenter is a separate sub-campaign.**
  - It overlaps almost nothing with the burst rule (1–8 truth sessions per window).
  - Precision is 77% on 7 Nov 12, but only 26–33% on other windows.
- **Use them as OR'd signals, not AND'd.** Datacenter AND burst is near-empty.

**Suggested TTs (start at risk 0):**
1. `TT-hotmail-pattern-burst`: Hotmail family AND ruf ≥ 10 AND hpc ≥ 20. It is high-precision but only catches waves whose template is new.
2. `TT-hotmail-datacenter`: Hotmail family AND `g-ip-datacenter-with-fingerprint` AND dict ≥ 7. Treat it as a contributor, not a blocker, because 2d/2f are Group B context flags per the SOC guide. Dict ≥ 7 is untested here and should be validated.
3. Score the two TTs additively with the LONG handle-shape rule from 12.4. Each one covers a different slice of the attack.

#### 12.6.1 Full-week results (4–10 Nov, Hotmail family, 12h chunks; 10 Nov 00–12 run as 6h)

Each cell is truth / verified not truth / unverified not truth.
- **Burst** = ruf ≥ 10 AND hpc ≥ 20.
- **DC** = `g-ip-datacenter-with-fingerprint`.
- **DC + dict** = DC AND dict ≥ 7.
- **Union** = Burst OR (DC AND dict ≥ 7) OR (LONG handle AND dict ≥ 7).

| Chunk (UTC) | Hotmail truth | Burst | DC | DC + dict | Union |
|---|---:|---|---|---|---|
| 4 Nov 00 | 1,713 | **374 / 100 / 290** | 82 / 205 / 539 | 80 / 181 / 361 | 980 / 460 / 900 |
| 4 Nov 12 | 1,732 | 4 / 9 / 6 | 27 / 179 / 252 | 24 / 156 / 51 | 191 / 475 / 105 |
| 5 Nov 00 | 1,599 | 8 / 16 / 134 | 29 / 179 / 97 | 22 / 136 / 32 | 89 / 622 / 354 |
| 5 Nov 12 | 2,691 | 20 / 34 / 154 | 55 / 132 / 75 | 42 / 116 / 44 | 378 / 457 / 443 |
| 6 Nov 00 | 993 | 66 / 24 / 66 | 45 / 196 / 139 | 41 / 176 / 130 | 379 / 535 / 420 |
| 6 Nov 12 | 1,538 | 33 / 25 / 913 | **138 / 87 / 244** | 87 / 73 / 102 | 325 / 312 / 1,498 |
| 7 Nov 00 | 668 | 2 / 0 / 5 | **118 / 93 / 119** | 114 / 87 / 106 | 350 / 212 / 305 |
| 7 Nov 12 | 924 | 3 / 37 / 1,637 | **124 / 63 / 224** | 120 / 55 / 180 | 189 / 284 / 2,218 |
| 8 Nov 00 | 486 | 0 / 0 / 38 | 9 / 130 / 22 | 7 / 87 / 17 | 197 / 217 / 311 |
| 8 Nov 12 | 456 | 0 / 0 / 5 | 4 / 53 / 10 | 4 / 50 / 5 | 84 / 257 / 183 |
| 9 Nov 00 | 1,431 | 0 / 1 / 7 | 4 / 87 / 80 | 4 / 73 / 53 | 434 / 171 / 870 |
| 9 Nov 12 | 1,673 | 0 / 1 / 44 | 69 / 81 / 65 | 63 / 58 / 47 | 555 / 169 / 317 |
| 10 Nov (sparse truth) | 367 | 0 / 0 / 0 | 39 / 223 / 61 | 36 / 201 / 52 | 44 / 427 / 335 |
| **Week** | **16,271** | **510 / 247 / 3,299** | **743 / 1,708 / 1,927** | **644 / 1,449 / 1,180** | **4,195 / 4,598 / 8,259** |

**Week summary:**

| Rule | Recall (Hotmail truth) | Verified precision | Fires (% of created) |
|---|---:|---:|---:|
| Burst | 3.1% | 67% | 4,056 (0.57%) |
| DC | 4.6% | 30% | 4,378 (0.61%) |
| DC + dict ≥ 7 | 4.0% | 31% | 3,273 (0.46%) |
| LONG + dict ≥ 7 (from 12.4) | 22.7% | 54% | 12,085 (1.7%) |
| Union of all three | 25.8% | 48% | 17,052 (2.4%) |

**Reading:**
- **Burst is a one-wave detector.**
  - 73% of its week's truth (374 of 510) came from the 4 Nov 00–12 F1 wave. After 6 Nov it caught almost no truth.
  - 77% of its 3,299 unverified hits fell on 6 Nov 12 – 7 Nov 24, a burst that was already being mitigated.
  - It is cheap: 247 verified non-truth all week. It is worth keeping as a low-cost early-warning TT.
- **Datacenter is only useful for a 36-hour window** (6 Nov 12 – 7 Nov 24): 380 truth against 243 verified non-truth, 61% precision. Across the rest of the week it is mostly legitimate traffic (30% precision for the week). Adding dict ≥ 7 does not help.
- **The union adds little over LONG alone.** It adds 506 truth and 1,412 verified non-truth, so the added slice is about 26% precise. LONG carries most of the value. Burst and DC are contributors at best.

**Revised recommendation:**
- Ship LONG + dict as the main TT, at risk 0 first.
- Add Burst as a small extra score bump. It is cheap and catches new-template waves early.
- **Do not** add a datacenter TT for this attack. 2d/2f stay context-only, consistent with the SOC guide.

### 12.7 TT definitions

Use two separate TTs, not one combined TT, and no datacenter TT. Both definitions are in `telltales/blizzard2-hotmail-tts.json` and both passed Dataswan `validate_telltale`. Neither has been created yet.

- **`blizzard2-h-hotmail-long-handle-dict`** (primary)
  - Conditions: K2 public key AND `session_setup` AND domain regex `^(hotmail|outlook|live|msn)\.` AND `email__handle_pattern` regex `^[0-9]{2}(1[5-9]|[2-9][0-9])(0[01]|0[89]|[1-9][0-9])0000$` AND `di_dictionary_num_matched` ≥ 7.
  - The regex matches exactly the same sessions as the Athena logic used in 12.4: 871 = 871 on 9 Nov 12–24, with no differences either way.
- **`blizzard2-h-hotmail-handle-pattern-burst`** (secondary)
  - Conditions: K2 public key AND `session_setup` AND the same domain regex AND `email__handle_pattern_relative_usage_factor` ≥ 10 AND `email__short_term__handle_pattern_count` ≥ 20.

Why two TTs: they have different precision (54% and 67%) and different lifetimes. LONG covers steady state; Burst is a short early warning for new templates. Separate TTs can each get their own risk weight, degrade separately, and be measured separately. A combined TT would hide which signal fired. Start both as risk-0 suspicion flags, then score them after a week of monitoring.

### 12.8 Backtest outside the training week (one 12h window per day, 12–24 UTC, Hotmail family)

Each cell is truth / verified not truth / unverified not truth.

| Day | Hotmail truth | LONG + dict (TT 1) | Burst (TT 2) |
|---|---:|---|---|
| 12 Aug | 0 (no truth that day) | 0 / 180 / 60 | 0 / 25 / 21 |
| 26 Aug | 1,230 | 4 / 66 / 5 | **50 / 16 / 50** |
| 14 Oct | 652 | 24 / 177 / 147 | 1 / 0 / 12 |
| 23 Oct | 2,419 | 62 / 255 / 93 | 0 / 0 / 0 |
| 11 Nov | 180 | 10 / 142 / 147 | 0 / 0 / 0 |
| 12 Nov | 1,492 | 20 / 117 / 201 | **145 / 7 / 608** |
| 13 Nov | 553 | 42 / 263 / 68 | 0 / 0 / 0 |
| 14 Nov | 636 | 9 / 184 / 43 | 2 / 2 / 25 |
| 15 Nov | 0 (truth not in yet) | 0 / 377 / 55 | 0 / 7 / 38 |
| 16 Nov | 0 (truth not in yet) | 0 / 282 / 80 | 0 / 159 / 585 |

**TT 1 (LONG + dict) only fits the 4–9 Nov templates.**
- Outside that window it catches 0–6% of Hotmail truth, with 4–26% verified precision.
- Its standing cost is about 120–380 verified non-truth sessions per 12h.
- Keep it at risk 0, or let it degrade. Do not score it.

**TT 2 (Burst) generalises.**
- It caught the 26 Aug wave (76% verified precision) and the 12 Nov wave (95%).
- On non-wave days it stays near zero.

**16 Nov 12–24 (no truth yet):** Burst fired 744 times.
- **Template A:** 12:00–14:00 UTC, a new template of 15–22 letters + **5 digits** (`1611050000`, `1510050000`, `2015050000`, …), median dict 3, roughly 450 sessions. Almost none verified (about 6), so it was already mitigated. Burst flagged it within the hour.
- **Template B:** the rest, about 160 verified, came from common shapes (letters + 2–4 digits, dict 7). Confirm these against truth when it lands.

**Attack status:**
- Hotmail truth per 12h window was about 1,500–2,700 on 4–9 Nov. On 11–14 Nov it was 180–1,500.
- So the attack has slowed but not stopped.
- It keeps rotating templates (5-digit handles on 16 Nov). That is exactly why the static rule decays and the burst rule holds up.
