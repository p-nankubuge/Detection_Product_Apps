# Builds the per-grid-point tables and G7 / G8 checks from raw/ (no database access). Output: raw/10_tables.txt
import os
H=os.path.dirname(os.path.abspath(__file__)); R=os.path.join(H,'raw')
GP={0:'today ST',1:'m2 f5',2:'m5 f5',3:'m10 f5',4:'m20 f5',5:'m2 f11',6:'m5 f11',7:'m10 f11',8:'m20 f11'}
out=[]
p=lambda a,b: f"{100*a/b:.1f}" if b else "-"
# ---- Figma
fig={}
for l in open(os.path.join(R,'04_figma_20nov.txt')):
    if l.startswith('#') or not l.strip(): continue
    x=l.strip().split('|'); fig[(int(x[0]),x[1],x[2],x[3])]=list(map(int,x[4:]))
out.append("FIGMA 20 Nov (full day; slice 12-14 UTC in brackets)")
out.append("gp|rule|fires|High%|ver%|chall%|chall-not-solved%|clean fires|clean%|new-only|lost vs today ST|slice fires/High%/clean")
for g in range(9):
    a=[0]*14
    for s in ('0','1'):
        v=fig[(g,'ALL','ALL',s)]
        a=[i+j for i,j in zip(a,v)]
    n,cl,F,Fh,Fv,Fc,Fn,Fcl,NEW,LOST=a[:10]
    sv=fig[(g,'ALL','ALL','1')]
    out.append(f"{g}|{GP[g]}|{F}|{p(Fh,F)}|{p(Fv,F)}|{p(Fc,F)}|{p(Fn,F)}|{Fcl}|{p(Fcl,F)}|{NEW}|{LOST}|{sv[2]}/{p(sv[3],sv[2])}/{sv[7]}")
cells=sorted({(k[1],k[2]) for k in fig if k[1]!='ALL' and not k[2].startswith('SKIP')},key=lambda c:(int(c[0]),c[1]))
out.append("FIGMA G7 per cell: clean fires grid vs today (recorded ST breach, same cell); FAIL if grid > today. [eff] = vs today effective (Dict 63 exempt -> 0)")
for g in range(1,9):
    fails=[];fe=[]
    for c in cells:
        t=fig.get((0,)+c+('ALL',),[0]*14)[7]; v=fig.get((g,)+c+('ALL',),[0]*14)[7]
        if v>t: fails.append(f"{c[0]} {c[1]} ({v} vs {t})")
        elif c[0]=='63' and v>0: fe.append(f"{c[0]} {c[1]} ({v})")
    out.append(f"gp{g} {GP[g]}: {len(fails)} failing: {'; '.join(fails) or 'none'} | extra vs effective: {'; '.join(fe) or 'none'}")
out.append("FIGMA Dict 63 (all groups): fires / High% ; Dict 63 Linux cell fires/High/verified/clean")
for g in range(9):
    F=sum(fig.get((g,'63',G,'ALL'),[0]*14)[2] for G in ('Desktop','Mobile','Linux','WinRDVM','Other'))
    Fh=sum(fig.get((g,'63',G,'ALL'),[0]*14)[3] for G in ('Desktop','Mobile','Linux','WinRDVM','Other'))
    L=fig.get((g,'63','Linux','ALL'),[0]*14)
    out.append(f"{g}|{GP[g]}|D63 {F} fires {p(Fh,F)}% High | 63 Linux {L[2]} fires, {L[3]} High, {L[4]} verified, {L[7]} clean")
# ---- Blizzard
tot={}
for l in open(os.path.join(R,'06a_blizzard_totals_nolabels.txt')):
    if l.startswith('#') or not l.strip(): continue
    x=l.strip().split('|')
    if x[3]=='ALL': tot[int(x[0])]=list(map(int,x[4:]))
lab={'today ST':4,1:490,2:488,3:483,4:477,5:141,6:141,7:141,8:141}; newlab={1:486,2:484,3:479,4:473,5:137,6:137,7:137,8:137}
out.append("BLIZZARD 9-12 Nov (3 days); Nonlegit caught = 9 Nov labels only (3,670 labels)")
out.append("gp|rule|fires|High%|ver%|chall%|chall-not-solved%|clean fires|clean%|new-only|lost vs today ST|NL caught|NL new-only|G8 clean<=today|G8 more NL|G8")
t0=tot[0]
for g in range(9):
    n,cl,F,Fh,Fv,Fc,Fn,Fcl,NEW,LOST=tot[g][:10]
    nl=lab['today ST'] if g==0 else lab[g]; nn='-' if g==0 else newlab[g]
    if g==0: out.append(f"0|today ST|{F}|{p(Fh,F)}|{p(Fv,F)}|{p(Fc,F)}|{p(Fn,F)}|{Fcl}|{p(Fcl,F)}|-|-|{nl}|-|-|-|-"); continue
    c1=Fcl<=t0[7]; c2=nl>lab['today ST']
    out.append(f"{g}|{GP[g]}|{F}|{p(Fh,F)}|{p(Fv,F)}|{p(Fc,F)}|{p(Fn,F)}|{Fcl}|{p(Fcl,F)}|{NEW}|{LOST}|{nl}|{nn}|{'pass' if c1 else 'FAIL'}|{'pass' if c2 else 'FAIL'}|{'PASS' if c1 and c2 else 'FAIL'}")
out.append(f"today ST or LT: {tot[0][17]} fires, {tot[0][19]} clean; LT breaches {tot[0][12]}")
bz={};cl={}
for l in open(os.path.join(R,'04_blizzard_09nov_cells.txt')):
    x=l.strip().split('|')
    if x[0]=='CELL': cl[(x[1],x[2])]=(int(x[3]),int(x[4]))
    if x[0]=='G': bz[(int(x[1]),x[2],x[3])]=tuple(map(int,x[4:]))
out.append("BLIZZARD G7 per cell (9 Nov only): clean fires grid vs today same cell")
for g in range(1,9):
    fails=[]
    for c in sorted(cl,key=lambda c:(int(c[0]),c[1])):
        t=bz.get((0,)+c,(0,0,0))[2]; v=bz.get((g,)+c,(0,0,0))[2]
        if v>t: fails.append(f"{c[0]} {c[1]} ({v} vs {t})")
    F=sum(bz.get((g,'63',G),(0,0,0))[0] for G in ('Desktop','Mobile','Linux','WinRDVM','Other')); Fh=sum(bz.get((g,'63',G),(0,0,0))[1] for G in ('Desktop','Mobile','Linux','WinRDVM','Other'))
    out.append(f"gp{g} {GP[g]}: {len(fails)} failing: {'; '.join(fails) or 'none'} | Dict 63 fires {F}, {p(Fh,F)}% High")
open(os.path.join(R,'10_tables.txt'),'w').write('\n'.join(out)+'\n'); print('\n'.join(out))
