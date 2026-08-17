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
