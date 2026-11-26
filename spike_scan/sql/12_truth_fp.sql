-- Step 2 of the truth fingerprint check (Snowflake, database_id 14): the 09 fingerprint checks on truth-labelled sessions.
-- Rendered by truth_fp.py sql from step 1's cell (ids inlined ONCE as two comma strings: Superset echoes the SQL twice,
-- so keep <=150 ids per label and the session window to <=7 days (2 days for 10M+/day keys) or it times out). Output: "L:<fields>#F:<fields>" with fields
--   n|verified|h3|h1|font_os_mis|rig|no_fonts|no_fp|d3d_nonwin|plat_mis|top_fontset_n|top_voices_n|ja4_h1|soft_rend
WITH ids AS (SELECT 'L' AS lab, value AS sid FROM TABLE(SPLIT_TO_TABLE('{legit_ids}', ','))
             UNION ALL SELECT 'F', value FROM TABLE(SPLIT_TO_TABLE('{fraud_ids}', ','))),
s AS (
  SELECT ids.lab,
         COALESCE(SESSIONS_VERIFIED, 0) > 0 AS ver,
         CDN__HTTP_VERSION_AT_SESSION_CREATED AS hv, CDN__JA4_HASH_AT_SESSION_CREATED AS ja4,
         ARRAY_TO_STRING(LATEST_FP_FONTS::ARRAY, ',') AS fs, SPEECH_VOICES_HASH_AT_SESSION_CREATED AS vh,
         (NOT COALESCE(OS_AT_SESSION_CREATED, '') ILIKE 'windows%' AND ARRAY_TO_STRING(LATEST_FP_FONTS::ARRAY, ',') ILIKE ANY ('%Segoe UI%', '%Calibri%'))
           OR (OS_AT_SESSION_CREATED ILIKE 'windows%' AND ARRAY_SIZE(LATEST_FP_FONTS::ARRAY) > 5
               AND NOT ARRAY_TO_STRING(LATEST_FP_FONTS::ARRAY, ',') ILIKE '%Segoe UI%') AS fom,
         (LATEST_NAVIGATOR_DEVICE_MEMORY <= 4 AND LATEST_FP_HARDWARE_CONCURRENCY >= 12) AS rig,
         (LATEST_FP_FONTS IS NULL OR ARRAY_SIZE(LATEST_FP_FONTS::ARRAY) = 0) AS nofont,
         (INIT_FINGERPRINT_AT_SESSION_CREATED IS NULL) AS nofp,
         (COALESCE(WEBGL_UNMASKED_RENDERER_AT_SESSION_CREATED, '') ILIKE '%direct3d%' AND NOT COALESCE(OS_AT_SESSION_CREATED, '') ILIKE 'windows%') AS d3d,
         ((OS_AT_SESSION_CREATED ILIKE 'windows%' AND NOT COALESCE(LATEST_FP_NAVIGATOR_PLATFORM, '') ILIKE 'win%')
            OR (OS_AT_SESSION_CREATED ILIKE ANY ('mac%', 'os x%') AND NOT COALESCE(LATEST_FP_NAVIGATOR_PLATFORM, '') ILIKE 'mac%')
            OR (OS_AT_SESSION_CREATED ILIKE ANY ('linux%', 'chrome os%', 'android%', 'ios%') AND COALESCE(LATEST_FP_NAVIGATOR_PLATFORM, '') ILIKE 'win%')) AS pm,
         (COALESCE(WEBGL_UNMASKED_RENDERER_AT_SESSION_CREATED, '') ILIKE ANY ('%swiftshader%', '%llvmpipe%', '%basic render%', '%softpipe%')) AS rs
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY x JOIN ids ON ids.sid = x.GLOBAL_SESSION_ID
  WHERE x.SESSION_TS >= '{ts_from}' AND x.SESSION_TS < '{ts_to}' AND x.PUBLIC_KEY = '{key}'
),
a AS (SELECT lab, COUNT(*) n, COUNT_IF(ver) v, COUNT_IF(hv ILIKE '%3%') h3, COUNT_IF(hv ILIKE '%1.1%' OR hv = '1') h1, COUNT_IF(fom) fom,
             COUNT_IF(rig) rig, COUNT_IF(nofont) nofont, COUNT_IF(nofp) nofp, COUNT_IF(d3d) d3d, COUNT_IF(pm) pm,
             COUNT_IF(SPLIT_PART(ja4, '_', 1) ILIKE '%h1') ja4h1, COUNT_IF(rs) rs FROM s GROUP BY lab),
tf AS (SELECT lab, MAX(c) c FROM (SELECT lab, fs, COUNT(*) c FROM s WHERE fs <> '' GROUP BY 1, 2) GROUP BY lab),
tv AS (SELECT lab, MAX(c) c FROM (SELECT lab, vh, COUNT(*) c FROM s WHERE vh IS NOT NULL GROUP BY 1, 2) GROUP BY lab)
SELECT LISTAGG(a.lab || ':' || a.n || '|' || a.v || '|' || a.h3 || '|' || a.h1 || '|' || a.fom || '|' || a.rig || '|' || a.nofont || '|' || a.nofp
               || '|' || a.d3d || '|' || a.pm || '|' || COALESCE(tf.c, 0) || '|' || COALESCE(tv.c, 0) || '|' || a.ja4h1 || '|' || a.rs, '#') AS packed
FROM a LEFT JOIN tf ON tf.lab = a.lab LEFT JOIN tv ON tv.lab = a.lab
