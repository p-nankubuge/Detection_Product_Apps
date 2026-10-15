-- Spike scan step 1 (discovery): which single suspicion flags / global telltales spiked, and on
-- how many keys. Snowflake (Superset database_id 14). ~15s.
-- Params: {win_start} {win_end} {win_days} {base_start}  (UTC dates, end exclusive; baseline = 7d before win_start)
-- Rates are per key (flag sessions / key sessions) so a key's overall traffic surge alone is not a spike.
-- 1% SYSTEM (block) sample: multiply by 100 for estimated sessions. Screening only -- block
-- sampling is clumpy, so finalists are confirmed with exact counts (03_track_exact_day.sql).
-- Spike rule per (flag, key): win_daily >= 20 sampled (~2k/day) AND >= 3x baseline daily
--   AND share-of-key-traffic >= 2x baseline share.
WITH s AS (
  SELECT
    IFF(SESSION_TS >= '{win_start}', 'win', 'base') AS period,
    PUBLIC_KEY,
    ARRAY_CAT(COALESCE(SUSPICION_FLAGS::ARRAY, ARRAY_CONSTRUCT()),
              COALESCE(TELLTALE_LIST_AT_ALL_EVENTS::ARRAY, ARRAY_CONSTRUCT())) AS flags
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY SAMPLE SYSTEM (1)
  WHERE SESSION_TS >= '{base_start}' AND SESSION_TS < '{win_end}'
    AND PUBLIC_KEY_CATEGORY = 'Production'
),
key_tot AS (SELECT PUBLIC_KEY, period, COUNT(*) AS tot FROM s GROUP BY 1, 2),
fk AS (
  SELECT s.PUBLIC_KEY, s.period, f.value::STRING AS flag, COUNT(*) AS n
  FROM s, LATERAL FLATTEN(input => ARRAY_DISTINCT(s.flags)) f
  WHERE f.value::STRING NOT IN ('g-global-telltales-enabled')
    AND f.value::STRING NOT LIKE '%do-not-pressure%'
  GROUP BY 1, 2, 3
),
per_key AS (
  SELECT w.flag, w.PUBLIC_KEY,
         w.n / kw.tot AS win_rate,
         COALESCE(b.n, 0) / NULLIF(kb.tot, 0) AS base_rate,
         w.n / {win_days} AS win_daily, COALESCE(b.n, 0) / 7 AS base_daily
  FROM fk w
  JOIN key_tot kw ON kw.PUBLIC_KEY = w.PUBLIC_KEY AND kw.period = 'win'
  LEFT JOIN fk b ON b.flag = w.flag AND b.PUBLIC_KEY = w.PUBLIC_KEY AND b.period = 'base'
  LEFT JOIN key_tot kb ON kb.PUBLIC_KEY = w.PUBLIC_KEY AND kb.period = 'base'
  WHERE w.period = 'win'
),
sp AS (
  SELECT *, (win_daily >= 20 AND win_daily >= 3 * base_daily
             AND win_rate >= 2 * COALESCE(base_rate, 0)) AS spk
  FROM per_key
)
SELECT flag,
       COUNT(*) AS keys_present,
       COUNT_IF(spk) AS keys_spiking,
       ROUND(SUM(IFF(spk, (win_daily - base_daily) * 100, 0))) AS est_excess_per_day,
       ROUND(SUM(win_daily) * 100) AS est_win_per_day,
       ROUND(SUM(base_daily) * 100) AS est_base_per_day
FROM sp
GROUP BY 1
HAVING keys_spiking >= 3
ORDER BY keys_spiking DESC, est_excess_per_day DESC
LIMIT {limit}
