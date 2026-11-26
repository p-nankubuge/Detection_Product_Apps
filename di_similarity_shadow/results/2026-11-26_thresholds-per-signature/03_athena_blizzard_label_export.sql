-- NOTE: the full export (all days in one row each) exceeded the response cap (~73k tokens); only the chunk with mod 4 = 0 (758 labels, all ending in 04) was run, and used for the coverage check (08b_).
-- Athena (database_id 2). Export Blizzard ROW Registration K2 Nonlegit label session IDs (created 9-12 Nov 2026) compactly:
-- the 10-digit part after the '.' of arkose_session_id, one string per session-create day. Joined in Snowflake (04_/05_) on
-- RIGHT(session,10) + public_key + replay window (collisions checked there). The direct Athena join to prod_session_summary times out.
SELECT substr(cast(session_create_timestamp AS varchar),1,10) cday, count(*) n,
  array_join(array_agg(split_part(arkose_session_id,'.',2) ORDER BY arkose_session_id), ',') ids
FROM starfleet_production.truth_data_history
WHERE public_key='E8A75615-1CBA-5DFF-8032-D16BCF234E10' AND year=2026 AND month=11 AND day BETWEEN 9 AND 26
  AND is_legit='Nonlegit' AND is_verified=1
  AND session_create_timestamp >= timestamp '2026-11-09 00:00:00' AND session_create_timestamp < timestamp '2026-11-12 00:00:00'
GROUP BY 1 ORDER BY 1;
