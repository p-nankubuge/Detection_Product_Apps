-- Score tracked combinations against TRUTH labels (Athena, Superset database_id 2 -- NOT Snowflake 14).
-- Table: starfleet_production.truth_data_history (one row per labelled session: is_legit_value 1 = legit, 0 = fraud;
-- source Stream/Upload; fraud_category; suspicion_flags + telltale_list as they were on the session; partitions year/month/day).
-- Coverage is partial: most keys have only fraud labels (customer uploads / streams of confirmed abuse) -> hits there measure
-- RECALL; a few keys have legit labels (e.g. Uber SMS has ~73k legit-only labels) -> hits there are KNOWN false positives.
-- Window: 30 days before --win-start to now (render.py fills truth_from_*). Churned keys are excluded below.
-- Output rows: combo id, key, key's legit/fraud label counts, legit labels the combo hits, fraud labels it hits.
-- Render: python3 render.py sql/10_truth_check.sql --win-start <D-4> [--combos combos.json]
WITH c(id, fl) AS (VALUES
  {combo_values}),
t AS (SELECT is_legit_value lv, public_key k, concat(coalesce(suspicion_flags, ARRAY[]), coalesce(telltale_list, ARRAY[])) f
      FROM starfleet_production.truth_data_history
      WHERE date(from_iso8601_timestamp(format('%04d-%02d-%02dT00:00:00Z', year, month, day))) >= date '{truth_from}'
        AND year >= {truth_from_y}
        AND public_key NOT IN ('A2A14B1D-1AF3-C791-9BBC-EE33CC7A0A6F')),
kt AS (SELECT k, sum(IF(lv = 1, 1, 0)) kl, sum(IF(lv = 0, 1, 0)) kf FROM t GROUP BY k)
SELECT c.id, t.k, kt.kl AS key_legit, kt.kf AS key_fraud, sum(IF(t.lv = 1, 1, 0)) AS legit_hit, sum(IF(t.lv = 0, 1, 0)) AS fraud_hit
FROM t CROSS JOIN c JOIN kt ON kt.k = t.k
WHERE cardinality(array_except(c.fl, t.f)) = 0
GROUP BY 1, 2, 3, 4 HAVING count(*) >= 20
ORDER BY 1, 6 DESC
