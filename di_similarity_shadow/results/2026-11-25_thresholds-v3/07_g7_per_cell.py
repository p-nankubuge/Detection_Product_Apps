# G7 per cell: new clean-traffic fire rate in the cell (clNA / cl) vs today's per-dict clean rate (dict-level clT / cl), from
# raw/05_replay_figma_20nov_v3.txt. Dict 63 is also compared with today's EFFECTIVE rate (0: Dict 63 exempt today).
# A cell fails if its rate is above today's per-dict rate. Cells not in the file had no fires under the variant (pass).
import sys, os, re
f = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'raw', '05_replay_figma_20nov_v3.txt')
rows = {}
for l in open(f):
    if l.startswith('#') or not l.strip(): continue
    p = l.strip().split('|'); kv = dict(x.split('=', 1) for x in p[3:])
    rows[(int(p[0]), p[1], p[2])] = kv
for v in range(4):
    fails = []; fails_eff = []
    for (vv, d, g), kv in sorted(rows.items(), key=lambda x: (x[0][0], int(x[0][1]) if x[0][1] != 'ALL' else 99, x[0][2])):
        if vv != v or g == 'ALL' or g.startswith('SKIP') or d == 'ALL': continue
        dk = rows[(v, d, 'ALL')]; today = int(dk['clT']) / int(dk['cl'])
        cl = int(kv['cl']); c = int(kv['clNA']); rate = c / cl if cl else 0
        st = 'FAIL' if rate > today + 1e-12 else 'pass'
        if st == 'FAIL': fails.append(f"{d} {g}")
        if d == '63' and rate > 0 and st == 'pass': fails_eff.append(f"{d} {g}")
        print(f"V{v}|{d}|{g}|clean fires {c} of {cl} = {100*rate:.3f}% | today dict {d} {100*today:.3f}% | {st}")
    print(f"V{v} FAIL cells ({len(fails)}): {', '.join(fails)} | extra vs Dict 63 effective (0): {', '.join(fails_eff) or 'none'}")
