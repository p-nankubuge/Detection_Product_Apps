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
   **TT created 2026-10-30:** g-os-impersonation-appleos-device-param-spoofing-sec-fetch-dest (id 14989770). Its name enters
   TELLTALE_LIST from 0, so exclude it from step 1 until 2026-11-10.
   **TT created 2026-11-01:** g-biometric-mouse-exact-replay-above-2-events-4plus (id 15052692, check_answer, global suspicion
   flag; pressure keys in CHNGE-6738 item 6). Its name enters SUSPICION_FLAGS from 0, so exclude it from step 1 until 2026-11-12.
   **Parents created 2026-11-06 03:17-03:24 UTC** (CHNGE-6738 A-D): g-cdn-pragma-sec-ch-ua-upcoming-chrome (15144777),
   g-spoofed-os-mismatch-pagebio-null-grease (15144778), g-di-dict3-st-1x-di-short-300-pxr1 (15144820), g-os-spoofing-pagebio-null
   (15144836); G g-pagebio-null-grease-accept-lang-fp-mismatch (15144910), H g-upcoming-chrome-consecutive-sec-ch-ua-ip-intel-medium (15144915). Their names enter SUSPICION_FLAGS from 0: exclude them from step 1 until 2026-11-17.
   **DI dictionary flags off 2026-10-27, revert planned week of 2026-11-02** (THR-405..413, m.davies): dict-1, dict-3 and
   dict-neg1 got an impossible `di_dictionary_num_matched == -99` condition (never fire); dict-7/15/31 were re-thresholded.
   When the revert lands, these flags (and every combo/TT that includes them, incl. g-device-parameter-spoofing and the
   dict-3 TTs) will jump from ~0 back to normal on every key at the same hour. Treat that jump as a definition change, not an
   attack: check `get_telltale_changelog` for the revert time, drop them from step 1 for 11 days after it (until the
   baseline is clean), and compare tracking only against days before Oct 27. Then lift the hold on `didict3_dishort300` (BLUE-7297).
   **TTs created 2026-10-19** (grease, di-dict3, rta, ends-te, single-click, ja4-dict1): their names now appear in
   `TELLTALE_LIST_AT_ALL_EVENTS` from a zero baseline, so step 1 will show them as spiking on every key they fire on.
   Same for the 2 created 2026-10-20 (g-di-short-300-pxr1-di-dict7-st-1x-high-risk-sig-st, g-rfc-sec-ch-ua-webgl-device-param-spoofing) until 2026-10-27.
   Exclude them from step 1 until 2026-10-26 (same as the Oct 14-edited TTs). Tracking is unchanged, because it
   matches the raw flags, not the TT name. Daily check for live combos: a falling verified share on keys that have
   pressure means the action works; created dropping to ~0 means the attacker moved, so look for a new combo on that key in step 2.
7c. **Share of key traffic (false-positive check, from 2026-11-17).** A signal should flag **under 2% of a key's total traffic**
   unless it is a volumetric attack. After the exact counts are in:
   `python3 spike_report.py totals-keys --win-start <D-4> --win-end <D> --out <scratch>/tot_keys.txt` (keys with >=1k flagged on a window day),
   `python3 render.py sql/04_key_totals.sql --win-start <D-4> --win-end <D> --keys <scratch>/tot_keys.txt` -> `execute_sql`
   (11 days x ~45 keys is ~34k tokens: split into two date ranges by editing SESSION_TS) -> `python3 spike_report.py totals --packed '<cell>'`
   for each piece (merges into `data/key_totals.csv`). Check with `python3 spike_report.py share --win-start <D-4> --win-end <D>`.
   Verdict per combination x key, per window day: share = flagged / all Production sessions on the key.
   - **OK**: <2% on every day with >=1k flagged.
   - **Volumetric attack**: >2% only on days when the key's traffic was >=1.5x its median baseline day AND the flagged sessions
     explain >=50% of the extra traffic (the attack *is* the extra volume, so a high share is expected).
   - **FP risk**: >2% without such a jump, or the signal already flags >2% of the key's median baseline day (it fires on ordinary traffic).
     Read it with the verified share: FP risk + >=50% verified = real users are probably being caught, review before any pressure;
     FP risk + <10% verified = already-blocked bot traffic on a high-bot key, lower concern.
   The SOC pack shows the badges in "What to do" and the candidates card, and a full table per combination. Mention every
   FP-risk pair with >=30% verified in the summary, and never recommend pressure on a key where the signal is FP risk without saying so.
7d. **Traffic drops (from 2026-11-20).** Runs over ALL Production keys, independent of the combos:
   `python3 render.py sql/06_key_volume_drops.sql --win-start <D-4> --win-end <D> --recent-end "<D> <HH>"` with HH = the last complete hour MINUS ONE (the newest hour is still loading:
   on 2026-11-20 the 02-03h hour showed Amazon IDS and gtop100 at 5-35% of normal at 03:10) -> `execute_sql`
   (~25s) -> `python3 spike_report.py drops --run <D> --packed '<cell>'` (-> `data/key_drops.csv`). Flags a key when a window day is below
   40% of its median baseline day (>=5k/day) and below 50% of the same weekday a week earlier (weekend dips on B2B keys are normal), or the last 6 complete hours / the last complete hour are below 40% of the same hours on the
   7 previous days. These are outages / integration or key-config changes, not attacks: the SOC pack lists them in a "Traffic drops" card
   (with the same customer's other keys), and the share-of-traffic check skips whole-day drops for that key. Look up unnamed keys with
   `lookup_key_names` + `spike_report.py keys`. Say in the summary which drops are one key of a customer while its other keys are normal.
7e. **Claimed UA vs JA4 (from 2026-11-20).** `python3 spike_report.py uaja4-targets --win-start <D-4> --win-end <D> --n 5` picks the
   combination x key pairs with the most flagged traffic that gets through or is FP-risk (one per key). For each:
   `python3 render.py sql/07_ua_ja4_profile.sql --win-start <D-4> --win-end <D> --combo-id <id> --key <key>` -> `execute_sql` (~10s, key-pruned)
   -> `python3 spike_report.py uaja4 --run <D> --combo <id> --key <key> --packed '<cell>'` (-> `data/ua_ja4.json`). Per JA4 cohort of the
   flagged sessions (last 2 days of the window): main claimed browser/major, number of distinct claims (UA rotation), flagged/verified,
   unflagged on the same key, sec-ch-ua vs UA version mismatch, top ASN/country, and what that JA4 is across ALL keys (browser family
   chromium / webkit / firefox, from a 6h baseline slice). A JA4 does not carry a browser version, only the TLS stack, so the check is
   family consistency + rotation + client-hint consistency + concentration. A cohort that is >=30% verified with nothing odd in UA/JA4 is
   called out as a possible FP. The pack shows the table under each combination.
7f. **Attribute anomalies + key focus report (from 2026-11-24).** For a list of keys (one public_key per line):
   `python3 render.py sql/08_key_anomaly_profile.sql --win-start <D-4> --win-end <D> --keys <file> [--sample N]` -> `execute_sql`
   -> `python3 spike_report.py anomaly --run <D> --packed '<cell>' [--sample N]` (-> `data/key_anomalies.json`). Split by KEYS, never by
   dates (the CAPI baseline needs the baseline days); small keys in groups of 3-4, keys over ~1M/day alone with `--sample 25`, Uber SMS
   size (10M+/day) with `--sample 5`. Per key and day it counts: CAPI version off the key's usual one, navigator language != Accept-Language,
   browser vs IP timezone region, JS UA != HTTP UA header, sec-ch-ua != UA version, fake browser/OS/resolution, navigator.platform != OS,
   software WebGL renderer, renderer inconsistent with OS, no renderer, hosting, proxy/VPN, headless. A finding is a rate that is >=2x its
   median baseline day and +2 points (>=300/day), or stands above 20%. A CAPI change to the version most keys moved to (or >=90% verified)
   is a platform release, not an anomaly. Then `python3 spike_report.py focus --keys <file> --win-start <D-4> --win-end <D> --run <D>
   --summary data/focus_summary_<D>.json` -> `reports/focus_<D>.html`: per key traffic + drops (weekend dips ignored), anomalies, tracked
   combinations with the 2% rule, and UA vs JA4 for its biggest combination (07, `uaja4-targets --keys <file> --chart --min-flagged 500`).
   A JA4 group with near-equal volumes that is >=50% verified is usually normal Chrome TLS variants, not rotation.
7g. **Is it an attack? (from 2026-11-24) - verified share is NOT the false-positive test.** Verification is an outcome: a high pass
   rate means real users OR an attack that gets through (a new attack with no pressure on it often shows a HIGH pass rate). Judge a cohort
   (a combination on a key, or any predicate such as "Direct3D renderer with a mobile UA") on session-time evidence with
   `sql/09_cohort_profile.sql` (`render.py ... --key K --combo-id ID` or `--cond "<SQL predicate>"`, `--sample N` for keys over ~1M/day)
   -> `spike_report.py cohort --run D --name N --key K --desc '...' --packed '<cell>' [--sample N]`. Six indicators: new (>=5x its baseline),
   concentrated (sessions/IP, sessions/device, top ASN >=30%, hosting/proxy >=30%), off-rhythm (hourly correlation with the rest of the
   key < 0.5, or flat around the clock), other anomalies >=30% (language, platform, software renderer, headless, fake fingerprint), TLS
   (decoded JA4 does not fit the claimed browser), UA rotation. 3+ = attack-like, 2 = suspicious; only then the pass rate says "getting
   through" (>=20%) or "mostly blocked". The focus report shows a "Cohort profiles" card first.
   **Fingerprint detail (7th indicator, from 2026-11-26; idea from the Blizzard ROW "candidate signals vs truth" work).** 09 now also
   returns, for the cohort AND the rest of the key in the same window: HTTP/3 share, HTTP/1.1 share, fonts that don't match the
   claimed OS (Segoe UI/Calibri on a non-Windows UA, or a Windows UA with 6+ fonts and no Segoe UI), <=4GB memory with 12+ cores
   (rig), no fonts, no fingerprint, the largest share on one exact font set and on one speech-voices hash. It counts when 2+ of: no
   HTTP/3 (<=20% of the rest's rate, rest >=5%); font/OS mismatch >=30% and >=3x the rest; rig >=30%; one font set >=50% and >=2x the
   rest; one voices hash >=60% and >=1.5x the rest. **HTTP/3:** 0% HTTP/3 where the rest of the key has it points to a library or
   automation stack. HTTP/3 at the key's normal rate is NOT an FP bound (truth check 2026-11-26: labelled fraud on Grab 98% vs legit
   65%, Figma 67% vs 37%, Bumble 27% - sweatshop/manual fraud runs real browsers). The score is now out of 7
   (3+ still = attack-like). Cohorts ingested before this change have no granular fields and are still scored out of 6.
   Example (Uber SMS, D3D renderer + non-Windows UA, Nov 21-24): HTTP/3 0% vs 12%, Windows fonts on non-Windows UA 92% vs 5%,
   one font set 78% vs 29%, one voices hash 72% vs 46%.
   **JA4 decoding** (every UA/JA4 and cohort table): part a = transport (t TCP / q QUIC) + TLS version + SNI (d domain / i IP) + cipher
   count + extension count + ALPN (h2 / h1 / h3 / 00 none); part b = cipher-set hash. Browsers: TLS 1.3, SNI, ALPN h2 (h3 on QUIC);
   Chromium b=8daaf6152771 with 15-16 ciphers / 15-18 ext, Safari b=a09f3c656075 with 20 / 13-14, Firefox b=5b57614c22b0 with 17 / 15-17,
   Chrome QUIC b=55b375c5d22e. Red flags: TLS 1.2 or lower, no SNI, no ALPN, ALPN h1 with a browser UA, 25+ ciphers (OpenSSL/library
   default 30-52), < 10 extensions, a cipher set that is not a browser stack, claimed browser != stack, or a browser stack with the
   wrong cipher/extension counts (impersonation libraries such as curl-impersonate / tls-client).
   **Do not build on `ja4-dict-1-challenger` (13957758) or its copy `...-is-supicious-not-included` (13957871)**: the challenger DI
   dictionary 1 has known issues. Use the champion dictionary 1 (`di_dictionary_num_matched == 1`, via the champion flags such as
   `g-di-dict-1-match-short-term-threshold-exceeded-1x`). A raw `di_dictionary_num_matched` row can fail validate_telltale on
   ground_truth_overlap (msidentity2 cdssolver ground truth) - #INCLUDE the champion flag instead.
   **Churned customers (from 2026-11-25):** `data/churned_accounts.json` lists account names (Roblox Corporation churned Nov 2026).
   Their keys are dropped from per-key charts, recurrence tables, the 2% check, drop cards and UA/JA4 targets. Discovery should not
   count them in keys_spiking.
   **Proxy URL integrations (from 2026-11-26):** `data/proxy_integration_keys.json` lists keys where the customer proxies the
   Arkose calls (e.g. Payoneer E3EFEFBF): JA4, HTTP version and header order are the customer's proxy, not the visitor. UA vs JA4,
   the cohort TLS indicator and the HTTP/3 check are skipped for them; never draft a JA4 / header-order TT for such a key. Add a key
   when its JA4 is one non-browser stack for ~all traffic including verified/legit-labelled sessions, and confirm with the TAM.
   **Long-standing cohorts:** before asking SOC to pressure a cohort that has been steady for more than 4 weeks (e.g. Amazon IDS
   TLS1.2 JA4 b75078996b15, 10-25% of the key since August), confirm with the customer / account team that it is not their own
   integration - a steady, normal-looking curve can be a standing operation or an integration artifact.
7h. **Truth labels (from 2026-11-26).** `starfleet_production.truth_data_history` in **Athena (Superset database_id 2)**, not
   Snowflake: one row per labelled session (`is_legit_value` 1 legit / 0 fraud, `source` Stream/Upload, `fraud_category`,
   `suspicion_flags` + `telltale_list` as on the session, partitions year/month/day). Not every key has truth, and most keys are
   one-sided: fraud-only (Blizzard ROW Reg Key 2, uploads of "Automation" for several keys) measures RECALL; legit-only (Uber SMS,
   ~73k legit labels) gives KNOWN false positives. Two-sided keys (A207F8A1, E3EFEFBF, 963556DD) give both.
   `python3 render.py sql/10_truth_check.sql --win-start <D-4>` -> `execute_sql` with database_id 2 -> save as
   `data/truth_<D>.json`. Read it as: legit_hit / key_legit = FP rate on known-good sessions; fraud_hit / key_fraud = share of
   confirmed fraud the combination would catch. A combination with legit hits >=1% of a key's legit labels needs a scoped TT
   or an extra condition. Truth is labels on sessions, so it can score combinations (flags) directly; fingerprint-level cohorts
   (09) are scored with `truth_fp.py` (below).
   **Truth fingerprint check:** `truth_fp.py ids-sql --key K --from A --to B` (Athena, 150 ids per label, <=7-day session window, 2 days
   for 10M+/day keys; filters on session_create_timestamp because partitions are the upload date) -> `truth_fp.py sql --key K --packed
   '<cell>' --out q.sql` -> run q.sql on Snowflake -> `truth_fp.py save --key K --run D --packed '<cell>'` -> `truth_fp.py show`.
   Findings 2026-11-26 (6 keys): labelled sessions are ~100% verified (truth is mostly on sessions that got through). Fonts-vs-OS,
   Direct3D + non-Windows UA, rig, platform mismatch, no fonts / no fingerprint: <=1.3% on legit labels (Uber SMS, Grab, Figma,
   E3EFEFBF) - precise - but 0-7% on labelled fraud (Blizzard ROW Reg 2, Bumble SMS, Grab, Figma): they catch automation stacks, not
   the sweatshop / manual fraud customers label. HTTP/1.1 is key-relative: E3EFEFBF (Payoneer) is 100% HTTP/1.1 because it is a proxy URL
   integration (the JA4 is Payoneer's proxy), Figma legit 23% - never call an h1 JA4 non-browser without checking the rest of the key.
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

## Hand-off to TSE (from 2026-10-23)

Name used outside this repo: **Daily Attack Tracking**. Requests follow the SOC page
"Telltale Request Process (TSE / SOC)": default pressure is **ML Defense**; we never set pressure.
- Epic: BLUE-7295 "Daily Attack Tracking – Telltale Requests (TSE)" (ongoing, one for all runs).
- One Task per signal (labels `daily-attack-tracking`, `telltale-request`), one Sub-task per key.
  Map for each run in `data/jira_<day>.json`. New signals on later runs = new Tasks under the same epic;
  signals that already have a Task get a comment, not a new Task.
- Action pack HTML goes to Drive "Daily Attack Tracking/<date>/" as
  `Daily Attack Tracking – SOC action pack – <date>.html`. The Drive connector cannot upload a 4 MB file,
  so the analyst drops it in; we create the dated folder and link it.
