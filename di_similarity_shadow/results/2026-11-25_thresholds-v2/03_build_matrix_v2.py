# v2 (D-11) Figma K2 matrix. Key cells = v1 01_figma_base.sql (unchanged). Pooled = 01_figma_base_pooled.sql, variant P.
# Fallback: key cell if >= 500 clean sig-windows; else (a) key x dict pooled across groups if >= 500; else (b) key's current
# threshold (ST 11 / LT 660). Fallback values capped at ST 11 / LT 660; real key cells are not capped.
# ST = base x ST mult; LT = base x LT mult x 60 (v1 assumption). Win RD/VM mults capped 1.5x / 2x. Prints the VALUES list to stdout.
key = {
(-1,'Desktop'):(21,8),(-1,'Linux'):(1,1),(-1,'Mobile'):(5,1),(-1,'Other'):(5,1),
(1,'Desktop'):(413,8),(1,'Linux'):(65,5.08),(1,'Mobile'):(165,3.36),(1,'Other'):(6,1.95),(1,'WinRDVM'):(28,4.46),
(3,'Desktop'):(14359,7),(3,'Linux'):(1602,6),(3,'Mobile'):(3449,9),(3,'Other'):(56,3),(3,'WinRDVM'):(969,5),
(7,'Desktop'):(50697,4),(7,'Linux'):(3087,4),(7,'Mobile'):(1743,2),(7,'Other'):(11,1),(7,'WinRDVM'):(2897,4),
(15,'Desktop'):(39261,3),(15,'Linux'):(2198,3),(15,'Mobile'):(9791,3),(15,'Other'):(43,2),(15,'WinRDVM'):(1475,4),
(31,'Desktop'):(76762,3),(31,'Linux'):(2089,3),(31,'Mobile'):(5832,2),(31,'Other'):(1,1),(31,'WinRDVM'):(2977,3),
(63,'Desktop'):(212242,4),(63,'Linux'):(2451,3),(63,'Mobile'):(60986,5),(63,'Other'):(31,1),(63,'WinRDVM'):(6382,4)}
pooled = {-1:(30,7.55),1:(652,7.49),3:(20041,8),7:(57955,4),15:(52754,3),31:(87579,3),63:(282092,4)}
CUR_ST, CUR_LT = 11, 660
mult={-1:(1,1),1:(1,1),3:(1,1),7:(1.5,2),15:(2,4),31:(2,4),63:(2,6)}
MIN=500
vals=[]
for d in [-1,1,3,7,15,31,63]:
  for g in ['Desktop','Mobile','Linux','WinRDVM','Other']:
    kc=key.get((d,g),(0,None)); pc=pooled[d]
    ms,ml=mult[d]
    if g=='WinRDVM': ms,ml=min(ms,1.5),min(ml,2)
    if kc[0]>=MIN:
      src='key'; st=round(kc[1]*ms,2); lt=round(kc[1]*ml*60,1)
    elif pc[0]>=MIN:
      src='(a) key pooled'; st=min(round(pc[1]*ms,2),CUR_ST); lt=min(round(pc[1]*ml*60,1),CUR_LT)
    else:
      src='(b) current'; st,lt=CUR_ST,CUR_LT
    vals.append(f"({d},'{g}',{st},{lt})")
    print(f"{d}|{g}|key_sw={kc[0]}|key_p99={kc[1]}|pool_sw={pc[0]}|pool_p99={pc[1]}|{src}|x{ms}/x{ml}|ST={st}|LT={lt}")
print(','.join(vals))
