-- Whitelist size and session-window cross-check (Snowflake, database_id 14). Both run 2026-11-25.

-- (1) Session window: Figma Registration K2, sessions created 2026-11-20 12:00-14:00 UTC, by today's dict.
-- Result: 9,156 sessions (one row per session; matches run 1's 9,156 from first session_setup row in vw_events).
--   -1: 1 | 1: 23 | 3: 446 | 7: 1,138 | 15: 1,055 | 31: 1,470 | 63: 5,023.
--   Every session has a 6-part DI_HIGHEST_SIGNATURE_AT_SESSION_CREATED, a non-empty OS and non-empty screen /
--   device_params, so the "no score" column is empty in this window.
WITH s AS (
  SELECT session, di_dictionary_num_matched_at_session_created AS d, di_highest_signature_at_session_created AS h
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND session_last_timestamp >= '2026-11-20 12:00'
    AND session_ts >= '2026-11-20 12:00' AND session_ts < '2026-11-20 14:00'
)
SELECT d, COUNT(*) AS n, COUNT(DISTINCT session) AS ns, COUNT(DISTINCT h) AS nh,
       COUNT_IF(h IS NULL OR h = '') AS h_null, COUNT_IF(ARRAY_SIZE(SPLIT(h, '||')) <> 6) AS not6,
       COUNT_IF(SPLIT_PART(SPLIT_PART(h, '||', 1), '::', 1) IN ('', '--')) AS no_os,
       COUNT_IF(SPLIT_PART(h, '||', 4) = '') AS no_dp, COUNT_IF(SPLIT_PART(h, '||', 3) = '') AS no_scr
FROM s GROUP BY d ORDER BY d;

-- (2) Whitelist: distinct Dict 63 signatures on this key, sessions created 2026-11-13 00:00 to 2026-11-20 00:00 UTC.
-- UNCLEANED (no List A/B/C, no N-rules, no eligibility). 21 s.
WITH w AS (
  SELECT di_highest_signature_at_session_created AS h
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND session_last_timestamp >= '2026-11-13 00:00' AND session_last_timestamp < '2026-11-20 06:00'
    AND session_ts >= '2026-11-13 00:00' AND session_ts < '2026-11-20 00:00'
    AND di_dictionary_num_matched_at_session_created = 63
)
SELECT SPLIT_PART(SPLIT_PART(h, '||', 1), '::', 1) AS osf, COUNT(*) AS sessions, COUNT(DISTINCT h) AS sigs,
  COUNT(DISTINCT SPLIT_PART(h, '||', 2)) AS ja4s, COUNT(DISTINCT SPLIT_PART(h, '||', 3)) AS screens,
  COUNT(DISTINCT SPLIT_PART(h, '||', 4)) AS dps, COUNT(DISTINCT SPLIT_PART(h, '||', 5)) AS uas,
  COUNT(DISTINCT SPLIT_PART(h, '||', 6)) AS gls, COUNT(DISTINCT SPLIT_PART(SPLIT_PART(h, '||', 1), '::', 2)) AS osvs
FROM w GROUP BY ROLLUP (1) ORDER BY 2 DESC;
-- Result (osf | sessions | signatures | JA4s | screens | device_params | UAs | WebGL blocks | OS versions):
--   ALL          364,042  65,959  211  2,954  973  906  1,178  90
--   Windows      194,797  36,910  149    269  667   80    603   1
--   OS X          80,550  16,816   87  1,197  149  105    114  19
--   Android       42,725   7,328   30  1,372   23  175    346  10
--   iOS           34,337   2,095    6     16    3  353      3  73
--   Chrome OS      4,978   1,256   32     77   18   17     51   1
--   iPadOS         3,510     501    5     15    4  110      3  35
--   GNU/Linux      2,738     876   76    217   88   37    173   1
--   Ubuntu           374     160    4      8   22   12     16   1
--   Meta Horizon      14       4    1      1    1    4      2   1
--   HarmonyOS         10       5    1      3    1    5      3   1
--   Fire OS            5       5    2      2    1    5      2   2
--   OpenHarmony        4       3    1      3    2    3      2   1
