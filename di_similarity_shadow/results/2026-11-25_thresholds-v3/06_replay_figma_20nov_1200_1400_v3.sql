-- v3 (D-13) replay SLICE 2026-11-20 12:00-14:00 UTC (session_last_timestamp 12:00 to 21 Nov 06:00), Figma K2, all four variants. Otherwise identical to 05_. Identical to v2 04_replay_figma_20nov_v2.sql (window, filters,
-- List A/B/C, platform groups, clean flag, DI's own recorded counts, today = DI_SHORT_TERM_THRESHOLD_BREACHED / LT breached) except:
-- thr has one ST/LT pair per variant (02_build_matrices_v3.py figma), and rows are unpivoted per variant v (0..3).
-- Window: sessions created {T0} to {T1} UTC (full day 2026-11-20 00:00 - 2026-11-21 00:00; slice = 06_ uses 12:00-14:00).
-- new fire (variant v) = ST count > ST_v OR LT count > LT_v; List A/B/C sessions get no new threshold (thr NULL -> 0).
-- Output: v|d|grp|n|hi%|cl|T|clean T|NA n/High%/ver%/chall%/chall-not-solved%|NL|NEWONLY n/High%|TODAYONLY|CLEAN_NA
WITH thr(k,d,grp,st0,lt0,st1,lt1,st2,lt2,st3,lt3) AS (SELECT * FROM VALUES ('FIGMA',-1,'Desktop',11,660,11,660,11,660,11,660),('FIGMA',-1,'Mobile',11,660,11,660,11,660,11,660),('FIGMA',-1,'Linux',11,660,11,660,11,660,11,660),('FIGMA',-1,'WinRDVM',11,660,11,660,11,660,11,660),('FIGMA',-1,'Other',11,660,11,660,11,660,11,660),('FIGMA',1,'Desktop',7.49,449.4,7.49,449.4,11,660,11,660),('FIGMA',1,'Mobile',7.49,449.4,7.49,449.4,11,660,11,660),('FIGMA',1,'Linux',7.49,449.4,7.49,449.4,11,660,11,660),('FIGMA',1,'WinRDVM',7.49,449.4,7.49,449.4,11,660,11,660),('FIGMA',1,'Other',7.49,449.4,7.49,449.4,11,660,11,660),('FIGMA',3,'Desktop',7.0,420.0,7.0,420.0,12.0,720.0,12.0,720.0),('FIGMA',3,'Mobile',9.0,540.0,9.0,540.0,12.0,720.0,12.0,720.0),('FIGMA',3,'Linux',6.0,360.0,6.0,360.0,9.4,564.0,9.4,564.0),('FIGMA',3,'WinRDVM',5.0,300.0,5.0,300.0,7.0,420.0,7.0,420.0),('FIGMA',3,'Other',8.0,480.0,8.0,480.0,11,660,11,660),('FIGMA',7,'Desktop',6.0,480.0,7.5,600,12.0,960.0,12.0,960.0),('FIGMA',7,'Mobile',3.0,240.0,7.5,600,9.78,782.4,9.78,782.4),('FIGMA',7,'Linux',6.0,480.0,7.5,600,10.37,829.2,10.37,829.2),('FIGMA',7,'WinRDVM',6.0,480.0,7.5,600,13.65,1092.0,13.65,1092.0),('FIGMA',7,'Other',6.0,480.0,7.5,600,11,660,11,660),('FIGMA',15,'Desktop',6.0,720.0,10,1200,16.0,1920.0,16.0,1920.0),('FIGMA',15,'Mobile',6.0,720.0,10,1200,10.0,1200.0,10.0,1200.0),('FIGMA',15,'Linux',6.0,720.0,10,1200,10.0,1200.0,10.0,1200.0),('FIGMA',15,'WinRDVM',6.0,480.0,7.5,600,9.0,720.0,9.0,720.0),('FIGMA',15,'Other',6.0,660,10,660,11,660,11,660),('FIGMA',31,'Desktop',6.0,720.0,10,1200,14.0,1680.0,14.0,1680.0),('FIGMA',31,'Mobile',4.0,480.0,10,1200,8.34,1000.8,10,1200),('FIGMA',31,'Linux',6.0,720.0,10,1200,11.82,1418.4,11.82,1418.4),('FIGMA',31,'WinRDVM',4.5,360.0,7.5,600,12.03,962.4,12.03,962.4),('FIGMA',31,'Other',6.0,660,10,660,11,660,11,660),('FIGMA',63,'Desktop',8.0,1440.0,10,1800,18.0,3240.0,18.0,3240.0),('FIGMA',63,'Mobile',10.0,1800.0,10.0,1800.0,16.0,2880.0,16.0,2880.0),('FIGMA',63,'Linux',6.0,1080.0,10,1800,13.1,2358.0,13.1,2358.0),('FIGMA',63,'WinRDVM',6.0,480.0,7.5,600,12.0,960.0,12.0,960.0),('FIGMA',63,'Other',8.0,660,10,660,11,660,11,660)),
s0 AS (SELECT session_ts ts, di_dictionary_num_matched_at_session_created d, di_matched_signature_at_session_created ms, os_at_session_created os,
  COALESCE(webgl_unmasked_renderer_at_session_created,'') r, COALESCE(cdn__ja4_hash_at_session_created,'') ja4, COALESCE(ua_at_session_created,'') ua,
  IFF(latest_risk_band='High',1,0) hi, IFF(sessions_verified>0,1,0) ver, IFF(was_challenged>0,1,0) chl, IFF(was_challenged>0 AND COALESCE(sessions_solved,0)=0,1,0) chns,
  di_short_term_count_at_session_created stc, di_long_term_count_at_session_created ltc,
  IFF(di_short_term_threshold_breached_at_session_created,1,0) stb, IFF(di_long_term_threshold_breached_at_session_created,1,0) ltb
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY WHERE public_key='A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
  AND session_last_timestamp>='2026-11-20 12:00' AND session_last_timestamp<'2026-11-21 06:00' AND session_ts>='2026-11-20 12:00' AND session_ts<'2026-11-20 14:00'
  AND di_dictionary_num_matched_at_session_created IS NOT NULL),
s1 AS (SELECT s0.*, CASE WHEN r ILIKE '%SwiftShader%' OR r ILIKE '%llvmpipe%' OR r ILIKE '%VirtualBox%' OR r ILIKE '%VMware%' THEN 'A'
  WHEN r ILIKE '%Basic Render Driver%' AND COALESCE(os,'')<>'Windows' THEN 'B' WHEN COALESCE(os,'') IN ('','--') AND r<>'' THEN 'B'
  WHEN ja4 LIKE 't%' AND SPLIT_PART(ja4,'_',2) IN ('a09f3c656075','2802a3db6c62') AND os IN ('Windows','GNU/Linux','Ubuntu','Chrome OS') THEN 'C'
  WHEN ua LIKE '%Chrome/%' AND RIGHT(SPLIT_PART(ja4,'_',1),2)='h1' THEN 'C' WHEN TRY_TO_NUMBER(REGEXP_SUBSTR(ua,'Chrome/([0-9]+)',1,1,'e',1))>=70 AND ja4 LIKE 't12%' THEN 'C' END AS x,
  CASE WHEN r ILIKE '%Basic Render Driver%' AND os='Windows' THEN 'WinRDVM' WHEN os IN ('Windows','OS X','Chrome OS') THEN 'Desktop' WHEN os IN ('iOS','iPadOS','Android') THEN 'Mobile'
  WHEN os IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'Other' END AS grp0 FROM s0),
s2 AS (SELECT s1.*, IFF(x IS NULL, grp0, 'SKIP_'||x) grp, IFF(x IS NULL AND SUM(hi) OVER (PARTITION BY x, grp0, ms, TIME_SLICE(ts,40,'MINUTE')) / COUNT(*) OVER (PARTITION BY x, grp0, ms, TIME_SLICE(ts,40,'MINUTE')) < 0.2, 1, 0) cl FROM s1),
f AS (SELECT s2.d, s2.grp, hi, ver, chl, chns, cl, stb t, ltb tl, v.column1 v,
  IFF(stc > CASE v.column1 WHEN 0 THEN st0 WHEN 1 THEN st1 WHEN 2 THEN st2 ELSE st3 END, 1, 0) n,
  IFF(ltc > CASE v.column1 WHEN 0 THEN lt0 WHEN 1 THEN lt1 WHEN 2 THEN lt2 ELSE lt3 END, 1, 0) nl
  FROM s2 LEFT JOIN thr ON thr.d=s2.d AND thr.grp=s2.grp CROSS JOIN (SELECT column1 FROM VALUES (0),(1),(2),(3)) v),
g AS (SELECT f.*, GREATEST(n,nl) na, GREATEST(t,tl) tt FROM f)
SELECT v||'|'||COALESCE(d::STRING,'ALL')||'|'||COALESCE(grp,'ALL')||'|n='||COUNT(*)||'|hi='||ROUND(100*AVG(hi),1)||'|cl='||SUM(cl)||'|T='||SUM(t)||'|clT='||SUM(cl*t)
 ||'|NA='||SUM(na)||'/'||COALESCE(ROUND(100*SUM(na*hi)/NULLIF(SUM(na),0),1)::STRING,'-')||'/'||COALESCE(ROUND(100*SUM(na*ver)/NULLIF(SUM(na),0),1)::STRING,'-')
 ||'/'||COALESCE(ROUND(100*SUM(na*chl)/NULLIF(SUM(na),0),1)::STRING,'-')||'/'||COALESCE(ROUND(100*SUM(na*chns)/NULLIF(SUM(na),0),1)::STRING,'-')
 ||'|NL='||SUM(nl)||'|NEW='||SUM(na*(1-tt))||'/'||COALESCE(ROUND(100*SUM(na*(1-tt)*hi)/NULLIF(SUM(na*(1-tt)),0),1)::STRING,'-')
 ||'|TONLY='||SUM(tt*(1-na))||'|clNA='||SUM(cl*na) r
FROM g GROUP BY GROUPING SETS ((v,d,grp),(v)) HAVING SUM(na)+SUM(t)>0 OR grp IS NULL ORDER BY v, d, grp;
