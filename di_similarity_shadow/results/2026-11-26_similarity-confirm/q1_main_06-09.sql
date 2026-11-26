-- Similarity confirm run (D-20 trigger on a second window with truth data). Key: Figma Registration K2 (A207F8A1-...), not a proxy key.
-- Sessions created 2026-11-06 06:00 to 09:00 UTC, ALL sessions (no sampling). Whitelist (D-12): distinct Dict 63 signatures with session counts,
-- sessions created 2026-10-30 00:00 to 2026-11-06 00:00 UTC, UNCLEANED, Figma account production keys: Registration Production K2
-- (A207F8A1-...) and Login Production 1 (955D26AF-...); development keys excluded. Core = _core_template_v4.sql (unchanged from v4).
-- T0 = v4 trigger (band4, t4v); T1 = D-20 a+b+c (band_abc, tabc). Main v4 cut-offs.
-- Truth data: Athena starfleet_production.truth_data_history labels for sessions created in this chunk (labels_2026-11-06.csv), inlined as
-- 13-char keys (first 3 chars + last 10 chars of the session ID; unique among all 6 Nov sessions) + L (Legit) / N (Nonlegit).
-- Output: one row per section, 'NAME#' then items joined by ';' (fields pipe-delimited):
--   M|labels in chunk|labels matched|matched Legit|matched Nonlegit|sessions|verified sessions
--   X|today dict|T0 band T1 band (2 letters, 'n' = no score)|label (L/N/-)|n|High|verified|challenged|challenged not solved
--   G3|desk/mob|T0 trigger D/p + T1 trigger D/p|label|n|High
--   G1|dict (1/3)|single field differing from the closest device ('multi' = 2+ fields, '' = none)|n|T0 A/B|T1 A/B|High
--   ADD|desk/mob|T1 part that fired (a = coarse UAxDP never seen, b = 2+ warnings)|failed checks|warning signs counted by T1 (incl. SCRxGL moved)|label|n|High  (T0 not D, T1 D)
--   WF|desk/mob|failed checks (0-2+)|warning signs (0-3+, T0 view)|label|n|High
-- ja4_sim_v1, STANDALONE / SIMILARITY v4 = layer 1 v3 + pair checks GRADED BY FREQUENCY (D-18): common / rare / never.
-- v4 additions (everything v3 computed is still computed, so v1/v2/v3 bands come out of the same query):
--   * wl carries n (whitelist sessions per signature); ref = whitelist SESSION COUNT per lookup key (not just seen/not seen);
--     seen.zc = those counts per session key; pgt = whitelist sessions per platform group.
--   * pair frequency = whitelist sessions with the pair / whitelist sessions in the platform group, coarse and exact:
--       fuc / fux  UA x DP coarse / exact        fsc / fsx  screen x DP coarse / exact
--       fsg screen x WebGL (one level)            fsp screen x platform group
--     NULL = check not applicable (same "never both" preconditions as v3; exact level only where the coarse pair is seen).
--   * v4 grading: coarse never = failed check (as v3); rare = coarse < cut-off OR exact < cut-off (exact 0 included) = ONE warning
--     sign per pair; common = pass. Cut-offs = the CUT_* placeholders (in braces). Band D trigger unchanged.
--   * what-if triggers (desktop = non-Mobile groups; mobile trigger unchanged): ta = v4 + coarse UAxDP alone -> D; tb = v4 + 2+ warning
--     signs -> D; tc = screen x WebGL failure counted as a warning sign instead of a failed check; tabc = all three.
-- Below: the v3 header, unchanged.
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
WITH lab AS (SELECT LEFT(value,13) AS k, RIGHT(value,1) AS l FROM TABLE(SPLIT_TO_TABLE('1004596755004N,1018491527204L,1023823854104N,1058516315105L,1058816162604L,1079437900704L,1120126843004L,1238104210004N,1232771296704N,1275708288704N,1349747289303L,1624189262104N,1671541401104N,1815118023404L,1828688608004L,1867269134604L,1870963801904L,1917045193604L,1926273093705L,1931907893504N,1947483978605L,1988929462904N,1990867328004L,1994980164105N,2117557717205L,2136516578904L,2220019564504N,2328748020002N,2406802642702N,2584595684204L,2645123922005L,2656194620804N,2698085254104L,2699753845501N,2723320390004N,2742911227304N,2742197692604N,2740979487204N,2816999752405L,2831096939601L,2839989138805N,2851037294002N,2866663912204N,2956864921305L,2959168705304L,2961365421404N,2998884302103L,3055334138905N,3082942285305N,3170017781704N,3190211990404N,3216513434704N,3253312623904N,3274562014904N,3423368929605N,3427980150104L,3533545723104L,3538033035405N,3649482010905L,3676794004201L,3709038992704N,3713736779004L,3720344505004N,3855847264005L,3899109231904L,3926640215705L,3992572825604L,4186316821304N,4212243800604L,4216484230904L,4230189461105L,4279903393004L,4332083986004N,4440837552304L,4511041467004L,4537859810304N,4574711286504L,4578845663404N,4687746378704N,4709964679504L,4745558372205N,4758397226804L,4918501880904L,4928169750605N,4985514829104N,5031058556704L,5076830503204N,5130071777702N,5219539429904N,5276756741604N,5298638978804L,5373238248604L,5427510180305N,5442042763302L,5451856352804N,5500500223005N,5513451954404N,5519471677205N,5540643043402N,5652404585105L,5697049121304L,5722489276404L,5782574689901L,5874011854302N,5876685075604N,5875876252304L,5911902936204L,5962964936905L,6010377190101N,6021989212005L,6031890691304L,6048131882504L,6043554604305N,6154527277604L,6199889201304N,6220964715804L,6257412942805L,6328389010604L,6385632202704L,6403807857204N,6439562109205L,6457128955505L,6551924206804L,6573967027404N,6700899496702N,6794892243604N,6809077626602N,6828553360205L,6926251564704L,6951907743804L,6963499595505L,6973249173704N,7017516201904N,7029526958204L,7087368346704L,7088451462805N,7137887529904L,7177916234002N,7206591896004N,7236276751104L,7311925889004L,7323666065305L,7329286557005L,7404796377505N,7416399462004L,7504773871505N,7568575989904L,7616848054704L,7676374260004L,7704920121702L,7722125470704L,7777591439204N,7784875867905L,7819914965404L,7842241038604L,7855839188504L,7946232830004N,7944105295502N,7976025169505L,7988229286104N,8021701264705L,8041888547102N,8176122942502N,8206312033405N,8214793343404L,8218674309304L,8236474988104N,8234344257604N,8277422494904N,8286258083904N,8291752905405N,8499740672605N,8490595200204N,8542998030904L,8559205384005N,8614749494405N,8734302465604N,8737665913504L,8789370608903L,8793382389104L,8882695002304L,8963892151802L,9000809139702L,9039772659205L,9091001457804L,9150403859405L,9166440454004L,9177097704002N,9181916698805L,9410566018705L,9422917101105N,9510197111505L,9531923682305N,9653826044104N,9689064552404L,9705326396305L,9871976521505N,9897662272004N,1035931836804L,1042286795505L,1083494147304L,1084357232002L,1123781469004L,1157286395404N,1194261150505L,1209074930905L,1237942215205L,1291041131205N,1320540397505L,1398390716104N,1422150871901N,1476106734604L,1497775435605L,1520307779405L,1536174513702N,1535715535504L,1593838503104L,1704723663504N,1741559179904N,1754947660604L,1784186971805N,1867848329605L,1889898684704N,1929971629601N,1925078407504L,2002057677605N,2018377792305L,2013665558401L,2035530406104N,2080414788102N,2105231386505L,2137623557305N,2171269207105L,2224948504702N,2243054845804L,2251321020404L,2263422367804L,2310696746204L,2339544883005L,2424457743502N,2452933003004L,2522139755805L,2634167878605L,2632551973905N,2644609728004L,2643528425104L,2653149326305L,2662321279105L,2736667975504L,2742797848505L,2829991786505N,2868766784904N,2922267970602L,2969091268302N,3016927730805N,3013042747605L,3029959060704N,3085848276805L,3158385893505L,3205426168205N,3215429590804L,3234805205605L,3247533652102L,3249800617105L,3304291339805N,3333955578805N,3422217996405L,3427781886301L,3494073769205L,3513009448805L,3621390687705L,3647293314505L,3818497471705L,3855445273705L,3895332077404N,3944298359304N,3958509425802N,3974342008205N,4078351309504L,4082262878804L,4162276105505L,4216326282505L,4242169665004L,4257118673705N,4264636416405L,4344369050405L,4378957343005N,4427272129704N,4475409766601L,4484747897204L,4527868077904L,4572233891105L,4583387819904L,4654679375105L,4698220946604N,4784560352904L,4840847293602L,4896193116004N,5000340061602N,5010420464004L,5016245866404L,5022414985204N,5111130638605L,5130381020105N,5169822287405L,5363496840205L,5385512978505L,5451864785005N,5540524638504L,5540018396505L,5570213690005L,5589638672804L,5598871912005L,5595904063705N,5610915894105N,5623128093904N,5621062617604N,5846485061304L,5850457845104N,5933431810504L,5976289438204N,5980151222204N,5987757895204L,6177255142602N,6270934522105N,6312098115604N,6321233568105N,6324643106004L,6352994008605N,6361154778704N,6364129800004N,6387814300505L,6486946155205N,6561507554905L,6641848144804N,6654112341705N,6725383631705L,6779008240205L,6783313430105L,6793377490705N,6944779327005L,6988576769405L,7205376459404N,7276406602804L,7347645103105L,7363839064904N,7389697105304N,7396526963904L,7452658428604L,7473967152104L,7494222752105L,7496856849205L,7531039075002N,7534083194705L,7562053690304L,7585567090705L,7725609845705N,7840257724004N,7852140290805L,7896180069605L,7921377753204N,7924853130005L,7941776529804L,8004775942104L,8029041440605N,8034801621805L,8087738776205L,8092282846004L,8148340851905N,8256713525804L,8386798548204N,8404804502105L,8506051433104L,8521067422904L,8538226827805L,8545040591104L,8563337282204N,8647386059704N,8649159507704L,8645555931304L,8676294854104N,8764864299204L,8881780503205L,8947483649404N,8993968074905L,9003099807104L,9040010011205L,9135942479604N,9150291235505L,9205145065305L,9258471860804N,9286090940004L,9353590595004L,9429803290105L,9491118342905L,9503069284005N,9596469987305L,9700464521905L,9710270203005L,9736825683605L,9887081741705N,9899286534305L,9924340261604N', ','))),

wt AS (
  SELECT column1 AS plat, column2 AS w_ja4, column3 AS w_scr, column4 AS w_dp, column5 AS w_ua, column6 AS w_gl
  FROM VALUES ('Windows',0.10,0.15,0.30,0.15,0.30), ('macOS',0.15,0.35,0.15,0.20,0.15),
              ('Linux',0.25,0.20,0.25,0.15,0.15),   ('ChromeOS',0.15,0.20,0.25,0.15,0.25),
              ('Android',0.05,0.30,0.05,0.20,0.40), ('iOS',0.15,0.40,0.05,0.30,0.10)
),
sess_raw AS ( SELECT s.session, s.di_dictionary_num_matched_at_session_created AS d, s.di_highest_signature_at_session_created AS h,
    s.latest_risk_band AS risk, (s.sessions_verified > 0) AS verified, (s.sessions_verify_attempted > 0) AS va,
    (s.was_challenged > 0) AS ch, (s.sessions_solved > 0) AS solved, lab.l AS lab
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY s LEFT JOIN lab ON lab.k = LEFT(s.session,3)||RIGHT(s.session,10)
  WHERE s.public_key = 'A207F8A1-ED09-4325-ACE6-C8E26A458FBA'
    AND s.session_last_timestamp >= '2026-11-06 06:00:00' AND s.session_last_timestamp < '2026-11-07 06:00:00'
    AND s.session_ts >= '2026-11-06 06:00:00' AND s.session_ts < '2026-11-06 09:00:00' ),   -- columns: session, d, h, risk, verified, va, ch, solved
wl_raw AS ( SELECT di_highest_signature_at_session_created AS h, COUNT(*) AS n
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE public_key IN ('A207F8A1-ED09-4325-ACE6-C8E26A458FBA','955D26AF-E956-4106-A4EF-2F63304776D9')
    AND session_last_timestamp >= '2026-10-30 00:00:00' AND session_last_timestamp < '2026-11-06 06:00:00'
    AND session_ts >= '2026-10-30 00:00:00' AND session_ts < '2026-11-06 00:00:00'
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
wl AS (SELECT k.*, r.n AS wn FROM k JOIN wl_raw r ON r.h = k.h),
pgt AS (SELECT pg, SUM(wn) AS pgn FROM wl GROUP BY pg),
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
ref AS (SELECT x.value::NUMBER AS kk, SUM(wl.wn) AS cnt FROM wl, LATERAL FLATTEN(wl.ks) x GROUP BY 1),
seen AS (
  SELECT q.h, ARRAY_AGG(r.kk IS NOT NULL) WITHIN GROUP (ORDER BY q.i) AS z, ARRAY_AGG(COALESCE(r.cnt, 0)) WITHIN GROUP (ORDER BY q.i) AS zc
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
         WHEN z[19]::BOOLEAN THEN 'seen' WHEN s.osv_num > l.mx THEN 'newer than newest seen' ELSE 'older, not seen (warning)' END AS osv_status,
    -- v4 pair frequencies (share of the platform group's whitelist sessions; NULL = not applicable)
    pt.pgn AS pgn,
    IFF(s_uac AND s_dp, zc[17]::NUMBER / pt.pgn, NULL) AS fuc,
    IFF(s_uac AND s_dp AND s_ua AND zc[17]::NUMBER > 0, zc[14]::NUMBER / pt.pgn, NULL) AS fux,
    IFF(s_sp AND s_dp, zc[24]::NUMBER / pt.pgn, NULL) AS fsc,
    IFF(s_sp AND s_dp AND zc[24]::NUMBER > 0, zc[22]::NUMBER / pt.pgn, NULL) AS fsx,
    IFF(s.hw_gl AND s_sp AND s_gl, zc[23]::NUMBER / pt.pgn, NULL) AS fsg,
    IFF(s.sp_ok AND z[21]::BOOLEAN, zc[20]::NUMBER / pt.pgn, NULL) AS fsp,
    -- v4 rare flags (coarse seen but below the cut-off at the coarse or the exact level)
    (fuc > 0 AND (fuc < 1e-12 OR COALESCE(fux < 1e-12, FALSE))) AS r_ua_dp,
    (fsc > 0 AND (fsc < IFF(s.pg = 'Mobile', 1e-4, 1e-12) OR COALESCE(fsx < 1e-12, FALSE))) AS r_scr_dp,
    (fsg > 0 AND fsg < 1e-12) AS r_scr_gl,
    (fsp > 0 AND fsp < IFF(s.pg = 'Mobile', 1e-4, 1e-12)) AS r_scr_pg
  FROM st s JOIN seen USING (h) LEFT JOIN best b ON b.h = s.h LEFT JOIN omx o ON o.osf = s.osf LEFT JOIN lmx l ON l.line = s.line
  LEFT JOIN pgt pt ON pt.pg = s.pg
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
    IFF(t3 AND NOT no_score,'D',sb3) AS band,
    -- v4: same failed checks as v3 (nfail); warning signs = rare pairs (one per pair) + desktop never-seen screen / DP
    IFF(r_ua_dp,1,0)+IFF(r_scr_dp,1,0)+IFF(r_scr_gl,1,0)+IFF(r_scr_pg,1,0) AS nrare,
    IFF(mob2, nrare, nrare + IFF(h_w_scr,1,0) + IFF(p_dp_new,1,0)) AS nwarn4,
    IFF(mob2, nfail >= 1, nfail >= 2 OR (nfail >= 1 AND nwarn4 >= 1)) AS t4v,
    IFF(t4v AND NOT no_score,'D',sb3) AS band4,
    -- what-if triggers (desktop only; mobile = t4v)
    t4v OR (NOT mob2 AND g_ua_dp) AS ta,
    t4v OR (NOT mob2 AND nwarn4 >= 2) AS tb,
    nfail - IFF(h_scr_gl AND NOT mob2,1,0) AS nfail_c, nwarn4 + IFF(h_scr_gl AND NOT mob2,1,0) AS nwarn_c,
    IFF(mob2, nfail >= 1, nfail_c >= 2 OR (nfail_c >= 1 AND nwarn_c >= 1)) AS tc,
    IFF(mob2, nfail >= 1, nfail_c >= 2 OR (nfail_c >= 1 AND nwarn_c >= 1) OR g_ua_dp OR nwarn_c >= 2) AS tabc,
    IFF(ta AND NOT no_score,'D',sb3) AS band_a, IFF(tb AND NOT no_score,'D',sb3) AS band_b,
    IFF(tc AND NOT no_score,'D',sb3) AS band_c, IFF(tabc AND NOT no_score,'D',sb3) AS band_abc
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
      IFF(MOD(FLOOR(code3/18),2)=0,'DP',NULL), IFF(MOD(FLOOR(code3/36),2)=0 AND NOT basic,'GL',NULL)), '+')) AS reason,
    -- v4 warning signs and reason
    ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(h_w_scr AND NOT mob2,'SCRnew',NULL), IFF(p_dp_new AND NOT mob2,'DPnew',NULL),
      IFF(r_ua_dp,'UAxDPr',NULL), IFF(r_scr_dp,'SCRxDPr',NULL), IFF(r_scr_gl,'SCRxGLr',NULL), IFF(r_scr_pg,'SCRxPGr',NULL)), ' ') AS warns4,
    IFF(t4v, 'chk:'||fails3||IFF(warns4<>'',' +'||REPLACE(warns4,' ',' +'),''),
      'diff:'||ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(CASE MOD(code3,3) WHEN 1 THEN 'JA4qt' WHEN 0 THEN 'JA4' END,
      CASE MOD(FLOOR(code3/3),3) WHEN 1 THEN 'UAmaj' WHEN 0 THEN 'UA' END, IFF(MOD(FLOOR(code3/9),2)=0,'SCR',NULL),
      IFF(MOD(FLOOR(code3/18),2)=0,'DP',NULL), IFF(MOD(FLOOR(code3/36),2)=0 AND NOT basic,'GL',NULL)), '+')) AS reason4
  FROM sess_raw r JOIN t ON t.h = r.h
)
, g AS (SELECT r.session, r.d, r.risk, r.verified, r.ch, r.solved, COALESCE(r.lab,'-') AS lab, t.*, IFF(t.pg='Mobile','mob','desk') AS md, IFF(band4='no score','n',band4) AS b0, IFF(band_abc='no score','n',band_abc) AS b1, (t4v AND NOT no_score) AS tr0, (tabc AND NOT no_score) AS tr1, IFF(g_ua_dp AND NOT mob2,'a','')||IFF(nwarn_c>=2 AND NOT mob2,'b','') AS ab, ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(CASE MOD(code3,3) WHEN 1 THEN 'JA4qt' WHEN 0 THEN 'JA4' END, CASE MOD(FLOOR(code3/3),3) WHEN 1 THEN 'UAmaj' WHEN 0 THEN 'UA' END, IFF(MOD(FLOOR(code3/9),2)=0,'SCR',NULL), IFF(MOD(FLOOR(code3/18),2)=0,'DP',NULL), IFF(MOD(FLOOR(code3/36),2)=0 AND NOT basic,'GL',NULL)),'+') AS diff, ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(g_ua_dp,'UAxDP',NULL), IFF(h_scr_dp,'SCRxDP',NULL), IFF(h_scr_gl,'SCRxGL',NULL), IFF(h_scr_pg,'SCRxPG',NULL), IFF(p_dp_new AND mob2,'DPnew',NULL)),' ') AS fl, ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(IFF(h_w_scr AND NOT mob2,'SCRnew',NULL), IFF(p_dp_new AND NOT mob2,'DPnew',NULL), IFF(r_ua_dp,'UAxDPr',NULL), IFF(r_scr_dp,'SCRxDPr',NULL), IFF(r_scr_gl,'SCRxGLr',NULL), IFF(r_scr_pg,'SCRxPGr',NULL)),' ') AS wn, IFF(diff LIKE '%+%','multi',diff) AS dg, LEAST(nfail,2) AS nf2, LEAST(nwarn4,3) AS nw3 FROM sess_raw r JOIN t ON t.h = r.h)
SELECT r FROM (
SELECT 'M#'||(SELECT COUNT(*) FROM lab)||'|'||COUNT_IF(lab<>'-')||'|'||COUNT_IF(lab='L')||'|'||COUNT_IF(lab='N')||'|'||COUNT(*)||'|'||COUNT_IF(verified) AS r FROM g
UNION ALL SELECT 'X#'||LISTAGG(x,';') WITHIN GROUP (ORDER BY x) FROM (SELECT d||'|'||b0||b1||'|'||lab||'|'||COUNT(*)||'|'||COUNT_IF(risk='High')||'|'||COUNT_IF(verified)||'|'||COUNT_IF(ch)||'|'||COUNT_IF(ch AND NOT COALESCE(solved,FALSE)) AS x FROM g GROUP BY d, b0, b1, lab)
UNION ALL SELECT 'G3#'||LISTAGG(x,';') WITHIN GROUP (ORDER BY x) FROM (SELECT md||'|'||IFF(tr0,'D','p')||IFF(tr1,'D','p')||'|'||lab||'|'||COUNT(*)||'|'||COUNT_IF(risk='High') AS x FROM g GROUP BY md, tr0, tr1, lab)
UNION ALL SELECT 'G1#'||LISTAGG(x,';') WITHIN GROUP (ORDER BY x) FROM (SELECT d||'|'||dg||'|'||COUNT(*)||'|'||COUNT_IF(b0 IN ('A','B'))||'|'||COUNT_IF(b1 IN ('A','B'))||'|'||COUNT_IF(risk='High') AS x FROM g WHERE d IN (1,3) GROUP BY d, dg)
UNION ALL SELECT 'ADD#'||LISTAGG(x,';') WITHIN GROUP (ORDER BY x) FROM (SELECT md||'|'||ab||'|'||fl||'|'||nwarn_c||'|'||lab||'|'||COUNT(*)||'|'||COUNT_IF(risk='High') AS x FROM g WHERE b0<>'D' AND b1='D' GROUP BY md, ab, fl, nwarn_c, lab)
UNION ALL SELECT 'WF#'||LISTAGG(x,';') WITHIN GROUP (ORDER BY x) FROM (SELECT md||'|f'||nf2||'|w'||nw3||'|'||lab||'|'||COUNT(*)||'|'||COUNT_IF(risk='High') AS x FROM g WHERE NOT no_score GROUP BY md, nf2, nw3, lab)
) ORDER BY r
