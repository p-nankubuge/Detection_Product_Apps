-- Browser Reputation Engine (BRE) — global classification query
-- Source design doc: Confluence FP / "Browser Reputation Engine (BRE) - Design Document" (§5)
--
-- CORRECTIONS vs the design doc, discovered when running this on 2026-09-18:
--   1. Table. The doc says `starfleet_production.prod_session_summary`. The real object is
--      ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY (Snowflake, 38.7B rows).
--   2. Dialect. The doc's §5 snippet is ClickHouse-flavoured. On Snowflake use
--      DATEADD(day, -14, SYSDATE()) rather than `now() - INTERVAL 14 DAY`.
--      SESSION_TS is TIMESTAMP_NTZ in UTC, so SYSDATE() (not CURRENT_TIMESTAMP) is the
--      correct comparand.
--   3. Superset connection. Use the "Snowflake DATA" connection (database_id 17,
--      PROD_ARKOSE_SUPERSET_TIER1_WH). The plain "Snowflake" connection (id 14,
--      ..._DEFAULT_WH) is ~3.3x slower and cannot finish a 14-day pass inside the
--      MCP/SQL Lab call budget.
--   4. Empty user-agent. BROWSER_NAME_AT_SESSION_CREATED is '' (not NULL) for the
--      "(empty UA)" cohort, so it must be folded explicitly, as below.
--
-- PERFORMANCE NOTE: a 14-day window is ~1.28B sessions. The MCP/SQL Lab client caps a
-- call at 60s, so the query is split into three passes rather than one. Pass 1 is a cheap
-- full-population scan; passes 2 and 3 carry the expensive COUNT(DISTINCT)s but are
-- filtered to a candidate list, which is what keeps them inside the budget. Do not try to
-- merge them back into a single statement.

-------------------------------------------------------------------------------
-- PASS 1 — volume + verification rate for the whole population (~20s)
-- Evaluates Condition A (verification_rate < 1%) for every browser.
-------------------------------------------------------------------------------
SELECT
  COALESCE(NULLIF(TRIM(BROWSER_NAME_AT_SESSION_CREATED), ''), '(empty UA)') AS browser_name,
  COUNT(*)                AS total_sessions,
  SUM(SESSIONS_VERIFIED)  AS verified_sessions,
  ROUND(SUM(SESSIONS_VERIFIED) / NULLIF(COUNT(*), 0) * 100, 3) AS vr_pct
FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
WHERE SESSION_TS >= DATEADD(day, -14, SYSDATE())
  AND SESSION_TS <  SYSDATE()
GROUP BY 1
HAVING COUNT(*) >= 1000          -- 195 of 1,382 browser names clear this floor
ORDER BY total_sessions DESC;

-------------------------------------------------------------------------------
-- PASS 2 — diversity metrics (~45s)
-- Evaluates the ip_diversity and country_count halves of Condition B.
-- The NOT IN list drops the ten highest-volume mainstream browsers; without it the
-- COUNT(DISTINCT user_ip) over ~1.19B extra sessions blows the call budget. Those ten
-- are never classification candidates, but re-add any of them (one at a time) if you
-- need a baseline reading.
-------------------------------------------------------------------------------
WITH base AS (
  SELECT
    COALESCE(NULLIF(TRIM(BROWSER_NAME_AT_SESSION_CREATED), ''), '(empty UA)') AS browser_name,
    COUNT(*)                                          AS total_sessions,
    SUM(SESSIONS_VERIFIED)                            AS verified_sessions,
    COUNT(DISTINCT PUBLIC_KEY)                        AS key_count,
    COUNT(DISTINCT USER_IP_AT_SESSION_CREATED)        AS ip_count,
    COUNT(DISTINCT LATEST_ASN)                        AS asn_count,
    COUNT(DISTINCT COUNTRY_AT_SESSION_CREATED)        AS country_count
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE SESSION_TS >= DATEADD(day, -14, SYSDATE())
    AND SESSION_TS <  SYSDATE()
    AND COALESCE(NULLIF(TRIM(BROWSER_NAME_AT_SESSION_CREATED), ''), '(empty UA)') NOT IN (
      'Chrome', 'Mobile Safari', 'Chrome Webview', 'Microsoft Edge', 'Chrome Mobile',
      'Roblox', 'Safari', 'Firefox', 'Chrome Mobile iOS', 'Opera'
    )
  GROUP BY 1
)
SELECT
  browser_name,
  total_sessions,
  verified_sessions,
  ROUND(verified_sessions / NULLIF(total_sessions, 0) * 100, 3) AS vr_pct,
  key_count,
  ip_count,
  ROUND(ip_count / NULLIF(total_sessions, 0), 6) AS ip_diversity,
  asn_count,
  country_count,
  CASE WHEN verified_sessions / NULLIF(total_sessions, 0) < 0.01 THEN 'A' ELSE '' END AS cond_a,
  CASE WHEN ip_count / NULLIF(total_sessions, 0) < 0.001
        AND country_count < 20 THEN 'B-partial' ELSE '' END AS cond_b_partial
FROM base
WHERE (
        total_sessions >= 1000
        AND (
          verified_sessions / NULLIF(total_sessions, 0) < 0.01
          OR (ip_count / NULLIF(total_sessions, 0) < 0.001 AND country_count < 20)
        )
      )
   -- always report current list members + pending candidates, even below the floor,
   -- so that a collapse in volume is visible rather than silently dropping out
   OR browser_name IN (
        'Go-http-client', 'Cypress', 'Resty', 'Headless Chrome', '(empty UA)',
        'Nokia Browser', 'Python Requests', 'Unirest for Java', 'CaptchaBotRS',
        'Opera Mobile', 'Nintendo Browser', 'undici'
      )
ORDER BY total_sessions DESC;

-------------------------------------------------------------------------------
-- PASS 3 — ja4_concentration_ratio (~25s)
-- This closes the open TODO in the design doc §2.3/§5, which left the ratio
-- "to be computed". Do NOT infer it from the distinct JA4 count: the doc assumed a
-- single-digit hash count implies a ratio "well above 0.8", and measurement showed
-- that is false for Cypress (0.691), Resty (0.696) and Unirest for Java (0.743).
-- Replace the IN list with the candidates surfaced by passes 1-2.
-------------------------------------------------------------------------------
WITH j AS (
  SELECT
    COALESCE(NULLIF(TRIM(BROWSER_NAME_AT_SESSION_CREATED), ''), '(empty UA)') AS browser_name,
    CDN__JA4_HASH_AT_SESSION_CREATED AS ja4,
    COUNT(*) AS c
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE SESSION_TS >= DATEADD(day, -14, SYSDATE())
    AND SESSION_TS <  SYSDATE()
    AND COALESCE(NULLIF(TRIM(BROWSER_NAME_AT_SESSION_CREATED), ''), '(empty UA)') IN (
      'Go-http-client', 'Cypress', 'Resty', 'Unirest for Java', 'Nokia Browser',
      'Headless Chrome', '(empty UA)', 'Opera Mobile', 'Nintendo Browser',
      'CaptchaBotRS', 'Python Requests', 'undici'
    )
    AND CDN__JA4_HASH_AT_SESSION_CREATED IS NOT NULL
    AND CDN__JA4_HASH_AT_SESSION_CREATED <> ''
  GROUP BY 1, 2
)
SELECT
  browser_name,
  SUM(c)  AS sessions_with_ja4,
  COUNT(*) AS ja4_hash_count,
  MAX(c)  AS top_ja4_sessions,
  ROUND(MAX(c) / NULLIF(SUM(c), 0), 4) AS ja4_concentration_ratio
FROM j
GROUP BY 1
ORDER BY sessions_with_ja4 DESC;

-------------------------------------------------------------------------------
-- PASS 4 (optional) — investigation context per design doc §3.4 / §6.3 / §6.4
-- WebGL homogeneity, ISP spread, hosting/proxy share, connection type mix, satellite.
-- Not classification criteria; used to build the evidence case for a flagged browser.
-------------------------------------------------------------------------------
SELECT
  COALESCE(NULLIF(TRIM(BROWSER_NAME_AT_SESSION_CREATED), ''), '(empty UA)') AS browser_name,
  COUNT(*) AS total_sessions,
  COUNT(DISTINCT WEBGL_HASH_WEBGL_AT_SESSION_CREATED) AS webgl_hash_count,
  COUNT(DISTINCT LATEST_ISP) AS isp_count,
  ROUND(SUM(CASE WHEN LATEST_IS_HOSTING_PROVIDER THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS hosting_pct,
  ROUND(SUM(CASE WHEN LATEST_IS_PROXY           THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS proxy_pct,
  ROUND(SUM(CASE WHEN LATEST_IS_VPN             THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS vpn_pct,
  ROUND(SUM(CASE WHEN LATEST_CONNECTION_TYPE = 'wired'  THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS wired_pct,
  ROUND(SUM(CASE WHEN LATEST_CONNECTION_TYPE = 'wifi'   THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS wifi_pct,
  ROUND(SUM(CASE WHEN LATEST_CONNECTION_TYPE = 'mobile' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS mobile_pct,
  SUM(CASE WHEN LATEST_CONNECTION_TYPE = 'nat'       THEN 1 ELSE 0 END) AS nat_sessions,
  SUM(CASE WHEN LATEST_CONNECTION_TYPE = 'satellite' THEN 1 ELSE 0 END) AS satellite_sessions
FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
WHERE SESSION_TS >= DATEADD(day, -14, SYSDATE())
  AND SESSION_TS <  SYSDATE()
  AND COALESCE(NULLIF(TRIM(BROWSER_NAME_AT_SESSION_CREATED), ''), '(empty UA)') IN (
    'Go-http-client', 'Cypress', 'Resty', 'Unirest for Java', 'Nokia Browser',
    'Headless Chrome', '(empty UA)', 'Opera Mobile', 'Nintendo Browser',
    'CaptchaBotRS', 'Python Requests', 'undici'
  )
GROUP BY 1
ORDER BY total_sessions DESC;
