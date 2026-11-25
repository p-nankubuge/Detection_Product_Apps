-- Whitelist profile queries run 2026-11-25 before scoring (Snowflake, database_id 14). Whitelist = Dict 63 sessions on
-- Figma Registration K2 created 2026-11-13 00:00 to 2026-11-20 00:00 UTC (uncleaned), same filter as the scoring queries.

-- (1) device_params positions: per OS family (Windows / OS X / Android / iOS / other), for each of the 13 '::' positions,
--     number of distinct values and the top 5 values with session counts. Used to choose the coarse key (p1, p4, p5, p10, p11).
WITH w AS (
  SELECT SPLIT_PART(SPLIT_PART(di_highest_signature_at_session_created,'||',1),'::',1) AS osf, SPLIT_PART(di_highest_signature_at_session_created,'||',4) AS dp
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND session_last_timestamp >= '2026-11-13 00:00:00' AND session_last_timestamp < '2026-11-20 06:00:00'
    AND session_ts >= '2026-11-13 00:00:00' AND session_ts < '2026-11-20 00:00:00'
    AND di_dictionary_num_matched_at_session_created = 63
), x AS (
  SELECT IFF(osf IN ('Windows','OS X','Android','iOS'), osf, 'other') AS o, pos.index+1 AS i, pos.value::STRING AS v, COUNT(*) AS n
  FROM w, LATERAL FLATTEN(SPLIT(dp,'::')) pos GROUP BY 1,2,3
)
SELECT o||' | p'||i||' | nd='||COUNT(*)||' | '||LISTAGG(v||':'||n, ', ') WITHIN GROUP (ORDER BY n DESC) AS r
FROM (SELECT x.*, ROW_NUMBER() OVER (PARTITION BY o,i ORDER BY n DESC) rn, COUNT(*) OVER (PARTITION BY o,i) c FROM x)
WHERE rn <= 5 GROUP BY o, i, c ORDER BY o, i;
-- Result summary (whitelist sessions): p1 platform (Win32 / MacIntel / iPhone / Linux armv81 / Linux x86_64 / iPad);
-- p2, p3, p6-p9, p12: 0/1 flags (p12 = 1 exactly where p11 = 1); p4: 24 / 30 / 32 (colour depth); p5: 2-56 (CPU cores);
-- p10: 0 / 1 / 2 / 5 / 10 (max touch points; 5 on iPhone, Android, and 4,503 'MacIntel' sessions = iPads in desktop mode);
-- p11: 0/1 touch flag; p13: 5-hex font hash (e.g. 7EC6D, 4D4F4, 786DE, 5CC1A).

-- (2) OS line version shares (frozen test input) and platform-group composition of the whitelist.
WITH w AS (
  SELECT SPLIT_PART(SPLIT_PART(h,'||',1),'::',1) AS osf, SPLIT_PART(SPLIT_PART(h,'||',1),'::',2) AS osv, SPLIT_PART(h,'||',6) AS gl
  FROM (SELECT di_highest_signature_at_session_created AS h FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND session_last_timestamp >= '2026-11-13 00:00:00' AND session_last_timestamp < '2026-11-20 06:00:00'
    AND session_ts >= '2026-11-13 00:00:00' AND session_ts < '2026-11-20 00:00:00'
    AND di_dictionary_num_matched_at_session_created = 63)
), g AS (
  SELECT w.*, CASE WHEN osf IN ('iOS','iPadOS') THEN 'iOS+iPadOS' WHEN osf='Android' THEN 'Android' WHEN osf='Windows' THEN 'Windows' WHEN osf='OS X' THEN 'macOS' WHEN osf='Chrome OS' THEN 'ChromeOS' WHEN osf IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'none:'||osf END AS line,
   CASE WHEN gl ILIKE '%SwiftShader%' OR gl ILIKE '%llvmpipe%' OR gl ILIKE '%VirtualBox%' OR gl ILIKE '%VMware%' THEN 'Other'
        WHEN gl ILIKE '%Basic Render Driver%' THEN IFF(osf='Windows','WinRDVM','Other')
        WHEN osf IN ('Windows','OS X','Chrome OS') THEN 'Desktop' WHEN osf IN ('iOS','iPadOS','Android') THEN 'Mobile'
        WHEN osf IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'Other' END AS pg
  FROM w
), v AS (SELECT line, osv, COUNT(*) n FROM g GROUP BY 1,2)
SELECT 'LINE | '||line||' | sessions='||SUM(n)||' | nver='||COUNT(*)||' | top: '||LISTAGG(IFF(rn<=4, osv||'='||ROUND(100*n/tot,1)||'%', NULL), ', ') WITHIN GROUP (ORDER BY n DESC) AS r
FROM (SELECT v.*, ROW_NUMBER() OVER (PARTITION BY line ORDER BY n DESC) rn, SUM(n) OVER (PARTITION BY line) tot FROM v) GROUP BY line
UNION ALL
SELECT 'PG | '||pg||' | '||osf||' | '||COUNT(*) FROM g GROUP BY pg, osf
ORDER BY 1;
-- Result:
-- LINE | Android    | 42,725 sessions | 10 versions | 10=99.3%, 16=0.3%, 17=0.1%, 15=0.1%
-- LINE | ChromeOS   |  4,978 |  1 | 14541.0.0=100%
-- LINE | Linux      |  3,112 |  1 | (empty)=100%
-- LINE | Windows    | 194,797 | 1 | 10=100%
-- LINE | iOS+iPadOS | 37,847 | 74 | 26.6.1=22.6%, 27.2=18.6%, 27.0.1=15.5%, 26.5.2=4.4%
-- LINE | macOS      | 80,550 | 19 | 10.15.7=68.3%, 26.6.2=6.6%, 27.2=6.3%, 27.0.1=3.8%
-- (no OS line: Fire OS 5, HarmonyOS 10, Meta Horizon 14, OpenHarmony 4 sessions)
-- PG | Desktop: Windows 186,707, OS X 80,547, Chrome OS 4,978 | Mobile: Android 42,725, iOS 34,337, iPadOS 3,510
-- PG | Linux: GNU/Linux 2,468, Ubuntu 374 | Windows RD/VM: Windows 8,032
-- PG | Other: GNU/Linux 270, Windows 58, Meta Horizon 14, HarmonyOS 10, Fire OS 5, OpenHarmony 4, OS X 3

-- (3) Check of Snowflake HASH on NULL (affects the unchanged v1 UA 1/2-credit code): SELECT HASH(NULL) = HASH(NULL) -> TRUE.
