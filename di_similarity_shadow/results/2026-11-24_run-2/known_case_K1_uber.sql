-- Known case K1 (Uber SMS Key 1, 30000F36-CADF-490C-929A-C6A7DD8B33C4): replay of the same rule logic,
-- one day inside the case window (sessions created 2026-10-28 00:00 -> 2026-10-29 00:00 UTC). NO sampling.
-- (Single-key run on Figma; K1 is on another key and used only to confirm the rule logic catches what it should.)
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
  WHERE public_key = '30000F36-CADF-490C-929A-C6A7DD8B33C4'
    AND session_last_timestamp >= '2026-10-28 00:00:00'
    AND session_last_timestamp <  '2026-10-29 06:00:00'
    AND session_ts >= '2026-10-28 00:00:00'
    AND session_ts <  '2026-10-29 00:00:00'
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

SELECT IFF(ja4 IN ('t13d2613h2_2802a3db6c62_845d286b0d67','t13d2014h2_a09f3c656075_14788d8d241b',
                   't13d1516h1_8daaf6152771_e5627efa2ab1','t12d1209h2_d34a8e72043a_e08eabe7240f'), ja4, 'other') AS sig,
  COUNT(*) AS n, COUNT_IF(c2) AS c2, COUNT_IF(c3) AS c3, COUNT_IF(n9) AS n9, COUNT_IF(n10) AS n10, COUNT_IF(n11) AS n11
FROM flags GROUP BY 1 ORDER BY 2 DESC;
