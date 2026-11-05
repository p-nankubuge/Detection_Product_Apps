# SDV suspicion flags — Blizzard ROW Registration Key 2 (E8A75615)

Both definitions passed Dataswan `validate_telltale` on 5 Nov 2026 (no errors). Nothing has been created.

Analysis page: https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4815814669

## Common settings (both flags)

| Field | Value |
|---|---|
| Telltale type | suspicion_flags |
| Location | SESSION_SETUP |
| Owner category / owner | User / p.nankubuge@arkoselabs.com |
| Ticket | DETCORE-4519 (same as the Roblox flags; change if Blizzard needs its own) |
| Cohort category | Suspicious |
| Risk category / score | CUSTOM / 0 |
| Immediate non-legit | false |
| Active on creation | false (turn on after review) |
| Life-cycle management | A (auto) |
| Degrade action | 0 (same as the Roblox flags as created) |
| Allow pressure | allow |

## Backtest

Possible FP: transparent = transparent, verified and not in truth data. 1–4 Nov has no truth data yet, so it shows mitigated only.

| Flag | Flagged 20–31 Oct | Confirmed 20–27 Oct | Confirmed 28–31 Oct | Possible FP: transparent | Mitigated 1–4 Nov | Proposed use |
|---|---|---|---|---|---|---|
| `blizzard2-h-sdv-bzm-mitigate` | 8,240 | 98.4% | 97.9% | 0.6–1.7% | 98.1% | Mitigate |
| `blizzard2-h-sdv-bzc-challenge` | 11,327 | 90.7% | 90.7% | 1.8–3.0% | 83.0% | Challenge experiment |

The flags overlap: a session matching `top ASN + top IP + single country + subnet + mean gap` matches both. Act on BZ-M first.

## `blizzard2-h-sdv-bzm-mitigate`

**Internal description:** SDV gate (1d velocity ratio >= 1) + either (mean gap < 300 s AND top ASN share >= 0.8 AND top IP share >= 0.8 AND single country AND subnet distinct <= 3) OR (top ASN share >= 0.8 AND IP rotation AND single country AND hosting share > 0). Backtest 20 Oct-4 Nov: 98% confirmed/mitigated, 0.6-1.7% possible FP transparent.

**External description:** High-velocity sign-ups from one device concentrated on a single network or hosting provider

**Telltale definition (paste into Dataswan):**

```json
[
  {
    "key": "public_key",
    "operator": "TS_EQ",
    "value": "E8A75615-1CBA-5DFF-8032-D16BCF234E10",
    "type": "string"
  },
  {
    "key": "location",
    "operator": "TS_EQ",
    "value": "session_setup",
    "type": "string"
  },
  {
    "key": "rta__sdv_velocity_ratio_1d",
    "operator": "EXISTS"
  },
  {
    "key": "rta__sdv_velocity_ratio_1d",
    "operator": "TS_GREATER_EQ",
    "value": 1.0,
    "type": "float"
  },
  {
    "operator": "OR",
    "conditions": [
      {
        "operator": "AND",
        "conditions": [
          {
            "key": "rta__sdv_mean_gap_s",
            "operator": "TS_LESS",
            "value": 300,
            "type": "int"
          },
          {
            "key": "rta__sdv_top_asn_share",
            "operator": "TS_GREATER_EQ",
            "value": 0.8,
            "type": "float"
          },
          {
            "key": "rta__sdv_top_ip_share",
            "operator": "TS_GREATER_EQ",
            "value": 0.8,
            "type": "float"
          },
          {
            "key": "rta__sdv_single_country",
            "operator": "TS_EQ",
            "value": true,
            "type": "boolean"
          },
          {
            "key": "rta__sdv_subnet_distinct",
            "operator": "TS_LESS_EQ",
            "value": 3,
            "type": "int"
          }
        ]
      },
      {
        "operator": "AND",
        "conditions": [
          {
            "key": "rta__sdv_top_asn_share",
            "operator": "TS_GREATER_EQ",
            "value": 0.8,
            "type": "float"
          },
          {
            "operator": "OR",
            "conditions": [
              {
                "key": "rta__sdv_ip_distinct_saturated",
                "operator": "TS_EQ",
                "value": true,
                "type": "boolean"
              },
              {
                "key": "rta__sdv_ip_rotation_ratio",
                "operator": "TS_GREATER",
                "value": 0.5,
                "type": "float"
              }
            ]
          },
          {
            "key": "rta__sdv_single_country",
            "operator": "TS_EQ",
            "value": true,
            "type": "boolean"
          },
          {
            "key": "rta__sdv_hosting_share",
            "operator": "TS_GREATER",
            "value": 0,
            "type": "float"
          }
        ]
      }
    ]
  }
]
```

## `blizzard2-h-sdv-bzc-challenge`

**Internal description:** SDV gate (1d velocity ratio >= 1) + either (top ASN share >= 0.8 AND top IP share >= 0.8 AND single country AND subnet distinct <= 3) OR (IP rotation AND single country AND multi-ISP same country AND hosting share > 0). Backtest 20-31 Oct: 91% confirmed, 1.8-3.0% possible FP transparent; 83% mitigated 1-4 Nov. Challenge experiment.

**External description:** High-velocity sign-ups from one device on a concentrated network or rotating hosting IPs

**Telltale definition (paste into Dataswan):**

```json
[
  {
    "key": "public_key",
    "operator": "TS_EQ",
    "value": "E8A75615-1CBA-5DFF-8032-D16BCF234E10",
    "type": "string"
  },
  {
    "key": "location",
    "operator": "TS_EQ",
    "value": "session_setup",
    "type": "string"
  },
  {
    "key": "rta__sdv_velocity_ratio_1d",
    "operator": "EXISTS"
  },
  {
    "key": "rta__sdv_velocity_ratio_1d",
    "operator": "TS_GREATER_EQ",
    "value": 1.0,
    "type": "float"
  },
  {
    "operator": "OR",
    "conditions": [
      {
        "operator": "AND",
        "conditions": [
          {
            "key": "rta__sdv_top_asn_share",
            "operator": "TS_GREATER_EQ",
            "value": 0.8,
            "type": "float"
          },
          {
            "key": "rta__sdv_top_ip_share",
            "operator": "TS_GREATER_EQ",
            "value": 0.8,
            "type": "float"
          },
          {
            "key": "rta__sdv_single_country",
            "operator": "TS_EQ",
            "value": true,
            "type": "boolean"
          },
          {
            "key": "rta__sdv_subnet_distinct",
            "operator": "TS_LESS_EQ",
            "value": 3,
            "type": "int"
          }
        ]
      },
      {
        "operator": "AND",
        "conditions": [
          {
            "operator": "OR",
            "conditions": [
              {
                "key": "rta__sdv_ip_distinct_saturated",
                "operator": "TS_EQ",
                "value": true,
                "type": "boolean"
              },
              {
                "key": "rta__sdv_ip_rotation_ratio",
                "operator": "TS_GREATER",
                "value": 0.5,
                "type": "float"
              }
            ]
          },
          {
            "key": "rta__sdv_single_country",
            "operator": "TS_EQ",
            "value": true,
            "type": "boolean"
          },
          {
            "key": "rta__sdv_multi_isp_same_country",
            "operator": "TS_EQ",
            "value": true,
            "type": "boolean"
          },
          {
            "key": "rta__sdv_hosting_share",
            "operator": "TS_GREATER",
            "value": 0,
            "type": "float"
          }
        ]
      }
    ]
  }
]
```
