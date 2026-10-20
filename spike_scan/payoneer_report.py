#!/usr/bin/env python3
"""Payoneer deep-dive: per-key time series for two candidate signals, with the key's own traffic as a
circadian reference, so a low-and-slow attack can be told apart from organic day/night traffic.

Inputs (data/payoneer/, rows "key8,ts,hl,hl_verified,dp,dp_verified"; totals "key8,ts,sessions,verified"):
  signal_daily_0920_1012.csv   daily, Sep 20 - Oct 12
  signal_hourly_1013_1020.csv  hourly, Oct 13 - Oct 20 (exact, hours with at least one match)
  key_total_hourly_1017_1020.csv  all sessions per key per hour, Oct 17 - Oct 20
Output: reports/payoneer_signals_<last day>.html
"""
import datetime as dt
import html
import math
import pathlib
from collections import defaultdict

import spike_report as sr

ROOT = pathlib.Path(__file__).resolve().parent
D = ROOT / "data" / "payoneer"
KEYS = {"E3EFEFBF": ("Payoneer - CLM - Registration - Key 3", "E3EFEFBF-8DE4-42ED-9E7F-92F35B1FD3CF"),
        "EE844FC3": ("Payoneer - Login - Prod - Key 2", "EE844FC3-499D-4A4D-A643-D7400F0FD4DE"),
        "7CC24C4A": ("Payoneer - Registration - Prod - Key 1", "7CC24C4A-611B-41C7-9808-B95722C7861C")}
SIGNALS = [
    {"id": "hl", "name": "Headless browser on a VM", "flags": ["g-bot-headless-browser-vm"],
     "note": "Mostly hotmail.com, CN / Windows / Chrome. Inside the CN/HK/JP/KR exclusion on the Payoneer CLM telltales."},
    {"id": "dp", "name": "Device-parameter spoofing (invalid resolution + spoofed browser values)",
     "flags": ["g-dp-invalid-resolution", "g-dp-spoofing-browser-values"],
     "note": "Almost all outlook.com / hotmail.com, Firefox on Windows and macOS, CN and JP. Also inside the country exclusion."},
]
FIRST, LAST = "2026-09-20", "2026-10-20"
H0, H1 = "2026-10-17 00", "2026-10-20 21"  # hourly window with key totals (Oct 20 22h onward is still loading)


def rows(name):
    for line in (D / name).read_text().splitlines():
        p = line.split(",")
        yield p[0], p[1], [int(x) for x in p[2:]]


def load():
    daily = defaultdict(lambda: defaultdict(lambda: [0, 0, 0, 0]))  # key -> day -> [hl, hlv, dp, dpv]
    hourly = defaultdict(lambda: defaultdict(lambda: [0, 0, 0, 0]))
    for k, d, v in rows("signal_daily_0920_1012.csv"):
        daily[k][d] = v
    for k, h, v in rows("signal_hourly_1013_1020.csv"):
        hourly[k][h] = v
        a = daily[k][h[:10]]
        for i in range(4):
            a[i] += v[i]
    total = defaultdict(dict)
    for k, h, v in rows("key_total_hourly_1017_1020.csv"):
        total[k][h] = v
    return daily, hourly, total


def hours_between(a, b):
    t, end, out = dt.datetime.strptime(a, "%Y-%m-%d %H"), dt.datetime.strptime(b, "%Y-%m-%d %H"), []
    while t <= end:
        out.append(t.strftime("%Y-%m-%d %H"))
        t += dt.timedelta(hours=1)
    return out


def pearson(x, y):
    n = len(x)
    mx, my = sum(x) / n, sum(y) / n
    sx = math.sqrt(sum((a - mx) ** 2 for a in x))
    sy = math.sqrt(sum((b - my) ** 2 for b in y))
    return sum((a - mx) * (b - my) for a, b in zip(x, y)) / (sx * sy) if sx and sy else 0.0


def svg_hourly_ref(hours, created, verified, ref, uid):
    """Hourly created/verified on the left axis; the key's total sessions as a grey band on its own scale."""
    W, H, L, R, T, B = 470, 170, 40, 58, 14, 24
    pw, ph = W - L - R, H - T - B
    ymax = max(created + verified + [1]) * 1.15
    rmax = max(ref + [1]) * 1.05
    step = pw / max(len(hours) - 1, 1)
    x = lambda i: L + step * i
    y = lambda v: T + ph - ph * v / ymax
    yr = lambda v: T + ph - ph * v / rmax
    out = ['<svg viewBox="0 0 %d %d" class="chart" role="img" aria-labelledby="%s-t">' % (W, H, uid),
           '<title id="%s-t">Hourly sessions with the signal vs the key total traffic</title>' % uid]
    pts = " ".join("%.1f,%.1f" % (x(i), yr(v)) for i, v in enumerate(ref))
    out.append('<polygon points="%.1f,%d %s %.1f,%d" class="refband"/>' % (x(0), T + ph, pts, x(len(ref) - 1), T + ph))
    for f in (0, .5, 1):
        v = ymax / 1.15 * f
        out.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" class="grid"/>' % (L, W - R, y(v), y(v)))
        out.append('<text x="%d" y="%.1f" class="axis" text-anchor="end">%s</text>' % (L - 6, y(v) + 4, sr.fmt(v)))
    for i, h in enumerate(hours):
        if h.endswith(" 00") or h.endswith(" 12"):
            out.append('<line x1="%.1f" x2="%.1f" y1="%d" y2="%d" class="grid"/>' % (x(i), x(i), T, T + ph))
            out.append('<text x="%.1f" y="%d" class="axis" text-anchor="middle">%s</text>'
                       % (x(i), H - 6, h[5:10] if h.endswith(" 00") else "12h"))
    for vals, cls in ((created, "s1"), (verified, "s2")):
        out.append('<polyline points="%s" class="line %s"/>' % (" ".join("%.1f,%.1f" % (x(i), y(v)) for i, v in enumerate(vals)), cls))
    out.append('<text x="%.1f" y="%.1f" class="axis">signal</text>' % (x(len(hours) - 1) + 6, y(created[-1]) + 4))
    out.append('<text x="%.1f" y="%d" class="axis">key traffic</text>' % (x(len(hours) - 1) + 6, T + 10))
    for i, h in enumerate(hours):
        out.append('<rect x="%.1f" y="%d" width="%.1f" height="%d" class="hit" data-tip="%s:00 UTC · signal %s · verified %s · key total %s"/>'
                   % (x(i) - step / 2, T, step, ph, h, created[i], verified[i], "{:,}".format(ref[i])))
    out.append("</svg>")
    return "\n".join(out)


def verdict(r, burst, share_day):
    if burst >= 6 and r < 0.4:
        return "bursty", "spikes on its own schedule, not the key's day/night cycle"
    if r >= 0.6 and burst < 4:
        return "organic-looking", "rises and falls with the key's own traffic (circadian)"
    if share_day >= 0.85:
        return "shift pattern", "concentrated in working hours, more tightly than the key's own traffic"
    return "low & slow", "steady trickle with small bursts; weakly tied to the key's day/night cycle"


def main():
    daily, hourly, total = load()
    days = sr.days_between(dt.date.fromisoformat(FIRST), dt.date.fromisoformat(LAST) + dt.timedelta(days=1))
    hours = hours_between(H0, H1)
    sections = []
    for si, s in enumerate(SIGNALS):
        off = 0 if s["id"] == "hl" else 2
        cards = []
        for k8, (kname, kfull) in KEYS.items():
            cr = [daily[k8][d][off] if d in daily[k8] else 0 for d in days]
            vr = [daily[k8][d][off + 1] if d in daily[k8] else 0 for d in days]
            if sum(cr) == 0:
                continue
            hc = [hourly[k8][h][off] if h in hourly[k8] else 0 for h in hours]
            hv = [hourly[k8][h][off + 1] if h in hourly[k8] else 0 for h in hours]
            ref = [total[k8].get(h, [0, 0])[0] for h in hours]
            med = sorted(cr[:-1])[len(cr[:-1]) // 2]
            active = sum(1 for c in cr if c > 0)
            r = pearson(hc, ref) if any(ref) else 0.0
            mean_h = sum(hc) / len(hc)
            burst = max(hc) / mean_h if mean_h else 0
            day_h = sum(c for h, c in zip(hours, hc) if 6 <= int(h[-2:]) <= 15)
            share_day = day_h / sum(hc) if sum(hc) else 0
            ref_day = sum(c for h, c in zip(hours, ref) if 6 <= int(h[-2:]) <= 15) / max(sum(ref), 1)
            tag, why = verdict(r, burst, share_day)
            vt, ct = sum(vr), sum(cr)
            cards.append(
                '<div class="kcard"><h3>%s<span class="tag ongoing">%s</span><span class="tag">%s verified</span></h3>'
                '<div class="kstats">Payoneer · <code>%s</code></div>'
                '<div class="kstats">%s → %s: <b>%s</b> sessions on <b>%d of %d days</b> · median day %s · peak day %s · verified <b>%s of %s</b></div>'
                '<div class="kstats">Oct 17–20 hourly: correlation with key traffic <b>r = %.2f</b> · peak hour <b>%.1f×</b> the average hour · '
                '%.0f%% of matches in 06–15h UTC (key traffic: %.0f%%) → <b>%s</b>: %s</div>%s'
                '<div class="sub">Hourly, %s → %s UTC. Grey band = all sessions on the key (own scale), the organic day/night shape.</div>%s</div>'
                % (html.escape(kname), tag, "%.0f%%" % (100.0 * vt / ct), kfull, days[0], days[-1], "{:,}".format(ct), active, len(days),
                   sr.fmt(med), sr.fmt(max(cr)), "{:,}".format(vt), "{:,}".format(ct), r, burst, 100 * share_day, 100 * ref_day, tag, why,
                   sr.svg_key_lines(days, cr, vr, med, "2026-10-16", "p%d%s" % (si, k8), "so far, to 22:00 UTC"),
                   hours[0], hours[-1], svg_hourly_ref(hours, hc, hv, ref, "q%d%s" % (si, k8))))
        sections.append('<section class="combo"><h2 style="margin-top:0">%d. %s</h2><ul class="flags">%s</ul><p class="muted">%s</p>'
                        '<div class="legend"><span class="lg"><i class="sw s1"></i>sessions with the signal</span>'
                        '<span class="lg"><i class="sw s2"></i>of those, verified</span>'
                        '<span class="lg"><i class="sw refsw"></i>key total traffic (hourly chart)</span></div><div class="kgrid">%s</div></section>'
                        % (si + 1, html.escape(s["name"]), "".join('<li><code class="newflag">%s</code></li>' % html.escape(f) for f in s["flags"]),
                           html.escape(s["note"]), "".join(cards)))
    gen = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    extra = (".refband{fill:var(--text-muted);opacity:.18;stroke:none}.sw.refsw{background:var(--text-muted);opacity:.35}"
             ".newflag{background:#fff1c2;color:#4a3700;border:1px solid #d9a800;border-radius:4px;padding:1px 5px}")
    doc = ['<!doctype html><html><head><meta charset="utf-8"><title>Payoneer: candidate signals</title><style>%s%s%s</style></head><body><div class="viz-root">'
           % (sr.css(), sr.PERKEY_CSS, extra),
           "<h1>Payoneer: are these attacks, or organic traffic?</h1>",
           '<p class="muted">Generated %s. Exact session counts from <code>ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY</code> for Payoneer CLM Registration, '
           'Login and Registration keys. <b>Created</b> = sessions carrying the signal; <b>verified</b> = of those, sessions that ended verified. '
           'Daily chart: %s → %s (Oct 20 is partial, to 22:00 UTC; dashed line = median day). Hourly chart: the signal against the key\'s own traffic. '
           'Organic traffic follows the grey band; an attack either bursts on its own schedule or keeps a tighter shift pattern than real users. '
           'The registration key (Key 1) had no matches for either signal.</p>' % (gen, FIRST, LAST)] + sections + ['<div id="tip"></div>%s</div></body></html>' % sr.JS]
    out = ROOT / "reports" / ("payoneer_signals_%s.html" % LAST)
    out.write_text("\n".join(doc))
    print("wrote", out.relative_to(ROOT))


if __name__ == "__main__":
    main()
