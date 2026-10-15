-- Spike scan step 2: 2-, 3- and 4-flag combinations of a candidate vocabulary that spiked
-- across many keys. Snowflake (Superset database_id 14).
--
-- Params (UTC dates, end exclusive):
--   {win_start} {win_end} {win_days}   scan window
--   {base_start}                        baseline start (baseline = base_start .. win_start, 7 days)
--   {vocab}                             quoted, comma-separated flags (<= ~16; from step 1 + forced-in)
--   {max_arity}                         2, 3 or 4
--
-- How it stays fast: each sampled session's vocab membership is packed into one integer bitmask,
-- sessions are collapsed to (period, key, mask) counts, and every combo is tested against the
-- masks with BITAND -- no per-session self-joins.
-- 1% SYSTEM (block) sample: multiply counts by 100 for estimated sessions. Block sampling is
-- clumpy at small counts, so confirm finalists with 03_daily_by_key.sql before acting.
--
-- Spike rule per (combo, key): win_daily >= 10 sampled (~1k sessions/day)
--   AND win_daily >= 3x baseline daily AND share-of-key-traffic >= 2x baseline share.
WITH v AS (
  SELECT f.value::STRING AS flag, f.index AS idx
  FROM TABLE(FLATTEN(input => ARRAY_CONSTRUCT({vocab}))) f
),
s AS (
  SELECT
    SEQ8() AS rid,
    IFF(SESSION_TS >= '{win_start}', 'win', 'base') AS period,
    PUBLIC_KEY,
    ARRAY_CAT(COALESCE(SUSPICION_FLAGS::ARRAY, ARRAY_CONSTRUCT()),
              COALESCE(TELLTALE_LIST_AT_ALL_EVENTS::ARRAY, ARRAY_CONSTRUCT())) AS flags
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY SAMPLE SYSTEM (1)
  WHERE SESSION_TS >= '{base_start}' AND SESSION_TS < '{win_end}'
    AND PUBLIC_KEY_CATEGORY = 'Production'
),
key_tot AS (SELECT PUBLIC_KEY, period, COUNT(*) AS tot FROM s GROUP BY 1, 2),
sess_mask AS (
  SELECT s.rid, s.period, s.PUBLIC_KEY, BITOR_AGG(DISTINCT BITSHIFTLEFT(1::BIGINT, v.idx)) AS m
  FROM s, LATERAL FLATTEN(input => s.flags) f
  JOIN v ON v.flag = f.value::STRING
  GROUP BY 1, 2, 3
),
masks AS (SELECT period, PUBLIC_KEY, m, COUNT(*) AS n FROM sess_mask GROUP BY 1, 2, 3),
c AS (
  SELECT a.flag || ' + ' || b.flag AS combo, 2 AS arity,
         BITSHIFTLEFT(1::BIGINT, a.idx) + BITSHIFTLEFT(1::BIGINT, b.idx) AS cm
  FROM v a JOIN v b ON a.idx < b.idx
  UNION ALL
  SELECT a.flag || ' + ' || b.flag || ' + ' || x.flag, 3,
         BITSHIFTLEFT(1::BIGINT, a.idx) + BITSHIFTLEFT(1::BIGINT, b.idx) + BITSHIFTLEFT(1::BIGINT, x.idx)
  FROM v a JOIN v b ON a.idx < b.idx JOIN v x ON b.idx < x.idx
  WHERE {max_arity} >= 3
  UNION ALL
  SELECT a.flag || ' + ' || b.flag || ' + ' || x.flag || ' + ' || y.flag, 4,
         BITSHIFTLEFT(1::BIGINT, a.idx) + BITSHIFTLEFT(1::BIGINT, b.idx)
         + BITSHIFTLEFT(1::BIGINT, x.idx) + BITSHIFTLEFT(1::BIGINT, y.idx)
  FROM v a JOIN v b ON a.idx < b.idx JOIN v x ON b.idx < x.idx JOIN v y ON x.idx < y.idx
  WHERE {max_arity} >= 4
),
ck AS (
  SELECT c.combo, c.arity, masks.PUBLIC_KEY, masks.period, SUM(masks.n) AS n
  FROM c JOIN masks ON BITAND(masks.m, c.cm) = c.cm
  GROUP BY 1, 2, 3, 4
),
per_key AS (
  SELECT w.combo, w.arity, w.PUBLIC_KEY,
         w.n / kw.tot AS win_rate, COALESCE(b.n, 0) / NULLIF(kb.tot, 0) AS base_rate,
         w.n / {win_days} AS win_daily, COALESCE(b.n, 0) / 7 AS base_daily
  FROM ck w
  JOIN key_tot kw ON kw.PUBLIC_KEY = w.PUBLIC_KEY AND kw.period = 'win'
  LEFT JOIN ck b ON b.combo = w.combo AND b.PUBLIC_KEY = w.PUBLIC_KEY AND b.period = 'base'
  LEFT JOIN key_tot kb ON kb.PUBLIC_KEY = w.PUBLIC_KEY AND kb.period = 'base'
  WHERE w.period = 'win'
),
sp AS (
  SELECT *, (win_daily >= 10 AND win_daily >= 3 * base_daily
             AND win_rate >= 2 * COALESCE(base_rate, 0)) AS spk
  FROM per_key
)
SELECT combo, arity,
       COUNT(*) AS keys_present,
       COUNT_IF(spk) AS keys_spiking,
       ROUND(SUM(IFF(spk, (win_daily - base_daily) * 100, 0))) AS est_excess_per_day,
       -- share of the combo's window volume that sits on spiking keys (higher = cleaner signal)
       ROUND(SUM(IFF(spk, win_daily, 0)) / NULLIF(SUM(win_daily), 0), 2) AS spike_share,
       ARRAY_TO_STRING(ARRAY_AGG(IFF(spk, PUBLIC_KEY, NULL)), ',') AS spiking_keys
FROM sp
GROUP BY 1, 2
HAVING keys_spiking >= 4
ORDER BY keys_spiking DESC, spike_share DESC, est_excess_per_day DESC
LIMIT {limit}
