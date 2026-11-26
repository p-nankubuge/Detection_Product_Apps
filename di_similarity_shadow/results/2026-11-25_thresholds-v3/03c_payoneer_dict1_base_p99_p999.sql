-- v3 (D-13): EE844FC3 (Payoneer Login K2) Dict 1 base cells, p99 and p99.9, 7-day base 11-18 Nov (same definitions as v2 08_; Dict 1 only).
-- Why only Dict 1: the full Payoneer base (03_ one scan, 03b_ chunked histograms) timed out or exceeded the response cap. In v2's L1 replay,
-- 113,568 of 113,595 fires were Dict 1 cells, and every variant threshold is >= V0 in every cell, so non-Dict-1 cells can only lose fires.
-- E3EFEFBF and 7CC24C4A Dict 1 cells are at step (b) (pooled 177 / 26 clean sig-windows < 500) in every variant: window counts do not
-- depend on the variant. Run 2026-11-25, 14.5 s, no sampling.
WITH s0 AS (SELECT session_ts ts, di_matched_signature_at_session_created ms, os_at_session_created os, COALESCE(webgl_unmasked_renderer_at_session_created,'') r,
    IFF(latest_risk_band='High',1,0) hi FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key='EE844FC3-499D-4A4D-A643-D7400F0FD4DE' AND di_dictionary_num_matched_at_session_created=1
    AND session_last_timestamp>='2026-11-11' AND session_last_timestamp<'2026-11-18 06:00' AND session_ts>='2026-11-11' AND session_ts<'2026-11-18'),
s1 AS (SELECT s0.*, CASE WHEN r ILIKE '%SwiftShader%' OR r ILIKE '%llvmpipe%' OR r ILIKE '%VirtualBox%' OR r ILIKE '%VMware%' THEN 'A'
    WHEN r ILIKE '%Basic Render Driver%' AND COALESCE(os,'')<>'Windows' THEN 'B' WHEN COALESCE(os,'') IN ('','--') AND r<>'' THEN 'B' END x,
    CASE WHEN r ILIKE '%Basic Render Driver%' AND os='Windows' THEN 'WinRDVM' WHEN os IN ('Windows','OS X','Chrome OS') THEN 'Desktop'
    WHEN os IN ('iOS','iPadOS','Android') THEN 'Mobile' WHEN os IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'Other' END grp FROM s0),
wg AS (SELECT grp,ms,TIME_SLICE(ts,40,'MINUTE') t,COUNT(*) n,SUM(hi) h FROM s1 WHERE x IS NULL AND ms IS NOT NULL GROUP BY 1,2,3),
wp AS (SELECT 'ALL' grp,ms,TIME_SLICE(ts,40,'MINUTE') t,COUNT(*) n,SUM(hi) h FROM s1 WHERE x IS NULL AND ms IS NOT NULL GROUP BY 1,2,3),
w AS (SELECT * FROM wg UNION ALL SELECT * FROM wp)
SELECT grp||'|'||COUNT_IF(h/n<0.2)||'|'||COALESCE(ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY IFF(h/n<0.2,n,NULL)),2)::STRING,'-')
  ||'|'||COALESCE(ROUND(PERCENTILE_CONT(0.999) WITHIN GROUP (ORDER BY IFF(h/n<0.2,n,NULL)),2)::STRING,'-')||'|'||COALESCE(MAX(IFF(h/n<0.2,n,NULL))::STRING,'-') r
FROM w GROUP BY grp ORDER BY 1;
-- Result (grp|clean sig-windows|p99|p99.9|max):  ALL 2192|12.09|25.81|60   Desktop 315|13.00|36.78|44   Linux 1|1|1|1   Mobile 1779|12.00|25.22|60
--   Other 95|5.06|5.91|6   WinRDVM 2|1|1|1.   (p99 and window counts identical to v2 08_.)
-- EE844FC3 Dict 1 thresholds (ST / LT; current 35 / 2,100; mult 1x):
--   V0 = V1 (floor 5 does not bind): Mobile key cell 12.0 / 720; Desktop, Linux, WinRDVM, Other = (a) pooled 12.1 / 726 (v2 rounding).
--   V2 = V3: Mobile key cell 25.22 / 1,513.2; Desktop, Linux, WinRDVM, Other = (a) pooled 25.81 / 1,548.6 (below the cap of 35 / 2,100).
