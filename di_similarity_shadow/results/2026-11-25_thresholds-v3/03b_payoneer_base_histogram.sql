-- v3 (D-13): Payoneer base as TAIL histograms of clean signature-window sizes in day chunks.
-- Why: 03_payoneer_key_base_p99_p999.sql (one 7-day scan) timed out twice on 25 Nov; full histograms (and p95-cut tails) per 2-day chunk
-- exceeded/approached the ~25k-token response cap because of a few long-tailed proxy cells (EE844FC3 Dict 63 / 15 / 3 Mobile, up to 1,008).
-- Per cell x chunk this returns N (clean sig-windows), cut = PERCENTILE_DISC(0.98) of the chunk, the count with n <= cut, and the histogram
-- of n > cut with n BUCKETED: exact up to 50, floor to a multiple of 5 for 51-200, floor to a multiple of 25 above 200 (APPROXIMATION; only
-- affects cells whose p99 / p99.9 is above 50, i.e. EE844FC3 Dict 3 / 15 Mobile / 63 Mobile and E3EFEFBF Dict 3 cells, none of which is a
-- cell the L1 cohort lands in). 02_build_matrices_v3.py merges chunks and checks that the p99 rank falls above every chunk's cut.
-- Same definitions as v2 08_payoneer_key_base.sql: sessions created 2026-11-11 00:00 to 2026-11-18 00:00 UTC; session_last_timestamp in
-- [chunk start, 2026-11-18 06:00); 3 keys; List A/B only (proxy keys); 40-min TIME_SLICE buckets (never cross a UTC day, so chunks add up);
-- clean < 20% High; G = key x dict x group, P = key x dict pooled across groups (grp 'ALL').
-- Chunks {C0,C1}: (11,13), (13,16), (16,18) Nov.  Output: key8|lvl|d|grp|N|cut|le_cut|n:count,... (n > cut, bucketed)
WITH s0 AS (SELECT LEFT(public_key,8) k, session_ts ts, di_dictionary_num_matched_at_session_created d, di_matched_signature_at_session_created ms,
    os_at_session_created os, COALESCE(webgl_unmasked_renderer_at_session_created,'') r, IFF(latest_risk_band='High',1,0) hi
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key IN ('EE844FC3-499D-4A4D-A643-D7400F0FD4DE','E3EFEFBF-8DE4-42ED-9E7F-92F35B1FD3CF','7CC24C4A-611B-41C7-9808-B95722C7861C')
    AND session_last_timestamp>='{C0}' AND session_last_timestamp<'2026-11-18 06:00' AND session_ts>='{C0}' AND session_ts<'{C1}'),
s1 AS (SELECT s0.*,
    CASE WHEN r ILIKE '%SwiftShader%' OR r ILIKE '%llvmpipe%' OR r ILIKE '%VirtualBox%' OR r ILIKE '%VMware%' THEN 'A'
         WHEN r ILIKE '%Basic Render Driver%' AND COALESCE(os,'')<>'Windows' THEN 'B' WHEN COALESCE(os,'') IN ('','--') AND r<>'' THEN 'B' END x,
    CASE WHEN r ILIKE '%Basic Render Driver%' AND os='Windows' THEN 'WinRDVM' WHEN os IN ('Windows','OS X','Chrome OS') THEN 'Desktop'
         WHEN os IN ('iOS','iPadOS','Android') THEN 'Mobile' WHEN os IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'Other' END grp FROM s0),
wg AS (SELECT k,'G' lvl,d,grp,ms,TIME_SLICE(ts,40,'MINUTE') t,COUNT(*) n,SUM(hi) h FROM s1 WHERE x IS NULL AND ms IS NOT NULL GROUP BY 1,2,3,4,5,6),
wp AS (SELECT k,'P' lvl,d,'ALL' grp,ms,TIME_SLICE(ts,40,'MINUTE') t,COUNT(*) n,SUM(hi) h FROM s1 WHERE x IS NULL AND ms IS NOT NULL GROUP BY 1,2,3,4,5,6),
cw AS (SELECT k,lvl,d,grp,n FROM (SELECT * FROM wg UNION ALL SELECT * FROM wp) WHERE h/n<0.2),
cut AS (SELECT k,lvl,d,grp,COUNT(*) nn,PERCENTILE_DISC(0.98) WITHIN GROUP (ORDER BY n) c FROM cw GROUP BY 1,2,3,4),
hst AS (SELECT cw.k,cw.lvl,cw.d,cw.grp,IFF(cw.n<=50,cw.n,IFF(cw.n<=200,FLOOR(cw.n/5)*5,FLOOR(cw.n/25)*25)) b,COUNT(*) cc
  FROM cw JOIN cut USING (k,lvl,d,grp) WHERE cw.n>cut.c GROUP BY 1,2,3,4,5)
SELECT cut.k||'|'||cut.lvl||'|'||cut.d||'|'||cut.grp||'|'||cut.nn||'|'||cut.c||'|'||(cut.nn-COALESCE(SUM(hst.cc),0))||'|'||COALESCE(LISTAGG(hst.b||':'||hst.cc,',') WITHIN GROUP (ORDER BY hst.b),'') r
FROM cut LEFT JOIN hst USING (k,lvl,d,grp) GROUP BY cut.k,cut.lvl,cut.d,cut.grp,cut.nn,cut.c ORDER BY 1;
-- RESULT: only chunk (11,13) was run (12.7 s, ~20k-token response); chunks (13,16) and (16,18) were NOT run and this output is not used. Replaced by 03c_payoneer_dict1_base_p99_p999.sql (see caveats.md).
