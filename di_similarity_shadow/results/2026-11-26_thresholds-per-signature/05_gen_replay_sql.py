import sys,datetime as dt
t=open('/home/user/Detection_Product_Apps/di_similarity_shadow/results/2026-11-26_thresholds-per-signature/04_replay_per_signature_template.sql').read()
t='\n'.join(l for l in t.split('\n') if not l.startswith('--'))
key,d0=sys.argv[1],sys.argv[2]; lab=sys.argv[3] if len(sys.argv)>3 else ''
D0=dt.datetime.fromisoformat(d0)
f=lambda x:x.strftime('%Y-%m-%d %H:%M')
s=t.replace('{KEY}',key).replace('{D0}',f(D0)).replace('{D1}',f(D0+dt.timedelta(days=1))).replace('{B0}',f(D0-dt.timedelta(days=7))).replace('{L1}',f(D0+dt.timedelta(hours=30))).replace('{P0}',f(D0-dt.timedelta(minutes=20)))
if lab:
  s=s.replace('{LABCOL}',", IFF(l.k IS NULL,0,1) lab").replace('{LABJOIN}',"LEFT JOIN ("+lab+") l ON l.k=RIGHT(s1.sid,10)")
else:
  s=s.replace('{LABCOL}',', 0 lab').replace('{LABJOIN}','')
print(' '.join(s.split()))
