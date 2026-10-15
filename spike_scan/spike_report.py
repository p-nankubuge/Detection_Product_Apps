#!/usr/bin/env python3
"""Spike-scan bookkeeping + report generator (stdlib only).

  ingest  --day YYYY-MM-DD --packed '<cell from 03_track_exact_day.sql>'
          Replaces that day's rows in data/daily_key_counts.csv (long format:
          day,public_key,key_total,combo_id,sessions). c<i> maps to combos.json combos[i].
  keys    --names keynames.json   merge {public_key: {key_name, account_name}} into data/key_names.json
  missing --since YYYY-MM-DD      print UTC days with no rows yet (yesterday is the last full day)
  report  --win-start D --win-end D [--discovery discovery.json]
          Writes reports/<win-end - 1 day>.html and reports/latest.html.
"""
import argparse, csv, datetime as dt, html, json, pathlib, sys
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parent
COUNTS = ROOT / "data" / "daily_key_counts.csv"
NAMES = ROOT / "data" / "key_names.json"
COMBOS = ROOT / "combos.json"
FIELDS = ["day", "public_key", "key_total", "combo_id", "sessions"]

# A key counts as "hit" by a combo on a day when it has >= this many exact sessions.
ACTIVE_MIN = 1000
# ...and as "spiking" when that day is >= SPIKE_X times its baseline daily mean (min ACTIVE_MIN).
SPIKE_X = 3


def load_combos():
    return json.loads(COMBOS.read_text())["combos"]


def read_counts():
    if not COUNTS.exists():
        return []
    with COUNTS.open() as f:
        return list(csv.DictReader(f))


def write_counts(rows):
    COUNTS.parent.mkdir(parents=True, exist_ok=True)
    rows.sort(key=lambda r: (r["day"], r["combo_id"], r["public_key"]))
    with COUNTS.open("w", newline="") as f:
        w = csv.DictWriter(f, FIELDS)
        w.writeheader()
        w.writerows(rows)


def cmd_ingest(a):
    combos = load_combos()
    new = []
    packed = a.packed.strip()
    for chunk in filter(None, packed.split(";")):
        parts = chunk.split(",")
        if len(parts) != 2 + len(combos):
            sys.exit("chunk has %d fields, expected %d (combos.json changed since the query was rendered?): %s"
                     % (len(parts), 2 + len(combos), chunk))
        key, tot, vals = parts[0], parts[1], parts[2:]
        for c, v in zip(combos, vals):
            if int(v) > 0:
                new.append({"day": a.day, "public_key": key, "key_total": tot,
                            "combo_id": c["id"], "sessions": v})
    rows = [r for r in read_counts() if r["day"] != a.day] + new
    write_counts(rows)
    print("ingested %d rows for %s (%d keys)" % (len(new), a.day, len(packed.split(";")) if packed else 0))


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


def svg_stacked(days, stats, names, win_start, uid):
    """Stacked bars: daily sessions by key, top keys by window volume + Other."""
    ranked = sorted(stats, key=lambda k: (-stats[k]["spiking"], -stats[k]["win"]))
    top = ranked[:TOP_KEYS]
    other = [sum(stats[k]["series"][i] for k in ranked[TOP_KEYS:]) for i in range(len(days))]
    layers = [(key_label(k, names), stats[k]["series"], "c%d" % j) for j, k in enumerate(top)]
    if any(other):
        layers.append(("Other (%d keys)" % (len(ranked) - TOP_KEYS), other, "cother"))
    totals = [sum(l[1][i] for l in layers) for i in range(len(days))]
    W, H, L, R, T, B = 640, 260, 52, 16, 16, 30
    pw, ph = W - L - R, H - T - B
    ymax = max(totals + [1]) * 1.1
    bw = pw / len(days)
    x = lambda i: L + bw * i
    y = lambda v: T + ph - ph * v / ymax
    out = ['<svg viewBox="0 0 %d %d" class="chart" role="img" aria-labelledby="%s-t">' % (W, H, uid),
           '<title id="%s-t">Daily sessions by key</title>' % uid]
    wi = days.index(win_start) if win_start in days else None
    if wi is not None:
        out.append('<rect x="%.1f" y="%d" width="%.1f" height="%d" class="win"/>' % (x(wi), T, W - R - x(wi), ph))
    for f in (0, .25, .5, .75, 1):
        v = ymax / 1.1 * f
        out.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" class="grid"/>' % (L, W - R, y(v), y(v)))
        out.append('<text x="%d" y="%.1f" class="axis" text-anchor="end">%s</text>' % (L - 6, y(v) + 4, fmt(v)))
    for i, d in enumerate(days):
        base = 0
        for name, vals, cls in layers:
            v = vals[i]
            if v <= 0:
                continue
            y0, y1 = y(base), y(base + v)
            hgt = max(y0 - y1 - 2, 0.5)  # 2px surface gap between stacked segments
            out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" class="seg %s" data-tip="%s · %s · %s sessions"/>'
                       % (x(i) + bw * 0.18, y1, bw * 0.64, hgt, cls, html.escape(name), d, "{:,}".format(v)))
            base += v
        if i % 2 == 0 or i == len(days) - 1:
            out.append('<text x="%.1f" y="%d" class="axis" text-anchor="middle">%s</text>' % (x(i) + bw / 2, H - 10, d[5:]))
    out.append("</svg>")
    legend = "".join('<span class="lg"><i class="sw %s"></i>%s</span>' % (cls, html.escape(n)) for n, _, cls in layers)
    return "\n".join(out), '<div class="legend">%s</div>' % legend


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
        bars, legend = svg_stacked(days, st, names, str(ws), "b%d" % ci)
        parts.append('<div class="grid2"><div><h3>How many keys this signal applies to, per day</h3>'
                     '<div class="legend"><span class="lg"><i class="sw s1"></i>hit (≥%s sessions)</span><span class="lg"><i class="sw s2"></i>spiking (≥%d× baseline)</span></div>%s</div>'
                     '<div><h3>Daily sessions by key</h3>%s%s</div></div>' % (fmt(ACTIVE_MIN), SPIKE_X, line, legend, bars))
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
    name = str(we - dt.timedelta(days=1))
    (rep / ("%s.html" % name)).write_text(out)
    (rep / "latest.html").write_text(out)
    print("wrote reports/%s.html and reports/latest.html" % name)


def main():
    p = argparse.ArgumentParser()
    sp = p.add_subparsers(dest="cmd", required=True)
    i = sp.add_parser("ingest"); i.add_argument("--day", required=True); i.add_argument("--packed", required=True)
    k = sp.add_parser("keys"); k.add_argument("--names", required=True)
    m = sp.add_parser("missing"); m.add_argument("--since", required=True)
    r = sp.add_parser("report"); r.add_argument("--win-start", required=True); r.add_argument("--win-end", required=True); r.add_argument("--discovery")
    a = p.parse_args()
    {"ingest": cmd_ingest, "keys": cmd_keys, "missing": cmd_missing, "report": cmd_report}[a.cmd](a)


if __name__ == "__main__":
    main()
