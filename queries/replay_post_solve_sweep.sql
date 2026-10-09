-- Mouse-replay post-solve deny — platform-wide sweep (events_faster / Athena)
--
-- See docs/replay-post-solve-deny-findings.md. Two queries:
--   1. Daily totals for each candidate across all keys.
--   2. Per-key breakdown of replay hits, used to tell bots from short-track collisions.
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
