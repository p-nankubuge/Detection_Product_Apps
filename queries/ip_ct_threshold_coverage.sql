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
-- Same SQL as the Superset saved query 1068 and the dataset
-- "ip_ct_threshold_coverage_by_key_v3" behind chart 31923 (dashboard 1663).
-- Written without CTEs because Superset could not wrap the WITH version.
-- Run in Superset SQL Lab against the "Snowflake" database (id 14).
-- Change the date window, or uncomment a filter, as needed.
--
-- coverage_tier / use_telltales:
--   FULL    >= 90% of sessions have a CT threshold -> CT telltales (legacy optional)
--   PARTIAL 1-89%                                  -> CT telltales + legacy IP velocity telltales
--   NONE    0%                                     -> legacy IP velocity telltales only

SELECT
  k.account_name,
  k.name AS key_name,
  a.public_key,
  a.coverage_tier,
  CASE WHEN a.coverage_tier = 'NONE' THEN 'Legacy IP velocity TTs only'
       WHEN a.coverage_tier = 'PARTIAL' THEN 'CT TTs + legacy IP velocity TTs'
       ELSE 'CT TTs (legacy optional)' END AS use_telltales,
  a.pct_ct_covered,
  a.sessions,
  a.cts_with_threshold,
  a.cts_without_threshold,
  a.ip_short_term_threshold,
  k.key_type_name AS key_type
FROM (
  SELECT
    p.public_key,
    SUM(p.sessions) AS sessions,
    ROUND(100 * SUM(p.sessions_with_ct_threshold) / SUM(p.sessions), 1) AS pct_ct_covered,
    CASE WHEN SUM(p.sessions_with_ct_threshold) = 0 THEN 'NONE'
         WHEN SUM(p.sessions_with_ct_threshold) >= 0.9 * SUM(p.sessions) THEN 'FULL'
         ELSE 'PARTIAL' END AS coverage_tier,
    LISTAGG(CASE WHEN p.sessions_with_ct_threshold > 0 THEN p.ct END, ', ') WITHIN GROUP (ORDER BY p.sessions DESC) AS cts_with_threshold,
    LISTAGG(CASE WHEN p.sessions_with_ct_threshold = 0 THEN p.ct END, ', ') WITHIN GROUP (ORDER BY p.sessions DESC) AS cts_without_threshold,
    MAX(p.ip_threshold) AS ip_short_term_threshold
  FROM (
    SELECT
      public_key,
      COALESCE(connection_type, 'absent') AS ct,
      COUNT(*) AS sessions,
      COUNT(rta__ip_connection_type_velocity_short_term_threshold) AS sessions_with_ct_threshold,
      MAX(rta_ip_velocity_short_term_threshold) AS ip_threshold
    FROM events.events_log
    WHERE timestamp >= DATEADD(day, -1, CURRENT_DATE)
      AND timestamp < CURRENT_DATE
      AND location = 'session_setup'
      AND public_key IS NOT NULL
      -- AND public_key = '<PUBLIC_KEY>'
    GROUP BY 1, 2
  ) p
  GROUP BY 1
  HAVING SUM(p.sessions) >= 1000
) a
LEFT JOIN dataswan.customer_keys k
  ON UPPER(k.public_key) = UPPER(a.public_key)
-- WHERE k.account_name ILIKE '%pinterest%'
ORDER BY a.sessions DESC
