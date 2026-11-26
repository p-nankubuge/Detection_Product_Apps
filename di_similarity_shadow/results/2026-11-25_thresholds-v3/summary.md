# Summary: thresholds v3 (D-13 sensitivity of the base level), Figma Registration K2

**Question (D-13):** per-key thresholds v2 over-fire on clean traffic (G7). Does changing only the base level fix it? Variants: V0 p99 (= v2), V1 max(p99, 5), V2 p99.9, V3 max(p99.9, 5). Everything else is identical to v2. Files: `matrix.md`, `firing.md`, `variants.md`, `caveats.md`, SQL `01_`-`09_`, builder `02_build_matrices_v3.py`, G7 script `07_g7_per_cell.py`, outputs in `raw/` and `base_histograms/`.

## Results (20 Nov replay; known cases on their own windows)

| | Today | V0 | V1 | V2 | V3 |
|---|---|---|---|---|---|
| Clean-traffic fires | 118 rec. / 84 eff. | 301 | 203 | 83 | 83 |
| Total fires (High %) | 381 (52.8) | 698 (44.4) | 500 (47.6) | 218 (46.8) | 218 (46.8) |
| G7 failing cells | | 14 (15) | 11 (12) | 4 | 4 |
| Dict 63 Linux group fires | 14 (exempt) | 25 | 17 | 11 | 11 |
| K3 share firing | 76.6% | 91.2% | 91.2% | 84.8% | 84.8% |
| G8 vs today | | +2.4% | +2.4% | +0.6% | +0.6% |

- V0 reproduces v2 exactly (matrix, 698 / 301 fires, K3 1,900, L1 113,595).
- **V2 and V3 are identical** on Figma, Adobe and Payoneer. **V1 equals V0** on Adobe and Payoneer, but not on Figma.

## Gates
- **G7: FAIL in every variant**, but V2/V3 reduce it to 4 cells: Dict 3 Desktop, Dict 3 Win RD/VM, Dict 15 Win RD/VM, Dict 63 Linux.
  - Two of these (3 Desktop, 15 Win RD/VM) are at or below today's own clean firing in the same cell.
  - Aggregate clean firing under V2/V3 (83) is at today's effective level (84) and below today's recorded level (118).
  - The Dict 63 part of G7 (fires concentrate on High) passes in aggregate in every variant (V2/V3: 91 fires, 52.7% High vs 4.2% baseline). It fails in the Linux cell (0% High).
- **G8: FAIL marginally in every variant** (V2/V3 +0.6%). Threshold level cannot fix L1.
- **K3 fires** in every variant (V2/V3 84.8%; they lose the Dict 63 Desktop part, 132 sessions).

## Recommendation (opinion, not a decision)
**V3, p99.9 with a floor of 5 before multipliers.**
- It is the only tested level that brings Figma's clean-traffic firing to today's level while K3 still fires above today and High risk among fires stays around 47% (8x baseline).
- The floor changes nothing on the data seen, but guards low-volume cells where p99.9 itself could be 1-4.

Trade-offs:
- Almost no new detection on Figma: 5 new-only fires, 0% High. The gain over today is enforcement on Dict 63, where today's exemption hides 91 fires that are 52.7% High.
- V3 loses 40 fires that today's flat 11 catches (key cells now 12-16). Their risk was not profiled.
- It loses Adobe's Dict 63 Desktop attack fires.
- p99.9 is noisier.
- It does not solve the Dict 63 Linux fleet case or G8.

Before deciding D-13 (suggested):
1. Profile the 40 today-only sessions (High %, verified).
2. Test a fleet / IP-diversity exception for Dict 63 Linux.
3. Re-check V3 on a second key with truth data (Blizzard ROW K2), ideally with a full (non-sampled) Adobe base.

## Proposed spec rows (§4 Rule, for whoever owns `spec.md`; not applied)

| Item | Proposed wording |
|---|---|
| Rule 1, base | Base per key x dict x group = **p99.9** of sessions per signature per 40 min on clean traffic, **floored at 5** (before multipliers); rolling 7 days, recomputed daily. Pooled fallback cells use their own pooled p99.9, floored the same way; fallback values capped at the key's current threshold. |
| Rule 1, note | Real key cells may exceed today's threshold (e.g. Figma Dict 63 Desktop ST 18 vs 11; Adobe Dict 63 Desktop 104 vs 90). |
| Gate G7, note | Under p99.9 + floor 5, Figma clean-traffic fires 83 vs today 84 effective; 4 cells still above the per-dict rate (3 Desktop, 3 Win RD/VM, 15 Win RD/VM, 63 Linux). Open: fleet / IP-diversity exception for identical managed devices. |

## Failures and limits
- The full 7-day percentile queries timed out (Figma twice, Payoneer twice).
  - Figma was redone exactly via day-chunk histograms.
  - Payoneer was recomputed only for the EE844FC3 Dict 1 cells. These carry all but 3 of the L1 fires, and the bound is stated.
- The Adobe base is sampled by window (as v2).
- The run was interrupted once by an API spend limit; nothing was re-run.
- See `caveats.md`.
