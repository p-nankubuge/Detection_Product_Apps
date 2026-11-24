-- ATTEMPTED, NOT USED: direct Athena join of truth data to prod_session_summary (Trino, database_id 2).
-- Status: TIMED OUT. starfleet_production.prod_session_summary has NO year/month/day partition columns;
--   only session_ts prunes. count(*) for one key and 1 hour took ~27 s; 6 hours (and 1 day) timed out;
--   this full rule query timed out even for a single hour (2026-10-01 07:00-08:00).
--   The TD scoring actually used is td_sample_export_athena.sql + td_sample_scoring_snowflake.sql.
-- Kept so the attempt can be repeated if Athena gets a longer timeout ({START}/{END} = window bounds).
-- TD: truth_data_history, partitions year=2026, month IN (10,11); latest label per session (max_by ingest_timestamp).
-- Rule logic is identical to _flags_cte.sql (Snowflake).

WITH td AS (
  SELECT arkose_session_id,
         max_by(is_legit, ingest_timestamp)    AS lbl,
         max_by(is_verified, ingest_timestamp) AS td_verified
  FROM starfleet_production.truth_data_history
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND year = 2026 AND month IN (10, 11)
    AND session_create_timestamp >= TIMESTAMP '{START}'
    AND session_create_timestamp <  TIMESTAMP '{END}'
  GROUP BY 1
),
p AS (
  SELECT session,
         cdn__ja4_hash_at_session_created AS ja4,
         split_part(cdn__ja4_hash_at_session_created, '_', 1) AS a,
         ua_at_session_created AS ua,
         latest_browser_detection_brave AS is_brave,
         sessions_verify_attempted AS va
  FROM starfleet_production.prod_session_summary
  WHERE session_ts >= TIMESTAMP '{START}' AND session_ts < TIMESTAMP '{END}'
    AND public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
),
f AS (
  SELECT p.*,
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
    END AS fam,
    substr(a, 1, 1) AS tr, substr(a, 2, 2) AS tv,
    try_cast(substr(a, 5, 2) AS integer) AS cc, try_cast(substr(a, 7, 2) AS integer) AS ec,
    substr(a, 9, 2) AS alpn,
    try_cast(regexp_extract(ua, 'Chrome/([0-9]+)', 1) AS integer)  AS chm,
    try_cast(regexp_extract(ua, 'Firefox/([0-9]+)', 1) AS integer) AS ffm,
    try_cast(regexp_extract(ua, 'Version/([0-9]+)', 1) AS integer) AS sfm,
    try_cast(regexp_extract(ua, ' OS ([0-9]+)_', 1) AS integer)    AS iom
  FROM p
),
g AS (
  SELECT f.*,
    fam IN ('chrome','edge','firefox','safari','opera','brave','samsung') AS br,
    fam IN ('chrome','edge','opera','brave') AS chromium,
    CASE WHEN fam IN ('chrome','edge','opera','brave','samsung') THEN coalesce(chm >= 70, false)
         WHEN fam = 'firefox' THEN coalesce(ffm >= 63, false)
         WHEN fam = 'safari' THEN coalesce(sfm >= 13, iom >= 13, false) ELSE false END AS modern,
    coalesce(CASE fam
      WHEN 'chrome'  THEN cc IN (10,12,13,14,15,16,17,18,19,20,26,27,28,29,30,31,34,69)
      WHEN 'edge'    THEN cc IN (8,10,12,13,14,15,16,19,20,24,26,27,29,30,31,33,34,37,40,41,57,68,69,75,87)
      WHEN 'firefox' THEN cc IN (15,16,17,18,26,27,28,30,31,52)
      WHEN 'safari'  THEN cc IN (13,15,17,18,20,21,26)
      WHEN 'opera'   THEN cc IN (15) WHEN 'brave' THEN cc IN (15) WHEN 'samsung' THEN cc IN (15) END, false)
    AND coalesce(CASE fam
      WHEN 'chrome'  THEN ec IN (9,10,11,12,13,14,15,16,17,18)
      WHEN 'edge'    THEN ec IN (7,9,10,11,12,13,14,16,17)
      WHEN 'firefox' THEN ec IN (9,10,11,12,13,14,15,16,17)
      WHEN 'safari'  THEN ec IN (7,13,14,15,16,17)
      WHEN 'opera'   THEN ec IN (16,17,18) WHEN 'brave' THEN ec IN (10,12,16) WHEN 'samsung' THEN ec IN (16,17) END, false) AS in_rng
  FROM f
),
fl AS (
  SELECT g.session, g.va,
    coalesce(ja4 IS NOT NULL AND chromium AND tr = 't' AND alpn = 'h1', false) AS c2,
    coalesce(ja4 IS NOT NULL AND chromium AND chm >= 70 AND tr = 't' AND tv = '12', false) AS c3,
    coalesce(ja4 IS NOT NULL AND br AND alpn = '00', false) AS n9,
    coalesce(ja4 IS NOT NULL AND br AND tr = 't' AND NOT in_rng, false) AS n10,
    coalesce(ja4 IS NOT NULL AND modern AND tr = 't' AND tv <> '13', false) AS n11
  FROM g
),
j AS (
  SELECT fl.*, td.lbl, td.td_verified
  FROM fl LEFT JOIN td ON td.arkose_session_id = fl.session
)
SELECT
  count(*) AS sessions,
  count_if(lbl = 'Legit') AS legit, count_if(lbl = 'Nonlegit' AND td_verified = 1) AS nonlegit_ver,
  count_if(lbl = 'Nonlegit') AS nonlegit,
  -- per rule: hits, Legit hits, Nonlegit-verified hits, Nonlegit hits, unlabelled hits (verify attempted / not)
  count_if(c2)  AS c2,  count_if(c2  AND lbl='Legit') AS c2_l,  count_if(c2  AND lbl='Nonlegit' AND td_verified=1) AS c2_nv,  count_if(c2  AND lbl='Nonlegit') AS c2_n,  count_if(c2  AND lbl IS NULL AND va > 0) AS c2_u_va,  count_if(c2  AND lbl IS NULL AND NOT va > 0) AS c2_u_nva,
  count_if(c3)  AS c3,  count_if(c3  AND lbl='Legit') AS c3_l,  count_if(c3  AND lbl='Nonlegit' AND td_verified=1) AS c3_nv,  count_if(c3  AND lbl='Nonlegit') AS c3_n,  count_if(c3  AND lbl IS NULL AND va > 0) AS c3_u_va,  count_if(c3  AND lbl IS NULL AND NOT va > 0) AS c3_u_nva,
  count_if(n9)  AS n9,  count_if(n9  AND lbl='Legit') AS n9_l,  count_if(n9  AND lbl='Nonlegit' AND td_verified=1) AS n9_nv,  count_if(n9  AND lbl='Nonlegit') AS n9_n,  count_if(n9  AND lbl IS NULL AND va > 0) AS n9_u_va,  count_if(n9  AND lbl IS NULL AND NOT va > 0) AS n9_u_nva,
  count_if(n10) AS n10, count_if(n10 AND lbl='Legit') AS n10_l, count_if(n10 AND lbl='Nonlegit' AND td_verified=1) AS n10_nv, count_if(n10 AND lbl='Nonlegit') AS n10_n, count_if(n10 AND lbl IS NULL AND va > 0) AS n10_u_va, count_if(n10 AND lbl IS NULL AND NOT va > 0) AS n10_u_nva,
  count_if(n11) AS n11, count_if(n11 AND lbl='Legit') AS n11_l, count_if(n11 AND lbl='Nonlegit' AND td_verified=1) AS n11_nv, count_if(n11 AND lbl='Nonlegit') AS n11_n, count_if(n11 AND lbl IS NULL AND va > 0) AS n11_u_va, count_if(n11 AND lbl IS NULL AND NOT va > 0) AS n11_u_nva
FROM j;
