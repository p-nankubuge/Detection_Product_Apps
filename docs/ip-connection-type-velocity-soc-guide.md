# IP Connection-Type Velocity — SOC Implementation & Support Guide

**Status:** DRAFT for SOC enablement · **Author:** Patricia Nankubuge · **Data as of:** 14–15 Oct 2026
**Companion to:** [Residential Proxy IP — SOC Implementation & Support Guide](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4707778564)

> Items marked **VERIFY** could not be confirmed from Dataswan, Superset or Confluence.
> Items marked **DECISION** need an owner's call before go-live.

**Purpose:** This guide explains how SOC should interpret, support and operationalise the IP
connection-type (CT) velocity telltales. It covers why we moved to per-connection-type thresholds,
the data and fields behind them, the global telltale catalogue, which keys have CT thresholds (and
why some don't), and how the new telltales relate to the existing `g-ip-velocity-*` telltales.

---

# Overview

IP velocity used to apply **one threshold per key to every IP**. Shared infrastructure (mobile
carrier CGNAT, corporate NAT, satellite, university and public Wi-Fi) legitimately sends many
sessions from one IP. A single threshold had two bad options:

- set it low, and real users behind shared IPs get flagged (false positives); or
- raise it until those users pass, and abuse from residential or wired IPs gets through.

With connection-type thresholding, each key gets **a separate short-term and long-term threshold
for each connection type** (`wifi`, `wired`, `mobile`, `nat`, `satellite`, `dialup`). The thresholds
are learned automatically from that key's own traffic. A mobile IP is compared with that key's
mobile baseline, and a wired IP with its wired baseline.

**For SOC, this means:** when you investigate an IP velocity flag, check the session's
`connection_type` and whether a CT threshold applied to that session.

---

# Why we moved to connection-type thresholds

Sources: [Proposal: IP Velocity Auto-Thresholding Improvements](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4259348630),
[Per-Connection-Type IP Velocity Thresholds Implementation Overview](https://arkoselabs.atlassian.net/wiki/spaces/EN/pages/4320722948),
and the SOC enablement thread in #C0BHGFL23C3 (2 Oct 2026).

1. **A steady stream of false-positive tickets and manual overrides.** For about 3 months, SOC kept
   raising IP velocity thresholds by hand. These are the main cases:

   | Customer | Ticket(s) | What happened |
   | --- | --- | --- |
   | HP | ESM-5858, CHNGE-4419/4516 | Auto threshold of 45/hr was too low. It was raised twice, then switched to manual. |
   | Wells Fargo | ESM-6148, CHNGE-4465, ESM-5892, ESM-6544 | Thresholds changed day to day, and the customer wanted stable, controllable values. Switched to manual at 25/hr and 150/day. |
   | Roblox | ESM-6296, CHNGE-4749/4760 | South-East Asian mobile carriers (Viettel, FPT, VNPT) showed high but legitimate velocity. Login raised to 550/hr and 1500/day. |
   | AT&T | ESM-6297, CHNGE-4750 | Normal traffic of about 60/hr and 150/day was being caught. |
   | Coursera | ESM-6291, CHNGE-4772 | A 15/hr threshold was too aggressive during a promotion. |
   | Bumble, Agoda | ESM-6360, ESM-5631 | FPs on the IP velocity short-term and long-term telltales. |

2. **The root cause was connection-type blindness.** The auto-thresholder treated every IP the
   same, so one number had to fit residential, CGNAT, corporate NAT and hosting traffic. The Roblox
   login analysis showed this most clearly. SE Asian mobile carriers had device diversity of
   0.62–0.64 at 275–1100/hr, which is consistent with real users. The threshold where traffic
   started to look suspicious was far above the auto-set value.
3. **The manual connection-type telltales were a stopgap.** Under CHNGE-5096 we built static CT
   telltales by hand on AT&T, Air Canada, Anthropic, Base App, Bumble, Citizens, Coinbase, Coursera,
   GroupMe, HP, HelloSign, Roblox, TIAA and Wells Fargo. They don't adapt to changes in traffic. The
   built-in CT thresholds replace them; see the caveat in the
   [Relationship to the existing IP velocity telltales](#relationship-to-the-existing-ip-velocity-telltales)
   section.
4. **Other fixes in the same proposal.** These are separate from the CT work:
   - fix the "valley bug" in the circadian threshold picker (DETCORE-3854);
   - switch from an exponential to a Pareto-style tail model;
   - add scheduled overrides for customer promotions.

   Connection type was the change that addressed the shared-egress FPs.

---

# Data Sources, Refresh, and Trust

| Area | SOC reference | Operational implication |
| --- | --- | --- |
| **Velocity counting** | RTA counts every request in two places: an `{ip}` bucket (unchanged) and a new `{ip, connection_type}` bucket. Sessions with no connection type go into an `absent` bucket. | A CT count only includes that IP's traffic **on that connection type**, so it can be lower than the IP-only count for the same IP. |
| **Connection type** | Comes from IP Intelligence (`connection_type`). Values: `wifi`, `wired`, `mobile`, `nat`, `satellite`, `dialup`, `absent`. | CT quality depends on the IP-intel classification. A mis-typed IP is compared with the wrong baseline. |
| **Thresholds** | The detection-apps `automated-thresholds` cron runs daily at **16:00 UTC**. It runs the same circadian model as the global IP threshold, once per (key, CT), over 7 days of `session_setup` data. It writes `{ct: {short_term: T, long_term: 96·T}}` to conf-api → DynamoDB. | Thresholds can change daily. conf-api **replaces the whole map** on each write, so a CT that drops out of a run falls back to the IP-only threshold the next day. |
| **Fallback** | If a (key, CT) pair has too little traffic, or the learned value is ≤ 10, no CT threshold is written. | The CT ratio and threshold fields are **empty** for those sessions, so the CT telltales cannot fire. Only the legacy IP-only telltales cover that traffic. |
| **Trust level** | A strong velocity signal that is more precise than IP-only for shared-egress traffic. Like any velocity signal, it should be combined with other signals before hard enforcement. | Use multiplier tiers (1.5x / 2x / 3x) to pick severity. See [Recommended SOC Usage](#recommended-soc-usage). |

> **VERIFY:** the per-CT long-term threshold is written as `96 × short-term`. The global IP
> long-term threshold is `5 × short-term`. If that is intended, CT long-term thresholds are much
> looser relative to short-term than the legacy long-term thresholds. Confirm with Detection
> Engineering before SOC sets pressure on the CT long-term telltales.

---

# Available Fields

| Field (Snowflake `events.events_log` / telltale key) | Meaning | Populated when |
| --- | --- | --- |
| `connection_type` | IP Intelligence connection type of the session IP | IP-intel lookup succeeded |
| `rta__ip_connection_type_velocity_short_term_count` | Sessions from this IP **on this CT** in the short window (~40 min) | Always |
| `rta__ip_connection_type_velocity_long_term_count` | Same, for the long window (~48 h) | Always |
| `rta__ip_connection_type_velocity_short_term_threshold` | The key's CT short-term threshold applied to this session | **Only when a CT threshold exists for this key + CT** |
| `rta__ip_connection_type_velocity_long_term_threshold` | The key's CT long-term threshold | Same as above |
| `rta__ip_connection_type_velocity_short_term_ratio` | `count ÷ threshold` (short-term). Above 1.0 means over threshold. **The multiplier telltales evaluate this field.** | Same as above |
| `rta__ip_connection_type_velocity_long_term_ratio` | Same, for the long term | Same as above |
| `rta_ip_velocity_*` (count / threshold / ratio) | Legacy IP-only velocity. **Unchanged.** | As before |

**Quick test for any session:** if `rta__ip_connection_type_velocity_short_term_threshold` is
populated, a CT threshold applied and the CT telltales could fire. If it is empty, only the legacy
`g-ip-velocity-*` telltales can fire on that session.

---

# Global Telltale Catalogue

All of these share the same base:
- they are scoped to `GLOBAL`;
- they only evaluate at `location IN (session_setup, game_verify)`;
- they include `g-global-telltales-enabled`, so keys opted out of globals are skipped;
- they are tracked in DETCORE-4293 (1x base) and DETCORE-4371 (multipliers and context variants);
- **they currently have risk score 0, so they carry no pressure until it is set.**

Telltale pages are in the THRE space (THR-1173, status *Proposed*).

## Short-term — base (1x)

Fires when `count > CT threshold` for that connection type.

| Telltale | Type in Dataswan |
| --- | --- |
| `g-ip-connection-type-velocity-short-term-abuse-wifi` | telltale |
| `g-ip-connection-type-velocity-short-term-abuse-wired` | telltale |
| `g-ip-connection-type-velocity-short-term-abuse-mobile` | telltale |
| `g-ip-connection-type-velocity-short-term-abuse-nat` | telltale |
| `g-ip-connection-type-velocity-short-term-abuse-satellite` | telltale |
| *(no dialup base)* | — |

## Short-term — multiplier tiers

Fires when `rta__ip_connection_type_velocity_short_term_ratio > N`.

| CT | 1.5x | 2x | 3x |
| --- | --- | --- | --- |
| wifi | `...-wifi-15x` **(suspicion flag)** | `...-wifi-2x` | `...-wifi-3x` |
| wired | `...-wired-1point5x` | `...-wired-2x` | `...-wired-3x` |
| mobile | `...-mobile-1point5x` | `...-mobile-2x` | `...-mobile-3x` |
| nat | `...-nat-1point5` | `...-nat-2x` | `...-nat-3x` |
| satellite | `...-satellite-1point5x` | `...-satellite-2x` | `...-satellite-3x` |
| dialup | `...-dialup-1point5` | `...-dialup-2x` | `...-dialup-3x` **(suspicion flag)** |

`...` = `g-ip-connection-type-velocity-short-term-abuse`. Names are listed **exactly as they are in
Dataswan**. Note `mobile-1point5x` (not `mobile-1.5x` as posted in Slack), `nat-1point5` and
`dialup-1point5` (no trailing `x`), and `wifi-15x`.

> **Tiers are not banded.** Each tier checks `ratio > N` with no upper bound, so a session at 3.5x
> fires the 1.5x, 2x **and** 3x telltales. The legacy `g-ip-velocity-*` telltales are banded (1–2x,
> 2–4x, >4x). When you set pressure, either give pressure to one tier only, or expect the pressure
> to stack. **DECISION:** keep these as stacking thresholds or band them like the legacy set.

## Long-term

Fires when `long-term count > CT long-term threshold`.

| Telltale | Type in Dataswan |
| --- | --- |
| `g-ip-connection-type-velocity-long-term-abuse-wifi` | telltale |
| `g-ip-connection-type-velocity-long-term-abuse-mobile` | telltale |
| `g-ip-connection-type-velocity-long-term-abuse-nat` | telltale |
| `g-ip-connection-type-velocity-long-term-abuse-satellite` | telltale |
| `g-ip-connection-type-velocity-long-term-abuse-wired` | **suspicion flag**, and it is missing the `g-global-telltales-enabled` include |
| *(no dialup long-term; no long-term multiplier tiers yet)* | — |

This answers the question in #C0BHGFL23C3 on 15 Oct: long-term exists at 1x only, and it was
built after the short-term set.

## Context suspicion flags (DETCORE-4371, created 14 Oct)

These are not promoted to telltales yet. They are useful as investigation aids.

| Suspicion flag | Logic |
| --- | --- |
| `...-short-term-abuse-{wifi,wired,mobile,nat,satellite}-sf-shared-egress-carveout` | Over the CT threshold. If `vpn_proxy_type` is `consumer-privacy`, `corporate`, `edu` or `public`, it only fires above 3x. This is the proposed FP-safer base. |
| `...-short-term-abuse-harvested-proxy` | `ip_intel__is_proxy_harvested` and ratio > 0.5 on the CT ratio, **or** on the IP-only short-term or long-term ratio as a fallback. |
| `...-short-term-abuse-hosting` | DE `hosting` (excluding vpn, cloud-security and web-browser) and ratio > 0.5, with the same fallback. |
| `...-short-term-abuse-hosting-vpn` | DE `hosting` + `vpn` and ratio > 0.5, with the same fallback. |
| `...-short-term-abuse-cloud-asn` | Google, AWS or Microsoft cloud ASN not typed by DE, and ratio > 0.5, with the same fallback. |
| `...-short-term-abuse-high-risk-asn` | ASN `risk_band = High` and ratio > 1.0, with the same fallback. |

The last five already show the **fallback pattern**: CT ratio if present, otherwise IP-only ratio.
This pattern matters for the legacy telltales. See the next section.

## Promotion clean-up still needed (for THR)

These three are still `suspicion_flags`, have no `g-global-telltales-enabled` include, and are
missing from the 8 Oct promotion list:
- `wifi-15x`
- `dialup-3x`
- `long-term-abuse-wired`

The 15 Oct Slack reply says THR still needs to promote them and correct some values.

---

# Which keys have connection-type thresholds

Method: Snowflake `events.events_log`, `location = session_setup`, 14 Oct 2026 (UTC). The table
covers keys with at least 5,000 sessions that day. A session counts as "covered" when
`rta__ip_connection_type_velocity_short_term_threshold` is populated. The query is in
[`queries/ip_ct_threshold_coverage.sql`](../queries/ip_ct_threshold_coverage.sql).

| Tier | Keys | Meaning |
| --- | --- | --- |
| **FULL** (≥ 90% of sessions covered) | 30 | The CT telltales cover almost all traffic. |
| **PARTIAL** (1–89%) | 39 | Only some connection types have a threshold. The rest fall back to IP-only. |
| **NONE** (0%) | 104 (incl. non-prod/QA) | No CT thresholds. Only the legacy IP-only telltales apply. |

## FULL coverage

| Account | Key | PK | Sessions (14 Oct) | Covered | CTs with threshold |
| --- | --- | --- | --- | --- | --- |
| Doordash | DoorDash - Website - Production - Key 1 | `DE24F792` | 4,754,925 | 100% | wifi, wired, mobile, nat, satellite |
| Wells Fargo | Wells Fargo - Prod/Detect - Login - Web - Key 1 | `9B8ED233` | 4,418,492 | 100% | wifi, wired, mobile, satellite |
| Meta | Meta - Login - Production - Key 2 | `2BF0FE95` | 3,191,456 | 100% | wifi, wired, mobile, nat, satellite, dialup |
| Pinterest | Pinterest - Login - Production - Key 1 | `F5675B21` | 2,965,917 | 100% | wifi, wired, mobile, nat, satellite |
| Adobe | Adobe - Sign-in - Production - Key 5 | `430FF2C3` | 2,479,901 | 98% | wifi, wired, mobile |
| AT&T | AT&T - Consumer Login Web - Production - Key 3 | `FAD1C7FA` | 1,633,260 | 98% | wifi, wired, mobile |
| Amazon | Amazon - IDS - Production - Key 2 | `56938EF5` | 1,070,748 | 99% | wifi, wired, mobile, satellite |
| Adobe | Adobe - Commerce - Production - Key 3 | `AD73B601` | 880,897 | 97% | wifi, wired, mobile |
| Chime | Chime - Production - Key 1 - Login | `7BA04117` | 876,615 | 99% | wifi, wired, mobile, satellite |
| Airbnb | Airbnb - Account Lookup - Production Key 6 | `513F48D7` | 635,683 | 96% | wifi, wired, mobile |
| Payoneer | Payoneer - Login - Prod - Key 2 | `EE844FC3` | 579,377 | 99% | wifi, wired, mobile, nat |
| Tinder | Tinder - Production - PreSMS - Key 3 | `B5B07C8C` | 502,881 | 99% | wifi, wired, mobile, nat |
| Expedia | EG - Production EPC - UPL - Key 13 | `A3FCC6D6` | 467,974 | 97% | wifi, wired, mobile |
| Chime | Chime - Production - Key 2 - Registration | `8F5905D7` | 411,530 | 98% | wifi, wired, mobile |
| Citizens | Citizens - Production (OLB) - Key 1 | `4455454D` | 387,732 | 99% | wifi, wired, mobile |
| Bumble | Bumble - SMS - Mobile - Production - Key 4 | `CC3F2AEA` | 368,820 | 96% | wifi, wired, mobile |
| Linktree | LinkTree - Sign In - Production - Key 1 | `07D6B751` | 275,219 | 95% | wifi, wired, mobile |
| Amazon CBCC | Amazon CBCC - Production - Detect - Key 2 | `2B5F1335` | 252,584 | 97% | wifi, wired, mobile |
| AT&T | AT&T - Consumer SDK iOS - Production - Key 5 | `9644DF13` | 235,380 | 98% | wifi, wired, mobile |
| Docusign | Docusign - Abuse and Signup - Production - Key 2 | `51975FD6` | 231,921 | 98% | wifi, wired, mobile |
| Coinbase | Coinbase - Sign In - Prod - Key 3 | `32FBE3BC` | 194,217 | 97% | wifi, wired, mobile |
| Rightmove | Rightmove - Production - Login - Key 1 | `91523F73` | 173,680 | 98% | wifi, wired, mobile |
| TIAA | TIAA - Login - Production Key 1 | `942A102E` | 133,764 | 91% | wifi, wired |
| Blizzard | Blizzard - Production - ROW Login - Key 5 | `CF5C61EE` | 131,968 | 98% | wifi, wired, mobile |
| Blizzard | Blizzard - Production - ROW Support Site - Key 3 | `9C3260E3` | 107,190 | 97% | wifi, wired, mobile |
| Bumble | Bumble - Social - Mobile - Production - Key 2 | `44C599E8` | 70,537 | 96% | wifi, wired, mobile |
| AT&T | AT&T - Cricket SDK iOS - Production - Key 11 | `6E0D1A00` | 54,958 | 98% | wifi, wired, mobile |
| AT&T | AT&T - BIAM-AM - Production - Key 14 | `5AA600D0` | 52,895 | 92% | wifi, wired |
| Microsoft | Group Me - Registration Production - Key 4 | `49D02870` | 44,486 | 90% | wifi, wired |
| TriNet | Zenefits - Login - Production - Key 1 | `FB46D6FD` | 18,432 | 91% | wifi, wired |

## PARTIAL coverage

These keys need the legacy IP telltales kept on.

| Account | Key | PK | Sessions (14 Oct) | Covered | CTs with threshold |
| --- | --- | --- | --- | --- | --- |
| Adobe | Adobe - ARP FF - Production - Key 8 | `BBCC314C` | 6,108,435 | 77% | wifi, mobile, nat, satellite (no wired) |
| Gtop100 | gtop100.com - Production | `FDED3FA5` | 1,177,144 | 19% | mobile |
| Adobe | Adobe - Sign Up - Production - Key 2 | `436DD567` | 1,004,698 | 11% | wifi |
| Uber | Uber - Account Management - Production - Key 2 | `1BE2475D` | 827,990 | 84% | wifi, wired, mobile, nat |
| Wells Fargo | WCA - Prod/Detect - Vantage Login - Web - Key 10 | `B81C9A69` | 703,344 | 29% | wired |
| Dropbox | Dropbox - Production - Login - Key 1 | `419899FA` | 427,217 | 37% | wired, mobile |
| Pinterest | Pinterest - Registration - Production - Key 2 | `F7C0768A` | 366,283 | 88% | wifi, wired, mobile |
| Air Canada | Air Canada - Login - Production - Key 1 | `8BAAFE0D` | 202,288 | 84% | wifi, wired |
| Airbnb | Airbnb - Phone number OTP - Production Key 5 | `2F0D6CB5` | 192,901 | 21% | wired |
| CTM UK | CTMUK- Prod - Start Quote - Key 1 | `F8A9F272` | 174,660 | 84% | wifi, wired |
| Bumble | Badoo - Social - Mobile - Production - Key 6 | `89C573F3` | 167,332 | 76% | wifi, mobile |
| Microsoft | Microsoft - Commerce - Production - Key 2 | `272AEF57` | 155,888 | 60% | wifi, wired |
| Bumble | Badoo - SMS - Mobile - Production - Key 8 | `C812C939` | 154,462 | 60% | wifi, wired |
| Figma | Figma - Login - Production - 1 | `955D26AF` | 131,677 | 65% | wifi, mobile |
| Wells Fargo | WCA - Prod/Detect - WCA Enhanced Login - Web - Key 12 | `D20D87AA` | 130,823 | 60% | wifi, wired |
| TriNet | Zenefits - Trinet - Production - Key 3 | `05BEFACE` | 127,628 | 87% | wifi, wired |
| AT&T | AT&T - Consumer SDK Android - Production - Key 4 | `4DD22AF2` | 125,854 | 41% | mobile |
| Coursera | Coursera - Login - Production - Key 2 | `043FE28E` | 122,517 | 85% | wifi, wired, mobile, nat |
| Figma | Figma - Registration - Production - Key 2 | `A207F8A1` | 121,986 | 53% | wifi |
| Expedia | EG -Production - Taap - LowTraffic - Key 3 | `447C2794` | 117,785 | 75% | wifi, wired |
| Bumble | Badoo - Social - Web - Production - Key 5 | `85AD0329` | 93,759 | 45% | wifi |
| Olo | Olo - Payments - Production - Key 3 | `F82162A1` | 84,139 | 89% | wifi, wired, mobile |
| Grab | Grab - Login + Rego - Production - Key 1 | `963556DD` | 72,207 | 83% | wifi, mobile |
| Payoneer | Payoneer - CLM - Registration - Key 3 | `E3EFEFBF` | 69,055 | 83% | wifi, mobile |
| Expedia | BEXG - Production - Native App - OTP - Key 15 | `8D4A627D` | 59,595 | 27% | wired |
| AT&T | AT&T - Cricket SDK Android - Production - Key 10 | `42CF6EBA` | 55,882 | 81% | wifi, mobile |
| Dropbox | Dropbox - Production - Registration - Key 2 | `68CECE5D` | 55,389 | 18% | wifi |
| Amazon | Amazon - Client - Production - Key 1 | `2F1CD804` | 50,237 | 64% | wifi, mobile |
| Getty Images | Getty Images - Sign In, Oauth, SSO, PWD Reset - Prod - Key 3 | `0373782E` | 44,790 | 19% | wifi |
| Chime | Chime - Production - Key 4 - Chime Web App | `F169C36A` | 37,046 | 74% | wired, mobile |
| CTM AU | Compare the Market - Production - Key 1 | `F4E93EA5` | 35,140 | 44% | wired |
| Coursera | Coursera - Registration - Production - Key 1 | `98EFB87D` | 34,184 | 38% | wifi |
| Expedia | BEXG - Production - Login - Key 4 | `F0C12973` | 24,985 | 39% | wired |
| Bumble | Badoo - SMS - Web - Production - Key 7 | `3515A340` | 24,437 | 62% | wifi, wired |
| Microsoft | Microsoft - Outlook - Production - Key 1 | `FB98C7DB` | 22,378 | 68% | wifi, wired |
| Keno | Keno - Prod - Login - Key 2 | `D353809F` | 21,421 | 56% | wifi |
| Citizens | Citizens - Production (CAX) - Key 2 | `4BFF55FE` | 15,182 | 81% | wired |
| Wells Fargo | WCA - Prod/Detect - WCA Traditional Login - Web - Key 13 | `9F7D405C` | 14,072 | 19% | wired |
| Agoda | Agoda - SMS - Production 2 | `5B2700A1` | 12,234 | 12% | wired |

## NONE — and why

There are four reasons a key has no CT threshold. They come from the
[automated-thresholds (detection-apps)](https://arkoselabs.atlassian.net/wiki/spaces/DE/pages/4770234382)
write rules: the per-CT write uses the same key set and guards as the global IP write.

### Reason 1 — IP auto-thresholds are disabled for the key (manual thresholds)

The cron skips keys with automation disabled, so they never get a CT map. These are the keys
listed in [IP Intelligence (RTA) Auto-Thresholds — Enabled vs Disabled — Oct 2026](https://arkoselabs.atlassian.net/wiki/spaces/EN/pages/4748836897)
that had traffic on 14 Oct:

| Account | Keys (manual IP thresholds, no CT thresholds) | Known reason |
| --- | --- | --- |
| Uber | SMS (`30000F36`, 10.7M/day, IP threshold 20) | FPs; on the list to revert to auto |
| Wells Fargo | Login Mobile (`943697A4`), Online Enrollment (`EDCF26A3`), Password Reset Web (`DB4DC857`), Consumer Deposits Web (`414D40C4`) | Customer asked for stable, controllable thresholds (ESM-5892, ESM-6544). **Thomas asked to leave WF manual for now.** |
| Roblox | Login (`476068BF`), Signup (`A2A14B1D`), Game Join (`CC30DB96`), Monetization (`1B154715`), Other (`63E4117F`) | The whole Roblox account is excluded from IP/DI automation (excluded-accounts list). Reason **VERIFY**. |
| Microsoft | Identity Account Signup (`B7D8911C`), Payment (`E9C0EDAD`) | Probably never turned on. Thresholds were hand-set in ESM-3010 (May 2024) before automation existed. |
| HP | Returning Users (`5B6F3411`) | FPs (ESM-5858) |
| AT&T | Forgot Password (`A0C1F8BD`), Cricket Login Web (`9D83AB3F`), FirstNet ILM (`B993466D`) | FPs (ESM-6297) |
| theLott | Login (`1A413285`), Registration (`25C68761`) | Unknown; context requested 2 Oct |
| WBD | Bolt/Beam Login, Registration, Password Reset; Multi-Tenant Login, Payment, Reg/PW Reset; FUSE/Konto Login, Lookup, Reg/PW Reset; Dalton Login, Reg/PW/Payment; Games PN Account Registration; Discovery GIP Login, Comment Submission | All 18 WBD keys are off, which suggests one account-level decision. Unknown; context requested 2 Oct. |

**Implication:** moving these keys back to auto-thresholds is a **prerequisite** for CT coverage.
Until then, the CT telltales will never fire on them.

### Reason 2 — auto-thresholds enabled, but no CT learned a usable threshold

For each (key, CT), the walk either found too little data per hour, or returned a value ≤ 10, so
the CT was left out. This is expected for low-volume keys and for keys whose traffic is spread
thinly across connection types. Many of these keys also sit on very low IP-only thresholds (10–15),
which suggests the global walk is close to the floor too.

| Account | Keys (production, ≥ 5k sessions/day) |
| --- | --- |
| WBD | Bolt/Beam Account Lookup (`7A946A46`, 1.07M/day), TVN Login (`DF7842A7`), CNN Lookup (`72361606`), Games PN Password Login (`7BC9DF44`) |
| HP | New Users (`6E7F820D`), SMS (`FE504504`) |
| Airbnb | Account create (`9E720074`), Account login (`852AF3F3`) |
| Expedia | BEXG OTP (`B8BDED1B`), Hcom OTP (`F7B5AE6C`), Vrbo OTP (`FB58AF3E`), Vrbo Native OTP (`F4856F24`), Hcom Native OTP (`93568CD9`), BEXG Native Login (`776F96B5`), Hcom Native Login (`7FFD5D4D`), EG Forgot Password (`45F4AA3B`), Vrbo Native Login (`015353EB`) |
| Tinder | Mobile (`EBC0462E`) |
| Match | Registration (`D1632BAF`) |
| Dropbox | HelloSign Login (`07071A28`), HelloSign Registration (`C1B9473A`), Password Reset (`FDA64B05`), Payments (`8AFFAA35`) |
| Blizzard | ROW Registration (`E8A75615`) |
| Sony | Support Chat and Form (`CDB38584`) |
| Agoda | Registration (`1C2BB537`) |
| Zilch | Login (`284CE8B2`), PreAuth Mobile (`15C39990`) |
| Citizens | Commercial (`C2A97E50`), CPay and LaaS (`2100836D`) |
| Coinbase | SMS (`03CB9CF0`), Email Verification (`E191DADD`) |
| DoorDash | Storefront (`4AB70A00`) |
| GitLab | Sign Up & IDV (`12D76D4C`) |
| Getty Images | ESP Sign In (`17A2233B`), iStock Sign In (`E14A2FF7`) |
| AT&T | FirstNet IAM (`1E12F858`) |
| TIAA | Login Mobile (`6EE1DA30`) |
| Singapore Airlines | Key 1 (`4D297134`) |
| Air Canada | Forgot Password (`8DD93BC1`) |
| Hornet | Registration SDK Android (`4FDBF9EF`), SDK iOS (`825DD2FA`) |
| Lively, ResearchForGood, Alienvault OTX, FlashGap Social Mobile, Payoneer Registration, Bumble Geneva SMS Web, DigitalOcean Sign-up, Microsoft Learn | one key each |
| Wells Fargo | WCA Hosted Login (`97ED206F`) |
| CTM UK | Start Quote WhiteLabel (`7BD3F690`) |

> **VERIFY:** several of these keys show an IP-only short-term threshold of exactly **300**. These
> are WBD Account Lookup, TVN, CNN, Games PN, Hornet, Alienvault, Citizens CPay, WCA Hosted Login
> and CTM UK WhiteLabel. 300 looks like a default or never-tuned value. Check whether these keys
> are being "left alone" (non-circadian) by the cron, or have a manual value.

### Reason 3 — not a production key, or not a customer key

Dev, QA and synthetics keys are excluded from automation by design. Examples:
- Adobe dev keys;
- WF and WCA Dev/Detect;
- Coinbase, Chime, Citizens, HP and WBD dev keys;
- BofA dev key;
- Arkose QA "New-Synthetics-Key";
- Arkose Azure WAF Synthetics.

No action is needed.

### Reason 4 — no RTA threshold at all

**Microsoft Azure - Production - Key 1** (`8A1EAD4C`, about 689k sessions/day) has no IP-only
threshold on any session, as well as no CT threshold. It is listed as auto-enabled.

> **VERIFY:** is this an edge-API key? Edge keys are excluded from the cron. Or is RTA not
> returning for this key?

### Keys with manual CT telltales from CHNGE-5096

Check these **before** you delete the CHNGE-5096 telltales. Several keys on that list have no
built-in CT thresholds or only partial coverage today:
- HP Returning Users, New Users and SMS;
- all Roblox keys;
- HelloSign Login and Registration;
- WF Login Mobile;
- AT&T Forgot Password, Cricket Login and FirstNet;
- TIAA Mobile;
- Coursera Registration (38%).

Deleting the static telltales on those keys would remove connection-type coverage completely.
Delete per key, and only once the coverage query shows FULL.

---

# How SOC knows whether a key has connection-type thresholds

1. **For one session (in a ticket):** check
   `rta__ip_connection_type_velocity_short_term_threshold` in the session record.
   - Populated: a CT threshold applied to that connection type on that key.
   - Empty: nothing applied, and only `g-ip-velocity-*` could fire.
2. **For one key:** run [`queries/ip_ct_threshold_coverage.sql`](../queries/ip_ct_threshold_coverage.sql)
   in Superset SQL Lab (database **Snowflake**, id 14) with the `public_key` filter. It returns:
   - the coverage tier (FULL / PARTIAL / NONE);
   - which CTs have a threshold;
   - which CTs don't;
   - the IP-only threshold for comparison.
3. **Across all keys:** run the same query without the key filter. **DECISION:** save it as a
   Superset chart on the [IP Velocity Connection Type dashboard](https://superset-snowflake-green.production-blue.us-east-2.internal.services.aws.arkoselabs.com/superset/dashboard/1663/),
   so SOC has one place to look and doesn't rely on this page's 14 Oct snapshot.
4. **Re-check before every change.** The cron rewrites the CT map daily, so coverage can change
   from one day to the next. This is most likely on PARTIAL keys and right after a key is moved
   from manual to auto.

**Rule of thumb:**

| Tier | Customer TTs from CT globals | Legacy `g-ip-velocity-*` on the key |
| --- | --- | --- |
| FULL | Yes | Can be disabled for the key once the CT telltales are validated |
| PARTIAL | Yes, for the covered CTs | **Keep on.** It is the only coverage for the uncovered CTs. |
| NONE | No. They cannot fire. | **Keep on.** It is the only IP velocity coverage. |

---

# Relationship to the existing IP velocity telltales

- **Not retired.** The `g-ip-velocity-short-term-abuse`, `-2x`, `-4x` telltales and their
  long-term equivalents (ids 10276, 10275, …) stay active, because many keys have no or partial
  CT thresholds. This was confirmed in #C0BHGFL23C3 on 9 Oct.
- **They can be disabled per key** where the coverage query shows FULL and the CT telltales have
  been validated on that key.
- **Alternative to per-key disabling (DECISION for THR):** add the fallback condition already used
  by the harvested-proxy, hosting and cloud-asn flags, so the legacy telltale only fires when no
  CT threshold applied:

  ```json
  {"key": "rta__ip_connection_type_velocity_short_term_threshold", "operator": "NOT_EXISTS"}
  ```

  Without per-key exclusions, this removes double-firing on covered keys and keeps full IP-only
  coverage everywhere else. It also adapts automatically as coverage changes day to day.
- **The CHNGE-5096 manual CT telltales** will be deleted once the globals are enabled, because they
  are static. Delete them per key, after checking coverage (see the previous section).
- **The double-counting risk if you change nothing:** on FULL keys, a session can fire both
  `g-ip-velocity-*` and `g-ip-connection-type-velocity-*`. Account for this when you set pressure.

---

# Recommended SOC Usage

## Global versus customer-specific detection

1. **Global coverage:** the CT globals apply to every key with globals enabled, but they only fire
   where a CT threshold exists. Use them as the main IP velocity signal on FULL keys.
2. **Customer-specific telltales:** build custom telltales from the CT globals, for example a
   specific CT and tier with pressure for one key. Do this only on FULL keys, or on the covered CTs
   of PARTIAL keys. The CT globals stopped being suspicion flags on 7–8 Oct, so custom telltales
   built from the old suspicion-flag versions will stop working.
3. **Shared-egress-heavy keys** (mobile CGNAT, corporate, edu): consider the `sf-shared-egress-carveout`
   variants. They need 3x on consumer-privacy, corporate, edu and public egress before firing.
4. **Mixed coverage:** for PARTIAL keys, pair the CT telltales with the legacy IP telltale (or with
   the fallback version described above) so the uncovered CTs are still protected.

## Suggested enforcement posture

| Situation | Recommended posture |
| --- | --- |
| CT 3x on a sensitive flow (login, account creation, payment, OTP/SMS) | Strong candidate for high pressure |
| CT 2x plus a residential proxy, hosting or high-risk-ASN context flag | High-confidence compound; mitigate |
| CT 1.5x on a shared-egress CT (`mobile`, `nat`, `satellite`) | Monitor or step-up only. This is the band where shared-infrastructure FPs used to happen. |
| CT 1x on `wired` or `wifi` with device inconsistency or automation indicators | Candidate for mitigation, subject to customer tolerance |
| Customer wants stable, fixed thresholds (e.g. Wells Fargo) | Leave on manual IP thresholds and legacy telltales; don't push CT |

---

# SOC Support and Triage

## Recommended investigation steps

1. Confirm which telltale fired: CT (`g-ip-connection-type-velocity-*`) or legacy (`g-ip-velocity-*`), and which tier.
2. Check the session's `connection_type` and whether `rta__ip_connection_type_velocity_short_term_threshold` is populated.
3. Compare the CT count and threshold with the IP-only count and threshold for the same session.
4. Check the context: `vpn_proxy_type`/`vpn_proxy_description`, `ip_intel__is_proxy_harvested`, ASN risk band, ISP and country.
5. Run the coverage query for the key to see whether this CT is covered and how many sessions it carries.
6. Check whether the threshold changed recently (it is rewritten daily at 16:00 UTC), especially if the customer reports a sudden change.
7. Recommend a pressure, tier or carve-out change. Don't hand-edit CT thresholds; they are overwritten daily.

## Common ticket scenarios

- **"Why didn't the CT telltale fire when IP velocity was clearly high?"**
  - Check whether the key and CT have a threshold. If the field is empty, only the legacy
    telltales could fire.
  - If the key is on manual thresholds, explain that CT thresholds need auto-thresholds enabled.
- **"FPs on mobile or NAT traffic."**
  - Check the tier. Recommend pressure on 2x or 3x only for shared-egress CTs, or the
    `sf-shared-egress-carveout` variant.
- **"Both the legacy and CT telltales fired on the same session."**
  - This is expected on covered keys. Disable the legacy telltale for FULL keys, or apply the
    fallback condition.
- **"Which customers can have all the split telltales?"** (Karina, 15 Oct)
  - FULL keys can.
  - PARTIAL keys can only for the listed CTs.
  - NONE keys can't yet.
  - Use the coverage query, not this snapshot.
- **"The CT threshold looks wrong or too low."**
  - Check for a promotion or a traffic change in the last 7 days (the training window).
  - Escalate to Detection with the key, the CT and the dates.

---

# Related Jira and References

- **DETCORE-4081 / 4082 / 4083 / 4084 / 4085:** conf-api storage, RTA compound cube, detection-hub emit and compute, detection-apps per-CT training.
- **DETCORE-4293:** 1x CT telltales (short-term and long-term).
- **DETCORE-4371:** multiplier tiers and context suspicion flags.
- **THR-1173:** CT global telltale write-ups (THRE space, status *Proposed*).
- **CHNGE-5096:** manual per-CT telltales, to be removed per key.
- **DETCORE-3854:** valley bug in the circadian threshold picker.
- **ESM tickets:** ESM-5858, ESM-6148, ESM-5892, ESM-6544, ESM-6296, ESM-6297, ESM-6291, ESM-6360, ESM-5631, ESM-3010.
- **CHNGE tickets:** CHNGE-4419, CHNGE-4516, CHNGE-4465, CHNGE-4749, CHNGE-4760, CHNGE-4750, CHNGE-4772.

**Confluence pages:**
- [Proposal: IP Velocity Auto-Thresholding Improvements](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4259348630)
- [Per-Connection-Type IP Velocity Thresholds Implementation Overview](https://arkoselabs.atlassian.net/wiki/spaces/EN/pages/4320722948)
- [automated-thresholds (detection-apps)](https://arkoselabs.atlassian.net/wiki/spaces/DE/pages/4770234382)
- [IP Intelligence (RTA) Auto-Thresholds — Enabled vs Disabled — Oct 2026](https://arkoselabs.atlassian.net/wiki/spaces/EN/pages/4748836897)

**Dashboard:** [IP Velocity Connection Type (Superset 1663)](https://superset-snowflake-green.production-blue.us-east-2.internal.services.aws.arkoselabs.com/superset/dashboard/1663/)
