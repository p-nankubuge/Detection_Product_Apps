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
AND behavioral_analysis__mouse__events_count >= 6
AND public_key NOT IN (<Arkose QA synthetic keys>)
```

In the sample, excluding QA, this fires on ~7.3k of 6.5M mouse sessions (~0.11%). Every key it hits is
explained by automation (Gtop100, Roblox) except Amazon Client (129), which needs a look.

Open items:

- **The events threshold has no margin.** The AT&T attack had exactly 6 events, so `>= 6` only just keeps
  it. Test `>= 4` and `>= 5` against the Adobe-style collisions before fixing the value.
- **Amazon Client — Key 1 (`2F1CD804-…`).** One track, 43 IPs, Mobile Safari, malformed events, 128/129
  solved. Confirm it's automation, not a customer test harness, before going live there.
- **QA synthetics.** A global deny would hit New-Synthetics-Key. Exclude it, or confirm with QA that a deny
  doesn't break the monitor.
- **Coverage.** In-game mouse data only exists on desktop. Mobile/touch replay needs its own signal (out of
  scope here).
- **`bba-3-axis-mouse-replay` is blind to short scripts** (>9 events required). Revisit if it's meant to
  catch replays.
- **Full run.** This is a 4 h/day sample. Run the full 14 days per key before the CHNGE.
