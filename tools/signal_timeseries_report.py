#!/usr/bin/env python3
"""Render a SOC-pack-style HTML report: per-signal, per-key daily sessions created vs verified.

Zero-dependency. Inputs:
  --data    CSV with columns signal,key,date,created,verified[,firefox]  (one row per signal/key/day)
  --spec    JSON with report title, key names and per-signal metadata (title, verdict, telltale drafts, markers)
  --days    how many days back from --end to chart (default 45)
  --end     last full day to include, YYYY-MM-DD (default: latest date in the data, minus the partial day)
  --out     output HTML path

A day is a *burst* when created >= max(--burst-min, --burst-mult x that key's median day); back-to-back
burst days are one episode. Episodes are shaded on the chart and listed under it.
"""
import argparse
import csv
import datetime as dt
import html
import json
import statistics
from collections import defaultdict

CSS = """
.viz-root{color-scheme:light;--surface-1:#fcfcfb;--surface-2:#f2f1ee;--text-primary:#0b0b0b;--text-secondary:#52514e;--text-muted:#77766f;--grid:#e4e3df;--win:#f3ece4;
--series-1:#2a78d6;--series-2:#eb6834;--series-3:#1baf7a;--series-4:#eda100;--series-8:#e34948;}
@media (prefers-color-scheme: dark){:root:where(:not([data-theme="light"])) .viz-root{color-scheme:dark;--surface-1:#1a1a19;--surface-2:#242422;--text-primary:#f0efec;--text-secondary:#c3c2b7;--text-muted:#9a998f;--grid:#33332f;--win:#2b2620;
--series-1:#3987e5;--series-2:#d95926;--series-3:#199e70;--series-4:#c98500;--series-8:#e66767;}}
body{margin:0;font-family:Outfit,system-ui,sans-serif}
.viz-root{background:var(--surface-1);color:var(--text-primary);padding:24px 32px;min-height:100vh}
h1{font-size:22px;margin:0 0 4px}h2{font-size:17px;margin:28px 0 4px}h3{font-size:14px;margin:16px 0 6px;color:var(--text-secondary)}
p,li,td,th{font-size:13px;line-height:1.5}.muted{color:var(--text-secondary)}
.card{background:var(--surface-2);border-radius:8px;padding:16px 20px;margin:14px 0}
.tiles{display:flex;gap:28px;flex-wrap:wrap;margin:8px 0}.tile b{display:block;font-size:26px}.tile span{font-size:12px;color:var(--text-secondary)}
.grid2{display:grid;grid-template-columns:repeat(auto-fit,minmax(460px,1fr));gap:18px}
.chart{width:100%;height:auto}.grid{stroke:var(--grid);stroke-width:1}.axis{fill:var(--text-muted);font-size:11px}
.win{fill:var(--win)}.line{fill:none;stroke-width:2}.line.s1{stroke:var(--series-1)}.line.s2{stroke:var(--series-2)}
.line.s3{stroke:var(--series-3);stroke-dasharray:4 3;stroke-width:1.5}
.mark{stroke:var(--series-8);stroke-width:1.5;stroke-dasharray:3 3}.marktxt{fill:var(--series-8);font-size:10px}
.hit{fill:transparent}.hit:hover{fill:var(--grid);opacity:.5}
.legend{display:flex;flex-wrap:wrap;gap:6px 16px;margin:6px 0}.lg{font-size:12px;color:var(--text-secondary);display:flex;align-items:center;gap:6px}
.sw{width:10px;height:10px;border-radius:2px;display:inline-block}.sw.s1{background:var(--series-1)}.sw.s2{background:var(--series-2)}
.sw.s3{background:var(--series-3)}.sw.win{background:var(--win);border:1px solid var(--grid)}
.eps{margin:4px 0 8px;padding-left:18px}.eps li{font-size:12px;margin:2px 0}
table{border-collapse:collapse;width:100%}th,td{text-align:left;padding:4px 8px;border-bottom:1px solid var(--grid);vertical-align:top}
td.n,th.n{text-align:right;font-variant-numeric:tabular-nums}
pre{background:var(--surface-1);border-radius:6px;padding:10px 12px;font-size:12px;overflow:auto;white-space:pre-wrap}
.pill{display:inline-block;font-size:11px;padding:1px 8px;border-radius:10px;background:var(--grid);margin-left:6px}
.pill.bad{background:var(--series-8);color:#fff}.pill.watch{background:var(--series-4);color:#000}
code{font-size:12px}
"""


def fmt(n):
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if n >= 1000:
        return f"{n / 1000:.1f}k"
    return str(int(n))


def nice_max(v):
    if v <= 0:
        return 10
    for m in (1, 2, 2.5, 5, 10):
        step = m * 10 ** (len(str(int(v))) - 1)
        if step >= v:
            return step
    return v


def episodes(days, created, mult, minimum):
    med = statistics.median(created) if created else 0
    thr = max(minimum, mult * med)
    eps, cur = [], None
    for i, c in enumerate(created):
        if c >= thr:
            cur = [i, i] if cur is None else [cur[0], i]
        elif cur is not None:
            eps.append(cur)
            cur = None
    if cur is not None:
        eps.append(cur)
    return eps, med, thr


def chart(days, created, verified, extra, eps, markers, title):
    W, H, L, R, T, B = 520, 170, 48, 12, 14, 26
    pw, ph = W - L - R, H - T - B
    ymax = nice_max(max(created + [1]))
    n = len(days)
    x = lambda i: L + (pw * i / max(n - 1, 1))
    y = lambda v: T + ph - ph * v / ymax
    out = [f'<svg viewBox="0 0 {W} {H}" class="chart" role="img"><title>{html.escape(title)}</title>']
    half = pw / max(n - 1, 1) / 2
    for a, b in eps:
        out.append(f'<rect x="{x(a) - half:.1f}" y="{T}" width="{x(b) - x(a) + 2 * half:.1f}" height="{ph}" class="win"/>')
    for frac in (0, 0.5, 1):
        yy = y(ymax * frac)
        out.append(f'<line x1="{L}" x2="{W - R}" y1="{yy:.1f}" y2="{yy:.1f}" class="grid"/>')
        out.append(f'<text x="{L - 6}" y="{yy + 4:.1f}" class="axis" text-anchor="end">{fmt(ymax * frac)}</text>')
    step = max(1, n // 7)
    for i in range(0, n, step):
        out.append(f'<text x="{x(i):.1f}" y="{H - 8}" class="axis" text-anchor="middle">{days[i].strftime("%m-%d")}</text>')
    for label, d in markers:
        if d in days:
            i = days.index(d)
            out.append(f'<line x1="{x(i):.1f}" x2="{x(i):.1f}" y1="{T}" y2="{T + ph}" class="mark"/>')
            anchor = "end" if x(i) > W - 120 else "start"
            dx = -3 if anchor == "end" else 3
            out.append(f'<text x="{x(i) + dx:.1f}" y="{T + 10}" class="marktxt" text-anchor="{anchor}">{html.escape(label)}</text>')

    def poly(vals, cls):
        pts = " ".join(f"{x(i):.1f},{y(v):.1f}" for i, v in enumerate(vals))
        return f'<polyline points="{pts}" class="line {cls}"/>'

    if extra is not None:
        out.append(poly(extra, "s3"))
    out.append(poly(created, "s1"))
    out.append(poly(verified, "s2"))
    for i, d in enumerate(days):
        tip = f"{d:%Y-%m-%d}: created {created[i]}, verified {verified[i]}"
        if extra is not None:
            tip += f", firefox {extra[i]}"
        out.append(f'<rect x="{x(i) - half:.1f}" y="{T}" width="{2 * half:.1f}" height="{ph}" class="hit"><title>{tip}</title></rect>')
    out.append("</svg>")
    return "".join(out)


def tt_block(tt):
    rows = [
        ("Name", f"<code>{html.escape(tt['telltale_name'])}</code>"),
        ("Type / location / cohort", "suspicion_flags · SESSION_SETUP · Suspicious"),
        ("Risk category / owner", f"CUSTOM · User · {html.escape(tt.get('owner', ''))}"),
        ("Ticket", html.escape(tt.get("ticket", ""))),
        ("Description (internal)", html.escape(tt["telltale_description"])),
        ("External description", html.escape(tt["external_description"])),
    ]
    body = "".join(f"<tr><th>{k}</th><td>{v}</td></tr>" for k, v in rows)
    defn = html.escape(json.dumps(tt["telltale_definition"], indent=2))
    return f'<table>{body}</table><h3>Telltale definition JSON</h3><pre>{defn}</pre>'


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--data", required=True)
    ap.add_argument("--spec", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--days", type=int, default=45)
    ap.add_argument("--end")
    ap.add_argument("--burst-mult", type=float, default=3.0)
    ap.add_argument("--burst-min", type=int, default=50)
    a = ap.parse_args()

    spec = json.load(open(a.spec))
    series = defaultdict(dict)
    for r in csv.DictReader(open(a.data)):
        d = dt.date.fromisoformat(r["date"])
        series[(r["signal"], r["key"])][d] = (int(r["created"]), int(r["verified"]), int(r.get("firefox") or 0))
    latest = max(d for s in series.values() for d in s)
    end = dt.date.fromisoformat(a.end) if a.end else latest - dt.timedelta(days=1)
    days = [end - dt.timedelta(days=i) for i in range(a.days - 1, -1, -1)]

    parts = [f'<!doctype html><html><head><meta charset="utf-8"><title>{html.escape(spec["title"])}</title>'
             f"<style>{CSS}</style></head><body><div class=\"viz-root\">",
             f'<h1>{html.escape(spec["title"])}</h1>',
             f'<p class="muted">{html.escape(spec["subtitle"])} Window {days[0]} → {days[-1]} ({a.days} days). '
             f'<b>Created</b> = sessions carrying the signal; <b>verified</b> = of those, sessions that ended verified. '
             f'Lines on top of each other mean it is getting through. Shaded = burst day '
             f'(≥{a.burst_min} and ≥{a.burst_mult:g}× that key\'s median day).</p>']

    summary = ['<div class="card"><h3>Signals</h3><table><tr><th>Signal</th><th>Verdict</th>'
               '<th class="n">Created</th><th class="n">Verified</th><th class="n">Last 7d</th><th>Proposed suspicion flag(s)</th></tr>']
    sections = []
    for sig in spec["signals"]:
        sid = sig["id"]
        tot_c = tot_v = last7 = 0
        charts = []
        for key in sig["keys"]:
            s = series.get((sid, key), {})
            created = [s.get(d, (0, 0, 0))[0] for d in days]
            verified = [s.get(d, (0, 0, 0))[1] for d in days]
            extra = [s.get(d, (0, 0, 0))[2] for d in days] if sig.get("show_firefox") else None
            if sum(created) == 0:
                continue
            tot_c += sum(created)
            tot_v += sum(verified)
            last7 += sum(created[-7:])
            eps, med, _ = episodes(days, created, a.burst_mult, a.burst_min)
            markers = [(m["label"], dt.date.fromisoformat(m["date"])) for m in sig.get("markers", [])]
            ep_li = "".join(
                f"<li>{days[x0]:%b %d}{'' if x0 == x1 else ' – ' + days[x1].strftime('%b %d')}: "
                f"{fmt(sum(created[x0:x1 + 1]))} created, "
                f"{round(100 * sum(verified[x0:x1 + 1]) / max(sum(created[x0:x1 + 1]), 1))}% verified</li>"
                for x0, x1 in eps) or "<li>no burst days — steady low-and-slow</li>"
            vpct = round(100 * sum(verified) / sum(created))
            charts.append(
                f'<div class="card"><h3>{html.escape(spec["keys"][key])}</h3>'
                f'<div class="tiles"><div class="tile"><b>{fmt(sum(created))}</b><span>created</span></div>'
                f'<div class="tile"><b>{vpct}%</b><span>verified</span></div>'
                f'<div class="tile"><b>{sum(1 for c in created if c)}</b><span>active days</span></div>'
                f'<div class="tile"><b>{fmt(max(created))}</b><span>peak day · median {fmt(med)}</span></div>'
                f'<div class="tile"><b>{fmt(sum(created[-7:]))}</b><span>last 7 days</span></div></div>'
                + chart(days, created, verified, extra, eps, markers, f"{sid} {key} daily created vs verified")
                + f'<ul class="eps">{ep_li}</ul></div>')
        pill = {"missed": "bad", "watch": "watch"}.get(sig["verdict"], "")
        summary.append(
            f'<tr><td><a href="#{sid}">{html.escape(sig["title"])}</a></td><td><span class="pill {pill}">{sig["verdict"]}</span></td>'
            f'<td class="n">{fmt(tot_c)}</td><td class="n">{round(100 * tot_v / max(tot_c, 1))}%</td><td class="n">{fmt(last7)}</td>'
            f'<td>{"<br>".join("<code>" + html.escape(t["telltale_name"]) + "</code>" for t in sig["telltales"])}</td></tr>')
        legend = ('<div class="legend"><span class="lg"><i class="sw s1"></i>created</span>'
                  '<span class="lg"><i class="sw s2"></i>verified</span>'
                  + ('<span class="lg"><i class="sw s3"></i>Firefox variant (already caught by the invalid-resolution pair)</span>'
                     if sig.get("show_firefox") else "")
                  + '<span class="lg"><i class="sw win"></i>burst day</span></div>')
        tts = "".join(f'<div class="card">{tt_block(t)}</div>' for t in sig["telltales"])
        sections.append(
            f'<h2 id="{sid}">{html.escape(sig["title"])} <span class="pill {pill}">{sig["verdict"]}</span></h2>'
            f'<p>{html.escape(sig["why"])}</p>{legend}<div class="grid2">{"".join(charts)}</div>'
            f'<h3>Suspicion flag(s) to create — validated with validate_telltale, not created</h3>{tts}')
    summary.append("</table></div>")
    parts += summary + sections + ["</div></body></html>"]
    open(a.out, "w").write("".join(parts))
    print(f"wrote {a.out}: {len(spec['signals'])} signals, {days[0]} → {days[-1]}")


if __name__ == "__main__":
    main()
