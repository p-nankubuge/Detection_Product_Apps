-- Follow-up (run in the main session, not by the agent): were rule hits already challenged by today's system?
-- Key: A207F8A1-ED09-4325-ACE6-C8E26A458FBA (Figma Registration K2). Sessions created October 2026. No sampling.
-- Rule definitions: identical to _flags_cte.sql (s / f / r / flags CTEs), with was_challenged and sessions_solved added to s.
-- First attempt used UNION ALL (one branch per group) and timed out: it scanned the month 7 times.
-- This version scans once and joins each session to the groups it belongs to.

-- <s, f, r CTEs exactly as in _flags_cte.sql, with these extra columns selected in s:
--    was_challenged, sessions_solved, sessions_verify_attempted>
-- flags AS (SELECT dict, risk_band, was_challenged, sessions_solved, sessions_verify_attempted, c2, c3, n9, n10, n11 FROM r),

groups AS (
  SELECT column1 AS grp FROM VALUES ('0_all_sessions'), ('1_dict63'), ('C2'), ('C3'), ('N9'), ('N10'), ('N11')
)
SELECT g.grp,
  COUNT(*) AS sessions,
  ROUND(100 * COUNT_IF(was_challenged > 0) / COUNT(*), 1) AS challenged_pct,
  ROUND(100 * COUNT_IF(was_challenged > 0 AND NOT (sessions_solved > 0)) / COUNT(*), 1) AS challenged_not_solved_pct,
  ROUND(100 * COUNT_IF(NOT (sessions_verify_attempted > 0)) / COUNT(*), 1) AS no_verify_pct,
  ROUND(100 * COUNT_IF(risk_band = 'High') / COUNT(*), 2) AS high_risk_pct,
  ROUND(100 * COUNT_IF(dict = 63) / COUNT(*), 1) AS at_dict63_pct,
  ROUND(100 * COUNT_IF(dict <= 3) / COUNT(*), 1) AS at_dict_le3_pct
FROM flags
JOIN groups g ON g.grp = '0_all_sessions'
  OR (g.grp = '1_dict63' AND flags.dict = 63)
  OR (g.grp = 'C2' AND c2) OR (g.grp = 'C3' AND c3) OR (g.grp = 'N9' AND n9)
  OR (g.grp = 'N10' AND n10) OR (g.grp = 'N11' AND n11)
GROUP BY g.grp
ORDER BY g.grp;

-- Follow-up 2: N9 hits by IP tag, one day (15 Oct 2026), vw_events (vpn_proxy_description is only there).
-- Simplified N9: UA starts with 'Mozilla/' and JA4 ALPN = '00' (no browser-family parsing).
WITH s AS (
  SELECT session,
         MIN_BY(cdn__ja4_hash, timestamp) AS ja4,
         MIN_BY(ua, timestamp) AS ua,
         COALESCE(MIN_BY(vpn_proxy_description, timestamp), '(none)') AS ip_tag
  FROM ARK_PROD.events.vw_events
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND location = 'session_setup'
    AND timestamp >= '2026-10-15 00:00:00' AND timestamp < '2026-10-16 00:00:00'
  GROUP BY session
),
f AS (
  SELECT ip_tag,
         COALESCE(ja4 IS NOT NULL AND ua LIKE 'Mozilla/%' AND SUBSTR(SPLIT_PART(ja4, '_', 1), 9, 2) = '00', FALSE) AS n9
  FROM s
)
SELECT ip_tag,
       COUNT_IF(n9) AS n9_hits,
       ROUND(100 * COUNT_IF(n9) / SUM(COUNT_IF(n9)) OVER (), 1) AS pct_of_n9_hits,
       COUNT(*) AS all_sessions,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_all_sessions,
       ROUND(100 * COUNT_IF(n9) / COUNT(*), 1) AS n9_rate_within_tag
FROM f
GROUP BY ip_tag
ORDER BY n9_hits DESC;
