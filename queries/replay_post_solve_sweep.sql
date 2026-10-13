-- Mouse-replay post-solve deny — platform-wide sweep (events_faster / Athena)
--
-- See docs/replay-post-solve-deny-findings.md. Queries:
--   1. Daily totals for each candidate across all keys.
--   2. Per-key breakdown of replay hits, used to tell bots from short-track collisions.
--   3. Events-threshold comparison per account.
--   4–6. Five-day sweep (9–13 Oct): game_verify flags, the new exact-replay flag, ML replay.
--
-- A full day across all keys times out in Superset. Use a list of sampled hours (as here) or
-- chunks of 6 h or less.

-- 1. Daily totals ------------------------------------------------------------
SELECT
    substr(ymdh, 1, 10)                                                                  AS d,
    count(*)                                                                             AS n_mouse,
    count_if(solved = 1)                                                                 AS solved_n,
    count_if(contains(suspicion_flags, 'bba-4-axis-mouse-replay'))                       AS r_base,
    count_if(contains(suspicion_flags, 'bba-4-axis-mouse-replay-above-10'))              AS r_hi,
    count_if(contains(suspicion_flags, 'bba-4-axis-mouse-replay-above-2-below-11'))      AS r_lo,
    count_if(contains(suspicion_flags, 'g-biometric-mouse-exact-replay'))                AS g_exact,
    count_if(contains(suspicion_flags, 'bba-4-axis-mouse-replay-above-10')
             AND behavioral_analysis__mouse__events_count >= 6)                          AS candidate,
    count_if(contains(suspicion_flags, 'bba-4-axis-mouse-replay')
             AND NOT contains(suspicion_flags, 'g-biometric-anomalies'))                 AS r_uncorroborated,
    approx_distinct(IF(contains(suspicion_flags, 'bba-4-axis-mouse-replay'), public_key)) AS r_keys,
    approx_distinct(IF(contains(suspicion_flags, 'bba-4-axis-mouse-replay'),
                       behavioral_analysis__mouse__four_axis_key))                       AS r_tracks
FROM arkoselabs.events_faster
WHERE ymdh IN ('2026/10/04/03', '2026/10/04/09', '2026/10/04/15', '2026/10/04/21')   -- sampled hours
  AND location = 'game_verify'
  AND behavioral_analysis__mouse__four_axis_key IS NOT NULL                          -- in-game mouse data only
GROUP BY 1
ORDER BY 1;

-- 2. Per-key breakdown of replay hits ----------------------------------------
-- Bot signature: few tracks, many hits per track, often malformed events.
-- Collision signature: tracks ~= hits, 1 IP per hit, low events_count.
SELECT
    public_key,
    count(*)                                                                             AS hits,
    count_if(solved = 1)                                                                 AS solved_n,
    approx_distinct(behavioral_analysis__mouse__four_axis_key)                           AS tracks,
    approx_distinct(user_ip)                                                             AS ips,
    count_if(contains(suspicion_flags, 'bba-4-axis-mouse-replay-above-10'))              AS hi,
    count_if(contains(suspicion_flags, 'bba-4-axis-mouse-replay-above-10')
             AND behavioral_analysis__mouse__events_count >= 6)                          AS candidate,
    approx_percentile(behavioral_analysis__mouse__events_count, 0.5)                     AS med_events,
    count_if(contains(suspicion_flags, 'g-biometric-mouse-event-invalid')
             OR contains(suspicion_flags, 'g-biometric-mouse-out-of-order')
             OR contains(suspicion_flags, 'g-biometric-mouse-sampling-inconsistency'))   AS malformed,
    arbitrary(browser_name)                                                              AS browser
FROM arkoselabs.events_faster
WHERE ymdh IN ('2026/10/04/03', '2026/10/04/09', '2026/10/04/15', '2026/10/04/21')
  AND location = 'game_verify'
  AND contains(suspicion_flags, 'bba-4-axis-mouse-replay')
GROUP BY 1
ORDER BY 2 DESC;

-- 3. Events-threshold comparison per account (section 5 of the findings) -----
-- Run in chunks of 12 h or less (24 h times out). Rows with k IS NULL are account totals.
SELECT * FROM (
    SELECT
        account_id                                                   AS a,
        public_key                                                   AS k,
        count(*)                                                     AS n,
        count_if(solved = 1)                                         AS s,
        count_if(r)                                                  AS hi,
        count_if(r AND ev >= 4)                                      AS e4,
        count_if(r AND ev >= 5)                                      AS e5,
        count_if(r AND ev >= 6)                                      AS e6,
        count_if(r AND ev >= 4 AND solved = 1)                       AS e4s,
        count_if(r AND ev >= 5 AND solved = 1)                       AS e5s,
        count_if(r AND ev >= 6 AND solved = 1)                       AS e6s,
        approx_distinct(IF(r AND ev IN (4, 5), trk))                 AS b45trk,
        approx_distinct(IF(r AND ev IN (4, 5), user_ip))             AS b45ip
    FROM (
        SELECT account_id, public_key, solved, user_ip,
               behavioral_analysis__mouse__events_count              AS ev,
               behavioral_analysis__mouse__four_axis_key             AS trk,
               contains(suspicion_flags, 'bba-4-axis-mouse-replay-above-10') AS r
        FROM arkoselabs.events_faster
        WHERE ymdh >= '2026/10/02/12' AND ymdh < '2026/10/03/00'
          AND location = 'game_verify'
          AND account_id IN (21178, 23423, 23583)                    -- Roblox, Adobe, AT&T
          AND behavioral_analysis__mouse__four_axis_key IS NOT NULL
    )
    GROUP BY GROUPING SETS ((account_id, public_key), (account_id))
)
WHERE k IS NULL OR hi > 0;

-- 4. Five-day sweep of the proposed game_verify signals (section 12 of the findings) ---
-- One row per day and key with 20+ hits, plus a day total (k IS NULL). Run in 12 h chunks;
-- two in parallel is the most Superset takes before the 60 s tool timeout.
SELECT * FROM (
    SELECT d, k, arbitrary(a) a, count(*) n,
        count_if(s1) s1, count_if(s1 AND sv) s1s, approx_distinct(IF(s1, trk)) s1t, approx_distinct(IF(s1, ip)) s1ip,
        count_if(s2) s2, count_if(s2 AND sv) s2s, approx_distinct(IF(s2, trk3)) s2t, approx_distinct(IF(s2, ip)) s2ip,
        count_if(gx) gx, count_if(gx AND sv) gxs
    FROM (
        SELECT substr(ymdh, 1, 10) d, public_key k, account_id a, solved = 1 sv, user_ip ip,
            behavioral_analysis__mouse__four_axis_key trk, behavioral_analysis__mouse__three_axis_key trk3,
            contains(suspicion_flags, 'bba-4-axis-mouse-replay-above-10')
                AND behavioral_analysis__mouse__events_count >= 4                  AS s1,
            contains(suspicion_flags, 'bba-3-axis-mouse-replay')                  AS s2,
            -- parent flag as carried on the game_verify row (location ALL: may have been set earlier)
            contains(suspicion_flags, 'g-biometric-mouse-exact-replay')           AS gx
        FROM arkoselabs.events_faster
        WHERE ymdh >= '2026/10/09/00' AND ymdh < '2026/10/09/12'
          AND location = 'game_verify'
          AND behavioral_analysis__mouse__four_axis_key IS NOT NULL
          AND public_key <> '2EAD3543-36DC-4A77-90E1-F3AE6B16CF16')            -- Arkose QA synthetic monitor
    GROUP BY GROUPING SETS ((d, k), (d)))
WHERE k IS NULL OR s1 + s2 >= 20
ORDER BY d, k NULLS FIRST;

-- 5. New suspicion flag g-biometric-mouse-exact-replay-events-4plus, from game_verify fields --
-- Filtering on the fields keeps the scan cheap enough for a full day.
SELECT * FROM (
    SELECT d, k, count(*) hits, count_if(sv) solved, approx_distinct(trk) tracks, approx_distinct(ip) ips,
           approx_percentile(ev, 0.5) ev_med, count_if(nt) no_threat
    FROM (
        SELECT substr(ymdh, 1, 10) d, public_key k, solved = 1 sv, user_ip ip,
               behavioral_analysis__mouse__four_axis_key trk, behavioral_analysis__mouse__events_count ev,
               risk_category = 'NO-THREAT' nt
        FROM arkoselabs.events_faster
        WHERE ymdh >= '2026/10/13/00' AND ymdh < '2026/10/14/00'
          AND location = 'game_verify'
          AND behavioral_analysis__mouse__exact_match_cnt > 1
          AND behavioral_analysis__mouse__events_count > 3
          AND CAST(behavioral_analysis__touch__is_null_session AS varchar) IN ('true', '1')
          AND public_key <> '2EAD3543-36DC-4A77-90E1-F3AE6B16CF16')
    GROUP BY GROUPING SETS ((d, k), (d)))
WHERE k IS NULL OR hits >= 10
ORDER BY d, hits DESC;

-- 6. ML replay per key, session level, with NO-THREAT false-positive proxy (section 10) --
-- Run in 12 h chunks. Keeps the top 11 keys plus any key with 20+ flagged NO-THREAT sessions.
WITH r AS (
    SELECT coalesce(session_token, session) sid, public_key, risk_category rc,
           try_cast(json_extract_scalar(behavioral_analysis__experimental_attributes, '$.ml_replay.prob') AS double) p
    FROM arkoselabs.events_faster
    WHERE ymdh >= '2026/10/09/00' AND ymdh < '2026/10/09/12'
      AND location = 'check_answer' AND round_number > 1
      AND public_key <> '2EAD3543-36DC-4A77-90E1-F3AE6B16CF16'),
s AS (
    SELECT sid, arbitrary(public_key) k, bool_or(rc = 'NO-THREAT') nt,
           count(*) n, count_if(p >= 0.9) hi, count_if(p >= 0.97) hi97
    FROM r WHERE p IS NOT NULL GROUP BY 1),
g AS (
    SELECT k, count(*) sess, count_if(hi >= 1) any90, count_if(hi >= 2) two90,
           count_if(n >= 2 AND hi = n) all90, count_if(hi97 >= 1) any97,
           count_if(nt) nt_sess, count_if(nt AND hi >= 1) nt_any90,
           count_if(nt AND hi >= 2) nt_two90, count_if(nt AND hi97 >= 1) nt_any97
    FROM s GROUP BY GROUPING SETS ((k), ()))
SELECT * FROM (SELECT g.*, row_number() OVER (ORDER BY any90 DESC) rk FROM g)
WHERE rk <= 11 OR nt_any90 >= 20
ORDER BY any90 DESC;
