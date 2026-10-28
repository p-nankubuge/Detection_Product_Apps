-- Payoneer hunt queries (Snowflake, ARK_PROD.events.mini_events_log). See docs/payoneer-hunt-2026-10-28.md.
-- Keys: 7CC24C4A-611B-41C7-9808-B95722C7861C (Registration), EE844FC3-499D-4A4D-A643-D7400F0FD4DE (Login),
--       E3EFEFBF-8DE4-42ED-9E7F-92F35B1FD3CF (CLM Registration).
-- Suspicion flags + global TTs are in SUSPICION_FLAGS; pressured TTs are in TELLTALE_LIST.

-- 1. Daily surge scan for one key: every flag/TT whose daily count is >= 3x its trailing-14-day mean.
--    hist >= 10 skips flags created inside the window (new TTs, not surges).
WITH s AS (
  SELECT timestamp::date d, ARRAY_CAT(SUSPICION_FLAGS, TELLTALE_LIST) f
  FROM "ARK_PROD".events.mini_events_log
  WHERE timestamp >= DATEADD(day, -45, CURRENT_DATE()) AND timestamp < CURRENT_DATE()
    AND location = 'session_setup' AND message = 'Session Created'
    AND public_key = 'E3EFEFBF-8DE4-42ED-9E7F-92F35B1FD3CF'
), fd AS (
  SELECT t.value::string f, d, COUNT(*) n FROM s, LATERAL FLATTEN(input => s.f) t GROUP BY 1, 2
), b AS (
  SELECT a.f, a.d, a.n, COALESCE(SUM(p.n) / 14, 0) base, COUNT(p.d) hist
  FROM fd a
  LEFT JOIN fd p ON p.f = a.f AND p.d BETWEEN DATEADD(day, -14, a.d) AND DATEADD(day, -1, a.d)
  WHERE a.d >= DATEADD(day, -31, CURRENT_DATE())
  GROUP BY 1, 2, 3
)
SELECT d, f, n, ROUND(base) AS base
FROM b
WHERE hist >= 10 AND n >= 60 AND n >= 3 * GREATEST(base, 10) AND f NOT LIKE '%-e-aaa-%'
ORDER BY d, n - base DESC;

-- 2. Outcome for a candidate signal: verified / challenged / custom-TT coverage.
--    Swap the WHERE in `sig` for the signal under test.
WITH sig AS (
  SELECT session, SUBSTR(public_key, 1, 4) k, timestamp::date d, TELLTALE_LIST tl
  FROM "ARK_PROD".events.mini_events_log
  WHERE timestamp >= DATEADD(day, -30, CURRENT_DATE())
    AND location = 'session_setup' AND message = 'Session Created'
    AND public_key IN ('E3EFEFBF-8DE4-42ED-9E7F-92F35B1FD3CF', 'EE844FC3-499D-4A4D-A643-D7400F0FD4DE',
                       '7CC24C4A-611B-41C7-9808-B95722C7861C')
    AND TO_VARCHAR(fp_resolution::variant) = '[1050,1000]'
), o AS (
  SELECT session,
         MAX(IFF(location = 'game_verify' AND solved = 1 AND verified = 1, 1, 0)) v,
         MAX(IFF(location = 'game_setup', 1, 0)) ch
  FROM "ARK_PROD".events.mini_events_log
  WHERE timestamp >= DATEADD(day, -30, CURRENT_DATE()) AND location IN ('game_verify', 'game_setup')
    AND session IN (SELECT session FROM sig)
  GROUP BY 1
)
SELECT k, d, COUNT(*) n,
       ROUND(100 * AVG(COALESCE(v, 0))) ver_pct,
       ROUND(100 * AVG(COALESCE(ch, 0))) chal_pct,
       ROUND(100 * AVG(IFF(REGEXP_LIKE(ARRAY_TO_STRING(tl::ARRAY, ','), '.*payoneer[0-9a-f]*-h-.*'), 1, 0))) custom_tt_pct
FROM sig LEFT JOIN o USING (session)
GROUP BY 1, 2 ORDER BY 1, 2;

-- 3. Low-and-slow: desktop init_fingerprints reused across many IPs/days at low daily volume.
--    Mobile Safari / WebView are excluded: they collide on init_fingerprint legitimately.
WITH s AS (
  SELECT SUBSTR(public_key, 1, 4) k, timestamp::date d, init_fingerprint fp, user_ip ip, country cc,
         email__root_email_domain dom, TO_VARCHAR(fp_resolution::variant) res,
         browser_name || ' ' || SPLIT_PART(browser_version, '.', 1) br
  FROM "ARK_PROD".events.mini_events_log
  WHERE timestamp >= DATEADD(day, -30, CURRENT_DATE())
    AND location = 'session_setup' AND message = 'Session Created'
    AND public_key IN ('E3EFEFBF-8DE4-42ED-9E7F-92F35B1FD3CF', 'EE844FC3-499D-4A4D-A643-D7400F0FD4DE',
                       '7CC24C4A-611B-41C7-9808-B95722C7861C')
    AND init_fingerprint <> ''
    AND os IN ('Windows', 'OS X', 'GNU/Linux', 'Ubuntu', 'Chrome OS')
    AND browser_name NOT ILIKE '%webview%' AND browser_name NOT ILIKE 'mobile%'
), daily AS (
  SELECT k, fp, d, COUNT(*) c FROM s GROUP BY 1, 2, 3
)
SELECT g.k, g.fp, g.n, g.days, g.ips, g.ccs, m.mx AS max_per_day, g.mcc, g.mdom, g.mres, g.mbr
FROM (
  SELECT k, fp, COUNT(*) n, COUNT(DISTINCT d) days, COUNT(DISTINCT ip) ips, COUNT(DISTINCT cc) ccs,
         MODE(cc) mcc, MODE(dom) mdom, MODE(res) mres, MODE(br) mbr
  FROM s GROUP BY 1, 2
) g
JOIN (SELECT k, fp, MAX(c) mx FROM daily GROUP BY 1, 2) m USING (k, fp)
WHERE g.n >= 40 AND g.days >= 5 AND m.mx <= 60 AND g.ips >= 0.6 * g.n
ORDER BY g.k, g.n DESC;
