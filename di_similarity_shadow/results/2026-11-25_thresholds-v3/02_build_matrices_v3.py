# v3 (D-13 sensitivity) matrix builder. Same rule as v2 (03_build_matrix_v2.py / 09_ / 12_) except the base statistic:
#   V0 = p99 (= v2)   V1 = max(p99, 5)   V2 = p99.9   V3 = max(p99.9, 5)   (floor applied to the base, before multipliers)
# Fallback: key cell if >= 500 clean sig-windows; else (a) key x dict pooled across groups (its own p99 / p99.9, floored the same way)
# if >= 500, capped after multipliers at the key's current ST / LT; else (b) the key's current ST / LT. Real key cells are not capped.
# ST = base x ST mult; LT = base x LT mult x 60 (v1 assumption). Win RD/VM mults capped 1.5x / 2x.
# Usage:  python3 02_build_matrices_v3.py figma|payoneer|adobe   -> prints per-cell lines and a VALUES list
#         (k, d, grp, st0, lt0, st1, lt1, st2, lt2, st3, lt3).
# Figma input = base_histograms/figma_*.txt (01_figma_base_histogram.sql, 3 chunks); percentiles = PERCENTILE_CONT (linear interpolation).
# Adobe input = base_histograms/adobe_sampled_stats.txt (04_k3_adobe_key_base_sampled_p999.sql returns p99 / p99.9 directly).
# Payoneer: only the EE844FC3 Dict 1 cells were recomputed (03c_; see that file) - 'payoneer' mode is not used.
import sys, os, glob, collections
HERE = os.path.dirname(os.path.abspath(__file__))
MULT = {-1:(1,1),1:(1,1),3:(1,1),7:(1.5,2),15:(2,4),31:(2,4),63:(2,6)}
GROUPS = ['Desktop','Mobile','Linux','WinRDVM','Other']; MIN = 500; FLOOR = 5
def load(files):
    H = collections.defaultdict(collections.Counter)
    for f in files:
        for l in open(f):
            l = l.strip()
            if not l or l.startswith('#'): continue
            parts = l.split('|')
            if len(parts) == 4: parts = ['K'] + parts       # figma files: lvl|d|grp|hist
            k, lvl, d, g, h = parts
            for p in h.split(','):
                n, c = p.split(':'); H[(k, int(d), g if lvl == 'G' else 'ALL')][int(n)] += int(c)
    return H
def pcont(cnt, q):
    N = sum(cnt.values())
    if N == 0: return None
    vals = sorted(cnt); cum = []; s = 0
    for v in vals: s += cnt[v]; cum.append((s, v))
    def at(i):
        for s, v in cum:
            if i < s: return v
    rn = q * (N - 1); lo = int(rn); hi = min(lo + 1, N - 1)
    return at(lo) + (at(hi) - at(lo)) * (rn - lo)
def stats(cnt):
    if not cnt: return (0, None, None)
    return (sum(cnt.values()), round(pcont(cnt, .99), 2), round(pcont(cnt, .999), 2))
def base_for(v, p99, p999):
    b = p99 if v in (0, 1) else p999
    return max(b, FLOOR) if v in (1, 3) else b
def build(H, keys, cur):
    out = []
    for k in keys:
        for d in [-1,1,3,7,15,31,63]:
            for g in GROUPS:
                ms, ml = MULT[d]
                if g == 'WinRDVM': ms, ml = min(ms, 1.5), min(ml, 2)
                kc = H.get((k, d, g)); pc = H.get((k, d, 'ALL'))
                kc = (kc if isinstance(kc, tuple) else stats(kc)) if kc else (0, None, None)
                pc = (pc if isinstance(pc, tuple) else stats(pc)) if pc else (0, None, None)
                row = []; src = []
                for v in range(4):
                    if kc[0] >= MIN:
                        b = base_for(v, kc[1], kc[2]); s = 'key'
                        st, lt = round(b*ms, 2), round(b*ml*60, 1)
                    elif pc[0] >= MIN:
                        b = base_for(v, pc[1], pc[2]); s = '(a)'
                        st, lt = min(round(b*ms, 2), cur[k][0]), min(round(b*ml*60, 1), cur[k][1])
                        if st == cur[k][0] or lt == cur[k][1]: s = '(a,capped)' if (round(b*ms,2) > cur[k][0] or round(b*ml*60,1) > cur[k][1]) else s
                    else:
                        s = '(b)'; st, lt = cur[k]
                    row += [st, lt]; src.append(s)
                out.append((k, d, g, kc, pc, src, row))
    return out
if __name__ == '__main__':
    which = sys.argv[1]
    if which == 'figma':
        H = load(sorted(glob.glob(os.path.join(HERE, 'base_histograms', 'figma_*.txt'))))
        H = {('FIGMA',) + k[1:]: v for k, v in H.items()}; keys = ['FIGMA']; cur = {'FIGMA': (11, 660)}
    elif which == 'payoneer':
        H = load([os.path.join(HERE, 'base_histograms', 'payoneer.txt')])
        keys = ['EE844FC3','E3EFEFBF','7CC24C4A']; cur = {'EE844FC3':(35,2100),'E3EFEFBF':(15,900),'7CC24C4A':(60,3600)}
    else:
        # Adobe: the sampled base is small enough for SQL to return p99 / p99.9 directly (stats file, not a histogram).
        ST = {}
        for l in open(os.path.join(HERE, 'base_histograms', 'adobe_sampled_stats.txt')):
            if l.startswith('#') or not l.strip(): continue
            k, d, g, n, p99, p999 = l.strip().split('|'); ST[(k, int(d), g)] = (int(n), float(p99), float(p999))
        stats = lambda c: c if c else (0, None, None)
        H = {k: v for k, v in ST.items()}; keys = ['BBCC314C']; cur = {'BBCC314C': (90, 5400)}
    rows = build(H, keys, cur); vals = []
    for k, d, g, kc, pc, src, r in rows:
        print(f"{k}|{d}|{g}|key n={kc[0]} p99={kc[1]} p999={kc[2]}|pool n={pc[0]} p99={pc[1]} p999={pc[2]}|src={'/'.join(src)}|"
              + ' '.join(f"V{v}={r[2*v]}/{r[2*v+1]}" for v in range(4)))
        vals.append(f"('{k}',{d},'{g}'," + ','.join(str(x) for x in r) + ')')
    print('VALUES ' + ','.join(vals))
