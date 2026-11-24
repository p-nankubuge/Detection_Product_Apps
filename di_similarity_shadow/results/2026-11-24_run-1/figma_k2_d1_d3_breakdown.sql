-- Figma Registration K2: Dict 1 and Dict 3 broken down by OS and by top-5 JA4
-- Window: 2026-11-20 12:00-14:00 UTC (game_verify joined to 15:00)
-- Source: ARK_PROD.events.vw_events (Superset database_id 14). No sampling.
-- Dict 63 is used as the "normal / known-real device" baseline.

-- Query 1: OS split for Dict 1, Dict 3 and Dict 63
WITH setup AS (
  SELECT session,
         MIN_BY(di_dictionary_num_matched, timestamp) AS dict,
         COALESCE(MIN_BY(os, timestamp), '(null)') AS os_name
  FROM ARK_PROD.events.vw_events
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND location = 'session_setup'
    AND timestamp >= '2026-11-20 12:00:00'
    AND timestamp <  '2026-11-20 14:00:00'
  GROUP BY session
)
SELECT os_name,
       COUNT_IF(dict = 1) AS d1,
       ROUND(100 * COUNT_IF(dict = 1) / SUM(COUNT_IF(dict = 1)) OVER (), 1) AS d1_pct,
       COUNT_IF(dict = 3) AS d3,
       ROUND(100 * COUNT_IF(dict = 3) / SUM(COUNT_IF(dict = 3)) OVER (), 1) AS d3_pct,
       COUNT_IF(dict = 63) AS d63,
       ROUND(100 * COUNT_IF(dict = 63) / SUM(COUNT_IF(dict = 63)) OVER (), 1) AS d63_pct,
       COUNT(*) AS all_dicts
FROM setup
GROUP BY os_name
ORDER BY all_dicts DESC;

-- Query 2: top 5 JA4s within Dict 1 and within Dict 3,
-- with how many Dict 63 sessions share the same JA4.
-- (First attempt failed: a window function inside COUNT_IF is not allowed in Snowflake.)
WITH setup AS (
  SELECT session,
         MIN_BY(di_dictionary_num_matched, timestamp) AS dict,
         COALESCE(MIN_BY(os, timestamp), '(null)') AS os_name,
         COALESCE(MIN_BY(cdn__ja4_hash, timestamp), '(null)') AS ja4
  FROM ARK_PROD.events.vw_events
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND location = 'session_setup'
    AND timestamp >= '2026-11-20 12:00:00'
    AND timestamp <  '2026-11-20 14:00:00'
  GROUP BY session
),
verify AS (
  SELECT DISTINCT session
  FROM ARK_PROD.events.vw_events
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND location = 'game_verify'
    AND timestamp >= '2026-11-20 12:00:00'
    AND timestamp <  '2026-11-20 15:00:00'
),
d63_ja4 AS (
  SELECT ja4, COUNT(*) AS d63_sessions FROM setup WHERE dict = 63 GROUP BY ja4
),
low AS (
  SELECT s.dict, s.ja4,
         COUNT(*) AS sessions,
         MODE(s.os_name) AS top_os,
         COUNT(DISTINCT s.os_name) AS n_os,
         COUNT(v.session) AS reached_verify
  FROM setup s LEFT JOIN verify v ON v.session = s.session
  WHERE s.dict IN (1, 3)
  GROUP BY s.dict, s.ja4
)
SELECT l.dict,
       ROW_NUMBER() OVER (PARTITION BY l.dict ORDER BY l.sessions DESC, l.ja4) AS rnk,
       l.ja4,
       l.sessions,
       ROUND(100 * l.sessions / SUM(l.sessions) OVER (PARTITION BY l.dict), 1) AS pct_of_dict,
       l.top_os,
       l.n_os,
       ROUND(100 * l.reached_verify / l.sessions, 0) AS reached_verify_pct,
       COALESCE(d.d63_sessions, 0) AS same_ja4_at_d63
FROM low l LEFT JOIN d63_ja4 d ON d.ja4 = l.ja4
QUALIFY rnk <= 5
ORDER BY l.dict, rnk;
