# Generator for the confirm run's main query (one per 6-hour chunk of 6 Nov). Readable SQL -> q1_main_<chunk>.sql (results folder);
# executed (minified, unused intermediate columns dropped, res CTE removed) -> $SCRATCH/q1_main_<chunk>_min.sql.
import sys, os, csv
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build import build, minify, R
from slim import slim_exec, drop_items
SP=os.environ.get('SCRATCH','/tmp/')
KEY="A207F8A1-ED09-4325-ACE6-C8E26A458FBA"
CUTS_V4={'CUT_UADP_C':'1e-12','CUT_UADP_X':'1e-12','CUT_SCRDP_C':"IFF(s.pg = 'Mobile', 1e-4, 1e-12)",'CUT_SCRDP_X':'1e-12',
         'CUT_SCRGL':'1e-12','CUT_SCRPG':"IFF(s.pg = 'Mobile', 1e-4, 1e-12)"}
WL=f"""SELECT di_highest_signature_at_session_created AS h, COUNT(*) AS n
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key IN ('{KEY}','955D26AF-E956-4106-A4EF-2F63304776D9')
    AND session_last_timestamp >= '2026-10-30 00:00:00' AND session_last_timestamp < '2026-11-06 06:00:00'
    AND session_ts >= '2026-10-30 00:00:00' AND session_ts < '2026-11-06 00:00:00'
    AND di_dictionary_num_matched_at_session_created = 63
  GROUP BY 1"""
def sess(t0,t1,tl):
    return f"""SELECT s.session, s.di_dictionary_num_matched_at_session_created AS d, s.di_highest_signature_at_session_created AS h,
    s.latest_risk_band AS risk, (s.sessions_verified > 0) AS verified, (s.sessions_verify_attempted > 0) AS va,
    (s.was_challenged > 0) AS ch, (s.sessions_solved > 0) AS solved, lab.l AS lab
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY s LEFT JOIN lab ON lab.k = LEFT(s.session,3)||RIGHT(s.session,10)
  WHERE s.public_key = '{KEY}'
    AND s.session_last_timestamp >= '{t0}' AND s.session_last_timestamp < '{tl}'
    AND s.session_ts >= '{t0}' AND s.session_ts < '{t1}'"""
O="COUNT(*)||'|'||COUNT_IF(risk='High')||'|'||COUNT_IF(verified)||'|'||COUNT_IF(ch)||'|'||COUNT_IF(ch AND NOT COALESCE(solved,FALSE))"
H="COUNT(*)||'|'||COUNT_IF(risk='High')"
G=(", g AS (SELECT r.session, r.d, r.risk, r.verified, r.ch, r.solved, COALESCE(r.lab,'-') AS lab, t.*, IFF(t.pg='Mobile','mob','desk') AS md,"
   " IFF(band4='no score','n',band4) AS b0, IFF(band_abc='no score','n',band_abc) AS b1, (t4v AND NOT no_score) AS tr0, (tabc AND NOT no_score) AS tr1, IFF(g_ua_dp AND NOT mob2,'a','')||IFF(nwarn_c>=2 AND NOT mob2,'b','') AS ab,"
   " ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(CASE MOD(code3,3) WHEN 1 THEN 'JA4qt' WHEN 0 THEN 'JA4' END, CASE MOD(FLOOR(code3/3),3) WHEN 1 THEN 'UAmaj' WHEN 0 THEN 'UA' END,"
   " IFF(MOD(FLOOR(code3/9),2)=0,'SCR',NULL), IFF(MOD(FLOOR(code3/18),2)=0,'DP',NULL), IFF(MOD(FLOOR(code3/36),2)=0 AND NOT basic,'GL',NULL)),'+') AS diff,"
   " ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(g_ua_dp,'UAxDP',NULL), IFF(h_scr_dp,'SCRxDP',NULL), IFF(h_scr_gl,'SCRxGL',NULL), IFF(h_scr_pg,'SCRxPG',NULL), IFF(p_dp_new AND mob2,'DPnew',NULL)),' ') AS fl,"
   " ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(h_w_scr AND NOT mob2,'SCRnew',NULL), IFF(p_dp_new AND NOT mob2,'DPnew',NULL), IFF(r_ua_dp,'UAxDPr',NULL), IFF(r_scr_dp,'SCRxDPr',NULL), IFF(r_scr_gl,'SCRxGLr',NULL), IFF(r_scr_pg,'SCRxPGr',NULL)),' ') AS wn"
   " FROM sess_raw r JOIN t ON t.h = r.h)\n")
SEC=[
 ("M","(SELECT COUNT(*) FROM lab)||'|'||COUNT_IF(lab<>'-')||'|'||COUNT_IF(lab='L')||'|'||COUNT_IF(lab='N')||'|'||COUNT(*)||'|'||COUNT_IF(verified)", None),
 ("X","d||'|'||b0||b1||'|'||lab||'|'||"+O, "d, b0, b1, lab"),
 ("G3","md||'|'||IFF(tr0,'D','p')||IFF(tr1,'D','p')||'|'||lab||'|'||"+H, "md, tr0, tr1, lab"),
 ("G1","d||'|'||dg||'|'||COUNT(*)||'|'||COUNT_IF(b0 IN ('A','B'))||'|'||COUNT_IF(b1 IN ('A','B'))||'|'||COUNT_IF(risk='High')", "d, dg"),
 ("ADD","md||'|'||ab||'|'||fl||'|'||nwarn_c||'|'||lab||'|'||"+H, "md, ab, fl, nwarn_c, lab"),
 ("WF","md||'|f'||nf2||'|w'||nw3||'|'||lab||'|'||"+H, "md, nf2, nw3, lab"),
]
WHERE={"G1":"d IN (1,3)","ADD":"b0<>'D' AND b1='D'","WF":"NOT no_score"}
def sec(name,expr,grp):
    w=(" WHERE "+WHERE[name]) if name in WHERE else ""
    if grp is None: return f"SELECT '{name}#'||{expr} AS r FROM g"
    return f"SELECT '{name}#'||LISTAGG(x,';') WITHIN GROUP (ORDER BY x) FROM (SELECT {expr} AS x FROM g{w} GROUP BY {grp})"
G=G.replace(" FROM sess_raw r JOIN t ON t.h = r.h)\n", ", IFF(diff LIKE '%+%','multi',diff) AS dg, LEAST(nfail,2) AS nf2, LEAST(nwarn4,3) AS nw3 FROM sess_raw r JOIN t ON t.h = r.h)\n")
TAIL=G+"SELECT r FROM (\n"+"\nUNION ALL ".join(sec(*x) for x in SEC)+"\n) ORDER BY r\n"
HDR="""-- Similarity confirm run (D-20 trigger on a second window with truth data). Key: Figma Registration K2 (A207F8A1-...), not a proxy key.
-- Sessions created 2026-11-06 {a} to {b} UTC, ALL sessions (no sampling). Whitelist (D-12): distinct Dict 63 signatures with session counts,
-- sessions created 2026-10-30 00:00 to 2026-11-06 00:00 UTC, UNCLEANED, Figma account production keys: Registration Production K2
-- (A207F8A1-...) and Login Production 1 (955D26AF-...); development keys excluded. Core = _core_template_v4.sql (unchanged from v4).
-- T0 = v4 trigger (band4, t4v); T1 = D-20 a+b+c (band_abc, tabc). Main v4 cut-offs.
-- Truth data: Athena starfleet_production.truth_data_history labels for sessions created in this chunk (labels_2026-11-06.csv), inlined as
-- 13-char keys (first 3 chars + last 10 chars of the session ID; unique among all 6 Nov sessions) + L (Legit) / N (Nonlegit).
-- Output: one row per section, 'NAME#' then items joined by ';' (fields pipe-delimited):
--   M|labels in chunk|labels matched|matched Legit|matched Nonlegit|sessions|verified sessions
--   X|today dict|T0 band T1 band (2 letters, 'n' = no score)|label (L/N/-)|n|High|verified|challenged|challenged not solved
--   G3|desk/mob|T0 trigger D/p + T1 trigger D/p|label|n|High
--   G1|dict (1/3)|single field differing from the closest device ('multi' = 2+ fields, '' = none)|n|T0 A/B|T1 A/B|High
--   ADD|desk/mob|T1 part that fired (a = coarse UAxDP never seen, b = 2+ warnings)|failed checks|warning signs counted by T1 (incl. SCRxGL moved)|label|n|High  (T0 not D, T1 D)
--   WF|desk/mob|failed checks (0-2+)|warning signs (0-3+, T0 view)|label|n|High
"""
def main(chunks):
    rows=list(csv.DictReader(open(R+'labels_2026-11-06.csv')))
    for name,(h0,h1) in chunks.items():
        cs=[r for r in rows if h0//2 <= int(r['chunk2h']) < (h1+1)//2]  # 2-hour label chunks overlapping the window (labels outside the window simply do not match)
        tok=','.join(r['session'][:3]+r['session'][-10:]+r['label'][0] for r in cs)
        pre=f"lab AS (SELECT LEFT(value,13) AS k, RIGHT(value,1) AS l FROM TABLE(SPLIT_TO_TABLE('{tok}', ','))),\n"
        t0=f"2026-11-06 {h0:02d}:00:00"; t1=f"2026-11-0{6+h1//24} {h1%24:02d}:00:00"
        tl=f"2026-11-07 {min(h1,24)%24+6:02d}:00:00" if h1>=18 else f"2026-11-07 06:00:00"
        tl="2026-11-07 06:00:00"
        sql=HDR.format(a=f"{h0:02d}:00",b=f"{h1:02d}:00")+build(pre, sess(t0,t1,tl), WL, TAIL, CUTS_V4)
        open(R+f'q1_main_{name}.sql','w').write(sql)
        m=minify(sql); i=m.index(", res AS ("); j=m.index(" FROM sess_raw r JOIN t ON t.h = r.h )",i)
        m=m[:i]+m[j+len(" FROM sess_raw r JOIN t ON t.h = r.h )"):]
        m=slim_exec(m)
        # further drops for this run (columns not used by T0/T1 or the outputs; logic of every reported column unchanged)
        m=drop_items(m,['band_v1','t0','n0','band','t3','nwarn','nxw','x_ua_dp','x_scr_dp','band_a','band_b','band_c','ta','tb','tc',
                        'f_ua_dp','f_scr_dp','f_scr_gl','f_scr_os','f_osv','f_dp_new','w_scr0','sb','code','score','pk','pk_v2'])
        m=m.replace(", omx AS (SELECT osf, MAX(osv_num) AS mx FROM wl GROUP BY osf)","").replace(" LEFT JOIN omx o ON o.osf = s.osf","")
        m='EXECUTE IMMEDIATE $$'+m+'$$'
        open(SP+f'q1_main_{name}_min.sql','w').write(m); print(name,len(cs),len(m))
if __name__=='__main__':
    main({'00-06':(0,6),'06-09':(6,9),'09-12':(9,12),'12-15':(12,15),'15-18':(15,18),'18-24':(18,24)})
