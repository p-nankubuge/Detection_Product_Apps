-- Rule C2: Chromium UA (Chrome, Edge, Opera, Brave; not Samsung, not iOS) with TCP JA4 ALPN h1
-- Key: Figma - Registration - Production - Key 2 (A207F8A1-ED09-4325-ACE6-C8E26A458FBA), single-key mode.
-- Window: sessions created 2026-10-01 00:00 -> 2026-11-01 00:00 UTC. NO sampling. Snowflake (database_id 14).
-- Source: ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY (*_at_session_created = session_setup values), not
--   vw_events: a month of vw_events for this key would time out; the summary returned the full month in ~15 s.
--   Cross-check on 2026-10-15: vw_events session_setup = 116,428 sessions vs summary 116,429 (vw_events_crosscheck.sql).
-- Not a proxy key (proxy_key_check.sql), so JA4 rules apply. Synthetics key is excluded by the key filter.
-- Query 1: totals for the rule vs the key's own baseline (all sessions, Dict 63).
-- Query 2: top signatures hit.

WITH s AS (
  SELECT
    session,
    session_ts,
    cdn__ja4_hash_at_session_created AS ja4,
    SPLIT_PART(cdn__ja4_hash_at_session_created, '_', 1) AS part_a,
    ua_at_session_created AS ua,
    os_at_session_created AS os,
    os_version_at_session_created AS os_version,
    user_ip_at_session_created AS ip,
    di_dictionary_num_matched_at_session_created AS dict,
    latest_risk_band AS risk_band,
    sessions_verify_attempted,
    sessions_verified,
    latest_browser_detection_brave AS is_brave
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND session_last_timestamp >= '2026-10-01 00:00:00'
    AND session_last_timestamp <  '2026-11-01 06:00:00'
    AND session_ts >= '2026-10-01 00:00:00'
    AND session_ts <  '2026-11-01 00:00:00'
),
f AS (
  SELECT s.*,
    CASE
      WHEN ua IS NULL OR ua NOT LIKE 'Mozilla/%' THEN 'non_browser'
      WHEN ua LIKE '%iPhone%' OR ua LIKE '%iPad%' OR ua LIKE '%iPod%' THEN 'safari'
      WHEN ua LIKE '%SamsungBrowser/%' THEN 'samsung'
      WHEN ua LIKE '%Edg/%' OR ua LIKE '%EdgA/%' THEN 'edge'
      WHEN ua LIKE '%OPR/%' THEN 'opera'
      WHEN is_brave THEN 'brave'
      WHEN ua LIKE '%Firefox/%' THEN 'firefox'
      WHEN ua LIKE '%Chrome/%' THEN 'chrome'
      WHEN ua LIKE '%Safari/%' AND ua LIKE '%Version/%' THEN 'safari'
      ELSE 'other'
    END AS family,
    SUBSTR(part_a, 1, 1) AS transport,
    SUBSTR(part_a, 2, 2) AS tls_ver,
    TRY_TO_NUMBER(SUBSTR(part_a, 5, 2)) AS cipher_cnt,
    TRY_TO_NUMBER(SUBSTR(part_a, 7, 2)) AS ext_cnt,
    SUBSTR(part_a, 9, 2) AS alpn,
    TRY_TO_NUMBER(REGEXP_SUBSTR(ua, 'Chrome/([0-9]+)', 1, 1, 'e', 1)) AS chrome_major,
    TRY_TO_NUMBER(REGEXP_SUBSTR(ua, 'Firefox/([0-9]+)', 1, 1, 'e', 1)) AS firefox_major,
    TRY_TO_NUMBER(REGEXP_SUBSTR(ua, 'Version/([0-9]+)', 1, 1, 'e', 1)) AS safari_major,
    TRY_TO_NUMBER(REGEXP_SUBSTR(ua, ' OS ([0-9]+)_', 1, 1, 'e', 1)) AS ios_major
  FROM s
),
r AS (
  SELECT f.*,
    family IN ('chrome','edge','firefox','safari','opera','brave','samsung') AS is_browser,
    family IN ('chrome','edge','opera','brave') AS is_chromium,
    CASE
      WHEN family IN ('chrome','edge','opera','brave','samsung') THEN chrome_major >= 70
      WHEN family = 'firefox' THEN firefox_major >= 63
      WHEN family = 'safari'  THEN COALESCE(safari_major >= 13, ios_major >= 13, FALSE)
      ELSE FALSE
    END AS is_modern,
    COALESCE(CASE family
      WHEN 'chrome'  THEN cipher_cnt IN (10,12,13,14,15,16,17,18,19,20,26,27,28,29,30,31,34,69)
      WHEN 'edge'    THEN cipher_cnt IN (8,10,12,13,14,15,16,19,20,24,26,27,29,30,31,33,34,37,40,41,57,68,69,75,87)
      WHEN 'firefox' THEN cipher_cnt IN (15,16,17,18,26,27,28,30,31,52)
      WHEN 'safari'  THEN cipher_cnt IN (13,15,17,18,20,21,26)
      WHEN 'opera'   THEN cipher_cnt IN (15)
      WHEN 'brave'   THEN cipher_cnt IN (15)
      WHEN 'samsung' THEN cipher_cnt IN (15)
    END, FALSE) AS cipher_in_range,
    COALESCE(CASE family
      WHEN 'chrome'  THEN ext_cnt IN (9,10,11,12,13,14,15,16,17,18)
      WHEN 'edge'    THEN ext_cnt IN (7,9,10,11,12,13,14,16,17)
      WHEN 'firefox' THEN ext_cnt IN (9,10,11,12,13,14,15,16,17)
      WHEN 'safari'  THEN ext_cnt IN (7,13,14,15,16,17)
      WHEN 'opera'   THEN ext_cnt IN (16,17,18)
      WHEN 'brave'   THEN ext_cnt IN (10,12,16)
      WHEN 'samsung' THEN ext_cnt IN (16,17)
    END, FALSE) AS ext_in_range
  FROM f
),
flags AS (
  SELECT r.*,
    sessions_verify_attempted > 0 AS verify_attempted,
    sessions_verified > 0 AS verified,
    risk_band = 'High' AS high_risk,
    COALESCE(ja4 IS NOT NULL AND is_chromium AND transport = 't' AND alpn = 'h1', FALSE)                          AS c2,
    COALESCE(ja4 IS NOT NULL AND is_chromium AND chrome_major >= 70 AND transport = 't' AND tls_ver = '12', FALSE) AS c3,
    COALESCE(ja4 IS NOT NULL AND is_browser AND alpn = '00', FALSE)                                               AS n9,
    COALESCE(ja4 IS NOT NULL AND is_browser AND transport = 't' AND NOT (cipher_in_range AND ext_in_range), FALSE) AS n10,
    COALESCE(ja4 IS NOT NULL AND is_modern AND transport = 't' AND tls_ver <> '13', FALSE)                        AS n11
  FROM r
)

, sel AS (
  SELECT 'ALL' AS grp, * FROM flags
  UNION ALL SELECT 'DICT63', * FROM flags WHERE dict = 63
  UNION ALL SELECT 'C2', * FROM flags WHERE c2
)
SELECT grp,
  COUNT(*) AS sessions,
  COUNT_IF(high_risk) AS high_risk_n,
  CAST(COUNT_IF(high_risk) / COUNT(*) AS FLOAT) AS high_risk_pct,
  COUNT_IF(verify_attempted) AS verify_attempted_n,
  COUNT_IF(verified) AS verified_n,
  CAST(COUNT_IF(verified) / NULLIF(COUNT_IF(verify_attempted), 0) AS FLOAT) AS verified_of_attempted,
  COUNT_IF(NOT verify_attempted) AS unverified_hits,
  COUNT(DISTINCT ip) AS distinct_ips, COUNT(DISTINCT ja4) AS distinct_ja4, COUNT(DISTINCT ua) AS distinct_ua,
  COUNT_IF(dict = 63) AS at_dict63, COUNT_IF(dict <= 3) AS at_dict_le3
FROM sel GROUP BY grp ORDER BY grp;

-- Query 2 (top signatures): same CTEs, then
-- SELECT family, ja4, MODE(os) AS top_os, COUNT(*) AS n, COUNT_IF(high_risk) AS hr, COUNT_IF(verified) AS v,
--        COUNT_IF(NOT verify_attempted) AS nva, COUNT(DISTINCT ip) AS ips, COUNT_IF(dict = 63) AS d63
-- FROM flags WHERE c2 GROUP BY 1, 2 ORDER BY n DESC LIMIT 8;
