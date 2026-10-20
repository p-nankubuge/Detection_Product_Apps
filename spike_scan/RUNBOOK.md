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
  sql/05_hourly_by_key.sql        hourly exact counts for the chart keys (status + hourly panel)
  render.py                   fills SQL templates (dates, vocab, combos)
  spike_report.py             ingest / keys / missing / report (stdlib only)
  data/daily_key_counts.csv   exact all-key history: day, public_key, key_total, combo_id, sessions
  data/chart_key_counts.csv   exact history for data/chart_keys.txt, with verified counts (per-key charts)
  data/hourly_key_counts.csv  hourly exact counts for chart keys: ts_hour, public_key, combo_id, sessions, verified
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
   `python3 spike_report.py ingest --day <day> --packed '<PACKED cell>'`. A full-day all-key scan can
   exceed the Superset timeout: run `--half am` then `--half pm` (ingest the second with `--add`), and
   if a half still times out split it with `--hours 12-18` / `--hours 18-24`. If a combo was added since the last run, its history before
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
   - draft the TT: location row (`session_setup`, or `check_answer` when a flag only fires there) + `#INCLUDE` each flag, `telltale_type: suspicion_flags`,
     name `g-<short-flag-names>`; run `validate_telltale` and save the payload to
     `telltales/<name>.json` with the validation result in `_validated`. If an included telltale has a
     TTL (Ensemble ones do), validation requires a matching `degrade_time`.
   - Move combos that no longer earn their place to `retired` with a dated reason.
   **Never call `create_telltale`.** Creating/activating is the analyst's decision.
6. **Key names.** For any `public_key` in the CSV that is not in `data/key_names.json`, call
   `lookup_key_names` (batch), save the result to a temp JSON and `python3 spike_report.py keys --names <file>`.
7. **Per-key charts (created vs verified), from 4+ days before the spike through now.** Spiking keys of every
   combo go in `data/chart_keys.txt` (add new spiking keys there). For each missing day:
   `python3 render.py sql/03_track_exact_day.sql --win-start <day> --keys data/chart_keys.txt --combos combos.json`
   → `execute_sql` → `python3 spike_report.py ingest --chart --day <day> --packed '<cell>'`. The key filter
   makes a full day run in ~10-25s; run these one at a time (two in parallel time out).
   **Hourly, D-4 00:00 → now.** For every day from D-4 to today run `sql/05_hourly_by_key.sql` (same `--keys`/`--combos`)
   and save with `spike_report.py hourly --day <day> --packed '<cell>'`. If a day times out, slice it with
   `--hours 0-12` / `--hours 12-24` (or 6h slices) on BOTH render.py and `hourly` — `hourly --hours` replaces only those hours.
   Re-run today's slice right before rendering so the charts end at the latest hour. 05 emits 8-char key prefixes
   (smaller response); `hourly` maps them back via `chart_keys.txt`, so keep that file current first.
   Then per combo: `python3 spike_report.py perkey --combo <id> --win-start <D-4> --win-end <D>`. Each key card has
   - a daily chart: 7-day baseline (D-11 .. D-5), the shaded window (D-4 .. Y) and **today so far** as a hollow point
     (summed from today's hourly rows, label says up to which hour);
   - an hourly chart from D-4 00:00 to the last complete hour; the shaded last 24h is the status window;
   - status from the last 24 complete hours vs the baseline daily mean: ongoing (≥3×), elevated (1.5–3×), subsided.
   Read each chart: created ≫ verified = already mitigated; lines on top of each other = getting through.
   Lead the summary with keys that are ongoing AND getting through.
   **Adding a combo later:** backfill only the new one with a temporary combos file holding just the new entries:
   render 03 with `--combos new.json` (all keys, 12h halves) and `ingest --combos new.json` — only those combo ids
   are replaced. A combo's first flag is its anchor and may be a suspicion flag or a `telltale`-type global
   (render.py matches it against both SUSPICION_FLAGS and TELLTALE_LIST_AT_ALL_EVENTS).
7b. **Recurrence (does it come back?).** For every key that spiked on any tracked combo, keep the daily
   key-scoped history in `data/chart_key_counts.csv` going back ≥2 weeks before the window, and list those
   keys per combo in `data/recur_keys.json` (new spiking keys: add them there and backfill their earlier days
   with the key-scoped query, one full day per call, ~15s). Then
   `python3 spike_report.py recurrence --start <D-25> --end <D> --today <today>` writes
   `reports/recurrence_<today>.html` (heat table per key, each row on its own scale) and
   `data/recurrence_<today>.json`, which the main report reads for its per-combo burst-episode list.
   Burst day = ≥1k sessions and ≥3× the key's median day; back-to-back days = one episode; ≥2 episodes = recurring.
   Run this before step 8.
   **TTs created 2026-10-19** (grease, di-dict3, rta, ends-te, single-click, ja4-dict1): their names now appear in
   `TELLTALE_LIST_AT_ALL_EVENTS` from a zero baseline, so step 1 will show them as spiking on every key they fire on.
   Exclude them from step 1 until 2026-10-26 (same as the Oct 14-edited TTs). Tracking is unchanged, because it
   matches the raw flags, not the TT name. Daily check for live combos: a falling verified share on keys that have
   pressure means the action works; created dropping to ~0 means the attacker moved, so look for a new combo on that key in step 2.
8. **Report.** Save the shortlist as `data/discovery_<Y>.json` (same shape as the existing files),
   then `python3 spike_report.py report --win-start <D-4> --win-end <D> --discovery data/discovery_<Y>.json`.
   Screenshot `reports/latest.html` (Playwright, `executablePath: '/opt/pw-browsers/chromium'`)
   and look at it before committing.
8b. **SOC action pack (the deliverable to share).** Set `action` (keep live / create / create (scoped) / hold) and
   `action_detail` on each combo in `combos.json` from the recurrence and status findings, then
   `python3 spike_report.py soc --win-start <D-4> --win-end <D> --recur-start <D-25> --discovery data/discovery_<Y>.json`
   -> `reports/soc_<D>.html` + `reports/soc_latest.html`: one self-contained file with the action summary and, per TT
   combination (live and candidates), the signals, TT definition, recurrence table and per-key time series.
   Send this file to SOC; the other reports are working views.
   Optional `--chart-start 2026-09-20` stretches the per-key daily charts back to the start of the history (status and
   baseline still use --win-start). Candidate combos with `status` != live are listed in a highlighted
   "not created yet" card at the top, with their flags marked. `hourly_keys` on a combo limits status to keys with exact hourly data.
   Optional `--summary data/summary_<D>.json` (`{title, sections: [{h, items: [text]}]}`) adds a top card: what is still
   ongoing, new keys, what was mitigated. Use it for catch-up runs (e.g. after a weekend).
   Catch-up runs: pull hourly per chart key with `05_hourly_by_key.sql` in 6-12h slices (12h works when the warehouse
   is quiet), then build that range's daily `chart_key_counts` rows by summing the hourly rows. The hourly query uses
   HAVING >= 40/hour, so small counts are slightly undercounted. Pairs with no baseline rows get Oct 11-14-style fills
   from hourly sums so that status is not judged against a 0 baseline. The hourly chart in the pack starts at --win-start.
9. **Commit and push** `spike_scan/` with a message like `spike-scan: <Y> — N combos tracked, M new`.

## Known limits

- Discovery uses `SAMPLE SYSTEM (1)` (block sampling) because row sampling and exact multi-day scans
  time out in Superset. Block samples are clumpy at small counts — discovery only shortlists; every
  number in the report comes from the exact per-day query.
- Athena `events_faster` was tried first and times out even for one sampled day; Snowflake
  `PROD_INT_SESSION_SUMMARY` is the source. `SUSPICION_FLAGS` and `TELLTALE_LIST_AT_ALL_EVENTS`
  are concatenated so both suspicion flags and `telltale`-type globals (e.g. DI telltales) match.
- Session-level, Production keys only, all locations rolled into the session.
