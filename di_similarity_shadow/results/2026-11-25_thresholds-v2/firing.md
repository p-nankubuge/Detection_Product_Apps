# Firing replay v2 (per-key fallback): new thresholds vs today's, Figma Registration K2

Replay day: sessions created **20 Nov 2026 00:00-24:00 UTC**, 88,608 sessions with a dict (no sampling), plus the 12:00-14:00 slice (9,156). Thresholds from `matrix.md` (v2). Queries: `04_replay_figma_20nov_v2.sql`, `05_replay_figma_20nov_1200_1400_v2.sql`, `14_changed_cells_headroom.sql`. Same method as v1 `firing.md`: both sides use DI's own recorded counts; today = `DI_SHORT_TERM_THRESHOLD_BREACHED_AT_SESSION_CREATED` (count > 11; checked on every session, 0 mismatches); new = ST count > new ST **or** LT count > new LT. "Clean" = session in a replay-day signature-window with < 20% High (81,054 sessions). Stats: **n / High% / verified% / challenged% / challenged-not-solved%**. No truth data used.

## Summary, full day

| | Fires | High % | Verified % | Challenged % | Chall. not solved % | On clean traffic |
|---|---|---|---|---|---|---|
| Today, ST breached (incl. exempt Dict 63) | 381 | 52.8 | 62.7 | 82.7 | 36.7 | 118 (0.15%) |
| Today, effective (Dict 63 exempt) | 179 | | | | | 84 |
| **New v2** (ST or LT) | **698** | 44.4 | 65.9 | 72.3 | 32.2 | **301 (0.37%)** |
| New v1 (for reference) | 696 | 44.5 | 65.8 | 72.4 | 32.3 | 300 |
| New-only v2 (not fired today) | 334 | 33.8 | 66.8 | 61.7 | 29.9 | |
| Today-only (not fired by v2) | 17 | 23.5 | 11.8 | 94.1 | 88.2 | (all List A, skipped) |

Key baseline 5.9% High, 91.1% verified. Today's ST ratio >= 2x: 101; >= 4x: 4. **LT: 0 fires today, 0 v1, 0 v2.**

**The only difference from v1 is +2 fires in Dict 1 Desktop.** No other v2-changed cell fires on either side.

## Per cell, full day (cells with any fire)

| Dict | Group | Sessions (High %) | v2 ST thr (source) | Today ST | New v2 | New only | Clean: today -> new |
|---|---|---|---|---|---|---|---|
| **1** | **Desktop** | 109 (4.6) | **7.49 (a)** | 0 | **2 / 0 / 100 / 50 / 0** | 2 / 0 | 0 -> 1 of 96 |
| 3 | Desktop | 3,227 (8.2) | 7 (key) | 40 / 37.5 / 50.0 / 80.0 / 50.0 | 62 / 30.6 / 56.5 / 67.7 / 43.5 | 22 / 18.2 | 30 -> 47 of 2,874 |
| 3 | Linux | 323 (6.5) | 6 (key) | 0 | 5 / 0 / 20 / 80 / 80 | 5 / 0 | 0 -> 5 of 294 |
| 3 | Mobile | 770 (5.3) | 9 (key) | 0 | 2 / 0 / 100 / 0 / 0 | 2 / 0 | 0 -> 2 of 701 |
| 3 | Win RD/VM | 194 (18.0) | 5 (key) | 1 / 0 / 100 / 0 / 0 | 9 / 11.1 / 33.3 / 88.9 / 66.7 | 8 / 12.5 | 1 -> 8 of 155 |
| 7 | Desktop | 9,086 (8.1) | 6 (key) | 45 / 28.9 / 80.0 / 33.3 / 20.0 | 103 / 25.2 / 71.8 / 35.9 / 27.2 | 58 / 22.4 | 26 -> 71 of 8,230 |
| 7 | Linux | 497 (2.6) | 6 (key) | 0 | 6 / 0 / 50 / 100 / 33.3 | 6 / 0 | 0 -> 6 of 481 |
| 7 | Mobile | 283 (10.6) | 3 (key) | 0 | 6 / 66.7 / 0 / 100 / 83.3 | 6 / 66.7 | 0 -> 2 of 252 |
| 15 | Desktop | 7,392 (8.8) | 6 (key) | 28 / 71.4 / 60.7 / 71.4 / 35.7 | 67 / 58.2 / 64.2 / 65.7 / 29.9 | 39 / 48.7 | 8 -> 22 of 6,676 |
| 15 | Win RD/VM | 313 (8.9) | 6 (key) | 4 / 0 / 25 / 100 / 75 | 5 / 0 / 20 / 100 / 80 | 1 / 0 | 4 -> 5 of 285 |
| 31 | Desktop | 12,889 (7.6) | 6 (key) | 44 / 65.9 / 36.4 / 93.2 / 63.6 | 89 / 55.1 / 53.9 / 83.1 / 44.9 | 45 / 44.4 | 15 -> 36 of 11,787 |
| 31 | Mobile | 817 (3.1) | 4 (key) | 0 | 2 / 0 / 0 / 100 / 100 | 2 / 0 | 0 -> 2 of 791 |
| 31 | Win RD/VM | 604 (13.6) | 4.5 (key) | 0 | 7 / 14.3 / 85.7 / 28.6 / 14.3 | 7 / 14.3 | 0 -> 6 of 519 |
| 63 | Desktop | 35,571 (4.4) | 8 (key) | 183 / 63.4 / 70.5 / 92.3 / 29.0 (exempt) | 299 / 55.9 / 70.2 / 81.9 / 28.1 | 116 / 44.0 | 20 -> 62 of 33,541 |
| 63 | Linux | 387 (3.6) | 6 (key) | 14 / 0 / 85.7 / 100 / 14.3 (exempt) | 25 / 0 / 92.0 / 100 / 8.0 | 11 / 0 | 14 -> 25 of 370 |
| 63 | Mobile | 10,787 (3.1) | 10 (key) | 5 / 80 / 100 / 80 / 0 (exempt) | 9 / 44.4 / 100 / 44.4 / 0 | 4 / 0 | 0 -> 1 of 10,352 |

Per dict (today ST -> v2; High % of v2 fires): Dict -1 0 -> 0; **Dict 1 0 -> 2 (0%)**; Dict 3 43 -> 78 (25.6%); Dict 7 45 -> 115 (26.1%); Dict 15 45 -> 72 (54.2%); Dict 31 46 -> 98 (51.0%); Dict 63 202 recorded / 0 effective -> 333 (51.4%).

The two Dict 1 Desktop fires: matched signature `Windows::10` (Dict 1 = OS only), ST count 8 vs 7.49, Low risk, verified; one not challenged, one challenged and solved (Edge 157 with a no-ALPN JA4 `t13d260900_…`, and a "Chromium GOST" 150 UA). Both are consistent with ordinary low-risk users being caught by a tight OS-only threshold.

Headroom in the other v2-changed cells on 20 Nov (`14_changed_cells_headroom.sql`): max ST count Dict -1 2 (thr 11); Dict 1 Mobile / Linux / Win RD/VM 4 (thr 7.49); Other cells 1 to 3 (thr 6 to 8). Max LT count 185 (Dict 1 Desktop, thr 449.4).

## Slice 12:00-14:00 UTC

Identical to v1: today 25 (20.0% High), new 70 (18.6% High, 72.9% verified, 74.3% challenged, 22.9% challenged-not-solved), new-only 45 (17.8%), clean 24 -> 61. No v2-changed cell fires in the slice (Dict -1: 1 session, Dict 1: 23, Other: none fire).

## Dict 63 Linux cell (25 fires, 0% High): examples

`06_dict63_linux_examples.sql`, `07_dict63_linux_ipintel_history.sql`. All 25 fires are **one matched signature** (`cd17e5f3fc`, MD5 prefix):

| Field | Value (identical on all 25) |
|---|---|
| OS / version | `GNU/Linux` / empty |
| UA | `Mozilla/5.0 (X11; Linux x86_64; rv:156.0) Gecko/20100101 Firefox/156.0` |
| JA4 | `t13d1517h2_8daaf6152771_3cbfd9057e0d` |
| Screen | `1920,1080::1920,1080` |
| device_params | `Linux x86_64::0::1::24::8::1::1::0::1::0::0::0::476A6` (8 cores, 24-bit colour, no touch) |
| WebGL renderer | `Intel(R) HD Graphics, or similar` |
| IP | 4 addresses in `185.197.91.0/24` (.129, .162, .176, .178) |
| ASN / ISP | 34285, `junta de andalucia` (organization `junta de andalucia` or `curves`), connection type `nat`, country ES, hosting 0, VPN 0 |
| `vpn_proxy_description` / `vpn_proxy_type` | empty on all |
| Risk / outcomes | 25 Medium, 0 High; 25 challenged, 23 verified, 2 challenged and not solved (8.0% in the replay) |
| Timing | two bursts: 09:42-10:06 (6 fires) and 13:10-13:32 (19 fires); ST count climbs 7 -> 24 within a burst; today's threshold (11) also breached by 14 of them |
| History | the signature appears at Dict 63 on this key **only on 20 Nov** (37 sessions, all from the same /24, hours 9, 10, 13 UTC); not in 13-19 Nov |

20 rows with time, ST / LT count and IP are in `06_dict63_linux_examples.sql`.

**What it looks like.** Consistent with a group of identically configured managed Linux PCs (same Firefox build, screen, hardware profile and font hash) behind one NAT egress of a regional public-sector network, registering Figma accounts in two short sessions, for example a classroom or training room. The Firefox renderer string "…, or similar" is Firefox's generic WebGL renderer value, so many such machines legitimately share one Dict 63 signature. It is also consistent with a small scripted run from that network; 23 of 25 solved a challenge and none were High risk, which leans towards the first reading. This is not shown as fact. With today's threshold (11), 14 of these breach too (exempt at Dict 63); with the new 6, all 25.
