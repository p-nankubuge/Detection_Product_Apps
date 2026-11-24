# Figma Registration K2: sessions with no game_verify row

- **Key:** `A207F8A1-ED09-4325-ACE6-C8E26A458FBA` (Figma Registration K2)
- **Window:** sessions set up 2026-11-20 12:00–14:00 UTC; later events to 15:00; session summary to 16:00
- **Sources:** `ARK_PROD.events.vw_events` and `ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY`, Superset `database_id` 14
- **Sampling:** none (9,156 sessions; all found in the summary table)
- **Queries:** `figma_k2_no_verify.sql`

## Key fact

`game_verify` is the final verify step, not "played a challenge". It is present on silent passes too (6,896 sessions verified with no challenge). It matches the summary's `sessions_verify_attempted` exactly. Likely the customer's server checking the token when the form is submitted (not confirmed from docs).

## Final groups (from summary flags), by dictionary

| Dict | Sessions | No verify | No-verify rate | Challenged, abandoned | Solved, never verified | Silent pass, never verified | Never loaded |
|---:|---:|---:|---:|---:|---:|---:|---:|
| -1 | 1 | 0 | 0% | 0 | 0 | 0 | 0 |
| 1 | 23 | 3 | 13.0% | 3 | 0 | 0 | 0 |
| 3 | 446 | 46 | 10.3% | 41 | 1 | 1 | 3 |
| 7 | 1,138 | 110 | 9.7% | 91 | 6 | 7 | 6 |
| 15 | 1,055 | 88 | 8.3% | 80 | 5 | 1 | 2 |
| 31 | 1,470 | 85 | 5.8% | 68 | 3 | 7 | 7 |
| 63 | 5,023 | 286 | 5.7% | 242 | 7 | 19 | 18 |
| **Total** | 9,156 | **618** | 6.7% | **525 (85%)** | **22 (4%)** | **35 (6%)** | **36 (6%)** |

618, not 619 as in the event-only count: one Dict 31 session has a verify in the summary but not in events before 15:00.

## Event-based groups vs summary flags

| Event group | Sessions | Summary says | Reading |
|---|---:|---|---|
| verified_silent | 6,896 | not challenged; all verified | Silent pass |
| verified_after_puzzle | 1,641 | challenged + solved; 1,602 verified | 39 verify attempted but not verified |
| puzzle_abandoned | 316 | challenged; 0 solved; 0 verify | Abandoned |
| answered_not_finished | 162 | challenged; 22 solved; 0 verify | 140 wrong answers then quit; 22 solved but never verified |
| pow_only_no_widget | 71 | **loaded 71**; challenged; 12 PoW timeouts | Event label wrong: widget did load. Stopped at proof-of-work |
| loaded_nothing_served | 36 | not challenged; 1 verified | Silent pass, form not submitted |
| nothing_after_setup | 34 | not loaded; 21 "challenged" | Never loaded. `was_challenged` looks like the challenge *decision* |

## Event-based detail by dictionary

| Dict | Puzzle served % | Puzzle not finished % | Stopped at PoW (events) |
|---:|---:|---:|---:|
| 1 | 39.1 | 33.3 | 0 |
| 3 | 32.3 | 21.5 | 11 (2.5%) |
| 7 | 25.7 | 28.4 | 14 (1.2%) |
| 15 | 30.0 | 21.8 | 16 (1.5%) |
| 31 | 23.5 | 17.6 | 10 (0.7%) |
| 63 | 20.1 | 22.8 | 20 (0.4%) |

## Findings

- Sessions with no verify are mostly **challenged and abandoned** (85%). Silent passes that didn't complete are 6%.
- Low dictionaries drop out more (10–13% vs 5.7%) mainly because they are **challenged more often**; once challenged, ~18–28% don't finish at every dictionary.
- Stopping at proof-of-work is ~6× more common at Dict 3 than Dict 63.

## Implications for truth data (TD labels verified sessions only)

- TD covers ~93% of sessions; uplift (Nonlegit sessions let through) is unaffected.
- The missing 6.7% is concentrated in low dictionaries (~10% of Dict 1–7 vs 5.7% of Dict 63).
- TD can't say whether abandoners were stopped bots or lost real users, so the TD false-positive rate misses friction.
- For every rule, also report how many unverified sessions it would flag, separately and unlabelled.

## Not done

- Did not check TD itself: CLAUDE.md mentions an `is_verified` column, so TD may also hold some unverified sessions.
- Meaning of `game_verify` / `sessions_verify_attempted` inferred, not confirmed from documentation.
- One 2-hour window, one key.
