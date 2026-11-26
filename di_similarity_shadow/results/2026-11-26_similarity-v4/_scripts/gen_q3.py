from common import *
H="COUNT(*)||'|'||COUNT_IF(risk='High')"
G2x=G2.replace(" FROM sess_raw r JOIN t ON t.h = r.h)\n",
  ", ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(g_ua_dp,'UAxDP',NULL), IFF(h_scr_dp,'SCRxDP',NULL), IFF(h_scr_gl,'SCRxGL',NULL), IFF(h_scr_pg,'SCRxPG',NULL), IFF(p_dp_new AND mob2,'DPnew',NULL)), ' ') AS fails3"
  ", ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(h_w_scr,'SCRnew',NULL), IFF(p_dp_new AND NOT mob2,'DPnew',NULL), IFF(r_ua_dp,'UAxDPr',NULL), IFF(r_scr_dp,'SCRxDPr',NULL), IFF(r_scr_gl,'SCRxGLr',NULL), IFF(r_scr_pg,'SCRxPGr',NULL)), ' ') AS warns4"
  " FROM sess_raw r JOIN t ON t.h = r.h)\n") if 'AS fails3' not in G2 else G2
ex_r=EX.replace('{B}','band4').replace('{EXTRA}',"'U1e-4:'||"+RU4)
tail=G2x+"SELECT r FROM (\n"+"\nUNION ALL ".join([
 "SELECT 'REGX|band4<>band='||COUNT_IF(band4<>band)||'|nwarn4<>nwarn(desk)='||COUNT_IF(nwarn4<>nwarn AND NOT mob2) AS r FROM g",
 "SELECT 'X4|'||d||'|'||band4||'|'||"+O+"||'|'||ROUND(AVG(score3),3) FROM g GROUP BY d, band4",
 "SELECT 'XW|v4abc|'||d||'|'||band_abc||'|'||"+H+" FROM g GROUP BY d, band_abc",
 "SELECT 'WF4|'||md2||'|f'||LEAST(nfail,2)||'|w'||LEAST(nwarn4,3)||'|'||"+H+" FROM g WHERE NOT no_score GROUP BY md2, LEAST(nfail,2), LEAST(nwarn4,3)",
 "SELECT 'RARE|v4|'||md2||'|'||warns4||'|f'||LEAST(nfail,2)||'|'||"+H+" FROM g WHERE nrare>0 GROUP BY md2, warns4, LEAST(nfail,2)",
 "SELECT 'RARE|U1e-4|'||md2||'|f'||LEAST(nfail,2)||'|nrare='||LEAST(nrU4,3)||'|'||"+H+" FROM g WHERE NOT no_score GROUP BY md2, LEAST(nfail,2), LEAST(nrU4,3)",
 "SELECT 'G4|'||IFF(NOT g_ua_dp AND NOT r_ua_dp,'UAxDP ok','UAxDP fail/rare')||'|'||"+H+" FROM g WHERE mob2 AND NOT s_sp AND NOT no_score GROUP BY IFF(NOT g_ua_dp AND NOT r_ua_dp,'UAxDP ok','UAxDP fail/rare')",
 "SELECT 'G4|mobile all|'||"+H+" FROM g WHERE mob2",
 "SELECT * FROM (SELECT 'EXR|'||IFF(nrare>0,'v4 rare','U1e-4 rare only')||'|'||"+ex_r+" FROM g WHERE NOT no_score AND (nrare>0 OR (nrU4>0 AND NOT mob2)) QUALIFY ROW_NUMBER() OVER (PARTITION BY nrare>0 ORDER BY HASH(session)) <= IFF(nrare>0, 20, 10))",
])+"\n) ORDER BY r\n"
emit2('q3_stats_rare_examples', "-- Q3: regression check v4 vs v3 bands; v4 crosstab with outcomes (X4); v4abc crosstab (XW); High risk by failed checks x warning signs (WF4);\n-- rare-flag combinations (v4 main cut-offs, and uniform 1e-4); G4; up to 20 example sessions with a v4 rare-pair warning, plus up to 10\n-- desktop sessions rare only at a uniform 1e-4 cut-off (deterministic order HASH(session)).\n-- Example columns: EXR|group|session|OS|platform group|OS version|risk|v3 score|v3>v4 band|failed checks|v4 warning signs|rare pairs at 1e-4|\n-- UA (shortened, 55 chars)|JA4|screen|device_params|WebGL renderer (32 chars)|whitelist sessions with the pair: UAxDP coarse, exact, SCRxDP coarse,\n-- exact, SCRxGL, SCRxPG ('-' = not applicable).\n", tail)
