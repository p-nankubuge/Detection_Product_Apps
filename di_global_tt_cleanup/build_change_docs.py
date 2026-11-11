"""Build per-ticket change documents (DOCX, red FROM / green TO) and paste-ready JSON
for the global Device Intelligence (DI) telltale clean-up.

Inputs : current/<id>.json  (live definitions exported from Dataswan)
Outputs: CHNGE-xxxx_<slug>.docx and CHNGE-xxxx_<slug>.json per ticket

Run: python3 -I build_change_docs.py
"""
import json
import pathlib

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Pt, RGBColor

HERE = pathlib.Path(__file__).resolve().parent
RED = RGBColor(0xC0, 0x00, 0x00)
GREEN = RGBColor(0x00, 0x80, 0x00)
GREY = RGBColor(0x59, 0x59, 0x59)

KEYS = {
    "F7C0768A-A5B0-422A-BC5F-5912456296EE": "Pinterest Registration K2",
    "0F985541-B543-4B29-A098-4BB9B8E9DEF8": "Pinterest Challenge K3",
    "F5675B21-025B-4843-983C-38D86DEB394B": "Pinterest Login K1",
    "7CC24C4A-611B-41C7-9808-B95722C7861C": "Payoneer Registration K1",
    "E3EFEFBF-8DE4-42ED-9E7F-92F35B1FD3CF": "Payoneer CLM Registration K3",
    "56DA9CC0-3C2D-47A7-A8C0-564572D4D008": "Payoneer BLS K4",
    "EE844FC3-499D-4A4D-A643-D7400F0FD4DE": "Payoneer Login K2",
    "825DD2FA-D899-455F-970A-9E2453663EEA": "Hornet Registration iOS K3",
    "26AA6D55-8C04-4BD7-8A71-F66E707C8C42": "Hornet Registration Web K1",
    "4FDBF9EF-B787-48E4-8891-F065A8076184": "Hornet Registration Android K2",
    "42887D34-B283-4723-AD25-26299EB55AC9": "HornetX Registration Web K4",
    "E8A64FAC-C713-4EB4-85D2-7458E3579D31": "Bank of America Beacon Workforce ATM K4",
    "519C70B3-B8F5-427B-827F-D2D54AB25D04": "Bank of America Beacon AuthHub ATM K3",
    "54B78A70-0DD3-455D-BA99-AB5CB14276CF": "Highlight AI Chat Prompt K1",
}
BOFA = "E8A64FAC-C713-4EB4-85D2-7458E3579D31"
BOFA_AUTH = "519C70B3-B8F5-427B-827F-D2D54AB25D04"
HIGHLIGHT = "54B78A70-0DD3-455D-BA99-AB5CB14276CF"
PINTEREST = "F5675B21-025B-4843-983C-38D86DEB394B"
PAYONEER_LOGIN = "EE844FC3-499D-4A4D-A643-D7400F0FD4DE"
DICT3_LIST = [k for k in KEYS if k not in (BOFA, BOFA_AUTH, HIGHLIGHT)]
NEW_KEYS = {BOFA, BOFA_AUTH, HIGHLIGHT}

# id: (dict, window, lower x, upper x or None, excluded keys, ticket)
SPEC = {
    20782: (-1, "ST", 2, None, [BOFA], "CHNGE-6771"),
    20783: (-1, "LT", 2, None, [], "CHNGE-6771"),
    6756: (-1, "ST", 2, 4, [], "CHNGE-6771"),
    6762: (-1, "ST", 4, None, [], "CHNGE-6771"),
    6758: (-1, "LT", 2, 4, [], "CHNGE-6771"),
    6764: (-1, "LT", 4, None, [], "CHNGE-6771"),
    20775: (1, "ST", 2, None, [BOFA], "CHNGE-6771"),
    20776: (1, "ST", 4, None, [BOFA], "CHNGE-6771"),
    20780: (1, "ST", 10, None, [BOFA], "CHNGE-6771"),
    20781: (1, "LT", 2, None, [BOFA], "CHNGE-6771"),
    20772: (3, "ST", 2, None, DICT3_LIST + [BOFA, BOFA_AUTH, HIGHLIGHT], "CHNGE-6773"),
    20773: (3, "ST", 4, None, DICT3_LIST + [BOFA, BOFA_AUTH, HIGHLIGHT], "CHNGE-6773"),
    20774: (3, "LT", 2, None, DICT3_LIST + [BOFA, BOFA_AUTH, HIGHLIGHT], "CHNGE-6773"),
    20768: (7, "ST", 2, None, [PAYONEER_LOGIN, PINTEREST, BOFA], "CHNGE-6772"),
    20769: (7, "ST", 4, None, [BOFA], "CHNGE-6772"),
    20771: (7, "LT", 2, None, [BOFA], "CHNGE-6772"),
    20765: (15, "ST", 2, None, [PAYONEER_LOGIN, BOFA], "CHNGE-6772"),
    20767: (15, "ST", 4, None, [BOFA], "CHNGE-6772"),
    20758: (15, "LT", 2, None, [BOFA], "CHNGE-6772"),
    20751: (31, "ST", 2, None, [], "CHNGE-6772"),
    20756: (31, "ST", 4, None, [], "CHNGE-6772"),
    20757: (31, "LT", 2, None, [], "CHNGE-6772"),
    6755: ([7, 3], "ST", 2, 4, [PAYONEER_LOGIN, PINTEREST], "CHNGE-6797"),
    6761: ([7, 3], "ST", 4, None, [PINTEREST], "CHNGE-6797"),
    6759: ([7, 3], "LT", 2, 4, [PAYONEER_LOGIN, PINTEREST], "CHNGE-6797"),
    6766: ([7, 3], "LT", 4, None, [PAYONEER_LOGIN, PINTEREST], "CHNGE-6797"),
    6754: (15, "ST", 2, 4, [], "CHNGE-6797"),
    6760: (15, "ST", 4, None, [], "CHNGE-6797"),
    6757: (15, "LT", 2, 4, [], "CHNGE-6797"),
    6763: (15, "LT", 4, None, [], "CHNGE-6797"),
}

TICKETS = {
    "CHNGE-6771": ("dict-neg1-dict1", "Global DI telltales: re-enable dict -1 and dict 1 globals at 2x/4x and clean up definitions"),
    "CHNGE-6773": ("dict3", "Global DI telltales: re-enable dict 3 globals at 2x/4x and clean up definitions"),
    "CHNGE-6772": ("dict7-15-31", "Global DI telltales: move dict 7/15/31 from 3x/6x to 2x/4x and clean up definitions"),
    "CHNGE-6797": ("risk-signature", "Global DI telltales: move high/medium-risk signature globals to 2x/4x and clean up definitions"),
}

WHY_ALL = [
    "These global DI telltales were written about four years ago and have not been reviewed since. "
    "After the os_version re-key (ESM-6392) and the Android 17 incident (ESM-7076) we reviewed every definition against how DI actually behaves today.",
    "Every new definition uses the same plain structure: the dictionary, di_called = true, di_success = true, di_is_suspicious = true, "
    "threshold breached = true and a velocity ratio, all ANDed. No nested groups, no duplicate rows.",
    "The old true / \"1\" OR pairs and EXISTS rows are dropped. All DI fields are boolean in the Data Dictionary, so one boolean row checks the same thing. "
    "This also removes the risk of the AND-pair bug that left one telltale (6762) unable to ever fire.",
    "Velocity thresholds follow the DI global policy: base rule at 2x the threshold, high rule at 4x. Below 2x mostly catches normal repeat users.",
]


# ---------------------------------------------------------------- definitions
def row(key, op, value, typ):
    return {"key": key, "operator": op, "value": value, "type": typ}


def leaves(defn):
    for c in defn:
        if "conditions" in c:
            yield from c["conditions"]
        else:
            yield c


def requires_false(defn, key):
    return any(x.get("key") == key and x.get("value") in (False, "0") for x in leaves(defn))


def build(tt_id, cur):
    dict_val, win, lo, hi, excl, _ = SPEC[tt_id]
    d = cur["telltale_definition"]
    w = "short" if win == "ST" else "long"
    o = "long" if win == "ST" else "short"
    rows = []
    if excl:
        rows.append(row("public_key", "TS_NOT_IN", list(dict.fromkeys(excl)), "list[string]"))
    rows.append(row("di_dictionary_num_matched", "TS_IN", dict_val, "list[int]") if isinstance(dict_val, list)
                else row("di_dictionary_num_matched", "TS_EQ", dict_val, "int"))
    rows += [row("di_called", "TS_EQ", True, "boolean"),
             row("di_success", "TS_EQ", True, "boolean"),
             row("di_is_suspicious", "TS_EQ", True, "boolean"),
             row(f"di_{w}_term_threshold_breached", "TS_EQ", True, "boolean")]
    if requires_false(d, f"di_{o}_term_threshold_breached"):
        rows.append(row(f"di_{o}_term_threshold_breached", "TS_EQ", False, "boolean"))
    rows.append(row(f"di_{w}_term_threshold_ratio", "TS_GREATER", round(lo - 0.001, 3), "float"))
    if hi:
        rows.append(row(f"di_{w}_term_threshold_ratio", "TS_LESS", float(hi), "float"))
    for c in d:  # carry over non-DI filters (RingApp, location, Samsung). Brave is dropped.
        if "conditions" not in c and c.get("key") in ("ua", "location", "browser_name"):
            rows.append(c)
    rows.append({"operator": "#INCLUDE", "value": "g-global-telltales-enabled"})
    return rows


# ---------------------------------------------------------------- rendering
OPS = {"TS_EQ": "=", "TS_NOT_EQ": "≠", "TS_GREATER": ">", "TS_LESS": "<", "TS_IN": "in",
       "TS_NOT_IN": "not in", "EXISTS": "exists", "NOT_EXISTS": "is missing",
       "TS_NOT_CONTAINS": "does not contain"}


def fmt_val(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return f"\"{v}\""
    return str(v)


def render_leaf(c):
    if c.get("operator") == "#INCLUDE":
        return f"include {c['value']}"
    k, op, v = c.get("key"), c.get("operator"), c.get("value")
    if k == "public_key" and isinstance(v, list):
        names = [KEYS.get(x, x) for x in dict.fromkeys(v)]
        dup = len(v) - len(set(v))
        extra = f" ({dup} duplicate entries)" if dup else ""
        return f"public_key not in {len(set(v))} keys{extra}: " + ", ".join(names)
    if k == "public_key":
        return f"public_key {OPS.get(op, op)} {KEYS.get(v, v)}"
    if op in ("EXISTS", "NOT_EXISTS"):
        return f"{k} {OPS[op]}"
    return f"{k} {OPS.get(op, op)} {fmt_val(v)}"


def render(defn):
    lines = []
    for c in defn:
        if "conditions" in c:
            inner = f" {c['operator']} ".join(render_leaf(x) for x in c["conditions"])
            lines.append(f"({inner})")
        else:
            lines.append(render_leaf(c))
    return lines


# ---------------------------------------------------------------- reasons
def threshold_text(defn, w):
    lo = hi = None
    breach = False
    for c in defn:
        items = c["conditions"] if "conditions" in c else [c]
        for x in items:
            if x.get("key") == f"di_{w}_term_threshold_ratio":
                v = float(x["value"])
                if x["operator"] in ("TS_GREATER", "TS_EQ"):
                    lo = v if lo is None else max(lo, v)
                elif x["operator"] == "TS_LESS":
                    hi = v
            if x.get("key") == f"di_{w}_term_threshold_breached" and x.get("value") in (True, "1"):
                breach = True
    if lo is None and hi is None:
        return "1x (breach only, no ratio)" if breach else "no ratio condition"
    lo_txt = f"{round(lo + 0.01):g}x" if lo is not None and lo % 1 > 0.9 else (f"{lo:g}x" if lo is not None else "1x")
    return lo_txt + (f" to under {hi:g}x" if hi else "")


def reasons(tt_id, cur, new):
    d = cur["telltale_definition"]
    dict_val, win, lo, hi, excl, _ = SPEC[tt_id]
    w = "short" if win == "ST" else "long"
    out = []
    if any(x.get("key") == "di_dictionary_num_matched" and x.get("value") == -99 for x in leaves(d)):
        out.append("Re-enable: remove the impossible condition (dictionary = -99) added for the os_version release (CHNGE-6580). "
                   "Dictionaries have recovered from the re-key (go confirmed 5 Nov, re-checked 10 Nov).")
    old_t, new_t = threshold_text(d, w), f"{lo}x" + (f" to under {hi}x" if hi else "")
    if old_t != new_t:
        out.append(f"Velocity threshold: {old_t} → {new_t}.")
    if tt_id == 6762:
        out.append("Bug fix: the di_success group was AND (true AND \"1\"), which can never match. "
                   "It fired 0 times on 368 eligible sessions (1–20 Oct).")
    if any("conditions" in c and {x.get('key') for x in c['conditions']} == {"browser_detection_brave"} for c in d):
        out.append("Brave condition removed: it was added years ago when Brave landed in the low dictionaries. Today only 0.37% of Brave "
                   "sessions breach 2x (6.5% for other browsers) and Brave is 1.3% of dict -1/1 traffic (5.8% for others). "
                   "The exclusion no longer prevents false positives (data since 5 Nov, 2% sample).")
    old_keys = set()
    for c in d:
        if c.get("key") == "public_key":
            old_keys |= set(c["value"] if isinstance(c["value"], list) else [c["value"]])
    added = [k for k in dict.fromkeys(excl) if k not in old_keys]
    shared = [k for k in added if k in NEW_KEYS]
    other = [k for k in added if k not in NEW_KEYS]
    if shared:
        out.append("Exclude " + ", ".join(KEYS[k] for k in shared) +
                   ": production keys with shared or high-repeat devices (bank ATMs, chat prompts) that breach velocity on legitimate use "
                   "(e.g. BofA Workforce ATM K4: 77% of its dict 3 traffic at ≥2x).")
    if other:
        out.append("Exclude " + ", ".join(KEYS[k] for k in other) +
                   ": already excluded from the dict 3 and dict 7 globals. Keeps this rule consistent with them (decision 10 Nov).")
    band_moves = {6764: "The 2x to 4x long-term band now sits in 6758.",
                  6766: "The 2x to 4x long-term band now sits in 6759.",
                  6763: "The 2x to 4x long-term band now sits in 6757.",
                  6758: "Covers 2x to 4x; 6764 covers 4x and above.",
                  6759: "Covers 2x to 4x; 6766 covers 4x and above.",
                  6757: "Covers 2x to 4x; 6763 covers 4x and above.",
                  6754: "Covers 2x to 4x; 6760 covers 4x and above.",
                  6755: "Covers 2x to 4x; 6761 covers 4x and above.",
                  6756: "Covers 2x to 4x; 6762 covers 4x and above."}
    if tt_id in band_moves:
        out.append("Band: " + band_moves[tt_id])
    if not any(c.get("operator") == "#INCLUDE" for c in d):
        out.append("Add include g-global-telltales-enabled so the global kill switch applies (it was missing).")
    for c in d:
        if c.get("key") == "public_key" and isinstance(c["value"], list) and len(c["value"]) != len(set(c["value"])):
            out.append("Remove duplicate keys from the exclusion list.")
    if not any(x.get("key") == f"di_{w}_term_threshold_breached" and x.get("value") in (True, "1") for x in leaves(d)):
        out.append(f"Add {w}-term threshold breached = true so the rule states all core checks.")
    out.append("Structure: OR pairs, EXISTS rows and duplicate rows replaced by single boolean rows, all ANDed. Same intent, nothing can widen the match.")
    if cur.get("immediate_non_legit"):
        out.append("Note: this telltale has immediate_non_legit = true (unchanged), so the threshold change directly reduces sessions marked non-legit.")
    return out


def name_note(name, win, lo):
    for tag, mult in (("-1x", 1), ("-4x", 4), ("-5x", 5), ("-10x", 10), ("-2x-", 2)):
        if tag in name:
            if mult != lo:
                return f"NAME NOT CHANGED DUE TO DOWNSTREAM DEPS - RATIO IS {lo}x NOT {mult}x"
            return ""
    return f"RATIO IS {lo}x"


# ---------------------------------------------------------------- docx helpers
def shade(cell, hex_fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), hex_fill)
    tc_pr.append(shd)


def add_lines(cell, title, lines, color, fill):
    shade(cell, fill)
    p = cell.paragraphs[0]
    r = p.add_run(title)
    r.bold = True
    r.font.color.rgb = color
    r.font.size = Pt(10)
    for ln in lines:
        q = cell.add_paragraph()
        q.paragraph_format.space_after = Pt(0)
        rr = q.add_run("• " + ln)
        rr.font.size = Pt(9)
        rr.font.color.rgb = color


def build_doc(ticket, slug, title, items):
    doc = Document()
    st = doc.styles["Normal"]
    st.font.name = "Calibri"
    st.font.size = Pt(10)

    h = doc.add_heading(f"{ticket}: {title}", level=1)
    p = doc.add_paragraph()
    r = p.add_run("Parent: CHNGE-6578 (ESM-6392). Status: deferred, new window to be confirmed. "
                  "Prepared by Detection Product, 11 Nov 2026.")
    r.font.color.rgb = GREY

    doc.add_heading("Why we are changing these telltales", level=2)
    for w in WHY_ALL:
        doc.add_paragraph(w, style="List Bullet")

    lg = doc.add_paragraph()
    lg.add_run("Legend: ").bold = True
    a = lg.add_run("red = current definition (FROM)")
    a.font.color.rgb = RED
    lg.add_run(",  ")
    b = lg.add_run("green = new definition (TO)")
    b.font.color.rgb = GREEN
    lg.add_run(". Paste-ready JSON for each telltale is at the end of this document and in the attached .json file.")

    doc.add_heading("Summary", level=2)
    t = doc.add_table(rows=1, cols=5)
    t.style = "Light Grid Accent 1"
    for i, hdr in enumerate(["ID", "Telltale", "Dict", "From", "To"]):
        t.rows[0].cells[i].text = hdr
    for it in items:
        c = t.add_row().cells
        c[0].text = str(it["id"])
        c[1].text = it["name"]
        c[2].text = str(it["dict"])
        c[3].text = it["from_threshold"]
        c[4].text = it["to_threshold"]
        for run in c[3].paragraphs[0].runs:
            run.font.color.rgb = RED
        for run in c[4].paragraphs[0].runs:
            run.font.color.rgb = GREEN

    doc.add_heading("Changes by telltale", level=2)
    for it in items:
        doc.add_heading(f"{it['id']}  {it['name']}", level=3)
        meta = doc.add_paragraph()
        mr = meta.add_run(f"Last edited {it['last_edited'][:10]} by {it['last_edited_by']}. "
                          f"immediate_non_legit = {str(it['inl']).lower()}.")
        mr.font.color.rgb = GREY
        mr.font.size = Pt(9)
        doc.add_paragraph().add_run("What changes and why").bold = True
        for rsn in it["reasons"]:
            doc.add_paragraph(rsn, style="List Bullet")
        if it["desc"]:
            dp = doc.add_paragraph()
            dp.add_run("telltale_description: ").bold = True
            dp.add_run(it["desc"])
        tbl = doc.add_table(rows=1, cols=2)
        tbl.style = "Table Grid"
        add_lines(tbl.rows[0].cells[0], "FROM (current)", it["from_lines"], RED, "FDECEA")
        add_lines(tbl.rows[0].cells[1], "TO (new)", it["to_lines"], GREEN, "E8F5E9")

    doc.add_page_break()
    doc.add_heading("Appendix: paste-ready JSON (Dataswan → Paste Definition from Clipboard)", level=2)
    for it in items:
        doc.add_paragraph().add_run(f"{it['id']}  {it['name']}").bold = True
        jp = doc.add_paragraph()
        jr = jp.add_run(json.dumps(it["definition"]))
        jr.font.name = "Consolas"
        jr.font.size = Pt(7.5)
        jr.font.color.rgb = GREEN

    doc.add_heading("Implementation and backout", level=2)
    for s in ["Export the current JSON of every telltale in this document before editing (backout copy).",
              "Paste the new definition, update telltale_description as listed, click Validate, then Save. One telltale at a time.",
              "The ground-truth overlap warning (gtop-good-traffic, blizzard5-2captcha) is expected for broad DI globals.",
              "Verify within 4h on dashboards 1714/1715: base rules fire only at ratio ≥ 2x, high rules only at ≥ 4x.",
              "Backout: paste back the exported JSON."]:
        doc.add_paragraph(s, style="List Number")
    out = HERE / f"{ticket}_{slug}.docx"
    doc.save(out)
    return out


def main():
    cur_dir = HERE / "current"
    per_ticket = {t: [] for t in TICKETS}
    for tt_id, spec in SPEC.items():
        cur = json.loads((cur_dir / f"{tt_id}.json").read_text())
        new = build(tt_id, cur)
        dict_val, win, lo, hi, excl, ticket = spec
        w = "short" if win == "ST" else "long"
        per_ticket[ticket].append({
            "id": tt_id, "name": cur["telltale_name"], "dict": dict_val,
            "window": "short-term" if win == "ST" else "long-term",
            "from_threshold": ("OFF (-99); " if any(x.get("value") == -99 for x in leaves(cur["telltale_definition"])) else "")
                              + threshold_text(cur["telltale_definition"], w),
            "to_threshold": f"{lo}x" + (f" to under {hi}x" if hi else ""),
            "inl": cur.get("immediate_non_legit"),
            "last_edited": cur.get("last_edited", ""), "last_edited_by": cur.get("last_edited_by", ""),
            "reasons": reasons(tt_id, cur, new),
            "desc": name_note(cur["telltale_name"], win, lo),
            "from_lines": render(cur["telltale_definition"]),
            "to_lines": render(new),
            "definition": new,
        })
    for ticket, (slug, title) in TICKETS.items():
        items = per_ticket[ticket]
        docx_path = build_doc(ticket, slug, title, items)
        json_path = HERE / f"{ticket}_{slug}.json"
        json_path.write_text(json.dumps({
            "ticket": ticket, "title": title,
            "telltales": [{"id": i["id"], "name": i["name"], "telltale_description": i["desc"],
                           "from_threshold": i["from_threshold"], "to_threshold": i["to_threshold"],
                           "reasons": i["reasons"], "definition": i["definition"]} for i in items],
        }, indent=1))
        print(ticket, len(items), docx_path.name, json_path.name)


if __name__ == "__main__":
    main()
