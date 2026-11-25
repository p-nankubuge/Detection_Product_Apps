import sys
sys.path.insert(0,'.')
from build import build, minify, R
exec(open('gen_real.py').read().split("for name,tail,desc")[0])
G=", g AS (SELECT res.*, IFF(pg='Mobile','mob','desk') AS md2 FROM res)\n"
def tail(cells):
    cond=" OR ".join(f"(d={d} AND band='{b}')" for d,b in cells)
    return G+f"""SELECT d||'>'||band||'|'||session||'|'||osf||'|'||pg||'|'||osv||'|'||COALESCE(risk,'')||'|'||ROUND(score3,2)||'|'||reason||'|'||warns3||'|'||LEFT(REPLACE(REPLACE(REPLACE(SPLIT_PART(h,'||',5),'Mozilla/5.0 (',''),'AppleWebKit/537.36 (KHTML, like Gecko) ',''),'AppleWebKit/605.1.15 (KHTML, like Gecko) ',''),55)
  ||'|'||SPLIT_PART(h,'||',2)||'|'||SPLIT_PART(h,'||',3)||'|'||SPLIT_PART(h,'||',4)||'|'||LEFT(REPLACE(SPLIT_PART(SPLIT_PART(h,'||',6),'::',6),'ANGLE (',''),32) AS r
FROM g WHERE {cond}
QUALIFY ROW_NUMBER() OVER (PARTITION BY d, band ORDER BY HASH(session)) <= 5
ORDER BY d, band, HASH(session)
"""
sets={'examples_e1':[(31,'A'),(15,'A'),(7,'A'),(7,'B')],'examples_e2':[(3,'A'),(3,'B'),(3,'C'),(1,'A'),(1,'B')],
      'examples_e3':[(1,'C'),(-1,'B'),(63,'B'),(63,'C'),(63,'D'),(31,'C')],'examples_e4':[(31,'D'),(15,'C'),(15,'D'),(7,'D')]}
for n,cells in sets.items():
    sql=HDR+f"-- Examples: up to 5 sessions per moved cell (20, then 10, did not fit the Superset response cap) (deterministic pseudo-random order HASH(session)): {cells}\n-- Columns: dict>v3 band|session|OS|platform group|OS version|risk|v3 score|v3 reason|v3 warning signs|UA ('Mozilla/5.0 (' and 'AppleWebKit/... (KHTML, like Gecko) ' removed, first 55 chars)|JA4|screen|device_params|WebGL unmasked renderer ('ANGLE (' removed, first 32 chars)\n"+build('',SESS,WL,tail(cells))
    open(R+n+'.sql','w').write(sql); m='EXECUTE IMMEDIATE $$'+minify(sql)+'$$'; open(n+'_min.sql','w').write(m); print(n,len(m))
