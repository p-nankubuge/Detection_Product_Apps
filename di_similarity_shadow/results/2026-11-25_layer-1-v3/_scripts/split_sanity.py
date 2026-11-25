import re,sys
sys.path.insert(0,'.')
from build import minify
s=open('/home/user/Detection_Product_Apps/di_similarity_shadow/results/2026-11-25_layer-1-v3/sanity_test_v3.sql').read()
m=minify(s)
# drop res columns not used by the sanity output (chk_v1, reason_v2): identical logic otherwise
def cut(m, start, end):
    a=m.index(start); b=m.index(end,a); return m[:a]+m[b:]
m=cut(m,"IFF(t0, 'chk:'","ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(g_ua_dp")
rows=re.findall(r"\('s','[^']*','[^']*'\), ", m)
old=[r for r in rows if '[item' not in r]; new=[r for r in rows if '[item' in r]
# last session row in file may end with '), ' too; check counts
print(len(old),len(new))
A=m; B=m
for r in new: A=A.replace(r,'')
for r in old: B=B.replace(r,'')
open('sanA.sql','w').write('EXECUTE IMMEDIATE $$'+A+'$$'); open('sanB.sql','w').write('EXECUTE IMMEDIATE $$'+B+'$$')
print(len(A),len(B))
