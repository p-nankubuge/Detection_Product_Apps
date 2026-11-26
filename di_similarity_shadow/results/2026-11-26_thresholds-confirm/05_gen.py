# Generates runnable SQL from 11_replay_confirm_template.sql + a {FINAL} file. Usage: 05_gen.py KEY D0 LTCUR FINALFILE [VERONLY]
import sys,datetime as dt,os
H=os.path.dirname(os.path.abspath(__file__))
strip=lambda t:'\n'.join(l for l in t.split('\n') if not l.lstrip().startswith('--'))
t=strip(open(os.path.join(H,'11_replay_confirm_template.sql')).read())
key,d0,lt,fin=sys.argv[1:5]; ver=sys.argv[5] if len(sys.argv)>5 else ''
fin=strip(open(os.path.join(H,fin)).read()).replace('{VERONLY}',ver)
D0=dt.datetime.fromisoformat(d0); f=lambda x:x.strftime('%Y-%m-%d %H:%M'); td=dt.timedelta
s=t.replace('{FINAL}',fin)
for k,v in {'{KEY}':key,'{D0}':f(D0),'{D1}':f(D0+td(days=1)),'{B0}':f(D0-td(days=7)),'{P0}':f(D0-td(minutes=20)),'{Q0}':f(D0-td(days=1)),'{L1}':f(D0+td(hours=30)),'{LTCUR}':lt}.items(): s=s.replace(k,v)
print(' '.join(s.split()))
