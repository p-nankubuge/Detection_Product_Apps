# IP Connection-Type Velocity — SOC Implementation & Support Guide

**Status:** DRAFT for SOC enablement · **Author:** Patricia Nankubuge · **Data as of:** 15 Oct 2026
**Confluence:** https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4771381280
**Companion to:** [Residential Proxy IP — SOC Implementation & Support Guide](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4707778564)
**Live key list:** [IP CT threshold coverage by key — account, key, which TTs to use](https://superset-snowflake-green.production-blue.us-east-2.internal.services.aws.arkoselabs.com/explore/?slice_id=31923) (on the [IP Velocity Connection Type dashboard](https://superset-snowflake-green.production-blue.us-east-2.internal.services.aws.arkoselabs.com/superset/dashboard/1663/))

---

# What it is

IP velocity now has **a separate threshold for each connection type** on each key: `wifi`, `wired`,
`mobile`, `nat`, `satellite` and `dialup`. Each threshold is learned automatically from that key's
own traffic, so a mobile IP is compared with the key's mobile baseline and a wired IP with its
wired baseline.

The thresholds drive a new set of global telltales, `g-ip-connection-type-velocity-*` ("CT
telltales"). The existing IP velocity telltales, `g-ip-velocity-*` ("legacy IP velocity
telltales"), stay in place and use the single IP threshold as before.

# Why we changed it

- **One threshold could not fit every IP.** Shared infrastructure (mobile carrier CGNAT,
  corporate NAT, satellite, university and public Wi-Fi) legitimately sends many sessions from one
  IP. A single threshold either flagged those real users or had to be raised until it missed
  abuse from residential and wired IPs.
- **It produced a steady stream of FP tickets and manual overrides.** HP (ESM-5858), Wells Fargo
  (ESM-6148, ESM-5892, ESM-6544), Roblox (ESM-6296), AT&T (ESM-6297), Coursera (ESM-6291), Bumble
  (ESM-6360) and Agoda (ESM-5631). Roblox showed it most clearly: South-East Asian mobile carriers
  had high but legitimate velocity, well above the auto-set threshold.
- **The hand-built connection-type telltales (CHNGE-5096) were static** and did not adapt to
  traffic changes. The built-in thresholds replace them.

Background: [Proposal: IP Velocity Auto-Thresholding Improvements](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4259348630),
[Per-Connection-Type IP Velocity Thresholds Implementation Overview](https://arkoselabs.atlassian.net/wiki/spaces/EN/pages/4320722948).

---

# How to use it

## Step 1 — Look up the key

Open the [coverage chart](https://superset-snowflake-green.production-blue.us-east-2.internal.services.aws.arkoselabs.com/explore/?slice_id=31923)
and search for the account, key name or public key. It refreshes on yesterday's traffic and shows,
for each key:

| Column | What it tells you |
| --- | --- |
| **CT coverage** | `FULL`, `PARTIAL` or `NONE` (see Step 2) |
| **Use telltales** | Which IP velocity telltales to use on this key |
| **% sessions with CT threshold** | Share of the key's sessions that a CT threshold applied to |
| **CTs with threshold / CTs without threshold** | Which connection types are covered |
| **IP short-term threshold** | The single legacy IP threshold, for comparison |

## Step 2 — Use the right telltales for the key

| CT coverage | Meaning | Use | Don't use |
| --- | --- | --- | --- |
| **FULL** | 90% or more of the key's sessions have a CT threshold | **CT telltales** (`g-ip-connection-type-velocity-*`). The legacy IP velocity telltales can be disabled for the key once the CT telltales are validated. | — |
| **PARTIAL** | Some connection types have a threshold, others don't | **Both:** CT telltales **and** legacy IP velocity telltales (`g-ip-velocity-*`). The CT telltales fire on the connection types that have a threshold; the legacy telltales cover the rest. | Don't disable the legacy telltales on this key. |
| **NONE** | No connection type has a threshold | **Legacy IP velocity telltales** only | CT telltales (they cannot fire) |

On PARTIAL keys, a session on a covered connection type can fire both a CT telltale and a legacy
telltale. Allow for that when you set pressure, so the two don't add up to more than you intend.

## Step 3 — Pick the CT telltales (FULL and PARTIAL keys)

`...` below = `g-ip-connection-type-velocity-short-term-abuse`. Names are exactly as they are in
Dataswan.

| Connection type | 1x (over threshold) | 1.5x | 2x | 3x |
| --- | --- | --- | --- | --- |
| wifi | `...-wifi` | `...-wifi-15x` ⚠ | `...-wifi-2x` | `...-wifi-3x` |
| wired | `...-wired` | `...-wired-1point5x` | `...-wired-2x` | `...-wired-3x` |
| mobile | `...-mobile` | `...-mobile-1point5x` | `...-mobile-2x` | `...-mobile-3x` |
| nat | `...-nat` | `...-nat-1point5` | `...-nat-2x` | `...-nat-3x` |
| satellite | `...-satellite` | `...-satellite-1point5x` | `...-satellite-2x` | `...-satellite-3x` |
| dialup | — | `...-dialup-1point5` | `...-dialup-2x` | `...-dialup-3x` ⚠ |

Long-term (1x only): `g-ip-connection-type-velocity-long-term-abuse-{wifi, mobile, nat, satellite, wired ⚠}`.

⚠ = still a suspicion flag in Dataswan; THR is promoting it. Don't build on it yet.

Things to know before you build custom telltales:
- **All CT globals have risk score 0** today, so they carry no pressure until it is set.
- **Tiers stack.** Each tier is `ratio > N` with no upper bound, so a session at 3.5x fires 1.5x,
  2x and 3x. Put pressure on one tier, or expect it to add up.
- **Build from the promoted global telltales**, not from the old suspicion-flag versions, which
  stop working.
- They only evaluate at `session_setup` and `game_verify`, and only on keys with globals enabled.

## Step 4 — Suggested enforcement posture (where a CT threshold applies)

| Situation | Recommended posture |
| --- | --- |
| CT 3x on a sensitive flow (login, account creation, payment, OTP/SMS) | Strong candidate for high pressure |
| CT 2x plus a residential proxy, hosting or high-risk-ASN context flag | High-confidence compound; mitigate |
| CT 1.5x on a shared-egress CT (`mobile`, `nat`, `satellite`) | Monitor or step-up only. This is where shared-infrastructure FPs used to happen. |
| CT 1x on `wired` or `wifi` with device inconsistency or automation indicators | Candidate for mitigation, subject to customer tolerance |
| Customer wants stable, fixed thresholds (e.g. Wells Fargo) | Stay on manual IP thresholds and the legacy telltales |

## Step 5 — Investigating an IP velocity flag

1. Check the key in the coverage chart: FULL, PARTIAL or NONE.
2. Confirm which set fired: CT (`g-ip-connection-type-velocity-*`) or legacy (`g-ip-velocity-*`), and which tier.
3. Check the session's `connection_type` and whether `rta__ip_connection_type_velocity_short_term_threshold` is populated.
4. Compare the CT count and threshold with the IP-only count and threshold for the same session.
5. Check the context: `vpn_proxy_type` / `vpn_proxy_description`, `ip_intel__is_proxy_harvested`, ASN risk band, ISP and country.
6. Recommend a pressure, tier or carve-out change. Don't hand-edit CT thresholds; they are recalculated daily.

## Don'ts

- Don't rely on CT telltales for NONE keys; they cannot fire there.
- Don't disable the legacy IP velocity telltales on PARTIAL or NONE keys.
- Don't delete a key's CHNGE-5096 hand-built CT telltales until the key shows **FULL**.
- Don't build on the ⚠ suspicion flags above until THR promotes them.

# Rolling it out to accounts

Rollout starts **week of Monday 26 October 2026**, account by account, with TSE.

## Before 26 October (one-off)

| # | Step | Owner |
| --- | --- | --- |
| 1 | SOC enablement session held; SOC has this page and the coverage chart | Detection |
| 2 | THR promotes `wifi-15x`, `dialup-3x` and `long-term-abuse-wired` and adds the `g-global-telltales-enabled` include | THR |
| 3 | Agree the starting pressure per tier (the CT globals are at risk score 0 today) | Detection + SOC |
| 4 | Agree the account order (waves below) and a TSE owner per account | Detection + TSE |
| 5 | Confirm the CHNGE route: one CHNGE per wave, or per account | Detection + SCOPE |

## Proposed waves

| Wave | Week of | Keys | Why this order |
| --- | --- | --- | --- |
| 1 | 26 Oct | FULL keys already being tested or with CHNGE-5096 telltales: AT&T Consumer Login (`FAD1C7FA`), Pinterest Login (`F5675B21`), Chime Login (`7BA04117`), Blizzard ROW Login (`CF5C61EE`), Citizens OLB (`4455454D`), Coinbase Sign In (`32FBE3BC`), TIAA Login (`942A102E`) | Known traffic, existing dashboards, SOC already familiar |
| 2 | 2 Nov | Remaining FULL keys | Same playbook, higher volume |
| 3 | 9 Nov | PARTIAL keys | Need both sets; more pressure tuning |
| — | Separate track | NONE keys on manual thresholds (Uber SMS, Roblox, HP, AT&T, theLott, WBD, Microsoft). Wells Fargo stays manual. | Must move back to auto-thresholds first; CT thresholds appear only after that |

**DECISION:** confirm the waves and dates with TSE.

## Steps per account

1. **Check coverage.** Look the key up in the coverage chart: tier, CTs with and without a threshold. Re-check the day before go-live.
2. **Pre-checks with TSE:**
   - The key is on IP auto-thresholds and has globals enabled (`g-global-telltales-enabled`).
   - List the key's existing IP velocity telltales: legacy globals with pressure, custom IP velocity telltales, and any CHNGE-5096 hand-built CT telltales.
   - Note anything the customer has asked for (fixed thresholds, a known promotion, contractual limits).
   - Decide whether the customer needs to be told, and who tells them.
3. **Baseline (last 7 days).** Firing counts, pressure and challenge or block rates for the key's current IP velocity telltales, so the change can be compared.
4. **Shadow (2–3 days).** Create the key's custom CT telltales from the globals with **no pressure**. Compare their firing with the legacy telltales, and check verify rates, ISPs and connection types on what they catch.
5. **Raise the CHNGE.** Include:
   - the CT telltales and tiers to pressure, with values;
   - what happens to legacy: FULL — may be disabled after validation; PARTIAL and NONE — stays on;
   - any CHNGE-5096 telltales to delete (FULL keys only);
   - the rollback (below).
6. **Go live** in the agreed window: put pressure on the chosen CT tier(s).
7. **Monitor.** Check at 24 h, 48 h and 7 days: firing, challenge and solve rates, pressure, FP tickets. TSE confirms with the customer where relevant.
8. **Clean up.** After 7 clean days on a FULL key: disable legacy on the key if agreed, delete its CHNGE-5096 telltales, and mark the account done in the tracker.

**Rollback:** remove pressure from (or disable) the key's custom CT telltales and re-enable anything disabled in step 8. The legacy telltales remain in place throughout, so there is no coverage gap.

## Who does what

| Role | Responsibilities |
| --- | --- |
| **Detection** | Coverage data, telltale definitions, pressure guidance, escalations |
| **SOC** | Shadow telltales, analysis, CHNGE, go-live, monitoring |
| **TSE** | Account readiness, customer context and comms, post-go-live check with the customer |
| **THR** | Global telltale promotion and fixes |

---

# FAQs

## How do I know which public keys have connection-type thresholds, and for which connection types?

Use the [coverage chart](https://superset-snowflake-green.production-blue.us-east-2.internal.services.aws.arkoselabs.com/explore/?slice_id=31923),
or run the saved SQL Lab query [IP CT threshold coverage by key](https://superset-snowflake-green.production-blue.us-east-2.internal.services.aws.arkoselabs.com/sqllab?savedQueryId=1068)
(uncomment the account or public key filter to narrow it).
It lists every key with at least 1,000 `session_setup` sessions yesterday, with account, key name,
coverage tier, which telltales to use, and the connection types with and without a threshold.
Filter by account, key name or public key.

For a custom date range, run the query in the appendix in Superset SQL Lab (database
**Snowflake**).

## How do I check a single session?

Look at `rta__ip_connection_type_velocity_short_term_threshold` on the session.
- **Populated:** a CT threshold applied to that session's connection type, and the CT telltales could fire.
- **Empty:** no CT threshold applied, so only the legacy `g-ip-velocity-*` telltales could fire.

## Can a key have a connection-type threshold today and not have it tomorrow?

**Yes, but it is extremely rare.** Thresholds are recalculated daily (16:00 UTC) from the last 7
days of traffic, and the whole set for the key is replaced on each run. If a connection type's
traffic drops too low, or its learned value falls to 10 or below, that connection type is left out
and falls back to the IP-only threshold. If you're about to make a change on a key, check the chart
the same day.

## Which telltales should I use if a key has some connection types but not others?

**Both.** Use the CT telltales and keep the legacy IP velocity telltales (`g-ip-velocity-*`). The CT
telltales fire where a connection-type threshold exists; the legacy telltales cover the connection
types that don't have one. See Step 2.

## Why do some keys have no connection-type threshold at all?

The per-connection-type thresholds come from the same automated-thresholds job as the global IP
threshold, with the same rules
([automated-thresholds (detection-apps)](https://arkoselabs.atlassian.net/wiki/spaces/DE/pages/4770234382)).
There are four reasons a key gets none:

**1. IP auto-thresholds are disabled for the key (manual thresholds).** The job skips these keys
entirely. Moving them back to auto-thresholds is a prerequisite for CT coverage. Keys with traffic
on 14 Oct (source: [IP Intelligence (RTA) Auto-Thresholds — Enabled vs Disabled — Oct 2026](https://arkoselabs.atlassian.net/wiki/spaces/EN/pages/4748836897)):

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

**2. Auto-thresholds are on, but no connection type learned a usable threshold.** Too little
traffic per connection type, or a learned value of 10 or below. This is expected for lower-volume
keys and keys whose traffic is spread thinly across connection types. Production keys with at
least 5,000 sessions on 14 Oct:

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

**3. Not a production customer key.** Dev, QA and synthetics keys are excluded by design. No action needed.

**4. No RTA threshold at all.** Microsoft Azure - Production - Key 1 (`8A1EAD4C`, about 689k
sessions/day) has no IP-only or CT threshold on any session. **VERIFY:** edge-API key (edge keys
are excluded), or RTA not returning?

## Why does a key have thresholds for some connection types but not others?

Each connection type is learned separately. Connection types with little traffic on that key (often
`satellite`, `dialup`, `nat`, or `absent` when IP intel has no type) don't have enough data, so they
get no threshold. This is why a key can be PARTIAL.

## Are the existing IP short-term and long-term velocity telltales being retired?

No. `g-ip-velocity-short-term-abuse`, `-2x`, `-4x` and the long-term equivalents stay active,
because many keys have no or partial CT coverage. On FULL keys they can be disabled per key once
the CT telltales are validated.

## What happens to the hand-built connection-type telltales from CHNGE-5096?

They will be deleted, per key, once that key shows FULL. Several CHNGE-5096 keys are not FULL today,
so check before deleting:
- HP Returning Users, New Users and SMS;
- all Roblox keys;
- HelloSign Login and Registration;
- WF Login Mobile;
- AT&T Forgot Password, Cricket Login and FirstNet;
- TIAA Mobile;
- Coursera Registration.

## Are there long-term CT telltales?

Yes, at 1x only, for wifi, mobile, nat and satellite. Wired long-term is still a suspicion flag.
There is no dialup long-term and there are no long-term 1.5x/2x/3x tiers yet. The short-term set
was built first.

## Why are some telltale names inconsistent?

They were created at different times. As they are in Dataswan: `mobile-1point5x` (not
`mobile-1.5x` as posted in Slack), `nat-1point5` and `dialup-1point5` (no trailing `x`), and
`wifi-15x`. Always copy names from Dataswan.

## Which fields do the CT telltales use?

| Field | Meaning | Populated when |
| --- | --- | --- |
| `connection_type` | IP Intelligence connection type of the session IP | IP-intel lookup succeeded |
| `rta__ip_connection_type_velocity_short_term_count` | Sessions from this IP **on this connection type** in the short window (~40 min) | Always |
| `rta__ip_connection_type_velocity_long_term_count` | Same, for the long window (~48 h) | Always |
| `rta__ip_connection_type_velocity_short_term_threshold` | The key's CT short-term threshold applied to this session | Only when a CT threshold exists for this key + connection type |
| `rta__ip_connection_type_velocity_long_term_threshold` | The key's CT long-term threshold | Same as above |
| `rta__ip_connection_type_velocity_short_term_ratio` | `count ÷ threshold`. Above 1.0 means over threshold. The 1.5x/2x/3x telltales use this. | Same as above |
| `rta__ip_connection_type_velocity_long_term_ratio` | Same, for the long term | Same as above |
| `rta_ip_velocity_*` | Legacy IP-only velocity, unchanged | As before |

## How are the CT thresholds calculated?

- RTA counts every request twice: in the existing `{ip}` bucket and in a new
  `{ip, connection_type}` bucket. A CT count only includes that IP's traffic on that connection
  type.
- The detection-apps automated-thresholds job runs daily at 16:00 UTC. It runs the same circadian
  model as the global IP threshold, once per (key, connection type), over 7 days of data.
- It writes `short_term = T` and `long_term = 96 × T` for each connection type.

**VERIFY:** the global IP long-term threshold is `5 × short-term`, so CT long-term thresholds are
much looser relative to short-term. Confirm with Detection Engineering before SOC sets pressure on
the CT long-term telltales.

## What are the context suspicion flags (shared-egress carve-out, harvested proxy, hosting, cloud ASN, high-risk ASN)?

Added on 14 Oct under DETCORE-4371. They are not promoted to telltales yet, but are useful during
investigation.

| Suspicion flag | Logic |
| --- | --- |
| `...-{wifi,wired,mobile,nat,satellite}-sf-shared-egress-carveout` | Over the CT threshold. If `vpn_proxy_type` is `consumer-privacy`, `corporate`, `edu` or `public`, it only fires above 3x. |
| `...-harvested-proxy` | `ip_intel__is_proxy_harvested` and ratio > 0.5 (CT ratio, or IP-only ratio as a fallback) |
| `...-hosting` | DE `hosting` (excluding vpn, cloud-security, web-browser) and ratio > 0.5, same fallback |
| `...-hosting-vpn` | DE `hosting` + `vpn` and ratio > 0.5, same fallback |
| `...-cloud-asn` | Google, AWS or Microsoft cloud ASN not typed by DE, and ratio > 0.5, same fallback |
| `...-high-risk-asn` | ASN `risk_band = High` and ratio > 1.0, same fallback |

## A customer reports FPs on mobile or NAT traffic. What do I do?

If a CT telltale fired, check which tier. For shared-egress connection types, put pressure on 2x or
3x only, or use the `sf-shared-egress-carveout` variant once promoted. If a legacy telltale fired
(NONE keys, or uncovered connection types on PARTIAL keys), follow the
[IP Velocity FP Triage workflow](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4287430702).

## The CT threshold looks wrong or too low. What do I do?

Check for a promotion or traffic change in the last 7 days (the training window). Escalate to
Detection with the key, the connection type and the dates.

## Which keys were FULL and PARTIAL on 14 Oct?

Snapshot only. Use the coverage chart for current values.

**FULL (30 keys with at least 5,000 sessions):**

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

**PARTIAL (39 keys with at least 5,000 sessions) — use CT and legacy IP velocity telltales:**

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

## What is still open?

| Item | Owner | Type |
| --- | --- | --- |
| Promote `wifi-15x`, `dialup-3x` and `long-term-abuse-wired` to telltales and add the `g-global-telltales-enabled` include | THR | Action |
| CT long-term threshold is 96× short-term vs 5× for the global IP threshold — intended? | Detection Eng | VERIFY |
| Keep the 1.5x/2x/3x tiers stacking, or band them like the legacy set? | THR | DECISION |
| Several keys sit on an IP short-term threshold of exactly 300 (WBD Account Lookup, TVN, CNN, Games PN, Hornet, Alienvault, Citizens CPay, WCA Hosted Login, CTM UK WhiteLabel) — default or manual? | Detection | VERIFY |
| Microsoft Azure Key 1 has no RTA threshold — edge key or RTA issue? | Detection | VERIFY |
| Make IP velocity self-selecting: add `rta__ip_connection_type_velocity_short_term_threshold NOT_EXISTS` to the legacy `g-ip-velocity-*` telltales. The field is set per session, so legacy would fire only on sessions whose connection type has no CT threshold (e.g. wired, NAT, satellite on a key covered only for wifi and mobile). Removes per-key choices and double-firing. Not in scope for this rollout. | THR / Detection | Pending |
| Context on keys on manual thresholds with no ticket (WBD, theLott, Roblox account exclusion, X, Microsoft) | SOC | Action |

---

# Related Jira and References

- **DETCORE-4081 / 4082 / 4083 / 4084 / 4085:** conf-api storage, RTA compound cube, detection-hub emit and compute, detection-apps per-CT training.
- **DETCORE-4293:** 1x CT telltales. **DETCORE-4371:** multiplier tiers and context suspicion flags. **THR-1173:** CT global telltale write-ups (THRE space).
- **CHNGE-5096:** hand-built per-CT telltales, to be removed per key. **DETCORE-3854:** valley bug in the circadian threshold picker.
- **ESM tickets:** ESM-5858, ESM-6148, ESM-5892, ESM-6544, ESM-6296, ESM-6297, ESM-6291, ESM-6360, ESM-5631, ESM-3010.
- **CHNGE tickets:** CHNGE-4419, CHNGE-4516, CHNGE-4465, CHNGE-4749, CHNGE-4760, CHNGE-4750, CHNGE-4772.

**Confluence pages:**
- [Proposal: IP Velocity Auto-Thresholding Improvements](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4259348630)
- [Per-Connection-Type IP Velocity Thresholds Implementation Overview](https://arkoselabs.atlassian.net/wiki/spaces/EN/pages/4320722948)
- [automated-thresholds (detection-apps)](https://arkoselabs.atlassian.net/wiki/spaces/DE/pages/4770234382)
- [IP Velocity FP Triage: Connection-Type Analysis Workflow for SOC](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4287430702)
- [IP Intelligence (RTA) Auto-Thresholds — Enabled vs Disabled — Oct 2026](https://arkoselabs.atlassian.net/wiki/spaces/EN/pages/4748836897)

**Dashboard:** [IP Velocity Connection Type (Superset 1663)](https://superset-snowflake-green.production-blue.us-east-2.internal.services.aws.arkoselabs.com/superset/dashboard/1663/)

---

# Appendix — coverage query

Same SQL as the coverage chart and the [saved SQL Lab query](https://superset-snowflake-green.production-blue.us-east-2.internal.services.aws.arkoselabs.com/sqllab?savedQueryId=1068). Run in Superset SQL Lab (database **Snowflake**).

```sql
-- IP connection-type (CT) velocity threshold coverage, per key.
--
-- Answers: "does this key have connection-type thresholds, and which IP
-- velocity telltales should SOC use on it?" A key+CT has a threshold only when
-- detection-apps (automated-thresholds cron, daily 16:00 UTC) has written one
-- to conf-api. When it has, detection-hub populates
-- rta__ip_connection_type_velocity_short_term_threshold on the session. When it
-- has not, that field (and the CT ratio fields) are empty and the
-- g-ip-connection-type-velocity-* telltales cannot fire for that session.
--
-- Same SQL as the Superset saved query 1068 and the dataset
-- "ip_ct_threshold_coverage_by_key_v3" behind chart 31923 (dashboard 1663).
-- Written without CTEs because Superset could not wrap the WITH version.
-- Run in Superset SQL Lab against the "Snowflake" database (id 14).
-- Change the date window, or uncomment a filter, as needed.
--
-- coverage_tier / use_telltales:
--   FULL    >= 90% of sessions have a CT threshold -> CT telltales (legacy optional)
--   PARTIAL 1-89%                                  -> CT telltales + legacy IP velocity telltales
--   NONE    0%                                     -> legacy IP velocity telltales only

SELECT
  k.account_name,
  k.name AS key_name,
  a.public_key,
  a.coverage_tier,
  CASE WHEN a.coverage_tier = 'NONE' THEN 'Legacy IP velocity TTs only'
       WHEN a.coverage_tier = 'PARTIAL' THEN 'CT TTs + legacy IP velocity TTs'
       ELSE 'CT TTs (legacy optional)' END AS use_telltales,
  a.pct_ct_covered,
  a.sessions,
  a.cts_with_threshold,
  a.cts_without_threshold,
  a.ip_short_term_threshold,
  k.key_type_name AS key_type
FROM (
  SELECT
    p.public_key,
    SUM(p.sessions) AS sessions,
    ROUND(100 * SUM(p.sessions_with_ct_threshold) / SUM(p.sessions), 1) AS pct_ct_covered,
    CASE WHEN SUM(p.sessions_with_ct_threshold) = 0 THEN 'NONE'
         WHEN SUM(p.sessions_with_ct_threshold) >= 0.9 * SUM(p.sessions) THEN 'FULL'
         ELSE 'PARTIAL' END AS coverage_tier,
    LISTAGG(CASE WHEN p.sessions_with_ct_threshold > 0 THEN p.ct END, ', ') WITHIN GROUP (ORDER BY p.sessions DESC) AS cts_with_threshold,
    LISTAGG(CASE WHEN p.sessions_with_ct_threshold = 0 THEN p.ct END, ', ') WITHIN GROUP (ORDER BY p.sessions DESC) AS cts_without_threshold,
    MAX(p.ip_threshold) AS ip_short_term_threshold
  FROM (
    SELECT
      public_key,
      COALESCE(connection_type, 'absent') AS ct,
      COUNT(*) AS sessions,
      COUNT(rta__ip_connection_type_velocity_short_term_threshold) AS sessions_with_ct_threshold,
      MAX(rta_ip_velocity_short_term_threshold) AS ip_threshold
    FROM events.events_log
    WHERE timestamp >= DATEADD(day, -1, CURRENT_DATE)
      AND timestamp < CURRENT_DATE
      AND location = 'session_setup'
      AND public_key IS NOT NULL
      -- AND public_key = '<PUBLIC_KEY>'
    GROUP BY 1, 2
  ) p
  GROUP BY 1
  HAVING SUM(p.sessions) >= 1000
) a
LEFT JOIN dataswan.customer_keys k
  ON UPPER(k.public_key) = UPPER(a.public_key)
-- WHERE k.account_name ILIKE '%pinterest%'
ORDER BY a.sessions DESC
```
