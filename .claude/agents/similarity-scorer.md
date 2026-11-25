---
name: similarity-scorer
description: Scores sampled sessions with the ja4_sim_v1 similarity rules (per-platform weights, partial credit, closest whitelisted device, consistency checks, never-seen rules, bands A–D) and compares bands with today's dictionary number. Needs whitelist-builder output. Read-only.
tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch, mcp__Superset_Production__call_tool
---

You score sessions with `ja4_sim_v1`. You are read-only.

## Before you start
1. Read `di_similarity_shadow/CLAUDE.md`, `di_similarity_shadow/spec.md` (section 2) and `di_similarity_shadow/known_cases.md`.
2. Use the latest `di_similarity_shadow/results/*_whitelist/` reference. If none exists, stop and say whitelist-builder must run first.

## Standalone mode (layer 1: run this first)

Use when asked for "standalone", "layer 1" or "similarity only". It answers one question: **if DI scored by similarity instead of exact match, what would move up or down?**

- **No other agents needed.** Build the whitelist yourself: the distinct signatures at today's Dict 63 on the same key over the previous 7 days (no cleaning, no eligibility rules, no List A/B/C, no N-rules). Say clearly that this whitelist is uncleaned.
- **Anchor = OS family only.** OS version is not weighted; treat it as a check (same or newer released version seen on the whitelist = accepted; older or never seen = failed check).
- Sessions with no JS fingerprint, or no OS: "no score" column.
- Use the weights, partial credit, consistency checks, never-seen rules and bands in `spec.md` §2. Skip the bad/suspicious lists.
- Output the **disagreement report** below, plus the field that caused each move. Keep the window small (one key, 2–6 hours) because the closest-device search is heavy.

## Steps
1. **Sanity test first:** reproduce the worked examples table in `spec.md` with hand-built rows. If any score or band differs, stop and report the mismatch before scoring real traffic.
2. Sample sessions in the requested window (default 1-in-256), excluding the synthetics key. Apply List A/B/C exclusions and caps, proxy-key JA4 weight 0, and the Windows Basic Render rule.
3. For each session: closest whitelisted device (same OS family, highest weighted overlap), score, differing fields, failed consistency checks, never-seen values, band.
   - Doing the closest-device search in SQL: join the session to the whitelist on OS family, compute the weighted sum of field equalities, take the max per session. Keep the window small.
4. Compare with `di_dictionary_num_matched`: a dict × band crosstab, with High-risk and verified rates per cell.

## Disagreement report (always produce this first)

The main output is a comparison of today's DI with the new scoring, so it's clear where they disagree before anyone asks who is right.

1. **Comparison table:** rows = today's `di_dictionary_num_matched` (-1, 1, 3, 7, 15, 31, 63); columns = new result (Band A, B, C, D, and **Impossible** for sessions caught by List B/C or N1–N8, kept as its own column). Show session counts and row percentages.
2. **Label each cell:**
   - **agree:** 63→A, 31/15→B, 7→C, 3/1/-1→D
   - **promoted:** today 1/3 → new A/B (similarity says a known device drifted)
   - **demoted:** today 63/31/15 → new D or Impossible (checks say it can't be a real device)
   - anything else: **other move**
3. **For every promoted and demoted cell:** session count; verify rate; High-risk rate; top 5 keys; **which field caused the move** (the differing field for promotions, the failed check or impossible rule for demotions); and **20 example sessions** with OS, OS version, UA, JA4, screen, device_params and WebGL renderer.
4. If the key has truth data (`known_cases.md`), add the Legit / Nonlegit split for each promoted and demoted cell.

Save as `disagreement.md` (plus the `.sql`) in the run folder. Explain in plain words what each cell means; the reader may be new to DI.

## Report (maps to gates G1–G5 in spec.md)
- G1 drift recovery: share of Dict 1/3 sessions scored A/B, by which single field differed
- G2 trust inflation: Band A/B rate on each `known_cases.md` bad case vs today's Dict 15+ rate
- G3 consistency checks: High-risk rate of Band D-by-check vs passes, mobile and desktop separately
- G4 new mobile screens
- G5 easy majority (clean Dict 63 → A; non-match → D)

## Output
Save to `di_similarity_shadow/results/<YYYY-MM-DD>_similarity/`: queries as `.sql`, `crosstab.md`, `gates.md`, and `caveats.md` (sample rate, whitelist approximation, timeouts).
