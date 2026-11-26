-- Step 1 of the truth fingerprint check (Athena, Superset database_id 2). Samples labelled session ids for ONE key.
-- Filter on session_create_timestamp (labels arrive late: year/month/day partitions are the UPLOAD date, e.g. Oct 6
-- sessions uploaded Nov 18). Params: {key}, {ts_from}, {ts_to}, {n} per label.
-- Output: one cell "L:<id,id,...>#F:<id,...>#R:<first session ts>,<last session ts>" -> truth_fp.py sql (renders step 2).
WITH t AS (
  SELECT arkose_session_id sid, max(is_legit_value) lv, min(session_create_timestamp) ts
  FROM starfleet_production.truth_data_history
  WHERE year = 2026 AND public_key = '{key}'
    AND session_create_timestamp >= timestamp '{ts_from} 00:00:00' AND session_create_timestamp < timestamp '{ts_to} 00:00:00'
  GROUP BY 1),
r AS (SELECT sid, lv, ts, row_number() OVER (PARTITION BY lv ORDER BY random()) rn FROM t)
SELECT 'L:' || coalesce(array_join(array_agg(IF(lv = 1, sid)), ','), '') || '#F:' || coalesce(array_join(array_agg(IF(lv = 0, sid)), ','), '')
       || '#R:' || cast(min(ts) AS varchar) || ',' || cast(max(ts) AS varchar) AS packed
FROM r WHERE rn <= {n}
