-- All sessions per key per UTC day (no array work, so a whole 11-day range fits in one query).
-- Snowflake (Superset database_id 14). Params: {base_start} {win_end}, {keys} = quoted key list.
-- Feeds the "share of key traffic" figures. Save with: spike_report.py totals --packed '<cell>'.
WITH t AS (
  SELECT SESSION_TS::DATE AS d, PUBLIC_KEY AS k, COUNT(*) AS n
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE SESSION_TS >= '{base_start}' AND SESSION_TS < '{win_end}'
    AND PUBLIC_KEY IN ({keys})
  GROUP BY 1, 2
)
SELECT LISTAGG(TO_CHAR(d, 'YYYY-MM-DD') || ',' || k || ',' || n, ';') WITHIN GROUP (ORDER BY k, d) AS packed
FROM t
