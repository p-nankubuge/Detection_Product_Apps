from common import *
from slim import slim_exec
EXC=("c3||'|'||session||'|'||osf||'|'||pg||'|'||osv||'|'||COALESCE(risk,'-')||'|'||band||'>'||bx||'|'||fails3||'|'||warns4||'|'||tag||'|'"
     "||LEFT(REGEXP_REPLACE(SPLIT_PART(h,'||',5),'Mozilla/5.0 \\\\(|AppleWebKit/[0-9.]+ \\\\(KHTML, like Gecko\\\\) ',''),48)"
     "||'|'||SPLIT_PART(h,'||',2)||'|'||SPLIT_PART(SPLIT_PART(h,'||',3),'::',2)||'|'||SPLIT_PART(h,'||',4)||'|'||LEFT(REPLACE(SPLIT_PART(SPLIT_PART(h,'||',6),'::',6),'ANGLE (',''),28)"
     "||'|'||"+"||','||".join(cnt(f) for f in ['fuc','fux','fsc','fsx','fsg','fsp']))
tail=G2+(", e AS (SELECT 'IN' AS c3, band_abc AS bx, TRIM(IFF(ta AND NOT t3,'a ','')||IFF(tb AND NOT t3,'b ','')||IFF(tabc AND NOT (ta OR tb),'c','')) AS tag, g.* FROM g WHERE band<>'D' AND band_abc='D'"
 " UNION ALL SELECT 'OUT', band_c, '', g.* FROM g WHERE band='D' AND band_c<>'D'"
 " UNION ALL SELECT 'RARE', band4, '', g.* FROM g WHERE mob2 AND nrare>0)\n"
 "SELECT "+EXC+" AS r FROM e QUALIFY ROW_NUMBER() OVER (PARTITION BY c3 ORDER BY HASH(session)) <= {N} ORDER BY r\n")
for nm,N in [('q4_examples',20)]:
    emit2(nm, f"-- Q4: example sessions, up to {N} per cell (deterministic order HASH(session)): IN = newly in Band D under the combined what-if\n-- (v4abc) vs v3, with the trigger(s) responsible (a = coarse UAxDP alone, b = 2+ warning signs, c = SCRxGL counted as a warning);\n-- OUT = newly out of Band D under what-if c (SCRxGL as a warning); RARE = mobile sessions with a frequency-graded rare-pair warning (v4 main).\n-- Columns: cell|session|OS|platform group|OS version|risk|v3>new band|failed checks|v4 warnings|trigger|UA (48 chars, prefixes removed)|JA4|\n-- physical screen|device_params|WebGL renderer (28 chars)|whitelist sessions with the pair: UAxDP c,x; SCRxDP c,x; SCRxGL; SCRxPG.\n", tail.replace('{N}',str(N)))
SP2=SP
m=open(SP2+'q4_examples_min.sql').read(); s=slim_exec(m)
for N in (10,):
    open(SP2+f'q4s_{N}.sql','w').write(s.replace('<= 20 ORDER BY r',f'<= {N} ORDER BY r'))
print(len(s)); i=s.index(", g AS (SELECT r.session"); print(s[i:])
