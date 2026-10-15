#!/usr/bin/env python3
"""Render a spike_scan SQL template with dates/vocab. Prints the SQL (comments stripped).

  python3 render.py sql/01_single_flag_spikes.sql --win-start 2026-10-10 --win-end 2026-10-14
  python3 render.py sql/02_combo_spikes.sql --win-start 2026-10-10 --win-end 2026-10-14 \
      --vocab vocab.txt --max-arity 4 --limit 20
  python3 render.py sql/03_track_exact_day.sql --win-start 2026-10-13 --combos combos.json

Baseline is always the 7 days before --win-start.
"""
import argparse, datetime as dt, pathlib

p = argparse.ArgumentParser()
p.add_argument("template")
p.add_argument("--win-start", required=True)
p.add_argument("--win-end", help="exclusive (defaults to win-start + 1 day)")
p.add_argument("--vocab", help="file with one flag per line")
p.add_argument("--max-arity", default="3")
p.add_argument("--limit", default="25")
p.add_argument("--combos", help="combos.json (03_track_exact_day); uses --win-start as the day")
a = p.parse_args()

ws = dt.date.fromisoformat(a.win_start)
we = dt.date.fromisoformat(a.win_end) if a.win_end else ws + dt.timedelta(days=1)
vals = {
    "win_start": a.win_start, "win_end": str(we),
    "win_days": str((we - ws).days),
    "base_start": str(ws - dt.timedelta(days=7)),
    "max_arity": a.max_arity, "limit": a.limit,
}
if a.vocab:
    flags = [l.strip() for l in pathlib.Path(a.vocab).read_text().splitlines()
             if l.strip() and not l.startswith("#")]
    if len(flags) > 62:
        raise SystemExit("vocab too large for a BIGINT bitmask (max 62)")
    vals["vocab"] = ",".join("'%s'" % f.replace("'", "''") for f in flags)
if a.combos:
    import json
    combos = json.loads(pathlib.Path(a.combos).read_text())["combos"]
    cols = []
    for i, c in enumerate(combos):
        cond = " AND ".join("ARRAY_CONTAINS('%s'::VARIANT, flags)" % f for f in c["flags"])
        cols.append("COUNT_IF(%s) AS c%d" % (cond, i))
    vals["combo_cols"] = ",\n         ".join(cols)
    vals["combo_max"] = ", ".join("c%d" % i for i in range(len(combos))) + (", 0" if len(combos) == 1 else "")
    vals["combo_concat"] = " || ',' || ".join("c%d" % i for i in range(len(combos)))
    vals["day"] = a.win_start
    vals["next_day"] = str(ws + dt.timedelta(days=1))

sql = "\n".join(l for l in pathlib.Path(a.template).read_text().splitlines()
                if not l.lstrip().startswith("--"))
for k, v in vals.items():
    sql = sql.replace("{%s}" % k, v)
print(sql.strip())
