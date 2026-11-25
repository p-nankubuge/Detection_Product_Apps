# Builds the Figma K2 threshold matrix from 01_figma_base.sql (key cells) and 03_global_cells_19nov.sql (global cells).
# Fallback: key cell if >= 500 clean signature-windows, else global cell if >= 500, else global dict pooled (>= 500),
# else global dict -1 and 1 pooled. ST = base x short multiplier; LT = base x long multiplier x 60 (assumption, see caveats.md).
# Win RD/VM multipliers capped at 1.5x / 2x. Writes the VALUES list used by 05/06 (path is a scratch file).
key = {
(-1,'Desktop'):(21,8),(-1,'Linux'):(1,1),(-1,'Mobile'):(5,1),(-1,'Other'):(5,1),
(1,'Desktop'):(413,8),(1,'Linux'):(65,5.08),(1,'Mobile'):(165,3.36),(1,'Other'):(6,1.95),(1,'WinRDVM'):(28,4.46),
(3,'Desktop'):(14359,7),(3,'Linux'):(1602,6),(3,'Mobile'):(3449,9),(3,'Other'):(56,3),(3,'WinRDVM'):(969,5),
(7,'Desktop'):(50697,4),(7,'Linux'):(3087,4),(7,'Mobile'):(1743,2),(7,'Other'):(11,1),(7,'WinRDVM'):(2897,4),
(15,'Desktop'):(39261,3),(15,'Linux'):(2198,3),(15,'Mobile'):(9791,3),(15,'Other'):(43,2),(15,'WinRDVM'):(1475,4),
(31,'Desktop'):(76762,3),(31,'Linux'):(2089,3),(31,'Mobile'):(5832,2),(31,'Other'):(1,1),(31,'WinRDVM'):(2977,3),
(63,'Desktop'):(212242,4),(63,'Linux'):(2451,3),(63,'Mobile'):(60986,5),(63,'Other'):(31,1),(63,'WinRDVM'):(6382,4)}
glob = {(-1,'Desktop'):(77,143),(-1,'Linux'):(0,None),(-1,'Mobile'):(37,9.1),(-1,'Other'):(31,6),
(1,'Desktop'):(496,79.3),(1,'Linux'):(91,19.2),(1,'Mobile'):(807,15.9),(1,'Other'):(50,30.6),(1,'WinRDVM'):(47,10.5),
(3,'Desktop'):(14963,104),(3,'Linux'):(1440,16.6),(3,'Mobile'):(8387,21),(3,'Other'):(163,11.4),(3,'WinRDVM'):(1182,16.4),
(7,'Desktop'):(98250,29),(7,'Linux'):(2660,30.8),(7,'Mobile'):(14051,7),(7,'Other'):(96,10.2),(7,'WinRDVM'):(6711,10),
(15,'Desktop'):(87012,13),(15,'Linux'):(1489,10.1),(15,'Mobile'):(87042,21),(15,'Other'):(259,6.4),(15,'WinRDVM'):(4249,7),
(31,'Desktop'):(143574,27),(31,'Linux'):(1450,66.5),(31,'Mobile'):(13592,18),(31,'Other'):(33,7.1),(31,'WinRDVM'):(7083,7),
(63,'Desktop'):(339086,20),(63,'Linux'):(3084,13),(63,'Mobile'):(255490,72),(63,'Other'):(535,16.7),(63,'WinRDVM'):(12916,20)}
pooled = {-1:(145,134.2),1:(1491,35.3),3:(26135,68),7:(121768,25),15:(180051,17),31:(165732,26),63:(611111,37)}
pool11=(1636,68.7)
mult={-1:(1,1),1:(1,1),3:(1,1),7:(1.5,2),15:(2,4),31:(2,4),63:(2,6)}
MIN=500
vals=[]
for d in [-1,1,3,7,15,31,63]:
  for g in ['Desktop','Mobile','Linux','WinRDVM','Other']:
    kc=key.get((d,g),(0,None)); gc=glob.get((d,g),(0,None))
    if kc[0]>=MIN: b,src=kc[1],'key'
    elif gc[0]>=MIN: b,src=gc[1],'global cell'
    elif pooled[d][0]>=MIN: b,src=pooled[d][1],'global dict pooled'
    else: b,src=pool11[1],'global -1+1 pooled'
    ms,ml=mult[d]
    if g=='WinRDVM': ms,ml=min(ms,1.5),min(ml,2)
    st=round(b*ms,2); lt=round(b*ml*60,1)
    vals.append(f"({d},'{g}',{st},{lt})")
    print(f"{d}|{g}|key_sw={kc[0]}|key_p99={kc[1]}|glob_sw={gc[0]}|glob_p99={gc[1]}|base={b}|{src}|x{ms}/x{ml}|ST={st}|LT={lt}")
open('/tmp/claude-0/-home-user-Detection-Product-Apps/83646ed6-8420-5607-8e9d-1d6b47ee5460/scratchpad/vals.txt','w').write(','.join(vals))
