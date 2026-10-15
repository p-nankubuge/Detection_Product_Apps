-- Hourly exact sessions created / verified per key for every tracked combo -> "is it still ongoing?"
-- Snowflake (Superset database_id 14). One UTC day (or the part of today so far) per query.
-- Params: {ts_from} {ts_to} {key_filter} {anchors} {combo_bools} {combo_cols} {combo_concat} {combo_max}
-- render.py sql/05_hourly_by_key.sql --win-start <day> --keys data/chart_keys.txt --combos combos.json
-- Output: ONE cell "key,HH,c0,v0,c1,v1,...;..." -> spike_report.py hourly --day <day> --packed '<cell>'
WITH s AS (
  SELECT PUBLIC_KEY, HOUR(SESSION_TS) AS hh, COALESCE(SESSIONS_VERIFIED, 0) > 0 AS verified,
         ARRAY_CAT(COALESCE(SUSPICION_FLAGS::ARRAY, ARRAY_CONSTRUCT()),
                   COALESCE(TELLTALE_LIST_AT_ALL_EVENTS::ARRAY, ARRAY_CONSTRUCT())) AS flags
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE SESSION_TS >= '{ts_from}' AND SESSION_TS < '{ts_to}'
    AND PUBLIC_KEY_CATEGORY = 'Production'
    AND ({anchors}){key_filter}
),
m AS (
  SELECT PUBLIC_KEY, hh, verified,
         {combo_bools}
  FROM s
),
per_key AS (
  SELECT PUBLIC_KEY AS k, hh,
         {combo_cols}
  FROM m
  GROUP BY 1, 2
  HAVING GREATEST({combo_max}) >= 20   -- keeps the response under the MCP size cap
)
SELECT LISTAGG(k || ',' || hh || ',' || {combo_concat}, ';') WITHIN GROUP (ORDER BY k, hh) AS packed
FROM per_key
