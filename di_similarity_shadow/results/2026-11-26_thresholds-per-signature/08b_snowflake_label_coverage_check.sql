-- Coverage check: are TD label sessions present (and verified) in PROD_INT_SESSION_SUMMARY? 20 suffixes from the '04' label chunk.
-- Result: 20 rows, 20 distinct, 20 verified, session_ts 10 Nov 12:16 - 11 Nov 12:10.
SELECT COUNT(*) n, COUNT(DISTINCT RIGHT(session,10)) d, COUNT_IF(sessions_verified>0) ver, MIN(session_ts) mn, MAX(session_ts) mx
FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY WHERE public_key='E8A75615-1CBA-5DFF-8032-D16BCF234E10'
AND session_last_timestamp>='2026-11-09' AND session_last_timestamp<'2026-11-12 06:00' AND session_ts>='2026-11-09' AND session_ts<'2026-11-12'
AND RIGHT(session,10) IN ('7963158004','8729157604','1013331504','1157445704','9189131904','2155004604','3343640004','4931115004','0243327704','2125782004',
'2045784904','1187634804','1539720404','5672567704','9321889504','0490300604','6403130804','6018909904','0217926004','9493679104');
