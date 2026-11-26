"""Truth-label fingerprint check: do the 09 fingerprint checks separate labelled fraud from labelled legit sessions?
  1. python3 truth_fp.py ids-sql --key K --from YYYY-MM-DD --to YYYY-MM-DD [--n 250] > q.sql   (Athena, database_id 2)
  2. python3 truth_fp.py sql --key K --packed '<step-1 cell>' --out q2.sql                    (writes Snowflake SQL, database_id 14)
  3. python3 truth_fp.py save --key K --run D --packed '<step-2 cell>'                        (-> data/truth_fp.json)
  4. python3 truth_fp.py show [--run D]
"""
import argparse, datetime as dt, json, pathlib, sys
HERE = pathlib.Path(__file__).parent
OUT = HERE / "data" / "truth_fp.json"
F = ["n", "verified", "h3", "h1", "font_os_mis", "rig", "no_fonts", "no_fp", "d3d_nonwin", "plat_mis", "top_fontset_n", "top_voices_n", "ja4_h1", "soft_rend"]

p = argparse.ArgumentParser(); sub = p.add_subparsers(dest="cmd", required=True)
a1 = sub.add_parser("ids-sql"); a1.add_argument("--key", required=True); a1.add_argument("--from", dest="f", required=True); a1.add_argument("--to", required=True); a1.add_argument("--n", default="250")
a2 = sub.add_parser("sql"); a2.add_argument("--key", required=True); a2.add_argument("--packed", required=True); a2.add_argument("--out", required=True)
a3 = sub.add_parser("save"); a3.add_argument("--key", required=True); a3.add_argument("--run", required=True); a3.add_argument("--packed", required=True)
a4 = sub.add_parser("show"); a4.add_argument("--run")
a = p.parse_args()

if a.cmd == "ids-sql":
    print((HERE / "sql/11_truth_ids.sql").read_text().format(key=a.key, ts_from=a.f, ts_to=a.to, n=a.n))
elif a.cmd == "sql":
    parts = dict(x.split(":", 1) for x in a.packed.strip().split("#"))
    L = [i for i in parts.get("L", "").split(",") if i]; Fr = [i for i in parts.get("F", "").split(",") if i]
    lo, hi = parts["R"].split(",")
    q = lambda ids: ",".join("'%s'" % i.replace("'", "") for i in ids) or "''"
    t0 = dt.date.fromisoformat(lo[:10]); t1 = dt.date.fromisoformat(hi[:10]) + dt.timedelta(days=1)
    sql = (HERE / "sql/12_truth_fp.sql").read_text().format(key=a.key, legit_ids=q(L), all_ids=q(L + Fr), ts_from=t0, ts_to=t1)
    pathlib.Path(a.out).write_text(sql)
    print("legit ids %d, fraud ids %d, sessions %s .. %s -> %s" % (len(L), len(Fr), t0, t1, a.out))
elif a.cmd == "save":
    db = json.loads(OUT.read_text()) if OUT.exists() else {}
    rec = {}
    for part in filter(None, a.packed.strip().split("#")):
        lab, vals = part.split(":", 1); v = vals.split("|")
        if len(v) != len(F): sys.exit("bad field count %d" % len(v))
        rec["legit" if lab == "L" else "fraud"] = dict(zip(F, map(int, v)))
    db.setdefault(a.run, {})[a.key] = rec
    OUT.write_text(json.dumps(db, indent=1)); print("saved", a.key, {k: r["n"] for k, r in rec.items()})
else:
    db = json.loads(OUT.read_text()) if OUT.exists() else {}
    names = json.loads((HERE / "data/key_names.json").read_text())
    for run in sorted(db):
        if a.run and run != a.run: continue
        for k, rec in db[run].items():
            nm = names.get(k); nm = nm.get("key_name") if isinstance(nm, dict) else (nm or k[:8])
            print("== %s %s" % (run, nm))
            print("   %-8s" % "label" + "".join("%11s" % f[:10] for f in F[1:]))
            for lab, r in rec.items():
                n = max(1, r["n"])
                print("   %-8s" % ("%s %d" % (lab[0].upper(), r["n"])) + "".join("%10.1f%%" % (100.0 * r[f] / n) for f in F[1:]))
