# Matrix: per-signature threshold (D-19) as tested, 26 Nov

There is no per-cell threshold table in this design: the limit is computed **per session** from its matched signature. What is fixed per key and dictionary is:

| Dict | Dictionary factor d | Effective multiplier m x d for m = 2 / 5 / 10 / 20 |
|---|---|---|
| 1, 3 | 1 | 2 / 5 / 10 / 20 |
| 7 | 1.5 | 3 / 7.5 / 15 / 30 |
| 15, 31, 63 | 2 | 4 / 10 / 20 / 40 |

limit = max(floor, share x volume x m x d), floor 5 or 11; fire if DI's short-term count > limit. Same for every platform group (no Windows RD/VM cap was applied; the cap in spec §4 rule 3 belongs to the per-cell design).

| Key | Today's threshold (ST / LT) | Dictionary used (`di_dictionary_used`) | Base (share) window |
|---|---|---|---|
| Figma Registration K2 `A207F8A1-…` | 11 / 660 (flat, every dict) | `23454` (account) | 13-19 Nov (non-High sessions) |
| Blizzard ROW Registration K2 `E8A75615-…` | 25 / 1,500 (flat; unchanged 2-11 Nov) | `21280` (account) | 7 days before each replay day (2-8, 3-9, 4-10 Nov) |

Not produced (as v1-v3): global all-keys cells and a top-20-keys matrix. Global cells are not meaningful for a per-signature rule; per-key results exist only for the two keys tested.
