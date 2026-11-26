-- Q4: Chrome major version mix by day on Figma Registration K2 (desktop OSes), 30 Oct - 6 Nov 2026: all sessions and Dict 63 only
-- (Chrome 154-169 UAs, cells >= 200 sessions). Purpose: check whether trigger a (coarse UA x device_params never seen) coincides with a
-- Chrome major version that was new in the whitelist window. Output: day|Chrome major|sessions|Dict 63 sessions.
EXECUTE IMMEDIATE $$SELECT d||'|'||m||'|'||n||'|'||n63 AS r FROM (SELECT TO_CHAR(DATE_TRUNC('day', session_ts),'MM-DD') AS d,
  REGEXP_SUBSTR(ua_at_session_created,'Chrome/([0-9]+)',1,1,'e',1) AS m, COUNT(*) AS n,
  COUNT_IF(di_dictionary_num_matched_at_session_created = 63) AS n63
FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
  AND session_last_timestamp >= '2026-10-30 00:00:00' AND session_last_timestamp < '2026-11-07 06:00:00'
  AND session_ts >= '2026-10-30 00:00:00' AND session_ts < '2026-11-07 00:00:00'
  AND os_at_session_created IN ('Windows','OS X','Chrome OS','GNU/Linux','Ubuntu')
  AND ua_at_session_created RLIKE '.*Chrome/(15[4-9]|16[0-9])[.].*'
GROUP BY 1, 2 HAVING COUNT(*) >= 200) ORDER BY 1$$
