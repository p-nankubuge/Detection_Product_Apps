#!/usr/bin/env python3
"""Spike-scan bookkeeping + report generator (stdlib only).

  ingest  --day YYYY-MM-DD --packed '<cell from 03_track_exact_day.sql>'
          Replaces that day's rows in data/daily_key_counts.csv (long format:
          day,public_key,key_total,combo_id,sessions,verified). c<i>,v<i> map to combos.json combos[i].
  keys    --names keynames.json   merge {public_key: {key_name, account_name}} into data/key_names.json
  missing --since YYYY-MM-DD      print UTC days with no rows yet (yesterday is the last full day)
  report  --win-start D --win-end D [--discovery discovery.json]
          Writes reports/<win-end - 1 day>.html and reports/latest.html.
  hourly  --day YYYY-MM-DD --packed '<cell from 05_hourly_by_key.sql>'   -> data/hourly_key_counts.csv
  perkey  --combo ID --win-start D --win-end D [--all]
          One time-series per spiking key (own y-scale): sessions created vs verified, from
          data/chart_key_counts.csv -> reports/<day>_<combo>_per_key.html.
  soc     --win-start D --win-end D --recur-start D [--discovery F]
          THE deliverable: one HTML for SOC (reports/soc_<today>.html) with the action summary and, per TT
          combination, signals + TT definition + recurrence table + per-key time series.
  recurrence --start D --end D [--today D]
          Burst episodes per combo x key over a long history (keys from data/recur_keys.json)
          -> reports/recurrence_<day>.html + data/recurrence_<day>.json. Answers "does it come back?".
"""
import argparse, csv, datetime as dt, html, json, pathlib, sys
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parent
COUNTS = ROOT / "data" / "daily_key_counts.csv"
CHART_COUNTS = ROOT / "data" / "chart_key_counts.csv"
HOURLY = ROOT / "data" / "hourly_key_counts.csv"  # ts_hour,public_key,combo_id,sessions,verified (chart keys)
HOURLY_FIELDS = ["ts_hour", "public_key", "combo_id", "sessions", "verified"]  # key-filtered exact counts + verified, for perkey
NAMES = ROOT / "data" / "key_names.json"
COMBOS = ROOT / "combos.json"
FIELDS = ["day", "public_key", "key_total", "combo_id", "sessions", "verified"]

# A key counts as "hit" by a combo on a day when it has >= this many exact sessions.
ACTIVE_MIN = 1000
# ...and as "spiking" when that day is >= SPIKE_X times its baseline daily mean (min ACTIVE_MIN).
SPIKE_X = 3


def load_combos(path=None):
    return json.loads(pathlib.Path(path or COMBOS).read_text())["combos"]


def read_counts(path=None):
    path = path or COUNTS
    if not path.exists():
        return []
    with path.open() as f:
        return list(csv.DictReader(f))


def write_counts(rows, path=None):
    path = path or COUNTS
    path.parent.mkdir(parents=True, exist_ok=True)
    rows.sort(key=lambda r: (r["day"], r["combo_id"], r["public_key"]))
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, FIELDS)
        w.writeheader()
        w.writerows(rows)


def cmd_ingest(a):
    combos = load_combos(a.combos)
    ids = {c["id"] for c in combos}
    new = []
    packed = a.packed.strip()
    for chunk in filter(None, packed.split(";")):
        parts = chunk.split(",")
        if len(parts) != 2 + 2 * len(combos):
            sys.exit("chunk has %d fields, expected %d (combos.json changed since the query was rendered?): %s"
                     % (len(parts), 2 + 2 * len(combos), chunk))
        key, tot, vals = parts[0], parts[1], parts[2:]
        for i, c in enumerate(combos):
            created, verified = vals[2 * i], vals[2 * i + 1]
            if int(created) > 0:
                new.append({"day": a.day, "public_key": key, "key_total": tot,
                            "combo_id": c["id"], "sessions": created, "verified": verified})
    path = CHART_COUNTS if a.chart else COUNTS
    old = read_counts(path)
    keep = [r for r in old if r["combo_id"] not in ids]  # other combos' rows (when --combos is a subset)
    old = [r for r in old if r["combo_id"] in ids]
    if a.add:  # second half of a split day: sum into what is there
        idx = {(r["public_key"], r["combo_id"]): r for r in old if r["day"] == a.day}
        tot_by_key = {}
        for r in old:
            if r["day"] == a.day:
                tot_by_key[r["public_key"]] = int(r["key_total"])
        for n in new:
            prev = idx.pop((n["public_key"], n["combo_id"]), None)
            if prev:
                n["sessions"] = str(int(n["sessions"]) + int(prev["sessions"]))
                n["verified"] = str(int(n["verified"]) + int(prev.get("verified") or 0))
            n["key_total"] = str(int(n["key_total"]) + tot_by_key.get(n["public_key"], 0))
        for prev in idx.values():  # key only in the first half
            new.append(prev)
    rows = keep + [r for r in old if r["day"] != a.day] + new
    write_counts(rows, path)
    print("ingested %d rows for %s (%d keys)" % (len(new), a.day, len(packed.split(";")) if packed else 0))


def cmd_hourly(a):
    combos = load_combos(a.combos)
    ids = {c["id"] for c in combos}
    ck = ROOT / "data" / "chart_keys.txt"
    full = {k[:8]: k for k in (ck.read_text().split() if ck.exists() else [])}  # 05 emits 8-char key prefixes
    new = []
    for chunk in filter(None, a.packed.strip().split(";")):
        parts = chunk.split(",")
        if len(parts) != 2 + 2 * len(combos):
            sys.exit("chunk has %d fields, expected %d: %s" % (len(parts), 2 + 2 * len(combos), chunk))
        key, hh, vals = parts[0], int(parts[1]), parts[2:]
        key = full.get(key, key)
        for i, c in enumerate(combos):
            if int(vals[2 * i]) > 0:
                new.append({"ts_hour": "%s %02d" % (a.day, hh), "public_key": key, "combo_id": c["id"],
                            "sessions": vals[2 * i], "verified": vals[2 * i + 1]})
    old = []
    if HOURLY.exists():
        with HOURLY.open() as f:
            h0, h1 = (int(x) for x in (a.hours or "0-24").split("-"))
            old = [r for r in csv.DictReader(f)
                   if not (r["ts_hour"].startswith(a.day) and r["combo_id"] in ids and h0 <= int(r["ts_hour"][-2:]) < h1)]
    rows = sorted(old + new, key=lambda r: (r["ts_hour"], r["combo_id"], r["public_key"]))
    with HOURLY.open("w", newline="") as f:
        w = csv.DictWriter(f, HOURLY_FIELDS)
        w.writeheader()
        w.writerows(rows)
    print("hourly: %d rows for %s" % (len(new), a.day))


def cmd_keys(a):
    names = json.loads(NAMES.read_text()) if NAMES.exists() else {}
    incoming = json.loads(pathlib.Path(a.names).read_text())
    for k, v in incoming.items():
        if v.get("found", True):
            names[k] = {"key_name": v["key_name"], "account_name": v["account_name"]}
    NAMES.write_text(json.dumps(names, indent=1, sort_keys=True) + "\n")
    print("key_names.json: %d keys" % len(names))


def cmd_missing(a):
    have = {r["day"] for r in read_counts()}
    d = dt.date.fromisoformat(a.since)
    last = dt.datetime.now(dt.timezone.utc).date() - dt.timedelta(days=1)
    while d <= last:
        if str(d) not in have:
            print(d)
        d += dt.timedelta(days=1)


# ---------------------------------------------------------------- report

# Validated default categorical palette (dataviz skill, references/palette.md), light/dark.
SERIES_LIGHT = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#6250d6", "#e34948"]
SERIES_DARK = ["#3987e5", "#d95926", "#199e70", "#c98500", "#d55181", "#008300", "#9085e9", "#e66767"]
TOP_KEYS = 7  # + "Other" = 8 slots max


def fmt(n):
    n = float(n)
    for div, suf in ((1e6, "M"), (1e3, "k")):
        if abs(n) >= div:
            return ("%.1f" % (n / div)).rstrip("0").rstrip(".") + suf
    return "%d" % n


def days_between(a, b):
    d, out = a, []
    while d < b:
        out.append(str(d))
        d += dt.timedelta(days=1)
    return out


def key_label(k, names):
    n = names.get(k)
    return n["key_name"] if n else k[:8]


def combo_stats(cid, rows, days, win_days, base_days):
    """per key: daily series, baseline mean, window mean, spiking flag."""
    series = defaultdict(lambda: defaultdict(int))
    for r in rows:
        if r["combo_id"] == cid:
            series[r["public_key"]][r["day"]] = int(r["sessions"])
    stats = {}
    for k, s in series.items():
        base = sum(s.get(d, 0) for d in base_days) / max(len(base_days), 1)
        win = sum(s.get(d, 0) for d in win_days) / max(len(win_days), 1)
        peak = max((s.get(d, 0) for d in win_days), default=0)
        spiking = peak >= ACTIVE_MIN and peak >= SPIKE_X * max(base, 1)
        stats[k] = {"series": [s.get(d, 0) for d in days], "base": base, "win": win,
                    "peak": peak, "spiking": spiking}
    return stats


def keys_per_day(stats, days, base_by_key):
    active, spiking = [], []
    for i, d in enumerate(days):
        a = sum(1 for k, st in stats.items() if st["series"][i] >= ACTIVE_MIN)
        s = sum(1 for k, st in stats.items()
                if st["series"][i] >= ACTIVE_MIN and st["series"][i] >= SPIKE_X * max(base_by_key[k], 1))
        active.append(a)
        spiking.append(s)
    return active, spiking


def svg_keys_line(days, active, spiking, win_start, uid):
    """Line chart: keys hit per day (two series, one axis)."""
    W, H, L, R, T, B = 640, 220, 40, 16, 16, 30
    pw, ph = W - L - R, H - T - B
    ymax = max(active + spiking + [1])
    ymax = int(ymax + (1 if ymax < 5 else ymax * 0.15))
    x = lambda i: L + (pw * i / max(len(days) - 1, 1))
    y = lambda v: T + ph - ph * v / ymax
    out = ['<svg viewBox="0 0 %d %d" class="chart" role="img" aria-labelledby="%s-t">' % (W, H, uid),
           '<title id="%s-t">Keys hit per day</title>' % uid]
    wi = days.index(win_start) if win_start in days else None
    if wi is not None:
        out.append('<rect x="%.1f" y="%d" width="%.1f" height="%d" class="win"/>' % (x(wi) - pw / len(days) / 2, T, W - R - x(wi) + pw / len(days) / 2, ph))
        out.append('<text x="%.1f" y="%d" class="axis">scan window</text>' % (x(wi) - pw / len(days) / 2 + 4, T + 12))
    for t in range(0, ymax + 1, max(1, ymax // 4)):
        out.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" class="grid"/>' % (L, W - R, y(t), y(t)))
        out.append('<text x="%d" y="%.1f" class="axis" text-anchor="end">%d</text>' % (L - 6, y(t) + 4, t))
    for i, d in enumerate(days):
        if i % 2 == 0 or i == len(days) - 1:
            out.append('<text x="%.1f" y="%d" class="axis" text-anchor="middle">%s</text>' % (x(i), H - 10, d[5:]))
    for vals, cls, lab in ((active, "s1", "hit (≥%s sessions)" % fmt(ACTIVE_MIN)), (spiking, "s2", "spiking (≥%d× baseline)" % SPIKE_X)):
        pts = " ".join("%.1f,%.1f" % (x(i), y(v)) for i, v in enumerate(vals))
        out.append('<polyline points="%s" class="line %s"/>' % (pts, cls))
        for i, v in enumerate(vals):
            out.append('<circle cx="%.1f" cy="%.1f" r="4" class="dot %s"/>' % (x(i), y(v), cls))
        out.append('<text x="%.1f" y="%.1f" class="dlabel">%s</text>' % (x(len(vals) - 1) - 4, y(vals[-1]) - 8, vals[-1]))
    # hover columns
    for i, d in enumerate(days):
        out.append('<rect x="%.1f" y="%d" width="%.1f" height="%d" class="hit" data-tip="%s · hit: %d keys · spiking: %d keys"/>'
                   % (x(i) - pw / len(days) / 2, T, pw / len(days), ph, d, active[i], spiking[i]))
    out.append("</svg>")
    return "\n".join(out)


def tt_definition(combo):
    defn = [{"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"}]
    defn += [{"operator": "#INCLUDE", "value": f} for f in combo["flags"]]
    return defn


CSS = """
.viz-root{color-scheme:light;--surface-1:#fcfcfb;--surface-2:#f2f1ee;--text-primary:#0b0b0b;--text-secondary:#52514e;--text-muted:#77766f;--grid:#e4e3df;--win:#f3ece4;
%s}
@media (prefers-color-scheme: dark){:root:where(:not([data-theme="light"])) .viz-root{color-scheme:dark;--surface-1:#1a1a19;--surface-2:#242422;--text-primary:#f0efec;--text-secondary:#c3c2b7;--text-muted:#9a998f;--grid:#33332f;--win:#2b2620;
%s}}
body{margin:0;font-family:Outfit,system-ui,sans-serif}
.viz-root{background:var(--surface-1);color:var(--text-primary);padding:24px 32px;min-height:100vh}
h1{font-size:22px;margin:0 0 4px}h2{font-size:17px;margin:28px 0 4px}h3{font-size:14px;margin:16px 0 6px;color:var(--text-secondary)}
p,li,td,th{font-size:13px;line-height:1.5}.muted{color:var(--text-secondary)}
.card{background:var(--surface-2);border-radius:8px;padding:16px 20px;margin:14px 0}
.tiles{display:flex;gap:28px;flex-wrap:wrap;margin:8px 0}.tile b{display:block;font-size:26px}.tile span{font-size:12px;color:var(--text-secondary)}
.grid2{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:18px}
.chart{width:100%%;height:auto}.grid{stroke:var(--grid);stroke-width:1}.axis{fill:var(--text-muted);font-size:11px}
.win{fill:var(--win)}.line{fill:none;stroke-width:2}.dot{stroke:var(--surface-2);stroke-width:2}
.line.s1{stroke:var(--series-1)}.dot.s1{fill:var(--series-1)}.line.s2{stroke:var(--series-2)}.dot.s2{fill:var(--series-2)}
.dlabel{fill:var(--text-primary);font-size:11px;text-anchor:end}.hit{fill:transparent}
.seg{rx:2}.seg:hover,.hit:hover{opacity:.85;stroke:var(--text-primary);stroke-width:1}
%s .cother{fill:var(--text-muted)}
.eps{margin:4px 0 8px;padding-left:18px}.eps li{font-size:12px;margin:2px 0}
.legend{display:flex;flex-wrap:wrap;gap:6px 16px;margin:6px 0}.lg{font-size:12px;color:var(--text-secondary);display:flex;align-items:center;gap:6px}
.sw{width:10px;height:10px;border-radius:2px;display:inline-block}.sw.s1{background:var(--series-1)}.sw.s2{background:var(--series-2)}
table{border-collapse:collapse;width:100%%}th,td{text-align:left;padding:4px 8px;border-bottom:1px solid var(--grid)}td.n,th.n{text-align:right;font-variant-numeric:tabular-nums}
pre{background:var(--surface-1);border-radius:6px;padding:10px;overflow:auto;font-size:12px}
details summary{cursor:pointer;font-size:13px;color:var(--text-secondary)}
#tip{position:fixed;pointer-events:none;background:var(--text-primary);color:var(--surface-1);font-size:12px;padding:4px 8px;border-radius:4px;display:none;z-index:9}
"""
JS = """<script>
const tip=document.getElementById('tip');
document.querySelectorAll('[data-tip]').forEach(el=>{
 el.addEventListener('mousemove',e=>{tip.textContent=el.dataset.tip;tip.style.display='block';tip.style.left=(e.clientX+12)+'px';tip.style.top=(e.clientY+12)+'px'});
 el.addEventListener('mouseleave',()=>tip.style.display='none')});
</script>"""


def css():
    vars_l = "".join("--series-%d:%s;" % (i + 1, c) for i, c in enumerate(SERIES_LIGHT))
    vars_d = "".join("--series-%d:%s;" % (i + 1, c) for i, c in enumerate(SERIES_DARK))
    seg = "".join(".c%d{fill:var(--series-%d)}.sw.c%d{background:var(--series-%d)}" % (i, i + 1, i, i + 1) for i in range(TOP_KEYS))
    seg += ".sw.cother{background:var(--text-muted)}"
    return CSS % (vars_l, vars_d, seg)


def cmd_report(a):
    combos = load_combos()
    names = json.loads(NAMES.read_text()) if NAMES.exists() else {}
    rows = read_counts()
    ws, we = dt.date.fromisoformat(a.win_start), dt.date.fromisoformat(a.win_end)
    bs = ws - dt.timedelta(days=7)
    days = days_between(bs, we)
    win_days, base_days = days_between(ws, we), days_between(bs, ws)
    have = {r["day"] for r in rows}
    gaps = [d for d in days if d not in have]
    disc = json.loads(pathlib.Path(a.discovery).read_text()) if a.discovery else None
    name = str(we - dt.timedelta(days=1))
    rj = sorted((ROOT / "data").glob("recurrence_20*.json"))
    recur = json.loads(rj[-1].read_text()) if rj else None
    recur_page = ("recurrence_%s.html" % rj[-1].stem.split("_", 1)[1]) if rj else None

    parts = ['<!doctype html><html><head><meta charset="utf-8"><title>Spike scan %s</title><style>%s</style></head><body><div class="viz-root">' % (a.win_end, css())]
    parts.append("<h1>Suspicion-flag spike scan</h1>")
    parts.append('<p class="muted">Window <b>%s → %s</b> (%d days, UTC) vs 7-day baseline %s → %s. Exact session counts from '
                 'ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY (Production keys). A key is <i>hit</i> on a day at ≥%s sessions; '
                 '<i>spiking</i> when also ≥%d× its baseline daily mean. Generated %s.</p>'
                 % (ws, we - dt.timedelta(days=1), len(win_days), bs, ws - dt.timedelta(days=1), fmt(ACTIVE_MIN), SPIKE_X,
                    dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")))
    if gaps:
        parts.append('<p class="muted"><b>Missing days in history:</b> %s — charts show 0 there.</p>' % ", ".join(gaps))

    summary = []
    for ci, c in enumerate(combos):
        st = combo_stats(c["id"], rows, days, win_days, base_days)
        base_by_key = {k: v["base"] for k, v in st.items()}
        active, spiking = keys_per_day(st, days, base_by_key)
        sp_keys = sorted([k for k in st if st[k]["spiking"]], key=lambda k: -st[k]["peak"])
        win_total = sum(sum(st[k]["series"][days.index(d)] for d in win_days) for k in st)
        sp_share = (sum(sum(st[k]["series"][days.index(d)] for d in win_days) for k in sp_keys) / win_total) if win_total else 0
        summary.append((c, len(sp_keys), max(active[-len(win_days):] or [0]), sp_share))
        title = c.get("telltale_name") or c["id"]
        parts.append('<div class="card"><h2>%s <span class="muted" style="font-size:12px;font-weight:400">[%s]</span></h2>' % (html.escape(title), c["status"]))
        parts.append('<p class="muted">%s</p>' % " + ".join("<code>%s</code>" % html.escape(f) for f in c["flags"]))
        parts.append('<div class="tiles"><div class="tile"><b>%d</b><span>keys spiking in window</span></div>'
                     '<div class="tile"><b>%d</b><span>max keys hit on one day</span></div>'
                     '<div class="tile"><b>%s</b><span>window sessions (exact)</span></div>'
                     '<div class="tile"><b>%d%%</b><span>of window volume on spiking keys</span></div></div>'
                     % (len(sp_keys), max(active[-len(win_days):] or [0]), fmt(win_total), round(sp_share * 100)))
        line = svg_keys_line(days, active, spiking, str(ws), "k%d" % ci)
        # No stacked "sessions by key" chart: keys of very different size on one axis flatten each key's spike
        # into what looks like organic up-and-down. Per-key detail lives on the per-key and recurrence pages.
        hist = []
        for r in (recur or {}).get(c["id"], []):
            if r["n_episodes"]:
                hist.append('<li><b>%s</b> · %s · %s</li>' % (html.escape(key_label(r["key"], names)), r["kind"],
                            ", ".join(e["start"][5:] + ("+%dd" % (e["days"] - 1) if e["days"] > 1 else "") + " (" + fmt(e["peak"]) + ")" for e in r["episodes"])
                            + (" + today (%s)" % fmt(r["today"][0]) if r.get("today_burst") else "")))
        links = '<p><a href="%s_%s_per_key.html">Per-key charts: created vs verified, D-4 → now, ongoing/subsided →</a></p>' % (name, c["id"])
        if recur_page:
            links += '<p><a href="%s">Burst history, day by day per key (does it come back?) →</a></p>' % recur_page
        parts.append('<div class="grid2"><div><h3>How many keys this signal applies to, per day</h3>'
                     '<div class="legend"><span class="lg"><i class="sw s1"></i>hit (≥%s sessions)</span><span class="lg"><i class="sw s2"></i>spiking (≥%d× baseline)</span></div>%s</div>'
                     '<div><h3>Burst episodes per key (start date, peak day)</h3>%s%s</div></div>'
                     % (fmt(ACTIVE_MIN), SPIKE_X, line, ('<ul class="eps">%s</ul>' % "".join(hist)) if hist else '<p class="muted">No recurrence data for this combination yet — run <code>recurrence</code>.</p>', links))
        trs = "".join('<tr><td>%s</td><td>%s</td><td class="n">%s</td><td class="n">%s</td><td class="n">%s</td><td class="n">%s</td></tr>'
                      % (html.escape(key_label(k, names)), html.escape(names.get(k, {}).get("account_name", "")), fmt(st[k]["base"]),
                         fmt(st[k]["win"]), fmt(st[k]["peak"]), ("%.0f×" % (st[k]["peak"] / max(st[k]["base"], 1))) if st[k]["base"] >= 1 else "new")
                      for k in sp_keys)
        if trs:
            parts.append('<h3>Spiking keys</h3><table><tr><th>Key</th><th>Account</th><th class="n">Baseline/day</th><th class="n">Window/day</th><th class="n">Peak day</th><th class="n">Peak vs base</th></tr>%s</table>' % trs)
        defn = tt_definition(c)
        if c.get("draft") and (ROOT / c["draft"]).exists():
            defn = json.loads((ROOT / c["draft"]).read_text())
        parts.append('<details><summary>Telltale definition (%s)</summary><pre>%s</pre></details>'
                     % ("live in Dataswan" if c["status"] == "live" else "draft — not created", html.escape(json.dumps(defn, indent=2))))
        parts.append("</div>")

    tbl = "".join('<tr><td>%s</td><td>%s</td><td class="n">%d</td><td class="n">%d</td><td class="n">%d%%</td></tr>'
                  % (html.escape(c.get("telltale_name") or c["id"]), c["status"], n, mx, round(sh * 100)) for c, n, mx, sh in summary)
    parts.insert(3, '<div class="card"><h2>Tracked combinations</h2><table><tr><th>Combination</th><th>Status</th><th class="n">Keys spiking</th><th class="n">Max keys hit/day</th><th class="n">Volume on spiking keys</th></tr>%s</table></div>' % tbl)

    if disc:
        drows = "".join('<tr><td>%s</td><td class="n">%s</td><td class="n">%s</td><td class="n">%s</td><td>%s</td></tr>'
                        % ("<br>".join(html.escape(f) for f in d["combo"].split(" + ")), d["keys_spiking"],
                           ("%d%%" % round(d["spike_share"] * 100)) if d.get("spike_share") is not None else "–",
                           fmt(d.get("est_excess_per_day", 0)), html.escape(d.get("note", "")))
                        for d in disc.get("combos", []))
        parts.append('<div class="card"><h2>Discovery scan (1%% sample)</h2><p class="muted">%s</p><table><tr><th>Combination</th><th class="n">Keys spiking</th><th class="n">Volume on spiking keys</th><th class="n">Est. excess sessions/day</th><th>Note</th></tr>%s</table></div>'
                     % (html.escape(disc.get("summary", "")), drows))

    parts.append('<div id="tip"></div>%s</div></body></html>' % JS)
    out = "\n".join(parts)
    rep = ROOT / "reports"
    rep.mkdir(exist_ok=True)
    (rep / ("%s.html" % name)).write_text(out)
    (rep / "latest.html").write_text(out)
    print("wrote reports/%s.html and reports/latest.html" % name)


def svg_key_lines(days, created, verified, base, win_start, uid, partial=None):
    """One key, one combo: daily sessions created vs verified (same unit, one axis), baseline dashed.
    partial = label for the last point when it is today-so-far (drawn hollow, joined by a dashed segment)."""
    W, H, L, R, T, B = 470, 200, 48, 58, 18, 26
    pw, ph = W - L - R, H - T - B
    ymax = max(created + verified + [base, 1]) * 1.15
    step = pw / max(len(days) - 1, 1)
    x = lambda i: L + step * i
    y = lambda v: T + ph - ph * v / ymax
    out = ['<svg viewBox="0 0 %d %d" class="chart" role="img" aria-labelledby="%s-t">' % (W, H, uid),
           '<title id="%s-t">Sessions created vs verified per day</title>' % uid]
    if win_start in days:
        wi = days.index(win_start)
        out.append('<rect x="%.1f" y="%d" width="%.1f" height="%d" class="win"/>' % (x(wi) - step / 2, T, W - R - x(wi) + step / 2, ph))
    for f in (0, .5, 1):
        v = ymax / 1.15 * f
        out.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" class="grid"/>' % (L, W - R, y(v), y(v)))
        out.append('<text x="%d" y="%.1f" class="axis" text-anchor="end">%s</text>' % (L - 6, y(v) + 4, fmt(v)))
    for i, d in enumerate(days):
        if (len(days) - 1 - i) % 2 == 0:  # count back from the newest day so its label never collides
            out.append('<text x="%.1f" y="%d" class="axis" text-anchor="middle">%s</text>' % (x(i), H - 8, d[5:]))
    if base > 0:
        out.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" class="baseline"/>' % (L, W - R, y(base), y(base)))
        out.append('<text x="%d" y="%.1f" class="axis">baseline avg %s</text>' % (L + 4, y(base) - 4, fmt(base)))
    full = len(days) - (1 if partial else 0)
    for vals, cls in ((created, "s1"), (verified, "s2")):
        out.append('<polyline points="%s" class="line %s"/>' % (" ".join("%.1f,%.1f" % (x(i), y(v)) for i, v in enumerate(vals[:full])), cls))
        if partial and full >= 1:
            out.append('<polyline points="%.1f,%.1f %.1f,%.1f" class="line %s partial"/>' % (x(full - 1), y(vals[full - 1]), x(full), y(vals[full]), cls))
        for i, v in enumerate(vals):
            out.append('<circle cx="%.1f" cy="%.1f" r="3.5" class="dot %s%s"/>' % (x(i), y(v), cls, " hollow" if partial and i == full else ""))
    if partial:
        out.append('<text x="%.1f" y="%d" class="axis" text-anchor="middle">so far</text>' % (x(full), T + 10))
    # direct labels at the line ends (2 series)
    ly = [y(created[-1]), y(verified[-1])]
    if abs(ly[0] - ly[1]) < 12:
        ly[1] = ly[0] + 12 if ly[1] >= ly[0] else ly[0] - 12
    out.append('<text x="%.1f" y="%.1f" class="axis">created</text>' % (x(len(days) - 1) + 6, ly[0] + 4))
    out.append('<text x="%.1f" y="%.1f" class="axis">verified</text>' % (x(len(days) - 1) + 6, ly[1] + 4))
    for i, d in enumerate(days):
        c, v = created[i], verified[i]
        tip = "%s%s · created %s · verified %s (%s)" % (d, (" " + partial) if partial and i == full else "", "{:,}".format(c), "{:,}".format(v), ("%.0f%%" % (100.0 * v / c)) if c else "–")
        out.append('<rect x="%.1f" y="%d" width="%.1f" height="%d" class="hit" data-tip="%s"/>' % (x(i) - step / 2, T, step, ph, tip))
    out.append("</svg>")
    return "\n".join(out)


def load_hourly(combo_id):
    """-> (hours, {key: (created[], verified[])}) for complete hours only (the newest hour is dropped as partial)."""
    if not HOURLY.exists():
        return [], {}
    with HOURLY.open() as f:
        rows = list(csv.DictReader(f))
    hours = sorted({r["ts_hour"] for r in rows})[:-1]
    idx = {h: i for i, h in enumerate(hours)}
    out = defaultdict(lambda: ([0] * len(hours), [0] * len(hours)))
    for r in rows:
        if r["combo_id"] == combo_id and r["ts_hour"] in idx:
            c, v = out[r["public_key"]]
            c[idx[r["ts_hour"]]] = int(r["sessions"])
            v[idx[r["ts_hour"]]] = int(r["verified"])
    return hours, dict(out)


def load_today(combo_id, day):
    """-> ({key: (created, verified)}, last_hour) summed over every hourly row of `day`, incl. the partial newest hour."""
    if not HOURLY.exists():
        return {}, None
    with HOURLY.open() as f:
        rows = [r for r in csv.DictReader(f) if r["ts_hour"].startswith(day)]
    out = defaultdict(lambda: [0, 0])
    for r in rows:
        if r["combo_id"] == combo_id:
            out[r["public_key"]][0] += int(r["sessions"])
            out[r["public_key"]][1] += int(r["verified"])
    return dict(out), (max(r["ts_hour"] for r in rows)[-2:] if rows else None)


def ongoing_status(created, base_daily):
    """ongoing / elevated / subsided from the last 24 complete hours vs the baseline daily mean.
    A rolling 24h total is used (not the last few hours) so attacks that follow a daily
    cycle are not called 'subsided' just because it is their quiet time of day."""
    if not created:
        return "no hourly data", 0.0
    last24 = sum(created[-24:]) * 24.0 / min(24, len(created))
    if last24 >= max(3 * base_daily, ACTIVE_MIN):
        return "ongoing", last24
    if last24 >= max(1.5 * base_daily, ACTIVE_MIN / 2):
        return "elevated", last24
    return "subsided", last24


def svg_hourly(hours, created, verified, base_daily, uid):
    W, H, L, R, T, B = 470, 150, 48, 58, 14, 24
    pw, ph = W - L - R, H - T - B
    base_h = base_daily / 24.0
    ymax = max(created + verified + [base_h, 1]) * 1.15
    step = pw / max(len(hours) - 1, 1)
    x = lambda i: L + step * i
    y = lambda v: T + ph - ph * v / ymax
    out = ['<svg viewBox="0 0 %d %d" class="chart" role="img" aria-labelledby="%s-t">' % (W, H, uid),
           '<title id="%s-t">Hourly sessions created vs verified</title>' % uid]
    if len(hours) >= 24:  # the status window
        out.append('<rect x="%.1f" y="%d" width="%.1f" height="%d" class="win"/>' % (x(len(hours) - 24) - step / 2, T, W - R - x(len(hours) - 24) + step / 2, ph))
        out.append('<text x="%.1f" y="%d" class="axis">last 24h</text>' % (x(len(hours) - 24) + 2, T + 10))
    for f in (0, .5, 1):
        v = ymax / 1.15 * f
        out.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" class="grid"/>' % (L, W - R, y(v), y(v)))
        out.append('<text x="%d" y="%.1f" class="axis" text-anchor="end">%s</text>' % (L - 6, y(v) + 4, fmt(v)))
    for i, h in enumerate(hours):
        if h.endswith(" 00") or (len(hours) <= 48 and h.endswith(" 12")):
            lab = h[5:10] if h.endswith(" 00") else "12h"
            out.append('<line x1="%.1f" x2="%.1f" y1="%d" y2="%d" class="grid"/>' % (x(i), x(i), T, T + ph))
            out.append('<text x="%.1f" y="%d" class="axis" text-anchor="middle">%s</text>' % (x(i), H - 6, lab))
    if base_h > 0:
        out.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" class="baseline"/>' % (L, W - R, y(base_h), y(base_h)))
    for vals, cls in ((created, "s1"), (verified, "s2")):
        out.append('<polyline points="%s" class="line %s"/>' % (" ".join("%.1f,%.1f" % (x(i), y(v)) for i, v in enumerate(vals)), cls))
    ly = [y(created[-1]), y(verified[-1])]
    if abs(ly[0] - ly[1]) < 12:
        ly[1] = ly[0] + 12 if ly[1] >= ly[0] else ly[0] - 12
    out.append('<text x="%.1f" y="%.1f" class="axis">created</text>' % (x(len(hours) - 1) + 6, ly[0] + 4))
    out.append('<text x="%.1f" y="%.1f" class="axis">verified</text>' % (x(len(hours) - 1) + 6, ly[1] + 4))
    for i, h in enumerate(hours):
        c, v = created[i], verified[i]
        out.append('<rect x="%.1f" y="%d" width="%.1f" height="%d" class="hit" data-tip="%s:00 UTC · created %s · verified %s"/>'
                   % (x(i) - step / 2, T, step, ph, h, "{:,}".format(c), "{:,}".format(v)))
    out.append("</svg>")
    return "\n".join(out)


PERKEY_CSS = ('.baseline{stroke:var(--text-secondary);stroke-width:1.5;stroke-dasharray:4 3}'
              '.line.partial{stroke-dasharray:3 3}.dot.hollow.s1{fill:var(--surface-2);stroke:var(--series-1)}.dot.hollow.s2{fill:var(--surface-2);stroke:var(--series-2)}'
              '.kgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(440px,1fr));gap:16px}'
              '.kcard{background:var(--surface-2);border-radius:8px;padding:12px 16px}.kcard h3{margin:0;color:var(--text-primary)}'
              '.kstats{font-size:12px;color:var(--text-secondary);margin:2px 0 6px}.kstats b{color:var(--text-primary)}'
              '.tag{font-size:11px;padding:1px 6px;border-radius:4px;border:1px solid var(--grid);margin-left:6px;color:var(--text-secondary)}'
              '.tag.ongoing{border-color:var(--text-primary);color:var(--text-primary);font-weight:600}'
              '.sub{font-size:11px;color:var(--text-muted);margin:8px 0 0}')


def cmd_perkey(a):
    c = {c["id"]: c for c in load_combos()}[a.combo]
    we = dt.date.fromisoformat(a.win_end)
    title = c.get("telltale_name") or c["id"]
    body, n, _ = perkey_body(c, a.win_start, a.win_end, a.all, "p", heading=True)
    parts = ['<!doctype html><html><head><meta charset="utf-8"><title>%s per key</title><style>%s%s</style></head><body><div class="viz-root">'
             % (html.escape(title), css(), PERKEY_CSS)] + body + ['<div id="tip"></div>%s</div></body></html>' % JS]
    rep = ROOT / "reports"
    rep.mkdir(exist_ok=True)
    out = rep / ("%s_%s_per_key.html" % (we - dt.timedelta(days=1), c["id"]))
    out.write_text("\n".join(parts))
    print("wrote", out.relative_to(ROOT), "(%d keys)" % n)


def perkey_body(c, win_start, win_end, all_keys, uid, heading=True):
    """-> (html parts, n keys, {key: status}) — per-key daily + hourly charts for one combo, no page wrapper."""
    names = json.loads(NAMES.read_text()) if NAMES.exists() else {}
    rows = read_counts(CHART_COUNTS)
    if not rows:
        sys.exit("data/chart_key_counts.csv is empty -- run 03_track_exact_day.sql with --keys and ingest --chart")
    ws, we = dt.date.fromisoformat(win_start), dt.date.fromisoformat(win_end)
    bs = ws - dt.timedelta(days=7)
    days = days_between(bs, we)
    win_days, base_days = days_between(ws, we), days_between(bs, ws)
    st = combo_stats(c["id"], rows, days, win_days, base_days)
    ver = defaultdict(dict)
    for r in rows:
        if r["combo_id"] == c["id"]:
            ver[r["public_key"]][r["day"]] = int(r.get("verified") or 0)
    hours, hourly = load_hourly(c["id"])
    cut = next((i for i, h in enumerate(hours) if h >= win_start), len(hours))  # hourly chart covers the window only
    hours, hourly = hours[cut:], {k: (cv[cut:], vv[cut:]) for k, (cv, vv) in hourly.items()}
    today, today_hour = load_today(c["id"], str(we))  # today so far (we = window end = today when run daily)
    # spiking in the window, or bursting today (>= ACTIVE_MIN so far and >= SPIKE_X x baseline) -- a key hit for the
    # first time today must still get a chart
    for k, (tc, tv) in today.items():
        if k not in st and tc >= ACTIVE_MIN:
            st[k] = {"series": [0] * len(days), "base": 0, "win": 0, "peak": 0, "spiking": False}
    today_burst = {k for k, (tc, tv) in today.items() if tc >= max(ACTIVE_MIN, SPIKE_X * st.get(k, {}).get("base", 0))}
    keys = [k for k in st if st[k]["spiking"] or k in today_burst] if not all_keys else [k for k in st if st[k]["peak"] >= ACTIVE_MIN or k in today_burst]
    cdays = days + ([str(we)] if today_hour else [])
    partial = ("so far, to %s:59 UTC" % today_hour) if today_hour else None
    zero = [0] * len(hours)
    status = {k: ongoing_status(hourly.get(k, (zero, zero))[0], st[k]["base"]) for k in keys}
    order = {"ongoing": 0, "elevated": 1, "subsided": 2, "no hourly data": 3}
    keys.sort(key=lambda k: (order[status[k][0]], -(st[k]["peak"] / max(st[k]["base"], 1))))
    title = c.get("telltale_name") or c["id"]
    parts = []
    if heading:
        parts.append("<h1>%s — per key</h1>" % html.escape(title))
    parts.append('<p class="muted">%s<br>Exact daily sessions per key carrying this combination, each chart on its own scale. '
                 '<b>Created</b> = sessions with the signal; <b>verified</b> = of those, sessions that ended verified '
                 '(<code>SESSIONS_VERIFIED &gt; 0</code>). A wide gap means the traffic is already being stopped; lines on top of each other mean it is getting through. '
                 'Daily chart: baseline %s → %s (dashed line = its daily mean), shaded window %s → %s, and %s as a hollow point. '
                 'Hourly chart: every hour from %s to the last complete hour; the shaded last 24h is what the status uses. '
                 'Hover for numbers. Ongoing keys first, then by peak ÷ baseline.</p>'
                 % (" + ".join("<code>%s</code>" % html.escape(f) for f in c["flags"]), bs, ws - dt.timedelta(days=1), ws, we - dt.timedelta(days=1),
                    ("today (%s, %s)" % (we, partial)) if partial else "today (no data yet)", hours[0] if hours else "–"))
    if hours:
        groups = defaultdict(list)
        for k in keys:
            groups[status[k][0]].append(k)
        def _l(ks):
            return ", ".join("%s (%s in last 24h vs %s/day)" % (html.escape(key_label(k, names)), fmt(status[k][1]), fmt(st[k]["base"])) for k in ks) or "none"
        parts.append('<div class="card"><b>Status as of %s:00 UTC</b> — sessions with the signal in the last 24 complete hours vs the key\'s baseline daily mean '
                     '(a rolling day, so daily-cycle attacks are not mistaken for finished)<br>'
                     '<b>Ongoing</b> (≥3× baseline): %s<br><b>Elevated</b> (1.5–3×): %s<br><b>Subsided</b>: %s</div>'
                     % (hours[-1], _l(groups["ongoing"]), _l(groups["elevated"]), _l(groups["subsided"])))
    parts.append('<div class="legend"><span class="lg"><i class="sw s1"></i>sessions created (signal fired)</span>'
                 '<span class="lg"><i class="sw s2"></i>sessions verified</span></div>')
    parts.append('<div class="kgrid">')
    for i, k in enumerate(keys):
        s = st[k]
        vser = [ver[k].get(d, 0) for d in days]
        wc = sum(s["series"][days.index(d)] for d in win_days)
        wv = sum(vser[days.index(d)] for d in win_days)
        vr = (100.0 * wv / wc) if wc else 0
        tag = "mostly blocked" if vr < 20 else ("partly blocked" if vr < 60 else "getting through")
        ratio = ("%.0f×" % (s["peak"] / s["base"])) if s["base"] >= 1 else "new (no baseline)"
        stats = "baseline %s/day · window %s/day · peak %s (%s)" % (fmt(s["base"]), fmt(s["win"]), fmt(s["peak"]), ratio)
        n = names.get(k, {})
        stt, rate = status[k]
        hc, hv = hourly.get(k, (zero, zero))
        last6 = sum(hc[-6:]) / 6.0 if hc else 0
        hourly_svg = ('<div class="sub">Hourly, %s → %s UTC (dashed = baseline hourly rate)</div>%s'
                      % (hours[0], hours[-1], svg_hourly(hours, hc, hv, s["base"], "%sh%d" % (uid, i)))) if hours else ""
        parts.append('<div class="kcard"><h3>%s<span class="tag %s">%s</span><span class="tag">%s</span></h3><div class="kstats">%s · <code>%s</code></div>'
                     '<div class="kstats">%s</div><div class="kstats">window verified: <b>%s of %s (%.0f%%)</b> · last 24h: <b>%s</b> · last 6h: %s/h vs baseline %s/h</div>%s%s</div>'
                     % (html.escape(key_label(k, names)), stt.split()[0], stt, tag, html.escape(n.get("account_name", "")), k, stats,
                        "{:,}".format(wv), "{:,}".format(wc), vr, fmt(rate), fmt(last6), fmt(s["base"] / 24),
                        svg_key_lines(cdays, s["series"] + ([today.get(k, [0, 0])[0]] if partial else []),
                                      vser + ([today.get(k, [0, 0])[1]] if partial else []), s["base"], str(ws), "%sp%d" % (uid, i), partial),
                        hourly_svg))
    parts.append('</div>')
    return parts, len(keys), {k: status[k] for k in keys}

RECUR_KEYS = ROOT / "data" / "recur_keys.json"  # {combo_id: [public_key, ...]} keys backfilled in chart_key_counts


def episodes_of(days, created, verified, med):
    """Burst day = >= ACTIVE_MIN sessions and >= SPIKE_X x the key's median day. Consecutive burst days = one episode."""
    thr = max(ACTIVE_MIN, SPIKE_X * med)
    eps, cur = [], None
    for i, d in enumerate(days):
        if created[i] >= thr:
            if cur and cur["end_i"] == i - 1:
                cur.update(end=d, end_i=i)
            else:
                cur = {"start": d, "end": d, "start_i": i, "end_i": i}
                eps.append(cur)
    for e in eps:
        sl = range(e["start_i"], e["end_i"] + 1)
        e["days"] = len(sl)
        e["peak"] = max(created[i] for i in sl)
        e["peak_day"] = days[max(sl, key=lambda i: created[i])]
        e["sessions"] = sum(created[i] for i in sl)
        e["verified"] = sum(verified[i] for i in sl)
    return eps, thr


def recurrence_data(start, end, today=None):
    """-> (days, {combo_id: [key row]}) burst episodes per combo x key (keys from data/recur_keys.json)."""
    keymap = json.loads(RECUR_KEYS.read_text())
    rows = read_counts(CHART_COUNTS)
    days = days_between(dt.date.fromisoformat(start), dt.date.fromisoformat(end))
    di = {d: i for i, d in enumerate(days)}
    result = {}
    for cid, keys in keymap.items():
        ser = {k: ([0] * len(days), [0] * len(days)) for k in keys}
        for r in rows:
            if r["combo_id"] == cid and r["public_key"] in ser and r["day"] in di:
                ser[r["public_key"]][0][di[r["day"]]] = int(r["sessions"])
                ser[r["public_key"]][1][di[r["day"]]] = int(r["verified"])
        tday = load_today(cid, today)[0] if today else {}
        krows = []
        for k in keys:
            cr, vr = ser[k]
            med = sorted(cr)[len(cr) // 2]
            eps, thr = episodes_of(days, cr, vr, med)
            t = tday.get(k, [0, 0])
            t_burst = bool(today) and t[0] >= thr
            starts = [dt.date.fromisoformat(e["start"]) for e in eps]
            gaps_d = [(b - x).days for x, b in zip(starts, starts[1:])]
            n = len(eps) + (1 if t_burst and not (eps and eps[-1]["end"] == days[-1]) else 0)
            kind = "recurring" if n >= 2 else "one-off" if n == 1 else "none"
            if sum(1 for v in cr if v >= ACTIVE_MIN) >= 0.6 * len(days):
                kind = "persistent" if n < 2 else kind
            krows.append({"key": k, "median": med, "threshold": thr, "episodes": eps, "gaps_days": gaps_d,
                          "today": t, "today_burst": t_burst, "n_episodes": n, "kind": kind, "created": cr, "verified": vr})
        krows.sort(key=lambda r: ({"recurring": 0, "persistent": 1, "one-off": 2, "none": 3}[r["kind"]], -max(r["created"])))
        result[cid] = krows
    return days, result


def recurrence_body(krows, days, today, names):
    """Heat table (each row on its own scale: shade = day / key's burst threshold) + episode list, no wrapper."""
    parts = []
    head = "".join('<th class="d">%s</th>' % d[5:].replace("-", "/") for d in days) + ('<th class="d">%s*</th>' % today[5:].replace("-", "/") if today else "")
    trs = []
    for r in krows:
        cells = []
        burst_i = {i for e in r["episodes"] for i in range(e["start_i"], e["end_i"] + 1)}
        vals = list(zip(r["created"], r["verified"])) + ([tuple(r["today"])] if today else [])
        for i, (cv, vv) in enumerate(vals):
            is_b = (i in burst_i) or (i == len(days) and r["today_burst"])
            lvl = 0 if cv < ACTIVE_MIN else min(4, 1 + int(3 * cv / (r["threshold"] * 3)))
            cls = ("b%d" % lvl) if is_b else ("h%d" % min(lvl, 1))
            tipd = days[i] if i < len(days) else today + " (so far)"
            cells.append('<td class="hm %s" data-tip="%s · %s created · %s verified (%s)">%s</td>'
                         % (cls, tipd, "{:,}".format(cv), "{:,}".format(vv), ("%d%%" % round(100 * vv / cv)) if cv else "–", fmt(cv) if cv >= 100 else ""))
        trs.append('<tr><td class="kn">%s<br><span class="muted">median %s/day · %s</span></td>%s</tr>'
                   % (html.escape(key_label(r["key"], names)), fmt(r["median"]), r["kind"], "".join(cells)))
    parts.append('<div class="scroll"><table class="heat"><tr><th>Key</th>%s</tr>%s</table></div>' % (head, "".join(trs)))
    ers = []
    for r in krows:
        for e in r["episodes"]:
            ers.append('<tr><td>%s</td><td>%s</td><td>%s</td><td class="n">%d</td><td class="n">%s</td><td class="n">%s</td><td class="n">%d%%</td></tr>'
                       % (html.escape(key_label(r["key"], names)), e["start"] + ("" if e["end"] == e["start"] else " → " + e["end"]),
                          DOW[dt.date.fromisoformat(e["start"]).weekday()], e["days"], fmt(e["peak"]), fmt(e["sessions"]),
                          round(100 * e["verified"] / max(e["sessions"], 1))))
        if r["today_burst"]:
            ers.append('<tr><td>%s</td><td>%s (today so far)</td><td>%s</td><td class="n">–</td><td class="n">%s</td><td class="n">%s</td><td class="n">%d%%</td></tr>'
                       % (html.escape(key_label(r["key"], names)), today, DOW[dt.date.fromisoformat(today).weekday()], fmt(r["today"][0]), fmt(r["today"][0]),
                          round(100 * r["today"][1] / max(r["today"][0], 1))))
    if ers:
        parts.append('<details><summary>Burst episodes (%d)</summary><table><tr><th>Key</th><th>Dates</th><th>Starts</th><th class="n">Days</th><th class="n">Peak day</th><th class="n">Episode sessions</th><th class="n">Verified</th></tr>%s</table></details>' % (len(ers), "".join(ers)))
    return parts


RECUR_INTRO = ('Every row is on its <b>own scale</b>: a day is a <b>burst</b> (coloured) when it has ≥%s sessions and ≥%d× that key\'s median day; '
               'back-to-back burst days are one episode. A key is <b>recurring</b> with ≥2 separate episodes, <b>persistent</b> when it sits ≥%s on most days. '
               'Hover a cell for created / verified.')


def save_recurrence_json(result, tag):
    js = {cid: [{k: v for k, v in r.items() if k not in ("created", "verified")} | {"episodes": [{k: v for k, v in e.items() if not k.endswith("_i")} for e in r["episodes"]]}
                for r in krows] for cid, krows in result.items()}
    (ROOT / "data" / ("recurrence_%s.json" % tag)).write_text(json.dumps(js, indent=1))


def cmd_recurrence(a):
    """Per combo x key: daily history (data/chart_key_counts.csv, keys in data/recur_keys.json),
    burst episodes and whether they repeat. Optional --today adds today-so-far from the hourly file."""
    combos = {c["id"]: c for c in load_combos()}
    names = json.loads(NAMES.read_text()) if NAMES.exists() else {}
    days, result = recurrence_data(a.start, a.end, a.today)
    have = {r["day"] for r in read_counts(CHART_COUNTS)}
    gaps = [d for d in days if d not in have]
    parts, srows = [], []
    for cid, krows in result.items():
        c = combos[cid]
        title = c.get("telltale_name") or cid
        nrec = sum(1 for r in krows if r["kind"] == "recurring")
        parts.append('<div class="card"><h2>%s <span class="muted" style="font-size:12px;font-weight:400">[%s]</span></h2>' % (html.escape(title), c["status"]))
        parts.append('<p class="muted">%s</p>' % " + ".join("<code>%s</code>" % html.escape(f) for f in c["flags"]))
        parts.append('<div class="tiles"><div class="tile"><b>%d / %d</b><span>keys with ≥2 separate bursts</span></div>'
                     '<div class="tile"><b>%d</b><span>burst episodes in %d days</span></div></div>'
                     % (nrec, len(krows), sum(r["n_episodes"] for r in krows), len(days) + (1 if a.today else 0)))
        parts += recurrence_body(krows, days, a.today, names)
        parts.append("</div>")
        rec = [r for r in krows if r["kind"] == "recurring"]
        srows.append('<tr><td>%s</td><td>%s</td><td class="n">%d</td><td class="n">%d</td><td class="n">%d</td><td>%s</td></tr>'
                     % (html.escape(title), c["status"], len(krows), len(rec), sum(r["n_episodes"] for r in krows),
                        html.escape(", ".join(key_label(r["key"], names) for r in rec[:4]) + (" …" if len(rec) > 4 else ""))))
    head = ['<!doctype html><html><head><meta charset="utf-8"><title>Recurrence %s → %s</title><style>%s%s</style></head><body><div class="viz-root">'
            % (a.start, a.end, css(), RECUR_CSS),
            "<h1>Do these attacks come back?</h1>",
            '<p class="muted">Daily sessions per key for each tracked combination, %s → %s%s (UTC, exact counts on the keys each combination spiked on). %s Generated %s.</p>'
            % (days[0], days[-1], (" plus %s so far (*)" % a.today) if a.today else "", RECUR_INTRO % (fmt(ACTIVE_MIN), SPIKE_X, fmt(ACTIVE_MIN)),
               dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC"))]
    if gaps:
        head.append('<p class="muted"><b>Missing days:</b> %s</p>' % ", ".join(gaps))
    head.append('<div class="card"><h2>Summary</h2><table><tr><th>Combination</th><th>Status</th><th class="n">Keys</th><th class="n">Recurring keys</th><th class="n">Episodes</th><th>Recurring on</th></tr>%s</table></div>' % "".join(srows))
    out = ROOT / "reports" / ("recurrence_%s.html" % (a.today or days[-1]))
    out.write_text("\n".join(head + parts) + '<div id="tip"></div>%s</div></body></html>' % JS)
    save_recurrence_json(result, a.today or days[-1])
    print("wrote", out.relative_to(ROOT))


DOW = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
RECUR_CSS = """
.scroll{overflow-x:auto}.heat{width:auto}.heat th.d{font-size:10px;font-weight:400;color:var(--text-muted);padding:2px;text-align:center;writing-mode:vertical-rl;transform:rotate(180deg)}
.heat td.kn{white-space:nowrap;font-size:12px;padding-right:12px}.heat td.hm{min-width:30px;height:28px;padding:0 2px;text-align:center;font-size:10px;border:2px solid var(--surface-2);border-radius:4px;font-variant-numeric:tabular-nums}
.hm.h0{background:transparent;color:var(--text-muted)}.hm.h1{background:var(--grid);color:var(--text-secondary)}
.hm.b1{background:color-mix(in srgb,var(--series-2) 35%,transparent)}.hm.b2{background:color-mix(in srgb,var(--series-2) 60%,transparent)}
.hm.b3{background:color-mix(in srgb,var(--series-2) 85%,transparent);color:#fff}.hm.b4{background:var(--series-2);color:#fff;font-weight:600}
"""


SOC_CSS = """
.toc td a{color:var(--text-primary)}.pill{display:inline-block;font-size:11px;padding:1px 8px;border-radius:10px;border:1px solid var(--grid);margin-left:6px;vertical-align:middle;color:var(--text-secondary)}
.pill.create{background:var(--series-2);border-color:var(--series-2);color:#fff;font-weight:600}.pill.keep{background:var(--series-1);border-color:var(--series-1);color:#fff;font-weight:600}
.action{border-left:4px solid var(--series-2);padding:8px 14px;background:var(--surface-1);border-radius:4px;margin:10px 0;font-size:13px}
.action.keep{border-left-color:var(--series-1)}.action.hold{border-left-color:var(--text-muted)}
.flags li{font-size:13px;margin:2px 0}.sec{border-top:1px solid var(--grid);margin-top:22px;padding-top:6px}
section.combo{background:var(--surface-2);border-radius:10px;padding:18px 22px;margin:22px 0}
section.combo .card{background:var(--surface-1);font-size:13px;line-height:1.5}section.combo .kcard{background:var(--surface-1)}
@media print{.scroll{overflow:visible}details{display:block}section.combo{break-before:page}}
"""
ACTION_ORDER = {"keep": 0, "create": 1, "hold": 2}


def _akind(action):
    return "keep" if action.startswith("keep") else "create" if action.startswith("create") else "hold"


def cmd_soc(a):
    """One self-contained HTML for SOC: action summary, then per TT combination its signals, TT definition,
    status now, recurrence table and per-key created-vs-verified time series."""
    combos = load_combos()
    names = json.loads(NAMES.read_text()) if NAMES.exists() else {}
    ws, we = dt.date.fromisoformat(a.win_start), dt.date.fromisoformat(a.win_end)
    today = str(we)
    rdays, recur = recurrence_data(a.recur_start, a.win_end, today)
    save_recurrence_json(recur, today)
    combos.sort(key=lambda c: ACTION_ORDER[_akind(c.get("action", "hold"))])
    sections, srows = [], []
    for ci, c in enumerate(combos):
        title = c.get("telltale_name") or c["id"]
        anchor = "tt-%s" % c["id"]
        ak = _akind(c.get("action", "hold"))
        body, nkeys, status = perkey_body(c, a.win_start, a.win_end, False, "c%d" % ci, heading=False)
        krows = recur.get(c["id"], [])
        rec = [r for r in krows if r["kind"] == "recurring"]
        ongoing = [k for k, v in status.items() if v[0] == "ongoing"]
        srows.append('<tr><td><a href="#%s">%s</a></td><td>%s</td><td><span class="pill %s">%s</span></td><td class="n">%d</td><td class="n">%d / %d</td><td>%s</td></tr>'
                     % (anchor, html.escape(title), c["status"], ak, html.escape(c.get("action", "")), nkeys, len(rec), len(krows),
                        html.escape(", ".join(key_label(k, names) for k in ongoing)) or '<span class="muted">none</span>'))
        defn = tt_definition(c)
        meta = None
        if c.get("draft") and (ROOT / c["draft"]).exists():
            meta = json.loads((ROOT / c["draft"]).read_text())
            defn = meta.get("telltale_definition", meta)
        sec = ['<section class="combo" id="%s"><h2 style="margin-top:0">%d. %s <span class="pill">%s</span><span class="pill %s">%s</span></h2>'
               % (anchor, ci + 1, html.escape(title), c["status"], ak, html.escape(c.get("action", "")))]
        sec.append('<div class="action %s"><b>Action:</b> %s</div>' % (ak, html.escape(c.get("action_detail", ""))))
        if c.get("history_note"):
            sec.append('<p class="muted"><b>Data note:</b> %s</p>' % html.escape(c["history_note"]))
        sec.append('<h3>Signal combination (all must be present on the session)</h3><ul class="flags">%s</ul>'
                   % "".join("<li><code>%s</code></li>" % html.escape(f) for f in c["flags"]))
        if meta:
            where = ("<b>live in Dataswan</b> (id %s, created %s)" % (c["dataswan_id"], c.get("created", "–"))) if c.get("dataswan_id") else "not created in Dataswan"
            sec.append('<p class="muted">%s: location <b>%s</b> · type %s · cohort %s · ticket %s · %s · %s.</p>'
                       % (("Definition" if c.get("dataswan_id") else "Draft",) + tuple(html.escape(str(meta.get(k, "–"))) for k in ("location", "telltale_type", "cohort_category", "ticket", "_validated")) + (where,)))
        sec.append('<details%s><summary>Telltale definition JSON</summary><pre>%s</pre></details>'
                   % ("" if c["status"] == "live" else " open", html.escape(json.dumps(defn, indent=2))))
        sec.append('<h3 class="sec">Does it come back? Daily bursts per key, %s → %s</h3>' % (rdays[0], today))
        sec.append('<p class="muted">%d of %d keys had ≥2 separate bursts, %d episodes in total. %s</p>'
                   % (len(rec), len(krows), sum(r["n_episodes"] for r in krows), RECUR_INTRO % (fmt(ACTIVE_MIN), SPIKE_X, fmt(ACTIVE_MIN))))
        sec += recurrence_body(krows, rdays, today, names) if krows else ['<p class="muted">No backfilled history for this combination.</p>']
        sec.append('<h3 class="sec">Is it still going on? Per-key time series (%d spiking keys)</h3>' % nkeys)
        sec += body
        sec.append("</section>")
        sections.append("\n".join(sec))
    gen = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    head = ['<!doctype html><html><head><meta charset="utf-8"><title>Spike scan — SOC action pack %s</title><style>%s%s%s%s</style></head><body><div class="viz-root">'
            % (today, css(), PERKEY_CSS, RECUR_CSS, SOC_CSS),
            "<h1>Spike scan — telltale action pack</h1>",
            '<p class="muted">Generated %s. Scan window <b>%s → %s</b> vs 7-day baseline; history back to <b>%s</b> for recurrence; today (%s) so far from hourly data. '
            'Exact session counts from <code>ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY</code> (Production keys). '
            '<b>Created</b> = sessions carrying the signal combination; <b>verified</b> = of those, sessions that ended verified — a wide gap means it is being stopped, '
            'lines on top of each other mean it is getting through.</p>' % (gen, ws, we - dt.timedelta(days=1), rdays[0], today),
            '<div class="card"><h2 style="margin-top:0">What to do</h2><table class="toc"><tr><th>Telltale</th><th>Status</th><th>Action</th><th class="n">Spiking keys</th>'
            '<th class="n">Recurring keys</th><th>Ongoing now (last 24h ≥3× baseline)</th></tr>%s</table></div>' % "".join(srows)]
    if a.summary:
        sm = json.loads(pathlib.Path(a.summary).read_text())
        head.insert(3, '<div class="card"><h2 style="margin-top:0">%s</h2>%s</div>' % (html.escape(sm["title"]), "".join(
            '<h3>%s</h3><ul>%s</ul>' % (html.escape(x["h"]), "".join("<li>%s</li>" % html.escape(i) for i in x["items"])) for x in sm["sections"])))
    disc = json.loads(pathlib.Path(a.discovery).read_text()) if a.discovery else None
    tail = []
    if disc:
        drows = "".join('<tr><td>%s</td><td class="n">%s</td><td>%s</td></tr>'
                        % ("<br>".join(html.escape(f) for f in d["combo"].split(" + ")), d["keys_spiking"], html.escape(d.get("note", "")))
                        for d in disc.get("combos", []))
        tail.append('<section class="combo"><h2 style="margin-top:0">Appendix — how these were found</h2><p class="muted">%s</p>'
                    '<table><tr><th>Combination</th><th class="n">Keys spiking</th><th>Note</th></tr>%s</table></section>' % (html.escape(disc.get("summary", "")), drows))
    out = ROOT / "reports" / ("soc_%s.html" % today)
    doc = "\n".join(head + sections + tail) + '<div id="tip"></div>%s</div></body></html>' % JS
    out.write_text(doc)
    (ROOT / "reports" / "soc_latest.html").write_text(doc)
    print("wrote", out.relative_to(ROOT), "and reports/soc_latest.html")


def main():
    p = argparse.ArgumentParser()
    sp = p.add_subparsers(dest="cmd", required=True)
    i = sp.add_parser("ingest"); i.add_argument("--day", required=True); i.add_argument("--packed", required=True)
    i.add_argument("--add", action="store_true", help="sum into the day's existing rows (second 12h half)")
    i.add_argument("--chart", action="store_true", help="store in data/chart_key_counts.csv (query rendered with --keys)")
    i.add_argument("--combos", help="combos file the query was rendered with (a subset of combos.json: only those combos' rows are replaced)")
    k = sp.add_parser("keys"); k.add_argument("--names", required=True)
    m = sp.add_parser("missing"); m.add_argument("--since", required=True)
    r = sp.add_parser("report"); r.add_argument("--win-start", required=True); r.add_argument("--win-end", required=True); r.add_argument("--discovery")
    hr = sp.add_parser("hourly"); hr.add_argument("--day", required=True); hr.add_argument("--packed", required=True)
    hr.add_argument("--combos", help="combos file the query was rendered with (subset of combos.json)")
    hr.add_argument("--hours", help="the --hours slice the query was rendered with (only those hours are replaced)")
    pk = sp.add_parser("perkey"); pk.add_argument("--combo", required=True); pk.add_argument("--win-start", required=True)
    pk.add_argument("--win-end", required=True); pk.add_argument("--all", action="store_true", help="every key with a >=1k day, not just spiking")
    rc = sp.add_parser("recurrence"); rc.add_argument("--start", required=True); rc.add_argument("--end", required=True, help="exclusive")
    rc.add_argument("--today", help="also show this (partial) day from data/hourly_key_counts.csv")
    so = sp.add_parser("soc"); so.add_argument("--win-start", required=True); so.add_argument("--win-end", required=True, help="today (exclusive end of full days)")
    so.add_argument("--recur-start", required=True, help="first day of the recurrence history"); so.add_argument("--discovery")
    so.add_argument("--summary", help="JSON {title, sections: [{h, items: [text]}]} shown as a card above the action table")
    a = p.parse_args()
    {"ingest": cmd_ingest, "keys": cmd_keys, "missing": cmd_missing, "report": cmd_report, "perkey": cmd_perkey, "hourly": cmd_hourly, "recurrence": cmd_recurrence, "soc": cmd_soc}[a.cmd](a)


if __name__ == "__main__":
    main()
