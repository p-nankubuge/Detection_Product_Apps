-- Athena (database_id 2). Score ALL Blizzard Nonlegit verified TD labels for one session-create day against the Snowflake export of
-- verified sessions that fire under today / any grid point (07_). A label not in the export = not fired under any rule.
-- {GROUPS} = VALUES (mask, 'id,id,...'), ... as exported by 07_: id = first 8 digits of the 10-digit suffix + last digit (9 chars)
-- or first 7 digits + last digit (8 chars; used for the smaller groups and for 10-11 Nov). Labels are matched on the same
-- shortened key (false-match risk: about 5e-3 (9-char) to 0.1 (8-char) expected per day; duplicates reported).
-- Mask bits: 1 today ST, 2 today LT, 4/8/16/32 = (m 2/5/10/20, floor 5), 64/128/256/512 = (m 2/5/10/20, floor 11).
-- The IDs are not stored in this folder (they are re-creatable with 07_); the run outputs are in raw/08_*.txt.
WITH f(mask, ids) AS ({GROUPS}),
fx AS (SELECT mask, id FROM f CROSS JOIN UNNEST(split(ids, ',')) AS t(id)),
lab AS (SELECT DISTINCT split_part(arkose_session_id,'.',2) s FROM starfleet_production.truth_data_history
  WHERE public_key='E8A75615-1CBA-5DFF-8032-D16BCF234E10' AND year=2026 AND month=11 AND day BETWEEN 9 AND 26
  AND is_legit='Nonlegit' AND is_verified=1
  AND session_create_timestamp >= timestamp '{D0} 00:00:00' AND session_create_timestamp < timestamp '{D1} 00:00:00'),
m AS (SELECT l.s, fx.mask FROM lab l JOIN fx ON fx.id = IF(length(fx.id)=9, substr(l.s,1,8)||substr(l.s,10,1), substr(l.s,1,7)||substr(l.s,10,1)))
SELECT (SELECT count(*) FROM lab) labels, count(*) matched_rows, count(DISTINCT s) matched_labels,
  sum(IF(bitwise_and(mask,1)>0,1,0)) t_st, sum(IF(bitwise_and(mask,3)>0,1,0)) t_any,
  sum(IF(bitwise_and(mask,4)>0,1,0)) g1, sum(IF(bitwise_and(mask,8)>0,1,0)) g2, sum(IF(bitwise_and(mask,16)>0,1,0)) g3, sum(IF(bitwise_and(mask,32)>0,1,0)) g4,
  sum(IF(bitwise_and(mask,64)>0,1,0)) g5, sum(IF(bitwise_and(mask,128)>0,1,0)) g6, sum(IF(bitwise_and(mask,256)>0,1,0)) g7, sum(IF(bitwise_and(mask,512)>0,1,0)) g8,
  -- new-only vs today ST (n*) and vs today ST or LT (a*)
  sum(IF(bitwise_and(mask,4)>0 AND bitwise_and(mask,1)=0,1,0)) n1, sum(IF(bitwise_and(mask,8)>0 AND bitwise_and(mask,1)=0,1,0)) n2,
  sum(IF(bitwise_and(mask,16)>0 AND bitwise_and(mask,1)=0,1,0)) n3, sum(IF(bitwise_and(mask,32)>0 AND bitwise_and(mask,1)=0,1,0)) n4,
  sum(IF(bitwise_and(mask,64)>0 AND bitwise_and(mask,1)=0,1,0)) n5, sum(IF(bitwise_and(mask,128)>0 AND bitwise_and(mask,1)=0,1,0)) n6,
  sum(IF(bitwise_and(mask,256)>0 AND bitwise_and(mask,1)=0,1,0)) n7, sum(IF(bitwise_and(mask,512)>0 AND bitwise_and(mask,1)=0,1,0)) n8,
  sum(IF(bitwise_and(mask,4)>0 AND bitwise_and(mask,3)=0,1,0)) a1, sum(IF(bitwise_and(mask,64)>0 AND bitwise_and(mask,3)=0,1,0)) a5
FROM m;
