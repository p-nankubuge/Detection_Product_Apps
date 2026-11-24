-- Truth-data label completeness, Figma Registration K2, October 2026 sessions (Athena / Trino, database_id 2).
-- TD partitions: year = 2026, month IN (10, 11) (ingest 1 Oct -> 24 Nov = 3.5 weeks after the window end);
-- then session_create_timestamp in [2026-10-01, 2026-11-01). Latest label per session (max_by ingest_timestamp).
-- Result: 48,096 labelled sessions (29,456 Legit, 18,640 Nonlegit of which 18,627 is_verified = 1);
--         7 sessions had > 1 TD row, 0 had conflicting labels.
-- Denominator (verified sessions per day) comes from Snowflake:
--   SELECT TO_DATE(session_ts) d, COUNT_IF(sessions_verified > 0) v
--   FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
--   WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
--     AND session_last_timestamp >= '2026-10-01' AND session_last_timestamp < '2026-11-01 06:00:00'
--     AND session_ts >= '2026-10-01' AND session_ts < '2026-11-01'
--   GROUP BY 1 ORDER BY 1;
WITH td AS (
  SELECT arkose_session_id,
         max_by(is_legit, ingest_timestamp) AS lbl,
         max_by(is_verified, ingest_timestamp) AS ver,
         CAST(date(min(session_create_timestamp)) AS varchar) AS d,
         count(*) AS nrows,
         count(DISTINCT is_legit) AS nl
  FROM starfleet_production.truth_data_history
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND year = 2026 AND month IN (10, 11)
    AND session_create_timestamp >= TIMESTAMP '2026-10-01 00:00:00'
    AND session_create_timestamp <  TIMESTAMP '2026-11-01 00:00:00'
  GROUP BY 1
)
SELECT d, count(*) AS labelled, count_if(lbl = 'Legit') AS legit, count_if(lbl = 'Nonlegit') AS nonlegit,
       count_if(lbl = 'Nonlegit' AND ver = 1) AS nonlegit_ver, count_if(ver = 1) AS ver1,
       count_if(nrows > 1) AS multi, count_if(nl > 1) AS conflict
FROM td
GROUP BY ROLLUP(d)
ORDER BY 1;
