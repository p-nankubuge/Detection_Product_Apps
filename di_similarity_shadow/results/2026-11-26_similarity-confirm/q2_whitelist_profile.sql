-- Q2: whitelist profile for the confirm run (no sessions scored). Whitelist = Dict 63 sessions created 2026-10-30 00:00 to 2026-11-06 00:00 UTC
-- on Figma Registration Production K2 (A207F8A1-...) and Login Production 1 (955D26AF-...). Output: per key sessions / distinct signatures;
-- per platform group sessions / signatures; per OS line the most common OS version, its share (>= 90% = frozen, check skipped) and the
-- number of distinct versions. Platform group and OS line rules as in _core_template_v4.sql.
WITH w AS (
  SELECT public_key, di_highest_signature_at_session_created AS h
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key IN ('A207F8A1-ED09-4325-ACE6-C8E26A458FBA','955D26AF-E956-4106-A4EF-2F63304776D9')
    AND session_last_timestamp >= '2026-10-30 00:00:00' AND session_last_timestamp < '2026-11-06 06:00:00'
    AND session_ts >= '2026-10-30 00:00:00' AND session_ts < '2026-11-06 00:00:00'
    AND di_dictionary_num_matched_at_session_created = 63
), p AS (
  SELECT public_key, h, SPLIT_PART(SPLIT_PART(h,'||',1),'::',1) AS osf, SPLIT_PART(SPLIT_PART(h,'||',1),'::',2) AS osv,
    SPLIT_PART(h,'||',6) AS gl FROM w
), q AS (
  SELECT p.*, (gl ILIKE '%SwiftShader%' OR gl ILIKE '%llvmpipe%' OR gl ILIKE '%VirtualBox%' OR gl ILIKE '%VMware%') AS soft,
    CASE WHEN soft THEN 'Other' WHEN gl ILIKE '%Basic Render Driver%' THEN IFF(osf = 'Windows','Windows RD/VM','Other')
         WHEN osf IN ('Windows','OS X','Chrome OS') THEN 'Desktop' WHEN osf IN ('iOS','iPadOS','Android') THEN 'Mobile'
         WHEN osf IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'Other' END AS pg,
    CASE WHEN osf IN ('iOS','iPadOS') THEN 'iOS+iPadOS' WHEN osf IN ('GNU/Linux','Ubuntu') THEN 'Linux'
         WHEN osf IN ('Android','Windows','OS X','Chrome OS') THEN osf END AS line
  FROM p
), lv AS (SELECT line, osv, COUNT(*) AS n FROM q WHERE line IS NOT NULL GROUP BY 1, 2)
SELECT 'KEY|'||public_key||'|'||COUNT(*)||'|'||COUNT(DISTINCT h) AS r FROM q GROUP BY public_key
UNION ALL SELECT 'PG|'||pg||'|'||COUNT(*)||'|'||COUNT(DISTINCT h) FROM q GROUP BY pg
UNION ALL SELECT 'OSV|'||line||'|'||MAX_BY(osv, n)||'|'||ROUND(MAX(n)/SUM(n),3)||'|'||COUNT(*)||'|'||SUM(n) FROM lv GROUP BY line
ORDER BY r
