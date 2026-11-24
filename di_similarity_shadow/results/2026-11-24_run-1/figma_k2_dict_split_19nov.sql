-- Figma Registration K2: sessions and verify rate by champion DI dictionary
-- Window: 2026-11-19 12:00-14:00 UTC (game_verify joined to 15:00 for late finishers)
-- Source: ARK_PROD.events.vw_events (Superset database_id 14). No sampling.
-- timestamp is TIMESTAMP_NTZ; confirmed UTC by comparing MAX(timestamp) with SYSDATE() (0 min apart).

WITH setup AS (
  SELECT session,
         MIN_BY(di_dictionary_num_matched, timestamp) AS dict   -- earliest setup row per session
  FROM ARK_PROD.events.vw_events
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND location = 'session_setup'
    AND timestamp >= '2026-11-19 12:00:00'
    AND timestamp <  '2026-11-19 14:00:00'
  GROUP BY session
),
verify AS (
  SELECT session,
         COUNT(*) AS gv_rows,
         COUNT_IF(verified::BOOLEAN) AS verified_rows
  FROM ARK_PROD.events.vw_events
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND location = 'game_verify'
    AND timestamp >= '2026-11-19 12:00:00'
    AND timestamp <  '2026-11-19 15:00:00'
  GROUP BY session
)
SELECT s.dict,
       COUNT(*) AS sessions,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_sessions,
       COUNT(v.session) AS reached_verify,
       COUNT_IF(v.verified_rows > 0) AS verified,
       ROUND(100 * COUNT_IF(v.verified_rows > 0) / COUNT(*), 2) AS verify_rate_all_pct,
       ROUND(100 * COUNT_IF(v.verified_rows > 0) / NULLIF(COUNT(v.session), 0), 2) AS verify_rate_reached_pct
FROM setup s
LEFT JOIN verify v ON v.session = s.session
GROUP BY s.dict
ORDER BY s.dict;
