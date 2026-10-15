# Daily suspicion-flag spike scan — runbook

Finds combinations of suspicion flags / global telltales that spiked across many keys, charts how
many keys each one hits per day, and drafts TT definitions. Runs every day (Routine) and is
re-runnable by hand. Everything goes through the Superset MCP (`execute_sql`, Snowflake,
`database_id` 14) and the Dataswan MCP. No credentials live in this repo.

```
spike_scan/
  combos.json                 tracked combos (live / candidate) + retired ones, with reasons
  sql/01_single_flag_spikes.sql   discovery step 1 — single flags, 1% block sample (~15s)
  sql/02_combo_spikes.sql         discovery step 2 — 2-4 flag combos via bitmasks (~15s)
  sql/03_track_exact_day.sql      tracking — EXACT per-key counts, one UTC day (~20s)
  render.py                   fills SQL templates (dates, vocab, combos)
  spike_report.py             ingest / keys / missing / report (stdlib only)
  data/daily_key_counts.csv   exact history: day, public_key, key_total, combo_id, sessions
  data/key_names.json         public_key -> key/account name
  data/discovery_<day>.json   each run's discovery shortlist
  telltales/*.json            validated TT drafts (not created in Dataswan)
  reports/<day>.html, latest.html
```

## Definitions

- **Window** = the last 4 complete UTC days; **baseline** = the 7 days before it.
- Discovery spike rule (per combo × key, sampled): window daily ≥ 3× baseline daily **and** share of
  the key's traffic ≥ 2× baseline share **and** volume floor (~1–2k sessions/day).
- Report: a key is **hit** on a day at ≥ 1,000 exact sessions; **spiking** when that day is also
  ≥ 3× its baseline daily mean. "Volume on spiking keys" = how attack-specific a combo is
  (91% = nearly all its traffic is the spike; 5% = it mostly fires on steady traffic).

## Daily procedure (D = today UTC, Y = D-1, window = D-4 .. Y)

Work from the repo root, `cd spike_scan`.

1. **Backfill exact counts.** `python3 spike_report.py missing --since <D-11>` lists the days that have
   no rows. For each day: `python3 render.py sql/03_track_exact_day.sql --win-start <day> --combos combos.json`,
   run the SQL via `execute_sql` (database_id 14, limit 5), then
   `python3 spike_report.py ingest --day <day> --packed '<PACKED cell>'`. One day per query — a
   multi-day exact query times out. If a combo was added since the last run, its history before
   today is missing: re-run 03 for the last 11 days (ingest replaces a day's rows, so it is safe).
2. **Discovery, step 1.** `python3 render.py sql/01_single_flag_spikes.sql --win-start <D-4> --win-end <D> --limit 40`
   → `execute_sql`. Keep flags with `keys_spiking >= 3`.
3. **Artifact check — do this before trusting any spike.** For the step-1 flags, call
   `list_telltales(telltale_names="a,b,c")` and look at `last_edited`. A flag edited inside the
   window or the last 3 days of baseline whose baseline is ~0 is a **definition change, not an
   attack** — drop it and say so in the discovery note. Standing exceptions:
   `g--e-country-timezone-mismatch` and other `Ensemble:` telltales are re-dated daily by
   automation; only treat them as edited if the definition actually changed (compare with
   `get_telltale_changelog`). Also drop flags that are not includable (`allow_others_to_include=false`).
4. **Discovery, step 2.** Write the top ~14 surviving flags (plus every flag in `combos.json`) to a
   vocab file, one per line (≤ 16 keeps it fast; hard max 62). Run
   `python3 render.py sql/02_combo_spikes.sql --win-start <D-4> --win-end <D> --vocab vocab.txt --max-arity 4 --limit 20`.
   The response limit is ~25k tokens — keep `limit` ≤ 20.
5. **Pick candidates.** A combo is worth tracking when `keys_spiking >= 5` **and** `spike_share >= 0.5`
   and it is not just a subset/superset of a tracked combo with the same keys. Prefer the
   smallest combo that keeps the share high. For each new one:
   - add it to `combos.json` with `status: candidate` (append to the end — `c<i>` columns are
     positional), and backfill 11 days with step 1;
   - draft the TT: `location = session_setup` + `#INCLUDE` each flag, `telltale_type: suspicion_flags`,
     name `g-<short-flag-names>`; run `validate_telltale` and save the payload to
     `telltales/<name>.json` with the validation result in `_validated`. If an included telltale has a
     TTL (Ensemble ones do), validation requires a matching `degrade_time`.
   - Move combos that no longer earn their place to `retired` with a dated reason.
   **Never call `create_telltale`.** Creating/activating is the analyst's decision.
6. **Key names.** For any `public_key` in the CSV that is not in `data/key_names.json`, call
   `lookup_key_names` (batch), save the result to a temp JSON and `python3 spike_report.py keys --names <file>`.
7. **Report.** Save the shortlist as `data/discovery_<Y>.json` (same shape as the existing files),
   then `python3 spike_report.py report --win-start <D-4> --win-end <D> --discovery data/discovery_<Y>.json`.
   Screenshot `reports/latest.html` (Playwright, `executablePath: '/opt/pw-browsers/chromium'`)
   and look at it before committing.
8. **Commit and push** `spike_scan/` with a message like `spike-scan: <Y> — N combos tracked, M new`.

## Known limits

- Discovery uses `SAMPLE SYSTEM (1)` (block sampling) because row sampling and exact multi-day scans
  time out in Superset. Block samples are clumpy at small counts — discovery only shortlists; every
  number in the report comes from the exact per-day query.
- Athena `events_faster` was tried first and times out even for one sampled day; Snowflake
  `PROD_INT_SESSION_SUMMARY` is the source. `SUSPICION_FLAGS` and `TELLTALE_LIST_AT_ALL_EVENTS`
  are concatenated so both suspicion flags and `telltale`-type globals (e.g. DI telltales) match.
- Session-level, Production keys only, all locations rolled into the session.
