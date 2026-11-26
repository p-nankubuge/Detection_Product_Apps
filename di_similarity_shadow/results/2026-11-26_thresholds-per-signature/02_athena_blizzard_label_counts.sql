-- Athena (database_id 2). Blizzard ROW Registration K2 labels for sessions created in the replay window 9-12 Nov 2026,
-- ingest partitions year=2026, month=11, day 9-26 (bigint partitions). Counts per session-create day.
SELECT substr(cast(session_create_timestamp AS varchar),1,10) cday, is_legit, is_verified,
  count(*) n_rows, count(DISTINCT arkose_session_id) n_sess, min(ingest_timestamp) first_ingest, max(ingest_timestamp) last_ingest
FROM starfleet_production.truth_data_history
WHERE public_key='E8A75615-1CBA-5DFF-8032-D16BCF234E10' AND year=2026 AND month=11 AND day BETWEEN 9 AND 26
  AND session_create_timestamp >= timestamp '2026-11-09 00:00:00' AND session_create_timestamp < timestamp '2026-11-12 00:00:00'
GROUP BY 1,2,3 ORDER BY 1,2,3;
