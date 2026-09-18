# BRE — 14-day browser reputation run (2026-09-18)

Discovery run of the Browser Reputation Engine criteria (design doc §2.1) over the full
production browser population. The output is whatever browsers the criteria surface in this
window — derived independently, not checked against any previous list.

| Field | Value |
|---|---|
| **Window** | 2026-09-04 01:42 → 2026-09-18 00:50 UTC (rolling 14 days) |
| **Population** | **1,280,319,834 sessions**, **1,382 distinct `browser_name` values** |
| **Sweep floor** | 50 sessions / 14 days (the doc's own Tier-2 floor, §3.2) |
| **Coverage** | Complete. Condition A evaluated for every browser above the floor; Condition B evaluated for every browser above the floor. |
| **Source** | `ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY` (Snowflake) via Superset "Snowflake DATA" (db 17) |
| **Query** | [`queries/bre_global_classification.sql`](../queries/bre_global_classification.sql) |
| **Status** | Analysis only. No list or telltale changes made. |

Criteria as applied, verbatim from §2.1:
- **Condition A** — `verification_rate < 1%`
- **Condition B** — `ip_diversity < 0.001 AND country_count < 20 AND ja4_concentration_ratio > 0.8`

---

## 1. Output: browsers flagged this window

Seven browsers, out of 1,382. Ranked by volume.

| # | Browser | Sessions | Keys | Verif. rate | ip_diversity | Countries | JA4 conc. | Flagged by |
|---|---|---|---|---|---|---|---|---|
| 1 | **Go-http-client** | 16,725,210 | 6 | **0.0003%** | 0.0022 | 5 | **1.000** | **A** |
| 2 | **Cypress** | 192,741 | 33 | 96.73% | **0.000628** | 9 | 0.691 | B (clauses 1–2) |
| 3 | **Resty** | 142,088 | 3 | 20.72% | **0.000232** | 5 | 0.696 | B (clauses 1–2) |
| 4 | **Unirest for Java** | 6,577 | 2 | 31.23% | **0.000304** | 2 | 0.743 | B (clauses 1–2) |
| 5 | **KorbytPlayer** | 497 | 1 | **0.00%** | 0.0161 | 1 | 0.970 | **A** |
| 6 | **Beamrise** | 130 | 2 | **0.77%** | 0.969 | 1 | 0.992 | **A** |
| 7 | **KakaoTalk** | 76 | 2 | **0.00%** | 0.789 | 2 | 0.724 | **A** |

Condition A produced 4 hits. Condition B produced **0 complete hits** — three browsers satisfy
its IP and country clauses but none clears the `ja4_concentration_ratio > 0.8` clause. See §3.1.

Three of the seven sit below 1,000 sessions and are only visible because the sweep floor is 50.

---

## 2. Evidence per flagged browser

| Browser | ASNs | ISPs | WebGL hashes | Hosting % | Wired % | Satellite | Attempt rate | Pass rate *given* attempt |
|---|---|---|---|---|---|---|---|---|
| Go-http-client | 3 | 10 | **1** | 99.0% | 99.0% | **0** | 99.97% | **0.0%** |
| Cypress | 23 | 23 | 24 | 97.9% | 99.4% | **0** | 96.73% | **100.0%** |
| Resty | 5 | 5 | **0** | 74.3% | 96.1% | **0** | 20.72% | **99.97%** |
| Unirest for Java | 2 | 2 | **0** | 99.5% | 100.0% | **0** | 31.23% | **100.0%** |
| KorbytPlayer | 1 | 1 | 1 | 100.0% | 100.0% | **0** | **0%** (0 attempts) | n/a |
| Beamrise | 2 | 2 | 2 | 0.8% | 100.0% | **0** | 0.8% (1 attempt) | n/a |
| KakaoTalk | 9 | 6 | 43 | 0.0% | 6.6% | **0** | **0%** (0 attempts) | n/a |

Reads on each:

1. **Go-http-client** — Go's HTTP library. 16.7M sessions, 6 keys, 3 ASNs, **one WebGL hash
   across all 16.7M sessions**, 99% hosting, zero satellite. It attempts verification on
   99.97% of sessions and passes 44 of 16.7M. Unambiguous non-browser at very large volume.
2. **Cypress** — testing framework. 121 IPs serving 192,741 sessions, 97.9% hosting,
   zero satellite. Passes **100% of the attempts it makes**.
3. **Resty** — Go HTTP library. 33 IPs, 3 keys, 5 ASNs, **no WebGL at all**, zero satellite.
   Passes 99.97% of attempts; its headline 20.7% verification rate is low only because 79% of
   its sessions never attempt.
4. **Unirest for Java** — Java HTTP client. **2 IPs and 2 ASNs serving 6,577 sessions**, 100%
   wired, 99.5% hosting, no WebGL. The most concentrated infrastructure in the population.
5. **KorbytPlayer** — **false positive; recommend no action.** All 497 sessions are on a single
   key, `BBCC314C-4937-4CCD-B0A3-FDF0F0F7603C` ("Adobe - ARP FF - Production - Key 8",
   account **Adobe**, id 23423, Active). The single ASN is **22616 — Zscaler Inc.**, a corporate
   SASE/proxy egress, not datacenter hosting: the 100% `is_hosting_provider` / `is_proxy`
   reading is Zscaler's IP classification, and 8 IPs on one Zscaler ASN is the normal external
   shape of a corporate network rather than IP rotation. Korbyt is a digital-signage platform,
   so this reads as Adobe running signage players inside its own network. It was flagged only
   by Condition A on **zero verification attempts across 497 sessions** — see §3.2; a 0%
   verification rate with 0 attempts carries no information about solve capability.
6. **Beamrise** — a defunct Chromium-derived browser. 130 sessions, 2 keys, 100% wired, 1
   verification attempt in 14 days, JA4 concentration 0.992. Low volume, but a dead browser
   name on datacenter-shaped traffic is the same profile the doc built its Nokia Browser case on.
7. **KakaoTalk** — the messaging app's in-app browser. The odd one out: 43 WebGL hashes across
   76 sessions, 9 ASNs, 93% wifi, no hosting. That is device diversity, not one tool. Zero
   verification attempts across 76 sessions is what flagged it, and at this volume it is
   likely an SDK/integration issue on 2 keys rather than bad reputation. **Recommend no
   action; re-check next run.**

---

## 3. Criteria observations

### 3.1 Condition B cannot fire at its current threshold

Three browsers satisfy Condition B's `ip_diversity` and `country_count` clauses. All three are
then blocked by the JA4 clause:

| | JA4 concentration |
|---|---|
| Clause 1–2 hits, blocked by clause 3 | Unirest for Java 0.743 · Resty 0.696 · Cypress 0.691 |
| Measured real / mixed traffic | Nintendo Browser 0.473 · Headless Chrome 0.370 · (empty UA) 0.354 · Opera Mobile 0.270 |

The real-traffic ceiling measured here is **0.473**; the blocked-tool floor is **0.691**. There
is an empty band between them, and the threshold is set above both at 0.8. A threshold of
**~0.65** sits inside that band: it admits all three, keeps a 0.18 margin over the highest
legitimate browser measured, and adds no false positive — the one legitimate-looking browser
above 0.65 (Python Requests, 0.811) is excluded by the `ip_diversity` clause anyway at 0.2218.

The doc's stated baseline for clause 3 ("healthy JA4 concentration for real browsers: typically
below 10%") did not hold for any browser measured in this window, including two unambiguously
legitimate ones. Note also that §2.3 predicted these ratios would be "well above" 0.8 based on
low distinct-hash counts; measurement contradicts that for all three.

*Caveat:* Chrome's own JA4 concentration was not re-measured — an exact pass over its 441.7M
sessions exceeds the client call budget and a sampled pass timed out. The <5% figure in the doc
is unverified here, so the "real-traffic ceiling" above rests on Nintendo Browser, Headless
Chrome, (empty UA) and Opera Mobile.

### 3.2 Condition A conflates two different behaviours

`verification_rate = verified / total_sessions` puts these in the same bucket:

- **Attempts and fails** — Go-http-client: attempts on 99.97% of sessions, passes 0.0% of them.
  A bot being stopped by the challenge.
- **Never attempts** — KorbytPlayer (0 attempts / 497 sessions) and KakaoTalk (0 / 76).
  These clients never reach verify at all, so a 0% verification rate says nothing about whether
  they can solve a challenge.

Splitting Condition A into `attempt_rate` and `pass_rate_given_attempt` would separate "bot
failing challenges" from "client never challenged", which are different findings needing
different responses. It would also surface the inverse case below.

This is not a marginal issue: **both zero-attempt hits turned out to be false positives on
inspection** — KorbytPlayer resolves to Adobe signage behind Zscaler, and KakaoTalk's 43 WebGL
hashes across 76 sessions are real device diversity. Of Condition A's four hits this window,
the two with real attempt volume (Go-http-client, Beamrise) are genuine and the two with zero
attempts are not. Gating Condition A on `verify_attempted > 0` would have excluded both without
losing either true positive.

### 3.3 The high-verification-rate case is worse than the headline rate suggests

Cypress, Resty and Unirest for Java pass **100%, 99.97% and 100%** of the verification attempts
they make. Resty's headline verification rate of 20.7% looks unremarkable and would draw no
attention; it is low only because 79% of its sessions never attempt. Pass-rate-given-attempt
near 100% combined with 2–121 IPs is the signature the doc's P2 is about, and dividing by all
sessions hides it.

### 3.4 Condition B's IP clause misses the largest non-browser

Go-http-client's `ip_diversity` is **0.0022** — above the `< 0.001` threshold, so it fails
Condition B and is caught only by Condition A. Worth noting because the doc's §6.1 coverage
table marks it as a Condition B hit at "ip_div 0.003", which is also above 0.001; that row
contradicts the threshold stated in §2.1. (Same for the OhNine row at 0.001.)

### 3.5 Signals that did their job

- **Satellite = 0** held for all seven flagged browsers, and every high-volume legitimate
  browser measured has some (Opera Mobile 28,709; (empty UA) 49,048; Headless Chrome 8,713;
  Nintendo Browser 809). The most reliable confirming signal in this run.
- **WebGL homogeneity** is decisive at the extremes — Go-http-client 1 hash / 16.7M sessions;
  Resty, Unirest zero — and correctly kept as context rather than criteria, since Nintendo
  Browser also shows only 2 and KakaoTalk's 43 hashes across 76 sessions is what exonerates it.
- **Low JA4 + low country = tool, low JA4 + high country = legitimate** (§6.2) reconfirmed:
  Resty 8 hashes / 5 countries vs Nintendo Browser 18 hashes / 184 countries.

---

## 4. Relationship to the previous run's list

Recorded for continuity only — this run's output stands on its own.

| Previously listed | This window |
|---|---|
| Go-http-client (High) | Flagged again, Condition A |
| Cypress (High) | Flagged, Condition B clauses 1–2 |
| Resty (High) | Flagged, Condition B clauses 1–2 |
| ClaudeOrb (High) | **0 sessions** |
| OhNine (High) | **0 sessions** |
| Nokia Browser (Medium) | 340 sessions, hits nothing. VR 19.7%, ip_div 0.553, 36 ASNs, JA4 conc 0.539 — none of the §6.5 solve-farm evidence still describes it |
| Headless Chrome (Medium) | 4,661,100 sessions, hits nothing. 207 countries, 5,199 ASNs, JA4 conc 0.370 |
| (empty UA) (Medium) | 21,219,137 sessions, hits nothing. 221 countries, 20,628 ASNs, JA4 conc 0.354 |

Newly surfaced this run: **Unirest for Java, KorbytPlayer, Beamrise, KakaoTalk**.

Pending candidates from §11 item 7, now resolved: **sqlmap** 0 sessions, **Optimizely** 0
sessions, **undici** 8 sessions (0 verified, 1 IP — below the floor), **Python Requests** 5,978
sessions but hits nothing (1,326 IPs / 233 ASNs / 39 countries is a real-user profile despite
the name), **Unirest for Java** flagged as above.

One browser worth a manual look that the criteria did **not** flag: **CaptchaBotRS**, 1,318
sessions, 1.37% verification rate, zero WebGL hashes — but 1,208 IPs over 440 ASNs and 63
countries. It misses Condition A by 0.37pp and Condition B by three orders of magnitude on IP
diversity. A self-identifying captcha bot on residential-looking infrastructure is a live
instance of the "bots on residential proxies" gap in §7.

---

## 5. Not covered

- **Account-level Tier 2 (§3).** Global pass only. The per-account diversity alert needs
  `account_id`, which is not on `prod_session_summary` (the doc's own §9 gap).
- **Subnet and ASN concentration ratios (§3.4).** Per-flagged-browser investigation steps;
  not run here.
- **Chrome JA4 concentration baseline.** See §3.1 caveat.
- **Browsers under 50 sessions.** 1,382 names exist; the sweep floor excludes the long tail.
  A browser can be a real solve farm at low volume, so consider a no-floor pass on
  `ja4_concentration_ratio` alone in a future run.
