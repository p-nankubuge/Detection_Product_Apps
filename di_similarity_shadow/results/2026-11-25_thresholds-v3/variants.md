# V0-V3 comparison (D-13 sensitivity, Figma Registration K2 + known cases)

Everything identical to thresholds v2 except the base per cell. Details: `matrix.md`, `firing.md`, `caveats.md`. Replay day 20 Nov 2026 (88,608 sessions, 81,054 on clean signature-windows).

| | Today | V0 p99 (= v2) | V1 max(p99, 5) | V2 p99.9 | V3 max(p99.9, 5) |
|---|---|---|---|---|---|
| Fires on clean traffic, 20 Nov (n, %) | 118 (0.15%) recorded; 84 (0.10%) effective | 301 (0.37%) | 203 (0.25%) | **83 (0.10%)** | **83 (0.10%)** |
| Total fires, 20 Nov | 381 recorded; 179 effective | 698 | 500 | 218 | 218 |
| High % of fires | 52.8 | 44.4 | 47.6 | 46.8 | 46.8 |
| Verified % / challenged-not-solved % of fires | 62.7 / 36.7 | 65.9 / 32.2 | 65.0 / 34.0 | 63.8 / 35.8 | 63.8 / 35.8 |
| New-only fires (High %) | | 334 (33.8) | 136 (30.1) | 5 (0.0) | 5 (0.0) |
| Slice 12:00-14:00 fires (High %) / clean | 25 (20.0) / 24 | 70 (18.6) / 61 | 43 (16.3) / 40 | 13 (7.7) / 13 | 13 (7.7) / 13 |
| **G7 failing cells** (vs recorded per-dict rate; + vs Dict 63 effective) | | 14 (+1 = 15) | 11 (+1 = 12) | **4** (+0) | **4** (+0) |
| Dict 63 fires (High %), baseline 4.2% | 202 recorded, 0 effective | 333 (51.4) | 244 (57.8) | 91 (52.7) | 91 (52.7) |
| **Dict 63 Linux group fires** (all 0% High) | 14 (exempt) | 25 | 17 | 11 | 11 |
| **K3 share firing** (Adobe ARP K8, 2,084 attack sessions) | 1,597 (76.6%) | 1,900 (91.2%) | 1,900 (91.2%) | 1,767 (84.8%) | 1,767 (84.8%) |
| **G8** Payoneer L1 fires vs today (110,947) | | 113,595 (+2.4%) FAIL | 113,595 (+2.4%) FAIL | 111,639 (+0.6%) FAIL | 111,639 (+0.6%) FAIL |

G7 failing cells under V2/V3: Dict 3 Desktop, Dict 3 Win RD/VM, Dict 15 Win RD/VM, Dict 63 Linux. Dict 3 Desktop (27 clean fires vs today's 30 in the same cell) and Dict 15 Win RD/VM (4 vs 4) are at or below today's same-cell level; they fail only against the per-dict average.

**Why V2 = V3 and V1 ~ V0 on these keys:** the floor of 5 only binds where the base is below 5. Figma's p99 is 2-5 in most cells (so V1 moves Dict 7 / 15 / 31 / 63), but its p99.9 is 4.17 only in Dict 31 Mobile (no fires either way). On Adobe and the Payoneer Dict 1 cells every relevant base is already >= 5.

## Recommendation (opinion, not a decision)

**V3 (p99.9 with a floor of 5)**, with two follow-ups before deciding D-13.

Reasoning:
- V2/V3 is the only variant that brings Figma's clean-traffic firing down to today's level (83 vs 84 effective / 118 recorded), and cuts G7 failures from 14-15 cells to 4. V1 helps (203 clean, 11 cells) but still fires 1.7x today on clean traffic.
- High risk among fires stays at 46.8%, about 8x the 5.9% key baseline (between V0 44.4% and V1 47.6%; today 52.8%). Dict 63 fires stay concentrated on High (52.7% vs 4.2% baseline).
- K3 still fires (84.8%, above today's 76.6%).
- V3 rather than V2: they are identical on every key tested. The floor only adds protection for keys or cells where p99.9 is itself tiny (very low-volume signatures), where V2 alone could produce ST 2-8 thresholds. It costs nothing on the data seen.

Trade-offs and what V3 does not fix:
- **Little new detection on Figma.** Only 5 new-only fires (0% High). What V3 adds over today's effective behaviour is enforcing on Dict 63 (91 fires, 52.7% High, today exempt). It also **loses 40 fires** that today's flat 11 catches (Dict 15 Desktop 19, Dict 31 Desktop 9, Dict 3 / 7 Desktop 6 each) where the key cell is now 12-16. Their risk mix was not broken out.
- **K3 loses Dict 63 Desktop** (132 -> 0): Adobe's Dict 63 Desktop p99.9 is 52, so ST 104, which is above today's 90 (allowed for real key cells under D-11). If key cells were also capped at the current threshold, that cell would be 90 and still not catch ST counts of 23-44.
- **G7 still fails in 4 cells.** Dict 63 Linux (one managed-fleet-like signature, ST up to 24) is not solved by any base level tested. It needs the untested options in D-13 (IP-diversity / fleet exception, or larger minimum volume). Dict 3 Win RD/VM (155 clean sessions) is a small cell.
- **G8 is unchanged in substance** (+0.6%); threshold level cannot fix L1.
- p99.9 rests on the top 0.1% of clean signature-windows: 2-300 windows per Figma cell, and far fewer in Adobe's sampled base (14 of 252 buckets). It will be noisier day to day than p99.
