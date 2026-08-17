# Runbook: Validate Login Velocity Detection (Mode B) on a new account

**Audience:** a Claude Code session (incl. Claude on Bedrock / 3P) with access to a
different customer's data. **Goal:** reproduce and validate the Mode B login-velocity
detection on a login public key you have access to, and report whether it behaves
sanely (tier distribution + false-positive safety) on that key.

This runbook is **self-contained** — the analyser and the extraction query are embedded
below. You need only Python 3.8+ and read access to the session data (Athena
`events_faster` or an equivalent session table). No repo access required.

**What "Mode B" means:** the customer sends only the session — **no end-user account
identifier and no login outcome** (the two are inseparable: a backend that can report a
login outcome has already resolved the account, so it could send the identifier). Because
there is no account identifier, account fan-out is unobservable, and the verdict must come
from **infrastructure + timing signals alone**. That is exactly why Mode B is the case to
validate first — it carries the most false-positive risk.

**Scope (do not change without checking §7 of the design doc):** desktop only, non-Safari
(`Windows`, `GNU/Linux`, `Ubuntu`, `Chrome OS`), good fingerprint encryption. Point it at a
**login** public key.

---

## Step 0 — Create the analyser file

Save the block below **exactly** as `login_velocity_modeb.py`. (In a shell:
`cat > login_velocity_modeb.py` then paste, or write the file directly.)

```python
#!/usr/bin/env python3
"""Login Velocity Detection — Mode B analyser (no end-user identifiers).

Mode B is the low-integration case: the customer sends only the session, no
account identifier and no login outcome (the two are inseparable). Account
fan-out is therefore unobservable, so this analyser reaches a verdict from
infrastructure + timing signals alone. That makes Mode B the case to validate
first.

Anchor (the "signup flow 3 anchor", reused for login):
    (init_fingerprint, cdn__ja4_hash, timezone_continent, date)

Scoring uses cluster corroboration rather than a raw signal count, because the
compound anchor leaves only two genuinely independent dimensions:
  - Network      : proxy/VPN/hosting, IP rotation, ASN/subnet/country concentration,
                   harvested proxy, timezone scatter  (fires if ANY member fires)
  - Timing       : automated cadence  (rapid avg gap, bursts, metronomic regularity)
  - Device/UA    : user-agent mismatch  (JA4 itself is pinned by the anchor, so it
                   cannot corroborate — this is the cost of losing the identifier)

Verdict (per anchor-cluster, after the daily velocity gate):
    HARD_CHALLENGE : Timing fires AND at least one of {Network, Device} fires
    CHALLENGE      : Timing alone, OR (Network AND Device) without Timing
    MONITOR        : exactly one of {Network, Device}, no Timing
    NOISE          : gate passed, nothing fired
    COLLISION      : >500 sessions in any hour AND >10 distinct ISPs (fingerprint reuse)
    LOW_VELOCITY   : below the daily gate

Zero dependencies. Python 3.8+.

Usage:
    python3 login_velocity_modeb.py --data sessions.csv [--daily-threshold 30]
                                    [--export-clusters clusters.csv]
    python3 login_velocity_modeb.py --self-test
"""

import argparse
import csv
import statistics
import sys
from collections import defaultdict
from datetime import datetime, timezone

# --- Tunable thresholds (calibrate per key) ------------------------------------
DEFAULT_DAILY_GATE = 30        # Mode B raw-session gate/anchor/day (login >> signup's 6)
RAPID_GAP_SECONDS = 300        # avg gap < 5 min
BURST_WINDOW_SECONDS = 300     # rolling window for burst count
BURST_MIN_SESSIONS = 6         # >=6 sessions inside one 5-min window => bursty
CADENCE_CV_MAX = 0.35          # coefficient of variation below this => metronomic
METRONOMIC_MAX_GAP = 120       # regularity only counts as automation at machine speed
                               # (a regular *slow* cadence is normal human re-auth)
IP_ROTATION_RATIO = 0.5        # distinct_ips / sessions > 0.5
CONCENTRATION_SHARE = 0.8      # 80%+ share for same-IP / same-ASN
SUBNET_MAX = 3                 # <=3 distinct /24 subnets => concentrated
TZ_SCATTER_MIN = 3             # >=3 distinct timezones within a continent => scatter
UA_MISMATCH_SHARE = 0.5        # 50%+ sessions with UA mismatch
COLLISION_HOURLY = 500         # >500 sessions in any hour ...
COLLISION_ISPS = 10            # ... AND >10 ISPs => fingerprint collision


# --- Field access (tolerant to raw and *_at_session_created aliases) ------------
_ALIASES = {
    "fp": ["init_fingerprint", "init_fingerprint_at_session_created"],
    "ja4": ["cdn__ja4_hash", "cdn__ja4_hash_at_session_created"],
    "ts": ["session_ts", "timestamp"],
    "ip": ["user_ip", "user_ip_at_session_created"],
    "isp": ["isp", "latest_isp"],
    "asn": ["asn", "latest_asn"],
    "country": ["country", "country_at_session_created"],
    "timezone": ["timezone", "latest_timezone"],
    "is_proxy": ["is_proxy", "latest_is_proxy"],
    "is_vpn": ["is_vpn", "latest_is_vpn"],
    "active_vpn": ["active_vpn", "latest_active_vpn"],
    "is_hosting": ["is_hosting_provider", "latest_is_hosting_provider"],
    "harvested": [
        "ip_intel__is_proxy_harvested",
        "ip_intel__dx_user_ip__is_proxy_harvested",
    ],
    "ua_mismatch": ["ua_mismatch"],
}


def _get(row, key):
    for name in _ALIASES[key]:
        if name in row and row[name] not in (None, ""):
            return row[name]
    return ""


def _as_bool(v):
    return str(v).strip().lower() in ("true", "t", "1", "yes", "y")


def _continent(tz):
    tz = (tz or "").strip()
    if not tz:
        return "Unknown"
    return tz.split("/")[0] if "/" in tz else tz


def _parse_ts(v):
    v = str(v).strip()
    if not v:
        return None
    try:
        n = float(v)
        if n > 1e12:
            n /= 1000.0
        return datetime.fromtimestamp(n, tz=timezone.utc)
    except ValueError:
        pass
    for fmt in ("%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S",
                "%Y-%m-%dT%H:%M:%S.%f%z", "%Y-%m-%d %H:%M:%S.%f"):
        try:
            dt = datetime.strptime(v.replace("Z", "+0000"), fmt)
            return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    return None


def _subnet24(ip):
    parts = str(ip).split(".")
    return ".".join(parts[:3]) + ".0" if len(parts) >= 3 else str(ip)


def _timing(epochs):
    """Return (avg_gap, median_gap, p90_gap, cv, max_burst) over sorted epochs."""
    if len(epochs) < 2:
        return None, None, None, None, len(epochs)
    e = sorted(epochs)
    gaps = [e[i + 1] - e[i] for i in range(len(e) - 1)]
    avg = statistics.mean(gaps)
    med = statistics.median(gaps)
    p90 = sorted(gaps)[max(0, int(round(0.9 * (len(gaps) - 1))))]
    cv = (statistics.pstdev(gaps) / avg) if avg > 0 else 0.0
    burst, lo = 1, 0
    for hi in range(len(e)):
        while e[hi] - e[lo] > BURST_WINDOW_SECONDS:
            lo += 1
        burst = max(burst, hi - lo + 1)
    return avg, med, p90, cv, burst


def _peak_hourly(epochs):
    if not epochs:
        return 0
    e = sorted(epochs)
    peak, lo = 1, 0
    for hi in range(len(e)):
        while e[hi] - e[lo] > 3600:
            lo += 1
        peak = max(peak, hi - lo + 1)
    return peak


def evaluate(sessions, daily_gate):
    """sessions: list of normalised dicts for one anchor-cluster."""
    n = len(sessions)
    epochs = [s["epoch"] for s in sessions if s["epoch"] is not None]
    ips = [s["ip"] for s in sessions if s["ip"]]
    isps = [s["isp"] for s in sessions if s["isp"]]
    asns = [s["asn"] for s in sessions if s["asn"]]
    countries = {s["country"] for s in sessions if s["country"]}
    tzs = {s["timezone"] for s in sessions if s["timezone"]}
    subnets = {_subnet24(ip) for ip in ips}

    avg_gap, med_gap, p90_gap, cv, burst = _timing(epochs)

    def share(values):
        if not values:
            return 0.0
        counts = defaultdict(int)
        for v in values:
            counts[v] += 1
        return max(counts.values()) / len(values)

    signals = {}
    signals["RAPID_TIMING"] = avg_gap is not None and avg_gap < RAPID_GAP_SECONDS
    signals["BURST"] = burst >= BURST_MIN_SESSIONS
    signals["METRONOMIC"] = (cv is not None and n >= 5 and cv < CADENCE_CV_MAX
                             and med_gap is not None and med_gap < METRONOMIC_MAX_GAP)
    signals["IP_ROTATION"] = n > 0 and (len(set(ips)) / n) > IP_ROTATION_RATIO
    signals["SAME_ASN_80PCT"] = share(asns) >= CONCENTRATION_SHARE
    signals["SAME_IP_CONCENTRATED"] = share(ips) >= CONCENTRATION_SHARE
    signals["HOSTING_VPN_PROXY"] = any(
        s["is_proxy"] or s["is_vpn"] or s["active_vpn"] or s["is_hosting"]
        for s in sessions
    )
    signals["SINGLE_COUNTRY"] = len(countries) == 1
    signals["SUBNET_CONCENTRATED"] = 0 < len(subnets) <= SUBNET_MAX
    signals["MULTI_ISP_SAME_COUNTRY"] = len(set(isps)) >= 2 and len(countries) == 1
    signals["HARVESTED_PROXY"] = any(s["harvested"] for s in sessions)
    signals["TIMEZONE_MISMATCH"] = len(tzs) >= TZ_SCATTER_MIN
    ua_share = sum(1 for s in sessions if s["ua_mismatch"]) / n if n else 0.0
    signals["UA_MISMATCH"] = ua_share >= UA_MISMATCH_SHARE

    timing_fired = signals["RAPID_TIMING"] or signals["BURST"] or signals["METRONOMIC"]
    network_fired = any(signals[k] for k in (
        "IP_ROTATION", "SAME_ASN_80PCT", "SAME_IP_CONCENTRATED", "HOSTING_VPN_PROXY",
        "SINGLE_COUNTRY", "SUBNET_CONCENTRATED", "MULTI_ISP_SAME_COUNTRY",
        "HARVESTED_PROXY", "TIMEZONE_MISMATCH"))
    device_fired = signals["UA_MISMATCH"]
    others = int(network_fired) + int(device_fired)

    collision = _peak_hourly(epochs) > COLLISION_HOURLY and len(set(isps)) > COLLISION_ISPS

    if collision:
        verdict = "COLLISION"
    elif n < daily_gate:
        verdict = "LOW_VELOCITY"
    elif timing_fired and others >= 1:
        verdict = "HARD_CHALLENGE"
    elif timing_fired and others == 0:
        verdict = "CHALLENGE"
    elif not timing_fired and others == 2:
        verdict = "CHALLENGE"
    elif not timing_fired and others == 1:
        verdict = "MONITOR"
    else:
        verdict = "NOISE"

    return {
        "verdict": verdict,
        "sessions": n,
        "distinct_ips": len(set(ips)),
        "distinct_isps": len(set(isps)),
        "distinct_countries": len(countries),
        "distinct_subnets_24": len(subnets),
        "avg_gap_s": round(avg_gap, 1) if avg_gap is not None else None,
        "median_gap_s": round(med_gap, 1) if med_gap is not None else None,
        "p90_gap_s": round(p90_gap, 1) if p90_gap is not None else None,
        "cadence_cv": round(cv, 3) if cv is not None else None,
        "max_burst_5min": burst,
        "clusters": {"network": network_fired, "timing": timing_fired, "device": device_fired},
        "signals": [k for k, v in signals.items() if v],
    }


def _normalise(row):
    return {
        "epoch": (_parse_ts(_get(row, "ts")).timestamp()
                  if _parse_ts(_get(row, "ts")) else None),
        "ip": _get(row, "ip"),
        "isp": _get(row, "isp"),
        "asn": _get(row, "asn"),
        "country": _get(row, "country"),
        "timezone": _get(row, "timezone"),
        "is_proxy": _as_bool(_get(row, "is_proxy")),
        "is_vpn": _as_bool(_get(row, "is_vpn")),
        "active_vpn": _as_bool(_get(row, "active_vpn")),
        "is_hosting": _as_bool(_get(row, "is_hosting")),
        "harvested": _as_bool(_get(row, "harvested")),
        "ua_mismatch": _as_bool(_get(row, "ua_mismatch")),
    }


def _anchor_key(row):
    ts = _parse_ts(_get(row, "ts"))
    date = ts.strftime("%Y-%m-%d") if ts else "unknown"
    return (_get(row, "fp"), _get(row, "ja4"),
            _continent(_get(row, "timezone")), date)


def analyse_rows(rows, daily_gate):
    clusters = defaultdict(list)
    for row in rows:
        clusters[_anchor_key(row)].append(_normalise(row))
    results = []
    for anchor, sessions in clusters.items():
        r = evaluate(sessions, daily_gate)
        r["anchor"] = anchor
        results.append(r)
    results.sort(key=lambda r: (r["verdict"], -r["sessions"]))
    return results


def _print_summary(results, daily_gate):
    order = ["HARD_CHALLENGE", "CHALLENGE", "MONITOR", "NOISE",
             "COLLISION", "LOW_VELOCITY"]
    by_tier = defaultdict(lambda: [0, 0])
    for r in results:
        by_tier[r["verdict"]][0] += 1
        by_tier[r["verdict"]][1] += r["sessions"]
    print(f"\nLogin Velocity — Mode B  (daily gate = {daily_gate} sessions/anchor)")
    print(f"{'TIER':<16}{'CLUSTERS':>10}{'SESSIONS':>12}")
    print("-" * 38)
    for tier in order:
        c, s = by_tier[tier]
        print(f"{tier:<16}{c:>10,}{s:>12,}")
    print("-" * 38)
    print(f"{'TOTAL':<16}{len(results):>10,}{sum(r['sessions'] for r in results):>12,}\n")


def _export(results, path):
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["init_fingerprint", "ja4_hash", "tz_continent", "date", "verdict",
                    "sessions", "distinct_ips", "distinct_isps", "distinct_countries",
                    "distinct_subnets_24", "avg_gap_s", "median_gap_s", "p90_gap_s",
                    "cadence_cv", "max_burst_5min", "network", "timing", "device",
                    "signals"])
        for r in results:
            fp, ja4, cont, date = r["anchor"]
            cl = r["clusters"]
            w.writerow([fp, ja4, cont, date, r["verdict"], r["sessions"],
                        r["distinct_ips"], r["distinct_isps"], r["distinct_countries"],
                        r["distinct_subnets_24"], r["avg_gap_s"], r["median_gap_s"],
                        r["p90_gap_s"], r["cadence_cv"], r["max_burst_5min"],
                        cl["network"], cl["timing"], cl["device"], "|".join(r["signals"])])


def _synth():
    """Build labelled synthetic clusters covering each expected verdict."""
    rows = []
    base = int(datetime(2026, 8, 17, 8, 0, 0, tzinfo=timezone.utc).timestamp())

    def add(fp, ja4, tz, offset, ip, isp, asn, country, n, gap, *, proxy=False,
            harvested=False, ua=False, ip_series=None, isp_series=None):
        for i in range(n):
            rows.append({
                "init_fingerprint": fp, "cdn__ja4_hash": ja4, "timezone": tz,
                "session_ts": datetime.fromtimestamp(base + offset + i * gap,
                                                     tz=timezone.utc).isoformat(),
                "user_ip": ip_series[i] if ip_series else ip,
                "isp": isp_series[i % len(isp_series)] if isp_series else isp,
                "asn": asn, "country": country,
                "is_proxy": proxy, "is_vpn": False, "active_vpn": False,
                "is_hosting_provider": proxy,
                "ip_intel__is_proxy_harvested": harvested, "ua_mismatch": ua,
            })

    add("fp_stuff", "ja4_bot", "America/New_York", 0, None, None, "AS1", "US",
        n=90, gap=25, proxy=True, harvested=True,
        ip_series=[f"10.{i//254}.{i%254}.7" for i in range(90)],
        isp_series=["ISP-A", "ISP-B", "ISP-C"])
    add("fp_office", "ja4_chrome", "Europe/London", 100000, "203.0.113.9",
        "BT", "AS2", "GB", n=45, gap=420)
    add("fp_light", "ja4_chrome", "Europe/Paris", 200000, "198.51.100.5",
        "Orange", "AS3", "FR", n=15, gap=900)
    add("fp_uaspoof", "ja4_chrome", "Asia/Tokyo", 259200, "192.0.2.4",
        "NTT", "AS4", "JP", n=60, gap=300, ua=True)
    add("fp_coll", "ja4_chrome", "America/Chicago", 400000, None, None, "AS9", "US",
        n=1200, gap=2,
        ip_series=[f"172.16.{i//254}.{i%254}" for i in range(1200)],
        isp_series=[f"ISP-{i}" for i in range(40)])
    for i in range(35):
        rows.append({
            "init_fingerprint": "fp_noise", "cdn__ja4_hash": "ja4_chrome",
            "timezone": ["America/Denver", "America/Chicago"][i % 2],
            "session_ts": datetime.fromtimestamp(base + 100000 + i * 600,
                                                 tz=timezone.utc).isoformat(),
            "user_ip": f"8.{i % 14}.0.1",
            "isp": f"ISP-{i % 14}", "asn": f"AS{100 + (i % 14)}",
            "country": ["US", "CA", "MX"][i % 3],
            "is_proxy": False, "is_vpn": False, "active_vpn": False,
            "is_hosting_provider": False,
            "ip_intel__is_proxy_harvested": False, "ua_mismatch": False,
        })
    return rows


def _self_test():
    rows = _synth()
    results = {r["anchor"][0]: r for r in analyse_rows(rows, DEFAULT_DAILY_GATE)}
    expected = {
        "fp_stuff": "HARD_CHALLENGE",
        "fp_office": "MONITOR",
        "fp_light": "LOW_VELOCITY",
        "fp_uaspoof": "CHALLENGE",
        "fp_coll": "COLLISION",
        "fp_noise": "NOISE",
    }
    ok = True
    print("Self-test (synthetic Mode B clusters)")
    print(f"{'FINGERPRINT':<12}{'EXPECTED':<16}{'GOT':<16}{'SIGNALS'}")
    print("-" * 78)
    for fp, want in expected.items():
        got = results[fp]["verdict"]
        mark = "ok " if got == want else "XX "
        if got != want:
            ok = False
        print(f"{mark}{fp:<9}{want:<16}{got:<16}{','.join(results[fp]['signals'])}")
    print("-" * 78)
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


def main(argv=None):
    p = argparse.ArgumentParser(description="Login Velocity — Mode B analyser")
    p.add_argument("--data", help="sessions CSV (from the Mode B extraction query)")
    p.add_argument("--daily-threshold", type=int, default=DEFAULT_DAILY_GATE,
                   help=f"velocity gate per anchor/day (default {DEFAULT_DAILY_GATE})")
    p.add_argument("--export-clusters", help="write per-cluster verdicts to CSV")
    p.add_argument("--self-test", action="store_true",
                   help="run built-in synthetic validation and exit")
    args = p.parse_args(argv)

    if args.self_test:
        return _self_test()
    if not args.data:
        p.error("provide --data <sessions.csv> or --self-test")

    with open(args.data, newline="") as f:
        rows = list(csv.DictReader(f))
    results = analyse_rows(rows, args.daily_threshold)
    _print_summary(results, args.daily_threshold)
    if args.export_clusters:
        _export(results, args.export_clusters)
        print(f"Per-cluster verdicts written to {args.export_clusters}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

---

## Step 1 — Confirm Mode B applies (pre-flight)

Run these against your key over the intended window and record the answers:

1. **Is it a login flow key?** Confirm the public key serves a login/sign-in flow (not
   signup). If it's signup, this runbook does not apply.
2. **Identifier fill rate.** Is any end-user identifier column populated at session
   creation? If fill rate is high (≳50%), you are actually in **Mode A** — note it and
   prefer the Mode A approach (fan-out is a far stronger signal). Continue with Mode B
   only if the identifier is absent/sparse.
3. **`fp_encryption_status` distribution.** Confirm which statuses exist (`ok`, `v2__ok`,
   `current`). Adjust the query filter if your key uses different labels.
4. **OS / desktop distribution.** Confirm desktop (`Windows`, `GNU/Linux`, `Ubuntu`,
   `Chrome OS`) is a meaningful share. If the key is mobile-only, this detection does not
   apply. **Do not add macOS** for this run.

## Step 2 — Validate the tool itself (no data needed)

```
python3 login_velocity_modeb.py --self-test
```

**Expected: the last line prints `PASS`** and all six rows show `ok` (HARD_CHALLENGE,
MONITOR, LOW_VELOCITY, CHALLENGE, COLLISION, NOISE). If it prints `FAIL`, stop — the file
was not copied verbatim.

## Step 3 — Extract sessions

Run this against `events_faster` (Athena). Fill in the key and window. **Do not select any
account-identifier column** — that's the definition of Mode B. Save the result as
`sessions.csv`.

```sql
SELECT
    COALESCE(session_token, session)              AS session,
    public_key,
    timestamp                                     AS session_ts,
    init_fingerprint                              AS init_fingerprint,
    cdn__ja4_hash                                 AS cdn__ja4_hash,
    user_ip                                       AS user_ip,
    isp                                           AS isp,
    CAST(asn AS VARCHAR)                          AS asn,
    country                                       AS country,
    timezone                                      AS timezone,
    ip_region                                     AS ip_region,
    connection_type                               AS connection_type,
    is_proxy                                      AS is_proxy,
    is_vpn                                        AS is_vpn,
    active_vpn                                    AS active_vpn,
    is_hosting_provider                           AS is_hosting_provider,
    ip_intel__is_proxy_harvested                  AS ip_intel__is_proxy_harvested,
    ua_mismatch                                   AS ua_mismatch,
    os                                            AS os,
    browser_name                                  AS browser_name,
    fp_encryption_status                          AS fp_encryption_status
FROM arkoselabs.events_faster
WHERE public_key = 'YOUR_LOGIN_PUBLIC_KEY'
  AND ymdh >= 'YYYY/MM/DD/00'          -- 72h+ recommended; the analyser buckets by day
  AND ymdh <  'YYYY/MM/DD/00'
  AND location = 'session_setup'
  AND fp_encryption_status IN ('ok', 'v2__ok', 'current')
  AND os IN ('Windows', 'GNU/Linux', 'Ubuntu', 'Chrome OS')
  AND init_fingerprint IS NOT NULL
  AND init_fingerprint != ''
ORDER BY timestamp;
```

> **Different schema?** If your account uses a pre-aggregated table (e.g.
> `prod_session_summary` with `*_at_session_created` / `latest_*` column names), select the
> equivalent columns — the analyser already accepts both naming conventions, so the CSV
> headers can be either form. The columns it reads: init_fingerprint, cdn__ja4_hash,
> session_ts/timestamp, user_ip, isp, asn, country, timezone, is_proxy, is_vpn, active_vpn,
> is_hosting_provider, ip_intel__is_proxy_harvested, ua_mismatch.

## Step 4 — Calibrate the daily gate

Login has a much higher legitimate velocity baseline than signup (re-auth, shared devices,
SSO/NAT), so the gate must sit **above the legitimate tail**. Look at the distribution of
sessions per anchor per day:

- Group your data by `(init_fingerprint, cdn__ja4_hash, timezone_continent, date)` and look
  at the session-count distribution (e.g. p50/p90/p99/max).
- Pick `--daily-threshold` above the bulk of legitimate anchors. Start at **30**; raise it
  for high-traffic / shared-device-heavy keys, lower only with care.

## Step 5 — Run the detection

```
python3 login_velocity_modeb.py --data sessions.csv \
        --daily-threshold 30 --export-clusters clusters.csv
```

This prints a tier summary and writes per-cluster verdicts (with the fired signals) to
`clusters.csv`.

## Step 6 — Validate the output (this is the point of the exercise)

Do all of these and record findings:

1. **Tier distribution sanity.** Report the counts/sessions per tier. HARD_CHALLENGE should
   be a small, plausible fraction — not the majority of traffic. If most of the key is
   HARD_CHALLENGE, the gate is too low or the key is unusual; re-check Step 4.
2. **False-positive safety (most important).** Open several MONITOR and NOISE clusters and a
   sample of HARD_CHALLENGE clusters. Legitimate shared-device patterns (office, school,
   SSO/NAT: single IP + single country, human timing, no proxy, no UA mismatch) should land
   in **MONITOR/NOISE, not HARD_CHALLENGE**. Flag any that look like legit shared devices in
   HARD_CHALLENGE.
3. **Spot-check HARD_CHALLENGE.** For 5–10 HARD clusters, confirm the fired signals tell a
   coherent attack story (e.g. rapid/burst timing + proxy/rotation). Note any that look
   thin.
4. **COLLISION check.** Confirm COLLISION clusters really look like fingerprint reuse
   (very high hourly volume + many ISPs), not a single attacker. These are excluded by
   design.
5. **If truth/FP labels exist on this account** (confirmed-bad sessions, known-FP sessions),
   join them to `clusters.csv` and compute:
   - **Recall** = confirmed-bad sessions in HARD_CHALLENGE ÷ total confirmed-bad desktop sessions.
   - **FPR** = known-FP sessions in HARD_CHALLENGE ÷ total known-FP sessions.
   Compare against the signup-flow reference points (FVD v4: ~0.38–0.39% FPR). If no labels
   exist, say so — structural + FP-safety validation is still valuable.

## Step 7 — Report back

Return a short report with:

- **Key / window / total desktop sessions analysed**, and Mode A-vs-B determination from Step 1.
- **Self-test result** (PASS/FAIL).
- **Chosen `--daily-threshold`** and the session-per-anchor distribution that justified it.
- **Tier distribution table** (clusters + sessions per tier).
- **FP-safety findings** — did any legit-looking shared-device clusters land in HARD_CHALLENGE? Examples.
- **HARD_CHALLENGE spot-check** — do the fired signals look like real attacks? Examples.
- **Recall / FPR** if labels were available; otherwise state they weren't.
- **Anything that looked wrong or surprising**, and any threshold you'd recommend changing for this key.

---

## Appendix — signal & tier reference

**Anchor:** `(init_fingerprint, cdn__ja4_hash, timezone_continent, date)`. `timezone_continent`
is the part before `/` in the IANA timezone (e.g. `America/New_York` → `America`).

**Clusters (independent corroboration dimensions):**
- **Network** (fires if ANY member fires): `IP_ROTATION` (distinct IPs/sessions > 0.5),
  `SAME_ASN_80PCT`, `SAME_IP_CONCENTRATED` (≥80% share), `HOSTING_VPN_PROXY`,
  `SINGLE_COUNTRY`, `SUBNET_CONCENTRATED` (≤3 /24s), `MULTI_ISP_SAME_COUNTRY`,
  `HARVESTED_PROXY`, `TIMEZONE_MISMATCH` (≥3 timezones within the continent).
- **Timing**: `RAPID_TIMING` (avg gap < 5 min), `BURST` (≥6 sessions in any 5-min window),
  `METRONOMIC` (low gap variance **and** fast median gap < 2 min).
- **Device**: `UA_MISMATCH` (≥50% sessions with UA mismatch). JA4 is pinned by the anchor,
  so it cannot corroborate here — that's the cost of losing the account identifier.

**Verdicts:** HARD_CHALLENGE = Timing + (Network or Device); CHALLENGE = Timing alone or
(Network+Device) without Timing; MONITOR = one of Network/Device only; NOISE = gate passed,
nothing fired; COLLISION = >500 sessions/hour AND >10 ISPs; LOW_VELOCITY = below gate.

**Note:** in Mode B, rapid automation almost always trips a Network signal too, so the
realistic HARD path is Timing + Network. A "Timing alone" cluster is rare by construction.

**All thresholds** are constants at the top of `login_velocity_modeb.py` and can be tuned
per key; if you change any, say which and why in the report.
