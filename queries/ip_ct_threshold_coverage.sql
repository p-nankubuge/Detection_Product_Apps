-- IP connection-type (CT) velocity threshold coverage, per key.
--
-- Answers: "does this key have connection-type thresholds, and which IP
-- velocity telltales should SOC use on it?" A key+CT has a threshold only when
-- detection-apps (automated-thresholds cron, daily 16:00 UTC) has written one
-- to conf-api. When it has, detection-hub populates
-- rta__ip_connection_type_velocity_short_term_threshold on the session. When it
-- has not, that field (and the CT ratio fields) are empty and the
-- g-ip-connection-type-velocity-* telltales cannot fire for that session.
--
-- Same SQL as the Superset dataset "ip_ct_threshold_coverage_by_key_v2" behind the
-- "IP CT threshold coverage by key" chart (id 31922, dashboard 1663).
-- Run in Superset SQL Lab against the "Snowflake" database (id 14).
-- Change the date window, or uncomment the public_key filter, as needed.
--
-- coverage_tier / use_telltales:
--   FULL    >= 90% of sessions have a CT threshold -> use the CT telltales
--   PARTIAL 1-89%                                  -> use the legacy IP velocity telltales,
--                                                     exclude the CT telltales
--   NONE    0%                                     -> use the legacy IP velocity telltales

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
    AND public_key IS NOT NULL
    -- AND public_key = '<PUBLIC_KEY>'
),
per_ct AS (
  SELECT
    public_key,
    ct,
    COUNT(*)            AS sessions,
    COUNT(ct_threshold) AS sessions_with_ct_threshold,
    MAX(ip_threshold)   AS ip_threshold
  FROM s
  GROUP BY 1, 2
),
agg AS (
  SELECT
    public_key,
    SUM(sessions)                                                        AS sessions,
    SUM(sessions_with_ct_threshold)                                      AS sessions_with_ct_threshold,
    ROUND(100 * SUM(sessions_with_ct_threshold) / SUM(sessions), 1)      AS pct_ct_covered,
    CASE
      WHEN SUM(sessions_with_ct_threshold) = 0                 THEN 'NONE'
      WHEN SUM(sessions_with_ct_threshold) >= 0.9 * SUM(sessions) THEN 'FULL'
      ELSE 'PARTIAL'
    END                                                                  AS coverage_tier,
    LISTAGG(CASE WHEN sessions_with_ct_threshold > 0 THEN ct END, ', ')
      WITHIN GROUP (ORDER BY sessions DESC)                              AS cts_with_threshold,
    LISTAGG(CASE WHEN sessions_with_ct_threshold = 0 THEN ct END, ', ')
      WITHIN GROUP (ORDER BY sessions DESC)                              AS cts_without_threshold,
    MAX(ip_threshold)                                                    AS ip_short_term_threshold
  FROM per_ct
  GROUP BY 1
  HAVING SUM(sessions) >= 1000
)
SELECT
  k.account_name,
  k.name                    AS key_name,
  a.public_key,
  k.key_type_name           AS key_type,
  a.coverage_tier,
  CASE WHEN a.coverage_tier = 'FULL'
       THEN 'Connection-type TTs'
       ELSE 'Legacy IP velocity TTs (exclude CT TTs)'
  END                       AS use_telltales,
  a.pct_ct_covered,
  a.sessions,
  a.sessions_with_ct_threshold,
  a.cts_with_threshold,
  a.cts_without_threshold,
  a.ip_short_term_threshold
FROM agg a
LEFT JOIN dataswan.customer_keys k
  ON UPPER(k.public_key) = UPPER(a.public_key)
ORDER BY a.sessions DESC
