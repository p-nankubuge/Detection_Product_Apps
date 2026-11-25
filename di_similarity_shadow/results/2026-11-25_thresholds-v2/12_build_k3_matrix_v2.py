# v2 (D-11) per-key matrix for Adobe ARP FF K8 (K3) from 11_k3_adobe_key_base_sampled.sql. Same rule as 03_build_matrix_v2.py.
# Current threshold (cap and step b) = ST 90 / LT 5,400 (live on 17-18 Nov).
cells={(-1,'ALL'):(2,1.0),(-1,'Desktop'):(2,1.0),(1,'ALL'):(423,22.8),(1,'Desktop'):(155,24.9),(1,'Linux'):(9,2.0),(1,'Mobile'):(259,4.0),
(3,'ALL'):(7968,181.0),(3,'Desktop'):(5672,198.0),(3,'Linux'):(414,47.3),(3,'Mobile'):(1857,20.0),(3,'Other'):(10,6.8),(3,'WinRDVM'):(280,31.8),
(7,'ALL'):(83564,34.0),(7,'Desktop'):(80140,34.0),(7,'Linux'):(1563,6.0),(7,'Mobile'):(1054,5.0),(7,'WinRDVM'):(2500,10.0),
(15,'ALL'):(98600,10.0),(15,'Desktop'):(69830,7.0),(15,'Linux'):(795,6.0),(15,'Mobile'):(26515,16.0),(15,'Other'):(13,1.9),(15,'WinRDVM'):(1774,5.3),
(31,'ALL'):(101513,11.0),(31,'Desktop'):(95565,11.0),(31,'Linux'):(935,10.0),(31,'Mobile'):(3131,12.0),(31,'WinRDVM'):(2802,7.0),
(63,'ALL'):(291533,18.0),(63,'Desktop'):(240373,17.0),(63,'Linux'):(1491,7.0),(63,'Mobile'):(44841,27.0),(63,'Other'):(47,5.6),(63,'WinRDVM'):(4781,17.0)}
CUR=(90,5400); MIN=500
mult={-1:(1,1),1:(1,1),3:(1,1),7:(1.5,2),15:(2,4),31:(2,4),63:(2,6)}
vals=[]
for d in [-1,1,3,7,15,31,63]:
  for g in ['Desktop','Mobile','Linux','WinRDVM','Other']:
    ms,ml=mult[d]
    if g=='WinRDVM': ms,ml=min(ms,1.5),min(ml,2)
    kc=cells.get((d,g),(0,None)); pc=cells.get((d,'ALL'),(0,None))
    if kc[0]>=MIN: src='key'; st=round(kc[1]*ms,2); lt=round(kc[1]*ml*60,1)
    elif pc[0]>=MIN: src='(a)'; st=min(round(pc[1]*ms,2),CUR[0]); lt=min(round(pc[1]*ml*60,1),CUR[1])
    else: src='(b)'; st,lt=CUR
    vals.append(f"({d},'{g}',{st},{lt})"); print(f"{d}|{g}|key={kc}|pool={pc}|{src}|ST={st}|LT={lt}")
print(','.join(vals))
