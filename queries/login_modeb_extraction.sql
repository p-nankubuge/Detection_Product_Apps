-- Login Velocity Detection — Mode B extraction (events_faster / Athena)
--
-- Mode B = no end-user identifier available. This pulls session-level rows only;
-- feed the CSV to tools/login_velocity_modeb.py.
--
-- Scope matches the parent specs: desktop only, non-Safari, good fingerprint
-- encryption. Point it at a LOGIN public key (the flow is determined by the key).
-- No customer_id column is selected — that is the whole point of Mode B; if the
-- key does emit an identifier, use Mode A instead (it is the far stronger signal).

SELECT
    COALESCE(session_token, session)              AS session,
    public_key,
    timestamp                                     AS session_ts,
    init_fingerprint                              AS init_fingerprint,
    cdn__ja4_hash                                 AS cdn__ja4_hash,
    user_ip                                       AS user_ip,
    isp                                           AS isp,
    CAST(asn AS VARCHAR)                          AS asn,
    country                                       AS country,
    timezone                                      AS timezone,        -- IANA tz -> continent anchor
    ip_region                                     AS ip_region,
    connection_type                               AS connection_type,
    is_proxy                                      AS is_proxy,
    is_vpn                                        AS is_vpn,
    active_vpn                                    AS active_vpn,
    is_hosting_provider                           AS is_hosting_provider,
    ip_intel__is_proxy_harvested                  AS ip_intel__is_proxy_harvested,
    ua_mismatch                                   AS ua_mismatch,
    os                                            AS os,
    browser_name                                  AS browser_name,
    fp_encryption_status                          AS fp_encryption_status
FROM arkoselabs.events_faster
WHERE public_key = 'YOUR_LOGIN_PUBLIC_KEY'
  AND ymdh >= 'YYYY/MM/DD/00'          -- 72h+ window recommended; the analyser buckets by day
  AND ymdh <  'YYYY/MM/DD/00'
  AND location = 'session_setup'
  AND fp_encryption_status IN ('ok', 'v2__ok', 'current')
  AND os IN ('Windows', 'GNU/Linux', 'Ubuntu', 'Chrome OS')   -- macOS: see docs §7 before adding
  AND init_fingerprint IS NOT NULL
  AND init_fingerprint != ''
ORDER BY timestamp;
