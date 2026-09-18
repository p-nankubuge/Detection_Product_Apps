# BRE criteria v2 — proposed gates and scored signals

Proposal to replace the design doc's two binary conditions (§2.1) with three hard gates plus
a weighted scorecard. Every threshold here is derived from the 2026-09-18 14-day run
([`bre-14day-analysis-2026-09-18.md`](bre-14day-analysis-2026-09-18.md)), not from assumption.

**Status: proposal for team review. Nothing applied. Weights are a first pass and need
validating against a labelled set before any telltale is built on them.**

Why scoring rather than gating: in this window every candidate signal is defeated by at least
one confirmed tool — Cypress defeats WebGL and dictionary, Go-http-client defeats
`ip_diversity`, KorbytPlayer defeats verification rate, CaptchaBotRS defeats ASN concentration.
No single gate survives contact with the full set.

---

## 1. Hard gates

Three, and only three. A gate excludes a browser from scoring entirely — it is not evidence of
innocence, it means the data cannot support a verdict.

| # | Gate | Why it is a gate, not a signal |
|---|---|---|
| **G1** | `total_sessions >= 50` over the 14-day window | The doc's own Tier-2 floor (§3.2). Below this, every ratio is noise. Keep it at 50, not 1,000: three of the seven browsers flagged in the 2026-09-18 run sat below 1,000 sessions. |
| **G2** | `sessions_verify_attempted > 0` | A browser that never reaches verify cannot be assessed on solve behaviour. This gate alone removes both false positives from the last run — **KorbytPlayer** (0 attempts / 497 sessions, resolved to Adobe signage behind Zscaler) and **KakaoTalk** (0 / 76). Without it, "0% verification rate" conflates "fails every challenge" with "never challenged". |
| **G3** | `mega-browser exclusion` — the ~10 highest-volume browsers are ruled out on `country_count >= 200`, not scored | Purely a cost measure: exact `COUNT(DISTINCT user_ip)` over Chrome-scale groups cannot finish inside the query budget. All ten read 236–244 countries and 44–80% verification, so Condition B's country clause excludes them anyway. Re-derive the list each run; do not hardcode it as permanent. |
| **G4** | `PUBLIC_KEY_CATEGORY = 'Production'` | **The single highest-impact gate.** Development, Internal Test and client_poc keys generate exactly the library traffic the scorecard is built to find — Postman, Apache HTTP Client, Node Fetch, Resty, Unirest are what integration testing looks like. Without this gate the output is dominated by our own and our customers' test harnesses. Category distribution (1 day): Production 106.6M sessions / 235 keys · Internal Test 1.17M / 15 · Development 1.03M / 162 · client_poc 160K / 4. |

**Deliberately not gates** (and previously proposed as such, wrongly):

- `ip_diversity < 0.001` — as a gate it misses Go-http-client (0.0022), the largest non-browser
  on the platform. Demoted to a scored signal, where it becomes the clause that catches Cypress.
- `verification_rate < 1%` — replaced entirely by the attempt/pass decomposition below.
- `ja4_concentration > 0.8` — no browser in the population satisfied all three clauses of
  Condition B at this threshold, so Condition B had zero hits. Re-baselined and demoted.
- `is_hosting_provider` / `is_proxy` — Zscaler corporate egress reads as 100% on both. Never a
  gate, and weak even as a signal.

---

## 2. Scored signals

Applied only to browsers passing G1–G3. Suggested review threshold: **score >= 8**.

| Signal | Condition | Pts | What it catches | Known blind spot |
|---|---|---|---|---|
| **S1 — no renderer** | `webgl_hash_count = 0` | **3** | The whole HTTP-library class: Resty, Unirest, Apache HTTP Client, Node Fetch, Postman Desktop, JavaFX, CaptchaBotRS | Electron/embedded apps report 0 too (Slack, Discord, OpenFin). Never fires alone at threshold 8. |
| **S2 — concentrated infrastructure** | `ip_diversity < 0.001` | **3** | Cypress (0.000636), Resty (0.000231), Unirest (0.000305) | Misses Go-http-client (0.0022) — volume-normalised, so it drifts as traffic grows |
| **S3 — crude bot** | `attempt_rate >= 50% AND pass_rate < 1%` | **3** | Go-http-client (99.97% attempt, 0.0% pass) | Nothing else in this window |
| **S4 — never trusted** | `>= 95%` of sessions in dictionary bands `{1,3}` | **2** | Corroborates the library class (all at exactly 100%) | **Novelty, not badness — see §4.** Downgraded from 3 to 2. |
| **S5 — trusted tool / solve farm** | `pass_rate >= 99% AND attempted >= 500` | **2** | Cypress, Resty, Unirest — the P2 class that raw verification rate hides | The `attempted >= 500` floor is what stops tiny-sample 100%s flooding it |
| **S6 — TLS homogeneity** | `ja4_concentration_ratio >= 0.65` | **2** | Go-http-client (1.000), Postman (0.943), De Standaard (1.000), JavaFX (0.750), Cypress (0.691) | Misses Apache HTTP Client (0.445) and Node Fetch (0.402) — Java/Node TLS stacks vary |
| **S7 — account spread** | `account_count >= 5` | **1** | Scanner-shaped rather than integration-shaped. **Count accounts, not keys** — keys are sub-account, so one customer with 18 keys is still one customer. Cypress: 18 production keys but 9 accounts. Atom: 43 keys, 26 accounts. | Popular legitimate clients also span accounts |
| **S8 — no satellite at volume** | `satellite = 0 AND sessions >= 10000` | **1** | Confirming only | Several tool-shaped clients do have satellite sessions (Herma 54/54, JavaFX 5, CaptchaBotRS 12) |
| **S9 — no DI match** | `> 50%` of sessions at dictionary `-1` | **1** | Nokia Browser (98.5%), Palm Pre (100%) | Small populations only |

Threshold rationale: at `>= 8`, all four previously-listed tools score, and the two confirmed
false positives from the last run are gated out by G2 rather than needing a threshold.

---

## 2a. Routing: global classification vs account-level assessment

A browser is only a *global* classification problem if it appears across many accounts. If it is
concentrated on one or two, it is an account-level matter and belongs in the Tier-2 alert (§3),
not on a global telltale list — no global list entry should be created from single-account
evidence. Account count, not key count, is the dimension: keys are sub-account.

| Account spread (Production keys) | Route | This window |
|---|---|---|
| **1–2 accounts** | Account-level only. Tier-2 alert + account team conversation. | Resty (HP Inc) · De Standaard (Chime) · BAND · StreamMasterPro · OpenFin |
| **3–8 accounts** | Account-level per account, watch for global promotion | CaptchaBotRS (6) · JavaFX (4) · Avic (3) |
| **9+ accounts** | Global candidate — assess on browser-level signals | Cypress (9) · Yandex (11) · *Atom (26) and CrosswalkApp (15) — both cleared* |

## 3. Ranked output, Production keys only, by account

Restricting to `PUBLIC_KEY_CATEGORY = 'Production'` removes most of the previous list:

| Browser | Prod sessions | Keys | **Accounts** | WebGL | ip_div | Attempt | Pass | Verdict |
|---|---|---|---|---|---|---|---|---|
| **Cypress** | 55,784 | 18 | **9** | 14 | 0.000986 | 93.9% | 100% | Customer E2E suites. Global candidate but benign; per-account enforcement call |
| ~~Atom~~ | 51,884 | 43 | **26** | 2,164 | 0.641 | 32.1% | 99.98% | **Cleared** — 26 accounts, 2,164 WebGL hashes, 262 satellite |
| ~~CrosswalkApp~~ | 39,705 | 19 | **15** | 475 | 0.051 | 78.4% | 99.91% | **Cleared** — 15 accounts, diverse |
| **Resty** | 20,278 | 1 | **1** (HP Inc) | 0 | 0.000789 | **0.05%** | 0.0% | Account-level. Profile inverts vs dev key — barely attempts on production |
| **CaptchaBotRS** | 1,346 | 6 | **6** | 0 | 0.918 | 27.9% | 4.79% | Strongest genuine candidate: non-renderer, 6 accounts, residential-shaped |
| **Yandex** | 375 | 12 | **11** | 0 | 0.136 | 62.1% | 100% | Non-renderer across 11 accounts — investigate |
| **JavaFX** | 264 | 4 | **4** | 0 | 0.723 | 89.4% | 99.6% | Microsoft Identity signup + 3 others |
| **De Standaard** | 149 | 1 | **1** (Chime) | 0 | 1.0 | 100% | 100% | Account-level. Newspaper UA on a fintech login |
| OpenFin / Avic / BAND / StreamMasterPro | 62–261 | 1–4 | 1–3 | 0 | 0.08–0.70 | 11–100% | 100% | Low volume, account-level |

**Dropped entirely by G4** (all were Development or Internal Test): **Go-http-client**,
Apache HTTP Client, Node Fetch, Postman Desktop, Unirest for Java.

### Go-http-client is internal test traffic

The design doc's flagship P1 example — "16.2M sessions, 12th biggest browser globally, no
enforcement" — resolves to two **Internal Test** keys:
`2EAD3543-36DC-4A77-90E1-F3AE6B16CF16` (16,562,798 sessions, **exactly one browser name**) and
`F75933C8-8431-44C7-B6BB-4631062FB963` (160,836, one browser). On Production keys it has
essentially no traffic.

It is not a customer-facing threat and should not carry a global telltale. The 0.0003%
verification rate that made it look like the clearest bot on the platform is what synthetic load
testing looks like. Worth raising separately: 16.5M internal-test sessions in 14 days is ~1.3% of
all platform traffic and distorts any global aggregate that doesn't filter on key category.

### Attribution caveat, resolved

`CUSTOMER_KEYS` (427 rows) covers Production keys completely — `keys_unresolved = 0` for every
browser above. The unresolved keys in the earlier pass were *all* Development or Internal Test.
So the earlier worry about incomplete attribution was an artifact of not filtering on G4.

## 3b. Superseded ranked output (pre-G4, retained for traceability)

| Score | Browser | Sessions | Top accounts | Read |
|---|---|---|---|---|
| **14** | **Resty** | 142,609 | unresolved key `1AB5BA5D` (114,358) · **HP Inc** HPID Production (20,308) | Server-side integration, incl. a real customer's |
| **13** | **Unirest for Java** | 6,565 | **HP Inc** HPID Production (4,513) · `1AB5BA5D` (2,055) | Same shape as Resty, same accounts |
| **10** | **Go-http-client** | 16,721,140 | unresolved `2EAD3543` (16,564,302) · `F75933C8` (160,853) | The one unambiguous abuse case at scale |
| **9** | **Cypress** | 191,774 | unresolved `C1C9EC22` (74,492) · **DoorDash** (26,566) · **Expedia Identity** (20,653) | Customers' own E2E test suites hitting production |
| **8** | **Apache HTTP Client** | 9,644 | `1AB5BA5D` (9,642) | Same key as Resty/Unirest/Postman |
| **8** | **Node Fetch** | 689 | unresolved `91CD54F4`, `D909D9E5` | Library |
| **8** | **Postman Desktop** | 387 | `1AB5BA5D` (373) · **HP Inc** (14) | API client |
| **8** | **De Standaard** | 149 | **Chime** — Production Key 1, Login | **Investigate.** Belgian newspaper UA on a fintech login. 1 key, 1 ASN, 0 WebGL, JA4 conc 1.000, 100% dict band 1 |
| **8** | **JavaFX** | 264 | **Microsoft – Identity**, Account Signup Production Key 2 (254) | **Investigate.** 0 WebGL on an account-signup key, 88 ASNs |
| **8** | ~~CrosswalkApp~~ | 39,703 | **Roblox** Production Login (37,776) | **False positive** — see §4 |
| 7 | Galeon | 558 | not resolved | Dead browser, JA4 0.989 |
| 6 | Atom | 51,924 | **Roblox** Production Login (48,804) · Gtop100 · Pinterest | **False positive** — 2,221 JA4 hashes, 2,688 ASNs |
| 6 | Puffin Cloud Browser | 41,227 | 17 keys | Cloud-rendered by design; 1 WebGL hash is expected |

### The `1AB5BA5D-B967-9EAE-11CB-FDF69411C3D8` finding

One key carries **four** separately-flagged browsers: Resty (114,358), Apache HTTP Client
(9,642), Unirest for Java (2,055), Postman Desktop (373), plus Go-http-client (185). That is
almost certainly one integration or test harness emitting several library user-agents, not five
independent threats. It is the single highest-value investigation target from this run, and it
argues that **attribution should happen before listing** — four list entries collapse into one
conversation.

`5B6F3411` (**HP Inc**, HPID Production Returning Users Key 1) shows the same pattern at
customer scale: Resty + Unirest + Postman on one production login key.

> **Caveat on attribution.** `ARK_PROD.DATASWAN.CUSTOMER_KEYS` holds only 427 rows, far fewer
> than the keys in production. "Unresolved" means *absent from the Dataswan customer list*, not
> *no owner*. Go-http-client's 16.5M sessions sit on unresolved keys; that is a gap in the
> lookup, not evidence in itself.

---

## 4. What the data changed

**The dictionary signal is a novelty signal, not a bot signal.** At `>= 95%` in bands {1,3} it
fires on ~15 plainly legitimate browsers — Atom, CrosswalkApp, Alipay, Realme Browser, Google
Nest Hub, QQ Browser Lite, Wolvic, Sunrise, UBrowser, Basilisk, Mypal, Flow Browser. Account
resolution confirms it: **Atom and CrosswalkApp are Roblox login traffic**, with 2,221 and 475
distinct WebGL hashes and 2,688 and 780 ASNs respectively. Those are real, diverse users.

The mechanism: a low dictionary band means *this device has not accumulated matches yet*, which
is equally true of a tool and of a niche browser with a small or new user base. Hence weight 2,
never decisive alone. Including band 3 alongside 1 is still correct — it is what catches Resty
(96.0% in band 1, 100% in {1,3}) and Go-http-client, both of which a `dict_max = 1` rule misses
because a handful of band-3 sessions move the max.

**`ip_diversity` should be kept, demoted.** Dropping it (an earlier suggestion in this thread)
would lose Cypress, which no other signal catches: WebGL 24, dictionary band 63, ASN count 23.

**Non-browser is not the same as abusive.** Resty, Unirest and Postman on HP's production login
key, and Cypress on DoorDash's and Expedia's, are customer-side tooling. They belong on a
*classification* list, not an *enforcement* list. Recommend the two-axis split: axis 1 "is it a
browser" (objective, from S1/S4/S6), axis 2 "is the behaviour abusive" (volume, key spread
without an account relationship, account context). Enforcement follows axis 2 only.

---

## 4a. JA4_b / TLS-stack signals (from Sri Alapati's nine logics)

Source: Sri Alapati, Slack DM 2026-03-06. Items #2 and #5 apply directly to BRE. Tested against
1 day of Production traffic by splitting `CDN__JA4_HASH_AT_SESSION_CREATED` on `_` — JA4_b
(part 2) is the cipher-suite hash, which identifies the TLS stack rather than the self-reported
user-agent.

**Measured browser JA4_b baseline (1 day, Production):**

| JA4_b | Top-3 hash for |
|---|---|
| `8daaf6152771` | Chrome 75.4% · Samsung Browser 91.5% · Headless Chrome 72.0% · Chrome Webview 52.5% · Edge 29.3% · Firefox 25.4% · Opera 24.3% |
| `55b375c5d22e` | Safari 64.9% · Mobile Safari 62.7% · Opera 63.2% · Edge 61.5% · Chrome Mobile 54.9% · Firefox 38.0% · **Chrome 20.6%** |
| `5c443a9f7afe` | minor share across most Chromium browsers |

**#5 (cross-verify browser name against JA4_b) does not work between mainstream browsers.**
The worked example was "Chrome claiming `5b57614c22b0`, which is Firefox's cipher hash". In this
data the mainstream browsers share cipher hashes almost completely: `55b375c5d22e` is the top
hash for five different browsers and Firefox's #1, and Chrome legitimately shows 20.6% of its
traffic (12.15M sessions/day) on it. A browser-vs-browser mismatch rule would fire on ~12M
legitimate Chrome sessions daily. Likely cause is TLS 1.3 cipher-order convergence plus possible
CDN normalisation — worth confirming whether the CDN-observed JA4 is less discriminating than a
raw client-side one.

It *does* work in the non-browser direction:
- **CaptchaBotRS** — `8daaf6152771` at 98.75%, a genuine Chrome TLS stack. So it is automation
  driving real Chrome, which explains WebGL 0 alongside a perfect browser TLS fingerprint, and
  why it defeated every aggregate signal in §2.
- **Resty** — `f57a46bbacb6` at 100%, which is Mobile Safari's #3 hash. A Go library presenting
  a Safari cipher hash.

**#2 (is JA4_b a browser stack at all) works, and is the strongest signal found for Cypress.**

| Browser | JA4_b | In browser set? |
|---|---|---|
| **Cypress** | `5d04281c6031` 69.4% · `e8a523a41297` 30.1% | **No** — neither appears in any mainstream browser's top 3 |
| **JavaFX** | `1ce71f0edbb1` · `bd868743f55c` · `a1c778405cf3` | **No** |
| Yandex | `8daaf6152771` 96.8% | Yes (Chrome) — Chromium-based, consistent |
| Puffin Cloud Browser | `8daaf6152771` 100% | Yes (Chrome) — consistent with server-side Chrome rendering |
| Atom / CrosswalkApp | Chrome hashes, mixed | Yes — further confirms both are Chromium shells, not tools |
| Nintendo Browser | `700b5f71ebac` 99.05% | **No — but legitimate.** False positive risk |

Cypress defeated S1 (WebGL 14), S4 (dictionary band 63) and S6 (JA4 concentration 0.691). Its
TLS stack is the one thing that gives it away, and unlike every aggregate signal here it is
per-session, volume-independent and not forgeable from client-side JS.

**Cost:** Nintendo Browser shows the allowlist must cover legitimate long-tail browsers, not just
the mainstream set — the same maintenance burden the design doc is trying to avoid. Real, but
bounded.

### Proposed additions

| Signal | Condition | Pts | Notes |
|---|---|---|---|
| **S10 — non-browser TLS stack** | JA4_b outside maintained browser allowlist | **3** | **Replaces S6.** Concentration was measuring diversity as a proxy for what this measures directly. |
| **S11 — UA/TLS class inconsistency** | Non-browser UA with browser JA4_b, or vice versa | **2** | Never browser-vs-browser (see above) |

### #7 tested — fails at browser level, belongs in Tier 2

Both subnet formulations were measured over 14 days (IPv4 only, /24 subnets) and both rank
legitimate browsers as the most suspicious:

| Browser | Max hashes/subnet | Subnets with ≥10 hashes | Subnet ratio (/24s ÷ IPs) |
|---|---|---|---|
| **Opera Mobile** (legitimate, 232 countries) | **214** | **14,680** | 0.357 |
| Headless Chrome | 90 | 2,123 | 0.588 |
| Atom (legitimate, 26 accounts) | 90 | 43 | 0.640 |
| Resty | 7 | 0 | 0.242 |
| Nintendo Browser (legitimate) | 6 | 0 | 0.920 |
| Cypress | 3 | 0 | 0.603 |
| Puffin Cloud Browser | 3 | 0 | 0.113 |
| **CaptchaBotRS** | **2** | **0** | **0.972** |
| JavaFX | 2 | 0 | 1.000 |
| De Standaard | 1 | 0 | 0.436 |

Aggregating over a browser's entire user population accumulates carrier NAT blocks containing
many device types, so a large legitimate browser naturally shows many hashes per subnet. Sri's
#6 specifies "per KEY" and #7's rationale is about a *single* subnet being impossible for one
home or corporate NAT — so both are per-key/per-subnet alerts, not browser-level features.
Subnet ratio fails the same way in the other direction: it is low for datacenter-hosted clients
(Puffin 0.113, Resty 0.242) *and* low for carrier-concentrated mobile (Opera Mobile 0.357), so
it separates datacenter-from-distributed, not bot-from-human.

**Route both to the Tier-2 account alert (§3), evaluated per key and per subnet.** Not scored
signals.

This is the third candidate signal to turn out wrong-altitude for browser classification, after
residential-proxy prevalence and subnet ratio. The pattern is worth stating plainly: the
browser-level layer has few legitimate inputs, and most of the strong detection ideas are
session-level or account-level.

**The doc's §6.5 subnet claim no longer reproduces.** Nokia Browser now measures a subnet ratio
of **0.948** (127 /24s across 134 IPs) against the documented 0.085 (21 across 248) — consistent
with the farm having stopped (§F3 of the run report). Any future use of that figure as a
reference profile should note it describes traffic that no longer exists.
- **#4 — baseline most-seen hash per browser name, version *and* OS.** The test above used
  browser name alone, which is why the baseline looks degenerate; version+OS granularity would
  sharpen it and is the right way to build the S10 allowlist.
- **#3 — IP + JA4 verification ratio per key.** Fits the account-level Tier-2 routing in §2a.
- **#6, #8, #9** — subnet/ASN and JA4-velocity variants; overlap with the doc's existing §3.4
  investigation signals.

## 4b. What the full criteria set flags

Gates G1–G4 applied (Production keys only), S10/S11 replacing S6, threshold >= 8.

| Score | Browser | Prod sessions | Accounts | Firing signals | Route |
|---|---|---|---|---|---|
| **12** | **Resty** | 20,278 | 1 (HP Inc) | S1 WebGL 0 · S2 ip_div 0.000789 · S4 dict 100% · S8 · S11 (Mobile Safari TLS on a Go library) | Tier 2 — customer integration |
| **10** | **Cypress** | 55,784 | 9 | S2 ip_div 0.000986 · S5 pass 100% · S7 · S8 · **S10 non-browser TLS** | Global candidate; benign (customer QA) |
| **9** | **JavaFX** | 264 | 4 | S1 WebGL 0 · S4 dict 100% · **S10 non-browser TLS** | Per-account — Microsoft Identity signup |
| 6 | CaptchaBotRS | 1,346 | 6 | S1 WebGL 0 · S7 · **S11 (genuine Chrome TLS on a bot-named UA)** | Per-account, watch |
| 6 | De Standaard | 149 | 1 (Chime) | S1 WebGL 0 · S4 dict 100% | Tier 2 |
| 4 | Yandex | 375 | 11 | S1 WebGL 0 · S7 | Below threshold |

S10 earns its weight: it is the only signal that fires on Cypress, which defeats S1 (14 WebGL
hashes), S4 (dictionary band 63) and the retired S6 (JA4 concentration 0.691). It also lifts
JavaFX from 6 to 9, over the threshold.

Caveats on this list:
- **De Standaard's S10 is unscored** — it had no sessions in the 1-day Production window used to
  build the JA4_b baseline, so its TLS stack was never classified. Its 6 may be an underestimate.
- **CaptchaBotRS at 6 sits below threshold** and is the entry most worth being wrong about: a
  non-renderer on 6 accounts driving genuine Chrome TLS from 1,111 IPs across 430 ASNs. Nothing
  in the browser-level set catches it properly; it needs the Tier-2 residential-proxy and
  per-key subnet work.
- Nothing here has been validated against a labelled set. Three of the seven browsers the
  original Conditions A/B surfaced turned out to be false positives or internal traffic, so
  treat any new list the same way until attribution is checked.

## 5. Open items

- **Weights are unvalidated.** They reproduce this window's known-good answers, which is not the
  same as generalising. Needs a labelled set.
- **Residential proxy** (`ip_intel__is_proxy_harvested`) is deliberately absent from the
  scorecard. Measured browser-level harvested rates are flat — 4.5% (Chrome) to 10.7% (Venus
  Browser) — and the confirmed tools do not register at all because they run from hosting. It
  tracks where a browser's users live, not whether the browser is bad. It belongs in the Tier-2
  account alert (§3.3) in place of `is_proxy`, and as the per-session global flags
  `g-ip-residential-proxy-user-ip` / `-dx-user-ip`. Note those are not yet firing globally —
  every residential-proxy telltale currently firing is customer-scoped (`adobe5-`, `adobebbcc-`,
  `uberinc1be2-`, `attfad1-`, `blizzard2-`, `att*-`).
- **`di__challenger_dictionary_num_matched` is officially undocumented** — Dataswan status
  "Upcoming", `field_information` = "This is newly added field. Please update with more
  information.", `valid_values` = N/A, despite 455 active telltales referencing it. Measured
  domain is `{-1, 1, 3, 7, 15, 31, 63}` plus NULL — a bitmask (2ⁿ−1), so never average it.
  Population split: 63 → 31.9%, 7 → 28.2%, 15 → 25.1%, 31 → 6.1%, 3 → 4.1%, 1 → 2.2%,
  NULL → 3.1%, −1 → 0.01%. Confirm semantics with the DI team before shipping S4/S9.
- **Chrome's JA4 baseline** still unmeasured (exceeds query budget), so S6's 0.65 threshold rests
  on Nintendo Browser 0.473, Headless Chrome 0.370, (empty UA) 0.354, Opera Mobile 0.270.
