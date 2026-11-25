import sys
sys.path.insert(0,'.')
from build import build, minify, R
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
HDR="""-- Layer 1 v3. Key: Figma Registration K2 (A207F8A1-ED09-4325-ACE6-C8E26A458FBA), not a proxy key.
-- Sessions created 2026-11-20 12:00-14:00 UTC, ALL sessions (no sampling). Whitelist (D-12): distinct Dict 63 signatures,
-- sessions created 2026-11-13 00:00 to 2026-11-20 00:00 UTC, UNCLEANED, on the Figma account (23454) production keys:
-- Registration Production K2 (A207F8A1-...) and Login Production 1 (955D26AF-...). Development keys 98F60B6F-... and
-- 4193E70F-... excluded. Core = _core_template_v3.sql. Output: one pipe-delimited string per row (small Superset response).
"""
O="COUNT(*)||'|'||COUNT_IF(risk='High')||'|'||COUNT_IF(verified)||'|'||COUNT_IF(ch)||'|'||COUNT_IF(ch AND NOT COALESCE(solved,FALSE))"
G=", g AS (SELECT res.*, IFF(pg='Mobile','mob','desk') AS md2, IFF(mobile,'mob','desk') AS md1 FROM res)\n"
q1=G+f"""SELECT r FROM (
SELECT 'X3|'||d||'|'||band||'|'||{O}||'|'||ROUND(AVG(score3),3) AS r FROM g GROUP BY d, band
UNION ALL SELECT 'X2|'||d||'|'||band_v2||'|'||COUNT(*)||'|'||COUNT_IF(risk='High') FROM g GROUP BY d, band_v2
UNION ALL SELECT 'G3v1|'||md1||'|'||IFF(t0,'Dchk','pass')||'|'||{O} FROM g GROUP BY md1, t0
UNION ALL SELECT 'G3v2|'||md2||'|'||IFF(t4,'Dchk','pass')||'|'||{O} FROM g GROUP BY md2, t4
UNION ALL SELECT 'G3v3|'||md2||'|'||IFF(t3,'Dchk','pass')||'|'||{O} FROM g GROUP BY md2, t3
UNION ALL SELECT 'MV|'||IFF(band<>band_v2,'moved','same')||'|'||IFF(band='D' AND band_v2<>'D','intoD',IFF(band_v2='D' AND band<>'D','outD','other'))||'|'||{O} FROM g GROUP BY IFF(band<>band_v2,'moved','same'), IFF(band='D' AND band_v2<>'D','intoD',IFF(band_v2='D' AND band<>'D','outD','other'))
UNION ALL SELECT 'SC|'||SIGN(score3-score)||'|'||IFF(sb3<>sb,'scoreband changed','same scoreband')||'|'||IFF(band<>band_v2,'band changed','same band')||'|'||{O} FROM g GROUP BY SIGN(score3-score), IFF(sb3<>sb,'scoreband changed','same scoreband'), IFF(band<>band_v2,'band changed','same band')
UNION ALL SELECT 'D15|'||band||'|'||reason||'|'||{O} FROM g WHERE d=15 AND band_v1='D' AND chk_v1='chk:UAxDP SCRxDP' GROUP BY band, reason
UNION ALL SELECT 'OSV|'||COALESCE(line,'-')||'|'||osv_status||'|'||{O} FROM g GROUP BY line, osv_status
UNION ALL SELECT 'FRZ|'||line||'|'||top_osv||'|'||ROUND(top_share,4)||'|'||mx FROM lmx
UNION ALL SELECT 'NOSC|'||COUNT_IF(no_score)||'|v2_uanull_half='||COUNT_IF(ua_bm IS NULL AND MOD(FLOOR(code/3),3)=1)||'|v3_uanull_half='||COUNT_IF(NOT ub_ok AND MOD(FLOOR(code3/3),3)=1)||'|v3_unparsed_ua_exact='||COUNT_IF(NOT ub_ok AND MOD(FLOOR(code3/3),3)=2)||'|unparsed_ua_sessions='||COUNT_IF(NOT ub_ok)||'|score_changed='||COUNT_IF(score3<>score)||'|score1_changed='||COUNT_IF(score1<>score) FROM g
) ORDER BY r
"""
q2=G+f"""SELECT r FROM (
SELECT 'FL|'||d||'|'||band_v2||'>'||band||'|'||cause3||'|'||{O} AS r FROM g WHERE band<>band_v2 GROUP BY d, band_v2, band, cause3
UNION ALL SELECT 'WF|'||md2||'|f'||LEAST(nfail,2)||'|w'||LEAST(nwarn,3)||'|'||{O} FROM g WHERE NOT no_score GROUP BY md2, LEAST(nfail,2), LEAST(nwarn,3)
UNION ALL SELECT 'WX|'||md2||'|f'||LEAST(nfail,2)||'|x'||nxw||'|'||{O} FROM g WHERE NOT no_score GROUP BY md2, LEAST(nfail,2), nxw
UNION ALL SELECT 'PG|'||pg||'|'||osf||'|'||band||'|'||{O} FROM g GROUP BY pg, osf, band
) ORDER BY r
"""
q3a=G+f"""SELECT r FROM (
SELECT 'RS|'||d||'|'||band||'|'||reason||'|'||{O} AS r FROM g WHERE band<>agree_band GROUP BY d, band, reason
QUALIFY ROW_NUMBER() OVER (PARTITION BY d, band ORDER BY COUNT(*) DESC, reason) <= 5
) ORDER BY r
"""
q3b=G+f"""SELECT r FROM (
SELECT 'FC|'||cause3||'|'||band_v2||'>'||band||'|'||COALESCE(reason_v2,'')||' => '||reason||'|'||{O} AS r FROM g WHERE band<>band_v2 GROUP BY cause3, band_v2, band, reason_v2, reason
QUALIFY ROW_NUMBER() OVER (PARTITION BY cause3 ORDER BY COUNT(*) DESC) <= 8
UNION ALL SELECT 'FW|'||md2||'|'||IFF(t3,'D','notD')||'|'||fails3||'|'||warns3||'|'||{O} FROM g WHERE NOT no_score AND (fails3<>'' OR warns3 LIKE '%x%') GROUP BY md2, t3, fails3, warns3
QUALIFY ROW_NUMBER() OVER (PARTITION BY md2 ORDER BY COUNT(*) DESC) <= 22
UNION ALL SELECT 'D15W|'||band||'|'||fails3||'|'||warns3||'|'||{O} FROM g WHERE d=15 AND band_v1='D' AND chk_v1='chk:UAxDP SCRxDP' GROUP BY band, fails3, warns3
) ORDER BY r
"""
for name,tail,desc in [('q1_crosstab_gates',q1,'-- Q1: v3/v2/v1 crosstabs, G3 v1/v2/v3, moved vs same, score changes, Dict 15 subgroup, OS version, frozen test, null-fix counts.\n'),
                       ('q2_flow_warnings',q2,'-- Q2: v2 -> v3 flow by cause, High risk by failed checks x warning signs (all and exact-pair-only), platform groups.\n'),
                       ('q3a_reasons',q3a,'-- Q3a: top 5 v3 reasons per moved cell (v3 band differs from the agree band of today\'s dict).\n'),
                       ('q3b_flow_checks',q3b,'-- Q3b: top 8 v2 -> v3 reason pairs per cause; top 22 failed-check x warning combos per mobile/desktop; Dict 15 subgroup checks.\n')]:
    sql=HDR+desc+build('', SESS, WL, tail)
    open(R+name+'.sql','w').write(sql)
    m='EXECUTE IMMEDIATE $$'+minify(sql)+'$$'
    open(name+'_min.sql','w').write(m); print(name,len(m))
