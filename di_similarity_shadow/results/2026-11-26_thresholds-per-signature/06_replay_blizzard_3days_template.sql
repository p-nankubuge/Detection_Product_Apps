-- D-19 per-signature replay, Blizzard ROW Registration K2, replay 9-12 Nov 2026 in ONE scan, with TD Nonlegit labels.
-- Same definitions as 04_replay_per_signature_template.sql, except:
--  * base is per replay day: share(rday, ms) = non-High sessions with ms over [rday-7, rday) / all non-High sessions over that range
--    (from daily counts over 2-10 Nov);
--  * labels: {LABELS} = comma-separated 10-digit suffixes (after the '.') of arkose_session_id for Nonlegit, verified TD labels with
--    session_create_timestamp in [9 Nov, 12 Nov) (Athena export 03_athena_blizzard_label_export.sql, 4 chunks). Joined on
--    RIGHT(session,10) within this key and window; collisions reported in the LABSTAT row.
--  * dy = session day (replaces the Figma slice flag).
--  * extra columns: NEWlab (labelled fires not breached today ST), LOSTlab (labelled today-ST breaches not fired), ver (verified sessions
--    in group), tany / tanylab / tanycl (today ST OR LT breached: sessions / labelled / clean).
-- Output: gp|d|grp|dy|n|cl|F|Fh|Fv|Fc|Fn|Fcl|NEW|LOST|lab|Flab|tl|Fclh|NEWlab|LOSTlab|ver|tany|tanylab|tanycl
WITH lb AS (SELECT DISTINCT VALUE::STRING k FROM TABLE(FLATTEN(SPLIT('{LABELS}', ',')))),
bd AS (SELECT TO_DATE(session_ts) dy, di_matched_signature_at_session_created ms, COUNT(*) c FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key='E8A75615-1CBA-5DFF-8032-D16BCF234E10' AND session_last_timestamp>='2026-11-02' AND session_last_timestamp<'2026-11-12 06:00'
  AND session_ts>='2026-11-02' AND session_ts<'2026-11-11' AND COALESCE(latest_risk_band,'')<>'High' GROUP BY 1,2),
rd AS (SELECT column1::DATE rday FROM VALUES ('2026-11-09'),('2026-11-10'),('2026-11-11')),
sh0 AS (SELECT rday, ms, SUM(c) c FROM bd JOIN rd ON bd.dy>=DATEADD(day,-7,rday) AND bd.dy<rday GROUP BY 1,2),
sh AS (SELECT rday, ms, c/SUM(c) OVER (PARTITION BY rday) share FROM sh0),
a0 AS (SELECT session sid, session_ts ts, di_dictionary_num_matched_at_session_created d, di_matched_signature_at_session_created ms, os_at_session_created os,
  COALESCE(webgl_unmasked_renderer_at_session_created,'') r, COALESCE(cdn__ja4_hash_at_session_created,'') ja4, COALESCE(ua_at_session_created,'') ua,
  IFF(latest_risk_band='High',1,0) hi, IFF(sessions_verified>0,1,0) ver, IFF(was_challenged>0,1,0) chl, IFF(was_challenged>0 AND COALESCE(sessions_solved,0)=0,1,0) chns,
  di_short_term_count_at_session_created stc, IFF(di_short_term_threshold_breached_at_session_created,1,0) stb, IFF(di_long_term_threshold_breached_at_session_created,1,0) ltb,
  TIME_SLICE(session_ts,20,'MINUTE') b20
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY WHERE public_key='E8A75615-1CBA-5DFF-8032-D16BCF234E10' AND session_last_timestamp>='2026-11-08 23:40'
  AND session_last_timestamp<'2026-11-12 06:00' AND session_ts>='2026-11-08 23:40' AND session_ts<'2026-11-12'),
bc AS (SELECT b20, COUNT(*) bn FROM a0 GROUP BY 1),
a1 AS (SELECT a0.*, COUNT(*) OVER (PARTITION BY a0.b20 ORDER BY ts, sid ROWS UNBOUNDED PRECEDING) + COALESCE(p.bn,0) vol
  FROM a0 LEFT JOIN bc p ON p.b20 = DATEADD(minute,-20,a0.b20)),
s1 AS (SELECT a1.*, CASE WHEN r ILIKE '%SwiftShader%' OR r ILIKE '%llvmpipe%' OR r ILIKE '%VirtualBox%' OR r ILIKE '%VMware%' THEN 'A'
  WHEN r ILIKE '%Basic Render Driver%' AND COALESCE(os,'')<>'Windows' THEN 'B' WHEN COALESCE(os,'') IN ('','--') AND r<>'' THEN 'B'
  WHEN ja4 LIKE 't%' AND SPLIT_PART(ja4,'_',2) IN ('a09f3c656075','2802a3db6c62') AND os IN ('Windows','GNU/Linux','Ubuntu','Chrome OS') THEN 'C'
  WHEN ua LIKE '%Chrome/%' AND RIGHT(SPLIT_PART(ja4,'_',1),2)='h1' THEN 'C' WHEN TRY_TO_NUMBER(REGEXP_SUBSTR(ua,'Chrome/([0-9]+)',1,1,'e',1))>=70 AND ja4 LIKE 't12%' THEN 'C' END AS x,
  CASE WHEN r ILIKE '%Basic Render Driver%' AND os='Windows' THEN 'WinRDVM' WHEN os IN ('Windows','OS X','Chrome OS') THEN 'Desktop' WHEN os IN ('iOS','iPadOS','Android') THEN 'Mobile'
  WHEN os IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'Other' END AS grp0,
  COALESCE(sh.share,0) share, CASE WHEN d IN (1,3) THEN 1 WHEN d=7 THEN 1.5 ELSE 2 END dfac, TO_DATE(a1.ts) dy, lb.k
  FROM a1 LEFT JOIN sh ON sh.ms=a1.ms AND sh.rday=TO_DATE(a1.ts) LEFT JOIN lb ON lb.k=RIGHT(a1.sid,10)
  WHERE a1.ts>='2026-11-09' AND a1.d IS NOT NULL),
s2 AS (SELECT s1.*, IFF(x IS NULL, grp0, 'SKIP_'||x) grp, IFF(x IS NULL AND ms IS NOT NULL AND d>0, 1, 0) elig, IFF(k IS NULL,0,1) lab,
  IFF(SUM(hi) OVER (PARTITION BY x, grp0, ms, TIME_SLICE(ts,40,'MINUTE')) / COUNT(*) OVER (PARTITION BY x, grp0, ms, TIME_SLICE(ts,40,'MINUTE')) < 0.2, 1, 0) cl,
  GREATEST(stb,ltb) tany FROM s1),
gr(gp,m,f) AS (SELECT * FROM VALUES (1,2,5),(2,5,5),(3,10,5),(4,20,5),(5,2,11),(6,5,11),(7,10,11),(8,20,11),(0,0,0)),
x AS (SELECT gp, d, grp, dy, hi, ver, chl, chns, cl, lab, stb, ltb, tany,
  IFF(gp=0, stb, IFF(elig=1 AND stc > GREATEST(f, share*vol*m*dfac), 1, 0)) fi FROM s2 CROSS JOIN gr)
SELECT gp||'|'||COALESCE(d::STRING,'ALL')||'|'||COALESCE(grp,'ALL')||'|'||COALESCE(dy::STRING,'ALL')||'|'||COUNT(*)||'|'||SUM(cl)||'|'||SUM(fi)||'|'||SUM(fi*hi)||'|'||SUM(fi*ver)||'|'||SUM(fi*chl)||'|'||SUM(fi*chns)
  ||'|'||SUM(fi*cl)||'|'||SUM(fi*(1-stb))||'|'||SUM(stb*(1-fi))||'|'||SUM(lab)||'|'||SUM(fi*lab)||'|'||SUM(ltb)||'|'||SUM(fi*cl*hi)
  ||'|'||SUM(fi*lab*(1-stb))||'|'||SUM(stb*lab*(1-fi))||'|'||SUM(ver)||'|'||SUM(tany)||'|'||SUM(tany*lab)||'|'||SUM(tany*cl) r
FROM x GROUP BY GROUPING SETS ((gp, d, grp), (gp, dy), (gp)) HAVING {HAVING}
UNION ALL SELECT 'LABSTAT|labels '||(SELECT COUNT(*) FROM lb)||'|matched sessions '||COUNT(*)||'|distinct labels matched '||COUNT(DISTINCT k)
  ||'|in skip groups '||COUNT_IF(x IS NOT NULL)||'|no matched signature '||COUNT_IF(ms IS NULL OR d<=0)||'|not verified '||COUNT_IF(ver=0) FROM s2 WHERE k IS NOT NULL
ORDER BY 1;
-- Runs: 06a validation (output raw/06a_blizzard_totals_nolabels.txt); 06b coverage check with the label chunk whose suffix ends in '04'
-- (758 labels, {HAVING} = d IS NULL AND dy IS NULL; raw/06b_blizzard_label_coverage_chunk04.txt).
-- Validation run (06a): {LABELS} = '', {HAVING} = d IS NULL (per-day and total rows only).
-- Final run (06b): {HAVING} = gp=0 OR SUM(fi)>0 OR d IS NULL.
