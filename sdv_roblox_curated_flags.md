# SDV curated suspicion flags — Roblox Signup Key 2 (A2A14B1D)

All five definitions passed Dataswan `validate_telltale` on 2 Nov 2026 (no errors). Nothing has been created.

## Common settings (all five)

| Field | Value |
|---|---|
| Telltale type | suspicion_flags |
| Location | SESSION_SETUP |
| Owner category / owner | User / p.nankubuge@arkoselabs.com |
| Ticket | DETCORE-4371 |
| Cohort category | Suspicious |
| Risk category / score | CUSTOM / 0 |
| Active on creation | false (turn on after review) |
| Life-cycle management | A (auto) |
| Degrade action | 1 = send_to_ensemble (same as the existing dev2-5 monitor flag) |
| Allow pressure | allow |

## Backtest (20–27 Oct; 23–27 Oct excludes the 24 Oct Samsung windows)

Baseline under the gate, 23–27 Oct: 69.4% confirmed, 28.4% possible FP: transparent.

| Flag | Flagged 23–27 Oct | Confirmed 23–27 Oct | Possible FP: transparent 23–27 Oct | Share of truth data 23–27 Oct | Confirmed 20–22 Oct | Proposed use |
|---|---|---|---|---|---|---|
| `robloxa2a1-h-sdv-g1-core` | 1,498,350 | 76.8% | 14.3% | 19.7% | 91.7% | Monitor / challenge experiment |
| `robloxa2a1-h-sdv-g2-pairs` | 952,162 | 81.3% | 10.2% | 11.5% | 89.2% | Challenge experiment |
| `robloxa2a1-h-sdv-g3-triples` | 187,694 | 97.4% | 1.5% | 0.6% | 93.3% | Challenge |
| `robloxa2a1-h-sdv-g4-quads` | 109,168 | 98.3% | 0.8% | 0.2% | 93.7% | Challenge |
| `robloxa2a1-h-sdv-g5-gap-hosting` | 182,915 | 97.5% | 1.5% | 0.4% | 88.8% | Challenge |

Flags overlap: a session matching a stronger group also matches the wider flags. Act on the strongest flag that fires.

## `robloxa2a1-h-sdv-g1-core`

**Internal description:** SDV gate (1d velocity ratio >= 1) + at least one core signal: IP rotation (IP distinct saturated or rotation ratio > 0.5) OR any hosting share OR mean gap < 300 s. Widest SDV flag; monitor or experiment only.

**External description:** High-velocity sign-ups from one device with rotating IPs, hosting networks or rapid repeat attempts

**Proposed use:** Monitor / challenge experiment

**Telltale definition (paste into Dataswan):**

```json
[
  {
    "key": "public_key",
    "operator": "TS_EQ",
    "value": "A2A14B1D-1AF3-C791-9BBC-EE33CC7A0A6F",
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
      },
      {
        "key": "rta__sdv_hosting_share",
        "operator": "TS_GREATER",
        "value": 0,
        "type": "float"
      },
      {
        "key": "rta__sdv_mean_gap_s",
        "operator": "TS_LESS",
        "value": 300,
        "type": "int"
      }
    ]
  }
]
```

## `robloxa2a1-h-sdv-g2-pairs`

**Internal description:** SDV gate + any curated pair: IP rotation + hosting | mean gap + IP rotation | mean gap + hosting | top ASN share >= 0.8 + hosting. Excludes weak pairs (single country + multi-ISP, top ASN + IP rotation).

**External description:** High-velocity sign-ups from one device combining IP rotation, hosting networks or rapid repeat attempts

**Proposed use:** Challenge experiment

**Telltale definition (paste into Dataswan):**

```json
[
  {
    "key": "public_key",
    "operator": "TS_EQ",
    "value": "A2A14B1D-1AF3-C791-9BBC-EE33CC7A0A6F",
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
            "key": "rta__sdv_hosting_share",
            "operator": "TS_GREATER",
            "value": 0,
            "type": "float"
          }
        ]
      },
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
          }
        ]
      },
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
            "key": "rta__sdv_hosting_share",
            "operator": "TS_GREATER",
            "value": 0,
            "type": "float"
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

## `robloxa2a1-h-sdv-g3-triples`

**Internal description:** SDV gate + any curated triple: mean gap + IP rotation + hosting | IP rotation + hosting + device saturated | mean gap + single country + multi-ISP same country | mean gap + top ASN + hosting.

**External description:** High-velocity sign-ups from one device with three corroborating network and timing signals

**Proposed use:** Challenge

**Telltale definition (paste into Dataswan):**

```json
[
  {
    "key": "public_key",
    "operator": "TS_EQ",
    "value": "A2A14B1D-1AF3-C791-9BBC-EE33CC7A0A6F",
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
            "key": "rta__sdv_hosting_share",
            "operator": "TS_GREATER",
            "value": 0,
            "type": "float"
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
            "key": "rta__sdv_hosting_share",
            "operator": "TS_GREATER",
            "value": 0,
            "type": "float"
          },
          {
            "key": "rta__sdv_device_distinct_saturated",
            "operator": "TS_EQ",
            "value": true,
            "type": "boolean"
          }
        ]
      },
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
          }
        ]
      },
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

## `robloxa2a1-h-sdv-g4-quads`

**Internal description:** SDV gate + any curated 4-signal group: mean gap + single country + multi-ISP + hosting | mean gap + IP rotation + single country + multi-ISP | single country + subnet <= 3 + multi-ISP + hosting | mean gap + top ASN + IP rotation + hosting | top ASN + IP rotation + hosting + device saturated.

**External description:** High-velocity sign-ups from one device with four corroborating network and timing signals

**Proposed use:** Challenge

**Telltale definition (paste into Dataswan):**

```json
[
  {
    "key": "public_key",
    "operator": "TS_EQ",
    "value": "A2A14B1D-1AF3-C791-9BBC-EE33CC7A0A6F",
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
      },
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
          }
        ]
      },
      {
        "operator": "AND",
        "conditions": [
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
      },
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
            "key": "rta__sdv_hosting_share",
            "operator": "TS_GREATER",
            "value": 0,
            "type": "float"
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
            "key": "rta__sdv_hosting_share",
            "operator": "TS_GREATER",
            "value": 0,
            "type": "float"
          },
          {
            "key": "rta__sdv_device_distinct_saturated",
            "operator": "TS_EQ",
            "value": true,
            "type": "boolean"
          }
        ]
      }
    ]
  }
]
```

## `robloxa2a1-h-sdv-g5-gap-hosting`

**Internal description:** SDV gate + mean gap < 300 s + hosting share > 0 + one of: single country | top ASN >= 0.8 | IP rotation | subnet distinct <= 3.

**External description:** Rapid repeat sign-ups from one device on hosting networks with corroborating network signals

**Proposed use:** Challenge

**Telltale definition (paste into Dataswan):**

```json
[
  {
    "key": "public_key",
    "operator": "TS_EQ",
    "value": "A2A14B1D-1AF3-C791-9BBC-EE33CC7A0A6F",
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
            "key": "rta__sdv_hosting_share",
            "operator": "TS_GREATER",
            "value": 0,
            "type": "float"
          },
          {
            "key": "rta__sdv_single_country",
            "operator": "TS_EQ",
            "value": true,
            "type": "boolean"
          }
        ]
      },
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
            "key": "rta__sdv_hosting_share",
            "operator": "TS_GREATER",
            "value": 0,
            "type": "float"
          },
          {
            "key": "rta__sdv_top_asn_share",
            "operator": "TS_GREATER_EQ",
            "value": 0.8,
            "type": "float"
          }
        ]
      },
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
            "key": "rta__sdv_hosting_share",
            "operator": "TS_GREATER",
            "value": 0,
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
          }
        ]
      },
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
            "key": "rta__sdv_hosting_share",
            "operator": "TS_GREATER",
            "value": 0,
            "type": "float"
          },
          {
            "key": "rta__sdv_subnet_distinct",
            "operator": "TS_LESS_EQ",
            "value": 3,
            "type": "int"
          }
        ]
      }
    ]
  }
]
```
