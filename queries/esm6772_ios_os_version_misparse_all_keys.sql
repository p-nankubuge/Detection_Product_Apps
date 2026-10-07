-- ESM-6772 — Which keys/apps get a wrong os_version from the iOS UA parser?
-- Snowflake (Superset "Snowflake", database_id 14)
--
-- Compares the parsed os_version against the real iOS version written in the UA:
--   1. Safari/WebView token "iPhone OS 18_7" / "CPU OS 18_7", else
--   2. a trailing standalone "iOS/26.6.2" (CFNetwork-style UA, e.g. CTM's app).
-- The standalone match needs a space or start of string before "iOS/" so app names
-- such as "ServeAppServeiOS/1.4" or "RabbitiOS/2.6" are not taken as the OS.
--
-- Result on 7 Oct 2026 (last 24h, mismatch >= 50): only CTM's mobile.meerkat.ios
-- app on both CTM keys (F8A9F272…, 7BD3F690…), ~100% of its sessions.
-- Known benign hit: apps whose UA has Safari's frozen "iPhone OS 18_7" plus their own
-- "(iPhone;iOS 26.6)" (e.g. THDConsumer on 9B8ED233…). There the parser reads the
-- app's 26.x, which is the true version, so it is not this bug.

WITH t AS (
    SELECT
        public_key,
        ua,
        os_version,
        COALESCE(
            REPLACE(REGEXP_SUBSTR(ua, '(iPhone|CPU) OS ([0-9_]+)', 1, 1, 'e', 2), '_', '.'),
            REGEXP_SUBSTR(ua, '(^| )iOS/([0-9]+(\\.[0-9]+)*)\\s*$', 1, 1, 'e', 2)
        ) AS real_ios_version
    FROM ARK_PROD.EVENTS.EVENTS_LOG
    WHERE timestamp >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
      AND location = 'session_setup'
      AND ua ILIKE '%ios%'
)
SELECT
    public_key,
    SPLIT_PART(ua, '/', 1)                                                 AS ua_prefix,
    COUNT(*)                                                               AS sessions,
    SUM(IFF(real_ios_version IS NOT NULL AND os_version IS NOT NULL
            AND NOT STARTSWITH(real_ios_version, os_version)
            AND NOT STARTSWITH(os_version, real_ios_version), 1, 0))       AS os_version_mismatch,
    ANY_VALUE(LEFT(ua, 200))                                               AS sample_ua
FROM t
GROUP BY 1, 2
HAVING os_version_mismatch >= 50
ORDER BY os_version_mismatch DESC
LIMIT 40;
