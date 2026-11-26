-- v3 (D-13): Figma Registration K2 base as a HISTOGRAM of clean signature-window sizes, run in day chunks.
-- Why: the one-scan p99 + p99.9 query (01_figma_base_p99_p999.sql, kept for reference) timed out twice on 25 Nov (v1's equivalent ran in
-- 22 s; the warehouse was probably busier). 40-min TIME_SLICE buckets are epoch-aligned and never cross a UTC day boundary, so
-- histograms from day chunks add up exactly; p99 / p99.9 are then computed in 02_build_matrices_v3.py with PERCENTILE_CONT's
-- linear interpolation (same definition as Snowflake). The V0 column reproduces v2's p99 as a check.
-- Same definitions as v2: base sessions created 13 Nov 00:00 - 20 Nov 00:00 UTC; session_last_timestamp in [chunk start, 20 Nov 06:00)
-- (identical to v2's single filter); List A/B/C skipped; signature = DI_MATCHED_SIGNATURE_AT_SESSION_CREATED; clean = < 20% High.
-- G = key x dict x group; P = key x dict pooled across groups (matched signature x bucket, groups merged = v2 variant P).
-- Chunks: {C0,C1} = ('2026-11-13','2026-11-15'), ('2026-11-15','2026-11-17'), ('2026-11-17','2026-11-19'), ('2026-11-19','2026-11-20').
-- Output: lvl|d|grp|n:count,n:count,...  (count = clean signature-windows with exactly n sessions)
WITH s0 AS (SELECT session_ts ts, di_dictionary_num_matched_at_session_created d, di_matched_signature_at_session_created ms, os_at_session_created os,
    COALESCE(webgl_unmasked_renderer_at_session_created,'') r, COALESCE(cdn__ja4_hash_at_session_created,'') ja4, COALESCE(ua_at_session_created,'') ua,
    IFF(latest_risk_band='High',1,0) hi
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key='A207F8A1-ED09-4325-ACE6-C8E26A458FBA' AND session_last_timestamp>='{C0}' AND session_last_timestamp<'2026-11-20 06:00'
    AND session_ts>='{C0}' AND session_ts<'{C1}'),
s1 AS (SELECT s0.*, CASE WHEN r ILIKE '%SwiftShader%' OR r ILIKE '%llvmpipe%' OR r ILIKE '%VirtualBox%' OR r ILIKE '%VMware%' THEN 'A'
    WHEN r ILIKE '%Basic Render Driver%' AND COALESCE(os,'')<>'Windows' THEN 'B' WHEN COALESCE(os,'') IN ('','--') AND r<>'' THEN 'B'
    WHEN ja4 LIKE 't%' AND SPLIT_PART(ja4,'_',2) IN ('a09f3c656075','2802a3db6c62') AND os IN ('Windows','GNU/Linux','Ubuntu','Chrome OS') THEN 'C'
    WHEN ua LIKE '%Chrome/%' AND RIGHT(SPLIT_PART(ja4,'_',1),2)='h1' THEN 'C'
    WHEN TRY_TO_NUMBER(REGEXP_SUBSTR(ua,'Chrome/([0-9]+)',1,1,'e',1))>=70 AND ja4 LIKE 't12%' THEN 'C' END AS x,
    CASE WHEN r ILIKE '%Basic Render Driver%' AND os='Windows' THEN 'WinRDVM' WHEN os IN ('Windows','OS X','Chrome OS') THEN 'Desktop'
    WHEN os IN ('iOS','iPadOS','Android') THEN 'Mobile' WHEN os IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'Other' END AS grp FROM s0),
wg AS (SELECT 'G' lvl,d,grp,ms,TIME_SLICE(ts,40,'MINUTE') t,COUNT(*) n,SUM(hi) h FROM s1 WHERE x IS NULL AND ms IS NOT NULL GROUP BY 1,2,3,4,5),
wp AS (SELECT 'P' lvl,d,'ALL' grp,ms,TIME_SLICE(ts,40,'MINUTE') t,COUNT(*) n,SUM(hi) h FROM s1 WHERE x IS NULL AND ms IS NOT NULL GROUP BY 1,2,3,4,5),
hst AS (SELECT lvl,d,grp,n,COUNT(*) c FROM (SELECT * FROM wg UNION ALL SELECT * FROM wp) WHERE h/n<0.2 GROUP BY 1,2,3,4)
SELECT lvl||'|'||d||'|'||grp||'|'||LISTAGG(n||':'||c,',') WITHIN GROUP (ORDER BY n) r FROM hst GROUP BY lvl,d,grp ORDER BY 1;
