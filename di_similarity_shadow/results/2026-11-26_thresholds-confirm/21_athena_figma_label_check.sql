-- Athena (database_id 2). Figma Registration K2 labels for sessions created 6 Nov 2026 (ingest partitions 6-26 Nov):
-- counts by label and verified flag, distinct sessions, ID suffix length / tail code, ingest range, conflicting labels.
SELECT is_legit, is_verified, count(*) n_rows, count(DISTINCT arkose_session_id) n_sess,
  min(length(split_part(arkose_session_id,'.',2))) min_len, max(length(split_part(arkose_session_id,'.',2))) max_len,
  array_join(array_sort(array_distinct(array_agg(substr(split_part(arkose_session_id,'.',2),9,2)))), ',') tails,
  min(ingest_timestamp) first_ingest, max(ingest_timestamp) last_ingest
FROM starfleet_production.truth_data_history
WHERE public_key='A207F8A1-ED09-4325-ACE6-C8E26A458FBA' AND year=2026 AND month=11 AND day BETWEEN 6 AND 26
  AND session_create_timestamp >= timestamp '2026-11-06 00:00:00' AND session_create_timestamp < timestamp '2026-11-07 00:00:00'
GROUP BY 1,2 ORDER BY 1,2
