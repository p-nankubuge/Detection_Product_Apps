# IP Connection-Type Velocity — SOC Implementation & Support Guide

**Purpose:** This guide explains how SOC should interpret, support, and operationalise Arkose's per-connection-type (CT) IP velocity signal and the global `g-ip-connection-type-velocity-*` telltales and suspicion flags. It covers why the per-CT thresholds exist, where they come from, how often they refresh, why some keys have none, and how SOC can tell which keys are covered.

Companion to: [Residential Proxy IP — SOC Implementation & Support Guide](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4707778564/Residential+Proxy+IP+SOC+Implementation+Support+Guide).

> Facts in this draft come from Dataswan production (telltale definitions, pulled 2026-10-15), Athena `arkoselabs.events_faster` (coverage snapshot, hour `2026/10/15/00`), and the Confluence/Jira pages linked in References. Items marked **VERIFY** couldn't be confirmed from those sources. Items marked **DECISION** are for the owner to settle.

# Overview

IP velocity counts how many requests one IP sends to a key over a short window (~40 min) and a long window (~48 h), and compares that count to a threshold. Before this work every IP on a key was measured against **one** threshold, whatever kind of connection the traffic came from.

The per-CT feature adds a second counter keyed on `{ip, connection_type}` and gives each connection type its own short- and long-term threshold for each key. Connection types come from IP Intelligence: `wired`, `wifi`, `mobile`, `nat`, `satellite`, `dialup`. If the connection type is missing, the session goes into a separate `absent` bucket.

**Important:** The ip-only velocity fields (`rta_ip_velocity_*`) are unchanged. Per-CT is a parallel field set, not a replacement. Existing ip-velocity telltales keep firing exactly as before.

# Why we moved to per-connection-type short- and long-term thresholds

From [Per-Connection-Type IP Velocity Thresholds Implementation Overview](https://arkoselabs.atlassian.net/wiki/spaces/EN/pages/4320722948/Per-Connection-Type+IP+Velocity+Thresholds+Implementation+Overview) (§1–2, §3.3, §5.3.5, §9):

1. **One number can't tune both ways.** With a single global IP threshold, setting it low catches more attacks but produces false positives on users who share IPs. Setting it high protects those users but lets attacks through.
2. **Connection types behave differently.** Datacenter IPs often carry nothing but attack traffic and need tight thresholds. Residential, mobile and carrier-grade-NAT IPs are shared by many real users and need more headroom. A key's traffic mix means one threshold is always wrong for some of its traffic.
3. **Separate buckets.** Counting `{ip, connection_type}` separately means a mobile carrier IP's legitimate volume doesn't hide, or get blamed for, abuse from the same IP on another connection type.
4. **Short *and* long term.** The short-term ratio catches bursts. The long-term ratio catches sustained low-rate attacks that stay under the short-term threshold (§5.3.5).
5. **Parallel fields, not overwrite.** Earlier designs replaced the ip-only ratio with the CT ratio behind a flag. That was rejected because global/custom telltales, suspicion flags, ML and analytics all read the ip-only columns. Changing what those columns mean would silently change firing rates. Instead, six new `rta__ip_connection_type_velocity_*` fields were added, so per-CT telltales are opted into deliberately.
6. **No threshold without data.** If a `{key, CT}` pair doesn't have enough traffic for a reliable circadian model, no threshold is written: "taking a position on insufficient data is worse than not taking one" (§3.3).

# Data Sources, Refresh, and Trust

| Area | SOC reference | Operational implication |
| --- | --- | --- |
| **Counter** | RTA cube `ip-connection-type` keyed `[ip, connection_type]`, with 1-minute and hourly windows and a 48 h TTL (DETCORE-4082). | The count fields are filled on every session that goes through detection-hub RTA, whether or not a threshold exists. |
| **Threshold source** | detection-apps CronJob `automated-thresholds` runs a circadian model over 7 days of `prod_session_summary`, separately for each (key, CT) (DETCORE-4085). | Thresholds are learned from the key's own verified traffic, not set by hand. |
| **Write path** | conf-api `POST /v1/detection-hub/<pk>` → DynamoDB `detection_hub_config.ip_velocity_thresholds_by_connection_type` = `{ct: {short_term: T, long_term: 96·T}}`. | Dataswan doesn't show this map. It isn't in the key's client params or in the Dataswan RTA threshold screen. |
| **Refresh cadence** | Daily at 16:00 UTC (`0 16 * * *`). conf-api replaces the **whole** map on each write. | A CT can appear or disappear between days. A CT that's left out falls back to "no per-CT threshold". |
| **Minimum value** | Rungs that come out ≤ 10 are dropped. The lowest threshold seen in production is 15. | Low-traffic CTs often never get a threshold. |
| **Long-term threshold** | Always `96 × short_term` for CT. The ip-only global path uses `5×` for RTA. The Known Issues page flags this as possibly unintended. | Long-term CT telltales are deliberately loose. Don't compare long-term CT and ip-only thresholds directly. |
| **Trust level** | Behavioural, key-relative signal. A ratio > 1 means this IP on this CT is above what the key's own legitimate traffic supports. | Stronger at higher multiples (2×, 3×). Base (1×) and 1.5× should be combined with other evidence before hard enforcement. |

# Available Fields

| Field (events / `latest_rta__…` in session summary) | Meaning | Populated when |
| --- | --- | --- |
| `rta__ip_connection_type_velocity_short_term_count` | Requests from this `{ip, CT}` in the short window (~40 min). | Always, when RTA runs. |
| `rta__ip_connection_type_velocity_long_term_count` | Same, for the long window (~48 h). | Always, when RTA runs. |
| `rta__ip_connection_type_velocity_short_term_threshold` | Per-CT short-term threshold applied to this session. **This is the audit trail for "does this key/CT have a threshold".** | Only if the (key, CT) has a threshold. |
| `rta__ip_connection_type_velocity_long_term_threshold` | Per-CT long-term threshold (96 × short). | Only if the (key, CT) has a threshold. |
| `rta__ip_connection_type_velocity_short_term_ratio` | `count ÷ threshold`, short window. **The field the multiplier telltales evaluate.** | Only if the (key, CT) has a threshold. |
| `rta__ip_connection_type_velocity_long_term_ratio` | `count ÷ threshold`, long window. | Only if the (key, CT) has a threshold. |
| `connection_type` | IP Intelligence connection type used to pick the bucket. | When IP Intelligence returns one; otherwise the bucket is `absent`. |

# Global Telltales and Suspicion Flags (Dataswan, 2026-10-15)

All are `public_key = GLOBAL`, scoped to `location IN (session_setup, game_verify)`, `allow_pressure = allow`, and (unless noted) gated on `#INCLUDE g-global-telltales-enabled`. There are 38 in total.

## Family A — base threshold (count > per-CT threshold, i.e. ratio > 1×) — DETCORE-4293

| Name | Type | Window | CT |
| --- | --- | --- | --- |
| `g-ip-connection-type-velocity-short-term-abuse-{wired,wifi,mobile,nat,satellite}` | telltale | short | each |
| `g-ip-connection-type-velocity-long-term-abuse-{wifi,mobile,nat,satellite}` | telltale | long | each |
| `g-ip-connection-type-velocity-long-term-abuse-wired` | **suspicion_flags** | long | wired |

## Family B — ratio multipliers (`short_term_ratio > 1.5 / 2 / 3`) — DETCORE-4371, promoted under THR-1173

| CT | 1.5× | 2× | 3× |
| --- | --- | --- | --- |
| wired | `…-wired-1point5x` | `…-wired-2x` | `…-wired-3x` |
| wifi | `…-wifi-15x` (**suspicion_flags**, no global include) | `…-wifi-2x` | `…-wifi-3x` |
| mobile | `…-mobile-1point5x` | `…-mobile-2x` | `…-mobile-3x` |
| nat | `…-nat-1point5` | `…-nat-2x` | `…-nat-3x` |
| satellite | `…-satellite-1point5x` | `…-satellite-2x` | `…-satellite-3x` |
| dialup | `…-dialup-1point5` | `…-dialup-2x` | `…-dialup-3x` (**suspicion_flags**, no global include) |

There are no long-term multiplier telltales yet, although DETCORE-4371 scopes `long_term_ratio` 1.5×/2×/3×.

## Family C — context suspicion flags with ip-only fallback (cohort *Suspicious*) — DETCORE-4371

These fire when **either** the CT ratio **or** the ip-only short/long ratio is above the cut-off. Because of that fallback they still work on keys with no per-CT threshold.

| Suspicion flag | Context condition | Ratio cut-off |
| --- | --- | --- |
| `…-short-term-abuse-harvested-proxy` | `ip_intel__is_proxy_harvested = true` | > 0.5 |
| `…-short-term-abuse-hosting` | DE `vpn_proxy_type = hosting`, excluding vpn / cloud-security / web-browser | > 0.5 |
| `…-short-term-abuse-hosting-vpn` | DE hosting + `vpn` | > 0.5 |
| `…-short-term-abuse-cloud-asn` | Google/AWS/Microsoft ASNs not typed by DE | > 0.5 |
| `…-short-term-abuse-high-risk-asn` | `ip_intel__asn_intel__risk_band = High` | > 1.0 |

## Family D — shared-egress carve-outs (proposed base replacements) — DETCORE-4371

`g-ip-connection-type-velocity-short-term-abuse-{wired,wifi,mobile,nat,satellite}-sf-shared-egress-carveout`: the base condition (count > CT threshold), but if DE `vpn_proxy_type` is `consumer-privacy`, `corporate`, `edu` or `public`, the flag only fires above 3×. This targets shared corporate, school and public Wi-Fi false positives.

**Key behaviour for SOC:** Families A, B and D need a per-CT threshold on the session. On a key/CT with no threshold, `…_threshold` and `…_ratio` are null and these rules **cannot fire**. They don't fall back to the ip-only threshold. Only Family C has a fallback.

# Which keys have a connection-type threshold, and why some don't

## Coverage snapshot (`events_faster`, `session_setup`, hour 2026/10/15/00 UTC)

| Measure | Value |
| --- | --- |
| Keys with traffic in the hour | 349 |
| Keys with a per-CT threshold on at least one CT | 70 |
| Sessions carrying a per-CT threshold | 1.35 M of 2.94 M (46%) |
| Keys with ≥ 1k sessions in the hour | 116 |
| …of which have **no** per-CT threshold on any CT | 57 |

Even keys that are covered usually have thresholds for only some CTs. For example, `FDED3FA5…` has `mobile` only (≈18% of sessions covered), and `436DD567…` has `wifi` only. No key in the snapshot had an `absent` threshold, and only one key had a `dialup` threshold.

The full no-threshold list with key names is in the Appendix. Re-run `queries/ct_threshold_coverage.sql` for current state.

## Why a key or CT has no threshold

Thresholds exist only where the `automated-thresholds` cron wrote them. Reasons, from the [automated-thresholds](https://arkoselabs.atlassian.net/wiki/spaces/DE/pages/4770234382/automated-thresholds+detection-apps) and implementation pages, matched against the snapshot:

| Reason | Mechanism | What it looks like in the snapshot |
| --- | --- | --- |
| **Not a Production key** | The cron only takes `key_state=Active, key_type=Production` keys from core-accounts-api. | Dev and QA keys: Adobe Dev (Keys 5, 8), WCA Dev, Amazon Prime Credit Dev, HPID Dev, Coinbase Dev, WF Dev/Detect, Arkose `New-Synthetics-Key`. |
| **Excluded account** | `DETECTIONAPPS_AUTOMATED_THRESHOLDS_EXCLUDED_ACCOUNTS = [21178, 23486, 23604, 21371, 22846]`. | **VERIFY:** which accounts these IDs map to. Whole-account gaps (every Roblox, WBD, Wells Fargo prod key, Uber SMS) point to account-level exclusion or opt-out. |
| **Automation disabled for the key** | `detect_automation_config` `ip_enabled` false, or `ip_confidence_threshold = -1`. The CT loop uses the same guards as the global IP loop. | **VERIFY** per key in conf-api. A static-looking ip-only threshold (300, 550, 150) suggests a hand-set threshold on a key that isn't automated. |
| **Edge-API key** | Keys with `site_settings.edge_api_enabled = true` are skipped. Whether edge sessions write the CT bucket at all was open question #1 in the implementation doc. | No edge sessions in this snapshot (`edge__workflow` null). **VERIFY** for edge keys (e.g. Adobe Firefly). |
| **Not enough traffic for that CT** | Each (key, CT) needs enough verified sessions per hourly bin over 7 days. Rare CTs (dialup, satellite, nat on most keys) never get there. | Most covered keys are missing nat, satellite, dialup and `absent`. |
| **Non-circadian / result ≤ 10** | If the walk ends at ≤ 10, that CT is left out of the map. | Keys whose ip-only threshold sits at the floor (15) usually have no CT entries. |
| **RTA not running for the key** | No RTA counters at all, so no training data. | Microsoft Azure Key 1: `n_ct_count = 0` and no ip-only threshold. |
| **Silent write failure** | conf-api/Dataswan write responses are logged but not checked (Known Issues, *Medium*). | **VERIFY:** high-volume production keys with an automated-looking ip-only threshold but no CT map (e.g. Uber SMS Key 1, 375k sessions/h, ip-only threshold 20). |

# How SOC knows which keys have a connection-type threshold

Today there's no Dataswan screen for this. Use these, in order of reliability:

1. **Session record (authoritative, per ticket).** For the key in question, check `rta__ip_connection_type_velocity_short_term_threshold` (`latest_rta__…` in `prod_session_summary`). If it's populated, that (key, CT) has a threshold and the value is shown. If it's null while `…_short_term_count` is populated, there's no per-CT threshold. Run `queries/ct_threshold_coverage.sql` with a `public_key` filter.
2. **Fleet view (weekly).** Run the same query without a key filter, for an hour after the 16:00 UTC cron. Save it as a Superset chart or dashboard tile next to the THR-1173 dashboard (`superset/dashboard/1663`). **DECISION:** owner and location of the saved chart.
3. **Cron outputs.** `s3://arkose-detection-apps-automated-thresholds-production/YYYY-MM-DD/rta_results.csv` and the thresholds Slack channel. **VERIFY:** whether `rta_results.csv` includes the per-CT map or only the global IP threshold. If it doesn't, ask Detection Services to add a `rta_ct_results.csv`.
4. **Recommended product fix.** Show the per-CT map read-only in Dataswan next to the RTA thresholds (Dataswan already proxies RTA threshold writes), or post a daily "keys/CTs gained or lost a threshold" diff to Slack. **DECISION:** raise as a DETCORE ticket.

**Rule of thumb for SOC:** before recommending or adding pressure on a Family A/B/D telltale for a customer, confirm the key has a threshold **for the connection types that matter for that flow**. If it doesn't, the telltale won't fire, so use ip-only velocity telltales or the Family C flags instead.

# Recommended SOC Usage

## Global versus customer-specific

1. **Global coverage:** Family A/B telltales are already global and gated by `g-global-telltales-enabled`. They only act on keys/CTs that have a threshold.
2. **Keys without a threshold:** rely on ip-only `rta_ip_velocity_*` telltales and the Family C suspicion flags, which fall back to ip-only ratios.
3. **Shared-egress-heavy customers** (enterprise, edu, public Wi-Fi): prefer the Family D carve-out flags over Family A base telltales.
4. **Mismatch analysis:** if a CT telltale fires but the ip-only one doesn't (or the other way round), compare the two thresholds on the session. Usually the CT threshold is tighter for mobile/nat/satellite and looser for wired/wifi on high-volume keys.

## Suggested enforcement posture

| Situation | Recommended posture |
| --- | --- |
| Short-term CT ratio > 3× on any CT | Strong candidate for hard enforcement or high pressure on sensitive flows (signup, login, OTP/SMS, payment). |
| Short-term CT ratio > 2× | High-pressure mitigation. Hard enforcement when combined with automation, device-inconsistency or residential-proxy signals. |
| Short-term CT ratio > 1× to 1.5× (base / 1.5×) | Step-up, challenge or monitoring. Combine with other evidence before blocking, especially on `nat`/`mobile` CGNAT ranges. |
| Long-term CT base (count > 96 × short threshold) | Sustained-abuse indicator. Good for escalation and investigation. The threshold is loose, so a hit is meaningful. |
| Family C flag (harvested proxy / hosting / cloud / high-risk ASN + velocity) | High-confidence compound signal. Suitable for mitigation. |
| Shared egress (`consumer-privacy`, `corporate`, `edu`, `public`) | Use the Family D carve-out (fires only > 3×) instead of the base telltale. |

# SOC Support and Triage

## Recommended investigation steps

1. Confirm which telltale or flag fired, and its family (A/B/C/D) and window (short/long).
2. Check that `rta__ip_connection_type_velocity_short_term_threshold` is populated for the session's `connection_type`. For Family C, check whether the CT or the ip-only ratio crossed the cut-off.
3. Compare the CT ratio with `rta_ip_velocity_short_term_ratio` for the same session.
4. Review connection type, ASN/ISP, `vpn_proxy_type`/`vpn_proxy_description`, country, residential-proxy flags, and supporting telltales.
5. If behaviour changed suddenly, check whether the key's CT map changed at the last 16:00 UTC cron run (a CT gained or lost a threshold, or a value moved).
6. Recommend pressure, carve-out or rule changes based on the customer's tolerance and how sensitive the flow is.

## Common ticket scenarios

**"Why isn't the connection-type telltale firing on my key?"** Most often the key or CT has no per-CT threshold (see *Why a key or CT has no threshold*). Confirm with the coverage query, then use ip-only velocity or Family C instead. Escalate to Detection Services if a high-volume production key that should be automated has no CT map.

**"False positives on mobile / NAT."** Check that the CT threshold isn't at the floor (15). Use the 2× or 3× variant instead of base or 1.5×. Check for shared egress and use the Family D carve-out if it applies.

**"Threshold changed overnight."** Expected: the cron retrains daily on a rolling 7-day window and replaces the whole map. Compare that day's session thresholds with the previous day's.

**"Which threshold applies to this session?"** It's stamped on the session in `…_short_term_threshold` and `…_long_term_threshold`. Short and long are always 1 : 96 for CT.

# Known Gaps and Hygiene (for the owner)

- `…-long-term-abuse-wired`, `…-short-term-abuse-wifi-15x` and `…-short-term-abuse-dialup-3x` are `suspicion_flags` **without** `#INCLUDE g-global-telltales-enabled`. Every other member of their families is a gated telltale. **DECISION:** align them.
- `…-wifi-15x` is named inconsistently. It's the 1.5× wifi rule; the siblings use `1point5x`/`1point5`.
- Family A has no `dialup` base or `dialup` long-term entry. No family has an `absent` entry, and no long-term multipliers exist.
- Several descriptions are stale clone text. For example, `…-long-term-abuse-wifi` describes the Email Intelligence ML score. They should be rewritten before SOC relies on the Dataswan description.
- Dataswan shows many timestamped per-key copies (e.g. `<key>-e-global-telltale-non-circadian--g-ip-connection-type-velocity-…-2026-10-15-0050`, plus `audit-temp-*` copies) being created about every 25 minutes. **VERIFY:** which job creates them and whether they're expected. Telltale pile-up is a known issue for timestamped ensemble telltales.

# Related Jira and References

- [DETCORE-4081](https://arkoselabs.atlassian.net/browse/DETCORE-4081) — conf-api per-CT threshold storage.
- [DETCORE-4082](https://arkoselabs.atlassian.net/browse/DETCORE-4082) — RTA `{ip, connection_type}` cube.
- [DETCORE-4083](https://arkoselabs.atlassian.net/browse/DETCORE-4083) / [DETCORE-4084](https://arkoselabs.atlassian.net/browse/DETCORE-4084) — detection-hub compound key and per-CT fields.
- [DETCORE-4085](https://arkoselabs.atlassian.net/browse/DETCORE-4085) — detection-apps per-CT threshold training.
- [DETCORE-4293](https://arkoselabs.atlassian.net/browse/DETCORE-4293) — base per-CT velocity telltales.
- [DETCORE-4371](https://arkoselabs.atlassian.net/browse/DETCORE-4371) — per-CT ratio suspicion flags (1.5× / 2× / 3×).
- [THR-1173](https://arkoselabs.atlassian.net/browse/THR-1173) — promote CT suspicion flags to global telltales (Done).

**Primary documentation:** [Per-Connection-Type IP Velocity Thresholds Implementation Overview](https://arkoselabs.atlassian.net/wiki/spaces/EN/pages/4320722948/Per-Connection-Type+IP+Velocity+Thresholds+Implementation+Overview)

**Operational references:** [automated-thresholds (detection-apps)](https://arkoselabs.atlassian.net/wiki/spaces/DE/pages/4770234382/automated-thresholds+detection-apps) · [Detection Apps – Known Issues](https://arkoselabs.atlassian.net/wiki/spaces/DE/pages/4770791431/Detection+Apps+Known+Issues) · per-telltale THRE pages, e.g. [g-ip-connection-type-velocity-short-term-abuse-wifi](https://arkoselabs.atlassian.net/wiki/spaces/THRE/pages/4758208705/g-ip-connection-type-velocity-short-term-abuse-wifi)

# Appendix — Keys with ≥ 1k sessions/hour and no per-CT threshold (snapshot 2026/10/15/00 UTC)

Restricted: customer key names. Point-in-time. Re-run `queries/ct_threshold_coverage.sql` before acting.

| Public key | Key name | Sessions/h | ip-only short-term threshold |
| --- | --- | --- | --- |
| 30000F36-CADF-490C-929A-C6A7DD8B33C4 | Uber - SMS - Production - Key 1 | 375,102 | 20 |
| A2A14B1D-1AF3-C791-9BBC-EE33CC7A0A6F | Roblox Signup - Key 2 | 181,211 | 35 |
| 943697A4-B3EC-4F26-9AB6-62CC4BDFCA79 | Wells Fargo - Prod/Detect - Login - Mobile - Key 3 | 141,063 | 150 |
| B0217B00-2CA4-41CC-925D-1EEB57BFFC2F | WBD Bolt/Beam - Login - Production - Key 8 | 69,161 | 80 |
| 1A413285-A58D-4629-A9FD-B77170BBCBCE | theLott - Login - Production - Key 2 | 68,193 | 15 |
| 476068BF-9607-4799-B53D-966BE98E2B81 | Roblox - Production - Login - Key 1 | 65,762 | 550 |
| CC30DB96-0C88-4DEB-86E5-6601927ACBB4 | Roblox - Prod - Game Join - Key 6 | 64,297 | 70 |
| 7A946A46-88B6-40F4-9A8E-7286D122B384 | WBD Bolt/Beam - Account Lookup - Production - Key 20 | 54,638 | 300 |
| B7D8911C-5CC8-A9A3-35B0-554ACEE604DA | Microsoft - Identity - Account Signup - Production - Key 2 | 50,387 | 150 |
| 2EAD3543-36DC-4A77-90E1-F3AE6B16CF16 | New-Synthetics-Key (Arkose QA) | 48,716 | 300 |
| 1B154715-ACB4-2706-19ED-0DC7E3F7D855 | Roblox - Production - Monetization - Key 4 | 33,121 | 75 |
| 5B6F3411-4A78-4EC2-9223-16001F3B3E68 | HPID - Production - Returning Users - Key 1 | 30,599 | 60 |
| A0C1F8BD-F49D-47A8-85F8-F93D9F11E898 | AT&T - Consumer Forgot Password - Production - Key 2 | 27,943 | 57 |
| 8A1EAD4C-ABA1-4A1D-87DD-87521C761AF4 | Microsoft Azure - Production - Key 1 (no RTA) | 24,439 | — |
| 626ED8CB-A366-467A-974A-E5A3B2A1C542 | WBD Bolt/Beam - Registration - Production - Key 9 | 22,450 | 30 |
| 63E4117F-E727-42B4-6DAA-C8448E9B137F | Roblox - Production - Other - Key 3 | 13,085 | 75 |
| 56EBEF67-2E0F-4B78-BE92-AF54FBC411C8 | Adobe - ARP FF - Development - Key 8 | 9,246 | 300 |
| 6B5C1BA5-E301-4C1E-A167-AA71FF7EDB42 | WCA - Dev/Detect - Vantage Login - Web - Key 10 | 6,805 | 300 |
| DB4DC857-0913-46C5-8D96-E7EF9FBB83B2 | Wells Fargo - Prod/Detect - Password Reset - Web - Key 5 | 6,341 | 25 |
| FEC00DE9-743E-4B59-8182-B5E1C5E8F210 | Adobe - Sign-in - Development - Key 5 | 5,945 | 300 |
| B8BDED1B-BA3C-492B-AEDB-016DDA3E4837 | BEXG - Production - OTP - Key 5 | 5,042 | 15 |
| D4EC8D04-608C-483B-8841-5D69FA1A7001 | WBD Multi-Tenant - Login - Production - Key 18 | 4,619 | 30 |
| 9E720074-0602-42DD-B539-FAEA47262462 | Airbnb - Account create - Production Key 3 | 4,390 | 10 |
| 9F6770A0-50F0-45DE-AFC2-EABC625B1049 | Amazon Prime Credit - Development - Dev 3 | 4,254 | 300 |
| D1632BAF-6E1B-46C9-9FCF-EC19B49A4B4F | Match - Registration - Production - Key 2 | 4,100 | 15 |
| EBC0462E-1FD4-25CD-A21E-A68A0E5DDB23 | Tinder - Production - Mobile - Key 2 | 4,073 | 15 |
| 9D83AB3F-2484-41B6-AE99-634F749C2D87 | AT&T - Cricket Login Web - Production - Key 13 | 3,439 | 35 |
| 6E7F820D-4A08-446C-85AE-3FA0601853FE | HPID - Production - New Users - Key 2 | 3,304 | 15 |
| 12542EDB-1782-4932-A841-D2D21B6BBB9C | WBD Bolt/Beam - Password Reset - Production - Key 10 | 3,036 | 30 |
| EDCF26A3-C27C-45AC-9DFB-33B5C8A0E893 | Wells Fargo - Prod/Detect - Online Enrollment - Web - Key 8 | 2,988 | 30 |
| 4464DBBF-69BA-467C-A632-15BC005D7943 | WBD Multi-Tenant - Reg/PW Reset - Production - Key 19 | 2,661 | 30 |
| 414D40C4-4D7E-43E1-A6C8-7A59F079DA87 | Wells Fargo - Prod/Detect - Consumer Deposits - Web - Key 9 | 2,655 | 35 |
| 852AF3F3-77B8-478D-85E9-45039143E640 | Airbnb - Account login - Production Key 2 | 2,429 | 15 |
| E8A75615-1CBA-5DFF-8032-D16BCF234E10 | Blizzard - Production - ROW Registration - Key 2 | 2,225 | 15 |
| 4AB70A00-4D5E-4305-A161-A7231CCEBFE8 | DoorDash - Storefront - Production - Key 6 | 2,025 | 11 |
| B993466D-3658-48FF-B423-60E645D3543B | AT&T - FirstNet ILM - Production - Key 6 | 1,908 | 40 |
| 25C68761-85CB-4649-A8EB-E64FABF20A4D | theLott - Registration - Production - Key 1 | 1,907 | 10 |
| CDB38584-ABDB-4342-BCED-6F5067CBC8DC | Sony - Production - Key 2 - Support Chat and Form | 1,858 | 30 |
| FB58AF3E-E7BE-4AF8-BB16-E7CDB94CADCF | Vrbo - Production - OTP - Key 11 | 1,831 | 15 |
| 09CB1E22-0FB7-4AD8-957C-4F06CAFB3C7E | WBD - FUSE/Konto - Login - Production - Key 3 | 1,813 | 40 |
| 07071A28-2099-0596-6DA4-8CCD9C580290 | Hellosign - Production - Login | 1,804 | 15 |
| 342FE9D0-4049-4BCD-B32D-1FA3FFD5FC23 | WBD - FUSE/Konto - Lookup - Production - Key 5 | 1,680 | 25 |
| 1AB5BA5D-B967-9EAE-11CB-FDF69411C3D8 | HPID Dev Key 1 | 1,644 | 300 |
| F4856F24-1FA6-4A6E-B1CB-0E42B31A4CC1 | Vrbo - Production - Native App - OTP - Key 19 | 1,619 | 15 |
| F7B5AE6C-E684-9B4C-50B0-9839F6BF8FC2 | Hcom - Production - OTP - Key 7 | 1,496 | 15 |
| 6EE1DA30-0503-4FE8-824C-EAA5E778489E | TIAA - Login - Mobile - Production - Key 2 | 1,436 | 15 |
| 39ECB367-9FDE-4306-9788-EC0D7E67AB5C | Coinbase - Sign In - Dev - Key 3 | 1,304 | 300 |
| 776F96B5-6F1A-91FF-5642-5E47D86C40CF | BEXG - Production - Native App - Login - Key 14 | 1,268 | 15 |
| 03CB9CF0-EE31-41F9-A4B7-E57FD94373C5 | Coinbase - SMS - Prod - Key 1 | 1,262 | 15 |
| FE504504-DBA3-4C39-BC89-C87CDA6FB562 | HPID - Production - SMS - Key 4 | 1,241 | 15 |
| F60BEA2C-109F-4BA0-BC9F-61D889C14FB0 | WBD Multi-Tenant - Payment - Production - Key 15 | 1,214 | 15 |
| 72361606-06A8-445C-A3D0-9FB07DB14610 | CNN - Lookup - Prod - Key 29 | 1,175 | 300 |
| FDA64B05-5306-4D8F-862D-DC8BA7AFDF1E | Dropbox - Production - PasswordReset - Key 10 | 1,070 | 20 |
| 93568CD9-0A26-477F-80A2-5C7C808875FA | Hcom - Production - Native App - OTP - Key 17 | 1,053 | 15 |
| E191DADD-00A4-46D9-BC38-89721CB34BC7 | Coinbase - Email Verification - Prod - Key 2 | 1,020 | 15 |
| 3C5073B0-3106-423D-8D6B-81FE82CF5C2C | Wells Fargo - Dev/Detect - Login - Web - Key 1 | 1,019 | 10 |
| 95218C8B-B84E-413C-B875-785B35F92134 | WBD Dalton - Reg/PW Reset/Payment/Card Update - Production - Key 17 | 1,012 | 100 |
