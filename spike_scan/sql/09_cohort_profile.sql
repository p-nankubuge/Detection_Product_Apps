-- "Does this cohort look like an attack?" -- judged on session-time evidence, NOT on whether sessions ended verified.
-- Snowflake (Superset database_id 14). One key, one cohort predicate. Params (render.py): {key}, {cond} (SQL predicate; --combo-id
-- gives the combination's flags, --cond any predicate over the columns below), {base_start} {win_start} {win_end}, {sample}.
-- Output: ONE cell "D:<day,key_total,cohort,cohort_verified;...>#H:<hour,cohort,key_total;...>#S:<summary fields joined by |>"
--   S = n|verified|distinct_ips|max_sessions_one_ip|distinct_devices|max_sessions_one_device|distinct_ja4|distinct_ua_claims|
--       hosting|proxy_vpn|lang_mis|plat_mis|soft_renderer|tz_mis|headless|fake_fp|median_ip_velocity_st|top_asn|top_asn_n|
--       top_ja4|top_ja4_claim|top_ja4_n|top_http_version|top_http_n|top_country|top_country_n|
--       h3|h1|font_os_mis|rig_mem_cores|no_fonts|no_fp|top_fontset_n|top_voices_n|
--       rest_n|rest_h3|rest_font_os_mis|rest_top_fontset_n|rest_top_voices_n      (rest = same key, same window, NOT in the cohort)
--   Granular fields (other team's "candidate signals vs truth" ideas): HTTP/3 share is an FP bound (real Chrome upgrades to QUIC via
--   alt-svc, bot libraries rarely do) -- only meaningful when the rest of the key shows h3; fonts that don't match the claimed OS;
--   4GB-or-less memory with 12+ cores (rig); one exact font set / voices hash shared by most of the cohort (same build image).
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
         ({cond}) AS hit,
         (hv ILIKE '%3%') AS h3, (hv ILIKE '%1.1%' OR hv = '1') AS h1,
         ARRAY_TO_STRING(LATEST_FP_FONTS::ARRAY, ',') AS fs, SPEECH_VOICES_HASH_AT_SESSION_CREATED AS vh,
         (NOT COALESCE(OS_AT_SESSION_CREATED, '') ILIKE 'windows%' AND ARRAY_TO_STRING(LATEST_FP_FONTS::ARRAY, ',') ILIKE ANY ('%Segoe UI%', '%Calibri%'))
           OR (OS_AT_SESSION_CREATED ILIKE 'windows%' AND ARRAY_SIZE(LATEST_FP_FONTS::ARRAY) > 5
               AND NOT ARRAY_TO_STRING(LATEST_FP_FONTS::ARRAY, ',') ILIKE '%Segoe UI%') AS fom,
         (LATEST_NAVIGATOR_DEVICE_MEMORY <= 4 AND LATEST_FP_HARDWARE_CONCURRENCY >= 12) AS rig,
         (LATEST_FP_FONTS IS NULL OR ARRAY_SIZE(LATEST_FP_FONTS::ARRAY) = 0) AS nofont,
         (INIT_FINGERPRINT_AT_SESSION_CREATED IS NULL) AS nofp
  FROM (
    SELECT *, ARRAY_CAT(COALESCE(SUSPICION_FLAGS::ARRAY, ARRAY_CONSTRUCT()), COALESCE(TELLTALE_LIST_AT_ALL_EVENTS::ARRAY, ARRAY_CONSTRUCT())) AS flags
    FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY {sample}
    WHERE SESSION_TS >= '{base_start}' AND SESSION_TS < '{win_end}' AND PUBLIC_KEY = '{key}'
  )
),
w AS (SELECT * FROM s WHERE hit AND d >= '{win_start}'),
r AS (SELECT * FROM s WHERE NOT hit AND d >= '{win_start}'),
g AS (SELECT COUNT_IF(h3) h3, COUNT_IF(h1) h1, COUNT_IF(fom) fom, COUNT_IF(rig) rig, COUNT_IF(nofont) nofont, COUNT_IF(nofp) nofp,
             (SELECT COALESCE(MAX(c), 0) FROM (SELECT fs, COUNT(*) c FROM w WHERE fs <> '' GROUP BY fs)) tfs,
             (SELECT COALESCE(MAX(c), 0) FROM (SELECT vh, COUNT(*) c FROM w WHERE vh IS NOT NULL GROUP BY vh)) tvh FROM w),
gr AS (SELECT COUNT(*) n, COUNT_IF(h3) h3, COUNT_IF(fom) fom,
              (SELECT COALESCE(MAX(c), 0) FROM (SELECT fs, COUNT(*) c FROM r WHERE fs <> '' GROUP BY fs)) tfs,
              (SELECT COALESCE(MAX(c), 0) FROM (SELECT vh, COUNT(*) c FROM r WHERE vh IS NOT NULL GROUP BY vh)) tvh FROM r),
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
              || '|' || COALESCE((SELECT cc FROM tcc), '') || '|' || COALESCE((SELECT c FROM tcc), 0)
              || '|' || g.h3 || '|' || g.h1 || '|' || g.fom || '|' || g.rig || '|' || g.nofont || '|' || g.nofp || '|' || g.tfs || '|' || g.tvh
              || '|' || gr.n || '|' || gr.h3 || '|' || gr.fom || '|' || gr.tfs || '|' || gr.tvh AS x
       FROM sm, tip, tdv, g, gr)
SELECT pd.x || '#' || ph.x || '#' || ps.x AS packed FROM pd, ph, ps
