-- Global cells, run 2026-11-25 (Snowflake, database_id 14; 9 s and 7 s).
-- Sample: sessions created 2026-11-19 00:00-24:00 UTC (Thursday, inside the base period), ALL keys except the synthetics key
-- and the 13 single-JA4 (proxy) keys of 02_proxy_keys_19nov.sql. 1-in-16 deterministic sample BY SIGNATURE:
-- MOD(ABS(HASH(public_key, di_matched_signature_at_session_created)), 16) = 0. Sampling by session (HASH(session)) would cut
-- every signature-window's count to ~1/16 and bias p99 down, so whole signatures are kept or dropped instead.
-- Sampled: 5,497,002 sessions, 342 keys, 325,324 key x signature pairs.
-- Signature-window = key x matched signature x platform group x fixed 40-min bucket (signatures are per key).
-- Same session CTE as _session_cte.sql (List A/B/C skipped; PROXY = FALSE because proxy keys are excluded).
WITH s0 AS (SELECT public_key k, session_ts ts, di_dictionary_num_matched_at_session_created d,
    di_matched_signature_at_session_created ms, os_at_session_created os, COALESCE(webgl_unmasked_renderer_at_session_created,'') r,
    COALESCE(cdn__ja4_hash_at_session_created,'') ja4, COALESCE(ua_at_session_created,'') ua, IFF(latest_risk_band='High',1,0) hi
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE session_last_timestamp>='2026-11-19' AND session_last_timestamp<'2026-11-20 06:00'
    AND session_ts>='2026-11-19' AND session_ts<'2026-11-20' AND ms IS NOT NULL
    AND MOD(ABS(HASH(public_key, di_matched_signature_at_session_created)),16)=0
    AND public_key NOT IN ('2EAD3543-36DC-4A77-90E1-F3AE6B16CF16',
      'EE844FC3-499D-4A4D-A643-D7400F0FD4DE','E3EFEFBF-8DE4-42ED-9E7F-92F35B1FD3CF','7CC24C4A-611B-41C7-9808-B95722C7861C',
      '08E79816-973D-4A37-9982-14F296D3C65E','17B8681B-5BD5-4850-AC7E-50C58D6D95C0','75F2F4FE-87CB-4626-B36B-7754FBE3F9E6',
      '7AF91771-1D6C-44B0-8606-0187DF352B42','BE8E67A7-D570-4317-8017-E6F3EB022300','D550001E-0EC5-4EE5-8D53-3161298D1DFA',
      '282E022B-7C4D-4F83-8ABF-E8870003717B','B34FF33B-F8BD-4FE7-9F09-14F37F4FB804','3DB1BCB3-D1E8-4AA2-9270-B3F0121483A9',
      'E1991FB8-1F98-4291-B4C2-FE9AA0B53C38')),
s1 AS ( /* x and grp exactly as in _session_cte.sql with PROXY = FALSE */
  SELECT s0.*,
    CASE WHEN r ILIKE '%SwiftShader%' OR r ILIKE '%llvmpipe%' OR r ILIKE '%VirtualBox%' OR r ILIKE '%VMware%' THEN 'A'
         WHEN r ILIKE '%Basic Render Driver%' AND COALESCE(os,'')<>'Windows' THEN 'B' WHEN COALESCE(os,'') IN ('','--') AND r<>'' THEN 'B'
         WHEN ja4 LIKE 't%' AND SPLIT_PART(ja4,'_',2) IN ('a09f3c656075','2802a3db6c62') AND os IN ('Windows','GNU/Linux','Ubuntu','Chrome OS') THEN 'C'
         WHEN ua LIKE '%Chrome/%' AND RIGHT(SPLIT_PART(ja4,'_',1),2)='h1' THEN 'C'
         WHEN TRY_TO_NUMBER(REGEXP_SUBSTR(ua,'Chrome/([0-9]+)',1,1,'e',1))>=70 AND ja4 LIKE 't12%' THEN 'C' END AS x,
    CASE WHEN r ILIKE '%Basic Render Driver%' AND os='Windows' THEN 'WinRDVM' WHEN os IN ('Windows','OS X','Chrome OS') THEN 'Desktop'
         WHEN os IN ('iOS','iPadOS','Android') THEN 'Mobile' WHEN os IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'Other' END AS grp
  FROM s0),
w AS (SELECT k, d, grp, ms, TIME_SLICE(ts,40,'MINUTE') t, COUNT(*) n, SUM(hi) h FROM s1 WHERE x IS NULL GROUP BY 1,2,3,4,5)
-- (a) per dict x group
SELECT d||'|'||grp||'|'||COUNT(*)||'|'||COUNT_IF(h/n<0.2)||'|'||SUM(IFF(h/n<0.2,n,0))||'|'||SUM(n)||'|'||COUNT(DISTINCT k)
  ||'|'||COALESCE(ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY IFF(h/n<0.2,n,NULL)),1)::STRING,'-')
  ||'|'||COALESCE(ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY IFF(h/n<0.2,n,NULL)),1)::STRING,'-')
  ||'|'||COALESCE(MAX(IFF(h/n<0.2,n,NULL))::STRING,'-')||'|'||ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY n),1)||'|'||ROUND(SUM(h)/SUM(n),4) r
FROM w GROUP BY d,grp
UNION ALL SELECT d||'|SKIP_'||x||'|'||COUNT(*)||'|hi='||ROUND(AVG(hi),4) FROM s1 WHERE x IS NOT NULL GROUP BY d,x ORDER BY 1;
-- (b) second run, same CTEs, pooled fallbacks:
--   SELECT COALESCE(d::STRING,'ALL')||'|POOLED|'||COUNT(*)||'|'||COUNT_IF(h/n<0.2)||'|'||SUM(IFF(h/n<0.2,n,0))||'|'||COUNT(DISTINCT k)
--     ||'|'||ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY IFF(h/n<0.2,n,NULL)),1) FROM w GROUP BY GROUPING SETS ((d),())
--   UNION ALL SELECT 'D-1+1|POOLED|'||... FROM w WHERE d IN (-1,1)
--   UNION ALL SELECT 'TOTSESS|'||COUNT(*)||'|keys='||COUNT(DISTINCT k)||'|sigs='||COUNT(DISTINCT k,ms) FROM s1 ORDER BY 1;
--
-- Result (a): d|grp|sigwin_all|sigwin_clean|sess_clean|sess_all|keys|p99_clean|p95_clean|max_clean|p99_all|high_rate
-- -1|Desktop|108|77|1175|2578|7|143.0|104.4|143|141.6|0.2676   -1|Linux|1|0|0|1|1|-|-|-|1.0|1.0
-- -1|Mobile|77|37|78|218|6|9.1|4.0|12|13.7|0.3716             -1|Other|73|31|71|316|5|6.0|5.5|6|14.3|0.5538
--  1|Desktop|637|496|2630|3973|64|79.3|16.3|102|93.6|0.2819     1|Linux|132|91|312|7120|14|19.2|10.5|21|366.5|0.9046
--  1|Mobile|1226|807|2060|3025|76|15.9|9.0|26|14.8|0.2820       1|Other|69|50|139|327|17|30.6|7.2|38|57.5|0.5749
--  1|WinRDVM|63|47|137|169|6|10.5|7.0|11|10.4|0.1420
--  3|Desktop|16292|14963|133582|177683|181|104.0|26.0|1339|139.3|0.2026  3|Linux|1631|1440|3599|5885|107|16.6|8.0|29|24.7|0.3398
--  3|Mobile|10343|8387|22384|44272|148|21.0|10.0|119|39.6|0.4225       3|Other|288|163|340|2091|31|11.4|5.9|12|46.1|0.8187
--  3|WinRDVM|1356|1182|2935|5157|96|16.4|7.0|65|69.1|0.3591
--  7|Desktop|104490|98250|325633|530150|226|29.0|8.0|1611|40.0|0.3547  7|Linux|3075|2660|8896|18303|99|30.8|5.0|512|101.3|0.2693
--  7|Mobile|18299|14051|20978|38988|165|7.0|3.0|35|13.0|0.3778         7|Other|97|96|184|186|23|10.2|6.0|14|10.2|0.0054
--  7|WinRDVM|7393|6711|12021|26315|131|10.0|5.0|86|18.0|0.5058
-- 15|Desktop|93407|87012|171404|209892|195|13.0|5.0|137|14.0|0.1669  15|Linux|1607|1489|3173|5910|91|10.1|4.0|251|20.9|0.2411
-- 15|Mobile|89659|87042|228773|238883|195|21.0|8.0|106|21.0|0.0326   15|Other|291|259|415|456|34|6.4|4.0|9|6.1|0.0899
-- 15|WinRDVM|5110|4249|6457|8141|120|7.0|3.6|20|7.0|0.2017
-- 31|Desktop|149207|143574|390253|405921|201|27.0|8.0|182|26.0|0.0348 31|Linux|1615|1450|5745|20532|84|66.5|11.0|266|306.6|0.3524
-- 31|Mobile|14451|13592|28951|30584|147|18.0|6.0|51|17.0|0.0502      31|Other|33|33|50|50|7|7.1|2.4|9|7.1|0.0
-- 31|WinRDVM|7559|7083|10692|11685|128|7.0|4.0|26|7.0|0.0784
-- 63|Desktop|347720|339086|872566|902438|217|20.0|7.0|412|21.0|0.0262  63|Linux|3413|3084|9703|11971|93|13.0|6.0|332|29.9|0.1883
-- 63|Mobile|259719|255490|2500383|2519782|220|72.0|14.0|19659|72.0|0.0058  63|Other|565|535|1334|1493|60|16.7|7.0|29|18.1|0.0985
-- 63|WinRDVM|13519|12916|32378|34573|141|20.0|8.0|50|21.0|0.0466
-- Skipped (sampled sessions): A 179,029 (d3 110,792 at 94.7% High); B 2,444; C 46,461.
-- Result (b): pooled p99_clean (clean sig-windows): d-1 134.2 (145); d1 35.3 (1,491); d3 68.0 (26,135); d7 25.0 (121,768);
--   d15 17.0 (180,051); d31 26.0 (165,732); d63 37.0 (611,111); all 30.0 (1,106,433); d-1 and d1 together 68.7 (1,636).
