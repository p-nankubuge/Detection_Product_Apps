# Layer 1 (similarity scoring, standalone): summary

- **Scope:** Figma Registration K2, sessions created 2026-11-20 12:00-14:00 UTC, all 9,156 sessions, no sampling. Uncleaned whitelist: 65,959 Dict 63 signatures from this key, 13-20 Nov.
- **Sanity test:** all 14 `spec.md` worked examples reproduce.
- **Result:** Band A 68.7%, B 17.3%, C 2.3%, D 11.8%. Dict 63 → A 94.7%. 298 Dict 1/3 sessions promoted to A/B (63.5% of Dict 1/3), mostly single-field drift. 361 Dict 15/31/63 sessions demoted to D, all via consistency checks.
- **Main findings:** (1) Similarity on an uncleaned whitelist promotes JA4 anomalies (N9/N10/N11-pattern JA4s reach Band A when everything else matches), so it needs layer 3. (2) The exact-value consistency checks are weak on desktop (High risk 6.3% when failing vs 4.7% passing). The one strong subgroup is UA×device_params + screen×device_params on Dict 15 (31% High).
- **Truth data was dropped at the user's request for this run;** no TD queries or files were made.
- Details: `disagreement.md`, `crosstab.md`, `gates.md`, `caveats.md`.
