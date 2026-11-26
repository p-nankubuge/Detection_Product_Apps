# Builds totals, G7 per cell and G8 from raw/ (no database access). Output: raw/10_tables.txt
import os
H=os.path.dirname(os.path.abspath(__file__)); R=os.path.join(H,'raw')
N=['today ST','today LT','today ST or LT','ST m5 f11','ST m5 f8','ST m10 f8','ST m5 f5','ST m10 f11','LT m5 f11','LT m5 f8','ST or LT m5 f11','ST or LT m5 f8']
BASE={1:1,8:1,9:1,2:2,10:2,11:2}  # today counterpart for G7 (default r0)
p=lambda a,b: f"{100*a/b:.1f}" if b else "-"
out=[]
def g7(cells,i,ci):
    b=BASE.get(i,0); fails=[]
    for (d,g) in sorted(cells,key=lambda c:(int(c[0]),c[1])):
        if g.startswith('SKIP') or d=='-1': continue
        v=cells[(d,g)][i][ci]; t=cells[(d,g)][b][ci]
        if v>t: fails.append(f"{d} {g} {v} vs {t}")
    return fails
# Figma 20 Nov: blocks F,Fh,Fv,Fc,Fn,Fcl,NEW,LOST,Fclh
fc={}
for l in open(os.path.join(R,'12_figma_20nov_cells.txt')):
    if l.startswith('#'): continue
    x=l.strip().split('|'); fc[(x[0],x[1])]=[list(map(int,x[4+i].split(','))) for i in range(12)]
out.append("FIGMA 20 Nov (88,608 sessions; cells with no fire omitted in raw, totals from them)")
out.append("rule|fires|High%|verified%|challenged%|clean fires|new vs today|lost vs today|G7 failing cells (clean fires > today same cell)")
for i in range(12):
    t=[sum(fc[c][i][k] for c in fc) for k in range(9)]
    f=g7(fc,i,5)
    out.append(f"{N[i]}|{t[0]}|{p(t[1],t[0])}|{p(t[2],t[0])}|{p(t[3],t[0])}|{t[5]}|{t[6]}|{t[7]}|{len(f)}: {'; '.join(f) or 'none'}")
# Blizzard: day|d|grp|n|cl| blocks F,Fh,Fv,Fcl
bc={}; bt={}
for l in open(os.path.join(R,'19_blizzard_cells_by_day.txt')):
    if l.startswith('#'): continue
    x=l.strip().split('|'); v=[list(map(int,x[5+i].split(','))) for i in range(12)]
    k=(x[1],x[2]); bc.setdefault(k,[[0]*4 for _ in range(12)])
    bc[k]=[[a+b for a,b in zip(bc[k][i],v[i])] for i in range(12)]
    bt.setdefault(x[0],[[0]*4 for _ in range(12)])
    bt[x[0]]=[[a+b for a,b in zip(bt[x[0]][i],v[i])] for i in range(12)]
lab={}
for l in open(os.path.join(R,'18_blizzard_label_scores.txt')):
    if l.startswith('#'): continue
    x=l.strip().split('|'); lab[x[0]]=list(map(int,x[1:]))
# label columns: labels,matched_rows,matched_labels,t_st,t_lt,t_any,m5f11,m5f8,m10f8,m5f5,m10f11,lt_m5f11,lt_m5f8,comb_m5f11,comb_m5f8,...
LI={0:3,1:4,2:5,3:6,4:7,5:8,6:9,7:10,8:11,9:12,10:13,11:14}
L=[sum(lab[d][j] for d in lab) for j in range(len(lab['2026-11-09']))]
out.append("BLIZZARD 9-11 Nov (209,927 sessions); Nonlegit labels 5,718 (9 Nov 3,670; 10 Nov 981; 11 Nov 1,067)")
out.append("rule|fires|High%|verified%|clean fires|fires 9/10/11 Nov|NL caught (9/10/11)|G8 (clean <= today 974 and NL > today)|G7 failing cells (3-day clean fires > today same cell)")
tot=lambda i:[sum(bt[d][i][k] for d in bt) for k in range(4)]
for i in range(12):
    t=tot(i); f=g7(bc,i,3); nl=L[LI[i]]; per='/'.join(str(lab[d][LI[i]]) for d in sorted(lab))
    b=BASE.get(i,0); tb=tot(b); nlb=L[LI[b]]
    g8='-' if i in (0,1,2) else ('PASS' if t[3]<=tb[3] and nl>nlb else 'FAIL')
    out.append(f"{N[i]}|{t[0]}|{p(t[1],t[0])}|{p(t[2],t[0])}|{t[3]}|{'/'.join(str(bt[d][i][0]) for d in sorted(bt))}|{nl} ({per})|{g8}|{len(f)}: {'; '.join(f) or 'none'}")
# Dict 63
for i in (0,3,4,5,6):
    F=sum(bc[k][i][0] for k in bc if k[0]=='63'); Hh=sum(bc[k][i][1] for k in bc if k[0]=='63')
    out.append(f"Blizzard Dict 63 {N[i]}: {F} fires, {p(Hh,F)}% High")
open(os.path.join(R,'10_tables.txt'),'w').write('\n'.join(out)+'\n'); print('\n'.join(out))
