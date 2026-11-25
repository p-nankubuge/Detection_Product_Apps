-- Copied unchanged from results/2026-11-25_thresholds/01_figma_base.sql (v1). Its per-group key cells are reused by v2; not re-run.
-- Figma Registration K2 (A207F8A1-...) base thresholds. Run 2026-11-25, Snowflake (Superset database_id 14), 22 s. No sampling.
-- Base period: sessions created 2026-11-13 00:00 to 2026-11-20 00:00 UTC. Session CTE = _session_cte.sql (PROXY = FALSE).
-- Window = fixed 40-min bucket TIME_SLICE(session_ts, 40, 'MINUTE') (epoch-aligned; days start on a bucket edge): 252 windows.
-- Signature-window = matched signature (DI_MATCHED_SIGNATURE_AT_SESSION_CREATED) x platform group x bucket, counting only
-- non-List-A/B/C sessions. Clean = < 20% of the signature-window's sessions High risk. p99 = PERCENTILE_CONT(0.99) over
-- clean signature-windows (each window with >= 1 session counts once).
-- Output columns: d | grp | sigwin_all | sigwin_clean | sess_clean | sess_all | p99_clean | p95_clean | max_clean | p99_all | high_rate
WITH s0 AS (SELECT session, public_key k, session_ts ts, di_dictionary_num_matched_at_session_created d,
    di_matched_signature_at_session_created ms, os_at_session_created os, COALESCE(webgl_unmasked_renderer_at_session_created,'') r,
    COALESCE(cdn__ja4_hash_at_session_created,'') ja4, COALESCE(ua_at_session_created,'') ua, IFF(latest_risk_band='High',1,0) hi
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key='A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND session_last_timestamp>='2026-11-13' AND session_last_timestamp<'2026-11-20 06:00'
    AND session_ts>='2026-11-13' AND session_ts<'2026-11-20'),
s1 AS (SELECT s0.*,
    CASE WHEN r ILIKE '%SwiftShader%' OR r ILIKE '%llvmpipe%' OR r ILIKE '%VirtualBox%' OR r ILIKE '%VMware%' THEN 'A'
         WHEN r ILIKE '%Basic Render Driver%' AND COALESCE(os,'')<>'Windows' THEN 'B'
         WHEN COALESCE(os,'') IN ('','--') AND r<>'' THEN 'B'
         WHEN ja4 LIKE 't%' AND SPLIT_PART(ja4,'_',2) IN ('a09f3c656075','2802a3db6c62') AND os IN ('Windows','GNU/Linux','Ubuntu','Chrome OS') THEN 'C'
         WHEN ua LIKE '%Chrome/%' AND RIGHT(SPLIT_PART(ja4,'_',1),2)='h1' THEN 'C'
         WHEN TRY_TO_NUMBER(REGEXP_SUBSTR(ua,'Chrome/([0-9]+)',1,1,'e',1))>=70 AND ja4 LIKE 't12%' THEN 'C' END AS x,
    CASE WHEN r ILIKE '%Basic Render Driver%' AND os='Windows' THEN 'WinRDVM'
         WHEN os IN ('Windows','OS X','Chrome OS') THEN 'Desktop' WHEN os IN ('iOS','iPadOS','Android') THEN 'Mobile'
         WHEN os IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'Other' END AS grp
  FROM s0),
w AS (SELECT d, grp, ms, TIME_SLICE(ts,40,'MINUTE') t, COUNT(*) n, SUM(hi) h FROM s1 WHERE x IS NULL AND ms IS NOT NULL GROUP BY 1,2,3,4)
SELECT d||'|'||grp||'|'||COUNT(*)||'|'||COUNT_IF(h/n<0.2)||'|'||SUM(IFF(h/n<0.2,n,0))||'|'||SUM(n)
  ||'|'||COALESCE(ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY IFF(h/n<0.2,n,NULL)),2)::STRING,'-')
  ||'|'||COALESCE(ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY IFF(h/n<0.2,n,NULL)),2)::STRING,'-')
  ||'|'||COALESCE(MAX(IFF(h/n<0.2,n,NULL))::STRING,'-')||'|'||ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY n),2)||'|'||ROUND(SUM(h)/SUM(n),4) r
FROM w GROUP BY d,grp
UNION ALL SELECT d||'|SKIP_'||x||'|'||COUNT(*)||'|hi='||ROUND(AVG(hi),4) FROM s1 WHERE x IS NOT NULL GROUP BY d,x
UNION ALL SELECT d||'|NULLR_'||grp||'|'||COUNT(*)||'|hi='||ROUND(AVG(hi),4) FROM s1 WHERE x IS NULL AND r='' GROUP BY d,grp
UNION ALL SELECT 'OS|'||COALESCE(os,'NULL')||'|'||COUNT(*) FROM s1 GROUP BY os ORDER BY 1;
-- (UNION ALL branches read the same one-key CTE; the table is scanned once.)
-- Result (d|grp|sigwin_all|sigwin_clean|sess_clean|sess_all|p99_clean|p95_clean|max_clean|p99_all|high_rate):
-- -1|Desktop|24|21|37|42|8.00|4.00|9|7.85|0.0714      -1|Linux|1|1|1|1|1|1|1|1|0      -1|Mobile|8|5|5|8|1|1|1|1|0.3750
-- -1|Other|8|5|5|11|1|1|1|3.79|0.5455
--  1|Desktop|450|413|686|781|8.00|4.00|19|8.00|0.0858     1|Linux|77|65|97|131|5.08|3.00|7|6.24|0.1908
--  1|Mobile|185|165|197|225|3.36|2.00|6|3.16|0.1200       1|Other|11|6|7|12|1.95|1.75|2|1.90|0.4167
--  1|WinRDVM|30|28|42|45|4.46|3.00|5|4.42|0.0444
--  3|Desktop|15662|14359|21694|24268|7.00|3.00|45|7.00|0.0773   3|Linux|1747|1602|2312|2756|6.00|3.00|10|7.00|0.1027
--  3|Mobile|3713|3449|5409|5893|9.00|5.00|15|9.00|0.0614       3|Other|64|56|71|84|3.00|3.00|3|4.11|0.1548
--  3|WinRDVM|1021|969|1256|1335|5.00|3.00|7|5.00|0.0479
--  7|Desktop|54638|50697|59597|66201|4.00|2.00|26|4.00|0.0836  7|Linux|3252|3087|3572|3833|4.00|2.00|11|4.00|0.0592
--  7|Mobile|1825|1743|1835|1941|2.00|1.00|9|2.00|0.0531        7|Other|19|11|11|23|1.00|1.00|1|2.00|0.5217
--  7|WinRDVM|3096|2897|3361|3624|4.00|2.00|11|4.00|0.0679
-- 15|Desktop|44544|39261|43461|50686|3.00|2.00|56|3.00|0.1340  15|Linux|2270|2198|2402|2518|3.00|2.00|9|3.00|0.0409
-- 15|Mobile|10183|9791|10708|11297|3.00|2.00|12|3.00|0.0482   15|Other|50|43|46|59|2.00|1.90|2|3.00|0.2034
-- 15|WinRDVM|1790|1475|1695|2097|4.00|2.00|8|4.00|0.1850
-- 31|Desktop|82010|76762|85850|94420|3.00|2.00|155|3.00|0.0807 31|Linux|2173|2089|2300|2425|3.00|2.00|10|3.00|0.0487
-- 31|Mobile|6022|5832|6174|6435|2.00|1.00|7|3.00|0.0381       31|Other|1|1|1|1|1|1|1|1|0
-- 31|WinRDVM|3272|2977|3252|3655|3.00|2.00|11|3.00|0.1034
-- 63|Desktop|219065|212242|257872|271002|4.00|2.00|35|5.00|0.0379  63|Linux|2516|2451|2715|2842|3.00|2.00|11|3.00|0.0366
-- 63|Mobile|62827|60986|77142|80572|5.00|3.00|13|5.00|0.0322      63|Other|33|31|31|33|1|1|1|1|0.0606
-- 63|WinRDVM|6629|6382|7591|8021|4.00|2.00|21|4.00|0.0445
-- Skipped List A/B/C sessions (base period): A 1,815 (d-1 1, d1 56, d3 550, d7 454, d15 246, d31 177, d63 331);
--   B 387 (d1 367, d3 5, d7 6, d15 9); C 6,334 (d1 347, d3 1,158, d7 1,791, d15 1,006, d31 791, d63 1,241). Total 8,536 of 655,839 sessions.
-- NULL/empty renderer (grouped by OS, not skipped): 2,427 sessions (Desktop 1,590, Linux 774, Mobile 62, Other 1).
-- OS values: Windows 396,123; OS X 129,075; Android 62,990; iOS 38,783; GNU/Linux 13,981; Chrome OS 8,182; iPadOS 4,695;
--   Ubuntu 1,363; NULL 424; OpenHarmony 84; HarmonyOS 51; Meta Horizon 34; HyperOS 28; Fire OS 21; Android TV 3; Fedora 1; UOS 1.
