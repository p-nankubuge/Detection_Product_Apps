-- D-19 per-signature replay, confirm run (26 Nov). One key x one replay day per run; every rule computed per row in one scan.
-- Definitions as in ../2026-11-26_thresholds-per-signature/04_replay_per_signature_template.sql (signature = matched signature, count =
-- DI_SHORT_TERM_COUNT_AT_SESSION_CREATED, share = 7-day non-High share, ST volume = previous 20-min bucket + current bucket up to the
-- session, dfac 1/1/1.5/2/2/2, List A/B/C skipped, Dict -1 skipped, clean = signature-window (40-min TIME_SLICE) < 20% High), plus:
--  * LT: ltc = DI_LONG_TERM_COUNT_AT_SESSION_CREATED; LT volume = key sessions on the previous UTC day + the current UTC day up to
--    and including the session (approximation: DI's long-term buckets assumed to be UTC calendar days);
--    fire_LT(m,f) = ltc > GREATEST(LEAST(f*60, {LTCUR}), share x LTvol x m x dlt), dlt = 1 (Dict 1, 3), 2 (7), 4 (15, 31), 6 (63).
-- Placeholders: {KEY}; {D0} replay day; {D1} = D0+1d; {B0} = D0-7d; {P0} = D0-20min; {Q0} = D0-1d; {L1} = D0+30h; {LTCUR} key's LT
--   threshold (Figma 660, Blizzard 1500); {FINAL} final SELECT (see 12_/13_/14_ files).
-- Rule flags (r0..r11): r0 today ST breached | r1 today LT breached | r2 today ST or LT | r3 ST m5 f11 | r4 ST m5 f8 | r5 ST m10 f8 |
--   r6 ST m5 f5 | r7 ST m10 f11 | r8 LT m5 f11 | r9 LT m5 f8 | r10 ST or LT, m5 f11 | r11 ST or LT, m5 f8.
WITH b0 AS (SELECT di_matched_signature_at_session_created ms, COUNT(*) c FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key='{KEY}' AND session_last_timestamp>='{B0}' AND session_last_timestamp<'{L1}' AND session_ts>='{B0}' AND session_ts<'{D0}'
  AND COALESCE(latest_risk_band,'')<>'High' GROUP BY 1),
sh AS (SELECT ms, c/SUM(c) OVER () share FROM b0),
pd AS (SELECT COUNT(*) pdn FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY WHERE public_key='{KEY}' AND session_last_timestamp>='{Q0}' AND session_last_timestamp<'{L1}'
  AND session_ts>='{Q0}' AND session_ts<'{D0}'),
a0 AS (SELECT session sid, session_ts ts, di_dictionary_num_matched_at_session_created d, di_matched_signature_at_session_created ms, os_at_session_created os,
  COALESCE(webgl_unmasked_renderer_at_session_created,'') r, COALESCE(cdn__ja4_hash_at_session_created,'') ja4, COALESCE(ua_at_session_created,'') ua,
  user_ip_at_session_created ip, cdn__asn_at_session_created asn, latest_isp isp,
  IFF(latest_risk_band='High',1,0) hi, IFF(sessions_verified>0,1,0) ver, IFF(was_challenged>0,1,0) chl, IFF(was_challenged>0 AND COALESCE(sessions_solved,0)=0,1,0) chns,
  di_short_term_count_at_session_created stc, di_long_term_count_at_session_created ltc,
  IFF(di_short_term_threshold_breached_at_session_created,1,0) stb, IFF(di_long_term_threshold_breached_at_session_created,1,0) ltb,
  TIME_SLICE(session_ts,20,'MINUTE') b20
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY WHERE public_key='{KEY}' AND session_last_timestamp>='{P0}' AND session_last_timestamp<'{L1}' AND session_ts>='{P0}' AND session_ts<'{D1}'),
bc AS (SELECT b20, COUNT(*) bn FROM a0 GROUP BY 1),
a1 AS (SELECT a0.*, COUNT(*) OVER (PARTITION BY a0.b20 ORDER BY ts, sid ROWS UNBOUNDED PRECEDING) + COALESCE(p.bn,0) vol
  FROM a0 LEFT JOIN bc p ON p.b20 = DATEADD(minute,-20,a0.b20)),
a2 AS (SELECT a1.*, COUNT(*) OVER (PARTITION BY TO_DATE(ts) ORDER BY ts, sid ROWS UNBOUNDED PRECEDING) + pd.pdn lvol FROM a1 CROSS JOIN pd WHERE ts>='{D0}'),
s1 AS (SELECT a2.*, CASE WHEN r ILIKE '%SwiftShader%' OR r ILIKE '%llvmpipe%' OR r ILIKE '%VirtualBox%' OR r ILIKE '%VMware%' THEN 'A'
  WHEN r ILIKE '%Basic Render Driver%' AND COALESCE(os,'')<>'Windows' THEN 'B' WHEN COALESCE(os,'') IN ('','--') AND r<>'' THEN 'B'
  WHEN ja4 LIKE 't%' AND SPLIT_PART(ja4,'_',2) IN ('a09f3c656075','2802a3db6c62') AND os IN ('Windows','GNU/Linux','Ubuntu','Chrome OS') THEN 'C'
  WHEN ua LIKE '%Chrome/%' AND RIGHT(SPLIT_PART(ja4,'_',1),2)='h1' THEN 'C' WHEN TRY_TO_NUMBER(REGEXP_SUBSTR(ua,'Chrome/([0-9]+)',1,1,'e',1))>=70 AND ja4 LIKE 't12%' THEN 'C' END AS x,
  CASE WHEN r ILIKE '%Basic Render Driver%' AND os='Windows' THEN 'WinRDVM' WHEN os IN ('Windows','OS X','Chrome OS') THEN 'Desktop' WHEN os IN ('iOS','iPadOS','Android') THEN 'Mobile'
  WHEN os IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'Other' END AS grp0,
  COALESCE(sh.share,0) share, CASE WHEN d IN (1,3) THEN 1 WHEN d=7 THEN 1.5 ELSE 2 END dfac,
  CASE WHEN d IN (1,3) THEN 1 WHEN d=7 THEN 2 WHEN d IN (15,31) THEN 4 ELSE 6 END dlt
  FROM a2 LEFT JOIN sh ON sh.ms=a2.ms WHERE a2.d IS NOT NULL),
s2 AS (SELECT s1.*, IFF(x IS NULL, grp0, 'SKIP_'||x) grp, IFF(x IS NULL AND ms IS NOT NULL AND d>0, 1, 0) elig,
  IFF(SUM(hi) OVER (PARTITION BY x, grp0, ms, TIME_SLICE(ts,40,'MINUTE')) / COUNT(*) OVER (PARTITION BY x, grp0, ms, TIME_SLICE(ts,40,'MINUTE')) < 0.2, 1, 0) cl FROM s1),
s3 AS (SELECT s2.*, stb r0, ltb r1, GREATEST(stb,ltb) r2,
  IFF(elig=1 AND stc > GREATEST(11, share*vol*5*dfac),1,0) r3, IFF(elig=1 AND stc > GREATEST(8, share*vol*5*dfac),1,0) r4,
  IFF(elig=1 AND stc > GREATEST(8, share*vol*10*dfac),1,0) r5, IFF(elig=1 AND stc > GREATEST(5, share*vol*5*dfac),1,0) r6,
  IFF(elig=1 AND stc > GREATEST(11, share*vol*10*dfac),1,0) r7,
  IFF(elig=1 AND ltc > GREATEST(LEAST(660,{LTCUR}), share*lvol*5*dlt),1,0) r8, IFF(elig=1 AND ltc > GREATEST(LEAST(480,{LTCUR}), share*lvol*5*dlt),1,0) r9 FROM s2),
s4 AS (SELECT s3.*, GREATEST(r3,r8) r10, GREATEST(r4,r9) r11 FROM s3)
{FINAL}
