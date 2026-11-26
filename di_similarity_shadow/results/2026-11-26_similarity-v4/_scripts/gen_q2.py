from common import *
H="COUNT(*)||'|'||COUNT_IF(risk='High')"
tail=G2+V+"SELECT r FROM (\n"+"\nUNION ALL ".join([
 "SELECT 'X4|'||d||'|'||band4||'|'||"+O+"||'|'||ROUND(AVG(score3),3) AS r FROM g GROUP BY d, band4",
 "SELECT 'SH|'||ver||'|same='||COUNT_IF(rk=agr)||'|up='||COUNT_IF(rk<agr)||'|down='||COUNT_IF(rk>agr)||'|prom='||COUNT_IF(d IN (1,3) AND rk<=2)||'|dem='||COUNT_IF(d IN (63,31,15) AND rk=4)||'|D='||COUNT_IF(rk=4)||'|Dhigh='||COUNT_IF(rk=4 AND risk='High')||'|notD='||COUNT_IF(rk<>4)||'|notDhigh='||COUNT_IF(rk<>4 AND risk='High')||'|G1AB='||COUNT_IF(d IN (1,3) AND rk<=2)||'/'||COUNT_IF(d IN (1,3))||'|G5='||COUNT_IF(d=63 AND rk=1)||'/'||COUNT_IF(d=63)||'|m1D='||COUNT_IF(d=-1 AND rk=4)||'/'||COUNT_IF(d=-1) FROM v GROUP BY ver",
 "SELECT 'G3|'||ver||'|'||m||'|'||IFF(tr AND NOT no_score,'Dchk','pass')||'|'||"+H+" FROM v GROUP BY ver, m, IFF(tr AND NOT no_score,'Dchk','pass')",
 "SELECT 'D15|'||ver||'|'||bd||'|'||"+H+" FROM v WHERE d15g GROUP BY ver, bd",
 "SELECT 'FL|'||ver||'|intoD='||COUNT_IF(v.bd='D' AND g.band<>'D')||'/'||COUNT_IF(v.bd='D' AND g.band<>'D' AND g.risk='High')||'|outD='||COUNT_IF(v.bd<>'D' AND g.band='D')||'/'||COUNT_IF(v.bd<>'D' AND g.band='D' AND g.risk='High') FROM v JOIN g ON g.session=v.session GROUP BY ver",
 "SELECT 'WF4|'||md2||'|f'||LEAST(nfail,2)||'|w'||LEAST(nwarn4,3)||'|'||"+H+" FROM g WHERE NOT no_score GROUP BY md2, LEAST(nfail,2), LEAST(nwarn4,3)",
 "SELECT 'RARE|v4|'||md2||'|'||IFF(r_ua_dp,'UAxDPr ','')||IFF(r_scr_dp,'SCRxDPr ','')||IFF(r_scr_gl,'SCRxGLr ','')||IFF(r_scr_pg,'SCRxPGr','')||'|'||"+H+" FROM g WHERE nrare>0 GROUP BY md2, r_ua_dp, r_scr_dp, r_scr_gl, r_scr_pg",
 "SELECT 'RARE|U1e-4|'||md2||'|nrare='||LEAST(nrU4,3)||'|'||"+H+" FROM g GROUP BY md2, LEAST(nrU4,3)",
 "SELECT 'RARE|U1e-3|'||md2||'|nrare='||LEAST(nrU3,3)||'|'||"+H+" FROM g GROUP BY md2, LEAST(nrU3,3)",
 "SELECT 'G4|'||IFF(NOT g_ua_dp AND NOT r_ua_dp,'UAxDP ok','UAxDP fail/rare')||'|'||"+H+" FROM g WHERE mob2 AND NOT s_sp AND NOT no_score GROUP BY IFF(NOT g_ua_dp AND NOT r_ua_dp,'UAxDP ok','UAxDP fail/rare')",
 "SELECT 'G4|mobile all|'||"+H+" FROM g WHERE mob2",
])+"\n) ORDER BY r\n"
# v needs session for FL join
tail=tail.replace("SELECT g.d, g.risk,","SELECT g.session, g.d, g.risk,")
emit2('q2_v4_results', "-- Q2 (step 2): v4 crosstab (X4) with outcomes; same/up/down, Band D, G1, G5 for v1, v2, v3, v4, the what-if triggers (v4a: + desktop\n-- coarse UAxDP never-seen alone -> D; v4b: + 2+ warning signs -> D; v4c: screen x WebGL failure counted as a warning; v4abc: all three)\n-- and two sensitivity variants with one uniform rare cut-off for every pair and level (U1e-4, U1e-3); G3 per version; v1 Dict 15 group per\n-- version; flow into / out of Band D vs v3; High risk by failed checks x warning signs (v4); rare-flag counts; G4.\n-- Main v4 cut-offs (measured in q1): desktop groups = exact pair never seen only (no frequency cut-off); Mobile = screen x DP coarse < 1e-4\n-- and screen x platform group < 1e-4.\n", tail)
