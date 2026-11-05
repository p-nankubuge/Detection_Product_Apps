-- Suspicion-flag lift: truth Nonlegit vs unlabeled, verified sessions only.
-- Athena (Superset db "Athena"). Keep windows to ~6h or the Superset timeout hits.
-- Swap :key / window bounds. ymdh partition format is 'YYYY/MM/DD/HH'.
-- See docs/blizzard-truth-gap-analysis.md.
WITH truth AS (
  SELECT DISTINCT arkose_session_id AS sid
  FROM starfleet_production.truth_data_history
  WHERE ingest_timestamp > date_add('day', -40, current_date)
    AND public_key = 'E8A75615-1CBA-5DFF-8032-D16BCF234E10'           -- Blizzard ROW Registration K2
    AND session_create_timestamp BETWEEN TIMESTAMP '2026-10-21 00:00:00'
                                     AND TIMESTAMP '2026-10-21 06:00:00'
),
ev AS (
  SELECT session, location, suspicion_flags
  FROM arkoselabs.events_faster
  WHERE ymdh BETWEEN '2026/10/21/00' AND '2026/10/21/05'
    AND public_key = 'E8A75615-1CBA-5DFF-8032-D16BCF234E10'
    AND location IN ('session_setup', 'game_verify')
),
s AS (
  SELECT session,
         max_by(suspicion_flags, CASE WHEN location = 'session_setup' THEN 1 ELSE 0 END) AS sf,
         max(CASE WHEN location = 'game_verify' THEN 1 ELSE 0 END) AS v
  FROM ev GROUP BY 1
),
lab AS (
  SELECT s.*, CASE WHEN t.sid IS NOT NULL THEN 1 ELSE 0 END AS bad
  FROM s LEFT JOIN truth t ON s.session = t.sid
  WHERE s.v = 1                                  -- truth sessions are all verified
),
tot AS (SELECT sum(bad) nb, sum(1 - bad) ng FROM lab),
f AS (
  SELECT e AS flag, sum(bad) b, sum(1 - bad) g
  FROM lab CROSS JOIN UNNEST(sf) u(e) GROUP BY 1
)
SELECT flag, b, g,
       round(100.0 * b / nb, 1) AS bad_pct,
       round(100.0 * g / ng, 2) AS other_pct,
       round((1.0 * b / nb) / greatest(1.0 * g / ng, 0.00001), 1) AS lift
FROM f, tot
WHERE b >= 0.03 * nb
ORDER BY lift DESC;

-- Rule B (core-4) coverage, same CTEs up to `s`, then:
-- SELECT sum(bad) nb, sum(1-bad) ng,
--        sum(CASE WHEN b THEN bad END) b_hit, sum(CASE WHEN b THEN 1-bad END) other_hit
-- FROM (SELECT CASE WHEN t.sid IS NOT NULL THEN 1 ELSE 0 END bad,
--              contains(sf,'never-seen-before-fp-no-pressure')
--          AND contains(sf,'g-suspicious-extension-count-ja4-hash')
--          AND contains(sf,'github747b-h-email-free-domains')
--          AND NOT contains(sf,'dx-ip-user-ip-mismatch') AS b
--       FROM s LEFT JOIN truth t ON s.session = t.sid WHERE s.v = 1);
