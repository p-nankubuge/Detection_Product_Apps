# Zendesk ticket draft: Amazon IDS, UA-spoofing bot (Direct3D renderer with iOS/iPadOS/Android UA) - ongoing, pass rate rising

**Subject:** Amazon - IDS - Production - Key 2: persistent UA-spoofing bot (mobile UA on Windows machines, TLS1.2 library JA4), pass rate up to ~29% - add pressure on 2 new key-level TTs

**Customer / key:** Amazon - IDS - Production - Key 2, public key `56938EF5-6EFA-483E-B6F6-C8A72B6A95EE`

**Type / priority:** Attack, ongoing every day, getting through more since Nov 23. Suggested priority: High.

**Status now (2026-11-25): ongoing.** ~52k sessions already today (to ~07:00 UTC).

Daily estimate (25% block sample, scaled x4):

| Days (UTC) | Sessions/day (Direct3D + iOS/iPadOS/Android UA) | Verified | of which TLS1.2 library JA4 |
|---|---|---|---|
| Nov 5-9 | 144k-184k | 13-15% | 78k-116k (15-17% verified) |
| Nov 10-18 | 151k-211k | 9-11% | 100k-139k (~10% verified) |
| Nov 19-22 | 116k-144k | 15-17% | 77k-98k (~15%) |
| **Nov 23-24** | 126k-181k | **29%** | 89k-128k (**28-29%**) |
| Nov 25 (to ~07:00) | ~52k | 30% | ~36k (28%) |

**Superset chart (hourly created vs verified for the cohort and for the TLS1.2 library JA4, rolling 30 days, 25% sample estimate):**
https://superset-snowflake-green.production-blue.us-east-2.internal.services.aws.arkoselabs.com/explore/?slice_id=32431
(dataset `spike_scan_amazonids_d3d_mobile_ua_hourly_est25pct`, id 1584)

**Why it is an attack (session-time evidence, not the verified outcome):**
- **The UA lies about the device:** UA says iOS / iPadOS / Android, but the WebGL renderer is Direct3D (exists only on Windows) and `navigator.platform` is `Win32` on 99.3-99.5% of sessions every day. The browser environment is Windows; only the UA is fake.
- **The TLS client is not a phone:** ~2/3 of it uses JA4 `t12d280700_b75078996b15` - TLS 1.2 (current browsers negotiate 1.3), 28 ciphers (OpenSSL-style list), only 7 extensions and **no ALPN** (every browser offers h2), while claiming Mobile Safari. 273 browser/version claims over 42 JA4s.
- **Exclusive to this key:** Nov 24 14:00-15:00 UTC, every Production key with >=20k sessions: the TLS1.2 library JA4 appears only on Amazon IDS (11,518 sessions in that hour, 0 elsewhere); mobile-UA + Win32-platform is 5.1% of Amazon IDS traffic vs <=0.15% on other large keys (that background is real users with UA switchers / DevTools emulation). Uber Account Management (1BE2475D) is the one other key with a notable share (3.5%) - separate look.
- **Infrastructure:** ~1/3 hosting/proxy/VPN, top ASN 394474 (US), ~7 sessions per IP.
- **Persistent and adapting:** present every day for at least 3 weeks; the pass rate roughly tripled from ~10% (Nov 10-18) to ~29% (Nov 23-25).

**Request to SOC:** create the two key-level telltales below (no pressure on creation), then add pressure on Amazon IDS. Watch the Superset chart: verified should drop back below ~10%.

**Telltale 1** (validated with `validate_telltale`, not created) - `amazon5693-h-webgl-direct3d-mobile-ua`
Type telltale · SESSION_SETUP · CUSTOM / 0 · immediate_non_legit false · Life cycle M, "Specified TTL - Review after 14 days"
Description: Amazon IDS: UA claims iOS/iPadOS/Android but WebGL renderer is Direct3D (Windows-only) and navigator.platform is Win32 on 99.4%. Steady 115-210k/day since at least Nov 5, ~1/3 hosting/proxy, ~2/3 on a TLS1.2 no-ALPN library JA4; pass rate rose from ~9% to ~29% since Nov 23. Created without pressure; SOC to add pressure.
```json
[
 {"key": "public_key", "operator": "TS_EQ", "value": "56938EF5-6EFA-483E-B6F6-C8A72B6A95EE", "type": "string"},
 {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"},
 {"key": "webgl_unmasked_renderer", "operator": "TS_CONTAINS", "value": "Direct3D", "type": "string"},
 {"key": "os", "operator": "TS_IN", "value": ["iOS", "iPadOS", "Android"], "type": "list[string]"}
]
```

**Telltale 2** (validated, not created) - `amazon5693-h-ja4-tls12-no-alpn-library-b75078996b15`
Type telltale · SESSION_SETUP · CUSTOM / 0 · immediate_non_legit false · Life cycle M, "Specified TTL - Review after 14 days"
Description: Amazon IDS: non-browser TLS client - JA4 t12d280700_b75078996b15 (TLS 1.2, 28 ciphers, 7 extensions, no ALPN) claiming Mobile Safari / mobile browsers. ~80-140k/day since at least Nov 5, seen on no other large Production key; pass rate ~10% mid-Nov rising to ~28% since Nov 23. Created without pressure; SOC to add pressure.
```json
[
 {"key": "public_key", "operator": "TS_EQ", "value": "56938EF5-6EFA-483E-B6F6-C8A72B6A95EE", "type": "string"},
 {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"},
 {"key": "cdn__ja4_hash", "operator": "TS_REGEX", "value": "/^t12d\\d{4}00_b75078996b15_/", "type": "string"}
]
```
The regex matches TLS 1.2, no-ALPN clients on this cipher set (any cipher/extension count, any extension hash).
