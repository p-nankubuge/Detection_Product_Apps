import sys, datetime as dt
src, out = sys.argv[1], sys.argv[2]
lines = dict(l.split(':',1) for l in open(src).read().strip().splitlines())
daily = {}
for r in lines['D'].split(';'):
    d,n,v,c,a = r.split(','); daily[dt.date.fromisoformat(d)] = tuple(map(int,(n,v,c,a)))
hourly = {}
for r in lines['H'].split(';'):
    h,n,v = r.split(','); hourly[dt.datetime.strptime(h,'%Y-%m-%d %H')] = (int(n),int(v))
end = dt.date(2026,10,28)
days = [end - dt.timedelta(days=i) for i in range(29,-1,-1)]
hs0 = dt.datetime(2026,10,22,0); hrs = [hs0 + dt.timedelta(hours=i) for i in range(int((dt.datetime(2026,10,29,2)-hs0).total_seconds()//3600)+1)]
C = {'c':'#2a78d6','v':'#eb6834','ch':'#1baf7a','a':'#e34948'}
def chart(xs, series, labels, W=1000, H=260, step=None, fmtx=None, bars=False):
    L,R,T,B=48,14,14,30; pw,ph=W-L-R,H-T-B
    ymax=max(max(s) for s,_ in series) or 1
    ymax=[m for m in (10,20,25,50,100,150,200,250,300,400,500) if m>=ymax][0]
    n=len(xs); x=lambda i:L+pw*i/max(n-1,1); y=lambda v:T+ph-ph*v/ymax
    o=[f'<svg viewBox="0 0 {W} {H}" width="100%">']
    for f in (0,.5,1):
        yy=y(ymax*f); o.append(f'<line x1="{L}" x2="{W-R}" y1="{yy:.1f}" y2="{yy:.1f}" stroke="#e4e3df"/><text x="{L-6}" y="{yy+4:.1f}" font-size="11" fill="#77766f" text-anchor="end">{int(ymax*f)}</text>')
    for i in range(0,n,step):
        o.append(f'<text x="{x(i):.1f}" y="{H-10}" font-size="11" fill="#77766f" text-anchor="middle">{fmtx(xs[i])}</text>')
    if bars:
        bw=pw/n*0.8
        for s,col in series[:1]:
            for i,v in enumerate(s): o.append(f'<rect x="{x(i)-bw/2:.1f}" y="{y(v):.1f}" width="{bw:.1f}" height="{T+ph-y(v):.1f}" fill="{col}" opacity=".85"/>')
        for s,col in series[1:]:
            for i,v in enumerate(s): o.append(f'<rect x="{x(i)-bw/2:.1f}" y="{y(v):.1f}" width="{bw:.1f}" height="{T+ph-y(v):.1f}" fill="{col}"/>')
    else:
        for s,col in series:
            pts=" ".join(f"{x(i):.1f},{y(v):.1f}" for i,v in enumerate(s)); o.append(f'<polyline points="{pts}" fill="none" stroke="{col}" stroke-width="2"/>')
    o.append('</svg>')
    leg="".join(f'<span style="margin-right:16px;font-size:12px;color:#52514e"><i style="display:inline-block;width:10px;height:10px;background:{col};border-radius:2px;margin-right:5px"></i>{lab}</span>' for (_,col),lab in zip(series,labels))
    return f'<div>{leg}</div>'+"".join(o)
dn=[daily.get(d,(0,0,0,0)) for d in days]
tot=sum(v[0] for v in daily.values()); ver=sum(v[1] for v in daily.values()); ch=sum(v[2] for v in daily.values()); al=sum(v[3] for v in daily.values())
hn=[hourly.get(h,(0,0)) for h in hrs]
html=f'''<!doctype html><html><head><meta charset="utf-8"><style>body{{font-family:Outfit,system-ui,sans-serif;margin:0;background:#fcfcfb;color:#0b0b0b}}.w{{padding:22px 28px}}h1{{font-size:19px;margin:0 0 4px}}h3{{font-size:14px;color:#52514e;margin:18px 0 4px}}.m{{font-size:12.5px;color:#52514e}}.t{{display:flex;gap:30px;margin:12px 0}}.t b{{display:block;font-size:24px}}.t span{{font-size:12px;color:#52514e}}.c{{background:#f2f1ee;border-radius:8px;padding:14px 18px;margin-top:12px}}</style></head><body><div class="w">
<h1>Payoneer CLM — walletliving actor (TJ + Babilon-T + tg-TJ + hotmail/outlook/rambler.ru)</h1>
<div class="m">ARK_PROD.events.mini_events_log, session_setup → game_verify / game_setup. Daily Sep 30 – Oct 28; hourly Oct 22 – Oct 29 02:00 UTC.</div>
<div class="t"><div><b>{tot:,}</b><span>sessions (first seen Oct 17)</span></div><div><b>{round(100*ver/tot)}%</b><span>verified</span></div><div><b>{round(100*ch/tot)}%</b><span>challenged</span></div><div><b>{al}</b><span>allowlisted (control group)</span></div><div><b>110–300</b><span>per day since Oct 21</span></div></div>
<div class="c"><h3>Daily: created vs verified (challenged + allowlisted shown)</h3>{chart(days,[([v[0] for v in dn],C['c']),([v[1] for v in dn],C['v']),([v[2] for v in dn],C['ch']),([v[3] for v in dn],C['a'])],['created','verified','challenged','allowlisted'],step=3,fmtx=lambda d:d.strftime('%m-%d'))}</div>
<div class="c"><h3>Hourly, last 7 days: a steady drip around the clock, no single burst</h3>{chart(hrs,[([v[0] for v in hn],C['c']),([v[1] for v in hn],C['v'])],['created','verified'],step=12,fmtx=lambda h:h.strftime('%m-%d %H:00'),bars=True)}</div>
</div></body></html>'''
open(out,'w').write(html)
print(tot,ver,ch,al)
