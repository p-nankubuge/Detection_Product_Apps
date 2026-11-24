-- "Does this cohort look like an attack?" -- judged on session-time evidence, NOT on whether sessions ended verified.
-- Snowflake (Superset database_id 14). One key, one cohort predicate. Params (render.py): {key}, {cond} (SQL predicate; --combo-id
-- gives the combination's flags, --cond any predicate over the columns below), {base_start} {win_start} {win_end}, {sample}.
-- Output: ONE cell "D:<day,key_total,cohort,cohort_verified;...>#H:<hour,cohort,key_total;...>#S:<summary fields joined by |>"
--   S = n|verified|distinct_ips|max_sessions_one_ip|distinct_devices|max_sessions_one_device|distinct_ja4|distinct_ua_claims|
--       hosting|proxy_vpn|lang_mis|plat_mis|soft_renderer|tz_mis|headless|fake_fp|median_ip_velocity_st|top_asn|top_asn_n|
--       top_ja4|top_ja4_claim|top_ja4_n|top_http_version|top_http_n|top_country|top_country_n
-- -> spike_report.py cohort --run <D> --name <id> --key <key> --desc '<text>' --packed '<cell>' [--sample N]
WITH s AS (
  SELECT SESSION_TS::DATE AS d, HOUR(SESSION_TS) AS h, COALESCE(SESSIONS_VERIFIED, 0) > 0 AS ver,
         USER_IP_AT_SESSION_CREATED AS ip, CDN__ASN_AT_SESSION_CREATED AS asn, CDN__COUNTRY_CODE_AT_SESSION_CREATED AS cc,
         COALESCE(LATEST_IS_HOSTING_PROVIDER, FALSE) AS hosting,
         COALESCE(LATEST_IS_PROXY, FALSE) OR COALESCE(LATEST_IS_VPN, FALSE) AS proxy,
         STATELESS_DEVICE_ID_AT_SESSION_CREATED AS dev, CDN__JA4_HASH_AT_SESSION_CREATED AS ja4,
         COALESCE(BROWSER_NAME_AT_SESSION_CREATED, '?') || ' ' || COALESCE(SPLIT_PART(BROWSER_VERSION_AT_SESSION_CREATED, '.', 1), '?') AS claim,
         CDN__HTTP_VERSION_AT_SESSION_CREATED AS hv, LATEST_RTA_IP_VELOCITY_SHORT_TERM_COUNT AS ipv,
         (LATEST_FP_LANGUAGE IS NOT NULL AND LATEST_HTTP_ACCEPT_LANGUAGE IS NOT NULL
            AND LOWER(LEFT(LATEST_FP_LANGUAGE, 2)) <> LOWER(LEFT(LATEST_HTTP_ACCEPT_LANGUAGE, 2))) AS lm,
         ((OS_AT_SESSION_CREATED ILIKE 'windows%' AND NOT COALESCE(LATEST_FP_NAVIGATOR_PLATFORM, '') ILIKE 'win%')
            OR (OS_AT_SESSION_CREATED ILIKE ANY ('mac%', 'os x%') AND NOT COALESCE(LATEST_FP_NAVIGATOR_PLATFORM, '') ILIKE 'mac%')
            OR (OS_AT_SESSION_CREATED ILIKE 'android%' AND COALESCE(LATEST_FP_NAVIGATOR_PLATFORM, '') ILIKE ANY ('win%', 'mac%'))) AS pm,
         (COALESCE(WEBGL_UNMASKED_RENDERER_AT_SESSION_CREATED, '') ILIKE ANY ('%swiftshader%', '%llvmpipe%', '%basic render%', '%softpipe%')) AS rs,
         (LATEST_TIMEZONE IS NOT NULL AND CDN__TIMEZONE_AT_SESSION_CREATED IS NOT NULL
            AND LOWER(SPLIT_PART(LATEST_TIMEZONE, '/', 1)) <> LOWER(SPLIT_PART(CDN__TIMEZONE_AT_SESSION_CREATED, '/', 1))) AS tm,
         (COALESCE(UA_AT_SESSION_CREATED, '') ILIKE '%headless%') AS hl,
         COALESCE(LATEST_FP_HAS_FAKE_BROWSER, FALSE) OR COALESCE(LATEST_FP_HAS_FAKE_OS, FALSE) OR COALESCE(LATEST_FP_HAS_FAKE_RESOLUTION, FALSE) AS fk,
         ({cond}) AS hit
  FROM (
    SELECT *, ARRAY_CAT(COALESCE(SUSPICION_FLAGS::ARRAY, ARRAY_CONSTRUCT()), COALESCE(TELLTALE_LIST_AT_ALL_EVENTS::ARRAY, ARRAY_CONSTRUCT())) AS flags
    FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY {sample}
    WHERE SESSION_TS >= '{base_start}' AND SESSION_TS < '{win_end}' AND PUBLIC_KEY = '{key}'
  )
),
w AS (SELECT * FROM s WHERE hit AND d >= '{win_start}'),
pd AS (SELECT 'D:' || LISTAGG(TO_CHAR(d, 'YYYY-MM-DD') || ',' || tot || ',' || n || ',' || v, ';') WITHIN GROUP (ORDER BY d) AS x
       FROM (SELECT d, COUNT(*) tot, COUNT_IF(hit) n, COUNT_IF(hit AND ver) v FROM s GROUP BY d)),
ph AS (SELECT 'H:' || LISTAGG(h || ',' || n || ',' || tot, ';') WITHIN GROUP (ORDER BY h) AS x
       FROM (SELECT h, COUNT_IF(hit) n, COUNT(*) tot FROM s WHERE d >= '{win_start}' GROUP BY h)),
sm AS (SELECT COUNT(*) n, COUNT_IF(ver) v, COUNT(DISTINCT ip) ips, COUNT(DISTINCT dev) devs, COUNT(DISTINCT ja4) ja4s,
              COUNT(DISTINCT claim) claims, COUNT_IF(hosting) host, COUNT_IF(proxy) prox, COUNT_IF(lm) lm, COUNT_IF(pm) pm,
              COUNT_IF(rs) rs, COUNT_IF(tm) tm, COUNT_IF(hl) hl, COUNT_IF(fk) fk, MEDIAN(ipv) ipv FROM w),
tip AS (SELECT COALESCE(MAX(c), 0) c FROM (SELECT ip, COUNT(*) c FROM w WHERE ip IS NOT NULL GROUP BY ip)),
tdv AS (SELECT COALESCE(MAX(c), 0) c FROM (SELECT dev, COUNT(*) c FROM w WHERE dev IS NOT NULL GROUP BY dev)),
tas AS (SELECT asn, COUNT(*) c FROM w GROUP BY asn ORDER BY c DESC LIMIT 1),
tja AS (SELECT ja4, MODE(claim) claim, COUNT(*) c FROM w GROUP BY ja4 ORDER BY c DESC LIMIT 1),
thv AS (SELECT hv, COUNT(*) c FROM w GROUP BY hv ORDER BY c DESC LIMIT 1),
tcc AS (SELECT cc, COUNT(*) c FROM w GROUP BY cc ORDER BY c DESC LIMIT 1),
ps AS (SELECT 'S:' || sm.n || '|' || sm.v || '|' || sm.ips || '|' || tip.c || '|' || sm.devs || '|' || tdv.c || '|' || sm.ja4s || '|' || sm.claims
              || '|' || sm.host || '|' || sm.prox || '|' || sm.lm || '|' || sm.pm || '|' || sm.rs || '|' || sm.tm || '|' || sm.hl || '|' || sm.fk
              || '|' || COALESCE(sm.ipv::TEXT, '') || '|' || COALESCE((SELECT asn FROM tas), '') || '|' || COALESCE((SELECT c FROM tas), 0)
              || '|' || COALESCE((SELECT ja4 FROM tja), '') || '|' || REPLACE(COALESCE((SELECT claim FROM tja), ''), '|', '/') || '|' || COALESCE((SELECT c FROM tja), 0)
              || '|' || COALESCE((SELECT hv FROM thv), '') || '|' || COALESCE((SELECT c FROM thv), 0)
              || '|' || COALESCE((SELECT cc FROM tcc), '') || '|' || COALESCE((SELECT c FROM tcc), 0) AS x
       FROM sm, tip, tdv)
SELECT pd.x || '#' || ph.x || '#' || ps.x AS packed FROM pd, ph, ps
