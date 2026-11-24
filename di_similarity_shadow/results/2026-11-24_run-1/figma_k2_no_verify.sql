-- Figma Registration K2: what happened to sessions with no game_verify row
-- Window: sessions set up 2026-11-20 12:00-14:00 UTC; later events to 15:00; summary to 16:00
-- Sources: ARK_PROD.events.vw_events and ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY (Superset database_id 14). No sampling.

-- Query 1: which event locations exist on this key (vocabulary)
SELECT location, COUNT(*) AS event_rows, COUNT(DISTINCT session) AS sessions
FROM ARK_PROD.events.vw_events
WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
  AND timestamp >= '2026-11-20 12:00:00'
  AND timestamp <  '2026-11-20 15:00:00'
GROUP BY location
ORDER BY sessions DESC;

-- Query 2: stage groups inferred from event locations, by dictionary
WITH setup AS (
  SELECT session, MIN_BY(di_dictionary_num_matched, timestamp) AS dict
  FROM ARK_PROD.events.vw_events
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND location = 'session_setup'
    AND timestamp >= '2026-11-20 12:00:00' AND timestamp < '2026-11-20 14:00:00'
  GROUP BY session
),
stages AS (
  SELECT session,
         COUNT_IF(location = 'analytics_log') > 0 AS loaded,
         COUNT_IF(location = 'pow_setup') > 0     AS pow_served,
         COUNT_IF(location = 'game_setup') > 0    AS puzzle_served,
         COUNT_IF(location = 'check_answer') > 0  AS answered,
         COUNT_IF(location = 'game_verify') > 0   AS final_verify
  FROM ARK_PROD.events.vw_events
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND location <> 'session_setup'
    AND timestamp >= '2026-11-20 12:00:00' AND timestamp < '2026-11-20 15:00:00'
  GROUP BY session
),
grouped AS (
  SELECT s.dict,
         CASE
           WHEN t.final_verify AND t.puzzle_served THEN 'verified_after_puzzle'
           WHEN t.final_verify THEN 'verified_silent'
           WHEN t.puzzle_served AND t.answered THEN 'answered_not_finished'
           WHEN t.puzzle_served THEN 'puzzle_abandoned'
           WHEN t.pow_served AND NOT t.loaded THEN 'pow_only_no_widget'
           WHEN t.loaded THEN 'loaded_nothing_served'
           ELSE 'nothing_after_setup'
         END AS grp
  FROM setup s LEFT JOIN stages t ON t.session = s.session
)
SELECT dict,
       COUNT(*) AS sessions,
       COUNT_IF(grp = 'verified_silent') AS verified_silent,
       COUNT_IF(grp = 'verified_after_puzzle') AS verified_after_puzzle,
       COUNT_IF(grp NOT LIKE 'verified%') AS no_verify,
       COUNT_IF(grp = 'puzzle_abandoned') AS puzzle_abandoned,
       COUNT_IF(grp = 'answered_not_finished') AS answered_not_finished,
       COUNT_IF(grp = 'pow_only_no_widget') AS pow_only_no_widget,
       COUNT_IF(grp = 'loaded_nothing_served') AS loaded_nothing_served,
       COUNT_IF(grp = 'nothing_after_setup') AS nothing_after_setup,
       ROUND(100 * COUNT_IF(grp NOT LIKE 'verified%') / COUNT(*), 1) AS no_verify_pct,
       ROUND(100 * COUNT_IF(grp IN ('verified_after_puzzle','puzzle_abandoned','answered_not_finished')) / COUNT(*), 1) AS puzzle_served_pct,
       ROUND(100 * COUNT_IF(grp IN ('puzzle_abandoned','answered_not_finished')) / NULLIF(COUNT_IF(grp IN ('verified_after_puzzle','puzzle_abandoned','answered_not_finished')), 0), 1) AS puzzle_not_finished_pct
FROM grouped
GROUP BY dict
ORDER BY dict;

-- Query 3: summary-table columns about the session funnel
SELECT column_name, data_type
FROM ARK_PROD.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'STARFLEET' AND table_name = 'PROD_INT_SESSION_SUMMARY'
  AND (column_name ILIKE '%SUPPRESS%' OR column_name ILIKE '%SHOWN%' OR column_name ILIKE '%CHALLENGE%'
       OR column_name ILIKE '%GAME%' OR column_name ILIKE '%VERIF%' OR column_name ILIKE '%COMPLET%'
       OR column_name ILIKE '%ABANDON%' OR column_name ILIKE '%POW%' OR column_name ILIKE '%SOLVED%'
       OR column_name ILIKE '%LOADED%' OR column_name ILIKE '%DICTIONARY%')
ORDER BY column_name;

-- Query 4: cross-check event-based groups against summary flags
-- (same setup / stages / grouped CTEs as query 2, but keeping s.session instead of s.dict in grouped)
WITH setup AS (
  SELECT session, MIN_BY(di_dictionary_num_matched, timestamp) AS dict
  FROM ARK_PROD.events.vw_events
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND location = 'session_setup'
    AND timestamp >= '2026-11-20 12:00:00' AND timestamp < '2026-11-20 14:00:00'
  GROUP BY session
),
stages AS (
  SELECT session,
         COUNT_IF(location = 'analytics_log') > 0 AS loaded,
         COUNT_IF(location = 'pow_setup') > 0     AS pow_served,
         COUNT_IF(location = 'game_setup') > 0    AS puzzle_served,
         COUNT_IF(location = 'check_answer') > 0  AS answered,
         COUNT_IF(location = 'game_verify') > 0   AS final_verify
  FROM ARK_PROD.events.vw_events
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND location <> 'session_setup'
    AND timestamp >= '2026-11-20 12:00:00' AND timestamp < '2026-11-20 15:00:00'
  GROUP BY session
),
grouped AS (
  SELECT s.session,
         CASE
           WHEN t.final_verify AND t.puzzle_served THEN 'verified_after_puzzle'
           WHEN t.final_verify THEN 'verified_silent'
           WHEN t.puzzle_served AND t.answered THEN 'answered_not_finished'
           WHEN t.puzzle_served THEN 'puzzle_abandoned'
           WHEN t.pow_served AND NOT t.loaded THEN 'pow_only_no_widget'
           WHEN t.loaded THEN 'loaded_nothing_served'
           ELSE 'nothing_after_setup'
         END AS grp
  FROM setup s LEFT JOIN stages t ON t.session = s.session
),
summ AS (
  SELECT session, sessions_loaded, was_challenged, was_pow, sessions_pow_timeout,
         latest_pow__transparent, sessions_solved, sessions_verify_attempted, sessions_verified
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND session_last_timestamp >= '2026-11-20 12:00:00'
    AND session_last_timestamp <  '2026-11-20 16:00:00'
)
SELECT g.grp,
       COUNT(*) AS sessions,
       COUNT(m.session) AS in_summary,
       COUNT_IF(m.sessions_loaded > 0) AS loaded,
       COUNT_IF(m.was_challenged > 0) AS challenged,
       COUNT_IF(m.was_pow > 0) AS pow,
       COUNT_IF(m.latest_pow__transparent) AS pow_transparent,
       COUNT_IF(m.sessions_pow_timeout > 0) AS pow_timeout,
       COUNT_IF(m.sessions_solved > 0) AS solved,
       COUNT_IF(m.sessions_verify_attempted > 0) AS verify_attempted,
       COUNT_IF(m.sessions_verified > 0) AS verified
FROM grouped g LEFT JOIN summ m ON m.session = g.session
GROUP BY g.grp
ORDER BY sessions DESC;

-- Query 5 (final): groups from summary flags, by dictionary
WITH setup AS (
  SELECT session, MIN_BY(di_dictionary_num_matched, timestamp) AS dict
  FROM ARK_PROD.events.vw_events
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND location = 'session_setup'
    AND timestamp >= '2026-11-20 12:00:00' AND timestamp < '2026-11-20 14:00:00'
  GROUP BY session
),
summ AS (
  SELECT session, sessions_loaded, was_challenged, sessions_solved, sessions_verify_attempted
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND session_last_timestamp >= '2026-11-20 12:00:00'
    AND session_last_timestamp <  '2026-11-20 16:00:00'
),
g AS (
  SELECT s.dict,
         CASE
           WHEN m.sessions_verify_attempted > 0 THEN 'verify_attempted'
           WHEN NOT (m.sessions_loaded > 0) THEN 'never_loaded'
           WHEN m.was_challenged > 0 AND NOT (m.sessions_solved > 0) THEN 'challenged_abandoned'
           WHEN m.was_challenged > 0 THEN 'solved_never_verified'
           ELSE 'silent_never_verified'
         END AS grp
  FROM setup s JOIN summ m ON m.session = s.session
)
SELECT dict,
       COUNT(*) AS sessions,
       COUNT_IF(grp <> 'verify_attempted') AS no_verify,
       COUNT_IF(grp = 'challenged_abandoned') AS challenged_abandoned,
       COUNT_IF(grp = 'solved_never_verified') AS solved_never_verified,
       COUNT_IF(grp = 'silent_never_verified') AS silent_never_verified,
       COUNT_IF(grp = 'never_loaded') AS never_loaded,
       ROUND(100 * COUNT_IF(grp <> 'verify_attempted') / COUNT(*), 1) AS no_verify_pct,
       ROUND(100 * COUNT_IF(grp = 'challenged_abandoned') / COUNT(*), 1) AS abandoned_pct_of_dict
FROM g
GROUP BY dict
ORDER BY dict;
