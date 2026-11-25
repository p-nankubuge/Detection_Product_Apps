-- L1, Payoneer proxy keys (EE844FC3, E3EFEFBF, 7CC24C4A), peak window: sessions created 2026-11-18 10:00-14:00 UTC, no sampling (5.1 s).
-- Proxy keys: List C not applied (only List A/B). Thresholds = GLOBAL cells x multipliers (proxy keys are excluded from the global
-- sample; the keys' own 7-day cells were NOT computed). Same g(...) values as 07_known_case_K3_adobe_arp_k8.sql.
WITH g(d,grp,gb,ms,ml) AS (SELECT * FROM VALUES (-1,'Desktop',68.7,1,1),(-1,'Mobile',68.7,1,1),(-1,'Linux',68.7,1,1),(-1,'WinRDVM',68.7,1,1),(-1,'Other',68.7,1,1),(1,'Desktop',35.3,1,1),(1,'Mobile',15.9,1,1),(1,'Linux',35.3,1,1),(1,'WinRDVM',35.3,1,1),(1,'Other',35.3,1,1),(3,'Desktop',104,1,1),(3,'Mobile',21,1,1),(3,'Linux',16.6,1,1),(3,'WinRDVM',16.4,1,1),(3,'Other',68,1,1),(7,'Desktop',29,1.5,2),(7,'Mobile',7,1.5,2),(7,'Linux',30.8,1.5,2),(7,'WinRDVM',10,1.5,2),(7,'Other',25,1.5,2),(15,'Desktop',13,2,4),(15,'Mobile',21,2,4),(15,'Linux',10.1,2,4),(15,'WinRDVM',7,1.5,2),(15,'Other',17,2,4),(31,'Desktop',27,2,4),(31,'Mobile',18,2,4),(31,'Linux',66.5,2,4),(31,'WinRDVM',7,1.5,2),(31,'Other',26,2,4),(63,'Desktop',20,2,6),(63,'Mobile',72,2,6),(63,'Linux',13,2,6),(63,'WinRDVM',20,1.5,2),(63,'Other',16.7,2,6)),
s0 AS (SELECT LEFT(public_key,8) k, di_dictionary_num_matched_at_session_created d, os_at_session_created os,
  COALESCE(webgl_unmasked_renderer_at_session_created,'') r, IFF(latest_risk_band='High',1,0) hi, IFF(sessions_verified>0,1,0) ver,
  di_short_term_count_at_session_created stc, di_long_term_count_at_session_created ltc,
  COALESCE(di_short_term_threshold_ratio_at_session_created,0) str, COALESCE(di_long_term_threshold_ratio_at_session_created,0) ltr,
  IFF(di_short_term_threshold_breached_at_session_created,1,0) stb, IFF(di_long_term_threshold_breached_at_session_created,1,0) ltb
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key IN ('EE844FC3-499D-4A4D-A643-D7400F0FD4DE','E3EFEFBF-8DE4-42ED-9E7F-92F35B1FD3CF','7CC24C4A-611B-41C7-9808-B95722C7861C')
    AND session_last_timestamp>='2026-11-18 10:00' AND session_last_timestamp<'2026-11-18 20:00'
    AND session_ts>='2026-11-18 10:00' AND session_ts<'2026-11-18 14:00' AND di_dictionary_num_matched_at_session_created IS NOT NULL),
s1 AS (SELECT s0.*,
  CASE WHEN r ILIKE '%SwiftShader%' OR r ILIKE '%llvmpipe%' OR r ILIKE '%VirtualBox%' OR r ILIKE '%VMware%' THEN 'A'
       WHEN r ILIKE '%Basic Render Driver%' AND COALESCE(os,'')<>'Windows' THEN 'B' WHEN COALESCE(os,'') IN ('','--') AND r<>'' THEN 'B' END AS x,
  CASE WHEN r ILIKE '%Basic Render Driver%' AND os='Windows' THEN 'WinRDVM' WHEN os IN ('Windows','OS X','Chrome OS') THEN 'Desktop'
       WHEN os IN ('iOS','iPadOS','Android') THEN 'Mobile' WHEN os IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'Other' END AS grp FROM s0),
f AS (SELECT s1.*, g.gb, g.ms, g.ml, IFF(x IS NULL AND (stc>g.gb*g.ms OR ltc>g.gb*g.ml*60),1,0) nag, IFF(x IS NULL AND stc>g.gb*g.ms,1,0) nags
  FROM s1 LEFT JOIN g ON g.d=s1.d AND g.grp=s1.grp)
SELECT COALESCE(k,'ALL')||'|'||COALESCE(d::STRING,'ALL')||'|'||COALESCE(IFF(x IS NULL,grp,'SKIP_'||x),'ALL')||'|n='||COUNT(*)
 ||'|hi='||ROUND(100*AVG(hi),1)||'|ver='||ROUND(100*AVG(ver),1)||'|gST='||COALESCE(MAX(gb*ms)::STRING,'-')||'|gLT='||COALESCE(MAX(gb*ml*60)::STRING,'-')
 ||'|stc_p50/p90/max='||MEDIAN(stc)||'/'||PERCENTILE_DISC(0.9) WITHIN GROUP (ORDER BY stc)||'/'||MAX(stc)||'|ltc_p50/max='||MEDIAN(ltc)||'/'||MAX(ltc)
 ||'|thrST='||COALESCE(ROUND(MEDIAN(stc/NULLIF(str,0)),1)::STRING,'-')||'|thrLT='||COALESCE(ROUND(MEDIAN(ltc/NULLIF(ltr,0)),1)::STRING,'-')
 ||'|T='||SUM(stb)||'/'||COALESCE(ROUND(100*SUM(stb*hi)/NULLIF(SUM(stb),0),1)::STRING,'-')||'/'||COALESCE(ROUND(100*SUM(stb*ver)/NULLIF(SUM(stb),0),1)::STRING,'-')
 ||'|T2='||SUM(IFF(str>=2,1,0))||'|T4='||SUM(IFF(str>=4,1,0))||'|TL='||SUM(ltb)
 ||'|NA='||SUM(nag)||'/'||COALESCE(ROUND(100*SUM(nag*hi)/NULLIF(SUM(nag),0),1)::STRING,'-')||'/'||COALESCE(ROUND(100*SUM(nag*ver)/NULLIF(SUM(nag),0),1)::STRING,'-')||'|NST='||SUM(nags) r
FROM f GROUP BY GROUPING SETS ((k,d,x,grp),(k),()) HAVING COUNT(*)>=20 OR d IS NULL ORDER BY 1;
-- Result (fires: n/High%/verified%). Today's thresholds: EE844FC3 ST 35 / LT 2,100; E3EFEFBF 15 / 900; 7CC24C4A 60 / 3,600.
--   ALL 3 keys: 123,297 sessions, 1.3% High, 96.2% verified | today ST 110,947 (90.0%; 1.0% High, 96.4% ver), x2 107,062, x4 99,718,
--               LT 85,733 | new 112,383 (91.1%; 1.0% High, 96.3% ver), of which ST 112,315.
--   EE844FC3: 106,112 sess | today ST 96,967 | new 98,778. Dict 1 Desktop 31,975 (ST count p50 746, max 1,054): 30,507 vs 30,538;
--             Dict 1 Mobile 68,899 (p50 477): 63,194 vs 65,235; Dict 1 WinRDVM 1,950: 1,929 vs 1,933; Dict 1 Linux 1,186: 1,042 vs 1,042.
--   E3EFEFBF: 15,066 sess | today 12,719 | new 12,199. Dict 1 Desktop 4,337: 4,003 vs 3,683; Mobile 10,058: 8,337 vs 8,337; Linux 223: 92 vs 0.
--   7CC24C4A:  2,119 sess | today 1,261 | new 1,406. Dict 1 Desktop 1,062: 679 vs 704; Mobile 946: 556 vs 678.
--   Skipped List A on these keys: 742 sessions (401 breach today). ST counts top out at 1,052-1,054 on EE844FC3 (possible cap; not checked).
