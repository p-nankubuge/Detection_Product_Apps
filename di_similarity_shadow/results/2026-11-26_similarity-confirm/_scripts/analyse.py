# Aggregate q1_main_result.txt (6 session windows) into the confirm-run tables. Prints markdown blocks used in the reports.
import sys, collections, re
src = sys.argv[1] if len(sys.argv) > 1 else 'q1_main_result.txt'
sec = collections.defaultdict(list)
for line in open(src):
    line = line.rstrip('\n')
    if '#' not in line or line.startswith('#'): continue
    name, body = line.split('#', 1)
    if not body: continue
    for item in body.split(';'):
        sec[name].append(item.split('|'))
C = collections.Counter
# ---- M
M = [list(map(int, r)) for r in sec['M']]
sessions = sum(r[4] for r in M); verified = sum(r[5] for r in M)
labm = sum(r[1] for r in M); labL = sum(r[2] for r in M); labN = sum(r[3] for r in M)
print(f"SESSIONS {sessions} VERIFIED {verified} LABELS matched {labm} L {labL} N {labN} completeness {labm/verified:.2%}")
# ---- X: d|b0b1|lab|n|high|ver|ch|chns
X = collections.defaultdict(lambda: [0]*5)
for d, bb, lab, *v in sec['X']:
    k = (int(d), bb[0], bb[1], lab)
    for i, x in enumerate(map(int, v)): X[k][i] += x
DICTS = [-1, 1, 3, 7, 15, 31, 63]; BANDS = ['A', 'B', 'C', 'D', 'n']
agree = {63: 'A', 31: 'B', 15: 'B', 7: 'C', 3: 'D', 1: 'D', -1: 'D'}; rk = {'A': 1, 'B': 2, 'C': 3, 'D': 4, 'n': 9}
def agg(f):
    out = collections.defaultdict(lambda: [0]*5)
    for k, v in X.items():
        kk = f(k)
        if kk is None: continue
        for i in range(5): out[kk][i] += v[i]
    return out
for T, bi in [('T0', 1), ('T1', 2)]:
    print(f"\n### Crosstab {T}: today's dict (rows) x band (n, row %, High %)")
    ct = agg(lambda k: (k[0], k[bi]))
    print("| Dict | A | B | C | D | no score | Total |"); print("|---|---:|---:|---:|---:|---:|---:|")
    for d in DICTS:
        tot = sum(ct[(d, b)][0] for b in BANDS)
        if not tot: continue
        cells = []
        for b in BANDS:
            n, h = ct[(d, b)][0], ct[(d, b)][1]
            cells.append(f"{n:,} ({n/tot:.1%}; H {h/n:.0%})" if n else "0")
        print(f"| {d} | " + " | ".join(cells) + f" | {tot:,} |")
    same = up = down = prom = dem = 0; Dn = Dh = nD = nDh = 0
    for (d, b0, b1, lab), v in X.items():
        b = (b0, b1)[bi-1]
        if b == 'n': continue
        a = agree[d]
        if rk[b] == rk[a]: same += v[0]
        elif rk[b] < rk[a]: up += v[0]
        else: down += v[0]
        if d in (1, 3) and b in 'AB': prom += v[0]
        if d in (63, 31, 15) and b == 'D': dem += v[0]
        if b == 'D': Dn += v[0]; Dh += v[1]
        else: nD += v[0]; nDh += v[1]
    scored = same + up + down
    print(f"SUMMARY {T}: same {same/scored:.1%} up {up/scored:.1%} down {down/scored:.1%} promoted {prom} demoted {dem} D {Dn} ({Dh/Dn:.1%} High) notD {nD} ({nDh/nD:.1%} High) scored {scored}")
    g1 = sum(v[0] for k, v in X.items() if k[0] in (1, 3)); g1ab = sum(v[0] for k, v in X.items() if k[0] in (1, 3) and k[bi] in 'AB')
    g5 = sum(v[0] for k, v in X.items() if k[0] == 63); g5a = sum(v[0] for k, v in X.items() if k[0] == 63 and k[bi] == 'A')
    m1 = sum(v[0] for k, v in X.items() if k[0] == -1); m1d = sum(v[0] for k, v in X.items() if k[0] == -1 and k[bi] == 'D')
    print(f"G1 {T}: {g1ab}/{g1} = {g1ab/g1:.1%}; G5 {T}: {g5a}/{g5} = {g5a/g5:.1%}; Dict -1 -> D {m1d}/{m1}")
    # labels by band
    lb = agg(lambda k: (k[bi], k[3]))
    print(f"LABELS {T} by band: " + "; ".join(f"{b}: L {lb[(b,'L')][0]} N {lb[(b,'N')][0]} (unl {lb[(b,'-')][0]}, High% unl {lb[(b,'-')][1]/max(1,lb[(b,'-')][0]):.1%})" for b in BANDS))
    for lab, nm in [('L', 'Legit'), ('N', 'Nonlegit')]:
        tot = sum(lb[(b, lab)][0] for b in BANDS)
        print(f"  {nm}: in D {lb[('D',lab)][0]}/{tot} = {lb[('D',lab)][0]/tot:.1%}; in A/B {lb[('A',lab)][0]+lb[('B',lab)][0]}/{tot} = {(lb[('A',lab)][0]+lb[('B',lab)][0])/tot:.1%}")
# moved cells per T (for disagreement): dict x band, label split + outcomes
for T, bi in [('T0', 1), ('T1', 2)]:
    print(f"\n### Moved cells {T}: dict>band | n | verified | High | challenged | ch not solved | Legit | Nonlegit")
    ct = agg(lambda k: (k[0], k[bi]))
    lbl = agg(lambda k: (k[0], k[bi], k[3]))
    for d in DICTS:
        for b in BANDS:
            v = ct[(d, b)]
            if not v[0] or b == 'n' or rk[b] == rk[agree[d]]: continue
            lab = 'up' if rk[b] < rk[agree[d]] else 'down'
            tag = (' promoted' if d in (1, 3) and b in 'AB' else '') + (' demoted' if d in (63, 31, 15) and b == 'D' else '')
            print(f"| {d}>{b} ({lab}{tag}) | {v[0]:,} | {v[2]/v[0]:.1%} | {v[1]/v[0]:.1%} | {v[3]/v[0]:.1%} | {v[4]/v[0]:.1%} | {lbl[(d,b,'L')][0]} | {lbl[(d,b,'N')][0]} |")
# T1 additions vs T0
add = agg(lambda k: ('add' if k[1] != 'D' and k[2] == 'D' else ('rem' if k[1] == 'D' and k[2] != 'D' else None), k[3]))
for kind in ('add', 'rem'):
    n = sum(add[(kind, l)][0] for l in 'LN-'); h = sum(add[(kind, l)][1] for l in 'LN-')
    if n: print(f"\nT1 {kind}: n {n} High {h} ({h/n:.1%}); Legit {add[(kind,'L')][0]} Nonlegit {add[(kind,'N')][0]} unlabelled {add[(kind,'-')][0]} (High {add[(kind,'-')][1]}/{add[(kind,'-')][0]} = {add[(kind,'-')][1]/max(1,add[(kind,'-')][0]):.1%})")
fromto = agg(lambda k: ((k[0], k[1]) if k[1] != 'D' and k[2] == 'D' else None))
print("T1 adds by dict>T0 band: " + "; ".join(f"{d}>{b}: {v[0]} (H {v[1]})" for (d, b), v in sorted(fromto.items())))
# ADD by reason
AD = collections.defaultdict(lambda: [0, 0])
for md, ab, fl, nw, lab, n, h in sec['ADD']:
    AD[(ab, lab)][0] += int(n); AD[(ab, lab)][1] += int(h)
print("ADD by part: " + "; ".join(f"{k}: {v[0]} (H {v[1]})" for k, v in sorted(AD.items())))
# ---- G3
G = collections.defaultdict(lambda: [0, 0])
for md, tt, lab, n, h in sec['G3']:
    G[(md, tt, lab)][0] += int(n); G[(md, tt, lab)][1] += int(h)
for md in ('desk', 'mob'):
    for T, i in (('T0', 0), ('T1', 1)):
        dn = sum(v[0] for k, v in G.items() if k[0] == md and k[1][i] == 'D'); dh = sum(v[1] for k, v in G.items() if k[0] == md and k[1][i] == 'D')
        pn = sum(v[0] for k, v in G.items() if k[0] == md and k[1][i] == 'p'); ph = sum(v[1] for k, v in G.items() if k[0] == md and k[1][i] == 'p')
        dL = sum(v[0] for k, v in G.items() if k[0] == md and k[1][i] == 'D' and k[2] == 'L'); dN = sum(v[0] for k, v in G.items() if k[0] == md and k[1][i] == 'D' and k[2] == 'N')
        pL = sum(v[0] for k, v in G.items() if k[0] == md and k[1][i] == 'p' and k[2] == 'L'); pN = sum(v[0] for k, v in G.items() if k[0] == md and k[1][i] == 'p' and k[2] == 'N')
        print(f"G3 {md} {T}: Dchk {dh}/{dn} = {dh/dn:.1%}  pass {ph}/{pn} = {ph/pn:.1%}  ratio {dh/dn/(ph/pn):.2f}x | labels Dchk L {dL} N {dN} (Nonlegit share {dN/max(1,dL+dN):.0%}); pass L {pL} N {pN} ({pN/max(1,pL+pN):.0%})")
# ---- G1 single field
G1 = collections.defaultdict(lambda: [0]*4)
for d, dg, n, a0, a1, h in sec['G1']:
    dg = 'multi' if '+' in dg else dg
    for i, x in enumerate(map(int, (n, a0, a1, h))): G1[dg][i] += x
print("\nG1 by single differing field (Dict 1+3): field | n | T0 A/B | T1 A/B | High")
for k, v in sorted(G1.items(), key=lambda kv: -kv[1][0]):
    print(f"| {k or '(none: exact match on all fields)'} | {v[0]} | {v[1]} ({v[1]/v[0]:.0%}) | {v[2]} ({v[2]/v[0]:.0%}) | {v[3]} ({v[3]/v[0]:.1%}) |")
# ---- WF
W = collections.defaultdict(lambda: [0, 0, 0, 0])
for md, f, w, lab, n, h in sec['WF']:
    W[(md, f, w)][0] += int(n); W[(md, f, w)][1] += int(h)
    if lab == 'L': W[(md, f, w)][2] += int(n)
    if lab == 'N': W[(md, f, w)][3] += int(n)
print("\nWF: group | fails | warns | n | High% | Legit | Nonlegit")
for k in sorted(W):
    v = W[k]; print(f"| {k[0]} | {k[1][1:]} | {k[2][1:]} | {v[0]:,} | {v[1]/v[0]:.1%} | {v[2]} | {v[3]} |")
# baseline: labels by today's dict
bd = agg(lambda k: (k[0], k[3]))
print("\nLabels by today's dict: " + "; ".join(f"{d}: L {bd[(d,'L')][0]} N {bd[(d,'N')][0]} all {sum(bd[(d,l)][0] for l in 'LN-')} H {sum(bd[(d,l)][1] for l in 'LN-')}" for d in DICTS))
hl = agg(lambda k: k[3])
print("High by label: " + "; ".join(f"{l}: {hl[l][1]}/{hl[l][0]}" for l in 'LN-'))
