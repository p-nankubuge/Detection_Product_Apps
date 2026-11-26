# q3_examples: up to 20 sessions that T1 puts in Band D and T0 does not, labelled ones first (window 18:00-24:00, smallest label list).
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_main as G
from build import build, minify, R
from slim import slim_exec, drop_items
import csv
EX=("lab||'|'||d||'|'||b0||'>'||b1||'|'||ab||'|'||fl||'|'||wn||'|'||COALESCE(risk,'')||'|'||IFF(verified,'v','-')||'|'||osf||'|'||pg||'|'||osv||'|'||"
    "LEFT(REPLACE(REPLACE(REPLACE(SPLIT_PART(h,'||',5),'Mozilla/5.0 (',''),'AppleWebKit/537.36 (KHTML, like Gecko) ',''),'AppleWebKit/605.1.15 (KHTML, like Gecko) ',''),60)||'|'||"
    "SPLIT_PART(h,'||',2)||'|'||SPLIT_PART(SPLIT_PART(h,'||',3),'::',2)||'|'||SPLIT_PART(h,'||',4)||'|'||LEFT(REPLACE(SPLIT_PART(SPLIT_PART(h,'||',6),'::',6),'ANGLE (',''),40)")
tail=G.G+f"SELECT {EX} AS r FROM g WHERE b0<>'D' AND b1='D' QUALIFY ROW_NUMBER() OVER (ORDER BY IFF(lab<>'-',0,1), HASH(session)) <= 20 ORDER BY r\n"
rows=list(csv.DictReader(open(R+'labels_2026-11-06.csv')))
cs=[r for r in rows if 9 <= int(r['chunk2h']) < 12]
tok=','.join(r['session'][:3]+r['session'][-10:]+r['label'][0] for r in cs)
pre=f"lab AS (SELECT LEFT(value,13) AS k, RIGHT(value,1) AS l FROM TABLE(SPLIT_TO_TABLE('{tok}', ','))),\n"
hdr=("-- Q3: example sessions that T1 (D-20 a+b+c) puts in Band D and T0 (v4 trigger) does not; labelled sessions first, then deterministic\n"
     "-- order HASH(session); max 20. Window 2026-11-06 18:00-24:00 UTC only (smallest label list). Columns: label (L/N/-)|dict|T0>T1 band|\n"
     "-- T1 part (a = coarse UAxDP never seen, b = 2+ warnings)|failed checks|warning signs (T0 view)|risk band|verified|OS|platform group|OS version|\n"
     "-- UA (shortened, 60)|JA4|physical screen|device_params|WebGL renderer (40). Same core and whitelist as q1_main.\n")
sql=hdr+build(pre, G.sess("2026-11-06 18:00:00","2026-11-07 00:00:00","2026-11-07 06:00:00"), G.WL, tail, G.CUTS_V4)
open(R+'q3_examples_t1_added.sql','w').write(sql)
m=minify(sql); i=m.index(", res AS ("); j=m.index(" FROM sess_raw r JOIN t ON t.h = r.h )",i); m=m[:i]+m[j+len(" FROM sess_raw r JOIN t ON t.h = r.h )"):]
m=slim_exec(m)
m=drop_items(m,['band_v1','t0','n0','band','t3','nwarn','nxw','x_ua_dp','x_scr_dp','band_a','band_b','band_c','ta','tb','tc','f_ua_dp','f_scr_dp','f_scr_gl','f_scr_os','f_osv','f_dp_new','w_scr0','sb','code','score','pk','pk_v2'])
m=m.replace(", omx AS (SELECT osf, MAX(osv_num) AS mx FROM wl GROUP BY osf)","").replace(" LEFT JOIN omx o ON o.osf = s.osf","")
m=m.replace(", LEAST(nfail,2) AS nf2, LEAST(nwarn4,3) AS nw3","").replace(", IFF(diff LIKE '%+%','multi',diff) AS dg","")
open(os.environ.get('SCRATCH','/tmp/')+'q3_min.sql','w').write('EXECUTE IMMEDIATE $$'+m+'$$'); print(len(m))
