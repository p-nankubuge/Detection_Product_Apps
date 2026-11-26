-- Athena: distribution of the last 2 digits of the label session-ID suffix (not random: 01 2,467 / 02 799 / 03 26 / 04 758 / 05 1,668).
SELECT substr(split_part(arkose_session_id,'.',2),9,2) tail, count(*) n FROM starfleet_production.truth_data_history
WHERE public_key='E8A75615-1CBA-5DFF-8032-D16BCF234E10' AND year=2026 AND month=11 AND day BETWEEN 9 AND 26 AND is_legit='Nonlegit' AND is_verified=1
AND session_create_timestamp >= timestamp '2026-11-09 00:00:00' AND session_create_timestamp < timestamp '2026-11-12 00:00:00' GROUP BY 1 ORDER BY 1;
