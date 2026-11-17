-- Hotmail/Outlook handle-pattern rule sizing, Blizzard ROW Registration K2.
-- Athena; run in 12h windows (24h times out). ymdh format 'YYYY/MM/DD/HH'.
-- email__handle_pattern = LL AA DD SS 00 (length, letters, digits, specials; separators not counted).
-- See docs/blizzard-truth-gap-analysis.md section 12.
WITH truth AS (
  SELECT DISTINCT arkose_session_id sid FROM starfleet_production.truth_data_history
  WHERE ingest_timestamp > date_add('day', -40, current_date)
    AND public_key = 'E8A75615-1CBA-5DFF-8032-D16BCF234E10'
    AND session_create_timestamp >= TIMESTAMP '2026-11-09 12:00:00'
    AND session_create_timestamp <  TIMESTAMP '2026-11-10 00:00:00'
),
ev AS (
  SELECT session, location, verified, suspicion_flags sf, email__raw_email_domain dom,
         email__handle_pattern hp, di_dictionary_num_matched dm
  FROM arkoselabs.events_faster
  WHERE ymdh BETWEEN '2026/11/09/12' AND '2026/11/09/23'
    AND public_key = 'E8A75615-1CBA-5DFF-8032-D16BCF234E10'
    AND location IN ('session_setup', 'game_verify')
),
s AS (
  SELECT session,
         max(CASE WHEN location = 'game_verify' AND verified THEN 1 ELSE 0 END) v,
         max(CASE WHEN location = 'session_setup' THEN 1 ELSE 0 END) c,
         max(lower(dom)) dom,
         max(CASE WHEN regexp_like(hp, '^[0-9]{10}$') THEN hp END) hp,
         max(dm) dm
  FROM ev GROUP BY 1
),
x AS (
  SELECT s.*, CASE WHEN t.sid IS NOT NULL THEN 1 ELSE 0 END bad,
         cast(substr(hp,1,2) AS int) hl, cast(substr(hp,3,2) AS int) ha,
         cast(substr(hp,5,2) AS int) hd, substr(hp,7,4) hr
  FROM s LEFT JOIN truth t ON s.session = t.sid WHERE s.c = 1
),
l AS (
  SELECT bad, v, dm,
         regexp_like(coalesce(dom,''), '^(hotmail|outlook|live|msn)\.') hot,
         coalesce(hr='0000' AND hd=1 AND ha>=15 AND ha=hl-1, false)                   f1,   -- 4 Nov wave
         coalesce(hr='0000' AND hd>=8 AND ha>=5 AND ha+hd=hl, false)                  f2,   -- 4-6 Nov wave
         coalesce(hr='0000' AND ha>=15 AND (hd IN (0,1) OR hd>=8) AND ha+hd=hl, false) lg   -- static LONG rule
  FROM x
)
SELECT count_if(hot AND lg AND dm>=7 AND bad=1)          truth_hit,
       count_if(hot AND lg AND dm>=7 AND bad=0 AND v=1)  verified_not_truth,
       count_if(hot AND lg AND dm>=7 AND bad=0 AND v=0)  unverified_not_truth,
       count_if(hot AND bad=1)                           hotmail_truth,
       count(*)                                          created
FROM l;
