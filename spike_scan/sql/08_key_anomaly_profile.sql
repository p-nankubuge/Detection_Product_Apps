-- Attribute anomalies per key per day (light "is this an attack?" profile, independent of telltales).
-- Snowflake (Superset database_id 14). Key-filtered (PUBLIC_KEY IN {keys}) so it prunes; params {base_start} {win_start} {win_end} {keys}.
-- Split by KEYS, never by dates (the CAPI baseline needs the baseline days). Very large keys: render with --sample 5
-- (block sampling) and ingest with --sample 5; spike_report.py anomaly merges by key.
-- Per key and UTC day: sessions, verified, then (count, verified) for each anomaly:
--   a0 capi_off    LATEST_CAPI_VERSION differs from the key's most common CAPI version in the baseline (or is missing)
--   a1 lang_mis    navigator language (LATEST_FP_LANGUAGE) primary subtag != Accept-Language primary subtag
--   a2 tz_mis      browser timezone region (LATEST_TIMEZONE) != IP timezone region (CDN__TIMEZONE_AT_SESSION_CREATED)
--   a3 ua_hdr_mis  JS user agent != HTTP User-Agent header
--   a4 ch_mis      Chromium UA whose sec-ch-ua does not carry the UA major version
--   a5 fake        fingerprint says fake browser / fake OS / fake resolution
--   a6 plat_mis    navigator.platform inconsistent with the OS in the UA
--   a7 rend_soft   software WebGL renderer (SwiftShader, llvmpipe, Microsoft Basic Render, softpipe)
--   a8 rend_os_mis WebGL renderer inconsistent with the OS (Apple GPU on Windows, Direct3D off Windows, mobile GPU on desktop)
--   a9 rend_null   no WebGL renderer
--   a10 hosting    hosting-provider IP
--   a11 proxyvpn   proxy or VPN IP
--   a12 headless   headless in the UA
-- Output: ONE cell. Part 1 rows "key8,day,n,v,a0,v0,...,a12,v12" joined by ';'; then '#'; part 2 per key
--   "key8|baseline CAPI mode|window top CAPI|its share|window top renderer|its share" joined by ';'
-- -> spike_report.py anomaly --run <D> --packed '<cell>'
WITH s AS (
  SELECT PUBLIC_KEY AS k, SESSION_TS::DATE AS d, COALESCE(SESSIONS_VERIFIED, 0) > 0 AS ver,
         LATEST_CAPI_VERSION AS capi, LATEST_FP_LANGUAGE AS fl, LATEST_HTTP_ACCEPT_LANGUAGE AS al,
         LATEST_TIMEZONE AS tz, CDN__TIMEZONE_AT_SESSION_CREATED AS iptz,
         UA_AT_SESSION_CREATED AS ua, HEADER_USER_AGENT_AT_SESSION_CREATED AS hua, LATEST_SEC_CH_UA AS chua,
         BROWSER_NAME_AT_SESSION_CREATED AS br, SPLIT_PART(BROWSER_VERSION_AT_SESSION_CREATED, '.', 1) AS mj,
         OS_AT_SESSION_CREATED AS os, LATEST_FP_NAVIGATOR_PLATFORM AS plat,
         COALESCE(WEBGL_UNMASKED_RENDERER_AT_SESSION_CREATED, WEBGL_RENDERER_AT_SESSION_CREATED) AS rend,
         COALESCE(LATEST_FP_HAS_FAKE_BROWSER, FALSE) OR COALESCE(LATEST_FP_HAS_FAKE_OS, FALSE) OR COALESCE(LATEST_FP_HAS_FAKE_RESOLUTION, FALSE) AS fake,
         COALESCE(LATEST_IS_HOSTING_PROVIDER, FALSE) AS hosting,
         COALESCE(LATEST_IS_PROXY, FALSE) OR COALESCE(LATEST_IS_VPN, FALSE) AS proxyvpn
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY {sample}
  WHERE SESSION_TS >= '{base_start}' AND SESSION_TS < '{win_end}' AND PUBLIC_KEY IN ({keys})
),
capi_mode AS (SELECT k, MODE(capi) AS m FROM s WHERE d < '{win_start}' GROUP BY k),
f AS (
  SELECT s.k, s.d, s.ver,
    (s.capi IS NULL OR s.capi <> c.m) AS a0,
    (s.fl IS NOT NULL AND s.al IS NOT NULL AND LOWER(LEFT(s.fl, 2)) <> LOWER(LEFT(s.al, 2))) AS a1,
    (s.tz IS NOT NULL AND s.iptz IS NOT NULL AND LOWER(SPLIT_PART(s.tz, '/', 1)) <> LOWER(SPLIT_PART(s.iptz, '/', 1))) AS a2,
    (s.ua IS NOT NULL AND s.hua IS NOT NULL AND s.ua <> s.hua) AS a3,
    (s.br ILIKE ANY ('chrome%', 'edge%', 'opera%', 'samsung%') AND s.chua IS NOT NULL AND NOT CONTAINS(s.chua, 'v="' || s.mj || '"')) AS a4,
    s.fake AS a5,
    ((s.os ILIKE 'windows%' AND NOT COALESCE(s.plat, '') ILIKE 'win%')
      OR (s.os ILIKE 'mac%' AND NOT COALESCE(s.plat, '') ILIKE 'mac%')
      OR (s.os ILIKE 'android%' AND COALESCE(s.plat, '') ILIKE ANY ('win%', 'mac%'))
      OR (s.os ILIKE 'ios%' AND COALESCE(s.plat, '') ILIKE ANY ('win%', 'linux%'))) AS a6,
    (s.rend ILIKE ANY ('%swiftshader%', '%llvmpipe%', '%basic render%', '%softpipe%')) AS a7,
    ((s.rend ILIKE '%apple%' AND s.os ILIKE 'windows%')
      OR (s.rend ILIKE '%direct3d%' AND NOT s.os ILIKE 'windows%')
      OR (s.rend ILIKE ANY ('%adreno%', '%mali%', '%powervr%') AND s.os ILIKE ANY ('windows%', 'mac%'))) AS a8,
    (s.rend IS NULL OR s.rend = '') AS a9,
    s.hosting AS a10, s.proxyvpn AS a11,
    (s.ua ILIKE '%headless%' OR s.hua ILIKE '%headless%') AS a12
  FROM s LEFT JOIN capi_mode c ON c.k = s.k
),
agg AS (
  SELECT k, d, COUNT(*) AS n, COUNT_IF(ver) AS v,
    COUNT_IF(a0) a0, COUNT_IF(a0 AND ver) v0, COUNT_IF(a1) a1, COUNT_IF(a1 AND ver) v1, COUNT_IF(a2) a2, COUNT_IF(a2 AND ver) v2,
    COUNT_IF(a3) a3, COUNT_IF(a3 AND ver) v3, COUNT_IF(a4) a4, COUNT_IF(a4 AND ver) v4, COUNT_IF(a5) a5, COUNT_IF(a5 AND ver) v5,
    COUNT_IF(a6) a6, COUNT_IF(a6 AND ver) v6, COUNT_IF(a7) a7, COUNT_IF(a7 AND ver) v7, COUNT_IF(a8) a8, COUNT_IF(a8 AND ver) v8,
    COUNT_IF(a9) a9, COUNT_IF(a9 AND ver) v9, COUNT_IF(a10) a10, COUNT_IF(a10 AND ver) v10, COUNT_IF(a11) a11, COUNT_IF(a11 AND ver) v11,
    COUNT_IF(a12) a12, COUNT_IF(a12 AND ver) v12
  FROM f GROUP BY k, d
),
wcapi AS (
  SELECT k, capi, COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY k) AS sh FROM s WHERE d >= '{win_start}' GROUP BY k, capi
  QUALIFY ROW_NUMBER() OVER (PARTITION BY k ORDER BY COUNT(*) DESC) = 1
),
wrend AS (
  SELECT k, rend, COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY k) AS sh FROM s WHERE d >= '{win_start}' GROUP BY k, rend
  QUALIFY ROW_NUMBER() OVER (PARTITION BY k ORDER BY COUNT(*) DESC) = 1
),
p1 AS (
  SELECT LISTAGG(LEFT(k, 8) || ',' || TO_CHAR(d, 'YYYY-MM-DD') || ',' || n || ',' || v || ',' ||
         a0||','||v0||','||a1||','||v1||','||a2||','||v2||','||a3||','||v3||','||a4||','||v4||','||a5||','||v5||','||a6||','||v6||','||
         a7||','||v7||','||a8||','||v8||','||a9||','||v9||','||a10||','||v10||','||a11||','||v11||','||a12||','||v12, ';')
         WITHIN GROUP (ORDER BY k, d) AS x FROM agg
),
p2 AS (
  SELECT LISTAGG(LEFT(c.k, 8) || '|' || COALESCE(c.m, '-') || '|' || COALESCE(w.capi, '-') || '|' || ROUND(w.sh, 3) || '|' ||
         REPLACE(REPLACE(COALESCE(LEFT(r.rend, 60), '-'), '|', '/'), ';', ',') || '|' || ROUND(r.sh, 3), ';') AS x
  FROM capi_mode c LEFT JOIN wcapi w ON w.k = c.k LEFT JOIN wrend r ON r.k = c.k
)
SELECT p1.x || '#' || COALESCE(p2.x, '') AS packed FROM p1, p2
