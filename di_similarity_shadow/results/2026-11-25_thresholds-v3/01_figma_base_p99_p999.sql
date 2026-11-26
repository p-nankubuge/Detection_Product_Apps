-- v3 (D-13 sensitivity): Figma Registration K2 base, p99 AND p99.9 in one scan, per key x dict x group (G) and key x dict pooled (P).
-- Identical to v2 (v1 01_figma_base.sql for the per-group cells, v2 01_figma_base_pooled.sql variant P for pooled):
-- base = sessions created 2026-11-13 00:00 to 2026-11-20 00:00 UTC, no sampling, List A/B/C skipped, fixed 40-min TIME_SLICE buckets,
-- signature = DI_MATCHED_SIGNATURE_AT_SESSION_CREATED, clean = signature-window with < 20% High. p99 / p99.9 = PERCENTILE_CONT over
-- clean signature-windows. Output: lvl|d|grp|sigwin_clean|p99|p999|max_clean
WITH s0 AS (SELECT session, session_ts ts, di_dictionary_num_matched_at_session_created d,
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
wg AS (SELECT 'G' lvl, d, grp, ms, TIME_SLICE(ts,40,'MINUTE') t, COUNT(*) n, SUM(hi) h FROM s1 WHERE x IS NULL AND ms IS NOT NULL GROUP BY 1,2,3,4,5),
wp AS (SELECT 'P' lvl, d, 'ALL' grp, ms, TIME_SLICE(ts,40,'MINUTE') t, COUNT(*) n, SUM(hi) h FROM s1 WHERE x IS NULL AND ms IS NOT NULL GROUP BY 1,2,3,4,5),
w AS (SELECT * FROM wg UNION ALL SELECT * FROM wp)
SELECT lvl||'|'||d||'|'||grp||'|'||COUNT_IF(h/n<0.2)
  ||'|'||COALESCE(ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY IFF(h/n<0.2,n,NULL)),2)::STRING,'-')
  ||'|'||COALESCE(ROUND(PERCENTILE_CONT(0.999) WITHIN GROUP (ORDER BY IFF(h/n<0.2,n,NULL)),2)::STRING,'-')
  ||'|'||COALESCE(MAX(IFF(h/n<0.2,n,NULL))::STRING,'-') r
FROM w GROUP BY lvl,d,grp ORDER BY 1;
