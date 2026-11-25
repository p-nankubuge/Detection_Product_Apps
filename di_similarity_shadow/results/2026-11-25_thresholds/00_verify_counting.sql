-- Run 2026-11-25. Snowflake (Superset database_id 14). Read-only.
-- (a) What today's DI records on Figma Registration K2 for 20 Nov: per dict, sessions, distinct matched signatures,
--     ST / LT breached, ratio >= 2 / >= 4, counts, and the implied thresholds (count / ratio).
SELECT di_dictionary_num_matched_at_session_created d, COUNT(*) n, COUNT(DISTINCT di_matched_signature_at_session_created) nms,
  COUNT_IF(di_short_term_threshold_breached_at_session_created) stb, COUNT_IF(di_long_term_threshold_breached_at_session_created) ltb,
  COUNT_IF(di_short_term_threshold_ratio_at_session_created>=2) st2, COUNT_IF(di_short_term_threshold_ratio_at_session_created>=4) st4,
  COUNT_IF(di_short_term_threshold_ratio_at_session_created IS NULL) stnull,
  MEDIAN(di_short_term_count_at_session_created) stc_med, MAX(di_short_term_count_at_session_created) stc_max,
  MEDIAN(di_long_term_count_at_session_created) ltc_med,
  APPROX_TOP_K(ROUND(di_short_term_count_at_session_created/NULLIF(di_short_term_threshold_ratio_at_session_created,0),1),4) st_thr,
  APPROX_TOP_K(ROUND(di_long_term_count_at_session_created/NULLIF(di_long_term_threshold_ratio_at_session_created,0),1),4) lt_thr,
  APPROX_TOP_K(ROUND(di_short_term_percent_at_session_created,3),3) stp
FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
WHERE public_key='A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
  AND session_last_timestamp>='2026-11-20' AND session_last_timestamp<'2026-11-21 06:00'
  AND session_ts>='2026-11-20' AND session_ts<'2026-11-21'
GROUP BY 1 ORDER BY 1;
-- Result (20 Nov, 88,614 sessions): implied ST threshold = 11 and LT threshold = 660 for EVERY dict and session;
-- di_short_term_percent = 0.01 everywhere. No ratio NULL except 6 sessions with dict NULL.
--  d   | n      | matched sigs | ST breached | LT breached | ST ratio>=2 | >=4 | ST count med / max | LT count med
--  -1  |      6 |      1 |   0 | 0 |  0 | 0 | 1 / 2  | 8.5
--   1  |    232 |     33 |   0 | 0 |  0 | 0 | 2 / 8  | 55.5
--   3  |  4,773 |    840 |  43 | 0 |  0 | 0 | 1 / 20 | 11
--   7  | 11,011 |  5,205 |  45 | 0 |  8 | 0 | 1 / 27 | 2
--  15  |  9,864 |  7,330 |  45 | 0 |  7 | 0 | 1 / 28 | 1
--  31  | 14,705 |  9,279 |  46 | 0 | 23 | 0 | 1 / 36 | 1
--  63  | 48,017 | 20,485 | 202 | 0 | 63 | 4 | 1 / 47 | 3
--  NULL|      6 |      0 |   - | - |  - | - | -      | -

-- (b) What signature and window today's count uses. For sessions created 20 Nov 12:00-14:00 (all with ST count >= 3, plus a
--     1-in-20 hash sample of the rest), recount same-key sessions with the same DI_MATCHED_SIGNATURE_AT_SESSION_CREATED in the
--     preceding 10/20/30/40/60 min and 6/12/24 h (inclusive of the session), and compare with the recorded counts.
WITH s AS (SELECT session, session_ts ts, di_matched_signature_at_session_created ms, di_dictionary_num_matched_at_session_created d,
    di_short_term_count_at_session_created stc, di_long_term_count_at_session_created ltc
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key='A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND session_last_timestamp>='2026-11-19' AND session_last_timestamp<'2026-11-21 06:00'
    AND session_ts>='2026-11-19' AND session_ts<'2026-11-21' AND di_matched_signature_at_session_created IS NOT NULL),
t AS (SELECT * FROM s WHERE ts>='2026-11-20 12:00' AND ts<'2026-11-20 14:00' AND (stc>=3 OR MOD(ABS(HASH(session)),20)=0)),
j AS (SELECT t.session, t.d, t.stc, t.ltc,
    COUNT_IF(s.ts>DATEADD(minute,-10,t.ts)) c10, COUNT_IF(s.ts>DATEADD(minute,-20,t.ts)) c20, COUNT_IF(s.ts>DATEADD(minute,-30,t.ts)) c30,
    COUNT_IF(s.ts>DATEADD(minute,-40,t.ts)) c40, COUNT_IF(s.ts>DATEADD(minute,-60,t.ts)) c60,
    COUNT_IF(s.ts>DATEADD(hour,-6,t.ts)) h6, COUNT_IF(s.ts>DATEADD(hour,-12,t.ts)) h12, COUNT(*) h24
  FROM t JOIN s ON s.ms=t.ms AND s.ts<=t.ts AND s.ts>DATEADD(hour,-24,t.ts) GROUP BY 1,2,3,4)
SELECT COUNT(*) n, AVG(stc) stc, COUNT_IF(c10=stc) e10, COUNT_IF(c20=stc) e20, COUNT_IF(c30=stc) e30, COUNT_IF(c40=stc) e40,
  COUNT_IF(c60=stc) e60, CORR(stc,c10) r10, CORR(stc,c20) r20, CORR(stc,c30) r30, CORR(stc,c40) r40, CORR(stc,c60) r60,
  AVG(c10) a10, AVG(c20) a20, AVG(c40) a40, AVG(c60) a60, AVG(ltc) ltc, AVG(h6) a6, AVG(h12) a12, AVG(h24) a24,
  CORR(ltc,h6) q6, CORR(ltc,h12) q12, CORR(ltc,h24) q24, COUNT_IF(h24=ltc) e24
FROM j;
-- Result: 1,043 test sessions, mean recorded ST count 3.33.
--  window | exact match | corr  | mean recount
--  10 min | 593 (57%)   | 0.786 | 2.41
--  20 min | 671 (64%)   | 0.918 | 3.03
--  30 min | 716 (69%)   | 0.943 | -
--  40 min | 765 (73%)   | 0.940 | 3.83
--  60 min | 659 (63%)   | 0.862 | 4.39
--  LT: mean recorded 30.2; recount 6 h 11.9 (corr 0.909), 12 h 17.9 (0.936), 24 h 34.7 (0.936, exact 320/1,043).
-- Reading: the ST count is a count of same-key sessions with the same MATCHED signature (the prefix at the matched dict level)
-- over a ~30-40 min trailing window (best fit 30-40 min; not exact, consistent with a bucketed sliding estimate:
-- vw_events also carries DI_SHORT_TERM_CURRENT_BUCKET_COUNT / _PREVIOUS_BUCKET_COUNT). LT is ~12-24 h. Not confirmed from code.

-- (c) vw_events, Figma K2, session_setup 20 Nov 12:00-13:00, sessions with DI_SHORT_TERM_COUNT >= 2: is the count two buckets?
SELECT COUNT(*) n,
  COUNT_IF(di_short_term_count = di_short_term_current_bucket_count + di_short_term_previous_bucket_count) st_sum,
  COUNT_IF(di_short_term_count = di_short_term_current_bucket_count) st_cur,
  COUNT_IF(di_long_term_count = di_long_term_current_bucket_count + di_long_term_previous_bucket_count) lt_sum,
  AVG(di_short_term_count) st, AVG(di_short_term_current_bucket_count) cur, AVG(di_short_term_previous_bucket_count) prev,
  APPROX_TOP_K(di_dictionary_used,3) du
FROM ARK_PROD.events.vw_events
WHERE public_key='A207F8A1-ED09-4325-ACE6-C8E26A458FBA' AND location='session_setup'
  AND timestamp>='2026-11-20 12:00' AND timestamp<'2026-11-20 13:00' AND di_short_term_count>=2;
-- Result: 851 rows; ST count = current + previous bucket count on 851/851 (current alone on 560); LT count = current + previous
-- on 851/851. Mean ST 2.86 = 2.40 current + 0.46 previous. One dictionary version (23454).
-- Reading: today's velocity count is a two-bucket count (current partial bucket + the whole previous bucket), so it covers
-- between one and two bucket lengths. With (b) best-fitting 30-40 min, a 20-min bucket is the likely size (window 20-40 min);
-- the bucket length itself was NOT confirmed (no config/code access).
