-- Tracking step: EXACT (unsampled) sessions per key for every tracked combo on ONE UTC day.
-- Snowflake (Superset database_id 14). ~10s per day; one day per query or it times out.
-- Params: {day} {next_day} {combo_cols} (built by render.py from combos.json).
-- Output: ONE cell, "key,total_sessions,c0,c1,...;key,..." (keys where any combo >= 300 that day).
-- Packed so the MCP response stays small; save it with: spike_report.py ingest --day {day} --packed '<cell>'.
-- c<i> = combos.json "combos"[i] at the time the query was rendered.
WITH s AS (
  SELECT PUBLIC_KEY,
         ARRAY_CAT(COALESCE(SUSPICION_FLAGS::ARRAY, ARRAY_CONSTRUCT()),
                   COALESCE(TELLTALE_LIST_AT_ALL_EVENTS::ARRAY, ARRAY_CONSTRUCT())) AS flags
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE SESSION_TS >= '{day}' AND SESSION_TS < '{next_day}'
    AND PUBLIC_KEY_CATEGORY = 'Production'
    AND ARRAY_SIZE(SUSPICION_FLAGS) > 0
),
per_key AS (
  SELECT PUBLIC_KEY AS k,
         COUNT(*) AS tot,
         {combo_cols}
  FROM s
  GROUP BY 1
  HAVING GREATEST({combo_max}) >= 300
)
SELECT LISTAGG(k || ',' || tot || ',' || {combo_concat}, ';') WITHIN GROUP (ORDER BY k) AS packed
FROM per_key
