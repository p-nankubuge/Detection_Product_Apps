-- Layer 1 v3. Key: Figma Registration K2 (A207F8A1-ED09-4325-ACE6-C8E26A458FBA), not a proxy key.
-- Sessions created 2026-11-20 12:00-14:00 UTC, ALL sessions (no sampling). Whitelist (D-12): distinct Dict 63 signatures,
-- sessions created 2026-11-13 00:00 to 2026-11-20 00:00 UTC, UNCLEANED, on the Figma account (23454) production keys:
-- Registration Production K2 (A207F8A1-...) and Login Production 1 (955D26AF-...). Development keys 98F60B6F-... and
-- 4193E70F-... excluded. Core = _core_template_v3.sql. Output: one pipe-delimited string per row (small Superset response).
-- Examples: up to 5 sessions per moved cell (20, then 10, did not fit the Superset response cap) (deterministic pseudo-random order HASH(session)): [(3, 'A'), (3, 'B'), (3, 'C'), (1, 'A'), (1, 'B')]
-- Columns: dict>v3 band|session|OS|platform group|OS version|risk|v3 score|v3 reason|v3 warning signs|UA ('Mozilla/5.0 (' and 'AppleWebKit/... (KHTML, like Gecko) ' removed, first 55 chars)|JA4|screen|device_params|WebGL unmasked renderer ('ANGLE (' removed, first 32 chars)
-- ja4_sim_v1, STANDALONE / LAYER 1 v3 ("Seen-before rules" of the similarity-scorer agent file, items 5, 6 and 9 updated 25 Nov).
-- Snowflake, Superset database_id 14. Template: the PRE, SESS_RAW and WL_RAW placeholders (in braces, below) are
-- replaced by hand-built rows (sanity_test_v3.sql) or by the real Figma K2 window / 7-day uncleaned account whitelist.
--
-- Starts from results/2026-11-25_layer-1-v2/_core_template_v2.sql. Everything v2 computed is still computed (v1 and v2
-- bands, so both can be compared in the same query); v3 adds four steps on top of v2, applied in this order:
--   V2 = layer 1 v2 (verbatim: CTE best -> pk_v2, flags in c, t4 -> band_v2)
--   S1 = V2 + null fix (item 9 / D-10): an empty or unparsed value gets no credit, full or partial, and is never "seen".
--        In Snowflake HASH(NULL) = HASH(NULL), so every hashed comparison is guarded on the session side (a non-empty
--        session value can only hash-match the same non-empty whitelist value). Scoring and lookups.
--   S2 = S1 + physical screen in SCORING (item 6 / D-8): screen credit on `w,h` (part after '::') instead of the full string.
--        Changes the score and possibly the closest device.
--   S3 = S2 + physical screen in CHECKS: never-seen screen, screen x platform group, screen x DP, screen x WebGL on `w,h`.
--   S4 = S3 + two-level pair checks (item 5 / D-9): coarse pair never seen = failed check (as v2); coarse seen but exact
--        pair never seen = one warning sign (counts toward the desktop Band D trigger; reported only on mobile).   (= v3)
-- Sequential attribution: `cause3` lists the step(s) at which the band changed on the V2 -> S4 path.
--
-- Pair definitions in v3 (screen is the physical size at both levels, so screen x WebGL has one level only):
--   UA x DP     coarse (browser family/major, DP positions 1,4,5,10,11)  exact (full UA, full DP)
--   screen x DP coarse (w,h, DP positions 1,4,5,10,11)                     exact (w,h, full DP)
--   screen x WebGL (w,h, full WebGL block)                                 failed check only
-- "Never both": a pair check runs only if the screen and DP are each seen exactly in the platform group and the UA is seen at
-- the coarse level (as v2). The exact-level warning additionally needs the exact UA seen (a never-seen exact UA is neutral,
-- so it is not turned into a pair warning).
--
-- Lookup key types (array ks; 0-19 unchanged from v2):
--   0 osf+screen  1 screen (any OS)  2 osf+dp  3 osf+ua  4 osf+webgl  5 osf+osv  6 osf+ua+dp  7 osf+screen+dp
--   8 osf+screen+webgl  9 pg+screen  10 pg+dp  11 pg+ua  12 pg+webgl  13 pg+coarse ua  14 pg+ua+dp  15 pg+screen+dp
--   16 pg+screen+webgl  17 pg+coarse ua+coarse dp  18 pg+screen+coarse dp  19 OS line+osv
--   v3: 20 pg+phys screen  21 phys screen (any group)  22 pg+phys screen+dp  23 pg+phys screen+webgl  24 pg+phys screen+coarse dp
WITH 
wt AS (
  SELECT column1 AS plat, column2 AS w_ja4, column3 AS w_scr, column4 AS w_dp, column5 AS w_ua, column6 AS w_gl
  FROM VALUES ('Windows',0.10,0.15,0.30,0.15,0.30), ('macOS',0.15,0.35,0.15,0.20,0.15),
              ('Linux',0.25,0.20,0.25,0.15,0.15),   ('ChromeOS',0.15,0.20,0.25,0.15,0.25),
              ('Android',0.05,0.30,0.05,0.20,0.40), ('iOS',0.15,0.40,0.05,0.30,0.10)
),
sess_raw AS ( SELECT session, di_dictionary_num_matched_at_session_created AS d, di_highest_signature_at_session_created AS h,
    latest_risk_band AS risk, (sessions_verified > 0) AS verified, (sessions_verify_attempted > 0) AS va,
    (was_challenged > 0) AS ch, (sessions_solved > 0) AS solved
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND session_last_timestamp >= '2026-11-20 12:00:00'
    AND session_ts >= '2026-11-20 12:00:00' AND session_ts < '2026-11-20 14:00:00' ),   -- columns: session, d, h, risk, verified, va, ch, solved
wl_raw AS ( SELECT di_highest_signature_at_session_created AS h, COUNT(*) AS n
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key IN ('A207F8A1-ED09-4325-ACE6-C8E26A458FBA','955D26AF-E956-4106-A4EF-2F63304776D9')
    AND session_last_timestamp >= '2026-11-13 00:00:00' AND session_last_timestamp < '2026-11-20 06:00:00'
    AND session_ts >= '2026-11-13 00:00:00' AND session_ts < '2026-11-20 00:00:00'
    AND di_dictionary_num_matched_at_session_created = 63
  GROUP BY 1 ),       -- columns: h, n (whitelist sessions per signature)
p AS (
  SELECT h, SPLIT_PART(SPLIT_PART(h,'||',1),'::',1) AS osf, SPLIT_PART(SPLIT_PART(h,'||',1),'::',2) AS osv,
    SPLIT_PART(h,'||',2) AS ja4, SPLIT_PART(h,'||',3) AS scr, SPLIT_PART(h,'||',4) AS dp,
    SPLIT_PART(h,'||',5) AS ua, SPLIT_PART(h,'||',6) AS gl
  FROM (SELECT h FROM sess_raw UNION SELECT h FROM wl_raw)
),
p2 AS (
  SELECT p.*, LEFT(ja4,1) AS tr,
    CASE WHEN ua RLIKE '.*Edg(e|A|iOS)?/[0-9].*' THEN 'Edge' WHEN ua RLIKE '.*(OPR|OPT)/[0-9].*' THEN 'Opera'
         WHEN ua RLIKE '.*SamsungBrowser/[0-9].*' THEN 'Samsung' WHEN ua RLIKE '.*(Firefox|FxiOS)/[0-9].*' THEN 'Firefox'
         WHEN ua RLIKE '.*(Chrome|CriOS)/[0-9].*' THEN 'Chrome'
         WHEN ua RLIKE '.*Version/[0-9.]+ (Mobile/[^ ]+ )?Safari/.*' THEN 'Safari' END AS bfam,
    COALESCE(TRY_TO_NUMBER(SPLIT_PART(osv,'.',1)),0)*1000000 + COALESCE(TRY_TO_NUMBER(SPLIT_PART(osv,'.',2)),0)*1000
      + COALESCE(TRY_TO_NUMBER(SPLIT_PART(osv,'.',3)),0) AS osv_num,
    CASE osf WHEN 'Windows' THEN 'Windows' WHEN 'OS X' THEN 'macOS' WHEN 'Chrome OS' THEN 'ChromeOS'
             WHEN 'Android' THEN 'Android' WHEN 'iOS' THEN 'iOS' WHEN 'iPadOS' THEN 'iOS' ELSE 'Linux' END AS plat,
    osf IN ('iOS','iPadOS','Android') AS mobile,                                   -- v1 mobile flag
    (osf = 'Windows' AND gl ILIKE '%Basic Render Driver%') AS basic,
    (gl ILIKE '%SwiftShader%' OR gl ILIKE '%llvmpipe%' OR gl ILIKE '%VirtualBox%' OR gl ILIKE '%VMware%') AS soft,
    NOT (soft OR gl ILIKE '%Basic Render Driver%') AS hw_gl,
    CASE WHEN soft THEN 'Other' WHEN gl ILIKE '%Basic Render Driver%' THEN IFF(osf = 'Windows','Windows RD/VM','Other')
         WHEN osf IN ('Windows','OS X','Chrome OS') THEN 'Desktop' WHEN osf IN ('iOS','iPadOS','Android') THEN 'Mobile'
         WHEN osf IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'Other' END AS pg,           -- platform group
    CASE WHEN osf IN ('iOS','iPadOS') THEN 'iOS+iPadOS' WHEN osf IN ('GNU/Linux','Ubuntu') THEN 'Linux'
         WHEN osf IN ('Android','Windows','OS X','Chrome OS') THEN osf END AS line,        -- OS line (NULL = none)
    SPLIT_PART(dp,'::',1)||'::'||SPLIT_PART(dp,'::',4)||'::'||SPLIT_PART(dp,'::',5)||'::'||SPLIT_PART(dp,'::',10)
      ||'::'||SPLIT_PART(dp,'::',11) AS dpc,                                             -- coarse device_params
    IFF(SPLIT_PART(scr,'::',2) RLIKE '[0-9]+,[0-9]+', SPLIT_PART(scr,'::',2), NULL) AS spv  -- v3 physical screen (NULL = unparsed)
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
    HASH(ja4) AS hj, HASH(scr) AS hs, HASH(dp) AS hd, HASH(ua) AS hu, HASH(gl) AS hg, HASH(ua_bm) AS hub,
    HASH(COALESCE(ua_bm, ua)) AS huc, HASH(dpc) AS hdc, HASH(spv) AS hsp,
    -- v3 item 9 guards: TRUE only when the value is present and parsed
    (ja4 <> '') AS ja4_ok, (spv IS NOT NULL) AS sp_ok, (ua <> '') AS ua_ok, (ua_bm IS NOT NULL) AS ub_ok, (gl <> '') AS gl_ok,
    (ua_bm IS NOT NULL OR ua <> '') AS uc_ok, (osv <> '') AS osv_ok
  FROM p2
),
k AS (
  SELECT f.*, ARRAY_CONSTRUCT(HASH(0,osf,hs), HASH(1,hs), HASH(2,osf,hd), HASH(3,osf,hu), HASH(4,osf,hg), HASH(5,osf,osv),
    HASH(6,osf,hu,hd), HASH(7,osf,hs,hd), HASH(8,osf,hs,hg), HASH(9,pg,hs), HASH(10,pg,hd), HASH(11,pg,hu), HASH(12,pg,hg),
    HASH(13,pg,huc), HASH(14,pg,hu,hd), HASH(15,pg,hs,hd), HASH(16,pg,hs,hg), HASH(17,pg,huc,hdc), HASH(18,pg,hs,hdc),
    HASH(19,line,osv),
    HASH(20,pg,hsp), HASH(21,hsp), HASH(22,pg,hsp,hd), HASH(23,pg,hsp,hg), HASH(24,pg,hsp,hdc)) AS ks
  FROM f
),
wl AS (SELECT k.* FROM k WHERE h IN (SELECT h FROM wl_raw)),
jf AS (SELECT DISTINCT hj, bfam FROM wl WHERE bfam IS NOT NULL),
st AS (
  SELECT k.*, (jf.hj IS NOT NULL) AS ja4_fam_ok,
    IFF(basic, w.w_ja4/0.70, w.w_ja4) AS w_ja4, IFF(basic, w.w_scr/0.70, w.w_scr) AS w_scr,
    IFF(basic, w.w_dp/0.70, w.w_dp) AS w_dp,    IFF(basic, w.w_ua/0.70, w.w_ua) AS w_ua,
    IFF(basic, 0, w.w_gl) AS w_gl
  FROM k JOIN wt w ON w.plat = k.plat
  LEFT JOIN jf ON jf.hj = k.hj AND jf.bfam = k.bfam
  WHERE k.h IN (SELECT h FROM sess_raw)
),
-- closest device, three variants in one join: packed = round(score*10000)*100 + match code
--   pk_v2 = verbatim layer 1 / v2 arithmetic (unguarded; HASH(NULL)=HASH(NULL) gives 1/2 UA credit between two unparsed UAs)
--   pk_s1 = null-guarded (item 9), full screen string          pk_s3 = null-guarded, physical screen (v3 scoring)
--   per-candidate match codes: jc JA4 (2 exact, 1 QUIC/TCP variant of the same browser family), uc UA (2 exact, 1 browser+major),
--   sv full screen, pv physical screen, dv device_params, gv WebGL (1 = equal)
bm AS (
  SELECT s.h, s.w_ja4, s.w_scr, s.w_dp, s.w_ua, s.w_gl,
    IFF(s.hj = c.hj, 2, IFF(s.tr <> c.tr AND s.bfam = c.bfam AND s.ja4_fam_ok, 1, 0)) AS jc, IFF(s.hu = c.hu, 2, IFF(s.hub = c.hub, 1, 0)) AS uc,
    IFF(s.hs = c.hs, 1, 0) AS sv, IFF(s.hsp = c.hsp, 1, 0) AS pv, IFF(s.hd = c.hd, 1, 0) AS dv, IFF(s.hg = c.hg, 1, 0) AS gv,
    IFF(s.ja4_ok, jc, 0) AS jg, CASE WHEN uc = 2 AND s.ua_ok THEN 2 WHEN uc >= 1 AND s.ub_ok THEN 1 ELSE 0 END AS ug,
    IFF(s.sp_ok, sv, 0) AS sg, IFF(s.sp_ok, pv, 0) AS pg2, IFF(s.gl_ok, gv, 0) AS gg
  FROM st s JOIN wl c ON c.osf = s.osf
),
best AS (
  SELECT h,
    MAX(ROUND(10000 * (w_ja4 * DECODE(jc, 2, 1, 1, 2/3, 0) + w_scr * sv + w_dp * dv + w_ua * DECODE(uc, 2, 1, 1, 0.5, 0) + w_gl * gv)) * 100
        + jc + 3 * uc + 9 * sv + 18 * dv + 36 * gv) AS pk_v2,
    MAX(ROUND(10000 * (w_ja4 * DECODE(jg, 2, 1, 1, 2/3, 0) + w_scr * sg + w_dp * dv + w_ua * DECODE(ug, 2, 1, 1, 0.5, 0) + w_gl * gg)) * 100
        + jg + 3 * ug + 9 * sg + 18 * dv + 36 * gg) AS pk_s1,
    MAX(ROUND(10000 * (w_ja4 * DECODE(jg, 2, 1, 1, 2/3, 0) + w_scr * pg2 + w_dp * dv + w_ua * DECODE(ug, 2, 1, 1, 0.5, 0) + w_gl * gg)) * 100
        + jg + 3 * ug + 9 * pg2 + 18 * dv + 36 * gg) AS pk_s3
  FROM bm GROUP BY h
),
ref AS (SELECT DISTINCT x.value::NUMBER AS kk FROM wl, LATERAL FLATTEN(wl.ks) x),
seen AS (
  SELECT q.h, ARRAY_AGG(r.kk IS NOT NULL) WITHIN GROUP (ORDER BY q.i) AS z
  FROM (SELECT s.h, x.index AS i, x.value::NUMBER AS kk FROM st s, LATERAL FLATTEN(s.ks) x) q
  LEFT JOIN ref r ON r.kk = q.kk GROUP BY q.h
),
omx AS (SELECT osf, MAX(osv_num) AS mx FROM wl GROUP BY osf),
lv AS (SELECT w.line, w.osv, MAX(w.osv_num) AS vn, SUM(r.n) AS n FROM wl w JOIN wl_raw r ON r.h = w.h WHERE w.line IS NOT NULL GROUP BY 1, 2),
lmx AS (SELECT line, MAX(vn) AS mx, MAX_BY(osv, n) AS top_osv, MAX(n) / SUM(n) AS top_share FROM lv GROUP BY line),
c AS (
  SELECT s.h, s.osf, s.osv, s.pg, s.line, s.mobile, s.basic, s.ua_bm, s.ua_ok, s.ub_ok, (s.pg = 'Mobile') AS mob2,
    (s.osf IN ('','--') OR s.dp = '') AS no_score,
    COALESCE(b.pk_v2, 0) AS pk, FLOOR(pk / 100) / 10000 AS score, MOD(pk, 100) AS code,
    COALESCE(b.pk_s1, 0) AS pk1, FLOOR(pk1 / 100) / 10000 AS score1, MOD(pk1, 100) AS code1,
    COALESCE(b.pk_s3, 0) AS pk3, FLOOR(pk3 / 100) / 10000 AS score3, MOD(pk3, 100) AS code3,
    CASE WHEN no_score THEN 'no score' WHEN score >= 0.85 THEN IFF(s.basic,'B','A') WHEN score >= 0.65 THEN 'B'
         WHEN score >= 0.40 THEN 'C' ELSE 'D' END AS sb,                            -- v2 score band (before the Band D trigger)
    CASE WHEN no_score THEN 'no score' WHEN score1 >= 0.85 THEN IFF(s.basic,'B','A') WHEN score1 >= 0.65 THEN 'B'
         WHEN score1 >= 0.40 THEN 'C' ELSE 'D' END AS sb1,
    CASE WHEN no_score THEN 'no score' WHEN score3 >= 0.85 THEN IFF(s.basic,'B','A') WHEN score3 >= 0.65 THEN 'B'
         WHEN score3 >= 0.40 THEN 'C' ELSE 'D' END AS sb3,                          -- v3 score band
    -- v1 (S0) flags, verbatim
    z[3]::BOOLEAN AND z[2]::BOOLEAN AND NOT z[6]::BOOLEAN AS f_ua_dp, z[0]::BOOLEAN AND z[2]::BOOLEAN AND NOT z[7]::BOOLEAN AS f_scr_dp,
    s.hw_gl AND z[0]::BOOLEAN AND z[4]::BOOLEAN AND NOT z[8]::BOOLEAN AS f_scr_gl, z[1]::BOOLEAN AND NOT z[0]::BOOLEAN AS f_scr_os,
    NOT z[5]::BOOLEAN AND NOT (s.osv_num > COALESCE(o.mx,-1)) AS f_osv, NOT z[2]::BOOLEAN AS f_dp_new, NOT z[0]::BOOLEAN AND NOT s.mobile AS w_scr0,
    -- v2 flags, verbatim
    z[11]::BOOLEAN AND z[10]::BOOLEAN AND NOT z[14]::BOOLEAN AS p_ua_dp, z[9]::BOOLEAN AND z[10]::BOOLEAN AND NOT z[15]::BOOLEAN AS p_scr_dp,
    s.hw_gl AND z[9]::BOOLEAN AND z[12]::BOOLEAN AND NOT z[16]::BOOLEAN AS p_scr_gl, z[1]::BOOLEAN AND NOT z[9]::BOOLEAN AS p_scr_pg,
    NOT z[10]::BOOLEAN AS p_dp_new, NOT z[9]::BOOLEAN AND s.pg <> 'Mobile' AS w_scr1,
    z[13]::BOOLEAN AND z[10]::BOOLEAN AND NOT z[17]::BOOLEAN AS c_ua_dp, z[9]::BOOLEAN AND z[10]::BOOLEAN AND NOT z[18]::BOOLEAN AS c_scr_dp,
    -- S1/S2 flags = v2 checks with item 9 guards (full screen string)
    (z[9]::BOOLEAN AND s.sp_ok) AS s_scr, z[10]::BOOLEAN AS s_dp, (z[13]::BOOLEAN AND s.uc_ok) AS s_uac,
    (z[11]::BOOLEAN AND s.ua_ok) AS s_ua, (z[12]::BOOLEAN AND s.gl_ok) AS s_gl, (z[20]::BOOLEAN AND s.sp_ok) AS s_sp,
    s_uac AND s_dp AND NOT z[17]::BOOLEAN AS g_ua_dp, s_scr AND s_dp AND NOT z[18]::BOOLEAN AS g_scr_dp,
    s.hw_gl AND s_scr AND s_gl AND NOT z[16]::BOOLEAN AS g_scr_gl, z[1]::BOOLEAN AND s.sp_ok AND NOT z[9]::BOOLEAN AS g_scr_pg,
    NOT s_scr AND s.pg <> 'Mobile' AS g_w_scr,
    -- S3 flags: physical screen in the checks (UA x DP unchanged = g_ua_dp)
    s_sp AND s_dp AND NOT z[24]::BOOLEAN AS h_scr_dp, s.hw_gl AND s_sp AND s_gl AND NOT z[23]::BOOLEAN AS h_scr_gl,
    z[21]::BOOLEAN AND s.sp_ok AND NOT z[20]::BOOLEAN AS h_scr_pg, NOT s_sp AND s.pg <> 'Mobile' AS h_w_scr,
    z[9]::BOOLEAN AS scr_seen_pg, s_sp AS sp_seen_pg,
    -- S4 flags: exact-only pair mismatches = warning signs
    s_uac AND s_dp AND NOT g_ua_dp AND s_ua AND NOT z[14]::BOOLEAN AS x_ua_dp,
    s_sp AND s_dp AND NOT h_scr_dp AND NOT z[22]::BOOLEAN AS x_scr_dp,
    -- OS version status (reported only; v3 adds the empty-version guard)
    CASE WHEN s.line IS NULL THEN 'skip: no OS line' WHEN l.top_share >= 0.90 THEN 'skip: frozen line'
         WHEN NOT s.osv_ok THEN 'skip: empty version'
         WHEN z[19]::BOOLEAN THEN 'seen' WHEN s.osv_num > l.mx THEN 'newer than newest seen' ELSE 'older, not seen (warning)' END AS osv_status
  FROM st s JOIN seen USING (h) LEFT JOIN best b ON b.h = s.h LEFT JOIN omx o ON o.osf = s.osf LEFT JOIN lmx l ON l.line = s.line
),
t AS (
  SELECT c.*,
    -- v1 and v2, verbatim
    IFF(f_ua_dp,1,0)+IFF(f_scr_dp,1,0)+IFF(f_scr_gl,1,0)+IFF(f_scr_os,1,0)+IFF(f_osv,1,0)+IFF(f_dp_new,1,0) AS n0,
    IFF(c_ua_dp,1,0)+IFF(c_scr_dp,1,0)+IFF(p_scr_gl,1,0)+IFF(p_scr_pg,1,0) AS n3x,
    n3x + IFF(p_dp_new AND mob2,1,0) AS n4,
    IFF(mobile, n0 >= 1, n0 >= 2 OR (n0 >= 1 AND (w_scr0 OR f_dp_new))) AS t0,
    IFF(mob2, n4 >= 1, n4 >= 2 OR (n4 >= 1 AND (w_scr1 OR p_dp_new))) AS t4,
    IFF(t0 AND NOT no_score,'D',sb) AS band_v1, IFF(t4 AND NOT no_score,'D',sb) AS band_v2,
    -- S1 / S2 (v2 checks, guarded)
    IFF(g_ua_dp,1,0)+IFF(g_scr_dp,1,0)+IFF(g_scr_gl,1,0)+IFF(g_scr_pg,1,0)+IFF(p_dp_new AND mob2,1,0) AS ng,
    IFF(mob2, ng >= 1, ng >= 2 OR (ng >= 1 AND (g_w_scr OR p_dp_new))) AS tg,
    IFF(tg AND NOT no_score,'D',sb1) AS bs1, IFF(tg AND NOT no_score,'D',sb3) AS bs2,
    -- S3 (physical screen in checks, coarse pairs only)
    IFF(g_ua_dp,1,0)+IFF(h_scr_dp,1,0)+IFF(h_scr_gl,1,0)+IFF(h_scr_pg,1,0)+IFF(p_dp_new AND mob2,1,0) AS nfail,   -- = v3 failed checks
    IFF(mob2, nfail >= 1, nfail >= 2 OR (nfail >= 1 AND (h_w_scr OR p_dp_new))) AS th,
    IFF(th AND NOT no_score,'D',sb3) AS bs3,
    -- S4 = v3: warning signs. Desktop (non-Mobile groups): never-seen screen, never-seen DP, exact-only pair mismatches.
    -- Mobile: only the exact-only pair mismatches are counted (reported; they never trigger D on mobile).
    IFF(x_ua_dp,1,0)+IFF(x_scr_dp,1,0) AS nxw,
    IFF(mob2, nxw, nxw + IFF(h_w_scr,1,0) + IFF(p_dp_new,1,0)) AS nwarn,
    IFF(mob2, nfail >= 1, nfail >= 2 OR (nfail >= 1 AND nwarn >= 1)) AS t3,
    IFF(t3 AND NOT no_score,'D',sb3) AS band
  FROM c
),
res AS (
  SELECT r.session, r.d, r.h, r.risk, r.verified, r.va, r.ch, r.solved, t.* EXCLUDE (h),
    CASE WHEN r.d = 63 THEN 'A' WHEN r.d IN (31,15) THEN 'B' WHEN r.d = 7 THEN 'C' ELSE 'D' END AS agree_band,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(band_v2<>bs1,'null fix',NULL), IFF(bs1<>bs2,'phys screen in scoring',NULL),
      IFF(bs2<>bs3,'phys screen in checks',NULL), IFF(bs3<>band,'two-level pairs',NULL)), ' + ') AS cause3,
    IFF(t0, 'chk:'||ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(f_ua_dp,'UAxDP',NULL), IFF(f_scr_dp,'SCRxDP',NULL),
      IFF(f_scr_gl,'SCRxGL',NULL), IFF(f_scr_os,'SCRxOS',NULL), IFF(f_osv,'OSver',NULL), IFF(f_dp_new,'DPnew',NULL),
      IFF(w_scr0,'+SCRnew',NULL)), ' '), NULL) AS chk_v1,
    IFF(t4, 'chk:'||ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(c_ua_dp,'UAxDP',NULL), IFF(c_scr_dp,'SCRxDP',NULL),
      IFF(p_scr_gl,'SCRxGL',NULL), IFF(p_scr_pg,'SCRxPG',NULL), IFF(p_dp_new AND mob2,'DPnew(fail)',NULL),
      IFF(w_scr1,'+SCRnew',NULL), IFF(p_dp_new AND NOT mob2,'+DPnew',NULL)), ' '),
      'diff:'||ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(CASE MOD(code,3) WHEN 1 THEN 'JA4qt' WHEN 0 THEN 'JA4' END,
      CASE MOD(FLOOR(code/3),3) WHEN 1 THEN 'UAmaj' WHEN 0 THEN 'UA' END, IFF(MOD(FLOOR(code/9),2)=0,'SCR',NULL),
      IFF(MOD(FLOOR(code/18),2)=0,'DP',NULL), IFF(MOD(FLOOR(code/36),2)=0 AND NOT basic,'GL',NULL)), '+')) AS reason_v2,
    -- v3 failed checks and warning signs (always listed, whatever the band)
    ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(g_ua_dp,'UAxDP',NULL), IFF(h_scr_dp,'SCRxDP',NULL), IFF(h_scr_gl,'SCRxGL',NULL),
      IFF(h_scr_pg,'SCRxPG',NULL), IFF(p_dp_new AND mob2,'DPnew',NULL)), ' ') AS fails3,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(h_w_scr,'SCRnew',NULL), IFF(p_dp_new AND NOT mob2,'DPnew',NULL),
      IFF(x_ua_dp,'UAxDPx',NULL), IFF(x_scr_dp,'SCRxDPx',NULL)), ' ') AS warns3,
    -- v3 reason: the checks if Band D by trigger (fails, then +warning signs), else the fields that differ from the closest device
    IFF(t3, 'chk:'||fails3||IFF(warns3<>'',' +'||REPLACE(warns3,' ',' +'),''),
      'diff:'||ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(CASE MOD(code3,3) WHEN 1 THEN 'JA4qt' WHEN 0 THEN 'JA4' END,
      CASE MOD(FLOOR(code3/3),3) WHEN 1 THEN 'UAmaj' WHEN 0 THEN 'UA' END, IFF(MOD(FLOOR(code3/9),2)=0,'SCR',NULL),
      IFF(MOD(FLOOR(code3/18),2)=0,'DP',NULL), IFF(MOD(FLOOR(code3/36),2)=0 AND NOT basic,'GL',NULL)), '+')) AS reason
  FROM sess_raw r JOIN t ON t.h = r.h
)
, g AS (SELECT res.*, IFF(pg='Mobile','mob','desk') AS md2 FROM res)
SELECT d||'>'||band||'|'||session||'|'||osf||'|'||pg||'|'||osv||'|'||COALESCE(risk,'')||'|'||ROUND(score3,2)||'|'||reason||'|'||warns3||'|'||LEFT(REPLACE(REPLACE(REPLACE(SPLIT_PART(h,'||',5),'Mozilla/5.0 (',''),'AppleWebKit/537.36 (KHTML, like Gecko) ',''),'AppleWebKit/605.1.15 (KHTML, like Gecko) ',''),55)
  ||'|'||SPLIT_PART(h,'||',2)||'|'||SPLIT_PART(h,'||',3)||'|'||SPLIT_PART(h,'||',4)||'|'||LEFT(REPLACE(SPLIT_PART(SPLIT_PART(h,'||',6),'::',6),'ANGLE (',''),32) AS r
FROM g WHERE (d=3 AND band='A') OR (d=3 AND band='B') OR (d=3 AND band='C') OR (d=1 AND band='A') OR (d=1 AND band='B')
QUALIFY ROW_NUMBER() OVER (PARTITION BY d, band ORDER BY HASH(session)) <= 5
ORDER BY d, band, HASH(session)
