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
p.add_argument("--half", choices=["am", "pm"], help="03_track_exact_day: 00-12h or 12-24h UTC")
p.add_argument("--hours", help="03_track_exact_day: custom UTC hour slice, e.g. 12-18 (use when a half times out)")
p.add_argument("--keys", help="03_track_exact_day: file with one public_key per line (per-key charts)")
p.add_argument("--combos", help="combos.json (03_track_exact_day); uses --win-start as the day")
p.add_argument("--sample", help="08_key_anomaly_profile: block-sample percent for very large keys (counts are scaled back)")
p.add_argument("--recent-end", help="06_key_volume_drops: last complete hour, 'YYYY-MM-DD HH' (default: win-end 00h)")
p.add_argument("--combo-id", help="07_ua_ja4_profile: combos.json id")
p.add_argument("--key", help="07_ua_ja4_profile / 09_cohort_profile: public key")
p.add_argument("--cond", help="09_cohort_profile: SQL predicate defining the cohort (instead of --combo-id)")
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
vals["sample"] = ("SAMPLE SYSTEM (%s) SEED (42)" % a.sample) if a.sample else ""  # seeded: every CTE reference sees the same blocks
# 06_key_volume_drops
vals["window_days"] = ", ".join("('%s')" % (ws + dt.timedelta(days=i)) for i in range((we - ws).days))
vals["recent_end"] = (a.recent_end + ":00:00") if a.recent_end else str(we) + " 00:00:00"
# 07_ua_ja4_profile: window = last 2 days of the scan window; family map = 12-18h on the first baseline day
if a.combo_id:
    import json
    c = next(c for c in json.loads(pathlib.Path("combos.json").read_text())["combos"] if c["id"] == a.combo_id)
    vals["combo_cond"] = " AND ".join("ARRAY_CONTAINS('%s'::VARIANT, flags)" % f for f in c["flags"])
    vals["key"] = a.key
    vals["ts_from"], vals["ts_to"] = str(max(ws, we - dt.timedelta(days=2))), str(we)
    fb = ws - dt.timedelta(days=7)
    vals["fam_from"], vals["fam_to"] = "%s 12:00:00" % fb, "%s 18:00:00" % fb
    vals["cond"] = vals["combo_cond"]
if a.cond:
    vals["cond"], vals["key"] = a.cond, a.key
# 10_truth_check (Athena): every combo as a VALUES row (id, ARRAY[flags])
import json as _j
vals["combo_values"] = ",\n  ".join("('%s', ARRAY[%s])" % (c["id"], ", ".join("'%s'" % f for f in c["flags"]))
                                     for c in _j.loads(pathlib.Path(a.combos or "combos.json").read_text())["combos"])
vals["truth_from"] = str(ws - dt.timedelta(days=30)); vals["truth_from_y"] = vals["truth_from"][:4]
if a.keys and not a.combos:  # 04_key_totals.sql: plain key list
    vals["keys"] = ",".join("'%s'" % l.strip() for l in pathlib.Path(a.keys).read_text().splitlines() if l.strip())
if a.combos:
    import json
    combos = json.loads(pathlib.Path(a.combos).read_text())["combos"]
    cols, bools = [], []
    for i, c in enumerate(combos):
        cond = " AND ".join("ARRAY_CONTAINS('%s'::VARIANT, flags)" % f for f in c["flags"])
        bools.append("(%s) AS b%d" % (cond, i))
        cols.append("COUNT_IF(b%d) AS c%d" % (i, i))
        cols.append("COUNT_IF(b%d AND verified) AS v%d" % (i, i))
    # anchor = each combo's first flag; telltale-type globals (g-rta-*, g-di-*) live in TELLTALE_LIST_AT_ALL_EVENTS
    vals["anchors"] = " OR ".join(sorted({"ARRAY_CONTAINS('{0}'::VARIANT, SUSPICION_FLAGS::ARRAY)"
                                          " OR ARRAY_CONTAINS('{0}'::VARIANT, TELLTALE_LIST_AT_ALL_EVENTS::ARRAY)".format(c["flags"][0])
                                          for c in combos}))
    vals["combo_bools"] = ",\n         ".join(bools)
    vals["combo_cols"] = ",\n         ".join(cols)
    vals["combo_max"] = ", ".join("c%d" % i for i in range(len(combos))) + (", 0" if len(combos) == 1 else "")
    vals["combo_concat"] = " || ',' || ".join("c%d || ',' || v%d" % (i, i) for i in range(len(combos)))
    vals["day"] = a.win_start
    vals["key_filter"], vals["min_sessions"] = "", "150"
    if a.keys:
        ks = [l.strip() for l in pathlib.Path(a.keys).read_text().splitlines() if l.strip()]
        vals["key_filter"] = "\n    AND PUBLIC_KEY IN (%s)" % ",".join("'%s'" % k for k in ks)
        vals["min_sessions"] = "1"
    nd = str(ws + dt.timedelta(days=1))
    if a.hours:
        h0, h1 = (int(x) for x in a.hours.split("-"))
        vals["ts_from"] = "%s %02d:00:00" % (a.win_start, h0)
        vals["ts_to"] = nd if h1 == 24 else "%s %02d:00:00" % (a.win_start, h1)
    else:
      vals["ts_from"], vals["ts_to"] = {None: (a.win_start, nd), "am": (a.win_start, a.win_start + " 12:00:00"),
                                      "pm": (a.win_start + " 12:00:00", nd)}[a.half]

sql = "\n".join(l for l in pathlib.Path(a.template).read_text().splitlines()
                if not l.lstrip().startswith("--"))
for k, v in vals.items():
    sql = sql.replace("{%s}" % k, v)
print(sql.strip())
