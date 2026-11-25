-- SANITY TEST (spec.md section 2 worked examples) using the unchanged scoring core.
-- Whitelist = device W plus 4 low-similarity 'support' devices per OS so that each drifted value is
-- already seen in consistent pairs, and the QUIC JA4 is a known JA4 of the same browser family (otherwise never-seen / pair checks would force Band D, which the
-- worked examples do not model). Expected: Windows 1.00 A, .93 A, .97 A, .90 A, .70 B, .70 B, .10 D;
-- iOS 1.00 A, .85 A, .95 A, .85 A, .95 A, .90 A, .15 D.
-- ja4_sim_v1, STANDALONE / LAYER 1 scoring core (Snowflake, Superset database_id 14).
-- This file is a template: the SESS_RAW and WL_RAW placeholders (in braces below) are replaced by
--   * hand-built VALUES rows in sanity_test.sql, and
--   * the real Figma K2 session set / 7-day Dict 63 whitelist in the analysis queries.
-- Every analysis query = this core + a final SELECT over `res` (one row per session).
--
-- Field source: DI_HIGHEST_SIGNATURE_AT_SESSION_CREATED (PROD_INT_SESSION_SUMMARY) = the session's own full
-- dictionary signature, even when it matched below 63:
--   os::os_version || ja4 || screen (avail_w,avail_h::w,h) || device_params (platform::...::font hash)
--   || ua || webgl block (hash::version::glsl::max dims::unmasked vendor::unmasked renderer::bits)
-- Standalone rules: anchor = OS family (exact `os` value); OS version is a check, not weighted;
-- NO List A/B/C, NO N-rules, NO bad/suspicious lists, NO whitelist cleaning or eligibility.
-- Windows + Microsoft Basic Render Driver: WebGL weight 0, rest rescaled to 1.0, max Band B.
WITH
wt AS (
  SELECT column1 AS plat, column2 AS w_ja4, column3 AS w_scr, column4 AS w_dp, column5 AS w_ua, column6 AS w_gl
  FROM VALUES ('Windows',0.10,0.15,0.30,0.15,0.30), ('macOS',0.15,0.35,0.15,0.20,0.15),
              ('Linux',0.25,0.20,0.25,0.15,0.15),   ('ChromeOS',0.15,0.20,0.25,0.15,0.25),
              ('Android',0.05,0.30,0.05,0.20,0.40), ('iOS',0.15,0.40,0.05,0.30,0.10)
),
sess_raw AS ( SELECT column1 AS session, 0 AS d, column2 AS h, NULL AS risk, NULL AS verified, NULL AS va, NULL AS ch, NULL AS solved FROM VALUES
    ('Windows 1 everything matches', 'Windows::10||t13d1516h2_8daaf6152771_02713d6af862||1920,1032::1920,1080||Win32::0::1::24::8::1::1::0::1::0::0::0::AAAAA||Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Direct3D11 vs_5_0 ps_5_0, D3D11)::16,16,16,16'),
    ('Windows 2 all but UA (same major)', 'Windows::10||t13d1516h2_8daaf6152771_02713d6af862||1920,1032::1920,1080||Win32::0::1::24::8::1::1::0::1::0::0::0::AAAAA||Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Direct3D11 vs_5_0 ps_5_0, D3D11)::16,16,16,16'),
    ('Windows 3 all but JA4, QUIC/TCP variant', 'Windows::10||q13d0312h3_55b375c5d22e_178839b6cec1||1920,1032::1920,1080||Win32::0::1::24::8::1::1::0::1::0::0::0::AAAAA||Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Direct3D11 vs_5_0 ps_5_0, D3D11)::16,16,16,16'),
    ('Windows 4 all but JA4, unrelated', 'Windows::10||t13d1715h2_5b57614c22b0_3d5424432f57||1920,1032::1920,1080||Win32::0::1::24::8::1::1::0::1::0::0::0::AAAAA||Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Direct3D11 vs_5_0 ps_5_0, D3D11)::16,16,16,16'),
    ('Windows 5 all but device_params', 'Windows::10||t13d1516h2_8daaf6152771_02713d6af862||1920,1032::1920,1080||Win32::0::1::24::16::1::1::0::1::0::0::0::BBBBB||Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Direct3D11 vs_5_0 ps_5_0, D3D11)::16,16,16,16'),
    ('Windows 6 all but WebGL (hardware)', 'Windows::10||t13d1516h2_8daaf6152771_02713d6af862||1920,1032::1920,1080||Win32::0::1::24::8::1::1::0::1::0::0::0::AAAAA||Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::ANGLE (Intel, Intel(R) UHD Graphics 630 Direct3D11 vs_5_0 ps_5_0, D3D11)::16,16,16,16'),
    ('Windows 7 os + JA4 only', 'Windows::10||t13d1516h2_8daaf6152771_02713d6af862||1111,1111::1111,1111||Win32::0::1::24::2::1::1::0::1::0::0::0::DDDDD||Mozilla/5.0 (X11; nothing) Foo/1||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::Unknown GPU X::16,16,16,16'),
    ('iOS 1 everything matches', 'iOS::26.1||t13d2014h2_a09f3c656075_14788d8d241b||852,393::852,393||iPhone::1::1::24::4::1::1::0::1::5::1::1::5CC1A||Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Mobile/15E148 Safari/604.1||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::Apple GPU::16,16,16,16'),
    ('iOS 2 all but UA (same major)', 'iOS::26.1||t13d2014h2_a09f3c656075_14788d8d241b||852,393::852,393||iPhone::1::1::24::4::1::1::0::1::5::1::1::5CC1A||Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::Apple GPU::16,16,16,16'),
    ('iOS 3 all but JA4, QUIC/TCP variant', 'iOS::26.1||q13d0311h3_55b375c5d22e_f2a83c8e78ae||852,393::852,393||iPhone::1::1::24::4::1::1::0::1::5::1::1::5CC1A||Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Mobile/15E148 Safari/604.1||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::Apple GPU::16,16,16,16'),
    ('iOS 4 all but JA4, unrelated', 'iOS::26.1||t13d1516h2_8daaf6152771_02713d6af862||852,393::852,393||iPhone::1::1::24::4::1::1::0::1::5::1::1::5CC1A||Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Mobile/15E148 Safari/604.1||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::Apple GPU::16,16,16,16'),
    ('iOS 5 all but device_params', 'iOS::26.1||t13d2014h2_a09f3c656075_14788d8d241b||852,393::852,393||iPhone::1::1::24::6::1::1::0::1::5::1::1::5CC1A||Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Mobile/15E148 Safari/604.1||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::Apple GPU::16,16,16,16'),
    ('iOS 6 all but WebGL (hardware)', 'iOS::26.1||t13d2014h2_a09f3c656075_14788d8d241b||852,393::852,393||iPhone::1::1::24::4::1::1::0::1::5::1::1::5CC1A||Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Mobile/15E148 Safari/604.1||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::Apple A17 GPU::16,16,16,16'),
    ('iOS 7 os + JA4 only', 'iOS::26.1||t13d2014h2_a09f3c656075_14788d8d241b||1,1::1,1||iPhone::9::9::9::9::9::9::9::9::9::9::9::ZZZZZ||Mozilla/5.0 (Foo) Bar/1||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::Unknown GPU Y::16,16,16,16') ),   -- columns: session, d, h, risk, verified, va, ch, solved
wl_raw AS ( SELECT column1 AS h, 1 AS n FROM VALUES
    ('Windows::10||t13d1516h2_8daaf6152771_02713d6af862||1920,1032::1920,1080||Win32::0::1::24::8::1::1::0::1::0::0::0::AAAAA||Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Direct3D11 vs_5_0 ps_5_0, D3D11)::16,16,16,16'),
    ('Windows::10||t13d0000h2_aaaaaaaaaaaa_aaaaaaaaaaaa||800,600::800,600||Win32::0::1::24::8::1::1::0::1::0::0::0::AAAAA||Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::ANGLE (AMD, Radeon RX 580)::16,16,16,16'),
    ('Windows::10||t13d0000h2_bbbbbbbbbbbb_bbbbbbbbbbbb||1920,1032::1920,1080||Win32::0::1::24::16::1::1::0::1::0::0::0::BBBBB||Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::ANGLE (AMD, Radeon RX 6600)::16,16,16,16'),
    ('Windows::10||t13d0000h2_cccccccccccc_cccccccccccc||1920,1032::1920,1080||Win32::0::1::24::4::1::1::0::1::0::0::0::CCCCC||Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101 Firefox/150.0||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::ANGLE (Intel, Intel(R) UHD Graphics 630 Direct3D11 vs_5_0 ps_5_0, D3D11)::16,16,16,16'),
    ('Windows::10||q13d0312h3_55b375c5d22e_178839b6cec1||640,480::640,480||Win32::0::1::24::2::1::1::0::1::0::0::0::QQQQQ||Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::ANGLE (AMD, Radeon RX 7600)::16,16,16,16'),
    ('iOS::26.1||t13d2014h2_a09f3c656075_14788d8d241b||852,393::852,393||iPhone::1::1::24::4::1::1::0::1::5::1::1::5CC1A||Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Mobile/15E148 Safari/604.1||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::Apple GPU::16,16,16,16'),
    ('iOS::26.1||t13d0000h2_dddddddddddd_dddddddddddd||390,844::390,844||iPhone::1::1::24::4::1::1::0::1::5::1::1::5CC1A||Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::Apple GPU Y::16,16,16,16'),
    ('iOS::26.1||t13d0000h2_eeeeeeeeeeee_eeeeeeeeeeee||852,393::852,393||iPhone::1::1::24::6::1::1::0::1::5::1::1::5CC1A||Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Mobile/15E148 Safari/604.1||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::Apple GPU Z::16,16,16,16'),
    ('iOS::26.1||t13d0000h2_ffffffffffff_ffffffffffff||852,393::852,393||iPhone::1::1::24::8::1::1::0::1::5::1::1::5CC1A||Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/150.0 Mobile/15E148 Safari/604.1||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::Apple A17 GPU::16,16,16,16'),
    ('iOS::26.1||q13d0311h3_55b375c5d22e_f2a83c8e78ae||320,568::320,568||iPhone::1::1::24::2::1::1::0::1::5::1::1::QQQQQ||Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Mobile/15E148 Safari/604.1||h::WebGL 1.0::GLSL ES 1.0::16384,16384::Vendor::Apple GPU Q::16,16,16,16') ),       -- columns: h, n (whitelist sessions per signature)
p AS (
  SELECT h,
    SPLIT_PART(SPLIT_PART(h,'||',1),'::',1) AS osf,
    SPLIT_PART(SPLIT_PART(h,'||',1),'::',2) AS osv,
    SPLIT_PART(h,'||',2) AS ja4, SPLIT_PART(h,'||',3) AS scr, SPLIT_PART(h,'||',4) AS dp,
    SPLIT_PART(h,'||',5) AS ua,  SPLIT_PART(h,'||',6) AS gl
  FROM (SELECT h FROM sess_raw UNION SELECT h FROM wl_raw)
),
p2 AS (
  SELECT p.*,
    SPLIT_PART(gl,'::',6) AS rend,
    LEFT(ja4,1) AS tr,
    CASE WHEN ua RLIKE '.*Edg(e|A|iOS)?/[0-9].*' THEN 'Edge'
         WHEN ua RLIKE '.*(OPR|OPT)/[0-9].*' THEN 'Opera'
         WHEN ua RLIKE '.*SamsungBrowser/[0-9].*' THEN 'Samsung'
         WHEN ua RLIKE '.*(Firefox|FxiOS)/[0-9].*' THEN 'Firefox'
         WHEN ua RLIKE '.*(Chrome|CriOS)/[0-9].*' THEN 'Chrome'
         WHEN ua RLIKE '.*Version/[0-9.]+ (Mobile/[^ ]+ )?Safari/.*' THEN 'Safari' END AS bfam,
    COALESCE(TRY_TO_NUMBER(SPLIT_PART(osv,'.',1)),0)*1000000 + COALESCE(TRY_TO_NUMBER(SPLIT_PART(osv,'.',2)),0)*1000
      + COALESCE(TRY_TO_NUMBER(SPLIT_PART(osv,'.',3)),0) AS osv_num,
    CASE osf WHEN 'Windows' THEN 'Windows' WHEN 'OS X' THEN 'macOS' WHEN 'Chrome OS' THEN 'ChromeOS'
             WHEN 'Android' THEN 'Android' WHEN 'iOS' THEN 'iOS' WHEN 'iPadOS' THEN 'iOS' ELSE 'Linux' END AS plat,
    osf IN ('iOS','iPadOS','Android') AS mobile,
    (osf = 'Windows' AND gl ILIKE '%Basic Render Driver%') AS basic,
    NOT (gl ILIKE '%SwiftShader%' OR gl ILIKE '%llvmpipe%' OR gl ILIKE '%VirtualBox%' OR gl ILIKE '%VMware%' OR gl ILIKE '%Basic Render Driver%') AS hw_gl
  FROM p
),
f AS (
  SELECT p2.*,
    bfam || '/' || CASE bfam WHEN 'Edge' THEN REGEXP_SUBSTR(ua,'Edg[A-Za-z]*/([0-9]+)',1,1,'e',1)
                             WHEN 'Opera' THEN REGEXP_SUBSTR(ua,'OP[RT]/([0-9]+)',1,1,'e',1)
                             WHEN 'Samsung' THEN REGEXP_SUBSTR(ua,'SamsungBrowser/([0-9]+)',1,1,'e',1)
                             WHEN 'Firefox' THEN REGEXP_SUBSTR(ua,'(Firefox|FxiOS)/([0-9]+)',1,1,'e',2)
                             WHEN 'Chrome' THEN REGEXP_SUBSTR(ua,'(Chrome|CriOS)/([0-9]+)',1,1,'e',2)
                             WHEN 'Safari' THEN REGEXP_SUBSTR(ua,'Version/([0-9]+)',1,1,'e',1) END AS ua_bm,
    HASH(ja4) AS hj, HASH(scr) AS hs, HASH(dp) AS hd, HASH(ua) AS hu, HASH(gl) AS hg
  FROM p2
),
wl AS (SELECT f.*, HASH(f.ua_bm) AS hub FROM f WHERE f.h IN (SELECT h FROM wl_raw)),
-- JA4s seen on the whitelist (any OS family) with a given UA browser family. Used to restrict the 2/3
-- "QUIC/TCP variant of the same browser family" credit to JA4s that are known JA4s of that browser family.
-- (v1 of this run gave the credit on transport differ + same UA family only; that let non-browser TCP JA4s
--  such as t13d3213h1_... and t12d520500_... claim 2/3 credit. Fixed before the reported results.)
jf AS (SELECT DISTINCT hj, bfam FROM wl WHERE bfam IS NOT NULL),
-- session tuples (one row per distinct signature in the session set) with per-session weights
st AS (
  SELECT f.*, HASH(f.ua_bm) AS hub, (jf.hj IS NOT NULL) AS ja4_fam_ok,
    IFF(basic, w.w_ja4/0.70, w.w_ja4) AS w_ja4, IFF(basic, w.w_scr/0.70, w.w_scr) AS w_scr,
    IFF(basic, w.w_dp/0.70, w.w_dp) AS w_dp,    IFF(basic, w.w_ua/0.70, w.w_ua) AS w_ua,
    IFF(basic, 0, w.w_gl) AS w_gl
  FROM f JOIN wt w ON w.plat = f.plat
  LEFT JOIN jf ON jf.hj = f.hj AND jf.bfam = f.bfam
  WHERE f.h IN (SELECT h FROM sess_raw)
),
-- closest device: max weighted overlap within the same OS family.
-- packed = round(score*10000)*100 + match code; code = ja4 lvl (0 none,1 q/t variant,2 exact)
--   + 3*ua lvl (0 none,1 same browser+major,2 exact) + 9*screen + 18*device_params + 36*webgl
best AS (
  SELECT s.h, MAX(
    ROUND(10000 * ( s.w_ja4 * IFF(s.hj = c.hj, 1, IFF(s.tr <> c.tr AND s.bfam = c.bfam AND s.ja4_fam_ok, 2/3, 0))
                  + s.w_scr * IFF(s.hs = c.hs, 1, 0) + s.w_dp * IFF(s.hd = c.hd, 1, 0)
                  + s.w_ua  * IFF(s.hu = c.hu, 1, IFF(s.hub = c.hub, 0.5, 0))
                  + s.w_gl  * IFF(s.hg = c.hg, 1, 0) )) * 100
    + IFF(s.hj = c.hj, 2, IFF(s.tr <> c.tr AND s.bfam = c.bfam AND s.ja4_fam_ok, 1, 0))
    + 3 * IFF(s.hu = c.hu, 2, IFF(s.hub = c.hub, 1, 0))
    + 9 * IFF(s.hs = c.hs, 1, 0) + 18 * IFF(s.hd = c.hd, 1, 0) + 36 * IFF(s.hg = c.hg, 1, 0)) AS packed
  FROM st s JOIN wl c ON c.osf = s.osf
  GROUP BY s.h
),
-- reference sets for never-seen values and consistency checks (per OS family unless stated)
v_scr AS (SELECT DISTINCT osf, hs FROM wl),  v_scr_any AS (SELECT DISTINCT hs FROM wl),
v_dp  AS (SELECT DISTINCT osf, hd FROM wl),  v_ua AS (SELECT DISTINCT osf, hu FROM wl),
v_gl  AS (SELECT DISTINCT osf, hg FROM wl),  v_osv AS (SELECT DISTINCT osf, osv FROM wl),
v_osvmax AS (SELECT osf, MAX(osv_num) AS mx FROM wl GROUP BY osf),
pr_ua_dp AS (SELECT DISTINCT osf, hu, hd FROM wl), pr_scr_dp AS (SELECT DISTINCT osf, hs, hd FROM wl),
pr_scr_gl AS (SELECT DISTINCT osf, hs, hg FROM wl),
chk AS (
  SELECT s.h, s.osf, s.osv, s.plat, s.mobile, s.basic, s.hw_gl,
    (s.osf IN ('','--') OR s.dp = '') AS no_score,      -- no OS, or no JS fingerprint (empty device_params)
    COALESCE(b.packed, 0) AS packed,
    (a1.hs IS NOT NULL) AS scr_seen, (a2.hd IS NOT NULL) AS dp_seen, (a3.hu IS NOT NULL) AS ua_seen,
    (a4.hg IS NOT NULL) AS gl_seen,  (a0.hs IS NOT NULL) AS scr_seen_any_os,
    (o1.osv IS NOT NULL) AS osv_seen, (s.osv_num > COALESCE(o2.mx, -1)) AS osv_newer,
    (q1.hu IS NOT NULL) AS pair_ua_dp, (q2.hs IS NOT NULL) AS pair_scr_dp, (q3.hs IS NOT NULL) AS pair_scr_gl
  FROM st s
  LEFT JOIN best b ON b.h = s.h
  LEFT JOIN v_scr a1 ON a1.osf = s.osf AND a1.hs = s.hs
  LEFT JOIN v_scr_any a0 ON a0.hs = s.hs
  LEFT JOIN v_dp a2 ON a2.osf = s.osf AND a2.hd = s.hd
  LEFT JOIN v_ua a3 ON a3.osf = s.osf AND a3.hu = s.hu
  LEFT JOIN v_gl a4 ON a4.osf = s.osf AND a4.hg = s.hg
  LEFT JOIN v_osv o1 ON o1.osf = s.osf AND o1.osv = s.osv
  LEFT JOIN v_osvmax o2 ON o2.osf = s.osf
  LEFT JOIN pr_ua_dp q1 ON q1.osf = s.osf AND q1.hu = s.hu AND q1.hd = s.hd
  LEFT JOIN pr_scr_dp q2 ON q2.osf = s.osf AND q2.hs = s.hs AND q2.hd = s.hd
  LEFT JOIN pr_scr_gl q3 ON q3.osf = s.osf AND q3.hs = s.hs AND q3.hg = s.hg
),
sc AS (
  SELECT chk.*,
    FLOOR(packed / 100) / 10000 AS score,
    MOD(packed, 100) AS code,
    -- consistency checks: both values seen on their own (this OS family) but never together
    (ua_seen AND dp_seen AND NOT pair_ua_dp) AS f_ua_dp,
    (scr_seen AND dp_seen AND NOT pair_scr_dp) AS f_scr_dp,
    (hw_gl AND scr_seen AND gl_seen AND NOT pair_scr_gl) AS f_scr_gl,
    (scr_seen_any_os AND NOT scr_seen) AS f_scr_os,          -- screen seen on another OS family only
    (NOT osv_seen AND NOT osv_newer) AS f_osv,               -- older / unseen-and-not-newer OS version
    (NOT dp_seen) AS f_dp_new,                               -- never-seen device_params = failed check
    (NOT scr_seen AND NOT mobile) AS warn_scr_new            -- never-seen desktop screen = warning sign
  FROM chk
),
bd AS (
  SELECT sc.*,
    IFF(f_ua_dp,1,0) + IFF(f_scr_dp,1,0) + IFF(f_scr_gl,1,0) + IFF(f_scr_os,1,0) + IFF(f_osv,1,0) + IFF(f_dp_new,1,0) AS n_fail,
    CASE WHEN score >= 0.85 THEN 'A' WHEN score >= 0.65 THEN 'B' WHEN score >= 0.40 THEN 'C' ELSE 'D' END AS score_band
  FROM sc
),
bands AS (
  SELECT bd.*,
    IFF(mobile, n_fail >= 1, n_fail >= 2 OR (n_fail >= 1 AND (warn_scr_new OR f_dp_new))) AS d_trigger,
    CASE WHEN no_score THEN 'no score'
         WHEN IFF(mobile, n_fail >= 1, n_fail >= 2 OR (n_fail >= 1 AND (warn_scr_new OR f_dp_new))) THEN 'D'
         WHEN basic AND score_band = 'A' THEN 'B'
         ELSE score_band END AS band
  FROM bd
),
res AS (
  SELECT r.session, r.d, r.h, r.risk, r.verified, r.va, r.ch, r.solved, b.*  EXCLUDE (h)
  FROM sess_raw r JOIN bands b ON b.h = r.h
)
SELECT session AS example, ROUND(score,4) AS score, score_band, band, code, n_fail, f_ua_dp, f_scr_dp, f_scr_gl, f_scr_os, f_osv, f_dp_new, warn_scr_new
FROM res ORDER BY session;
