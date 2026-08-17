# Detection Idea: Login Velocity Detection (FVD compound anchor, adapted for login)

**Status:** DRAFT · **Author:** Patricia · **Scope:** Web · Desktop only · Login flow

> Working notes reconciling two existing specs for the login flow:
> - [LII — init_fingerprint Account Divergence](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4328128666) (login, init_fingerprint-only anchor, 72h/3-cluster)
> - [Signup Flow Device Velocity — init_fingerprint + JA4 (FVD v4)](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4250206224) (signup, compound anchor, per-day/11-signal)
>
> The proposal here is to run login on the **FVD v4 compound anchor + 11-signal model**, not the
> init_fingerprint-only anchor, and to change how the velocity gate works because login has a
> fundamentally different legitimate baseline.

---

## 1. Why login is not signup

FVD v4 works on signup because the legitimate baseline is ~1 account per device per day, so a gate
of **6 sessions/device/day** is already anomalous. Login breaks that premise:

- A single legitimate user re-authenticates repeatedly — token expiry, multiple devices/tabs, app +
  web, logout/login cycles.
- **Shared devices** (family PC, library, office, school) legitimately produce many accounts/day
  from one `init_fingerprint`.
- **SSO / enterprise NAT gateways** put many real users behind one egress and, often, one device
  fingerprint family.

So the signup gate of 6/day would drown login in false positives. **The velocity-per-day gate must
be raised, and — more importantly — it should gate on the right quantity.** See §4.

## 2. The "no identifiers" problem (Mode B) — and what's actually left

Without a customer identifier at session creation we cannot compute **account fan-out**
(`distinct_accounts`), which is the single strongest login signal. That means we cannot, from
velocity alone, separate:

| Pattern | Accounts | Threat | Fan-out visible? |
| --- | --- | --- | --- |
| Credential stuffing | many distinct | **high** (the target) | Mode A only |
| Password spray / brute force | one (or few) | medium | no |
| Heavy legitimate re-auth | one | none | no |

The premise in the question is correct: **in Mode B, rapid timing plus network infrastructure is
what's left.** But "we only have rapid timing" undersells it — most of the FVD v4 signal set
describes *attack infrastructure*, not signup-specific fan-out, so those signals transfer to login
unchanged even without identifiers. See §3.

## 3. What we can use: FVD v4's compound anchor + signals on login

### 3.1 Anchor (the "signup flow 3 anchor")

Adopt the FVD v4 compound anchor for login clustering:

```
(init_fingerprint, cdn__ja4_hash, timezone_continent, date)
```

Why this beats LII's `init_fingerprint`-only anchor on login: login has far more legitimate
shared-device traffic (school/office/library), and those users *collide* on an init_fingerprint-only
anchor (same Chrome/Windows build → same hash). Adding `cdn__ja4_hash` + `timezone_continent` tightens
the cluster so a shared classroom device and a credential-stuffing tool don't land in the same bucket
just because they share a browser build. Lower collisions → a given velocity threshold *means more*.

### 3.2 Signals that transfer to login as-is (identity-agnostic infrastructure/behaviour)

All eleven FVD v4 compound signals are about infrastructure or cadence, not signup, so they apply to
login in **both** Mode A and Mode B:

| Signal | Condition | Carries in Mode B? |
| --- | --- | --- |
| RAPID_TIMING | avg gap < 5 min | ✅ primary |
| IP_ROTATION | rotation ratio > 50% | ✅ |
| SAME_ASN_80PCT | 80%+ sessions one ASN | ✅ |
| SAME_IP_CONCENTRATED | 80%+ sessions one IP | ✅ |
| HOSTING_VPN_PROXY | any hosting/VPN/proxy | ✅ |
| SINGLE_COUNTRY | all sessions 1 country | ✅ |
| SUBNET_CONCENTRATED | ≤3 /24 subnets | ✅ |
| MULTI_ISP_SAME_COUNTRY | 2+ ISPs, 1 country | ✅ |
| HARVESTED_PROXY | harvested-proxy flag | ✅ |
| TIMEZONE_MISMATCH | IP tz regions scattered | ✅ |
| UA_MISMATCH | 50%+ UA mismatch | ✅ |

### 3.3 What Mode A adds back

When the customer sends identifiers, add **account fan-out as a 12th, high-weight signal**
(`distinct_accounts per anchor per day ≥ N`). This is exactly LII Mode A, and on login it's the
strongest discriminator — a device touching many *distinct* accounts is the credential-stuffing
signature. In Mode A the fan-out signal should be able to gate on its own; the infra signals
corroborate. In Mode B, since we can't confirm fan-out, we require *more* infra corroboration to hold
FP down (see §4).

## 4. Increasing the velocity per day — do it by gating on the right quantity

Raising the raw session count is necessary but not sufficient. Recommendation:

- **Mode A — gate on distinct accounts, not raw sessions.** A device re-authenticating 40 times to
  *one* account is not the threat; a device hitting *many distinct* accounts is. Suggested start:
  `distinct_accounts / anchor / day ≥ 5–10` (key-dependent). Raw re-auth volume is ignored by the
  gate and only feeds the timing signals.
- **Mode B — raise the raw-session gate substantially and require heavier corroboration.** LII uses
  `total_sessions ≥ 50` over a 72h window. Per day, start around **≥ 30–50 sessions/anchor/day**
  (key-dependent) and require **more signals than signup** to fire HARD_CHALLENGE, because fan-out is
  unconfirmable. Mirror LII's "all clusters must corroborate" discipline rather than FVD's 3-of-11.

Per-key calibration is mandatory (same as both parent specs): run a 14-day baseline and pick the gate
above the legitimate tail. High-traffic / shared-device keys need higher gates; fintech/crypto login
keys can run tighter.

### Suggested action tiers (login)

Mode B scores by **cluster corroboration** (LII discipline), not a raw signal
count, because the compound anchor pins JA4 and leaves only two genuinely
independent dimensions to corroborate with — **Network** and **Timing**
(Device/UA is a weak third). This is deliberately stricter than FVD v4's raw
3-of-11 count, since Mode B cannot confirm fan-out and must keep FPR down.

| Tier | Mode A condition | Mode B condition (implemented in the analyser) |
| --- | --- | --- |
| HARD_CHALLENGE | gate + fan-out + ≥2 infra signals | gate + Timing fires + (Network **or** Device) |
| CHALLENGE | gate + fan-out only | gate + Timing alone, **or** Network + Device (no Timing) |
| MONITOR | gate + 1 infra signal | gate + exactly one of Network / Device |
| NOISE | gate + 0 signals | gate + nothing fires |
| COLLISION | >500 sessions/hour AND >10 ISPs | same |
| LOW_VELOCITY | below gate | below gate |

Clusters: **Network** = proxy/VPN/hosting · IP rotation · ASN/subnet/country
concentration · harvested proxy · timezone scatter (fires if any member fires).
**Timing** = rapid avg gap · burst · metronomic cadence. **Device** = UA mismatch.
A testing finding worth noting: in Mode B, rapid automation almost always trips a
Network signal too, so "Timing alone" is effectively unreachable — the realistic
HARD path is Timing + Network.

## 5. Make rapid timing multi-dimensional (it's the load-bearing signal in Mode B)

Since Mode B leans on timing, don't rely on a single `avg gap < 5 min` — it's easily diluted by long
idle stretches and easily paced around. Enrich the Timing cluster with:

- **median / p90 inter-arrival gap** — robust to outliers that hide a fast core.
- **burst count** — max sessions in any rolling 60s / 5-min window. Farms burst even when the overall
  average looks human.
- **cadence regularity** — coefficient of variation of inter-arrival gaps. Metronomic, low-variance
  spacing is a machine tell that legitimate humans don't produce and that's awkward to fake at scale.

This is the fast-follow the LII spec already gestures at (challenge-level behavioural enrichment); for
login it should be brought forward because timing is doing more work here.

## 6. There is only one data ask: the account identifier

It's tempting to list "per-attempt login outcome (success/fail)" as a separate signal — fail-rate
would separate credential stuffing (mostly-fail, one shot per account) from heavy legitimate re-auth
(mostly-success). **But outcome and identifier are inseparable.** To report an outcome the customer's
backend has already resolved the attempt to an account (it looked up that account to check the
password), so the identifier exists at that exact moment and costs ~nothing extra to send. The
consequence runs both ways:

- A customer who *can* send outcome can send the identifier — so we'd just ask for the identifier,
  which is the stronger signal (it unlocks account fan-out, §3.3 / §4).
- A customer who *won't* send the identifier (the definition of Mode B) won't be sending outcome
  either.

So **outcome is not an independent lever, and it is not a Mode B lifeline.** The single data ask is
the account identifier; getting it moves the key from Mode B to Mode A. If it's present, treat
fail-rate as a free Mode A enrichment on top of fan-out.

This is what makes the mode split real: **Mode B is genuinely low-integration** — the customer sends
nothing but the session, no identifier and no outcome. There is no cheap signal to recover fan-out
there, which is exactly why the multi-dimensional timing work (§5) and the infrastructure signal set
(§3.2) have to carry Mode B on their own.

## 7. Open items to resolve before productising

- **macOS inconsistency between the two parent specs.** LII v1.1 includes macOS Chrome/Firefox
  (argues sufficient entropy); FVD v4 excludes macOS Chrome as a precaution. Pick one for login and
  validate collision rate per key before including macOS.
- **Window.** FVD anchor bakes `date` into the key (24h). LII uses a 72h rolling window on a 1h
  cadence to catch bursts in-flight. Recommend the LII rolling window with the FVD compound anchor —
  best of both: tight anchor, in-flight detection.
- **Validation.** No login labels yet. Recall/FPR/uplift must be measured per key (as FVD v4 did on
  Roblox/Blizzard/Figma) before this becomes a blocking signal.
- **Signal lifecycle monitoring.** Same anti-detect-browser degradation risk as both parents; carry
  LII's single-session-fingerprint-ratio and entropy-distribution monitors over.

## 8. Tooling — test Mode B first

Mode B is the case to validate before anything else: no fan-out to lean on, so the
verdict rests entirely on infrastructure + timing, which is where the false-positive
risk lives. The analyser and extraction query are in the repo:

- `tools/login_velocity_modeb.py` — zero-dependency analyser implementing the anchor,
  gate, and cluster scoring above. `--self-test` validates the tier logic on labelled
  synthetic clusters (no warehouse needed); `--data sessions.csv` runs a real key.
- `queries/login_modeb_extraction.sql` — session-only extraction for a login key.
- See `tools/README.md` for the calibration workflow (14-day baseline → pick
  `--daily-threshold` above the legitimate tail → confirm shared-device traffic stays
  out of HARD_CHALLENGE).

Validation status: tier logic verified on synthetic data; **not yet run on a real
login key** — recall/FPR pending, same as the parent specs.

## 9. TL;DR answers to the questions raised

- *"With login, velocity should be higher than normal"* — correct; the signup gate of 6/day is far
  too low for login. Raise it, and in Mode A gate on **distinct accounts** rather than raw sessions.
- *"Since we can't tell if it's the same account, we only have rapid timing?"* — rapid timing is the
  primary *behavioural* signal in Mode B, but the full network-infrastructure signal set (IP
  rotation, ASN/subnet concentration, proxy/VPN/hosting, harvested proxy, tz mismatch, UA mismatch)
  transfers unchanged, so it isn't timing alone. Make timing multi-dimensional (median/p90, burst,
  cadence regularity) so it's not a single flimsy signal. Note there is no "login outcome" shortcut:
  outcome and account identifier are inseparable, so a Mode B key that won't send the identifier
  won't send outcome either — the only data ask is the identifier, which promotes the key to Mode A.
- *"Use the sign up flow 3 anchor"* — yes: `init_fingerprint + cdn__ja4_hash + timezone_continent`
  is a strictly better anchor for login than init_fingerprint alone because it survives the much
  larger volume of legitimate shared-device login traffic.
