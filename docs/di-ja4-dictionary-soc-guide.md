# DI Dictionary Promotion (Canvas FP → JA4) — SOC Implementation & Support Guide

**Status:** DRAFT for SOC enablement · **Author:** Patricia Nankubuge · **Data as of:** 13–15 Oct 2026
**Confluence:** https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4771479605
**Companion to:** [IP Connection-Type Velocity — SOC Implementation & Support Guide](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4771381280)
**Per-key check:** [Saved SQL Lab query — DI dictionary mix and threshold breach rate by key](https://superset-snowflake-green.production-blue.us-east-2.internal.services.aws.arkoselabs.com/sqllab?savedQueryId=1069)

> Items marked **VERIFY** could not be confirmed from Dataswan, Superset or Confluence.
> Items marked **DECISION** need an owner's call before go-live.

---

# What it is

Device Intelligence (DI) matches each session's device signature against dictionaries of known
legitimate devices. Dictionary levels run `1 → 3 → 7 → 15 → 31 → 63`: the higher the number, the
more attributes matched and the more the device is trusted. `-1` means no match.

On **30 Sep 2026** ([CHNGE-6290](https://arkoselabs.atlassian.net/browse/CHNGE-6290)) the signature
anchor changed from the **canvas fingerprint (CFP)** to the **JA4 TLS hash**. The challenger recipe
became the champion; nothing else in the dictionaries changed.

Because traffic now lands in different dictionaries, the global DI telltale **multipliers are being
re-tuned the other way round**:

| Dictionary | Today | New |
| --- | --- | --- |
| **Dict 1** | 5x and 10x (1x is a suspicion flag) | **1x and 2x** — more sensitive |
| **Dict 3, 7, 15, 31** | 1x and 4x | **2x, 4x and 6x** — less sensitive at the bottom |
| Dict 63, Dict -1, long-term | unchanged | unchanged |

**Proxy-integration keys:** the Dict 3 telltales stay **off** for now. Standard and vanity-URL
integrations keep Dict 3.

# Why we changed it

- **Canvas randomisation broke Dict 1.** Firefox, Mobile Safari and Chrome randomise or add noise
  to the canvas fingerprint, so legitimate devices fell through to Dict 1. Dict 1 plus velocity drove
  FPs: Dropbox / Firefox 144 (ESM-5514), Firefox 154 (ESM-6815), Dict 1 FPs across suspicion flags
  (ESM-6791). Before the switch, about 14M sessions a week sat in champion Dict 1 that JA4 placed
  in Dict 63.
- **JA4 fixed it.** One day before and after the switch, all keys, `session_setup`:

  | Dictionary | 24 Sep (CFP) | 13 Oct (JA4) |
  | --- | --- | --- |
  | 1 | 6.75M (9.3%) | 1.89M (2.8%) |
  | 3 | 3.56M (4.9%) | 3.74M (5.5%) |
  | 7 | 4.88M (6.7%) | 8.55M (12.6%) |
  | 15 | 10.35M (14.3%) | 10.96M (16.2%) |
  | 31 | 3.84M (5.3%) | 6.18M (9.1%) |
  | 63 | 43.1M (59.4%) | 36.4M (53.8%) |
  | -1 | 39k | 14k |

  Firefox sessions in Dict 1 fell from **1.54M to 11.6k a day**, and Mobile Safari from 1.25M to
  48.5k.
- **So the multipliers need to flip.** Dict 1 is now small and mostly genuinely unrecognised
  devices, so it can fire earlier (1x, 2x). Dicts 3–31 now hold more legitimate traffic, so 1x is too
  noisy there. For example, on AT&T Consumer Login (standard integration) 30.5% of Dict 3 sessions
  breached the 1x short-term threshold on 14 Oct.
- **Proxy integrations are a special case.** On these keys the JA4 hash belongs to the proxy, not
  the user, so many users collapse onto one signature and velocity looks inflated
  ([ESM-6922](https://arkoselabs.atlassian.net/browse/ESM-6922)). On 13 Oct, 44% of Dict 3 sessions on
  Pinterest Login and 50% on Payoneer Login breached the short-term threshold.

Background: [DI Challenger Promotion (Canvas FP → JA4): Effort Analysis & Promotion Plan](https://arkoselabs.atlassian.net/wiki/spaces/EN/pages/4654497793),
[JA4 Hash Final Confirmation — Customer Escalation Accounts](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4637327365),
[Detection Q3 2026 Breakdown](https://arkoselabs.atlassian.net/wiki/spaces/DE/pages/4750475270) (release record).

---

# How to use it

## Step 1 — Check the key's integration type

| Integration | How to tell | Dict 3 telltales |
| --- | --- | --- |
| **Standard** (Arkose called from the user's browser) | Not on the proxy list | On |
| **Vanity URL** (customer domain in front of Arkose, still direct to the user) | Not on the proxy list | On |
| **Proxy** (Arkose called server-side through the customer's proxy) | Listed on [Proxy Integrations](https://arkoselabs.atlassian.net/wiki/spaces/THRE/pages/4726390843) | **Off** |

Proxy keys today: Pinterest Login and Registration, Payoneer Login, CLM Registration and
Registration (plus their dev keys), and the Arkose Azure integration keys. The Azure keys have no
DI dictionary match at all, so DI telltales don't apply to them.

## Step 2 — Look at the key's dictionary mix

Run the [saved SQL Lab query](https://superset-snowflake-green.production-blue.us-east-2.internal.services.aws.arkoselabs.com/sqllab?savedQueryId=1069)
with the key's `public_key` (or account) filter. For each dictionary it shows share of sessions,
% breaching the short-term threshold and the median ratio. This tells you which tier is likely to
be noisy before you put pressure on it.

## Step 3 — Use the new multipliers

`...` below = `g-di-dict-N-match-short-term-threshold-exceeded`.

| Dictionary | Short-term tiers to use | Replaces | Notes |
| --- | --- | --- | --- |
| **1** | `...-1x`, `...-2x` | `-5x`, `-10x` | `-1x` exists today as a suspicion flag; `-2x` is new |
| **3** | `...-2x`, `...-4x`, `...-6x` | `-1x` | `-4x` exists; `-2x` and `-6x` are new. **Not on proxy keys.** |
| **7** | `...-2x`, `...-4x`, `...-6x` | `-1x` | `-4x` exists; `-2x` and `-6x` are new |
| **15** | `...-2x`, `...-4x`, `...-6x` | `-1x` | `-4x` exists; `-2x` and `-6x` are new |
| **31** | `...-2x`, `...-4x`, `...-6x` | `-1x` | `-4x` exists; `-2x` and `-6x` are new |
| 63 | none | — | no global dict-63 threshold telltale today |
| -1 | unchanged | — | `g-di-dict-neg1-match-*` |

Long-term telltales (`g-di-dict-N-match-long-term-threshold-exceeded`) are unchanged.

New names are **proposed**, following the existing pattern. Use the names THR creates in Dataswan.

Things to know before you build custom telltales:
- **Tiers stack today.** The existing 4x telltales check `ratio >= 4` with no upper bound, so a
  session at 7x would fire 2x, 4x and 6x. Put pressure on one tier, or expect it to add up.
  **DECISION:** band the new tiers (2–4x, 4–6x, 6x+) or keep stacking.
- Only build on the global telltales once THR has created and promoted them. Don't copy the old
  1x/5x/10x definitions.
- All DI dictionary globals include `g-global-telltales-enabled`, so keys opted out of globals are
  skipped.

## Step 4 — Suggested enforcement posture

| Situation | Recommended posture |
| --- | --- |
| Dict 1 at 2x on a sensitive flow (login, signup, payment, OTP) | Strong candidate for high pressure |
| Dict 1 at 1x | Step-up or moderate pressure; Dict 1 is now small, but check the browser mix first |
| Dict 3–31 at 6x | Strong candidate for high pressure |
| Dict 3–31 at 4x | Mitigate, especially with other bot signals |
| Dict 3–31 at 2x | Monitor or step-up only |
| Dict 3 on a proxy key | Don't use; use other signals |

## Step 5 — Investigating a DI flag

1. Check the integration type (Step 1). On a proxy key, treat DI velocity with caution.
2. Confirm which dictionary and tier fired, and the session's `di_short_term_threshold_ratio`.
3. Check `cdn__ja4_hash_at_session_created`. A single hash covering many users or ASNs points to a
   proxy, CDN or shared client, not a single device.
4. Check the browser and OS mix of the sessions that fired.
5. Compare with the key's dictionary mix in the saved query.
6. Recommend a tier or pressure change. Don't hand-edit DI thresholds without Detection; they are
   moving to per-dictionary automated thresholds (DETCORE-4329).

## Don'ts

- Don't put Dict 3 telltales on proxy keys.
- Don't use the old Dict 1 5x/10x or Dict 3–31 1x tiers for new custom telltales.
- Don't assume a dictionary means what it meant before 30 Sep. Re-check old custom DI telltales.

---

# Rolling it out to accounts

The plan matches the IP connection-type rollout. The only change per account is the DI dictionary
multipliers (and Dict 3 off on proxy keys). It runs from the **week of Monday 26 October 2026**,
account by account, with TSE.

## Before 26 October (one-off)

| # | Step | Owner |
| --- | --- | --- |
| 1 | SOC enablement session; SOC has this page and the saved query | Detection |
| 2 | THR creates the new global tiers (Dict 1 2x; Dict 3–31 2x and 6x), promotes Dict 1 1x, and carries the proxy exclusion onto every new Dict 3 tier | THR |
| 3 | Agree risk scores and pressure for the new tiers, and whether to band them | Detection + SOC |
| 4 | Decide what happens to the old tiers (Dict 1 5x/10x, Dict 3–31 1x): retire, or demote to suspicion flags during the rollout | Detection + THR |
| 5 | Agree the account order and a TSE owner per account; confirm the CHNGE route | Detection + TSE + SCOPE |

## Proposed waves

| Wave | Week of | Keys | Why |
| --- | --- | --- | --- |
| 1 | 26 Oct | Proxy keys: confirm Dict 3 is off. Accounts from the JA4 confirmation work: AT&T, Airbnb, Roblox, CTM UK (vanity) | Already analysed, known before/after |
| 2 | 2 Nov | Remaining standard and vanity keys with DI pressure today | Same playbook |
| 3 | 9 Nov | Remaining keys, and keys with custom DI dictionary telltales | Need per-key review |

**DECISION:** confirm the waves and dates with TSE.

## Steps per account

1. **Integration type.** Standard, vanity or proxy (Step 1 above).
2. **Pre-checks with TSE:**
   - List the key's DI telltales with pressure: the globals, and any custom telltales that test
     `di_dictionary_num_matched` directly. Custom telltales do not pick up global edits.
   - Note customer constraints and whether the customer needs to be told.
3. **Baseline (last 7 days).** Firing and pressure for the key's current DI telltales, and its
   dictionary mix from the saved query.
4. **Shadow (2–3 days).** Watch the new tiers with no pressure. Compare firing with the old tiers.
5. **Raise the CHNGE.** Include the tiers to pressure and values, which old tiers come off, Dict 3
   off for proxy keys, and the rollback.
6. **Go live** in the agreed window.
7. **Monitor** at 24 h, 48 h and 7 days: firing, challenge and solve rates, FP tickets. TSE confirms
   with the customer where relevant.
8. **Clean up.** After 7 clean days, remove the old tiers from the key and mark it done in the
   tracker.

**Rollback:** put pressure back on the old tiers and remove it from the new ones.

## Who does what

| Role | Responsibilities |
| --- | --- |
| **Detection** | Data, telltale definitions, pressure guidance, escalations |
| **SOC** | Shadow, analysis, CHNGE, go-live, monitoring |
| **TSE** | Account readiness, customer context and comms, post-go-live check |
| **THR** | Creating and promoting the global tiers, proxy exclusions |

---

# FAQs

## How do I know whether a key is a proxy integration?

Check [Proxy Integrations](https://arkoselabs.atlassian.net/wiki/spaces/THRE/pages/4726390843)
(THR re-verifies it regularly; last 13 Oct). On those keys the `cdn__*` fields, including the JA4
hash, describe the proxy, not the user.

## When exactly did the switch happen?

The DI pipeline promotion ran on **30 Sep 2026** under [CHNGE-6290](https://arkoselabs.atlassian.net/browse/CHNGE-6290)
(DETCORE-4291, DETCORE-4319). Signatures changed wholesale, so DI velocity counts restarted from
zero and warmed up over the following hours. Dictionaries rebuild over a rolling 14-day window, so
the mix kept settling into mid-October.

## Why does Dict 1 get *lower* multipliers now?

Before, Dict 1 was full of legitimate browsers whose canvas fingerprint was randomised, so a low
multiplier caused FPs and it needed 5x and 10x. With JA4, those browsers match higher
dictionaries (Firefox in Dict 1 dropped by about 99%). What is left in Dict 1 is a small,
genuinely unrecognised population, so it can fire at 1x and 2x.

## Why do Dicts 3–31 get *higher* multipliers?

They now hold much more legitimate traffic (Dict 7 grew by about 75% and Dict 31 by about 60%), so
the 1x tier fires on ordinary users. Starting at 2x and adding 6x keeps the signal and cuts the
noise.

## Why only Dict 3 off for proxy keys?

Dict 3 is where proxy collapse shows most: 44–50% of Dict 3 sessions breach on Pinterest Login and
Payoneer Login. Most of the Dict 3 globals already exclude these keys today. The other dictionaries
stay on, but watch them: on Payoneer Login, 42.9% of Dict 63 sessions also breached on 13 Oct.
**VERIFY** whether any custom Dict 63 telltales carry pressure there.

## Which keys are excluded from the Dict 3 globals today?

The Dict 3 globals carry a `public_key NOT_IN` list of 11 keys:
- Pinterest Login, Registration and Challenge;
- Payoneer Login, CLM Registration, Registration and BLS;
- four Hornet keys (iOS, Android, Web, HornetX Web).

The Hornet keys and Pinterest Challenge aren't on the Proxy Integrations page. **VERIFY** why they
are excluded (possibly the "two other keys" in ESM-6922).

**DECISION:** replace the hard-coded lists with one shared include (a single proxy-key list), so new
tiers and new proxy keys stay in sync.

## Do the Dict 1 telltales still need the challenger condition?

The Dict 1 globals require `di__challenger_dictionary_num_matched = 1`. Since the promotion, the
challenger is the same JA4 recipe as the champion, so on 13 Oct 99.9% of Dict 1 sessions also had
challenger = 1. The condition is harmless today but **will change behaviour silently** when the
challenger slot is reloaded with the next recipe (Challenger v2). **DECISION:** drop it from the new
Dict 1 tiers.

The Dict 1 5x telltale also excludes Mobile Safari and Samsung Browser, and 10x excludes Samsung
Browser. Re-check whether those carve-outs are still needed with JA4 before copying them.

## What about per-dictionary thresholds?

Per-dictionary automated thresholds (DETCORE-4329) will give each dictionary its own learned
threshold. The multipliers here sit on top of whatever threshold applies. Once per-dictionary
thresholds go live, re-check the multipliers, because the base threshold for each dictionary will
move.

## Are bots getting into Dict 63?

Yes, there is an open escalation where bots self-promote into Dict 63
([ESM-6914](https://arkoselabs.atlassian.net/browse/ESM-6914), DETCORE-4387). There is no global
Dict 63 threshold telltale, so use other signals there.

## What about custom telltales that test the dictionary number directly?

Custom telltales don't pick up changes to the globals. Review them per key during the rollout. The
[ESM-6392 appendix](https://arkoselabs.atlassian.net/wiki/spaces/SB/pages/4759159236) lists custom
telltales that test `di_dictionary_num_matched` directly.

## Which global DI telltales exist today?

From Dataswan, 15 Oct:

| Telltale | Type | Risk score |
| --- | --- | --- |
| `g-di-dict-1-match-short-term-threshold-exceeded-1x` | suspicion flag | 1 |
| `g-di-dict-1-match-short-term-threshold-exceeded-5x` | telltale | 30 |
| `g-di-dict-1-match-short-term-threshold-exceeded-10x` | telltale | 30 |
| `g-di-dict-1-match-long-term-threshold-exceeded` | suspicion flag | 1 |
| `g-di-dict-3-match-short-term-threshold-exceeded-1x` / `-4x` | telltale | 70 / 95 |
| `g-di-dict-3-match-long-term-threshold-exceeded` | telltale | 85 |
| `g-di-dict-7-match-short-term-threshold-exceeded-1x` / `-4x` | telltale | 85 / 90 |
| `g-di-dict-7-match-long-term-threshold-exceeded` | telltale | 85 |
| `g-di-dict-15-match-short-term-threshold-exceeded-1x` / `-4x` | telltale | 50 / 85 |
| `g-di-dict-15-match-long-term-threshold-exceeded` | telltale | 85 |
| `g-di-dict-31-match-short-term-threshold-exceeded-1x` / `-4x` | telltale | 50 / 85 |
| `g-di-dict-31-match-long-term-threshold-exceeded` | telltale | 70 |
| `g-di-dict-neg1-match-short-term-threshold-exceeded` / long-term | telltale | 85 / 85 |

The full Device Intel list (28 telltales) is in
[Global telltales list §2.8](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/1808203779/Global+telltales+list#2.8-Device-Intel-(28)).
That page still shows the old tiers and needs updating after the rollout.

## What is still open?

| Item | Owner | Type |
| --- | --- | --- |
| Create Dict 1 2x and Dict 3–31 2x and 6x; promote Dict 1 1x | THR | Action |
| Retire or demote the old tiers (Dict 1 5x/10x, Dict 3–31 1x) | Detection + THR | DECISION |
| Band the new tiers or keep stacking | THR | DECISION |
| Drop `di__challenger_dictionary_num_matched = 1` from the Dict 1 tiers | THR | DECISION |
| Re-check the Mobile Safari and Samsung carve-outs on Dict 1 | THR | VERIFY |
| One shared proxy-key list instead of hard-coded `NOT_IN` lists | THR | DECISION |
| Why the Hornet keys and Pinterest Challenge are in the Dict 3 exclusion | THR | VERIFY |
| Payoneer Login: high Dict 63 breach rate (42.9% on 13 Oct) | Detection | VERIFY |
| Update Global telltales list §2.8 after rollout | THR | Action |

---

# Related Jira and References

- **CHNGE-6290** (30 Sep): DI challenger promoted to champion, canvas FP → JA4. **DETCORE-4291**, **DETCORE-4319**.
- **ESM-6922:** JA4 collapses DI signatures on proxy integrations. **ESM-6914 / DETCORE-4387:** bots self-promote into Dict 63.
- **ESM-5514, ESM-6791, ESM-6815:** Dict 1 FPs fixed by the promotion.
- **DETCORE-4329:** per-dictionary DI thresholds. **DETCORE-4334 / THR-1233:** telltale multipliers.

**Confluence pages:**
- [DI Challenger Promotion (Canvas FP → JA4): Effort Analysis & Promotion Plan](https://arkoselabs.atlassian.net/wiki/spaces/EN/pages/4654497793)
- [JA4 Hash Final Confirmation — Customer Escalation Accounts](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4637327365)
- [Proxy Integrations](https://arkoselabs.atlassian.net/wiki/spaces/THRE/pages/4726390843)
- [Per-Dictionary DI Velocity Thresholds](https://arkoselabs.atlassian.net/wiki/spaces/DE/pages/4661411848)
- [Global telltales list §2.8 Device Intel](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/1808203779/Global+telltales+list#2.8-Device-Intel-(28))
- [Detection Q3 2026 Breakdown](https://arkoselabs.atlassian.net/wiki/spaces/DE/pages/4750475270)
