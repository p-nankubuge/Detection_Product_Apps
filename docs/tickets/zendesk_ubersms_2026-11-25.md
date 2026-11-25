# Zendesk ticket draft: Uber SMS, Direct3D renderer with non-Windows UA (UA spoofing wave, ongoing)

**Subject:** Uber - SMS - Production - Key 1: UA-spoofing wave (Direct3D renderer with Linux/Android UA) + HTTP/1.1 library bursts getting through - add pressure on 2 new key-level TTs

**Customer / key:** Uber - SMS - Production - Key 1, public key `30000F36-CADF-490C-929A-C6A7DD8B33C4`

**Type / priority:** Attack, ongoing, partly getting through. Suggested priority: High.

**Status now (2026-11-25 ~06:00 UTC): ongoing.** Last burst from the HTTP/1.1 library started today 04:12 UTC and was still running at 05:48 UTC (latest data).

Daily estimate (5% block sample, scaled x20 - order of magnitude, not exact):

| Day (UTC) | Sessions (Direct3D + non-Windows UA) | Verified | of which HTTP/1.1 library JA4 |
|---|---|---|---|
| Nov 8-20 (baseline) | 4k-60k/day | 30-70% | 0 |
| Nov 21 | ~1.14M | ~64% | ~1.11M (21:39-23:19 UTC, 65% verified) |
| Nov 22 | ~31k | ~48% | ~0 |
| Nov 23 | ~1.20M | ~27% | 0 |
| Nov 24 | ~5.13M | ~4% | 0 |
| Nov 25 (to 05:49) | ~0.68M | ~11% | ~0.67M (04:12-05:48 UTC, 11% verified) |

**Superset chart (hourly created vs verified, all + HTTP/1.1-library JA4, rolling 21 days, 5% sample estimate):** https://superset-snowflake-green.production-blue.us-east-2.internal.services.aws.arkoselabs.com/explore/?slice_id=32430
(dataset `spike_scan_ubersms_d3d_nonwin_hourly_est5pct`, id 1582)

**Two operations in the wave (Nov 21 - now):**
1. **Linux-Chrome UA on Windows machines** - ~6M sessions (est.), real Chrome TLS stack (JA4 t13d1517h2_8daaf6152771), UA says GNU/Linux but the WebGL renderer is Direct3D (Windows-only), spread over a very large number of residential IPs (top ASN 9121 Turk Telekom, TR). ~8% verified = mostly blocked, but at this volume that is ~450k sessions through.
2. **Android "Chrome Mobile"/"Chrome Webview" from an HTTP library** - JA4 t13d3013h1_1d37bd780c83 / t13d3014h1_1d37bd780c83: TLS 1.3 but **HTTP/1.1 only and 30 ciphers** (OpenSSL-style list, not a browser), Direct3D renderer with an Android UA, mostly India (ASN 9329). Bursts of ~1-2h: Nov 21 (claimed Chrome Mobile, **65% verified**) and today (claims Chrome Webview, 11% verified - the Webview claim is now partly caught by the existing `uberinc3000-h-os-android-bn-wur-swiftshader-or-direct3d`, which only covers Android + Chrome Webview).

**Why it is an attack (session-time evidence, not the verified outcome):** new (~26k/day -> ~600k/day+), does not follow the key's daily rhythm, platform/fake-fingerprint anomalies on ~48%, Direct3D is impossible on Linux/Android/iOS (the browser actually runs on Windows), and the burst cohort's TLS is an HTTP library, not a phone.

**Request to SOC:** create the two key-level telltales below (no pressure on creation), then add pressure on Uber SMS:
- `uber3000-h-webgl-direct3d-non-windows-os` - covers both operations (and generalises the existing Android+Webview-only TT).
- `uber3000-h-ja4-http1-library-1d37bd780c83` - catches the burst tool even if it changes its renderer/UA.
Monitor the Superset chart for the next burst.

**Telltale 1** (validated with `validate_telltale`, not created) - `uber3000-h-webgl-direct3d-non-windows-os`
Type telltale · SESSION_SETUP · CUSTOM / 0 · immediate_non_legit false · Life cycle M, "Specified TTL - Review after 14 days"
Description: Uber SMS: WebGL renderer says Direct3D (only exists on Windows) while the UA claims a non-Windows OS (Linux, Android, iOS, OS X). Wave since Nov 21: Linux-Chrome UA on Windows machines (~6M est, ~8% verified, residential IPs, TR) plus Android Chrome Mobile/Webview bursts from an HTTP/1.1 library JA4 (t13d30xxh1_1d37bd780c83, IN, 11-65% verified). Created without pressure; SOC to add pressure.
```json
[
 {"key": "public_key", "operator": "TS_EQ", "value": "30000F36-CADF-490C-929A-C6A7DD8B33C4", "type": "string"},
 {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"},
 {"key": "webgl_unmasked_renderer", "operator": "EXISTS"},
 {"key": "os", "operator": "EXISTS"},
 {"key": "webgl_unmasked_renderer", "operator": "TS_CONTAINS", "value": "Direct3D", "type": "string"},
 {"key": "os", "operator": "TS_NOT_IN", "value": ["Windows", "Xbox", "Windows Phone"], "type": "list[string]"}
]
```

**Telltale 2** (validated, not created) - `uber3000-h-ja4-http1-library-1d37bd780c83`
Type telltale · SESSION_SETUP · CUSTOM / 0 · immediate_non_legit false · Life cycle M, "Specified TTL - Review after 14 days"
Description: Uber SMS: non-browser TLS client (JA4 cipher set 1d37bd780c83, 30 ciphers, ALPN http/1.1 only) claiming Chrome Mobile / Chrome Webview on Android. Bursts Nov 21 21:39-23:19 UTC (~1.1M est, 65% verified) and Nov 25 04:12-05:48 UTC (~0.67M est, 11% verified), mostly India (ASN 9329). Catches the tool even if it changes its WebGL renderer. Created without pressure; SOC to add pressure.
```json
[
 {"key": "public_key", "operator": "TS_EQ", "value": "30000F36-CADF-490C-929A-C6A7DD8B33C4", "type": "string"},
 {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"},
 {"key": "cdn__ja4_hash", "operator": "TS_REGEX", "value": "/^t13d\\d{4}h1_1d37bd780c83_/", "type": "string"}
]
```
False-positive note: Direct3D with a non-Windows UA also comes from real Windows users with UA-switcher extensions / DevTools device emulation, but that is a few hundred sessions a day on large keys, against millions here.
