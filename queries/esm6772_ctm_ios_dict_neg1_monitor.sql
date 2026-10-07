-- ESM-6772 — Compare the Market UK iOS app releases falling to DI dict -1
-- Snowflake (Superset "Snowflake", database_id 14)
--
-- Key: F8A9F272-CC12-410D-8030-4172C0935409 (CTMUK- Prod - Start Quote - Key 1)
--
-- Root cause (see ticket): the iOS app UA "mobile.meerkat.ios/<build> ... iOS/<real>"
-- is parsed so os_version = app build. Every new build looks like a new OS, so the
-- release is dict -1 (empty di_matched_signature) until the offline pipeline learns
-- it (~2 days). If the shared dict -1 short-term counter passes the threshold
-- (di_short_term_threshold_ratio >= 1), the dict -1 threshold telltales fire on all
-- of it and risk_band goes High.
--
-- Read it per app version: a new version with pct_dict_neg1 near 100% means it is
-- still happening; tagged_dict_neg1_tt > 0 means it caused false positives.
-- os_version == ios_app_version means the UA misparse is still in place.

SELECT
    CAST(DATE_TRUNC('day', timestamp) AS DATE)                                     AS day,
    REGEXP_SUBSTR(ua, '^mobile\\.meerkat\\.ios/([0-9.]+)', 1, 1, 'e')              AS ios_app_version,
    COUNT(*)                                                                       AS sessions,
    ROUND(AVG(IFF(di_dictionary_num_matched = -1, 1, 0)) * 100, 1)                 AS pct_dict_neg1,
    SUM(IFF(di_called = 1 AND di_success = 1
            AND COALESCE(di_matched_signature, '') = '', 1, 0))                    AS empty_matched_sig,
    SUM(IFF(ARRAY_TO_STRING(telltale_list::ARRAY, ',') ILIKE '%dict-neg1%', 1, 0)) AS tagged_dict_neg1_tt,
    SUM(IFF(risk_band = 'High', 1, 0))                                             AS risk_high,
    MAX(di_short_term_threshold_ratio)                                             AS max_st_ratio,
    ANY_VALUE(os_version)                                                          AS sample_os_version,
    MIN(timestamp)                                                                 AS first_seen,
    MAX(timestamp)                                                                 AS last_seen
FROM ARK_PROD.EVENTS.EVENTS_LOG
WHERE public_key = 'F8A9F272-CC12-410D-8030-4172C0935409'
  AND location = 'session_setup'
  AND timestamp >= DATEADD('day', -7, CURRENT_DATE())
  AND ua ILIKE 'mobile.meerkat.ios/%'
GROUP BY 1, 2
ORDER BY 1, 2;
