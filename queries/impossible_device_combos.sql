-- Impossible / contradictory OS x OS version x browser x UA x device combinations
-- (events_faster / Athena).
--
-- The UA-parsed fields (os, os_version, device_type, browser_name, browser_engine)
-- are all derived from ONE string, so they almost never contradict each other.
-- The real contradictions appear when the UA is compared against signals that a
-- spoofer has to fake separately:
--   * fp_navigator_platform   -- JS navigator.platform (iPhone, Win32, MacIntel, Linux x86_64...)
--   * sec_ch_ua_platform / sec_ch_ua_mobile / user_agent_data_mobile -- UA Client Hints
--     (Chromium only: WebKit/Safari, i.e. EVERY browser on iOS, does not implement them)
--   * browser version vs. the last version that vendor ships for that OS version
--
-- tier H = physically/technically impossible on a genuine device
-- tier M = very unusual, possible in odd in-app browsers or edge configs; review before use
--
-- Output: one row per rule with session counts and overlap with existing flags.
-- For row-level output, replace the final SELECT with: SELECT * FROM flagged WHERE CARDINALITY(rules) > 0

WITH base AS (
    SELECT
        COALESCE(session_token, session)                          AS session,
        public_key,
        os, os_version, device_type, browser_name, browser_engine,
        TRY_CAST(SPLIT_PART(browser_version, '.', 1) AS INTEGER)  AS bmaj,
        TRY_CAST(SPLIT_PART(os_version, '.', 1) AS INTEGER)       AS osmaj,
        TRY_CAST(SPLIT_PART(os_version, '.', 2) AS INTEGER)       AS osmin,
        fp_navigator_platform                                     AS plat,
        NULLIF(TRIM(REPLACE(sec_ch_ua_platform, '"', '')), '')    AS ch,
        NULLIF(TRIM(sec_ch_ua_mobile), '')                        AS ch_mobile,
        user_agent_data_mobile,
        fp_has_fake_os, ua_mismatch,
        user_agent
    FROM arkoselabs.events_faster
    WHERE ymdh >= 'YYYY/MM/DD/HH'      -- ymdh is 'YYYY/MM/DD/HH' (no minutes): '2026/10/05/00'
      AND ymdh <  'YYYY/MM/DD/HH'      -- a suffix like '00:00:00.000' shifts the window by 1h
      AND location = 'session_setup'
),
flagged AS (
    SELECT b.*,
        FILTER(ARRAY[
            -- 1. "Linux on iOS": a real iPhone/iPad reports navigator.platform iPhone/iPad/iPod
            --    (iPad desktop-mode reports MacIntel). Win32 / Linux x86_64 cannot happen.
            IF(os IN ('iOS','iPadOS') AND plat <> ''
               AND plat NOT IN ('iPhone','iPad','iPod touch','iPod','MacIntel'),
               'H01_ios_non_apple_navigator_platform'),
            -- 2. WebKit on iOS has no User-Agent Client Hints: any CH value means a Chromium
            --    browser (or a hand-built header set) wearing an iOS UA.
            --    Restricted to a non-Apple navigator.platform: CH/userAgentData alongside a genuine
            --    iPhone/iPad platform is confined to a handful of keys with 0% fp_has_fake_os
            --    (likely integration-specific) -> M06.
            IF(os IN ('iOS','iPadOS')
               AND (ch IS NOT NULL OR ch_mobile IS NOT NULL OR user_agent_data_mobile IS NOT NULL)
               AND COALESCE(plat, '') NOT IN ('iPhone','iPad','iPod touch','iPod','MacIntel'),
               'H02_ios_with_client_hints'),
            -- 4. Android navigator.platform is always Linux* (or null) -- never Win/Mac/iPhone.
            --    (Android WebViews excluded: the host app can inject JS / UA metadata -> M05.)
            IF(os = 'Android' AND COALESCE(browser_name, '') <> 'Chrome Webview'
               AND plat IN ('Win32','Win64','MacIntel','iPhone','iPad','iPod touch'),
               'H04_android_non_linux_navigator_platform'),
            -- 5. Windows UA but navigator.platform of another OS.
            IF(os = 'Windows' AND (plat IN ('MacIntel','iPhone','iPad') OR plat LIKE 'Linux%'),
               'H05_windows_foreign_navigator_platform'),
            -- 6. macOS UA (Intel and Apple Silicon both report MacIntel).
            IF(os = 'OS X' AND (plat LIKE 'Win%' OR plat LIKE 'Linux%' OR plat IN ('iPhone','iPad')),
               'H06_macos_foreign_navigator_platform'),
            -- 7. Desktop Linux / ChromeOS UA with Windows/Mac/iOS navigator.platform.
            IF(os IN ('GNU/Linux','Ubuntu','Chrome OS')
               AND (plat LIKE 'Win%' OR plat IN ('MacIntel','iPhone','iPad')),
               'H07_linux_foreign_navigator_platform'),
            -- 8. Client-Hint platform contradicts UA OS. (Android Chrome "desktop site" sends
            --    CH=Android with a Linux UA, so Android+GNU/Linux is allowed. WebViews excluded:
            --    apps can set UA metadata, and Android apps on ChromeOS send CH=Android -> M05.)
            IF(ch IS NOT NULL AND os IS NOT NULL AND COALESCE(browser_name, '') <> 'Chrome Webview' AND (
                   (ch = 'Windows'   AND os <> 'Windows')
                OR (ch = 'macOS'     AND os <> 'OS X')
                OR (ch = 'Chrome OS' AND os <> 'Chrome OS')
                OR (ch = 'Android'   AND os NOT IN ('Android','Android TV','Fire OS','HarmonyOS',
                                                    'GNU/Linux','OpenHarmony'))
                OR (ch = 'Linux'     AND os IN ('Windows','OS X','iOS','iPadOS','Android'))),
               'H08_client_hint_platform_vs_ua_os'),
            -- 9. Client-Hint platform value no Chromium build ever emits (case-sensitive spec list).
            IF(ch IS NOT NULL AND ch NOT IN ('Android','Chrome OS','Chromium OS','iOS','Linux',
                                             'macOS','Windows','Unknown','Fuchsia'),
               'H09_nonstandard_client_hint_platform'),
            -- 10. Sec-CH-UA-Mobile ?1 on a desktop OS UA.
            IF(ch_mobile = '?1' AND os IN ('Windows','OS X','GNU/Linux','Ubuntu','Chrome OS'),
               'H10_mobile_hint_on_desktop_os'),
            -- 11. Desktop OS in a phone form factor.
            IF(os IN ('OS X','Windows') AND device_type IN ('smartphone','phablet','feature phone'),
               'H11_desktop_os_phone_device_type'),
            -- 12. Safari only exists on Apple OSes. Limited to Windows/Android: smart-TV and
            --     embedded-Linux browsers (Tizen, webOS, armv7l/mips boxes) carry a Safari token
            --     and the parser names them "Safari" -- those are NOT impossible.
            --     (Safari for Windows died at 5.1.7, so anything newer there is fake.)
            IF(browser_name IN ('Safari','Mobile Safari') AND COALESCE(device_type, '') <> 'tv'
               AND (os = 'Android' OR (os = 'Windows' AND COALESCE(bmaj, 99) > 5)),
               'H12_safari_on_non_apple_os'),
            -- 13. Browser version newer than the vendor ships for that OS version.
            --     Chrome/Edge 109 = last for Win 7/8/8.1; nothing modern runs XP/Vista/2003.
            IF(os = 'Windows' AND browser_name IN ('Chrome','Microsoft Edge') AND bmaj >= 110
               AND os_version IN ('7','8','8.1','Vista','XP','Server 2003','NT'),
               'H13_chrome_edge_too_new_for_windows'),
            --     Firefox 115 ESR = last for Win 7/8/8.1 and macOS 10.12-10.14.
            IF(browser_name = 'Firefox' AND bmaj >= 116 AND (
                   (os = 'Windows' AND os_version IN ('7','8','8.1','Vista','XP','Server 2003'))
                OR (os = 'OS X' AND osmaj = 10 AND osmin < 15)),
               'H14_firefox_too_new_for_os'),
            --     Chrome 116 = last for macOS 10.13/10.14 (and Chrome freezes the UA at 10_15_7,
            --     so a pre-10.15 Chrome UA with a modern version is hand-written).
            IF(os = 'OS X' AND browser_name = 'Chrome' AND bmaj >= 117 AND osmaj = 10 AND osmin < 15,
               'H15_chrome_too_new_for_macos'),
            --     Chrome 119 = last for Android 7; Chrome's reduced UA reports "Android 10".
            IF(os = 'Android' AND browser_name = 'Chrome Mobile' AND bmaj >= 120 AND osmaj < 7,
               'H16_chrome_too_new_for_android'),
            -- M1. iPhone UA but navigator.platform MacIntel / iPad (iPhone-only apps on iPad,
            --     odd webviews) -- review.
            IF(os = 'iOS' AND plat IN ('MacIntel','iPad'), 'M01_iphone_ua_mac_or_ipad_platform'),
            -- M2. Safari/Chrome/Firefox all freeze macOS at 10.15(.7); a UA claiming macOS 11+
            --     or a nonsense version (77.7.7) is non-mainstream or hand-written.
            IF(os = 'OS X' AND (osmaj >= 11), 'M02_macos_unfrozen_or_bogus_version'),
            -- M3. Android UA with Sec-CH-UA-Mobile ?0 on a phone (desktop-site mode changes the UA
            --     to Linux, so the Android UA should not carry ?0).
            IF(os = 'Android' AND device_type = 'smartphone' AND ch_mobile = '?0',
               'M03_android_phone_mobile_hint_false'),
            -- M4. Non-WebKit engine on iOS. Apple mandates WebKit, BUT browser_engine is inferred
            --     from the browser name by the UA parser (iOS Brave -> "Blink"), so most hits are
            --     parser artifacts. Only meaningful combined with a non-Apple navigator.platform.
            IF(os IN ('iOS','iPadOS')
               AND (browser_engine IN ('Blink','Presto','Trident') OR browser_engine LIKE 'Gecko%'),
               'M04_ios_non_webkit_engine_label'),
            -- M5. Android WebView with a foreign navigator.platform or CH platform (host app can
            --     override these; Android apps on ChromeOS legitimately send CH=Android).
            IF(browser_name = 'Chrome Webview' AND (
                   plat IN ('Win32','Win64','MacIntel','iPhone','iPad')
                OR (ch IS NOT NULL AND ch NOT IN ('Android') AND os = 'Android')),
               'M05_android_webview_platform_mismatch'),
            -- M6. iOS UA + Client Hints / userAgentData but a genuine Apple navigator.platform.
            IF(os IN ('iOS','iPadOS')
               AND (ch IS NOT NULL OR ch_mobile IS NOT NULL OR user_agent_data_mobile IS NOT NULL)
               AND plat IN ('iPhone','iPad','iPod touch','iPod','MacIntel'),
               'M06_ios_client_hints_apple_platform')
        ], x -> x IS NOT NULL) AS rules
    FROM base b
),
tagged AS (
    SELECT public_key, fp_has_fake_os,
           CASE WHEN CARDINALITY(rules) = 0 THEN ARRAY['_NONE']
                ELSE rules || IF(ANY_MATCH(rules, r -> r LIKE 'H%'), ARRAY['_ANY_H'], ARRAY[])
           END AS rr
    FROM flagged
)
-- Single scan; _ANY_H = sessions breaking >=1 hard rule, _NONE = clean sessions.
-- Keep the window to ~2h when running through Superset (6h hits the timeout).
SELECT
    rule,
    COUNT(*)                                                           AS sessions,
    COUNT(DISTINCT public_key)                                         AS keys,
    ROUND(AVG(IF(COALESCE(fp_has_fake_os, false), 1.0, 0.0)) * 100, 1) AS pct_already_fp_has_fake_os
FROM tagged
CROSS JOIN UNNEST(rr) AS t(rule)
GROUP BY rule
ORDER BY rule;
