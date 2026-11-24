-- vw_events cross-check + IP-intel breakdown (spec asks N11 hits by vpn_proxy_description), Snowflake (database_id 14).
-- Window: vw_events location='session_setup', timestamp 2026-10-15 00:00 -> 2026-10-16 00:00 (UTC). One day only:
--   a full month of vw_events was not attempted (would time out). NO sampling within the day.
-- Purpose: (1) confirm the session summary matches vw_events session_setup (116,428 vs 116,429 sessions);
--          (2) where C2/C3/N9-like hits sit by vpn_proxy_description / vpn_proxy_type.
-- Rule approximations here (simpler than _flags_cte.sql, for the breakdown only):
--   chromium_ua = Mozilla UA with Chrome/ and not Samsung/iOS (Brave/Opera/Edge included, Brave flag not used);
--   c3_like = chromium_ua + TCP JA4 TLS 1.2/1.1/1.0 + Chrome major >= 70 (so it is C3 widened to 1.1/1.0, = N11 Chromium part)
--   c2_like = chromium_ua + TCP + ALPN h1;  n9_like = Mozilla UA + ALPN 00 (all families incl. 'other').
WITH e AS (
  SELECT session, MIN(timestamp) AS ts,
         MIN_BY(cdn__ja4_hash, timestamp) AS ja4, MIN_BY(ua, timestamp) AS ua,
         MIN_BY(vpn_proxy_description, timestamp) AS vpd, MIN_BY(vpn_proxy_type, timestamp) AS vpt
  FROM ARK_PROD.events.vw_events
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND location = 'session_setup'
    AND timestamp >= '2026-10-15' AND timestamp < '2026-10-16'
  GROUP BY session
),
x AS (SELECT e.*, SPLIT_PART(ja4, '_', 1) AS a,
             TRY_TO_NUMBER(REGEXP_SUBSTR(ua, 'Chrome/([0-9]+)', 1, 1, 'e', 1)) AS chm FROM e),
y AS (
  SELECT x.*,
    (ua LIKE '%Chrome/%' AND ua NOT LIKE '%SamsungBrowser%' AND ua NOT LIKE '%iPhone%' AND ua NOT LIKE '%iPad%'
     AND ua LIKE 'Mozilla/%') AS chromium_ua,
    SUBSTR(a, 1, 1) = 't' AND SUBSTR(a, 2, 2) IN ('12', '11', '10') AS old_tls,
    SUBSTR(a, 9, 2) AS alpn
  FROM x
)
SELECT COALESCE(vpd, '(null)') AS vpd, COALESCE(vpt, '(null)') AS vpt, COUNT(*) AS sessions,
       COUNT_IF(chromium_ua AND old_tls AND chm >= 70) AS c3_like,
       COUNT_IF(chromium_ua AND SUBSTR(a, 1, 1) = 't' AND alpn = 'h1') AS c2_like,
       COUNT_IF(alpn = '00' AND ua LIKE 'Mozilla/%') AS n9_like,
       MIN(ts) AS mn, MAX(ts) AS mx
FROM y
GROUP BY 1, 2
ORDER BY c3_like + c2_like + n9_like DESC;
