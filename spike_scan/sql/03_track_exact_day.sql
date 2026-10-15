-- Tracking step: EXACT (unsampled) sessions per key for every tracked combo, one 12h half (or a smaller --hours slice) of a UTC day.
-- Snowflake (Superset database_id 14). ~15s cold per half; a full day can exceed the Superset timeout.
-- render.py --half am|pm; ingest the am cell, then the pm cell with --add (sums into the same day).
-- Params: {day} {next_day} {anchors} {combo_bools} {combo_cols} (built by render.py from combos.json).
-- Rows are pre-filtered on each combo's FIRST flag (must be a suspicion flag) -- without that the
-- full-day scan times out. So total_sessions below is NOT the key's traffic; key totals come from
-- 04_key_totals.sql.
-- --keys FILE restricts to those keys (fast: the table prunes by key) and keeps every non-zero day.
-- Output: ONE cell, "key,anchor_sessions,c0,v0,c1,v1,...;key,..." (keys where any combo >= 150 in that half-day).
-- c<i> = sessions created that carry combo i, v<i> = of those, sessions verified (SESSIONS_VERIFIED > 0).
-- Packed so the MCP response stays small; save it with: spike_report.py ingest --day {day} --packed '<cell>'.
-- c<i> = combos.json "combos"[i] at the time the query was rendered.
WITH s AS (
  SELECT PUBLIC_KEY, COALESCE(SESSIONS_VERIFIED, 0) > 0 AS verified,
         ARRAY_CAT(COALESCE(SUSPICION_FLAGS::ARRAY, ARRAY_CONSTRUCT()),
                   COALESCE(TELLTALE_LIST_AT_ALL_EVENTS::ARRAY, ARRAY_CONSTRUCT())) AS flags
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE SESSION_TS >= '{ts_from}' AND SESSION_TS < '{ts_to}'
    AND PUBLIC_KEY_CATEGORY = 'Production'
    AND ({anchors}){key_filter}
),
m AS (
  SELECT PUBLIC_KEY, verified,
         {combo_bools}
  FROM s
),
per_key AS (
  SELECT PUBLIC_KEY AS k,
         COUNT(*) AS tot,
         {combo_cols}
  FROM m
  GROUP BY 1
  HAVING GREATEST({combo_max}) >= {min_sessions}
)
SELECT LISTAGG(k || ',' || tot || ',' || {combo_concat}, ';') WITHIN GROUP (ORDER BY k) AS packed
FROM per_key
