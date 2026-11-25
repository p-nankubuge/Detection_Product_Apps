-- Layer 1 v2 (Seen-before rules). Key: Figma Registration K2 (A207F8A1-ED09-4325-ACE6-C8E26A458FBA), not a proxy key.
-- Sessions created 2026-11-20 12:00-14:00 UTC, ALL sessions (no sampling). Whitelist: distinct Dict 63 signatures on this
-- key, sessions created 2026-11-13 00:00 to 2026-11-20 00:00 UTC, UNCLEANED. Core = _core_template_v2.sql.
-- Output is one pipe-delimited string per row to keep the Superset response small.
-- Q1: v2 and v1 crosstabs, G3 v1/v2, OS version status, frozen test, moved share, Dict 15 subgroup, platform groups.
-- ja4_sim_v1, STANDALONE / LAYER 1, re-run with the "Seen-before rules" (similarity-scorer agent file, 25 Nov).
-- Snowflake, Superset database_id 14. Template: the PRE, SESS_RAW and WL_RAW placeholders (in braces, below) are
-- replaced by hand-built rows (sanity_test_v2.sql) or by the real Figma K2 window / 7-day uncleaned Dict 63 whitelist.
--
-- SCORING IS UNCHANGED from results/2026-11-25_layer-1/_core_template.sql: weights, partial credit (incl. the JA4 2/3
-- browser-family fix), closest device per exact OS family (CTE `best` is copied verbatim), bands, Basic Render cap.
-- Only the checks change. Band is computed under five rule sets so every v1 -> v2 move can be attributed:
--   S0 = layer-1 run (v1): lookups per exact OS family, exact pairs, OS version = failed check, DP never seen = failed check
--   S1 = S0 + platform grouping (lookups per platform group; screen x OS family -> screen x platform group; mobile = group Mobile)
--   S2 = S1 + coarse pair values (UA = browser/major; device_params = positions 1,4,5,10,11)
--   S3 = S2 + new OS version rule (per OS line, frozen lines skipped, older-unseen reported only; never counts toward D)
--   S4 = S3 + device_params never seen on a non-Mobile group = warning sign, not a failed check   (= v2)
-- Sequential attribution: `cause` lists the step(s) at which the band changed on the S0 -> S4 path.
--
-- device_params coarse key: 13 '::' values. Kept (from whitelist value distributions, 25 Nov): p1 navigator.platform,
--   p4 colour depth (24/30/32), p5 CPU cores, p10 max touch points (0/1/2/5/10), p11 touch flag (0/1).
--   Dropped: p2, p3, p6-p9, p12 (0/1 flags, assumed storage/cookie/feature flags; not individually confirmed), p13 font hash.
--
-- "Seen before" lookups: every whitelist row emits 20 hashed keys (array ks, index = key type); the reference table is
-- the distinct set of those keys; a session looks up its own 20 keys. Key types:
--   0 osf+screen  1 screen (any OS)  2 osf+dp  3 osf+ua  4 osf+webgl  5 osf+osv  6 osf+ua+dp  7 osf+screen+dp
--   8 osf+screen+webgl  9 pg+screen  10 pg+dp  11 pg+ua  12 pg+webgl  13 pg+coarse ua  14 pg+ua+dp  15 pg+screen+dp
--   16 pg+screen+webgl  17 pg+coarse ua+coarse dp  18 pg+screen+coarse dp  19 OS line+osv
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
  WHERE public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
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
         WHEN osf IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'Other' END AS pg,           -- v2 platform group
    CASE WHEN osf IN ('iOS','iPadOS') THEN 'iOS+iPadOS' WHEN osf IN ('GNU/Linux','Ubuntu') THEN 'Linux'
         WHEN osf IN ('Android','Windows','OS X','Chrome OS') THEN osf END AS line,        -- v2 OS line (NULL = none)
    SPLIT_PART(dp,'::',1)||'::'||SPLIT_PART(dp,'::',4)||'::'||SPLIT_PART(dp,'::',5)||'::'||SPLIT_PART(dp,'::',10)
      ||'::'||SPLIT_PART(dp,'::',11) AS dpc                                              -- v2 coarse device_params
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
    HASH(COALESCE(ua_bm, ua)) AS huc, HASH(dpc) AS hdc                  -- coarse UA falls back to the full UA if unparsed
  FROM p2
),
k AS (
  SELECT f.*, ARRAY_CONSTRUCT(HASH(0,osf,hs), HASH(1,hs), HASH(2,osf,hd), HASH(3,osf,hu), HASH(4,osf,hg), HASH(5,osf,osv),
    HASH(6,osf,hu,hd), HASH(7,osf,hs,hd), HASH(8,osf,hs,hg), HASH(9,pg,hs), HASH(10,pg,hd), HASH(11,pg,hu), HASH(12,pg,hg),
    HASH(13,pg,huc), HASH(14,pg,hu,hd), HASH(15,pg,hs,hd), HASH(16,pg,hs,hg), HASH(17,pg,huc,hdc), HASH(18,pg,hs,hdc),
    HASH(19,line,osv)) AS ks
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
-- closest device (verbatim from layer 1): packed = round(score*10000)*100 + match code
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
ref AS (SELECT DISTINCT x.value::NUMBER AS kk FROM wl, LATERAL FLATTEN(wl.ks) x),
seen AS (
  SELECT q.h, ARRAY_AGG(r.kk IS NOT NULL) WITHIN GROUP (ORDER BY q.i) AS z
  FROM (SELECT s.h, x.index AS i, x.value::NUMBER AS kk FROM st s, LATERAL FLATTEN(s.ks) x) q
  LEFT JOIN ref r ON r.kk = q.kk GROUP BY q.h
),
-- newest version per OS family (v1) and per OS line (v2); top version share per OS line (frozen test, session-weighted)
omx AS (SELECT osf, MAX(osv_num) AS mx FROM wl GROUP BY osf),
lv AS (SELECT w.line, w.osv, MAX(w.osv_num) AS vn, SUM(r.n) AS n FROM wl w JOIN wl_raw r ON r.h = w.h WHERE w.line IS NOT NULL GROUP BY 1, 2),
lmx AS (SELECT line, MAX(vn) AS mx, MAX_BY(osv, n) AS top_osv, MAX(n) / SUM(n) AS top_share FROM lv GROUP BY line),
c AS (
  SELECT s.h, s.osf, s.osv, s.pg, s.line, s.mobile, s.basic, s.ua_bm, (s.pg = 'Mobile') AS mob2,
    (s.osf IN ('','--') OR s.dp = '') AS no_score, COALESCE(b.packed, 0) AS pk,
    FLOOR(pk / 100) / 10000 AS score, MOD(pk, 100) AS code,
    CASE WHEN no_score THEN 'no score' WHEN score >= 0.85 THEN IFF(s.basic,'B','A') WHEN score >= 0.65 THEN 'B'
         WHEN score >= 0.40 THEN 'C' ELSE 'D' END AS sb,                            -- band before the Band D trigger
    -- S0 (v1) flags
    z[3]::BOOLEAN AND z[2]::BOOLEAN AND NOT z[6]::BOOLEAN AS f_ua_dp, z[0]::BOOLEAN AND z[2]::BOOLEAN AND NOT z[7]::BOOLEAN AS f_scr_dp,
    s.hw_gl AND z[0]::BOOLEAN AND z[4]::BOOLEAN AND NOT z[8]::BOOLEAN AS f_scr_gl, z[1]::BOOLEAN AND NOT z[0]::BOOLEAN AS f_scr_os,
    NOT z[5]::BOOLEAN AND NOT (s.osv_num > COALESCE(o.mx,-1)) AS f_osv, NOT z[2]::BOOLEAN AS f_dp_new, NOT z[0]::BOOLEAN AND NOT s.mobile AS w_scr0,
    -- S1 flags (per platform group, exact pairs)
    z[11]::BOOLEAN AND z[10]::BOOLEAN AND NOT z[14]::BOOLEAN AS p_ua_dp, z[9]::BOOLEAN AND z[10]::BOOLEAN AND NOT z[15]::BOOLEAN AS p_scr_dp,
    s.hw_gl AND z[9]::BOOLEAN AND z[12]::BOOLEAN AND NOT z[16]::BOOLEAN AS p_scr_gl, z[1]::BOOLEAN AND NOT z[9]::BOOLEAN AS p_scr_pg,
    NOT z[10]::BOOLEAN AS p_dp_new, NOT z[9]::BOOLEAN AND s.pg <> 'Mobile' AS w_scr1,
    -- S2 flags (coarse pairs). Precondition: screen and DP seen exactly (their never-seen is a signal: "never both");
    -- UA seen at the coarse level (a never-seen exact UA is neutral, so it does not pre-empt the pair check).
    z[13]::BOOLEAN AND z[10]::BOOLEAN AND NOT z[17]::BOOLEAN AS c_ua_dp, z[9]::BOOLEAN AND z[10]::BOOLEAN AND NOT z[18]::BOOLEAN AS c_scr_dp,
    -- v2 OS version status (reported only)
    CASE WHEN s.line IS NULL THEN 'skip: no OS line' WHEN l.top_share >= 0.90 THEN 'skip: frozen line'
         WHEN z[19]::BOOLEAN THEN 'seen' WHEN s.osv_num > l.mx THEN 'newer than newest seen' ELSE 'older, not seen (warning)' END AS osv_status
  FROM st s JOIN seen USING (h) LEFT JOIN best b ON b.h = s.h LEFT JOIN omx o ON o.osf = s.osf LEFT JOIN lmx l ON l.line = s.line
),
t AS (
  SELECT c.*,
    IFF(f_ua_dp,1,0)+IFF(f_scr_dp,1,0)+IFF(f_scr_gl,1,0)+IFF(f_scr_os,1,0)+IFF(f_osv,1,0)+IFF(f_dp_new,1,0) AS n0,
    IFF(p_ua_dp,1,0)+IFF(p_scr_dp,1,0)+IFF(p_scr_gl,1,0)+IFF(p_scr_pg,1,0)+IFF(f_osv,1,0) AS n1x,  -- + DP never seen
    IFF(c_ua_dp,1,0)+IFF(c_scr_dp,1,0)+IFF(p_scr_gl,1,0)+IFF(p_scr_pg,1,0) AS n3x,                 -- + DP never seen
    n1x + IFF(p_dp_new,1,0) AS n1, n3x + IFF(f_osv,1,0) + IFF(p_dp_new,1,0) AS n2, n3x + IFF(p_dp_new,1,0) AS n3,
    n3x + IFF(p_dp_new AND mob2,1,0) AS n4,
    IFF(mobile, n0 >= 1, n0 >= 2 OR (n0 >= 1 AND (w_scr0 OR f_dp_new))) AS t0,
    IFF(mob2, n1 >= 1, n1 >= 2 OR (n1 >= 1 AND (w_scr1 OR p_dp_new))) AS t1,
    IFF(mob2, n2 >= 1, n2 >= 2 OR (n2 >= 1 AND (w_scr1 OR p_dp_new))) AS t2,
    IFF(mob2, n3 >= 1, n3 >= 2 OR (n3 >= 1 AND (w_scr1 OR p_dp_new))) AS t3,
    IFF(mob2, n4 >= 1, n4 >= 2 OR (n4 >= 1 AND (w_scr1 OR p_dp_new))) AS t4,   -- v2 warning = never-seen desktop screen or DP
    IFF(t0 AND NOT no_score,'D',sb) AS band_v1, IFF(t1 AND NOT no_score,'D',sb) AS b1, IFF(t2 AND NOT no_score,'D',sb) AS b2,
    IFF(t3 AND NOT no_score,'D',sb) AS b3, IFF(t4 AND NOT no_score,'D',sb) AS band
  FROM c
),
res AS (
  SELECT r.session, r.d, r.h, r.risk, r.verified, r.va, r.ch, r.solved, t.* EXCLUDE (h),
    CASE WHEN r.d = 63 THEN 'A' WHEN r.d IN (31,15) THEN 'B' WHEN r.d = 7 THEN 'C' ELSE 'D' END AS agree_band,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(band_v1<>b1,'platform grouping',NULL), IFF(b1<>b2,'coarse pairs',NULL),
      IFF(b2<>b3,'OS version',NULL), IFF(b3<>band,'device_params warning',NULL)), ' + ') AS cause,
    IFF(t0, 'chk:'||ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(f_ua_dp,'UAxDP',NULL), IFF(f_scr_dp,'SCRxDP',NULL),
      IFF(f_scr_gl,'SCRxGL',NULL), IFF(f_scr_os,'SCRxOS',NULL), IFF(f_osv,'OSver',NULL), IFF(f_dp_new,'DPnew',NULL),
      IFF(w_scr0,'+SCRnew',NULL)), ' '), NULL) AS chk_v1,
    -- v2 reason: the checks if Band D by trigger, else the fields that differ from the closest device ('diff:' alone = exact match)
    IFF(t4, 'chk:'||ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(c_ua_dp,'UAxDP',NULL), IFF(c_scr_dp,'SCRxDP',NULL),
      IFF(p_scr_gl,'SCRxGL',NULL), IFF(p_scr_pg,'SCRxPG',NULL), IFF(p_dp_new AND mob2,'DPnew(fail)',NULL),
      IFF(w_scr1,'+SCRnew',NULL), IFF(p_dp_new AND NOT mob2,'+DPnew',NULL)), ' '),
      'diff:'||ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(CASE MOD(code,3) WHEN 1 THEN 'JA4qt' WHEN 0 THEN 'JA4' END,
      CASE MOD(FLOOR(code/3),3) WHEN 1 THEN 'UAmaj' WHEN 0 THEN 'UA' END, IFF(MOD(FLOOR(code/9),2)=0,'SCR',NULL),
      IFF(MOD(FLOOR(code/18),2)=0,'DP',NULL), IFF(MOD(FLOOR(code/36),2)=0 AND NOT basic,'GL',NULL)), '+')) AS reason
  FROM sess_raw r JOIN t ON t.h = r.h
)

, g AS (SELECT res.*, IFF(pg='Mobile','mob','desk') AS md2, IFF(mobile,'mob','desk') AS md1 FROM res)
SELECT r FROM (
SELECT 'X2|'||d||'|'||band||'|'||COUNT(*)||'|'||COUNT_IF(risk='High')||'|'||COUNT_IF(verified)||'|'||COUNT_IF(ch)||'|'||COUNT_IF(ch AND NOT COALESCE(solved,FALSE))||'|'||ROUND(AVG(score),3) AS r FROM g GROUP BY d, band
UNION ALL SELECT 'X1|'||d||'|'||band_v1||'|'||COUNT(*)||'|'||COUNT_IF(risk='High')||'|'||COUNT_IF(verified)||'|'||COUNT_IF(ch)||'|'||COUNT_IF(ch AND NOT COALESCE(solved,FALSE)) FROM g GROUP BY d, band_v1
UNION ALL SELECT 'G3v1|'||md1||'|'||IFF(t0,'Dchk','pass')||'|'||COUNT(*)||'|'||COUNT_IF(risk='High')||'|'||COUNT_IF(verified)||'|'||COUNT_IF(ch)||'|'||COUNT_IF(ch AND NOT COALESCE(solved,FALSE)) FROM g GROUP BY md1, t0
UNION ALL SELECT 'G3v2|'||md2||'|'||IFF(t4,'Dchk','pass')||'|'||COUNT(*)||'|'||COUNT_IF(risk='High')||'|'||COUNT_IF(verified)||'|'||COUNT_IF(ch)||'|'||COUNT_IF(ch AND NOT COALESCE(solved,FALSE)) FROM g GROUP BY md2, t4
UNION ALL SELECT 'OSV|'||COALESCE(line,'-')||'|'||osv_status||'|'||COUNT(*)||'|'||COUNT_IF(risk='High')||'|'||COUNT_IF(verified)||'|'||COUNT_IF(ch)||'|'||COUNT_IF(ch AND NOT COALESCE(solved,FALSE)) FROM g GROUP BY line, osv_status
UNION ALL SELECT 'FRZ|'||line||'|'||top_osv||'|'||ROUND(top_share,4)||'|'||mx FROM lmx
UNION ALL SELECT 'MV|'||IFF(band<>band_v1,'moved','same')||'|'||COUNT(*)||'|'||COUNT_IF(risk='High')||'|'||COUNT_IF(verified)||'|'||COUNT_IF(ch)||'|'||COUNT_IF(ch AND NOT COALESCE(solved,FALSE)) FROM g GROUP BY IFF(band<>band_v1,'moved','same')
UNION ALL SELECT 'D15|'||band||'|'||reason||'|'||COUNT(*)||'|'||COUNT_IF(risk='High')||'|'||COUNT_IF(verified)||'|'||COUNT_IF(ch)||'|'||COUNT_IF(ch AND NOT COALESCE(solved,FALSE)) FROM g WHERE d=15 AND band_v1='D' AND chk_v1='chk:UAxDP SCRxDP' GROUP BY band, reason
UNION ALL SELECT 'PG|'||pg||'|'||osf||'|'||band||'|'||COUNT(*)||'|'||COUNT_IF(risk='High')||'|'||COUNT_IF(verified)||'|'||COUNT_IF(ch)||'|'||COUNT_IF(ch AND NOT COALESCE(solved,FALSE)) FROM g GROUP BY pg, osf, band
UNION ALL SELECT 'NOSC|'||COUNT_IF(no_score)||'|uanull_halfcredit='||COUNT_IF(ua_bm IS NULL AND MOD(FLOOR(code/3),3)=1) FROM g
) ORDER BY r
