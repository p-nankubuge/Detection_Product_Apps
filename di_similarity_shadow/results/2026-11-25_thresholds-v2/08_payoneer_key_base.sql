-- v2 (D-11) per-key base cells for the 3 Payoneer proxy keys (L1 / G8). v1 used global cells here; D-11 forbids that.
-- Base = sessions created 2026-11-11 00:00 to 2026-11-18 00:00 UTC (7 days before the L1 replay day, same rule as Figma's base).
-- Same platform groups, 40-min fixed buckets, clean rule, signature column as Figma. Proxy keys: List C NOT applied (only A/B), as v1 08.
-- Output: key8|d|grp|sigwin_clean|p99_clean   (grp = 'ALL' is the key x dict pooled across groups, variant P: ms x bucket)
--         plus CUR|key8|median(ST count/ratio)|median(LT count/ratio) = the key's current thresholds.
WITH s0 AS (SELECT LEFT(public_key,8) k, session_ts ts, di_dictionary_num_matched_at_session_created d, di_matched_signature_at_session_created ms,
    os_at_session_created os, COALESCE(webgl_unmasked_renderer_at_session_created,'') r, IFF(latest_risk_band='High',1,0) hi,
    di_short_term_count_at_session_created stc, di_short_term_threshold_ratio_at_session_created str,
    di_long_term_count_at_session_created ltc, di_long_term_threshold_ratio_at_session_created ltr
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
SELECT k||'|'||d||'|'||grp||'|'||COUNT_IF(h/n<0.2)||'|'||COALESCE(ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY IFF(h/n<0.2,n,NULL)),1)::STRING,'-') r
FROM w GROUP BY k,d,grp
UNION ALL SELECT 'CUR|'||k||'|'||ROUND(MEDIAN(stc/NULLIF(str,0)),1)||'|'||ROUND(MEDIAN(ltc/NULLIF(ltr,0)),1)||'|n='||COUNT(*) FROM s1 GROUP BY k
ORDER BY 1;
-- Run 2026-11-25, 29 s, no sampling (4.05M sessions). Result key8|d|grp|clean sig-windows|p99 (grp ALL = pooled across groups):
-- CUR (key's current thresholds, median count/ratio): EE844FC3 ST 35 / LT 2,100 (3,481,761 sess); E3EFEFBF 15 / 900 (502,028); 7CC24C4A 60 / 3,600 (68,773)
-- EE844FC3: -1 ALL 152/17.5 Desktop 92/19.3 Mobile 72/10.0 Other 29/3.4 | 1 ALL 2192/12.1 Desktop 315/13.0 Linux 1/1.0 Mobile 1779/12.0 Other 95/5.1 WinRDVM 2/1.0
--   3 ALL 17085/189.2 Desktop 4587/231.0 Linux 413/136.0 Mobile 11723/115.0 Other 320/20.1 WinRDVM 377/68.7
--   7 ALL 76876/41.0 Desktop 51752/49.0 Linux 2535/16.7 Mobile 21256/10.0 WinRDVM 5866/12.0
--  15 ALL 234665/39.0 Desktop 96808/12.0 Linux 3459/11.0 Mobile 130173/53.0 WinRDVM 6815/8.9
--  31 ALL 106780/19.0 Desktop 82512/19.0 Linux 1748/13.5 Mobile 19822/14.0 WinRDVM 7452/8.0
--  63 ALL 257431/51.0 Desktop 62443/15.0 Linux 857/8.4 Mobile 190035/148.7 WinRDVM 4096/12.0
-- E3EFEFBF: -1 ALL 27/7.7 Desktop 5/6.9 Mobile 22/7.8 | 1 ALL 177/7.0 Desktop 11/3.9 Mobile 149/7.0 Other 17/6.8
--   3 ALL 4295/73.0 Desktop 1141/35.0 Linux 211/27.9 Mobile 2894/80.0 Other 49/6.5 WinRDVM 111/11.0
--   7 ALL 13711/14.0 Desktop 7903/15.0 Linux 528/10.0 Mobile 4953/10.0 WinRDVM 624/7.0
--  15 ALL 44209/15.0 Desktop 10966/8.0 Linux 648/9.0 Mobile 32077/16.0 WinRDVM 563/7.0
--  31 ALL 23405/11.0 Desktop 14129/9.7 Linux 331/7.7 Mobile 8284/12.0 WinRDVM 810/7.0
--  63 ALL 49746/21.0 Desktop 9668/10.0 Linux 126/9.0 Mobile 39395/23.0 WinRDVM 557/8.4
-- 7CC24C4A: -1 ALL 13/5.6 Desktop 8/2.0 Mobile 5/5.9 | 1 ALL 26/10.5 Desktop 1/1.0 Mobile 24/10.6 Other 1/2.0
--   3 ALL 1028/27.0 Desktop 514/12.9 Linux 102/19.0 Mobile 408/29.9 Other 3/1.0 WinRDVM 15/3.9
--   7 ALL 2502/9.0 Desktop 1751/9.0 Linux 86/7.2 Mobile 585/7.2 WinRDVM 107/15.8
--  15 ALL 4269/8.3 Desktop 1842/7.0 Linux 110/6.8 Mobile 2241/9.0 WinRDVM 77/9.7
--  31 ALL 4767/8.0 Desktop 2952/8.0 Linux 58/6.4 Mobile 1629/10.0 WinRDVM 139/10.5
--  63 ALL 6384/11.0 Desktop 2097/7.0 Linux 19/7.8 Mobile 4180/12.0 WinRDVM 88/6.1
-- (Cells not listed had no clean signature-windows: 0 -> fallback.)
