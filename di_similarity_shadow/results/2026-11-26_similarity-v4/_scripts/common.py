import sys
sys.path.insert(0,'/home/user/Detection_Product_Apps/di_similarity_shadow/results/2026-11-26_similarity-v4/_scripts')
from build import build, minify, R, EPS
SP=__import__('os').environ.get('SCRATCH','/tmp/')
SESS="""SELECT session, di_dictionary_num_matched_at_session_created AS d, di_highest_signature_at_session_created AS h,
    latest_risk_band AS risk, (sessions_verified > 0) AS verified, (sessions_verify_attempted > 0) AS va,
    (was_challenged > 0) AS ch, (sessions_solved > 0) AS solved
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND session_last_timestamp >= '2026-11-20 12:00:00'
    AND session_ts >= '2026-11-20 12:00:00' AND session_ts < '2026-11-20 14:00:00'"""
WL="""SELECT di_highest_signature_at_session_created AS h, COUNT(*) AS n
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key IN ('A207F8A1-ED09-4325-ACE6-C8E26A458FBA','955D26AF-E956-4106-A4EF-2F63304776D9')
    AND session_last_timestamp >= '2026-11-13 00:00:00' AND session_last_timestamp < '2026-11-20 06:00:00'
    AND session_ts >= '2026-11-13 00:00:00' AND session_ts < '2026-11-20 00:00:00'
    AND di_dictionary_num_matched_at_session_created = 63
  GROUP BY 1"""
HDR="""-- Similarity v4. Key: Figma Registration K2 (A207F8A1-ED09-4325-ACE6-C8E26A458FBA), not a proxy key.
-- Sessions created 2026-11-20 12:00-14:00 UTC, ALL sessions (no sampling). Whitelist (D-12, same as v3): distinct Dict 63 signatures
-- with session counts, sessions created 2026-11-13 00:00 to 2026-11-20 00:00 UTC, UNCLEANED, Figma account (23454) production keys:
-- Registration Production K2 (A207F8A1-...) and Login Production 1 (955D26AF-...). Core = _core_template_v4.sql.
-- Output: one pipe-delimited string per row (small Superset response).
"""
O="COUNT(*)||'|'||COUNT_IF(risk='High')||'|'||COUNT_IF(verified)||'|'||COUNT_IF(ch)||'|'||COUNT_IF(ch AND NOT COALESCE(solved,FALSE))"
OS="COUNT(*)||'|'||COUNT_IF(risk='High')"
G=", g AS (SELECT res.*, IFF(pg='Mobile','mob','desk') AS md2, IFF(mobile,'mob','desk') AS md1 FROM res)\n"
def slim(m):
    # drop res text columns not used by v4 outputs (identical logic otherwise): cause3, reason_v2
    def cut(m,a,b):
        i=m.index(a); j=m.index(b,i); return m[:i]+m[j:]
    m=cut(m,", ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(band_v2<>bs1",", IFF(t0, 'chk:'")
    m=cut(m,", IFF(t4, 'chk:'",", ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(g_ua_dp,'UAxDP'")
    return m
def emit(name, desc, tail, cuts=EPS, doslim=True):
    sql=HDR+desc+build('', SESS, WL, tail, cuts)
    open(R+name+'.sql','w').write(sql)
    m=minify(sql)
    if doslim: m=slim(m)
    m='EXECUTE IMMEDIATE $$'+m+'$$'
    open(SP+name+'_min.sql','w').write(m); print(name,len(m))
CUTS_V4={'CUT_UADP_C':'1e-12','CUT_UADP_X':'1e-12',
         'CUT_SCRDP_C':"IFF(s.pg = 'Mobile', 1e-4, 1e-12)",'CUT_SCRDP_X':'1e-12',
         'CUT_SCRGL':'1e-12','CUT_SCRPG':"IFF(s.pg = 'Mobile', 1e-4, 1e-12)"}
def strip_res(m):
    i=m.index(", res AS ("); j=m.index(" FROM sess_raw r JOIN t ON t.h = r.h )",i)
    return m[:i]+m[j+len(" FROM sess_raw r JOIN t ON t.h = r.h )"):]
def emit2(name, desc, tail, cuts=CUTS_V4):
    sql=HDR+desc+build('', SESS, WL, tail, cuts)
    open(R+name+'.sql','w').write(sql)
    m='EXECUTE IMMEDIATE $$'+strip_res(minify(sql))+'$$'
    open(SP+name+'_min.sql','w').write(m); print(name,len(m))
# g: one row per session, built from t (res is not needed); variant columns for uniform cut-offs X (sensitivity)
def unif(tag,X):
    r=lambda f,x: f"({f} > 0 AND ({f} < {X}{' OR COALESCE('+x+' < '+X+', FALSE)' if x else ''}))"
    nr=f"IFF({r('fuc','fux')},1,0)+IFF({r('fsc','fsx')},1,0)+IFF({r('fsg',None)},1,0)+IFF({r('fsp',None)},1,0)"
    return (f"{nr} AS nr{tag}, IFF(mob2, nfail >= 1, nfail >= 2 OR (nfail >= 1 AND nr{tag} + IFF(mob2, 0, IFF(h_w_scr,1,0) + IFF(p_dp_new,1,0)) >= 1)) AS t{tag},"
            f" IFF(t{tag} AND NOT no_score,'D',sb3) AS band{tag}")
G2=(", g AS (SELECT r.session, r.d, r.risk, r.verified, r.ch, r.solved, t.*, IFF(t.pg='Mobile','mob','desk') AS md2, IFF(t.mobile,'mob','desk') AS md1,"
    " (r.d = 15 AND band_v1 = 'D' AND f_ua_dp AND f_scr_dp AND NOT f_scr_gl AND NOT f_scr_os AND NOT f_osv AND NOT f_dp_new AND NOT w_scr0) AS d15g,"
    " CASE WHEN r.d = 63 THEN 1 WHEN r.d IN (31,15) THEN 2 WHEN r.d = 7 THEN 3 ELSE 4 END AS agr,"
    " ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(g_ua_dp,'UAxDP',NULL), IFF(h_scr_dp,'SCRxDP',NULL), IFF(h_scr_gl,'SCRxGL',NULL), IFF(h_scr_pg,'SCRxPG',NULL), IFF(p_dp_new AND mob2,'DPnew',NULL)), ' ') AS fails3,"
    " ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(h_w_scr,'SCRnew',NULL), IFF(p_dp_new AND NOT mob2,'DPnew',NULL), IFF(r_ua_dp,'UAxDPr',NULL), IFF(r_scr_dp,'SCRxDPr',NULL), IFF(r_scr_gl,'SCRxGLr',NULL), IFF(r_scr_pg,'SCRxPGr',NULL)), ' ') AS warns4,"
    " "+unif('U4','1e-4')+", "+unif('U3','1e-3')+
    " FROM sess_raw r JOIN t ON t.h = r.h)\n")
VERS=[('v1','band_v1','t0','md1'),('v2','band_v2','t4','md2'),('v3','band','t3','md2'),('v4','band4','t4v','md2'),
      ('v4a','band_a','ta','md2'),('v4b','band_b','tb','md2'),('v4c','band_c','tc','md2'),('v4abc','band_abc','tabc','md2'),
      ('U1e-4','bandU4','tU4','md2'),('U1e-3','bandU3','tU3','md2')]
V=(", v AS (SELECT g.d, g.risk, g.d15g, g.agr, g.no_score, x.value:v::STRING AS ver, x.value:b::STRING AS bd, x.value:t::BOOLEAN AS tr, x.value:m::STRING AS m,"
   " DECODE(x.value:b::STRING,'A',1,'B',2,'C',3,'D',4,9) AS rk FROM g, LATERAL FLATTEN(ARRAY_CONSTRUCT("+
   ", ".join(f"OBJECT_CONSTRUCT('v','{a}','b',{b},'t',{t},'m',{m})" for a,b,t,m in VERS)+")) x)\n")
# example row: fields of the session's own signature (h) + pair counts (whitelist sessions) for UAxDP c/x, SCRxDP c/x, SCRxGL, SCRxPG
def cnt(f): return f"COALESCE(ROUND({f}*pgn)::VARCHAR,'-')"
EX=("session||'|'||osf||'|'||pg||'|'||osv||'|'||COALESCE(risk,'')||'|'||ROUND(score3,2)||'|'||band||'>'||{B}||'|'||fails3||'|'||warns4||'|'||{EXTRA}||'|'"
    "||LEFT(REPLACE(REPLACE(REPLACE(SPLIT_PART(h,'||',5),'Mozilla/5.0 (',''),'AppleWebKit/537.36 (KHTML, like Gecko) ',''),'AppleWebKit/605.1.15 (KHTML, like Gecko) ',''),55)"
    "||'|'||SPLIT_PART(h,'||',2)||'|'||SPLIT_PART(h,'||',3)||'|'||SPLIT_PART(h,'||',4)||'|'||LEFT(REPLACE(SPLIT_PART(SPLIT_PART(h,'||',6),'::',6),'ANGLE (',''),32)"
    "||'|'||"+"||','||".join(cnt(f) for f in ['fuc','fux','fsc','fsx','fsg','fsp']))
RU4=("TRIM(IFF(fuc > 0 AND (fuc < 1e-4 OR COALESCE(fux < 1e-4, FALSE)),'UAxDPr ','')||IFF(fsc > 0 AND (fsc < 1e-4 OR COALESCE(fsx < 1e-4, FALSE)),'SCRxDPr ','')"
     "||IFF(fsg > 0 AND fsg < 1e-4,'SCRxGLr ','')||IFF(fsp > 0 AND fsp < 1e-4,'SCRxPGr',''))")
