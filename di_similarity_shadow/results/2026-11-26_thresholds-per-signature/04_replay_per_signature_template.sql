-- D-19 per-signature threshold replay, one key x one replay day per run, all 8 grid points + today in one scan.
-- Placeholders: {KEY} public key; {D0} replay day start; {D1} = D0 + 1 day; {B0} = D0 - 7 days (base start); {P0} = D0 - 20 min.
-- {L1} = D1 + 6 h (upper bound on session_last_timestamp for pruning).
-- Source: ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY (one row per session; *_at_session_created = values at session_setup).
-- signature = DI_MATCHED_SIGNATURE_AT_SESSION_CREATED; count = DI_SHORT_TERM_COUNT_AT_SESSION_CREATED (DI's own current + previous
--   20-min bucket count).
-- share = non-High sessions of the key with that matched signature over [B0, D0) / all non-High sessions of the key over [B0, D0);
--   no history -> 0. (High = latest_risk_band = 'High'.)
-- volume = key sessions (all sessions, any dict, incl. List A/B/C) in the previous 20-min TIME_SLICE + the current TIME_SLICE up to
--   and including this session (causal, as DI would know it at session_setup). Ties on identical session_ts ordered by session.
-- expected = share x volume; fire(m,f) = count > GREATEST(f, expected x m x dfac); dfac = 1 (Dict 1, 3), 1.5 (7), 2 (15, 31, 63).
-- Grid gp 1..8 = (m,f): 1 (2,5) 2 (5,5) 3 (10,5) 4 (20,5) 5 (2,11) 6 (5,11) 7 (10,11) 8 (20,11). gp 0 = today's short-term breach
--   (DI_SHORT_TERM_THRESHOLD_BREACHED, Dict 63 included as recorded); also reported: today's LT breach (tl).
-- No new fire for: List A/B/C sessions (grp SKIP_A/B/C), Dict -1 / NULL matched signature (grp kept, flag nosig).
-- clean = session's (List flag, platform group, matched signature, 40-min TIME_SLICE) window has < 20% High (as thresholds v3).
-- sl = 1 if session_ts in [12:00, 14:00) of the replay day (Figma slice).
-- Output per (gp, d, grp) [sl=ALL] and per (gp, sl) [d=grp=ALL]: counts only; rates computed in 06_build_tables.py.
--   n sessions | cl clean sessions | F fires | Fh High | Fv verified | Fc challenged | Fn challenged-not-solved | Fcl clean fires |
--   NEW fires not breached today (ST) | LOST today ST breaches not fired | lab labelled (Blizzard only; 0 otherwise) | Flab labelled fires
WITH b0 AS (SELECT di_matched_signature_at_session_created ms, COUNT(*) c FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key='{KEY}' AND session_last_timestamp>='{B0}' AND session_last_timestamp<'{L1}' AND session_ts>='{B0}' AND session_ts<'{D0}' AND COALESCE(latest_risk_band,'')<>'High'
  GROUP BY 1),
sh AS (SELECT ms, c/SUM(c) OVER () share FROM b0),
a0 AS (SELECT session sid, session_ts ts, di_dictionary_num_matched_at_session_created d, di_matched_signature_at_session_created ms, os_at_session_created os,
  COALESCE(webgl_unmasked_renderer_at_session_created,'') r, COALESCE(cdn__ja4_hash_at_session_created,'') ja4, COALESCE(ua_at_session_created,'') ua,
  IFF(latest_risk_band='High',1,0) hi, IFF(sessions_verified>0,1,0) ver, IFF(was_challenged>0,1,0) chl, IFF(was_challenged>0 AND COALESCE(sessions_solved,0)=0,1,0) chns,
  di_short_term_count_at_session_created stc, IFF(di_short_term_threshold_breached_at_session_created,1,0) stb, IFF(di_long_term_threshold_breached_at_session_created,1,0) ltb,
  TIME_SLICE(session_ts,20,'MINUTE') b20
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY WHERE public_key='{KEY}' AND session_last_timestamp>='{P0}' AND session_last_timestamp<'{L1}' AND session_ts>='{P0}' AND session_ts<'{D1}'),
bc AS (SELECT b20, COUNT(*) bn FROM a0 GROUP BY 1),
a1 AS (SELECT a0.*, COUNT(*) OVER (PARTITION BY a0.b20 ORDER BY ts, sid ROWS UNBOUNDED PRECEDING) + COALESCE(p.bn,0) vol
  FROM a0 LEFT JOIN bc p ON p.b20 = DATEADD(minute,-20,a0.b20)),
s1 AS (SELECT a1.*, CASE WHEN r ILIKE '%SwiftShader%' OR r ILIKE '%llvmpipe%' OR r ILIKE '%VirtualBox%' OR r ILIKE '%VMware%' THEN 'A'
  WHEN r ILIKE '%Basic Render Driver%' AND COALESCE(os,'')<>'Windows' THEN 'B' WHEN COALESCE(os,'') IN ('','--') AND r<>'' THEN 'B'
  WHEN ja4 LIKE 't%' AND SPLIT_PART(ja4,'_',2) IN ('a09f3c656075','2802a3db6c62') AND os IN ('Windows','GNU/Linux','Ubuntu','Chrome OS') THEN 'C'
  WHEN ua LIKE '%Chrome/%' AND RIGHT(SPLIT_PART(ja4,'_',1),2)='h1' THEN 'C' WHEN TRY_TO_NUMBER(REGEXP_SUBSTR(ua,'Chrome/([0-9]+)',1,1,'e',1))>=70 AND ja4 LIKE 't12%' THEN 'C' END AS x,
  CASE WHEN r ILIKE '%Basic Render Driver%' AND os='Windows' THEN 'WinRDVM' WHEN os IN ('Windows','OS X','Chrome OS') THEN 'Desktop' WHEN os IN ('iOS','iPadOS','Android') THEN 'Mobile'
  WHEN os IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'Other' END AS grp0,
  COALESCE(sh.share,0) share, CASE WHEN d IN (1,3) THEN 1 WHEN d=7 THEN 1.5 ELSE 2 END dfac
  FROM a1 LEFT JOIN sh ON sh.ms=a1.ms WHERE a1.ts>='{D0}' AND a1.d IS NOT NULL),
s2 AS (SELECT s1.*, IFF(x IS NULL, grp0, 'SKIP_'||x) grp, IFF(x IS NULL AND ms IS NOT NULL AND d>0, 1, 0) elig,
  IFF(SUM(hi) OVER (PARTITION BY x, grp0, ms, TIME_SLICE(ts,40,'MINUTE')) / COUNT(*) OVER (PARTITION BY x, grp0, ms, TIME_SLICE(ts,40,'MINUTE')) < 0.2, 1, 0) cl,
  IFF(HOUR(ts) IN (12,13),1,0) sl {LABCOL}
  FROM s1 {LABJOIN}),
gr(gp,m,f) AS (SELECT * FROM VALUES (1,2,5),(2,5,5),(3,10,5),(4,20,5),(5,2,11),(6,5,11),(7,10,11),(8,20,11),(0,0,0)),
x AS (SELECT gp, d, grp, sl, hi, ver, chl, chns, cl, lab, stb, ltb,
  IFF(gp=0, stb, IFF(elig=1 AND stc > GREATEST(f, share*vol*m*dfac), 1, 0)) fi FROM s2 CROSS JOIN gr)
SELECT gp||'|'||COALESCE(d::STRING,'ALL')||'|'||COALESCE(grp,'ALL')||'|'||COALESCE(sl::STRING,'ALL')||'|'||COUNT(*)||'|'||SUM(cl)||'|'||SUM(fi)||'|'||SUM(fi*hi)||'|'||SUM(fi*ver)||'|'||SUM(fi*chl)||'|'||SUM(fi*chns)
  ||'|'||SUM(fi*cl)||'|'||SUM(fi*(1-stb))||'|'||SUM(stb*(1-fi))||'|'||SUM(lab)||'|'||SUM(fi*lab)||'|'||SUM(ltb)||'|'||SUM(fi*cl*hi) r
-- (trailing columns: tl = today LT breaches in group | Fclh = clean fires that are High)
FROM x GROUP BY GROUPING SETS ((gp, d, grp), (gp, sl)) HAVING SUM(fi)+SUM(stb)>0 OR gp=0 ORDER BY gp, d, grp, sl;
