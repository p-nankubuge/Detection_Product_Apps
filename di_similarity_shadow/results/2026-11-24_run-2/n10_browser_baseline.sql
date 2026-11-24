-- N10 browser baseline: cipher-count and extension-count ranges per browser family
-- ASSUMPTION: Dict 63 sessions are treated as real devices. Not yet proven (checked by another agent).
-- Source: ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY (Snowflake, database_id 14), *_at_session_created
--         fields (= values at session_setup). One row per session. NO sampling.
-- Window: sessions created 2026-10-15 00:00 to 2026-10-16 00:00 UTC (24h), ALL keys.
-- Exclusions: synthetics key; known Payoneer proxy keys; any key where one JA4 is >= 98% of
--             its sessions that day (>= 200 sessions); QUIC JA4s (q...); List A, List B, List C (C1-C3).
-- Range rule: per family, values sorted by sessions desc, kept until cumulative >= 99.9%.
--             Values with < 50 sessions are listed separately (in_range_999 shown, flag low_n).

WITH base AS (
  SELECT
    public_key,
    session,
    cdn__ja4_hash_at_session_created AS ja4,
    SPLIT_PART(cdn__ja4_hash_at_session_created, '_', 1) AS part_a,
    ua_at_session_created AS ua,
    os_at_session_created AS os,
    webgl_unmasked_renderer_at_session_created AS renderer,
    latest_browser_detection_brave AS is_brave
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE session_last_timestamp >= '2026-10-15 00:00:00'
    AND session_last_timestamp <  '2026-10-16 06:00:00'
    AND session_ts >= '2026-10-15 00:00:00'
    AND session_ts <  '2026-10-16 00:00:00'
    AND di_dictionary_num_matched_at_session_created = 63
    AND public_key NOT IN ('2EAD3543-36DC-4A77-90E1-F3AE6B16CF16',   -- synthetics
                           'EE844FC3-499D-4A4D-A643-D7400F0FD4DE',   -- Payoneer proxy keys
                           'E3EFEFBF-8DE4-42ED-9E7F-92F35B1FD3CF',
                           '7CC24C4A-611B-41C7-9808-B95722C7861C')
    AND cdn__ja4_hash_at_session_created IS NOT NULL
),
key_top AS (           -- proxy-key detection on the same day (all dicts would be better; dict 63 used as proxy)
  SELECT public_key, MAX(n) / SUM(n) AS top_share, SUM(n) AS tot
  FROM (SELECT public_key, ja4, COUNT(*) AS n FROM base GROUP BY 1, 2)
  GROUP BY 1
),
fam AS (
  SELECT b.*,
    CASE
      WHEN ua IS NULL OR ua NOT LIKE 'Mozilla/%' THEN 'non_browser'
      WHEN ua LIKE '%iPhone%' OR ua LIKE '%iPad%' OR ua LIKE '%iPod%' THEN 'safari'  -- every iOS browser uses WebKit TLS
      WHEN ua LIKE '%SamsungBrowser/%' THEN 'samsung'
      WHEN ua LIKE '%Edg/%' OR ua LIKE '%EdgA/%' THEN 'edge'
      WHEN ua LIKE '%OPR/%' THEN 'opera'
      WHEN is_brave THEN 'brave'
      WHEN ua LIKE '%Firefox/%' THEN 'firefox'
      WHEN ua LIKE '%Chrome/%' THEN 'chrome'
      WHEN ua LIKE '%Safari/%' AND ua LIKE '%Version/%' THEN 'safari'
      ELSE 'other'
    END AS family,
    TRY_TO_NUMBER(SUBSTR(part_a, 5, 2)) AS cipher_cnt,
    TRY_TO_NUMBER(SUBSTR(part_a, 7, 2)) AS ext_cnt,
    TRY_TO_NUMBER(REGEXP_SUBSTR(ua, 'Chrome/([0-9]+)', 1, 1, 'e', 1)) AS chrome_major
  FROM base b
  JOIN key_top k ON k.public_key = b.public_key
  WHERE NOT (k.top_share >= 0.98 AND k.tot >= 200)
    AND part_a LIKE 't%'
),
clean AS (
  SELECT * FROM fam
  WHERE family <> 'non_browser'
    -- List A
    AND NOT COALESCE(renderer ILIKE '%SwiftShader%' OR renderer ILIKE '%llvmpipe%'
                     OR renderer ILIKE '%VirtualBox%' OR renderer ILIKE '%VMware SVGA%', FALSE)
    -- List B
    AND NOT COALESCE(os <> 'Windows' AND renderer ILIKE '%Microsoft Basic Render%', FALSE)
    AND NOT COALESCE((os IS NULL OR os = '--') AND renderer IS NOT NULL AND renderer <> '', FALSE)
    -- List C
    AND NOT COALESCE(SPLIT_PART(ja4, '_', 2) IN ('a09f3c656075', '2802a3db6c62')
                     AND os IN ('Windows', 'GNU/Linux', 'Ubuntu', 'Chrome OS', 'Linux'), FALSE)       -- C1
    AND NOT COALESCE(ua LIKE '%Chrome/%' AND SUBSTR(part_a, 9, 2) = 'h1', FALSE)                     -- C2
    AND NOT COALESCE(ua LIKE '%Chrome/%' AND chrome_major >= 70 AND SUBSTR(part_a, 2, 2) = '12', FALSE) -- C3
),
dist AS (
  SELECT family, 'cipher' AS dim, cipher_cnt AS val, COUNT(*) AS n, COUNT(DISTINCT public_key) AS keys
  FROM clean GROUP BY 1, 2, 3
  UNION ALL
  SELECT family, 'ext' AS dim, ext_cnt AS val, COUNT(*) AS n, COUNT(DISTINCT public_key) AS keys
  FROM clean GROUP BY 1, 2, 3
),
cum AS (
  SELECT d.*,
    SUM(n) OVER (PARTITION BY family, dim) AS fam_total,
    SUM(n) OVER (PARTITION BY family, dim ORDER BY n DESC, val
                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_n
  FROM dist d
)
SELECT family, dim, val, n, keys, fam_total,
       CAST(n / fam_total AS FLOAT) AS share,
       -- in range if the cumulative share BEFORE this value was still < 99.9%
       (cum_n - n) / fam_total < 0.999 AS in_range_999,
       n < 50 AS low_n
FROM cum
ORDER BY family, dim, n DESC;

-- Compact form used in the run (same CTEs, final SELECT replaced by):
-- SELECT family, dim, MAX(fam_total) AS fam_total,
--        LISTAGG(IFF((cum_n - n) / fam_total < 0.999, val || ':' || n, NULL), ' ') WITHIN GROUP (ORDER BY n DESC) AS in_range,
--        LISTAGG(IFF((cum_n - n) / fam_total >= 0.999, val || ':' || n, NULL), ' ') WITHIN GROUP (ORDER BY n DESC) AS outside
-- FROM cum GROUP BY 1, 2 ORDER BY 1, 2;
