-- Athena (database_id 2). Score TD labels for one session-create day against the Snowflake export of fired sessions (13_final_export.sql
-- or the export query in 17_). A label not in the export = not fired under any rule.
-- {KEY}; {D0}/{D1} session-create day; {LEGIT} = label filter: Blizzard "is_legit='Nonlegit' AND is_verified=1"; Figma: none (both labels).
-- {GROUPS} = VALUES (mask, 'id,id,...'), ...; id = first 7 digits + last digit of the 10-digit suffix after '.'.
-- Bits: 1 today ST | 2 today LT | 4 ST m5 f11 | 8 ST m5 f8 | 16 ST m10 f8 | 32 ST m5 f5 | 64 ST m10 f11 | 128 LT m5 f11 | 256 LT m5 f8.
-- Output per label value (lv): labels, matched rows, matched labels, then caught counts: tST, tLT, tANY, m5f11, m5f8, m10f8, m5f5, m10f11,
--   LTm5f11, LTm5f8, COMBm5f11 (ST or LT), COMBm5f8, and new-only vs today ST: n_m5f11, n_m5f8, n_m10f8, n_m5f5; lost vs today ST: l_m5f11, l_m5f8.
WITH f(mask, ids) AS ({GROUPS}),
fx AS (SELECT mask, id FROM f CROSS JOIN UNNEST(split(ids, ',')) AS t(id)),
lab AS (SELECT split_part(arkose_session_id,'.',2) s, max(is_legit) lv FROM starfleet_production.truth_data_history
  WHERE public_key='{KEY}' AND year=2026 AND month=11 AND day BETWEEN {PD0} AND 26 AND {LEGIT}
  AND session_create_timestamp >= timestamp '{D0} 00:00:00' AND session_create_timestamp < timestamp '{D1} 00:00:00' GROUP BY 1),
m AS (SELECT l.s, l.lv, fx.mask FROM lab l LEFT JOIN fx ON fx.id = substr(l.s,1,7)||substr(l.s,10,1)),
b AS (SELECT lv, s, mask, IF(mask IS NULL,0,1) mt, bitwise_and(coalesce(mask,0),1) st FROM m)
SELECT lv, count(DISTINCT s) labels, sum(mt) matched_rows, count(DISTINCT IF(mt=1,s)) matched_labels,
  sum(IF(bitwise_and(coalesce(mask,0),1)>0,1,0)) t_st, sum(IF(bitwise_and(coalesce(mask,0),2)>0,1,0)) t_lt, sum(IF(bitwise_and(coalesce(mask,0),3)>0,1,0)) t_any,
  sum(IF(bitwise_and(coalesce(mask,0),4)>0,1,0)) m5f11, sum(IF(bitwise_and(coalesce(mask,0),8)>0,1,0)) m5f8, sum(IF(bitwise_and(coalesce(mask,0),16)>0,1,0)) m10f8,
  sum(IF(bitwise_and(coalesce(mask,0),32)>0,1,0)) m5f5, sum(IF(bitwise_and(coalesce(mask,0),64)>0,1,0)) m10f11,
  sum(IF(bitwise_and(coalesce(mask,0),128)>0,1,0)) lt_m5f11, sum(IF(bitwise_and(coalesce(mask,0),256)>0,1,0)) lt_m5f8,
  sum(IF(bitwise_and(coalesce(mask,0),132)>0,1,0)) comb_m5f11, sum(IF(bitwise_and(coalesce(mask,0),264)>0,1,0)) comb_m5f8,
  sum(IF(bitwise_and(coalesce(mask,0),4)>0 AND st=0,1,0)) n_m5f11, sum(IF(bitwise_and(coalesce(mask,0),8)>0 AND st=0,1,0)) n_m5f8,
  sum(IF(bitwise_and(coalesce(mask,0),16)>0 AND st=0,1,0)) n_m10f8, sum(IF(bitwise_and(coalesce(mask,0),32)>0 AND st=0,1,0)) n_m5f5,
  sum(IF(bitwise_and(coalesce(mask,0),4)=0 AND st=1,1,0)) l_m5f11, sum(IF(bitwise_and(coalesce(mask,0),8)=0 AND st=1,1,0)) l_m5f8
FROM b GROUP BY lv ORDER BY lv
