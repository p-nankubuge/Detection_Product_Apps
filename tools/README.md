# Login Velocity Detection — tooling

Design notes: [`../docs/login-velocity-detection.md`](../docs/login-velocity-detection.md)

## Mode B analyser (validate this first)

`login_velocity_modeb.py` — zero-dependency, Python 3.8+. Mode B is the
low-integration case (session only, no account identifier and no login outcome),
so it has no account fan-out to lean on and is the case to prove out first.

### Validate the logic (no data / warehouse needed)

```
python3 tools/login_velocity_modeb.py --self-test
```

Runs six labelled synthetic anchor-clusters — credential-stuffing farm, heavy
legit office device, light legit, UA-spoof farm, fingerprint collision, and a
diffuse cluster — and asserts each lands in the expected tier
(HARD_CHALLENGE / MONITOR / LOW_VELOCITY / CHALLENGE / COLLISION / NOISE).

### Run against a real login key

```
# 1. extract sessions for a login public key
#    queries/login_modeb_extraction.sql  ->  sessions.csv
# 2. analyse (calibrate --daily-threshold per key; default 30)
python3 tools/login_velocity_modeb.py --data sessions.csv \
        --daily-threshold 30 --export-clusters clusters.csv
```

The analyser groups sessions by the compound anchor
`(init_fingerprint, cdn__ja4_hash, timezone_continent, date)`, applies the daily
velocity gate, then scores each cluster with LII-style cluster corroboration
(Network / Timing / Device) — see the module docstring for the exact rules and
tunable thresholds.

### Calibration workflow

1. Run over a 14-day baseline first and look at the sessions-per-anchor
   distribution to pick `--daily-threshold` above the legitimate tail.
2. Sanity-check the MONITOR / NOISE tiers for legitimate shared-device traffic
   (office, school, SSO/NAT) — these should NOT be in HARD_CHALLENGE.
3. Only after FPR looks sane on a real key, consider Mode A (requires the
   account identifier — the far stronger signal).

## `signal_timeseries_report.py` — created vs verified per signal (SOC-pack style)

Renders a self-contained HTML report with one daily created-vs-verified chart per signal and key,
burst days shaded, plus the proposed suspicion-flag definition and descriptions for each signal.

```
python3 tools/signal_timeseries_report.py \
  --data queries/payoneer_signal_daily_2026-10-28.csv \
  --spec tools/payoneer_signals_spec.json \
  --days 45 --end 2026-10-27 --out docs/payoneer-signals-2026-10-28.html
```

`--days` sets the "last X days" window. The CSV is `signal,key,date,created,verified[,firefox]`; the
daily-outcome query in `queries/payoneer_hunt.sql` (section 2) produces it per signal.
