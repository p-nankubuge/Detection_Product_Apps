# Mouse-replay post-solve deny — findings

Context: AT&T Consumer Login Key 3 (`FAD1C7FA-…`) attack, Sept 19–21 2026. Flagged sessions solved the
challenge anyway because the replay signal (`bba-4-axis-mouse-replay`) is a 0-score suspicion flag. Ask:
turn in-game mouse replay into a standing post-solve deny at `game_verify`, platform-wide, and use it as the
high-confidence trigger for auto-punish. Page-level, touch and keyboard biometrics are out of scope.

Source: `arkoselabs.events_faster` (Athena via Superset), `location = 'game_verify'`. Queries in
`queries/replay_post_solve_sweep.sql`.

## 1. The AT&T attack (Sept 19–21, Key 3)

- 134.0k attack sessions at `game_verify`, 127.9k solved.
- One replayed track: `four_axis_key = f87ec7149dea28bced37324a30bc1b6d`. 6 mouse events (3 clicks), no
  movement, 1 ms click, `exact_match_cnt` ~4,000. No other track repeated ≥20× in any 6 h window.
- Ran Sept 19 18:00 → Sept 21 18:00 UTC (probes from 06:00 on the 19th). Solve rate drops to 71% from
  Sept 21 06:00 (SOC's manual telltale), gone after 18:00.
- Only ~26k of ~2.9M non-attack `game_verify` sessions on the key carry in-game mouse data. Mouse signals
  cover desktop only.

Mouse suspicion flags on the attack vs the other 26k mouse sessions on the key:

| Flag | Attack recall | Other hits |
|---|---|---|
| `bba-4-axis-mouse-replay`, `-above-10` | 100% | 0 |
| `g-biometric-mouse-exact-replay` | 100% | 2 |
| `g-biometric-mouse-click-fast` | 100% | 42 |
| `g-biometric-no-mouse-movement` | 100% | 233 |
| `bio-timing-h-click-faster-than-10ms` | 100% | 588 |
| `g-biometric-anomalies` | 100% | 1,553 |
| `…has-fast-click` / `…low-coordinate-count` / `…short-interaction` | 100% | 7k–11k |
| `bba-3-axis-mouse-replay` | **0%** (needs >9 events) | 0 |
| `bba-4-axis-mouse-replay-above-2-below-11` | 0% | 0 |

## 2. Platform-wide sweep (Sept 24 – Oct 7)

Sample: 4 hours/day (03, 09, 15, 21 UTC) × 14 days, all keys, `game_verify` sessions with in-game mouse
data. 6.53M sessions. This is a sample, not the full 14 days.

Daily totals are steady at ~22k `bba-4-axis-mouse-replay` hits per sampled day on 3–8 keys. From Oct 4 the
low-repeat bucket (`above-2-below-11`) rises (446 → 2,226/day) and distinct tracks jump from tens to thousands.

**Candidates tailored to the AT&T script don't generalise.** `replay-above-10 AND g-biometric-no-mouse-movement`
fired 21 times in the whole sample. The other replay traffic moves the mouse, so this candidate is too specific.

### Who replay hits (Oct 4–7 sample, 16 h)

| Key | Replay hits | `>10` repeats | `>10` & ≥6 events | Tracks (`>10`) | IPs | Solved | Read |
|---|---|---|---|---|---|---|---|
| Arkose Labs QA — New-Synthetics-Key | 88,517 | 88,517 | 88,517 | 1 | 1,351 | 0 | **Our synthetic monitor.** Go-http-client. Must be excluded. |
| Gtop100 — Production | 18,759 | 5,600 | 5,600 | 346 | 5 | 5,600 | Solve farm (5 IPs, all solved, malformed events). True positive. |
| Roblox Signup — Key 2 | 1,505 | 1,505 | 1,505 | 1 | 972 | 0 | Standing bot, already failing. |
| Amazon Client — Key 1 | 131 | 129 | 129 | 1 | 43 | 128 | One track across 43 IPs, malformed events. Likely automation. **Review.** |
| Roblox Login — Key 1 | 257 | 73 | 73 | 69 | 70 | 0 | Bot track pool, already failing. |
| Adobe Sign Up — Key 2 | 411 | 21 | **0** | 19 | 21 | 16 | Short tracks (median 2 events) colliding by chance. **False-positive risk.** |
| Hornet / Amazon IDS / Bumble / Meta | 4–36 each | 0 | 0 | — | — | — | Same short-track collision pattern. Removed by `>10`. |

The earlier sample (Sept 24 – Oct 1) shows the same shape: QA synthetics dominate, then a few hundred on
Amazon Client, Roblox and Bumble, plus 10 leftover hits on AT&T Key 3 (same 1-track malformed pattern).

Replay hits with no other biometric anomaly (`NOT g-biometric-anomalies`) are 0–11 per sampled day. Almost
every replay hit is corroborated by another biometric anomaly.

## 3. Where false positives come from

Short tracks (1–4 events) are not unique. Two humans tapping the same spot produce the same 4-axis key.
That is where every diffuse hit comes from (track count ≈ hit count, 1 IP per hit, median repeat 1–5). Two
guards remove it in this sample:

1. **Repeat count > 10** (`bba-4-axis-mouse-replay-above-10`). This removes Hornet, Amazon IDS, Bumble and
   Meta, and cuts Adobe from 411 to 21.
2. **Events count ≥ 6.** This removes the rest of Adobe (0 left).

## 4. Candidate rule (needs owner decision)

```
location = game_verify
AND has(suspicion_flags, 'bba-4-axis-mouse-replay-above-10')
AND behavioral_analysis__mouse__events_count >= 4   -- see section 5
AND public_key NOT IN (<Arkose QA synthetic keys>)
```

In the sample, excluding QA, this fires on ~7.3k of 6.5M mouse sessions (~0.11%). Every key it hits is
explained by automation (Gtop100, Roblox) except Amazon Client (129), which needs a look.

## 5. Events threshold: ≥4 vs ≥5 vs ≥6 (AT&T, Roblox, Adobe — full 14 days)

All hours Sept 24 – Oct 7 (not sampled), `game_verify`, sessions with in-game mouse data, accounts AT&T
(23583), Roblox (21178) and Adobe (23423). Base: `bba-4-axis-mouse-replay-above-10`.

| Account | Mouse sessions | `>10` hits | ≥4 events | ≥5 | ≥6 | Of those solved | Hits with 4–5 events | Hits with <4 events |
|---|---|---|---|---|---|---|---|---|
| AT&T | 344,708 | 1,365 | 1,365 | 1,365 | 1,365 | 257 | 0 | 0 |
| Roblox | 7,843,334 | 6,678 | 6,678 | 6,678 | 6,678 | 3,864 | 0 | 0 |
| Adobe | 352,506 | 82 | **0** | **0** | **0** | 0 | 0 | 82 |

- **4, 5 and 6 give identical results** on these accounts. No high-repeat replay hit had 4 or 5 events.
  Every bot hit had ≥6 and every Adobe collision had <4.
- **Adobe:** 82 high-repeat hits over 14 days (Oct 4 only: 66 + 16), all under 4 events. Every threshold
  removes them. Zero Adobe sessions would be denied.
- **AT&T:** 1,365 hits. Most are **AT&T Consumer SDK Android Key 4** (`4DD22AF2-…`): 1,159 on Oct 2
  12:00–24:00 (72 solved), then 80 + 105 on Oct 7, all solved. This fits the Key 4 attack Rahul raised on
  the Oct 5 call. The rest are small Key 3 (`FAD1…`) bursts (1–10, unsolved).
- **Roblox:** 6,678 hits, almost all **Roblox Signup Key 2** (`A2A14B1D-…`). Bursts Oct 1–3 were mostly
  solved (3,864 solved in total). The Oct 7 burst (2,348) went unsolved. Login Key 1 and Game Join Key 6
  hits were all unsolved.

**Recommendation: `events_count >= 4`.** It costs nothing in false positives on these three accounts and
leaves 2 events of margin under the 6-event AT&T script. Note there was no 4–5-event traffic to test
against, so this shows ≥4 is safe here, not that it catches more. Re-check on the platform-wide run.

Open items:

- ~~The events threshold has no margin.~~ Resolved for AT&T/Roblox/Adobe (section 5): use `>= 4`.
- **Amazon Client — Key 1 (`2F1CD804-…`).** One track, 43 IPs, Mobile Safari, malformed events, 128/129
  solved. Confirm it's automation, not a customer test harness, before going live there.
- **QA synthetics.** A global deny would hit New-Synthetics-Key. Exclude it, or confirm with QA that a deny
  doesn't break the monitor.
- **Coverage.** In-game mouse data only exists on desktop. Mobile/touch replay needs its own signal (out of
  scope here).
- **`bba-3-axis-mouse-replay` is blind to short scripts** (>9 events required). Revisit if it's meant to
  catch replays.
- **Full run.** This is a 4 h/day sample. Run the full 14 days per key before the CHNGE.

## 6. `bba-3-axis-mouse-replay` platform-wide (correction to section 1)

Section 1 marked this flag 0% because it can't see the AT&T script (it needs >9 mouse events; that bot had
6). That judged it against one attack. The ask is a *set* of high-confidence in-game biometric signals for
post-solve deny and auto-punish, across all keys. So this flag was re-checked on its own.

Sample: all keys, `game_verify`, 4 h/day (03/09/15/21 UTC) on Sept 6–7, 12–13, 18–19 and Oct 4–5 (32 h,
roughly 1.8M in-game mouse sessions). The 3-axis flag matches identical *coordinates* while ignoring timing
(`exact_match_no_time_cnt`), so it catches replays with randomised timing, which defeat the 4-axis flag.

Hits excluding Arkose QA synthetics (~44k per sample, always also caught by 4-axis):

| Key | Hits (sum of samples) | Solved | Also 4-axis `>10` | Read |
|---|---|---|---|---|
| Gtop100 — Production | 10,179 | 10,177 | 1,445 | Solve farm; Sept 12–13 hits are **Headless Chrome**. 4-axis misses ~85%. |
| Amazon IDS — Key 2 | 4,243 | 3,236 | 3,762 | Sept 6–7 attack (3.7k IPs, 24 tracks). |
| Adobe Sign Up — Key 2 | 1,047 | 853 | 21 | Oct 4–5: 46 tracks repeated ~274× across 520 IPs. **A real replay attack, not collisions.** 4-axis missed it. |
| Bumble SMS Mobile — Key 4 | 1,182 | 756 | 0 | Sept 18–19 burst, 71 tracks. |
| Amazon Client — Key 1 | 858 | 858 | 850 | Same single-track automation seen in section 2. |
| Unknown key `0152B4EB-…` | 732 | 674 | 0 | Key not found in Dataswan. |
| Roblox Login — Key 1 | 437 | 0 | 0 | Already failing. |
| Hornet Registration — Key 1 | 412 | 0 | 0 | Already failing. |
| Expedia BEXG Login — Key 4 | 272 | 31 | 0 | |
| Roblox Other — Key 3 | 222 | 222 | 0 | Oct 4–5. |
| Roblox Signup — Key 2 | 167 | 163 | 83 | |
| Others (Agoda, Meta, Tinder, Uber, Blizzard, WBD, …) | 1–53 each | — | ~0 | Small; includes rows with low repeat counts and few IPs. **These are the false-positive-risk tail to review.** |

Takeaways:

- **Complementary to 4-axis, not redundant.** On most keys above, 4-axis `>10` caught little or nothing of
  what 3-axis caught (Gtop100, Adobe, Bumble, the unknown key, Roblox Other/Login, Hornet, Expedia).
- **It never fires on AT&T Key 3** (short scripts). The two flags cover different bot styles: 4-axis catches
  short exact replays, 3-axis catches longer replays with jittered timing.
- **Revises section 2 on Adobe.** The Oct 4 Adobe 4-axis hits under 4 events were collisions, but Adobe *was*
  under a separate replay attack the same days, which only 3-axis sees.
- **Next:** measure the 3-axis tail per key (repeat count vs IPs vs events) to set a repeat-count floor, the
  same way `>10` was set for 4-axis. Then propose both as deny signals:
  `(4-axis >10 AND events >= 4) OR (3-axis AND <repeat floor TBD>)`.

---

# Part 2 — other replay signals, touch, and behaviour flags (12 Oct)

## 7. Other mouse replay signals (all keys, one table per signal)

Samples: all keys, `game_verify`, sessions with in-game mouse data, Arkose QA synthetic monitor excluded. **S1** = 6–7 Sept, **S2** = 4–5 Oct (4 hours a day, 16 hours each; S1 = 1,195,594 mouse sessions).

### 7a. `g-biometric-mouse-no-time-replay`

Definition: `exact_match_no_time_cnt > 3` AND `events_count > 9` AND touch null session. **This is the same definition as `bba-3-axis-mouse-replay`.**

| Sample | Hits | Solved | Keys | Also `bba-3-axis-mouse-replay` |
|---|---|---|---|---|
| S1 | 5,457 | 4,367 | 12 | 5,457 (100%) |
| S2 | 10,157 | 9,335 | 18 | 10,157 (100%) |

**Verdict:** duplicate of section 6. Adds no coverage.

### 7b. `g-biometric-mouse-exact-replay`

Definition: `exact_match_cnt > 1` AND `events_count > 0` AND touch null session (a looser 4-axis: repeat above 1 instead of above 2).

| Sample | Hits | Solved | Keys | Also 4-axis `>10` & ≥4 events | Also 3-axis |
|---|---|---|---|---|---|
| S1 | 6,539 | 5,323 | 11 | 6,416 | 4,320 |
| S2 | 7,361 | 7,142 | 8 | 1,934 | 6,364 |

| Key (S2) | Hits | Solved | IPs | Median events | Read |
|---|---|---|---|---|---|
| Gtop100 – Production | 6,401 | 6,401 | 6 | 9 | Solve farm. Catches more than 4-axis `>10` (1,856), but 5,636 are already caught by 3-axis. |
| Adobe Sign Up – Key 2 | 541 | 439 | 371 | 8 | All also caught by 3-axis. |
| Amazon IDS – Key 2 | 209 | 209 | 207 | **1** | 1-event sessions: chance collisions. |
| Hornet Registration – Key 1 | 111 | 0 | 103 | 6 | Already failing. |

**Verdict:** possible third signal, but only with an events guard (≥4), and its gain over 4-axis + 3-axis is small. Low priority.

### 7c. `bba-4-axis-mouse-replay-above-2-below-11`

Definition: `bba-4-axis-mouse-replay` AND `exact_match_cnt < 11` (exact track repeated 3–10 times).

| Sample | Hits | Solved | Keys | IPs | Also 3-axis |
|---|---|---|---|---|---|
| S1 | 12 | 10 | 2 | 11 | 10 |
| S2 | 1,363 | 1,335 | 7 | 112 | 1,057 |

S2: 1,250 of the 1,363 were Gtop100 (5 IPs, all solved, 1,066 tracks): a farm that spreads its recordings so each one repeats only a few times. 969 of those are already caught by 3-axis. This band is also where short-track chance matches sit (Adobe, section 5b).

**Verdict:** mixed. Not a deny signal; can feed pressure.

### 7d. `mouse-replay-1250`

Definition: one hard-coded mouse track (`biometrics_mouse = "1250,0,147,204;…"`) from a 2024 Microsoft Identity attack, cloned as global.

| Sample | Hits |
|---|---|
| S1 | 0 |
| S2 | 0 |

**Verdict:** dead. It can only match that one recording. Candidate for retirement.

**Not evaluated as global candidates:** key-scoped replay flags (Microsoft Identity, Snap, Twitter, Sony, Meta). They're tied to one key by design.

**Also found:** AT&T Key 3 had an earlier replay burst on **6–7 Sept**: 2,185 hits, 2,012 solved, same 6-event no-movement style (median track repeat about 1,138). The 19–21 Sept attack wasn't the first.

---

## 8. Touch replay signals (all keys, one table per signal)

Touch sessions at `game_verify` (touch track present): **584,834** in S1 and **476,893** in S2, on 127–128 keys. Median 5 touch events; **27% have fewer than 4 events** (single taps). Only 50 (S1) and 187 (S2) touch sessions in total repeated an exact track more than 10 times.

### 8a. `g-biometric-touch-exact-replay`

Definition: `touch__exact_match_cnt > 2` AND `touch__events_count > 0` (no repeat floor, no events guard).

| Sample | Hits | Solved | Keys | IPs | Median events | Repeat >10 & ≥4 events |
|---|---|---|---|---|---|---|
| S1 | 136 | 128 | 4 | 43 | 1 | 0 |
| S2 | 2,412 | 916 | 5 | 1,994 | 2 | 23 (8 solved) |

| Key (S2) | Hits | Solved | IPs | Median events | Read |
|---|---|---|---|---|---|
| Roblox Login – Key 1 | 1,430 | 0 | 1,083 | 3 | Already failing. |
| Roblox Signup – Key 2 | 586 | 581 | 565 | 3 | Short taps; looks like chance matches. |
| Uber SMS – Key 1 | 328 | 318 | 309 | 1 | Single taps landing on the same pixel. In one hour on 30 Sept this key alone had **9,184 hits (99% solved, median 1 event)**. These are real users, not an attack. |
| Bumble SMS Mobile – Key 4 | 67 | 16 | 29 | 3 | The only high-repeat cluster (6 tracks, repeat median 22). |

**Verdict:** as written, mostly chance matches from single taps. With the same guards as mouse (repeat >10, ≥4 events), almost nothing is left (0 and 23 sessions). **No meaningful touch replay attack is visible in these samples.**

### 8b. `g-biometric-touch-no-time-replay`

Definition: `touch__exact_match_no_time_cnt > 100` AND `touch__events_count > 0`.

| Sample | Hits | Solved | Keys | IPs | Median events | Under 4 events |
|---|---|---|---|---|---|---|
| S1 | 3,055 | 3,027 | 3 | 291 | 4 | 1,229 |
| S2 | 24,738 | 24,722 | 1 | 14,397 | 3 | 14,937 |

S1: Gtop100 2,559 and Roblox Game Join 493. S2: all on **Roblox Signup – Key 2**: 14,397 IPs, 24,635 distinct exact tracks, 99.9% solved, median 3 events.

**Verdict:** not usable as is. The S2 spike is short taps sharing the same coordinates across 14k IPs, which looks like same-device-model users tapping the same button rather than one bot. Needs an events guard and a review of Roblox Signup before it can be judged.

**Touch summary:** the gap is real (about 99% of AT&T Key 3 traffic has no mouse data), but **touch replay isn't how mobile bots are getting through** in these samples. Mobile needs a different kind of signal (device/SDK integrity, IP, velocity) rather than a touch-replay deny.

---

## 9. Making the behaviour flags usable: IP add-ons (tested one at a time)

The behaviour flags (no movement, fast click, 6 events, no input) fire on 0.4–1.1% of mouse sessions across 30–64 keys, mixing bots and people. Test: add **one** IP signal from the *IP Intelligence Improvements Q4 2026 – Phase 1* one-pager at a time and see whether the remaining hits look more like bots.

**How "looks like bots" is measured:** the share of hits *also* caught by a replay signal (4-axis `>10` & ≥4 events, or 3-axis). Replay is our near-certain bot marker, so this is a **lower bound** on bot share: bots that don't replay aren't counted. Baseline across all mouse sessions: **0.64%**.

Sample S1 (6–7 Sept, 1,195,594 mouse sessions, all keys).

### 9a. `g-biometrics-no-mouse-movement-no-biometric-touch-no-keyboard-input`

| Add-on | Hits | Solved | Keys | Replay-confirmed |
|---|---|---|---|---|
| None (flag alone) | 6,578 | 5,895 | 50 | 2,881 (44%) |
| Datacenter IP | 1,094 | 989 | 28 | 460 (42%) |
| High-risk ASN band | 615 | 514 | 7 | 334 (54%) |
| Harvested proxy | 266 | 242 | 16 | 160 (60%) |

### 9b. `g-biometric-no-mouse-movement`

| Add-on | Hits | Solved | Keys | Replay-confirmed |
|---|---|---|---|---|
| None (flag alone) | 7,563 | 6,744 | 51 | 2,881 (38%) |
| Datacenter IP | 1,201 | 1,079 | 30 | 460 (38%) |
| High-risk ASN band | 680 | 573 | 7 | 334 (49%) |
| Harvested proxy | 320 | 287 | 20 | 160 (50%) |

### 9c. `g-biometric-mouse-click-fast`

| Add-on | Hits | Solved | Keys | Replay-confirmed |
|---|---|---|---|---|
| None (flag alone) | 4,314 | 3,896 | 30 | 2,787 (65%) |
| Datacenter IP | 713 | 619 | 19 | 335 (47%) |
| High-risk ASN band | 384 | 295 | 9 | 312 (81%) |
| Harvested proxy | 218 | 201 | 11 | 156 (72%) |

### 9d. `mouse-behavioral-analysis--mouse--events-count-is-6`

| Add-on | Hits | Solved | Keys | Replay-confirmed |
|---|---|---|---|---|
| None (flag alone) | 12,759 | 4,432 | 43 | 2,768 (22%) |
| Datacenter IP | 8,293 | 528 | 22 | 355 (4%) |
| High-risk ASN band | 1,353 | 340 | 9 | 318 (24%) |
| Harvested proxy | 235 | 216 | 16 | 161 (69%) |

(Datacenter + 6 events is mostly Roblox Game Join traffic that already fails: 8,293 hits, 528 solved.)

**Add-ons that didn't work at `game_verify`:**

- **Datacenter with no fingerprint (2e):** only 377 mouse sessions in the whole sample. Scripts without a fingerprint rarely reach the game, so 2e belongs at `session_setup`, not here.
- **Commercial VPN (`hosting` + `vpn`):** 0 hits on these flags.
- **IP velocity ratio:** not populated at `game_verify` (0%). Using it needs a join to the `session_setup` event.

**What this shows:**

- **High-risk ASN and harvested proxy help the most.** They lift the replay-confirmed share from 22–65% to 49–81%, but cut coverage by 85–98%.
- **Datacenter alone doesn't help** (flat, or worse on fast-click and 6-events).
- **None of these pairs reaches deny grade** (replay signals are about 100%). They're good for **pressure tiers and auto-punish escalation**, not for a standalone deny.

**Other add-ons worth testing next (not yet run):**

1. **Key-level spike:** fire when a behaviour flag's rate on a key jumps above its own baseline. This is how SOC already spots attacks, and it fits the throughput-based auto-escalation the Automation team is scoping.
2. **IP velocity** from `session_setup`, joined on session.
3. **Device Intelligence low-trust dictionary** and **JA4 bot hashes**, already present in suspicion flags.
4. **Many IPs sharing one track or device**: the coordination tell behind replay, but applied to fingerprints.
5. **Solve-timing flags** (`bio-timing-h-*`).
