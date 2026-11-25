-- v2 (D-11): Figma Registration K2 key x dict POOLED ACROSS PLATFORM GROUPS (fallback step a). Run 2026-11-25, Snowflake (database_id 14).
-- Same base period, filters, List A/B/C skip, 40-min fixed buckets and clean rule (< 20% High) as v1 01_figma_base.sql (reused unchanged
-- for the per-group key cells; its results are copied into 03_build_matrix_v2.py).
-- Two pooling variants are reported per dict:
--   P = signature-window = matched signature x 40-min bucket, groups merged (one signature spanning Desktop + Win RD/VM counts once,
--       which is how DI itself counts). USED for the v2 matrix.
--   U = union of the per-group signature-windows from v1 (matched signature x group x bucket). Shown as a sensitivity check.
-- Output: d | variant | sigwin_all | sigwin_clean | sess_clean | p99_clean | p95_clean | max_clean
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
wp AS (SELECT d, ms, TIME_SLICE(ts,40,'MINUTE') t, COUNT(*) n, SUM(hi) h FROM s1 WHERE x IS NULL AND ms IS NOT NULL GROUP BY 1,2,3),
wu AS (SELECT d, grp, ms, TIME_SLICE(ts,40,'MINUTE') t, COUNT(*) n, SUM(hi) h FROM s1 WHERE x IS NULL AND ms IS NOT NULL GROUP BY 1,2,3,4),
w AS (SELECT d,'P' v,n,h FROM wp UNION ALL SELECT d,'U' v,n,h FROM wu)
SELECT d||'|'||v||'|'||COUNT(*)||'|'||COUNT_IF(h/n<0.2)||'|'||SUM(IFF(h/n<0.2,n,0))
  ||'|'||COALESCE(ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY IFF(h/n<0.2,n,NULL)),2)::STRING,'-')
  ||'|'||COALESCE(ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY IFF(h/n<0.2,n,NULL)),2)::STRING,'-')
  ||'|'||COALESCE(MAX(IFF(h/n<0.2,n,NULL))::STRING,'-') r
FROM w GROUP BY d,v ORDER BY 1;
-- Run 2026-11-25, 22 s, no sampling. Result (d|variant|sigwin_all|sigwin_clean|sess_clean|p99_clean|p95_clean|max_clean):
-- -1|P|39|30|47|7.55|3.55|9        -1|U|41|32|48|7.45|3.45|9
--  1|P|726|652|1031|7.49|4.00|19    1|U|753|677|1029|7.00|4.00|19
--  3|P|21800|20041|30721|8.00|4.00|45   3|U|22207|20435|30742|7.00|4.00|45
--  7|P|62343|57955|68308|4.00|2.00|26   7|U|62830|58435|68376|4.00|2.00|26
-- 15|P|58820|52754|58310|3.00|2.00|56  15|U|58837|52768|58312|3.00|2.00|56
-- 31|P|93370|87579|97563|3.00|2.00|155 31|U|93478|87661|97577|3.00|2.00|155
-- 63|P|291070|282092|345351|4.00|2.00|35 63|U|291070|282092|345351|4.00|2.00|35
