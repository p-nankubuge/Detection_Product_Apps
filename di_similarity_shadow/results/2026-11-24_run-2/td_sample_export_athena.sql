-- TD sample export (Athena / Trino, database_id 2). Step 1 of the TD scoring actually used.
-- Why: the Athena join to prod_session_summary times out (see td_scoring_athena.sql), and TD is not in Snowflake.
--   So a deterministic sample of labelled sessions was exported as compact keys and joined in Snowflake.
-- Sample: substr(arkose_session_id, 2, 1) = '0' (a uniform digit: 4,878 of 48,096 Oct labels, 10.1%), then the first
--   NTILE(5) chunk ordered by session ID = arkose_session_id <= '20718df145a254ea1.1894341001'.
--   => 976 labelled sessions (575 Legit, 401 Nonlegit verified, 0 Nonlegit unverified) = 2.0% of October labels.
--   The chunk spans the whole month (session_create_timestamp 2026-10-01 00:04 -> 2026-10-31 14:05), and its
--   Legit:Nonlegit mix (59:41) matches the full month (61:39).
-- Key: label letter (L = Legit, N = Nonlegit & is_verified = 1, X = Nonlegit unverified)
--      || substr(id, 10, 8) || substr(id, 19, 4)  (12 chars, ~45 bits; 976 / 976 matched exactly one session in Snowflake).
-- Only chunk 1 was transferred (each chunk is ~1k keys pasted into the Snowflake query); chunks 2-5 were NOT run.
WITH td AS (
  SELECT arkose_session_id AS id,
         max_by(is_legit, ingest_timestamp) AS lbl,
         max_by(is_verified, ingest_timestamp) AS ver
  FROM starfleet_production.truth_data_history
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND year = 2026 AND month IN (10, 11)
    AND session_create_timestamp >= TIMESTAMP '2026-10-01 00:00:00'
    AND session_create_timestamp <  TIMESTAMP '2026-11-01 00:00:00'
    AND substr(arkose_session_id, 2, 1) = '0'
  GROUP BY 1
),
k AS (
  SELECT CASE WHEN lbl = 'Legit' THEN 'L' WHEN ver = 1 THEN 'N' ELSE 'X' END
           || substr(id, 10, 8) || substr(id, 19, 4) AS kk,
         ntile(5) OVER (ORDER BY id) AS chunk
  FROM td
)
SELECT array_join(array_agg(kk ORDER BY kk), ',') AS s
FROM k
WHERE chunk = 1;

-- Chunk description query (used to check the chunk spans the month):
-- ... same td CTE plus session_create_timestamp, then
-- SELECT chunk, count(*), count_if(lbl='Legit'), count_if(lbl='Nonlegit' AND ver=1), min(sct), max(sct), min(id), max(id)
-- FROM k GROUP BY 1 ORDER BY 1;
