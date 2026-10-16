-- Per-connection-type (CT) IP velocity threshold coverage, per key (events_faster / Athena)
--
-- Answers "does this key have a connection-type threshold, and for which connection types?"
-- The threshold lives in conf-api / DynamoDB (detection_hub_config.ip_velocity_thresholds_by_connection_type),
-- which Dataswan does not show. The session record is the reliable read-out: detection-hub stamps
-- rta__ip_connection_type_velocity_short_term_threshold on every session whose (key, CT) pair has one.
--
-- How to read the output:
--   ct_thresholds empty, n_ct_count > 0  -> key has NO per-CT threshold; base / ratio CT telltales cannot fire
--   ct_thresholds lists some CTs only     -> only those CTs are covered; other CTs fall back to ip-only telltales
--   n_ct_count = 0                        -> key is not emitting the RTA CT bucket at all (no RTA / edge path)
--
-- One hour of session_setup is enough: thresholds change at most once a day (cron 16:00 UTC).
-- Pick an hour after the most recent 16:00 UTC run.

SELECT
    public_key,
    COUNT(*)                                                         AS sessions,
    COUNT(rta__ip_connection_type_velocity_short_term_count)         AS n_ct_count,
    COUNT(rta__ip_connection_type_velocity_short_term_threshold)     AS n_with_ct_threshold,
    ROUND(100.0 * COUNT(rta__ip_connection_type_velocity_short_term_threshold) / COUNT(*), 1)
                                                                     AS pct_sessions_covered,
    ARRAY_JOIN(ARRAY_AGG(DISTINCT CASE
        WHEN rta__ip_connection_type_velocity_short_term_threshold IS NOT NULL
        THEN connection_type || ':' || CAST(rta__ip_connection_type_velocity_short_term_threshold AS VARCHAR)
            || '/' || CAST(rta__ip_connection_type_velocity_long_term_threshold AS VARCHAR)
    END), ', ')                                                      AS ct_thresholds,   -- ct:short/long
    MAX(rta_ip_velocity_short_term_threshold)                        AS ip_only_short_term_threshold
FROM arkoselabs.events_faster
WHERE ymdh = 'YYYY/MM/DD/HH'            -- e.g. '2026/10/15/00'
  AND location = 'session_setup'
  -- AND public_key = 'YOUR_PUBLIC_KEY' -- single-key check for a ticket
GROUP BY 1
HAVING COUNT(*) >= 100
ORDER BY sessions DESC;
