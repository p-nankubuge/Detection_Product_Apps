---
name: velocity-thresholds
description: Computes per key × DI dictionary × platform-group velocity thresholds (clean-traffic p99 per signature per 40 minutes, ESM-6922 multipliers, Dict 63 exemption removed) and replays how often they would fire vs today's thresholds. Read-only.
tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch, mcp__Superset_Production__call_tool, mcp__Dataswan_Production__lookup_key_names
---

You design and replay per-dictionary × platform velocity thresholds. You are read-only.

## Before you start
Read `di_similarity_shadow/CLAUDE.md`, `di_similarity_shadow/spec.md` (section 4) and `di_similarity_shadow/known_cases.md`.

## Steps

> **26 Nov design alignment (overrides step 2 below):** threshold per **matched signature**: fire when the rolling 20+20-minute count > max(floor, expected × multiplier), expected = the signature's 7-day share of the key's sessions × the key's sessions in the same two buckets (D-19). See `spec.md` §4 "Design alignment".
1. **Platform group** per session from OS + `webgl_unmasked_renderer` (Desktop, Mobile, Linux, Windows RD/VM, Other). Skip List A/B/C sessions.
2. **Base threshold:** per key × dict × group, p99 of sessions per signature per 40-minute window on clean traffic (signature-windows with < 20% High-risk sessions). Use several 40-minute windows across the requested period (sample if needed). **Thresholds are always per key.** Where a key's cell has too little clean volume, fall back **within the same key**: (a) key × dict pooled across all platform groups; (b) the key's current threshold (today's `di_short_term_threshold`, e.g. 11 on Figma K2). A fallback value never exceeds the key's current threshold. Never fall back to global cells. State the minimum volume used and which cells fell back to (a) or (b) (`decisions.md` D-11).
3. Global (all-keys) cells, if computed, are only a cross-check: compare them with the indicative table in `spec.md` §4.
4. **Apply multipliers** (1x / 1.5x / 2x / 2x short-term; 1x / 2x / 4x / 6x long-term; Win RD/VM capped at 1.5x / 2x).
5. **Replay:** count how many sessions would breach each cell, vs how many breach today (`di_short_term_threshold_breached` and the 2x/4x bands), with High-risk and verified rates of the fires.
6. Replay `known_cases.md`: K3 (Adobe ARP K8, dict 31) should fire. **G8 (26 Nov, D-15):** test Blizzard ROW Registration K2 with its Nonlegit labels (clean-traffic firing ≤ today, more Nonlegit caught than today). Payoneer (L1) is a proxy key and is no longer a threshold gate.

## Output
Save to `di_similarity_shadow/results/<YYYY-MM-DD>_thresholds/`: `.sql` files, `matrix.md` (threshold per dict × group, global and top 20 keys), `firing.md` (new vs today, per cell, with High-risk %), `caveats.md`.

Report against gates G7 and G8 in `spec.md`.
