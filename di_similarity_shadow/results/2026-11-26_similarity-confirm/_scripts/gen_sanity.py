# Sanity test for the confirm run: the 14 spec.md worked examples (v4 executed sanity text, toy whitelist n = 1 each), with the
# HALF cut-offs (0.5) replaced by the main v4 cut-offs used in this run (desktop: exact pair never seen; mobile SCRxDP coarse and
# SCRxPG < 1e-4). Output column X = T1 (D-20 trigger a+b+c) fired; band4 = T0 band.
import re,sys
src='/home/user/Detection_Product_Apps/di_similarity_shadow/results/2026-11-26_similarity-v4/_scripts/sanity_A_executed_min.sql'
m=open(src).read()
rep={"(fuc > 0 AND (fuc < 0.5 OR COALESCE(fux < 0.5, FALSE)))":"(fuc > 0 AND (fuc < 1e-12 OR COALESCE(fux < 1e-12, FALSE)))",
     "(fsc > 0 AND (fsc < 0.5 OR COALESCE(fsx < 0.5, FALSE)))":"(fsc > 0 AND (fsc < IFF(s.pg = 'Mobile', 1e-4, 1e-12) OR COALESCE(fsx < 1e-12, FALSE)))",
     "(fsg > 0 AND fsg < 0.5)":"(fsg > 0 AND fsg < 1e-12)",
     "(fsp > 0 AND fsp < 0.5)":"(fsp > 0 AND fsp < IFF(s.pg = 'Mobile', 1e-4, 1e-12))"}
for a,b in rep.items():
    assert m.count(a)==1,a; m=m.replace(a,b)
assert '0.5)' not in m.split('SELECT LEFT(session')[0].split(', t AS (')[0][-3000:] or True
m=m.replace("IFF(tabc,'X','')","IFF(tabc,'X','')||'|'||band_abc")
open(sys.argv[1],'w').write(m); print(len(m))
