-- Traffic DROPS on any Production key (outage / integration change / key config change -- not an attack).
-- Snowflake (Superset database_id 14). Plain COUNT(*) per key, no array work.
-- Params (render.py): {base_start} {win_start} {win_end} {window_days} {recent_end} (last complete hour, 'YYYY-MM-DD HH:00:00').
-- Two checks, both against the key's own median:
--   D  = a window day below 40% of the key's median baseline day (baseline >= 5000 sessions/day) AND below 50% of the same
--        weekday one week earlier (so B2B keys' normal weekend dips are not reported as drops)
--   H6 = the last 6 complete hours below 40% of the median of the same 6 hours on the 7 previous days (baseline >= 300)
--   H1 = the last complete hour below 40% of the median of the same hour on the 7 previous days (baseline >= 100):
--        catches a drop that started within the last hour or two (e.g. a registration page that stopped calling the key)
-- Output: ONE cell "key,kind,when,sessions,baseline_median;..." -> spike_report.py drops --packed '<cell>'
WITH d AS (
  SELECT PUBLIC_KEY AS k, SESSION_TS::DATE AS d, COUNT(*) AS n
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE SESSION_TS >= '{base_start}' AND SESSION_TS < '{win_end}'
    AND PUBLIC_KEY_CATEGORY = 'Production'
  GROUP BY 1, 2
),
b AS (
  SELECT k, MEDIAN(n) AS med FROM d WHERE d < '{win_start}' GROUP BY k HAVING MEDIAN(n) >= 5000
),
wd AS (SELECT column1::DATE AS d FROM VALUES {window_days}),
day_drops AS (
  SELECT b.k, 'D' AS kind, TO_CHAR(wd.d, 'YYYY-MM-DD') AS w, COALESCE(d.n, 0) AS n, b.med
  FROM b CROSS JOIN wd LEFT JOIN d ON d.k = b.k AND d.d = wd.d
  LEFT JOIN d pw ON pw.k = b.k AND pw.d = DATEADD('day', -7, wd.d)
  WHERE COALESCE(d.n, 0) < 0.4 * b.med AND COALESCE(d.n, 0) < 0.5 * COALESCE(pw.n, b.med)
),
r AS (
  SELECT PUBLIC_KEY AS k, FLOOR(TIMESTAMPDIFF('second', SESSION_TS, '{recent_end}'::TIMESTAMP_NTZ) / 86400) AS back,
         COUNT(*) AS n6, COUNT_IF(MOD(TIMESTAMPDIFF('second', SESSION_TS, '{recent_end}'::TIMESTAMP_NTZ), 86400) < 3600) AS n1
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE SESSION_TS >= DATEADD('day', -8, '{recent_end}'::TIMESTAMP_NTZ) AND SESSION_TS < '{recent_end}'
    AND PUBLIC_KEY_CATEGORY = 'Production'
    AND MOD(TIMESTAMPDIFF('second', SESSION_TS, '{recent_end}'::TIMESTAMP_NTZ), 86400) < 21600
  GROUP BY 1, 2
),
rb AS (SELECT k, MEDIAN(n6) AS med6, MEDIAN(n1) AS med1 FROM r WHERE back BETWEEN 1 AND 7 GROUP BY k HAVING MEDIAN(n1) >= 100 OR MEDIAN(n6) >= 300),
hour_drops AS (
  SELECT rb.k, 'H6' AS kind, 'last6h' AS w, COALESCE(r.n6, 0) AS n, rb.med6 AS med
  FROM rb LEFT JOIN r ON r.k = rb.k AND r.back = 0
  WHERE rb.med6 >= 300 AND COALESCE(r.n6, 0) < 0.4 * rb.med6
  UNION ALL
  SELECT rb.k, 'H1' AS kind, 'last1h' AS w, COALESCE(r.n1, 0) AS n, rb.med1 AS med
  FROM rb LEFT JOIN r ON r.k = rb.k AND r.back = 0
  WHERE rb.med1 >= 100 AND COALESCE(r.n1, 0) < 0.4 * rb.med1
),
u AS (SELECT * FROM day_drops UNION ALL SELECT * FROM hour_drops)
SELECT LISTAGG(k || ',' || kind || ',' || w || ',' || n || ',' || ROUND(med), ';') WITHIN GROUP (ORDER BY kind, k, w) AS packed
FROM u
