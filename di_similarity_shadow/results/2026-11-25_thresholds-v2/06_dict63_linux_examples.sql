-- Dict 63 Linux fires on 20 Nov (Figma K2): 20 example sessions + a summary of all fires. Run 2026-11-25, Snowflake (database_id 14).
-- Fire = non-List-A/B/C, dict 63, group Linux (OS GNU/Linux or Ubuntu, renderer not Basic Render), DI ST count > 6 (v1 = v2 threshold).
-- Fields from PROD_INT_SESSION_SUMMARY; screen = 3rd '||' part and device_params = 4th '||' part of DI_HIGHEST_SIGNATURE_AT_SESSION_CREATED;
-- ASN / vpn_proxy_description / vpn_proxy_type from vw_events (session_setup, same key, 20 Nov), first row per session.
-- sig = left 10 of MD5(DI_MATCHED_SIGNATURE_AT_SESSION_CREATED) (full signature is long; the parts are shown separately).
WITH s AS (SELECT session, session_ts ts, os_at_session_created os, os_version_at_session_created osv, cdn__ja4_hash_at_session_created ja4,
    ua_at_session_created ua, COALESCE(webgl_unmasked_renderer_at_session_created,'') r, user_ip_at_session_created ip,
    SPLIT_PART(di_highest_signature_at_session_created,'||',3) scr, SPLIT_PART(di_highest_signature_at_session_created,'||',4) dp,
    LEFT(MD5(di_matched_signature_at_session_created),10) sig, di_short_term_count_at_session_created stc, di_long_term_count_at_session_created ltc,
    IFF(di_short_term_threshold_breached_at_session_created,1,0) stb, latest_risk_band rb, IFF(sessions_verified>0,1,0) ver,
    IFF(was_challenged>0,1,0) chl, COALESCE(sessions_solved,0) sol
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key='A207F8A1-ED09-4325-ACE6-C8E26A458FBA' AND session_last_timestamp>='2026-11-20' AND session_last_timestamp<'2026-11-21 06:00'
    AND session_ts>='2026-11-20' AND session_ts<'2026-11-21' AND di_dictionary_num_matched_at_session_created=63
    AND os_at_session_created IN ('GNU/Linux','Ubuntu') AND di_short_term_count_at_session_created>6),
f AS (SELECT * FROM s WHERE NOT (r ILIKE '%SwiftShader%' OR r ILIKE '%llvmpipe%' OR r ILIKE '%VirtualBox%' OR r ILIKE '%VMware%' OR r ILIKE '%Basic Render Driver%')
    AND NOT (COALESCE(ja4,'') LIKE 't%' AND SPLIT_PART(ja4,'_',2) IN ('a09f3c656075','2802a3db6c62'))
    AND NOT (COALESCE(ua,'') LIKE '%Chrome/%' AND RIGHT(SPLIT_PART(COALESCE(ja4,''),'_',1),2)='h1')
    AND NOT (TRY_TO_NUMBER(REGEXP_SUBSTR(COALESCE(ua,''),'Chrome/([0-9]+)',1,1,'e',1))>=70 AND COALESCE(ja4,'') LIKE 't12%')),
e AS (SELECT session, ANY_VALUE(asn) asn, ANY_VALUE(vpn_proxy_description) vpd, ANY_VALUE(vpn_proxy_type) vpt
  FROM ARK_PROD.events.vw_events WHERE public_key='A207F8A1-ED09-4325-ACE6-C8E26A458FBA' AND location='session_setup'
    AND timestamp>='2026-11-20' AND timestamp<'2026-11-21 01:00' AND session IN (SELECT session FROM f) GROUP BY session)
SELECT 'EX|'||TO_CHAR(ts,'HH24:MI:SS')||'|'||sig||'|stc='||stc||'/6|ltc='||ltc||'|todayST='||stb||'|'||COALESCE(rb,'-')||'|ver='||ver||'|chl='||chl||'|sol='||sol
  ||'|'||COALESCE(os,'')||' '||COALESCE(osv,'')||'|'||COALESCE(ja4,'')||'|'||COALESCE(scr,'')||'|'||COALESCE(dp,'')||'|'||r
  ||'|'||COALESCE(ip,'')||'|asn='||COALESCE(e.asn::STRING,'-')||'|vpn='||COALESCE(vpd,'-')||'/'||COALESCE(vpt,'-')||'|'||COALESCE(ua,'') x
FROM f LEFT JOIN e USING (session) QUALIFY ROW_NUMBER() OVER (ORDER BY ts)<=20
UNION ALL
SELECT 'SUM|fires='||COUNT(*)||'|sigs='||COUNT(DISTINCT sig)||'|ips='||COUNT(DISTINCT ip)||'|ip24='||COUNT(DISTINCT REGEXP_SUBSTR(ip,'^[0-9]+\\.[0-9]+\\.[0-9]+'))
  ||'|asns='||COUNT(DISTINCT e.asn)||'|uas='||COUNT(DISTINCT ua)||'|ja4s='||COUNT(DISTINCT ja4)||'|scr='||COUNT(DISTINCT scr)||'|dp='||COUNT(DISTINCT dp)
  ||'|r='||COUNT(DISTINCT r)||'|first='||TO_CHAR(MIN(ts),'HH24:MI')||'|last='||TO_CHAR(MAX(ts),'HH24:MI')||'|high='||COUNT_IF(rb='High')||'|ver='||SUM(ver)
  ||'|chl='||SUM(chl)||'|stc_max='||MAX(stc)||'|vpn_any='||COUNT_IF(vpd IS NOT NULL AND vpd<>'') x
FROM f LEFT JOIN e USING (session)
UNION ALL
SELECT 'SIG|'||sig||'|n='||COUNT(*)||'|ips='||COUNT(DISTINCT ip)||'|'||TO_CHAR(MIN(ts),'HH24:MI')||'-'||TO_CHAR(MAX(ts),'HH24:MI')||'|stc_max='||MAX(stc) x FROM f GROUP BY sig
ORDER BY 1;
-- Run 2026-11-25, 10.9 s, no sampling. Result:
--   SUM: fires 25 | 1 matched signature (cd17e5f3fc) | 4 IPs, all in 185.197.91.0/24 (.129, .162, .176, .178) | 1 ASN (34285) | 1 UA | 1 JA4
--        | 1 screen | 1 device_params | 1 renderer | 09:42-13:32 UTC | High 0 (all Medium) | verified 23 | challenged 25 | ST count max 24
--        | vpn_proxy_description empty ('') on all 25
--   Every one of the 20 example rows has: OS 'GNU/Linux' (version empty) | JA4 t13d1517h2_8daaf6152771_3cbfd9057e0d | screen 1920,1080::1920,1080
--     | device_params Linux x86_64::0::1::24::8::1::1::0::1::0::0::0::476A6 | renderer 'Intel(R) HD Graphics, or similar'
--     | UA Mozilla/5.0 (X11; Linux x86_64; rv:156.0) Gecko/20100101 Firefox/156.0 | ASN 34285 | vpn '' / ''
--   Rows (time | ST count vs v1/v2 threshold 6 | LT count | today ST breached | risk | verified | IP):
--     09:42:29 7 | 7 | 0 | Medium | 1 | .178     09:46:38 8 | 8 | 0 | Medium | 1 | .162     09:58:00 9 | 9 | 0 | Medium | 1 | .176
--     10:00:21 10 | 10 | 0 | Medium | 1 | .162   10:05:58 11 | 11 | 0 | Medium | 1 | .178   10:06:02 12 | 12 | 1 | Medium | 1 | .178
--     13:10:18 7 | 19 | 0 | Medium | 1 | .129    13:10:20 8 | 20 | 0 | Medium | 1 | .178    13:10:29 9 | 21 | 0 | Medium | 1 | .178
--     13:10:39 10 | 22 | 0 | Medium | 1 | .162   13:11:35 11 | 23 | 0 | Medium | 1 | .178   13:11:36 11 | 23 | 0 | Medium | 1 | .162
--     13:11:52 12 | 24 | 1 | Medium | 1 | .162   13:13:06 13 | 25 | 1 | Medium | 1 | .176   13:14:01 14 | 26 | 1 | Medium | 1 | .178
--     13:14:34 15 | 27 | 1 | Medium | 1 | .162   13:17:58 16 | 28 | 1 | Medium | 1 | .178   13:18:13 17 | 29 | 1 | Medium | 1 | .129
--     13:20:16 18 | 30 | 1 | Medium | 0 (challenged, not solved) | .178   13:20:29 19 | 31 | 1 | Medium | 1 | .176
