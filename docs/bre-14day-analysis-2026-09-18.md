# BRE — 14-day global browser reputation refresh (2026-09-18)

Re-run of the Browser Reputation Engine global classification query (design doc §5) against
production, to refresh the High/Medium Risk lists and validate the classification criteria
(§2.1) on current data.

| Field | Value |
|---|---|
| **Design doc** | Confluence FP — *Browser Reputation Engine (BRE) - Design Document* (last updated 2026-06-11) |
| **Window** | 2026-09-04 01:42 → 2026-09-18 00:50 UTC (rolling 14 days) |
| **Population** | **1,280,319,834 sessions**, 1,382 distinct `browser_name` values (195 with ≥1,000 sessions) |
| **Source** | `ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY` (Snowflake) via Superset "Snowflake DATA" connection |
| **Query** | [`queries/bre_global_classification.sql`](../queries/bre_global_classification.sql) |
| **Status** | Analysis only. No list changes or telltale changes made. Per the doc's own standing warning, no browser should be actioned without team review. |

---

## Headline

Three things changed materially since the doc was written, and two of them undercut the
criteria rather than the lists:

1. **Two High Risk entries and one Medium Risk entry have disappeared from production
   entirely.** ClaudeOrb (was 620K sessions), OhNine (was 165K) and the pending candidates
   sqlmap and Optimizely all return **zero sessions** in the window. Nokia Browser — the
   doc's headline solve-farm case — has collapsed from 418,157 sessions to **340**.
2. **Condition B, as written, now catches nothing.** Once `ja4_concentration_ratio` is
   actually computed (the doc left it as a TODO and estimated it from distinct hash counts),
   Cypress (0.691), Resty (0.696) and Unirest for Java (0.743) all fall **below** the 0.8
   threshold. They were estimated as "well above" it. Condition B has zero hits this window.
3. **Condition A catches exactly one browser at scale** — Go-http-client, at 16.7M sessions
   and a 0.0003% verification rate.

Net effect: of the eight browsers on the two lists, only Go-http-client is currently
re-derivable from the criteria. Cypress and Resty — which are on the High Risk list
*because of* Condition B — now survive only because the list is manually maintained. That is
worth fixing before the telltales in §11 item 1 are built, because the lists and the criteria
that justify them have drifted apart.

---

## 1. Measured results

All figures are exact counts over the window (no sampling, no approximation). Session totals
differ by up to ±0.02% between rows because each pass was a separate query and the rolling
`SYSDATE()` boundary advanced between calls; pass 2 is used as the canonical count.

| Browser | Sessions | Verif. rate | Keys | IPs | ip_diversity | ASNs | Countries | JA4 hashes | **JA4 conc.** | WebGL hashes | Hosting % | Wired % | Satellite |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| (empty UA) | 21,213,429 | 22.17% | 337 | 1,217,445 | 0.0574 | 20,628 | 221 | 5,017 | 0.354 | 12,692 | 11.1% | 48.6% | 49,048 |
| **Go-http-client** | 16,719,842 | **0.0003%** | 6 | 36,762 | 0.0022 | 3 | 5 | 5 | **1.000** | **1** | 99.0% | 99.0% | **0** |
| Headless Chrome | 4,661,100 | 49.21% | 216 | 125,685 | 0.0270 | 5,199 | 207 | 2,271 | 0.370 | 7,845 | 72.2% | 82.5% | 8,713 |
| Opera Mobile | 3,664,021 | 28.94% | 170 | 1,868,583 | 0.5100 | 23,062 | 232 | 4,592 | 0.270 | 2,911 | 4.5% | 16.9% | 28,709 |
| **Cypress** | 192,983 | 96.73% | 33 | 121 | **0.000627** | 23 | 9 | 8 | 0.691 | 24 | 97.9% | 99.4% | **0** |
| **Resty** | 141,888 | 20.73% | 3 | 33 | **0.000233** | 5 | 5 | 8 | 0.696 | **0** | 74.3% | 96.1% | **0** |
| Nintendo Browser *(legit baseline)* | 40,282 | 50.77% | 40 | 20,116 | 0.4994 | 2,101 | 184 | 18 | 0.473 | 2 | 0.3% | 1.5% | 809 |
| **Unirest for Java** | 6,575 | 31.24% | 2 | **2** | **0.000304** | 2 | 2 | 2 | 0.743 | **0** | 99.5% | 100.0% | **0** |
| Python Requests | 5,978 | 65.84% | 16 | 1,326 | 0.2218 | 233 | 39 | 14 | 0.811 | 16 | 11.4% | 33.9% | 50 |
| **CaptchaBotRS** *(new)* | 1,318 | 1.37% | 6 | 1,208 | 0.9165 | 440 | 63 | 3 | 0.554 | **0** | 5.6% | 10.6% | 12 |
| Nokia Browser | **340** | 19.71% | 20 | 188 | 0.5529 | 36 | 18 | 16 | 0.539 | 19 | 12.8% | 12.8% | 0 |
| undici | 8 | 0.00% | 1 | 1 | 0.125 | 1 | 1 | 1 | 1.000 | 0 | 100.0% | 0.0% | 0 |
| ClaudeOrb / OhNine / sqlmap / Optimizely | **0** | — | — | — | — | — | — | — | — | — | — | — | — |

Chrome's JA4 concentration was **not** re-measured this run — an exact pass over its 441.8M
sessions exceeds the client call budget, and a sampled pass timed out. The doc's figure
(39,880 hashes, <5%) is carried forward unverified. Chrome's volume and verification rate
were measured: 441,812,393 sessions at 43.87%.

### Criteria evaluation

Thresholds per §2.1 — **A:** `verification_rate < 1%`; **B:** `ip_diversity < 0.001 AND country_count < 20 AND ja4_concentration_ratio > 0.8`.

| Browser | Condition A | Condition B | Caught? |
|---|---|---|---|
| Go-http-client | ✅ 0.0003% | ❌ ip_div 0.0022 (> 0.001) | **Yes — A only** |
| Cypress | ❌ 96.73% | ❌ JA4 conc. 0.691 (≤ 0.8) | **No** |
| Resty | ❌ 20.73% | ❌ JA4 conc. 0.696 (≤ 0.8) | **No** |
| Unirest for Java | ❌ 31.24% | ❌ JA4 conc. 0.743 (≤ 0.8) | **No** |
| (empty UA) | ❌ 22.17% | ❌ ip_div 0.0574, 221 countries | No |
| Headless Chrome | ❌ 49.21% | ❌ ip_div 0.0270, 207 countries | No |
| Nokia Browser | ❌ 19.71% | ❌ ip_div 0.5529, JA4 conc. 0.539 | No |
| Python Requests | ❌ 65.84% | ❌ ip_div 0.2218 | No |
| CaptchaBotRS | ❌ 1.37% | ❌ ip_div 0.9165 | No |
| undici | ✅ 0.00% | ❌ ip_div 0.125 | Yes — A, but only 8 sessions |

**Condition B: 0 hits. Condition A: 1 hit at meaningful volume.**

---

## 2. Findings

### F1 — The 0.8 JA4 concentration threshold is set in the wrong place

This is the substantive criteria problem. Measured ratios separate tools from real browsers
cleanly, but the boundary sits far lower than 0.8:

| | JA4 concentration |
|---|---|
| **Tools** | Go-http-client 1.000 · undici 1.000 · Python Requests 0.811 · Unirest 0.743 · Resty 0.696 · Cypress 0.691 |
| **Real / mixed traffic** | Nintendo Browser 0.473 · Headless Chrome 0.370 · (empty UA) 0.354 · Opera Mobile 0.270 |

The real-traffic ceiling is 0.473 and the tool floor is 0.691. The doc's stated baseline —
"healthy JA4 concentration for real browsers: typically below 10%" — does not hold for any
browser measured here, including two that are unambiguously legitimate. A threshold of
**~0.65** would sit in the empty band between the two populations: it captures Cypress,
Resty and Unirest for Java while leaving a 0.18 margin above the highest legitimate browser.
It introduces no new false positives, because the browsers between 0.65 and 0.8 that are
legitimate are excluded by the `ip_diversity` clause anyway (Python Requests at 0.811 JA4
concentration fails Condition B on `ip_diversity` 0.2218).

Recommendation: lower the Condition B JA4 threshold to 0.65 and re-baseline the "healthy"
figure in §2.1 from measurement rather than from Chrome alone.

### F2 — Condition B's `ip_diversity < 0.001` misses the largest non-browser, and the doc's §6.1 table asserts otherwise

Go-http-client's measured `ip_diversity` is **0.0022** — above the 0.001 threshold, so it
fails Condition B on the IP clause. The doc's §6.1 coverage table marks it
"✅ ip_div 0.003", but 0.003 is also above 0.001, so that row is internally inconsistent:
the number shown contradicts the criterion stated in §2.1. The same applies to the OhNine
row (0.001, not strictly `< 0.001`).

This does not change Go-http-client's classification — Condition A catches it decisively —
but §6.1 overstates Condition B's coverage and should be corrected.

### F3 — Nokia Browser's solve farm is gone

The §6.5 session-level evidence no longer describes this traffic. Every dimension has
inverted:

| Dimension | Doc (§6.5) | Now |
|---|---|---|
| Sessions | 418,157 | **340** |
| Verification rate | 95.6% | 19.71% |
| JA4 concentration | 100% (single hash) | 0.539 (16 hashes) |
| ip_diversity | 0.002 | 0.5529 |
| ASNs | 1 (ASN 6079) | 36 |
| Connection mix | 99.97% wired, 0 NAT | 12.8% wired, 60.4% mobile |
| WebGL hashes | 1 | 19 |

340 sessions across 20 keys with mobile-dominant connectivity and diverse ASNs is residual
long-tail traffic, not a farm. The operator has stopped or moved to another `browser_name`.
§11 item 3 (investigate Nokia Browser across 24 keys, coordinate with the Roblox account
team) is no longer worth the effort at this volume, though the name should stay on the
Medium Risk list — it remains a dead browser with no legitimate user base, and re-emergence
is cheap to detect.

### F4 — Of the five pending candidates, only one merits listing, and not via the criteria

§11 item 7 asked for validation of five 30-day candidates against a 14-day window:

| Candidate | Result | Verdict |
|---|---|---|
| **Unirest for Java** | 6,575 sessions, **2 IPs**, 2 ASNs, 2 keys, 2 countries, 100% wired, 99.5% hosting, 0 WebGL hashes, 0 satellite | **Add to Medium Risk by manual review.** 2 IPs serving 6,575 sessions is the most concentrated profile in the dataset. Fails Condition B only on JA4 concentration (0.743) — would be caught automatically under F1's 0.65 threshold. |
| Python Requests | 5,978 sessions, 1,326 IPs, 233 ASNs, 39 countries, 49% mobile, 11% hosting | **Do not add.** Infrastructure profile is real-user-like despite the name; likely genuine clients sending a library UA. Fails both conditions. |
| sqlmap | 0 sessions | Drop from candidates. |
| Optimizely | 0 sessions | Drop from candidates. |
| undici | 8 sessions, 0 verified, 1 IP, 1 key | Too small to classify. Keep watching. |

### F5 — New candidate: CaptchaBotRS

Not in the doc. 1,318 sessions across 6 keys, self-identifying as a captcha bot, **1.37%
verification rate**, and **zero WebGL hashes** across all sessions — it is not running a
renderer. But its infrastructure looks nothing like a datacenter tool: 1,208 IPs over 440
ASNs and 63 countries (`ip_diversity` 0.9165), 51% wifi, 32% mobile, only 5.6% hosting.

It escapes both conditions — Condition A by 0.37 percentage points, Condition B by three
orders of magnitude on IP diversity. This is a concrete instance of the "bots on residential
proxies" gap the doc names in §7, and it argues that gap is live now rather than pending
`is_proxy_harvested`. Recommend Medium Risk by manual review, and use it as the worked
example when that gap is escalated.

### F6 — Signals that held up

- **Satellite = 0 (§6.4)** is the most reliable confirming signal measured. Every tool has
  exactly zero satellite sessions (Go-http-client 0/16.7M, Cypress 0/193K, Resty 0/142K,
  Unirest 0/6.6K); every real browser has some (Opera Mobile 28,709, (empty UA) 49,048,
  Headless Chrome 8,713, Nintendo Browser 809).
- **WebGL homogeneity (§3.4)** is strong at the extremes: Go-http-client shows **1 hash
  across 16.7M sessions**, and Resty, Unirest, CaptchaBotRS and undici show none at all.
  It is weak as a standalone signal, though — Nintendo Browser also shows only 2, because
  it is one hardware platform. Correctly kept as investigation context.
- **Connection type is not a classification signal (§6.3)** — reconfirmed. Unirest is 100%
  wired and CaptchaBotRS is 83% wifi/mobile; both are non-browsers.
- **Low JA4 + high country count = legitimate (§6.2)** — reconfirmed by Nintendo Browser
  (18 hashes, 184 countries) versus Resty (8 hashes, 5 countries).

---

## 3. Volume changes vs the design doc baseline

| Browser | Doc | Now | Change |
|---|---|---|---|
| Chrome | 428.8M | 441.8M | +3% |
| (empty UA) | 19,322,442 | 21,213,429 | +10% (VR 14.3% → 22.2%) |
| Go-http-client | 16,247,509 | 16,719,842 | +3% (VR still ~0%) |
| Roblox | 66.1M | 54.9M | −17% |
| Headless Chrome | 3,467,234 | 4,661,100 | +34% (VR 55.6% → 49.2%) |
| Cypress | 162,272 | 192,983 | +19% (VR 95.0% → 96.7%) |
| Resty | 101,804 | 141,888 | +39% (VR 15.4% → 20.7%) |
| Nintendo Browser | 92K | 40,282 | −56% |
| **Nokia Browser** | 418,157 | **340** | **−99.9%** |
| **ClaudeOrb** | 620,075 | **0** | gone |
| **OhNine** | 165,116 | **0** | gone |

---

## 4. Recommended list state

No changes applied. Proposed for team review:

**High Risk** — keep Go-http-client (re-derived from Condition A, 16.7M sessions), Cypress
and Resty (criteria no longer re-derive them; see F1 — they qualify again under a 0.65 JA4
threshold). Retire **ClaudeOrb** and **OhNine** to a dormant list rather than deleting them:
zero traffic is not evidence of legitimacy, and re-listing on re-emergence should be cheap.

**Medium Risk** — keep Headless Chrome ((empty UA) and Headless Chrome both look more like
legitimate diverse traffic this window than the doc suggests: 207–221 countries, JA4
concentration 0.35–0.37). Keep Nokia Browser as dormant. Add **Unirest for Java** and
**CaptchaBotRS** by manual review.

**Drop from candidates** — sqlmap, Optimizely (zero traffic); Python Requests (real-user
infrastructure profile).

## 5. Suggested doc amendments

1. §2.1 — lower the Condition B JA4 threshold from 0.8 to ~0.65, and re-baseline the
   "healthy JA4 concentration" figure on measured data (real-traffic range 0.27–0.47, not
   "below 10%").
2. §2.3 — replace the "exact JA4 concentration ratios to be computed" note with the measured
   values, and drop the inference that single-digit hash counts imply a ratio above 0.8.
3. §6.1 — fix the Go-http-client and OhNine rows, which mark `ip_diversity` values of 0.003
   and 0.001 as satisfying a `< 0.001` criterion.
4. §5 — correct the table name to `ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY`, the dialect
   to Snowflake (`DATEADD`/`SYSDATE()`), and note that `browser_name` is `''` rather than
   NULL for the "(empty UA)" cohort.
5. §9 — add a platform gap: a 14-day global pass cannot run as a single query within the
   Superset/MCP 60s call budget and must be split into passes (see the query file header).
6. §11 — item 3 (Nokia Browser) is largely moot at 340 sessions; item 4 (ClaudeOrb, OhNine)
   is moot at zero; item 7 is complete, with one of five candidates advancing.

## 6. Not covered

- **Account-level Tier 2 analysis (§3).** This refresh is the global pass only. The
  per-account diversity alert needs `account_id`, which is not on `prod_session_summary`
  (the doc's own §9 gap) and requires an events-table lookup.
- **Subnet concentration and ASN concentration ratios (§3.4).** Computable but not run here;
  they are per-flagged-browser investigation steps rather than classification inputs.
- **Chrome JA4 concentration baseline.** See §1 — exceeded the call budget, carried forward
  from the doc unverified.
