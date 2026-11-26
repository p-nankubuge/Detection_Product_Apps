-- v3 (D-13): per-key base cells for the 3 Payoneer proxy keys (L1 / G8), p99 AND p99.9 in one scan. Identical to v2
-- 08_payoneer_key_base.sql (base 2026-11-11 00:00 to 2026-11-18 00:00 UTC, no sampling, List A/B only on proxy keys, 40-min buckets,
-- clean < 20% High, grp ALL = key x dict pooled across groups) plus PERCENTILE_CONT(0.999).
-- Output: key8|d|grp|sigwin_clean|p99|p999
WITH s0 AS (SELECT LEFT(public_key,8) k, session_ts ts, di_dictionary_num_matched_at_session_created d, di_matched_signature_at_session_created ms,
    os_at_session_created os, COALESCE(webgl_unmasked_renderer_at_session_created,'') r, IFF(latest_risk_band='High',1,0) hi
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key IN ('EE844FC3-499D-4A4D-A643-D7400F0FD4DE','E3EFEFBF-8DE4-42ED-9E7F-92F35B1FD3CF','7CC24C4A-611B-41C7-9808-B95722C7861C')
    AND session_last_timestamp>='2026-11-11' AND session_last_timestamp<'2026-11-18 06:00' AND session_ts>='2026-11-11' AND session_ts<'2026-11-18'),
s1 AS (SELECT s0.*,
    CASE WHEN r ILIKE '%SwiftShader%' OR r ILIKE '%llvmpipe%' OR r ILIKE '%VirtualBox%' OR r ILIKE '%VMware%' THEN 'A'
         WHEN r ILIKE '%Basic Render Driver%' AND COALESCE(os,'')<>'Windows' THEN 'B' WHEN COALESCE(os,'') IN ('','--') AND r<>'' THEN 'B' END x,
    CASE WHEN r ILIKE '%Basic Render Driver%' AND os='Windows' THEN 'WinRDVM' WHEN os IN ('Windows','OS X','Chrome OS') THEN 'Desktop'
         WHEN os IN ('iOS','iPadOS','Android') THEN 'Mobile' WHEN os IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'Other' END grp FROM s0),
wg AS (SELECT k,d,grp,ms,TIME_SLICE(ts,40,'MINUTE') t,COUNT(*) n,SUM(hi) h FROM s1 WHERE x IS NULL AND ms IS NOT NULL GROUP BY 1,2,3,4,5),
wp AS (SELECT k,d,'ALL' grp,ms,TIME_SLICE(ts,40,'MINUTE') t,COUNT(*) n,SUM(hi) h FROM s1 WHERE x IS NULL AND ms IS NOT NULL GROUP BY 1,2,3,4,5),
w AS (SELECT * FROM wg UNION ALL SELECT * FROM wp)
SELECT k||'|'||d||'|'||grp||'|'||COUNT_IF(h/n<0.2)||'|'||COALESCE(ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY IFF(h/n<0.2,n,NULL)),1)::STRING,'-')
  ||'|'||COALESCE(ROUND(PERCENTILE_CONT(0.999) WITHIN GROUP (ORDER BY IFF(h/n<0.2,n,NULL)),1)::STRING,'-') r
FROM w GROUP BY k,d,grp ORDER BY 1;
-- RESULT: timed out on 25 Nov (twice: all 3 keys; E3EFEFBF + 7CC24C4A only). Replaced by 03b_payoneer_base_histogram.sql.
