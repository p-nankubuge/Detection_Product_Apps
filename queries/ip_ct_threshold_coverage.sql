-- IP connection-type (CT) velocity threshold coverage, per key.
--
-- Answers: "does this key have connection-type thresholds, and for which
-- connection types?" A key+CT has a threshold only when detection-apps
-- (automated-thresholds cron, daily 16:00 UTC) has written one to conf-api.
-- When it has, detection-hub populates
-- rta__ip_connection_type_velocity_short_term_threshold on the session.
-- When it has not, that field (and the CT ratio fields) are empty and the
-- g-ip-connection-type-velocity-* telltales cannot fire for that session.
--
-- Run in Superset SQL Lab against the "Snowflake" database (id 14).
-- Change the date window and the public_key filter as needed.
--
-- coverage_tier:
--   FULL    >= 90% of sessions have a CT threshold  -> CT telltales cover the key
--   PARTIAL 1-89%                                   -> CT telltales cover some CTs only;
--                                                      keep the legacy IP telltales
--   NONE    0%                                      -> legacy IP telltales only

WITH s AS (
  SELECT
    public_key,
    COALESCE(connection_type, 'absent')                   AS ct,
    rta__ip_connection_type_velocity_short_term_threshold AS ct_threshold,
    rta_ip_velocity_short_term_threshold                  AS ip_threshold
  FROM events.events_log
  WHERE timestamp >= DATEADD(day, -1, CURRENT_DATE)
    AND timestamp <  CURRENT_DATE
    AND location = 'session_setup'
    -- AND public_key = '<PUBLIC_KEY>'
)
SELECT
  public_key,
  COUNT(*)                                             AS sessions,
  COUNT(ct_threshold)                                  AS sessions_with_ct_threshold,
  ROUND(100 * COUNT(ct_threshold) / COUNT(*), 1)       AS pct_ct_covered,
  CASE
    WHEN COUNT(ct_threshold) = 0                 THEN 'NONE'
    WHEN COUNT(ct_threshold) >= 0.9 * COUNT(*)   THEN 'FULL'
    ELSE 'PARTIAL'
  END                                                  AS coverage_tier,
  LISTAGG(DISTINCT CASE WHEN ct_threshold IS NOT NULL THEN ct END, ',')
                                                       AS cts_with_threshold,
  LISTAGG(DISTINCT CASE WHEN ct_threshold IS NULL THEN ct END, ',')
                                                       AS cts_without_threshold,
  MAX(ip_threshold)                                    AS ip_short_term_threshold
FROM s
GROUP BY 1
HAVING COUNT(*) >= 5000
ORDER BY sessions DESC;

-- Per connection type detail for one key (thresholds in force and traffic share):
--
-- SELECT COALESCE(connection_type, 'absent') AS ct,
--        COUNT(*) AS sessions,
--        MAX(rta__ip_connection_type_velocity_short_term_threshold) AS ct_short_term_threshold,
--        MAX(rta__ip_connection_type_velocity_long_term_threshold)  AS ct_long_term_threshold,
--        MAX(rta_ip_velocity_short_term_threshold)                  AS ip_short_term_threshold
-- FROM events.events_log
-- WHERE timestamp >= DATEADD(day, -1, CURRENT_DATE) AND timestamp < CURRENT_DATE
--   AND location = 'session_setup' AND public_key = '<PUBLIC_KEY>'
-- GROUP BY 1 ORDER BY sessions DESC;
