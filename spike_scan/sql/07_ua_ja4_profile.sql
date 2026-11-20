-- Claimed UA vs JA4 for ONE tracked combination on ONE key (the top JA4 cohorts of the flagged sessions).
-- Snowflake (Superset database_id 14). Key-filtered, so it prunes fast. Params (render.py --combo-id --key):
--   {ts_from} {ts_to} (window, default last 2 days), {key}, {combo_cond} (all flags present), {fam_from} {fam_to} (6h baseline slice, all keys).
-- Per JA4 (top 15 by flagged sessions):
--   claimed browser/major among flagged (top one + number of distinct browser|major claims = UA rotation),
--   flagged, flagged & verified, unflagged sessions on the same key with that JA4,
--   sec-ch-ua that does not carry the UA's major version (Chromium claims only),
--   top ASN + its share, top country,
--   fam_*: what that JA4 claims to be across ALL Production keys in a baseline slice (top browser FAMILY chromium/webkit/firefox/other, its share, distinct majors).
-- Output: ONE cell, rows "ja4|claim|claims_n|flagged|flag_ver|unflagged|ch_mismatch|top_asn|asn_share|top_cc|fam_browser|fam_share|fam_majors|fam_n" joined by ';'
-- -> spike_report.py uaja4 --combo <id> --key <key> --packed '<cell>'
WITH s AS (
  SELECT CDN__JA4_HASH_AT_SESSION_CREATED AS ja4,
         COALESCE(BROWSER_NAME_AT_SESSION_CREATED, '?') AS br,
         COALESCE(SPLIT_PART(BROWSER_VERSION_AT_SESSION_CREATED, '.', 1), '?') AS mj,
         LATEST_SEC_CH_UA AS chua,
         CDN__ASN_AT_SESSION_CREATED AS asn,
         CDN__COUNTRY_CODE_AT_SESSION_CREATED AS cc,
         COALESCE(SESSIONS_VERIFIED, 0) > 0 AS verified,
         ({combo_cond}) AS hit
  FROM (
    SELECT *, ARRAY_CAT(COALESCE(SUSPICION_FLAGS::ARRAY, ARRAY_CONSTRUCT()),
                        COALESCE(TELLTALE_LIST_AT_ALL_EVENTS::ARRAY, ARRAY_CONSTRUCT())) AS flags
    FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
    WHERE SESSION_TS >= '{ts_from}' AND SESSION_TS < '{ts_to}' AND PUBLIC_KEY = '{key}'
  )
),
top AS (
  SELECT ja4, COUNT_IF(hit) AS flagged, COUNT_IF(hit AND verified) AS flag_ver, COUNT_IF(NOT hit) AS unflagged,
         COUNT(DISTINCT IFF(hit, br || ' ' || mj, NULL)) AS claims_n,
         COUNT_IF(hit AND br IN ('Chrome', 'Edge', 'Opera', 'Samsung Browser', 'Chrome Mobile', 'Chromium')
                  AND chua IS NOT NULL AND NOT CONTAINS(chua, 'v="' || mj || '"')) AS ch_mismatch
  FROM s WHERE ja4 IS NOT NULL GROUP BY ja4 HAVING COUNT_IF(hit) > 0
  ORDER BY flagged DESC LIMIT 15
),
claim AS (
  SELECT ja4, br || ' ' || mj AS claim FROM s WHERE hit AND ja4 IN (SELECT ja4 FROM top)
  GROUP BY ja4, br, mj QUALIFY ROW_NUMBER() OVER (PARTITION BY ja4 ORDER BY COUNT(*) DESC) = 1
),
asn AS (
  SELECT ja4, asn, COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY ja4) AS sh FROM s WHERE hit AND ja4 IN (SELECT ja4 FROM top)
  GROUP BY ja4, asn QUALIFY ROW_NUMBER() OVER (PARTITION BY ja4 ORDER BY COUNT(*) DESC) = 1
),
cc AS (
  SELECT ja4, cc FROM s WHERE hit AND ja4 IN (SELECT ja4 FROM top)
  GROUP BY ja4, cc QUALIFY ROW_NUMBER() OVER (PARTITION BY ja4 ORDER BY COUNT(*) DESC) = 1
),
fam_raw AS (
  SELECT CDN__JA4_HASH_AT_SESSION_CREATED AS ja4, COALESCE(BROWSER_NAME_AT_SESSION_CREATED, '?') AS br,
         SPLIT_PART(BROWSER_VERSION_AT_SESSION_CREATED, '.', 1) AS mj
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE SESSION_TS >= '{fam_from}' AND SESSION_TS < '{fam_to}' AND PUBLIC_KEY_CATEGORY = 'Production'
    AND CDN__JA4_HASH_AT_SESSION_CREATED IN (SELECT ja4 FROM top)
),
fam_b AS (
  SELECT ja4, CASE WHEN br ILIKE '%ios%' OR br ILIKE '%safari%' THEN 'webkit'
                   WHEN br ILIKE '%firefox%' THEN 'firefox'
                   WHEN br ILIKE ANY ('%chrom%', '%edge%', '%opera%', '%samsung%', '%brave%', '%yandex%', '%vivaldi%') THEN 'chromium'
                   ELSE br END AS br,
         COUNT(*) AS n
  FROM fam_raw GROUP BY 1, 2
),
fam_m AS (SELECT ja4, COUNT(DISTINCT mj) AS majors FROM fam_raw GROUP BY 1),
fam AS (
  SELECT b.ja4, MAX_BY(b.br, b.n) AS fam_browser, MAX(b.n) / SUM(b.n) AS fam_share, m.majors AS fam_majors, SUM(b.n) AS fam_n
  FROM fam_b b JOIN fam_m m ON m.ja4 = b.ja4 GROUP BY b.ja4, m.majors
)
SELECT LISTAGG(t.ja4 || '|' || c.claim || '|' || t.claims_n || '|' || t.flagged || '|' || t.flag_ver || '|' || t.unflagged || '|' || t.ch_mismatch
               || '|' || COALESCE(a.asn, '?') || '|' || ROUND(a.sh, 3) || '|' || COALESCE(x.cc, '?')
               || '|' || COALESCE(f.fam_browser, '-') || '|' || COALESCE(ROUND(f.fam_share, 3)::TEXT, '0') || '|' || COALESCE(f.fam_majors, 0) || '|' || COALESCE(f.fam_n, 0), ';')
       WITHIN GROUP (ORDER BY t.flagged DESC) AS packed
FROM top t JOIN claim c ON c.ja4 = t.ja4 LEFT JOIN asn a ON a.ja4 = t.ja4 LEFT JOIN cc x ON x.ja4 = t.ja4 LEFT JOIN fam f ON f.ja4 = t.ja4
