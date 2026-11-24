-- Proxy-key check, Figma Registration K2 (A207F8A1-ED09-4325-ACE6-C8E26A458FBA), Snowflake (database_id 14).
-- Rule: proxy key if one JA4 is on >= 98% of the key's sessions over 24h.
-- Window: sessions created 2026-10-15 00:00 -> 2026-10-16 00:00 UTC. NO sampling.
-- Result: 116,429 sessions, 652 distinct JA4s, top JA4 q13d0312h3_55b375c5d22e_178839b6cec1 = 40.9%
--         -> NOT a proxy key; List C and N8-N11 apply.
SELECT cdn__ja4_hash_at_session_created AS ja4,
       COUNT(*) AS n,
       COUNT(*) / SUM(COUNT(*)) OVER () AS share,
       SUM(COUNT(*)) OVER () AS total,
       COUNT(DISTINCT cdn__ja4_hash_at_session_created) OVER () AS distinct_ja4
FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
  AND session_last_timestamp >= '2026-10-15' AND session_last_timestamp < '2026-10-16 06:00:00'
  AND session_ts >= '2026-10-15' AND session_ts < '2026-10-16'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;
