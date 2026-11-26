# Extract the q1_main chunk results (6 rows each: M#, X#, G3#, G1#, ADD#, WF#) from this agent's transcript (the Superset tool
# returns results only into the conversation) and write q1_main_result.txt (one line per section per chunk, raw).
import json, sys, re
src, dst = sys.argv[1], sys.argv[2]
seen = []; out = []
for line in open(src):
    try: obj = json.loads(line)
    except Exception: continue
    def walk(o):
        if isinstance(o, dict):
            for v in o.values(): yield from walk(v)
        elif isinstance(o, list):
            for v in o: yield from walk(v)
        elif isinstance(o, str):
            yield o
    for s in walk(obj):
        if '"R":"M#' in s and s.startswith('{"success":true'):
            try: r = json.loads(s)
            except Exception: continue
            rows = [x['R'] for x in r['rows']]
            sql = r['statements'][0]['original_sql']
            m = re.search(r"s\.session_ts >= '([^']+)' AND s\.session_ts < '([^']+)'", sql)
            key = (m.group(1), m.group(2))
            if key in [k for k, _ in seen]: continue
            seen.append((key, rows))
with open(dst, 'w') as f:
    f.write("# Raw output of q1_main_<window>.sql (one block per session window). Sections: M, X, G3, G1, ADD, WF (see the .sql header).\n")
    for (a, b), rows in sorted(seen):
        f.write(f"## window {a} -> {b}\n")
        for r in sorted(rows): f.write(r + "\n")
print([k for k, _ in sorted(seen)])
