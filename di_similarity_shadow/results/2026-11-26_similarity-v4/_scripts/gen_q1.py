from common import *
CH=[('UAxDP_c','fuc'),('UAxDP_x','fux'),('SCRxDP_c','fsc'),('SCRxDP_x','fsx'),('SCRxGL','fsg'),('SCRxPG','fsp')]
U=", u AS (SELECT x.value:k::STRING AS k, md2, x.value:f::FLOAT AS fr, ROUND(fr*pgn) AS cn, risk FROM g, LATERAL FLATTEN(ARRAY_CONSTRUCT("+", ".join(f"OBJECT_CONSTRUCT('k','{nm}','f',{f})" for nm,f in CH)+")) x WHERE NOT no_score AND x.value:f IS NOT NULL)\n"
U+=", ub AS (SELECT u.*, CASE WHEN fr=0 THEN '0 never' WHEN fr<1e-5 THEN '1 <1e-5' WHEN fr<1e-4 THEN '2 1e-5..1e-4' WHEN fr<1e-3 THEN '3 1e-4..1e-3' WHEN fr<1e-2 THEN '4 1e-3..1e-2' ELSE '5 >=1e-2' END AS fb, CASE WHEN cn=0 THEN 'c0' WHEN cn=1 THEN 'c1' WHEN cn<5 THEN 'c2-4' WHEN cn<20 THEN 'c5-19' WHEN cn<100 THEN 'c20-99' WHEN cn<1000 THEN 'c100-999' ELSE 'c1000+' END AS cb FROM u)\n"
tail=G+U+"SELECT r FROM (\n"+"\nUNION ALL ".join([
 "SELECT 'BASE|'||md2||'|'||"+OS+" AS r FROM g GROUP BY md2",
 "SELECT 'BASE|all|'||"+OS+" FROM g",
 "SELECT 'PGN|'||pg||'|'||pgn FROM pgt",
 "SELECT 'REG|band4<>band='||COUNT_IF(band4<>band)||'|t4v<>t3='||COUNT_IF(t4v<>t3)||'|nwarn4<>nwarn(desk)='||COUNT_IF(nwarn4<>nwarn AND NOT mob2)||'|A='||COUNT_IF(band='A')||'|B='||COUNT_IF(band='B')||'|C='||COUNT_IF(band='C')||'|D='||COUNT_IF(band='D')||'|v2D='||COUNT_IF(band_v2='D')||'|v1D='||COUNT_IF(band_v1='D') FROM g",
 "SELECT 'FB|'||k||'|'||md2||'|'||fb||'|'||"+OS+" FROM ub GROUP BY k, md2, fb",
 "SELECT 'CB|'||k||'|'||md2||'|'||cb||'|'||"+OS+"||'|maxfr='||TO_VARCHAR(MAX(fr),'0.0000EEEE') FROM ub GROUP BY k, md2, cb",
])+"\n) ORDER BY r\n"
emit('q1_frequency_bins', "-- Q1 (step 1): pair frequency bins vs High risk, per pair check, desktop (all non-Mobile groups) vs mobile, coarse and exact;\n-- FB = log bins of frequency (share of the platform group's whitelist sessions), CB = bins of the raw whitelist session count\n-- (with the largest frequency in the bin). Plus baselines, whitelist sessions per platform group, and a regression check:\n-- with every cut-off ~0 (1e-12) v4 must equal v3.\n", tail)
