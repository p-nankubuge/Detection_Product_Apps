# SDV key-scoped suspicion flags for pressure (Roblox Key 2, Blizzard ROW Key 2)

These are key-scoped copies of the global SDV flags, for the four flag-and-key pairs selected for pressure. All four passed Dataswan `validate_telltale` on 16 Nov 2026. Nothing has been created yet.

The global flags (`g-sdv-*`) stay as they are for tagging and weight. These copies exist so SOC can attach pressure on each key separately.

## Common settings

| Field | Value |
|---|---|
| Telltale type | suspicion_flags |
| Location | SESSION_SETUP |
| Owner category / owner | User / p.nankubuge@arkoselabs.com |
| Ticket | DETCORE-4519 |
| Cohort category | Suspicious |
| Risk category / score | CUSTOM / 0 |
| Immediate non-legit | false |
| Life-cycle management | A |
| Degrade action | 0 |
| Allow pressure | allow |

## Evidence (live, 6–14 Nov, global flag on that key)

| Flag | Flagged | Mitigated | Transparent | Transparent passes later in truth data |
|---|---|---|---|---|
| `blizzard2-h-sdv-heavy-velocity` | 136,616 | 99.6% | 0.1% | 40% |
| `blizzard2-h-sdv-fast-repeat` | 133,755 | 99.9% | 0.0% | 40% |
| `robloxa2a1-h-sdv-device-spread` | 278,528 | 82.8% | 15.5% | 44% |
| `robloxa2a1-h-sdv-fast-repeat` | 639,641 | 94.6% | 1.2% | 12% |

Suggested pressure: a standard challenge first, not a block. Review solve rate and complaints after 24–48 hours.

Not included: Roblox heavy-velocity. Only 2% of its transparent passes are in truth data, so it stays tag-only.

## `blizzard2-h-sdv-heavy-velocity`

**Description:** SDV: device fingerprint at 4x or more the key's 1-day sign-up threshold. Key-scoped copy of g-sdv-heavy-velocity for pressure.
**External description:** Very high volume of sign-ups from the same device

```json
[
  {"key": "public_key", "operator": "TS_EQ", "value": "E8A75615-1CBA-5DFF-8032-D16BCF234E10", "type": "string"},
  {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"},
  {"key": "rta__sdv_velocity_ratio_1d", "operator": "EXISTS"},
  {"key": "rta__sdv_velocity_ratio_1d", "operator": "TS_GREATER_EQ", "value": 4.0, "type": "float"}
]
```

## `blizzard2-h-sdv-fast-repeat`

**Description:** SDV: device fingerprint over the key's 1-day sign-up threshold with sign-ups averaging 30 minutes apart or less. Key-scoped copy of g-sdv-fast-repeat for pressure.
**External description:** Repeated rapid sign-ups from the same device

```json
[
  {"key": "public_key", "operator": "TS_EQ", "value": "E8A75615-1CBA-5DFF-8032-D16BCF234E10", "type": "string"},
  {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"},
  {"key": "rta__sdv_velocity_ratio_1d", "operator": "EXISTS"},
  {"key": "rta__sdv_velocity_ratio_1d", "operator": "TS_GREATER_EQ", "value": 1.0, "type": "float"},
  {"key": "rta__sdv_mean_gap_s", "operator": "EXISTS"},
  {"key": "rta__sdv_mean_gap_s", "operator": "TS_LESS_EQ", "value": 1800, "type": "int"}
]
```

## `robloxa2a1-h-sdv-device-spread`

**Description:** SDV Cube 4: no single hardware signature accounts for half of the fingerprint's sign-ups (fingerprint randomisation). No velocity gate. Key-scoped copy of g-sdv-device-spread for pressure.
**External description:** Same device identity seen with many different hardware signatures

```json
[
  {"key": "public_key", "operator": "TS_EQ", "value": "A2A14B1D-1AF3-C791-9BBC-EE33CC7A0A6F", "type": "string"},
  {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"},
  {"key": "rta__sdv_device_top_share", "operator": "EXISTS"},
  {"key": "rta__sdv_device_top_share", "operator": "TS_LESS", "value": 0.5, "type": "float"}
]
```

## `robloxa2a1-h-sdv-fast-repeat`

**Description:** SDV: device fingerprint over the key's 1-day sign-up threshold with sign-ups averaging 30 minutes apart or less. Key-scoped copy of g-sdv-fast-repeat for pressure.
**External description:** Repeated rapid sign-ups from the same device

```json
[
  {"key": "public_key", "operator": "TS_EQ", "value": "A2A14B1D-1AF3-C791-9BBC-EE33CC7A0A6F", "type": "string"},
  {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"},
  {"key": "rta__sdv_velocity_ratio_1d", "operator": "EXISTS"},
  {"key": "rta__sdv_velocity_ratio_1d", "operator": "TS_GREATER_EQ", "value": 1.0, "type": "float"},
  {"key": "rta__sdv_mean_gap_s", "operator": "EXISTS"},
  {"key": "rta__sdv_mean_gap_s", "operator": "TS_LESS_EQ", "value": 1800, "type": "int"}
]
```
