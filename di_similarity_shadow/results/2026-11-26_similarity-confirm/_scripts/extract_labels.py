# Extract the Athena label export (chunk -> 'id+L/N' strings) from this agent's own transcript (tool results), since the
# Superset tool returns results only into the conversation. Writes labels_2026-11-06.csv (session,label,chunk).
import json, sys, re
src=sys.argv[1]; dst=sys.argv[2]
chunks={}
for line in open(src):
    for m in re.finditer(r'\{\\*"c\\*":(\d+),\\*"n\\*":(\d+),\\*"ids\\*":\\*"([0-9a-f.,LN]+)\\*"\}', line):
        c,n,ids=int(m.group(1)),int(m.group(2)),m.group(3)
        chunks[c]=(n,ids)
out=open(dst,'w'); out.write('session,label,chunk2h\n'); tot=0
for c in sorted(chunks):
    n,ids=chunks[c]; items=ids.split(',')
    assert len(items)==n,(c,n,len(items))
    for it in items:
        assert re.fullmatch(r'[0-9a-f]{17}\.[0-9]{10}[LN]',it),it
        out.write(f"{it[:-1]},{'Legit' if it[-1]=='L' else 'Nonlegit'},{c}\n"); tot+=1
print(sorted(chunks), tot)
