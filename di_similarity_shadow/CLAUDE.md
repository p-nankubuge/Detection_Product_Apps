# DI similarity shadow evaluator: read this first

## What this project is

A **shadow, read-only** evaluation of three Device Intelligence (DI) proposals, run on Snowflake data through the Superset connector. Nothing here changes production DI, Dataswan or any telltale.

1. **Similarity scoring (`ja4_sim_v1`):** score each session against whitelisted devices instead of the exact-match chain. Source: [One-Pager: Similarity Scoring on the JA4 DI Champion](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4778524947).
2. **Impossible combinations:** Lists A/B/C from the companion page, plus new checks (UA × OS / OS version, screen × OS family, platform × OS, browser version × OS version).
3. **Per-dictionary × platform velocity thresholds**, including Dict 63. Source: [One-Pager: Per-Dictionary × Platform Velocity Thresholds and Virtual GPU Eligibility](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/4780228745).

The exact rules are in `spec.md`. The ground-truth cases are in `known_cases.md`. **Work from those files, not from memory of the Confluence pages.**

## Agents

Defined in `.claude/agents/` at the repo root:

| Agent | Job |
|---|---|
| `whitelist-builder` | Builds the "real device" reference and pair indexes |
| `similarity-scorer` | Scores sessions with the `ja4_sim_v1` rules |
| `impossible-combos` | Tests List A/B/C and new impossible-combination rules |
| `velocity-thresholds` | Per key × dictionary × platform p99 thresholds and firing replay |
| `gate-reviewer` | Checks the others' results against `known_cases.md` and the gates |

Typical order: `whitelist-builder` first; then `similarity-scorer`, `impossible-combos` and `velocity-thresholds` (can run in parallel); then `gate-reviewer`.

## Hard rules

- **Read only.** Never create, update or delete anything in Dataswan, Jira, Confluence or Slack. `validate_telltale` (read-only) is allowed if a rule is being proposed.
- **Save everything.** Every query and result goes under `di_similarity_shadow/results/<YYYY-MM-DD>_<short-name>/` as `.sql` and `.md` (or `.csv`) files, so runs can be repeated and compared.
- **Say what you didn't do.** If a query timed out, was sampled, or used an approximation, write that in the result file.
- **No model identifiers** in files or commit messages.

## Data access

- **Tool:** `mcp__Superset_Production__call_tool` with `name: "execute_sql"` and `arguments: {"request": {"database_id": 14, "sql": "...", "limit": N}}`. If the tool isn't loaded, load it with ToolSearch (`select:mcp__Superset_Production__call_tool`).
- **Near real-time events:** `ARK_PROD.events.vw_events`, one row per event. Use `location = 'session_setup'` for DI fields, `location = 'game_verify'` for outcomes.
- **Session summary:** `ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY` lags ~30 min (10-min batches). Columns end in `_at_session_created` (e.g. `di_dictionary_num_matched_at_session_created`). Time column `session_last_timestamp`. Verified = `sessions_verified > 0`.
- **Discover columns before guessing:** `SELECT column_name, data_type FROM ARK_PROD.INFORMATION_SCHEMA.COLUMNS WHERE table_schema='EVENTS' AND table_name='VW_EVENTS' AND column_name ILIKE '%SCREEN%'`. Field names for screen size, device_params, OS version and navigator platform are **not yet confirmed**; look them up and record them in `spec.md` under "Confirmed field names".

### Known `vw_events` columns

| Column | Notes |
|---|---|
| `timestamp`, `location`, `session`, `public_key`, `user_ip`, `ua` | |
| `cdn__ja4_hash` | Full JA4, e.g. `t13d1516h2_8daaf6152771_e5627efa2ab1`. Part a = `t13d1516h2` (TLS 1.3, SNI d, 15 ciphers, 16 extensions, ALPN h2); b = cipher hash; c = extension hash. `q13…` = QUIC |
| `di_dictionary_num_matched` | Champion dict: -1, 1, 3, 7, 15, 31, 63 |
| `di__challenger_dictionary_num_matched` | Challenger. **Broken, do not use** |
| `di_short_term_threshold_ratio` / `_breached`, `di_long_term_threshold_ratio` / `_breached`, `di_success`, `di_called`, `di_is_suspicious` | Velocity ratio = count / threshold |
| `webgl_unmasked_renderer`, `os`, `browser_name` | For List A/B |
| `vpn_proxy_type`, `vpn_proxy_description`, `asn`, `ip_intel__is_proxy_harvested` | IP intelligence |
| `fp_timezone_offset`, `mobile_sdk__timezone_offset` | Both NULL = no browser/SDK fingerprint |
| `rta__ip_connection_type_velocity_short_term_ratio`, `rta_ip_velocity_short_term_ratio`, `rta_ip_velocity_long_term_ratio` | IP velocity |
| `telltale_list` | Cast with `CAST(telltale_list AS ARRAY)` |
| `verified`, `solved` | On `game_verify` rows; cast with `::BOOLEAN` |
| `email__experimental_attributes` | JSON text; `TRY_PARSE_JSON(...):ml_score` |
| `latest_risk_band` | Used by the one-pagers as the High-risk label (check it exists) |

## Snowflake gotchas (all hit in practice)

- Numeric booleans need `::BOOLEAN` inside `IFF` / `COUNT_IF` (e.g. `COUNT_IF(verified::BOOLEAN)`), otherwise "Invalid argument types for function IFF".
- Use `TIME_SLICE(timestamp, 10, 'MINUTE')` for buckets; interval arithmetic errors out.
- `ARRAY_CONTAINS('name'::VARIANT, CAST(telltale_list AS ARRAY))` to test a telltale fired.
- Aliases that clash with column names in `GROUP BY` break; wrap in a CTE.
- **Timeouts:** queries over ~1 day of `vw_events` across all keys usually time out. Keep windows to 2–6 hours, filter by key, or sample (e.g. `MOD(ABS(HASH(session)), 256) = 0`). Join `game_verify` for outcomes in a separate CTE limited to the same window plus an hour.
- `ROUND()` columns come back typed UNKNOWN in Superset datasets; `CAST(... AS FLOAT)` if building charts.

## Keys and traffic to treat specially

- **Exclude** `2EAD3543-36DC-4A77-90E1-F3AE6B16CF16` (New-Synthetics-Key, Arkose QA): ~124k dict 1 fires an hour.
- **Proxy keys** (JA4 is the customer's proxy, not the browser): a single JA4 on ≥ 98% of a key's sessions over 24h. Known: Payoneer `EE844FC3-499D-4A4D-A643-D7400F0FD4DE` (Login K2), `E3EFEFBF-8DE4-42ED-9E7F-92F35B1FD3CF` (CLM Reg K3), `7CC24C4A-611B-41C7-9808-B95722C7861C`. Pinterest `F5675B21-…` / `F7C0768A-…` proxy passes ~1,100 JA4s/day, so it is not a single-JA4 key. On proxy keys the JA4 weight is 0 and List C does not apply.
- **Googlebot** on DoorDash Website K1 (`DE24F792-2F8A-4CDC-BF2D-70F94BF1660A`) from 66.249.x / 192.178.x: real crawler, high volume at dict 3/7.

## Truth data (TD)

Figma Registration K2 (Legit + Nonlegit labels) and Blizzard ROW Registration K2 (Nonlegit only) have customer truth data. Prefer them for measuring uplift. TD is in **Athena** (Superset `database_id: 2`), `starfleet_production.truth_data_history`, and joins to `starfleet_production.prod_session_summary` (which has the DI, JA4, OS, UA and WebGL fields) on `session = arkose_session_id`. Always filter Athena tables on their `year`/`month`/`day` partitions. Full column list and caveats are at the top of `known_cases.md`. Athena uses Presto/Trino SQL, not Snowflake SQL (e.g. `date_add`, `regexp_like`, `contains()` for arrays).

**TD is optional, not required.** Most keys have no truth data, and where it exists it can arrive **up to ~2 weeks late**. So:
- Every analysis must work without TD (comparison tables, known cases, verify / risk, example sessions).
- When TD is used, pick a window that ended **at least 2–3 weeks ago**, and say how complete the labels look for that window.
- Never treat "no label" as "legitimate".

**Uplift, defined:** among TD **Nonlegit** sessions that Arkose let through (`is_verified = 1`), the share a new rule would have flagged. **False-positive rate:** among TD **Legit** sessions, the share the rule would have flagged. Report both, with counts.

## Judging results

- **"High risk" and "verified" are not ground truth.** Attacks verify when pressure is weak (Adobe ARP K8 solver farm verified 100% of challenges it reached). Use them as indicators, and lean on `known_cases.md` replays.
- Compare against the key's own baseline and the same hour the day before, not just global rates.
- Report counts **and** rates, with the window and sample rate.
