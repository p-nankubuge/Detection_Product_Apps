# Figma Registration K2: Dict 1 and Dict 3 by OS and JA4

- **Key:** `A207F8A1-ED09-4325-ACE6-C8E26A458FBA` (Figma Registration K2)
- **Window:** 2026-11-20 12:00–14:00 UTC (game_verify joined to 15:00)
- **Source:** `ARK_PROD.events.vw_events`, Superset `database_id` 14
- **Sampling:** none (Dict 1 = 23 sessions, Dict 3 = 446, Dict 63 = 5,023)
- **Queries:** `figma_k2_d1_d3_breakdown.sql`
- **Baseline:** Dict 63 (sessions that fully match a known real device)

## By OS

| OS | Dict 1 | Dict 1 % | Dict 3 | Dict 3 % | Dict 63 | Dict 63 % | All dicts |
|---|---:|---:|---:|---:|---:|---:|---:|
| Windows | 9 | 39.1 | 163 | 36.5 | 2,745 | 54.6 | 5,683 |
| OS X | 5 | 21.7 | 185 | 41.5 | 1,014 | 20.2 | 1,627 |
| Android | 1 | 4.3 | 65 | 14.6 | 614 | 12.2 | 899 |
| iOS | 0 | 0.0 | 2 | 0.4 | 444 | 8.8 | 502 |
| GNU/Linux | 6 | 26.1 | 20 | 4.5 | 73 | 1.5 | 215 |
| Chrome OS | 2 | 8.7 | 1 | 0.2 | 79 | 1.6 | 133 |
| iPadOS | 0 | 0.0 | 4 | 0.9 | 48 | 1.0 | 66 |
| Ubuntu | 0 | 0.0 | 3 | 0.7 | 5 | 0.1 | 26 |
| HarmonyOS | 0 | 0.0 | 1 | 0.2 | 1 | 0.0 | 3 |
| OpenHarmony | 0 | 0.0 | 2 | 0.4 | 0 | 0.0 | 2 |

Column totals check: Dict 1 = 23, Dict 3 = 446 (match the dictionary split).

## Top 5 JA4s

| Dict | # | JA4 | Sessions | % of dict | Top OS | # OSes | Reached verify | Same JA4 at Dict 63 |
|---:|---:|---|---:|---:|---|---:|---:|---:|
| 1 | 1 | `t13d3213h1_3af914e56c9f_cf4b9e61af1f` | 5 | 21.7 | Windows | 1 | 80% | 0 |
| 1 | 2 | `t12d2605h2_c69ecbaecc6c_46dc1bab6854` | 2 | 8.7 | OS X | 1 | 100% | 0 |
| 1 | 3 | `t12d520500_26e41e4f9c7e_22a92d800fe4` | 2 | 8.7 | Windows | 1 | 100% | 0 |
| 1 | 4 | `q13d0311h3_55b375c5d22e_04d7070e337d` | 1 | 4.3 | GNU/Linux | 1 | 100% | 0 |
| 1 | 5 | `q13d0316h3_55b375c5d22e_23f574fd77bc` | 1 | 4.3 | GNU/Linux | 1 | 100% | 0 |
| 3 | 1 | `q13d0312h3_55b375c5d22e_178839b6cec1` | 48 | 10.8 | Windows | 5 | 94% | 2,742 |
| 3 | 2 | `q13d0311h3_55b375c5d22e_f2a83c8e78ae` | 39 | 8.7 | OS X | 3 | 100% | 565 |
| 3 | 3 | `q13d0311h3_55b375c5d22e_653d80c3fe9d` | 31 | 7.0 | Windows | 5 | 84% | 741 |
| 3 | 4 | `t13d1517h2_8daaf6152771_234dc10236f4` | 14 | 3.1 | OS X | 4 | 71% | 13 |
| 3 | 5 | `t13d2013h2_a09f3c656075_7f0f34a4126d` | 14 | 3.1 | OS X | 1 | 100% | 266 |

## What stands out

1. **Dict 1 and Dict 3 are different kinds of traffic.** Every top Dict 1 JA4 has 0 sessions at Dict 63, and several look non-browser (`h1` ALPN, TLS 1.2, no ALPN). Dict 3's top JA4s are ordinary Chrome / Safari shared by hundreds to thousands of Dict 63 sessions, so for Dict 3 the mismatch is in another signature field, not JA4.
2. **macOS is over-represented at Dict 3** (41.5% vs 20.2% at Dict 63, 185 sessions), and its top JA4s cover only ~67 of them. Suggests a Mac-wide field (OS/browser version, screen, WebGL) the whitelist hasn't learned. This is the case similarity scoring is meant to help.
3. **GNU/Linux is over-represented** at Dict 1 (26% vs 1.5%) and Dict 3 (4.5%); small counts.
4. **iOS almost never lands at Dict 1/3** (0.4% vs 8.8%), consistent with uniform iPhone hardware and software matching easily.
5. **`t13d1517h2_8daaf6152771_234dc10236f4`** at Dict 3: Chrome cipher list with one extra extension, rare at Dict 63 (13), spread over 4 OSes, lowest reach-verify rate (71%). Candidate for a closer look.

## Not done

- JA4 readings (browser vs scripted client) are inferred from the JA4 format, not confirmed against UA, WebGL or truth data.
- Did not check which non-JA4 field drops the macOS Dict 3 sessions.
- No truth-data join; one 2-hour window only.
