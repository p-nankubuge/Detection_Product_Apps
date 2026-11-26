-- Q0 (Athena, database_id 2): truth-data labels for Figma Registration K2 sessions created 2026-11-06 (UTC), label partitions 6-26 Nov.
-- One label per session (latest ingest wins; no session had conflicting labels). Exported as one row per 2-hour chunk of
-- session_create_timestamp (string of session ID + L/N), in 4 runs (chunks 0-2, 3-5, 6-8, 9-11) because of the response cap.
-- Saved as labels_2026-11-06.csv (session,label,chunk2h) by _scripts/extract_labels.py.
WITH t AS (
  SELECT arkose_session_id s, MAX_BY(is_legit_value, ingest_timestamp) lv, MIN(session_create_timestamp) ct
  FROM starfleet_production.truth_data_history
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA' AND year = 2026 AND month = 11 AND day BETWEEN 6 AND 26
    AND session_create_timestamp >= TIMESTAMP '2026-11-06 00:00:00' AND session_create_timestamp < TIMESTAMP '2026-11-07 00:00:00'
  GROUP BY 1)
SELECT hour(ct)/2 AS c, COUNT(*) n, array_join(array_agg(s || IF(lv=1,'L','N') ORDER BY s), ',') AS ids
FROM t WHERE hour(ct)/2 BETWEEN 0 AND 2   -- then 3-5, 6-8, 9-11
GROUP BY 1 ORDER BY 1;
-- Profile run first (same filters): 1,427 distinct sessions = 807 Legit + 620 Nonlegit, all is_verified = 1; 5 sessions labelled twice
-- with the same label; 0 conflicts. Label ingest days 6-25 Nov.
