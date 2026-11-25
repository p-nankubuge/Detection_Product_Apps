-- Layer 1 v3, Q0: whitelist scope per key (D-12) and profile of empty / unparsed field values (item 9).
-- Whitelist = Dict 63 sessions created 2026-11-13 00:00 to 2026-11-20 00:00 UTC on the Figma account (23454) production keys:
--   A207F8A1-ED09-4325-ACE6-C8E26A458FBA (Registration Production K2), 955D26AF-E956-4106-A4EF-2F63304776D9 (Login Production 1).
-- Window = Registration K2 sessions created 2026-11-20 12:00-14:00 UTC (all, no sampling).
WITH x AS (
  SELECT public_key AS k, IFF(session_ts >= '2026-11-20 12:00:00','win','wl') AS src,
         di_dictionary_num_matched_at_session_created AS d, di_highest_signature_at_session_created AS h
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key IN ('A207F8A1-ED09-4325-ACE6-C8E26A458FBA','955D26AF-E956-4106-A4EF-2F63304776D9')
    AND session_last_timestamp >= '2026-11-13 00:00:00' AND session_last_timestamp < '2026-11-21 00:00:00'
    AND ((session_ts >= '2026-11-13 00:00:00' AND session_ts < '2026-11-20 00:00:00')
      OR (session_ts >= '2026-11-20 12:00:00' AND session_ts < '2026-11-20 14:00:00'
          AND public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'))
), y AS (
  SELECT k, src, d, h, SPLIT_PART(SPLIT_PART(h,'||',1),'::',1) AS osf, SPLIT_PART(h,'||',2) AS ja4, SPLIT_PART(h,'||',3) AS scr,
    SPLIT_PART(SPLIT_PART(h,'||',3),'::',2) AS sp, SPLIT_PART(h,'||',4) AS dp, SPLIT_PART(h,'||',5) AS ua, SPLIT_PART(h,'||',6) AS gl
  FROM x WHERE src = 'win' OR d = 63
)
SELECT src||'|'||k||'|'||COUNT(*)||'|sigs='||COUNT(DISTINCT h)||'|ja4empty='||COUNT_IF(ja4='')||'|scrempty='||COUNT_IF(scr='')
  ||'|sp_unparsed='||COUNT_IF(NOT sp RLIKE '[0-9]+,[0-9]+')||'|sp_zero='||COUNT_IF(sp RLIKE '0,0')||'|dpempty='||COUNT_IF(dp='')
  ||'|uaempty='||COUNT_IF(ua='')||'|glempty='||COUNT_IF(gl='' OR gl RLIKE '[:]*')||'|osempty='||COUNT_IF(osf IN ('','--'))
  ||'|sp_distinct='||COUNT(DISTINCT sp)||'|scr_distinct='||COUNT(DISTINCT scr) AS r
FROM y GROUP BY src, k
UNION ALL
SELECT 'SPX|'||src||'|'||scr||'|'||COUNT(*) FROM y WHERE NOT sp RLIKE '[0-9]+,[0-9]+' OR gl='' OR gl RLIKE '[:]*' GROUP BY src, scr
ORDER BY 1
