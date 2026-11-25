-- Proxy-key detection for the global sample day (sessions created 2026-11-19 00:00-24:00 UTC, all keys, no sampling).
-- Rule (CLAUDE.md): one JA4 on >= 98% of a key's sessions over 24 h. Only keys with >= 500 sessions listed.
WITH kj AS (SELECT public_key k, cdn__ja4_hash_at_session_created j, COUNT(*) n
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE session_last_timestamp>='2026-11-19' AND session_last_timestamp<'2026-11-20 06:00'
    AND session_ts>='2026-11-19' AND session_ts<'2026-11-20' GROUP BY 1,2),
kk AS (SELECT k, SUM(n) tot, MAX(n) top, MAX_BY(j,n) topj, COUNT(*) nj FROM kj GROUP BY k)
SELECT 'TOTAL|'||SUM(tot)||'|keys='||COUNT(*) r FROM kk
UNION ALL SELECT k||'|'||tot||'|'||ROUND(top/tot,4)||'|'||COALESCE(topj,'NULL')||'|nj='||nj FROM kk WHERE top/tot>=0.98 AND tot>=500 ORDER BY 1;
-- Result: 84,229,999 sessions on 478 keys (3.7 s). Keys >= 98% one JA4 (>= 500 sessions):
--   Payoneer (known): EE844FC3 478,584 (99.60%), E3EFEFBF 70,481 (99.87%), 7CC24C4A 8,477 (100%), all t13d1311h1_a44d0ee8b3cc_485d6013ba69
--   Six keys with 1,735-1,737 sessions each, ~100% q13d0311h3_55b375c5d22e_5a1f323ef56d:
--     08E79816, 17B8681B, 75F2F4FE, 7AF91771, BE8E67A7, D550001E (identical volumes suggest monitoring/synthetic traffic; not checked)
--   282E022B 3,134 (98.15%) and B34FF33B 5,289 (99.43%): t13d200700_0cff601e1ce0_e74d7d97755c (no ALPN)
--   3DB1BCB3 679 (98.53%) and E1991FB8 782 (99.23%): t13d331000_c5da32f751cf_a29327ec888c (no ALPN)
--   NULL JA4 on 100%: 8A1EAD4C 623,889 and F75933C8 11,517 -> no JA4 at all, NOT treated as proxy keys (kept in the global sample).
-- All 13 non-NULL single-JA4 keys above are excluded from the global cells, plus the synthetics key 2EAD3543.
