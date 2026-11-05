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
