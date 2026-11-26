# Thresholds confirmation: is "multiplier 5, floor 11" still best? (D-19)

Written by the main session from the agent's report (the agent's `summary.md` and `caveats.md` writes were blocked: "Subagents should return findings as text"). Start with `raw/10_tables.txt`. Earlier numbers reproduce exactly (Figma today 381 fires; m5 f11 335 / 96 clean; Blizzard m5 f11 39,336 / 173 clean; 9 Nov labels 141 and 488).

## In short

- **m5 f11 still looks best.** Blizzard: **198 of 5,718** confirmed-fraud labels caught over 9–11 Nov vs **5** today (10 with today's long-term check), and 173 false alarms on normal traffic vs 974. Figma: no device group fires more on normal traffic than today (G7, 20 Nov), and on 6 Nov it fires on **2 of 807** genuine-user labels (0.25%), the same 2 today does.
- **Floor 8 trades Figma for Blizzard.** Blizzard catches 354 (+156), but Figma gets 185 extra fires, High risk among fires drops 56.7% → 50.6%, 9 groups fire more than today, and genuine users fired on rise 2 → 8 (1.0%), with no fraud caught on Figma. Not adopted.
- **Both weak spots look like bursts** (consistent with, not proven): Blizzard's 50 Dict 31 Desktop "clean" fires all fall in 27 minutes; the one real loss on Figma is a 7-session burst that all failed the challenge.
- **The two-day (long-term) check adds little:** never fires on Figma; on Blizzard adds 21 labels (219 combined with short-term).
- **Figma labels show no fraud caught by any velocity rule** on 6 Nov: none of the 620 fraud labels fire under today or any new rule.

## Terms

- **m5 f11:** fire if DI's short-term count (current + previous 20 minutes) > max(11, expected × 5 × d), d = 1 (Dict 1, 3), 1.5 (7), 2 (15, 31, 63). Expected = the signature's normal share of the key's traffic × how busy the key is now. In practice the floor is min(11, the key's current threshold).
- **Clean:** the signature's 40-minute window has under 20% High-risk sessions.
- **Today:** DI's recorded breach (Figma 11 / 660, Blizzard 25 / 1,500).
- **Nonlegit / Legit labels:** the customer's after-the-fact judgement. Blizzard labels only fraud; Figma labels both.

## 1. Blizzard fraud labels caught, 9–11 Nov (all 5,718 scored)

| Rule | 9 Nov | 10 Nov | 11 Nov | Total |
|---|---:|---:|---:|---:|
| Today short-term | 4 | 0 | 1 | **5** |
| Today short- or long-term | 4 | 3 | 3 | 10 |
| **m5 f11** | 141 | 21 | 36 | **198** (3.5%) |
| m5 f8 | 262 | 33 | 59 | 354 (6.2%) |
| m10 f8 | 262 | 30 | 56 | 348 |
| m5 f5 | 488 | 47 | 85 | 620 (10.8%) |

No rule loses any of today's catches.

## 2. Floor 8

| Figma 20 Nov | Fires | High % | Clean fires | New / lost vs today | G7 failing groups |
|---|---:|---:|---:|---:|---:|
| Today | 381 | 52.8 | 131 | – | – |
| m5 f11 | 335 | 56.7 | 96 | 0 / 46 | 0 |
| m5 f8 | 520 | 50.6 | 176 | 185 / 46 | 9 |
| m10 f8 | 473 | 51.0 | 146 | 164 / 72 | 9 |

| Blizzard 9–11 Nov | Fires | High % | Clean fires | Fraud caught | G8 | G7 failing groups |
|---|---:|---:|---:|---:|---|---:|
| Today | 35,464 | 97.2 | 974 | 5 | – | – |
| m5 f11 | 39,336 | 99.3 | 173 | 198 | pass | 11 |
| m5 f8 | 42,226 | 98.7 | 317 | 354 | pass | 13 |

On Blizzard today's clean fires sit in one group (Dict 63 Other, 974, 0% High), so any clean fire elsewhere "fails" its group; the key total (173 vs 974) is the fairer view.

## 3. Weak spots (consistent with, not proven)

- **Blizzard Dict 31 Desktop, 9 Nov, 50 "clean" fires under m5 f11 (today 0):** all between 14:52 and 15:19 UTC; 9 signatures, all Windows Chrome 156 with one JA4, real GPUs; 50 distinct IPs on 19 US home ISPs; expected ≈ 0 so the floor of 11 decides (counts 12–22); 15 High (all from 15:06), 44 verified, 6 challenged-not-solved. Consistent with a coordinated campaign over residential IPs, or a short real surge. Labels on these 50 not checked.
- **Figma, the 46 fires today makes but m5 f11 doesn't (20 Nov):** 17 are List A sessions (skipped by design; 11 of 12 challenged not solved); 7 are a Dict 3 Desktop burst (07:32–08:06, Chrome 137, mobile-carrier IPs in Indonesia, India, Bangladesh; all failed the challenge), the one real loss; the rest look normal (verified, 0 High). Floor 8 recovers none.

## 4. Figma truth data, 6 Nov (807 Legit, 620 Nonlegit)

| Rule | Fires | Genuine users fired on | Fraud fired on | Unlabelled fires |
|---|---:|---:|---:|---:|
| Today | 291 | 2 (0.25%) | 0 | 289 |
| m5 f11 | 285 | 2 (0.25%) | 0 | 283 |
| m5 f8 | 512 | 8 (0.99%) | 0 | 504 |
| Any long-term | 0 | 0 | 0 | 0 |

## 5. Long-term (two-day) check, m5 f11

| Key | Rule | Fires | High % | Fraud caught |
|---|---|---:|---:|---:|
| Figma | today and new | 0 | – | 0 |
| Blizzard | today long-term | 32,843 | 100.0 | 6 |
| Blizzard | new long-term | 37,019 | 100.0 | 36 |
| Blizzard | long-term only | 1,462 | 99.6 | 21 |
| Blizzard | short- or long-term, m5 f11 | 40,798 | 99.3 | 219 |

## Proposed spec rows (not applied)

- Short-term: fire if count > max(min(11, key's current threshold), expected × 5 × d).
- Long-term: fire if two-day count > max(min(660, key's current long-term threshold), expected over two days × 5 × d_LT), d_LT = 1 / 1 / 2 / 4 / 4 / 6 for Dict 1 / 3 / 7 / 15 / 31 / 63. Breach = short- or long-term, as today.
- Floor 8 not adopted; reconsider per key where truth data shows uplift without a genuine-user cost.
- G7 on keys like Blizzard: report the key total next to the per-group check.

## Caveats

- Long-term buckets assumed to be UTC days; expected uses the current bucket up to the session; clean = fixed 40-minute slice with the latest risk band; no Windows RD/VM multiplier cap.
- Label join on 8 characters of the session ID (expected false matches ~0.1–0.4 a day; matched rows = matched labels every day).
- Not done: Figma m5 f5 labels; Figma 6 Nov G7 per group; labels of the 50 Blizzard Dict 31 sessions; Adobe (K3) replay.
- Timeouts worked around by per-day queries; one combined query over the response cap. Only SELECTs run.
