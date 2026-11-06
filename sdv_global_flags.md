# SDV global suspicion flags

All three passed Dataswan `validate_telltale` on 6 Nov 2026 (no errors). Nothing has been created yet.

Analysis: https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4832985107

Plan:
1. Use on Roblox Key 2 and Blizzard ROW Key 2 first.
2. Monitor only on Payoneer.

The flags have no public-key condition. They fire only where the SDV fields exist, which means keys with SDV enabled.

## Common settings (all three)

Same settings as your existing `g-` flags (public key GLOBAL):

| Field | Value |
|---|---|
| Telltale type | suspicion_flags |
| Location | SESSION_SETUP |
| Owner category / owner | User / p.nankubuge@arkoselabs.com |
| Ticket | DETCORE-4519 |
| Cohort category | Suspicious |
| Risk category / score | CUSTOM / 0 |
| Immediate non-legit | false |
| Active on creation | false |
| Life-cycle management | A |
| Degrade action | 0 |
| Allow pressure | allow |

Optional: `g-email-gibberish-handle-medium-risk` includes `#INCLUDE g-global-telltales-enabled`, which presumably limits it to keys enabled for global telltales. I did not add that include here, so these flags fire on every SDV key. Add it if you want the same global opt-in. If you do, check that Roblox and Blizzard are on that list.

## Backtest (28 Oct–2/3 Nov)

| Flag | Roblox: confirmed / possible FP: transparent / share of truth data | Blizzard: same | Payoneer CLM Key 3 |
|---|---|---|---|
| `g-sdv-fast-repeat` | 94.4% / 3.5% / 11.2% | 91.9% / 6.7% / 2.5% | 91 sessions, 33% mitigated, 0 labelled Legit |
| `g-sdv-heavy-velocity` | 83.3% / 7.5% / 11.0% | 96.6% / 1.9% / 3.4% | 0 sessions |
| `g-sdv-device-spread` | 89.1% / 9.2% / 23.3% | 51.7% / 38.9% / 0.1% | 481 sessions, 7.7% confirmed, 2 labelled Legit |

The cut-offs were chosen and tested on the same days, so re-test on 3–9 Nov before acting on them.

## `g-sdv-fast-repeat`

**Internal description:** SDV: device fingerprint over its key's 1-day sign-up threshold (velocity_ratio_1d >= 1) with an average gap between sign-ups of 30 minutes or less (mean_gap_s <= 1800). Backtest: Roblox Key 2 28 Oct-2 Nov 94.4% confirmed, 3.5% possible FP transparent, 11.2% of truth data; Blizzard ROW Key 2 28 Oct-3 Nov 91.9% / 6.7%; Payoneer CLM Key 3 91 sessions, 0 labelled Legit. Only fires on keys with SDV enabled.

**External description:** Repeated rapid sign-ups from the same device

```json
[
  {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"},
  {"key": "rta__sdv_velocity_ratio_1d", "operator": "EXISTS"},
  {"key": "rta__sdv_velocity_ratio_1d", "operator": "TS_GREATER_EQ", "value": 1.0, "type": "float"},
  {"key": "rta__sdv_mean_gap_s", "operator": "EXISTS"},
  {"key": "rta__sdv_mean_gap_s", "operator": "TS_LESS_EQ", "value": 1800, "type": "int"}
]
```

## `g-sdv-heavy-velocity`

**Internal description:** SDV: device fingerprint at 4x or more its key's 1-day sign-up threshold (velocity_ratio_1d >= 4). Backtest: Blizzard ROW Key 2 28 Oct-3 Nov 96.6% confirmed, 1.9% possible FP transparent; Roblox Key 2 28 Oct-2 Nov 83.3% / 7.5%, 11.0% of truth data; Payoneer CLM Key 3 never reached 4x. Only fires on keys with SDV enabled.

**External description:** Very high volume of sign-ups from the same device

```json
[
  {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"},
  {"key": "rta__sdv_velocity_ratio_1d", "operator": "EXISTS"},
  {"key": "rta__sdv_velocity_ratio_1d", "operator": "TS_GREATER_EQ", "value": 4.0, "type": "float"}
]
```

## `g-sdv-device-spread`

**Internal description:** SDV Cube 4: no single hardware signature accounts for half of the fingerprint's sign-ups (device_top_share < 0.5), a sign of fingerprint randomisation. No velocity gate. Backtest: Roblox Key 2 28 Oct-2 Nov 89.1% confirmed, 9.2% possible FP transparent, 23.3% of truth data; Blizzard 51.7% and Payoneer CLM Key 3 7.7% (no better than baseline). Monitor only outside Roblox. Only fires on keys with SDV enabled.

**External description:** Same device identity seen with many different hardware signatures

```json
[
  {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"},
  {"key": "rta__sdv_device_top_share", "operator": "EXISTS"},
  {"key": "rta__sdv_device_top_share", "operator": "TS_LESS", "value": 0.5, "type": "float"}
]
```
