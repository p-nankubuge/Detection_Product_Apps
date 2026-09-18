-- Browser Reputation Engine (BRE) — global classification / discovery run
-- Source design doc: Confluence FP / "Browser Reputation Engine (BRE) - Design Document" (§2.1, §5)
--
-- PURPOSE: sweep the whole browser population and return whichever browsers the criteria
-- surface. This is a discovery query. Do NOT add a watchlist of previously-listed browser
-- names to the filters — that biases the run toward the last run's answer and hides new
-- entrants. (Pass 2 below returns only condition hits; if you want continuity reporting on
-- specific names, run pass 5 separately and keep it out of the discovery path.)
--
-- Criteria, verbatim from §2.1:
--   Condition A: verification_rate < 1%
--   Condition B: ip_diversity < 0.001 AND country_count < 20 AND ja4_concentration_ratio > 0.8
--
-- CORRECTIONS vs the design doc, found when running this on 2026-09-18:
--   1. Table. The doc says `starfleet_production.prod_session_summary`. The real object is
--      ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY (Snowflake, 38.7B rows).
--   2. Dialect. §5 is ClickHouse-flavoured. On Snowflake use DATEADD(day, -14, SYSDATE()).
--      SESSION_TS is TIMESTAMP_NTZ in UTC, so SYSDATE() is the correct comparand, not
--      CURRENT_TIMESTAMP().
--   3. Connection. Use "Snowflake DATA" (database_id 17, PROD_ARKOSE_SUPERSET_TIER1_WH).
--      The plain "Snowflake" connection (id 14, ..._DEFAULT_WH) is ~3.3x slower and cannot
--      finish a 14-day pass inside the client call budget.
--   4. Empty user-agent. BROWSER_NAME_AT_SESSION_CREATED is '' (not NULL) for the
--      "(empty UA)" cohort, so it must be folded explicitly.
--
-- PERFORMANCE: 14 days is ~1.28B sessions and the MCP/SQL Lab client caps a call at 60s.
-- The sweep is therefore split by volume band rather than by browser name, so that coverage
-- stays complete:
--   * Pass 1  — cheap full-population scan: volume + verification rate (Condition A for all).
--   * Pass 2  — full population MINUS the ~10 mega browsers, exact distincts (Condition B
--               clauses 1-2). The exclusion is a cost measure only; pass 3 clears those 10.
--   * Pass 3  — the mega browsers, country_count only. Condition B needs country_count < 20,
--               so a 236-244 country reading disproves B without costing a per-IP distinct.
--   * Pass 4  — ja4_concentration_ratio (Condition B clause 3) for whatever passes 1-3 return.
--   * Pass 5  — investigation context (§3.4 / §6.3 / §6.4) for the flagged set.
-- Do not try to merge these into one statement.
--
-- SWEEP FLOOR: 50 sessions / 14 days, matching the doc's Tier-2 floor (§3.2). This matters:
-- in the 2026-09-18 run, 3 of 7 flagged browsers sat below 1,000 sessions and would have been
-- invisible at a 1,000 floor.

-------------------------------------------------------------------------------
-- PASS 1 — volume + verification rate, whole population (~20s)
-- Condition A for every browser. Also splits attempt rate from pass-rate-given-attempt:
-- verification_rate alone conflates "attempts and fails" (Go-http-client: 99.97% attempt,
-- 0.0% pass) with "never attempts" (KorbytPlayer: 0 attempts), which are different findings.
-------------------------------------------------------------------------------
SELECT
  COALESCE(NULLIF(TRIM(BROWSER_NAME_AT_SESSION_CREATED), ''), '(empty UA)') AS browser_name,
  COUNT(*)                        AS total_sessions,
  SUM(SESSIONS_VERIFIED)          AS verified_sessions,
  SUM(SESSIONS_VERIFY_ATTEMPTED)  AS verify_attempted,
  ROUND(SUM(SESSIONS_VERIFIED)         / NULLIF(COUNT(*), 0) * 100, 4)                      AS vr_pct,
  ROUND(SUM(SESSIONS_VERIFY_ATTEMPTED) / NULLIF(COUNT(*), 0) * 100, 2)                      AS attempt_rate_pct,
  ROUND(SUM(SESSIONS_VERIFIED) / NULLIF(SUM(SESSIONS_VERIFY_ATTEMPTED), 0) * 100, 2)        AS pass_rate_given_attempt_pct
FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
WHERE SESSION_TS >= DATEADD(day, -14, SYSDATE())
  AND SESSION_TS <  SYSDATE()
GROUP BY 1
HAVING COUNT(*) >= 50
ORDER BY total_sessions DESC;

-------------------------------------------------------------------------------
-- PASS 2 — Condition A + Condition B clauses 1-2, full population minus mega browsers (~26s)
-- Returns condition hits only. No browser-name watchlist: the output is the discovery result.
-- The NOT IN list is purely a cost measure (COUNT(DISTINCT user_ip) over Chrome-scale groups
-- blows the call budget); pass 3 rules those browsers out on the country clause instead.
-- Re-derive the NOT IN list from pass 1 each run rather than assuming it is stable.
-------------------------------------------------------------------------------
WITH base AS (
  SELECT
    COALESCE(NULLIF(TRIM(BROWSER_NAME_AT_SESSION_CREATED), ''), '(empty UA)') AS browser_name,
    COUNT(*)                                          AS total_sessions,
    SUM(SESSIONS_VERIFIED)                            AS verified_sessions,
    COUNT(DISTINCT USER_IP_AT_SESSION_CREATED)        AS ip_count,
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
  ROUND(verified_sessions / NULLIF(total_sessions, 0) * 100, 4) AS vr_pct,
  ip_count,
  ROUND(ip_count / NULLIF(total_sessions, 0), 6) AS ip_diversity,
  country_count,
  CASE WHEN verified_sessions / NULLIF(total_sessions, 0) < 0.01 THEN 'A' ELSE '' END AS cond_a,
  CASE WHEN ip_count / NULLIF(total_sessions, 0) < 0.001
        AND country_count < 20 THEN 'B12' ELSE '' END AS cond_b_clauses12
FROM base
WHERE total_sessions >= 50
  AND (
    verified_sessions / NULLIF(total_sessions, 0) < 0.01
    OR (ip_count / NULLIF(total_sessions, 0) < 0.001 AND country_count < 20)
  )
ORDER BY total_sessions DESC;

-------------------------------------------------------------------------------
-- PASS 3 — coverage close-out for the mega browsers excluded from pass 2 (~45s)
-- Condition B requires country_count < 20. Any browser reading 200+ countries is excluded
-- from B without needing its per-IP distinct. Combined with pass 1's verification rates
-- (all well above 1%), this completes coverage of the population.
-- Note the >= 10,000,000 predicate is applied in the OUTER query; a browser-name IN filter
-- over 1.28B rows is slower than the full GROUP BY.
-------------------------------------------------------------------------------
WITH base AS (
  SELECT
    COALESCE(NULLIF(TRIM(BROWSER_NAME_AT_SESSION_CREATED), ''), '(empty UA)') AS browser_name,
    COUNT(*) AS total_sessions,
    SUM(SESSIONS_VERIFIED) AS verified_sessions,
    COUNT(DISTINCT COUNTRY_AT_SESSION_CREATED) AS country_count
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE SESSION_TS >= DATEADD(day, -14, SYSDATE())
    AND SESSION_TS <  SYSDATE()
  GROUP BY 1
)
SELECT
  browser_name,
  total_sessions,
  ROUND(verified_sessions / NULLIF(total_sessions, 0) * 100, 2) AS vr_pct,
  country_count
FROM base
WHERE total_sessions >= 10000000
ORDER BY total_sessions DESC;

-------------------------------------------------------------------------------
-- PASS 4 — ja4_concentration_ratio, Condition B clause 3 (~20s)
-- Closes the open TODO in §2.3/§5, which left the ratio "to be computed". Do NOT infer it
-- from the distinct hash count: §2.3 assumed a single-digit count implies a ratio "well
-- above 0.8", and measurement showed otherwise (Cypress 0.691, Resty 0.696, Unirest 0.743).
-- Replace the IN list with whatever passes 2-3 surfaced.
-- Include a few known-legitimate browsers as controls so the threshold can be re-baselined:
-- measured real-traffic range was 0.27-0.47, not the "below 10%" the doc assumes.
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
      -- flagged by passes 2-3
      'Go-http-client', 'Cypress', 'Resty', 'Unirest for Java',
      'KorbytPlayer', 'Beamrise', 'KakaoTalk',
      -- legitimate controls for re-baselining the threshold
      'Nintendo Browser', 'Headless Chrome', '(empty UA)', 'Opera Mobile'
    )
    AND CDN__JA4_HASH_AT_SESSION_CREATED IS NOT NULL
    AND CDN__JA4_HASH_AT_SESSION_CREATED <> ''
  GROUP BY 1, 2
)
SELECT
  browser_name,
  SUM(c)   AS sessions_with_ja4,
  COUNT(*) AS ja4_hash_count,
  MAX(c)   AS top_ja4_sessions,
  ROUND(MAX(c) / NULLIF(SUM(c), 0), 4) AS ja4_concentration_ratio
FROM j
GROUP BY 1
ORDER BY sessions_with_ja4 DESC;

-------------------------------------------------------------------------------
-- PASS 5 — investigation context for the flagged set (§3.4 / §6.3 / §6.4) (~28s)
-- Not classification criteria. WebGL homogeneity, ISP/ASN spread, hosting share, connection
-- mix, satellite. Satellite = 0 was the most reliable confirming signal in the 2026-09-18 run.
-- This is also the pass to use for continuity reporting on previously-listed names — keep
-- those names here, out of the discovery filters in passes 1-3.
-------------------------------------------------------------------------------
SELECT
  COALESCE(NULLIF(TRIM(BROWSER_NAME_AT_SESSION_CREATED), ''), '(empty UA)') AS browser_name,
  COUNT(*) AS total_sessions,
  COUNT(DISTINCT PUBLIC_KEY) AS key_count,
  COUNT(DISTINCT LATEST_ASN) AS asn_count,
  COUNT(DISTINCT LATEST_ISP) AS isp_count,
  COUNT(DISTINCT WEBGL_HASH_WEBGL_AT_SESSION_CREATED) AS webgl_hash_count,
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
    'Go-http-client', 'Cypress', 'Resty', 'Unirest for Java',
    'KorbytPlayer', 'Beamrise', 'KakaoTalk'
  )
GROUP BY 1
ORDER BY total_sessions DESC;
