-- Shared per-session CTE (pasted into every query). Source ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY.
-- Platform group = similarity-scorer "Seen-before rules" item 1 (List A/B/C sessions skipped, so no software renderer
-- reaches a group). Renderer = WEBGL_UNMASKED_RENDERER_AT_SESSION_CREATED; OS = OS_AT_SESSION_CREATED.
-- A NULL/empty renderer is grouped by OS (as the layer-1 scorer code does: only software / Basic Render change the group).
--   List A: renderer SwiftShader / llvmpipe / VirtualBox / VMware (any OS)
--   List B: iOS/iPadOS/OS X/Android + SwiftShader|llvmpipe (already in A); Windows + llvmpipe (in A);
--           non-Windows + Microsoft Basic Render Driver; no OS ('', NULL, '--') with a non-empty renderer
--   List C (not on proxy keys; needs a JA4): C1 TCP JA4 with cipher hash a09f3c656075|2802a3db6c62 and OS Windows/Linux/ChromeOS;
--           C2 Chromium UA ('Chrome/' in UA) with JA4 ALPN h1; C3 Chrome major >= 70 with JA4 starting 't12'
-- x = 'A','B','C' (first list hit, in that order) or NULL; grp = Desktop / Mobile / Linux / WinRDVM / Other.
s0 AS (
  SELECT session, public_key k, session_ts ts, di_dictionary_num_matched_at_session_created d,
    di_matched_signature_at_session_created ms, os_at_session_created os, COALESCE(webgl_unmasked_renderer_at_session_created,'') r,
    COALESCE(cdn__ja4_hash_at_session_created,'') ja4, COALESCE(ua_at_session_created,'') ua,
    IFF(latest_risk_band='High',1,0) hi, IFF(sessions_verified>0,1,0) ver, IFF(was_challenged>0,1,0) chl,
    IFF(was_challenged>0 AND COALESCE(sessions_solved,0)=0,1,0) chns,
    di_short_term_count_at_session_created stc, di_long_term_count_at_session_created ltc,
    di_short_term_threshold_ratio_at_session_created str, di_long_term_threshold_ratio_at_session_created ltr,
    IFF(di_short_term_threshold_breached_at_session_created,1,0) stb, IFF(di_long_term_threshold_breached_at_session_created,1,0) ltb
  FROM ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY
  WHERE {FILTER}
),
s1 AS (
  SELECT s0.*,
    CASE WHEN r ILIKE '%SwiftShader%' OR r ILIKE '%llvmpipe%' OR r ILIKE '%VirtualBox%' OR r ILIKE '%VMware%' THEN 'A'
         WHEN r ILIKE '%Basic Render Driver%' AND COALESCE(os,'')<>'Windows' THEN 'B'
         WHEN COALESCE(os,'') IN ('','--') AND r<>'' THEN 'B'
         WHEN {PROXY} THEN NULL
         WHEN ja4 LIKE 't%' AND SPLIT_PART(ja4,'_',2) IN ('a09f3c656075','2802a3db6c62') AND os IN ('Windows','GNU/Linux','Ubuntu','Chrome OS') THEN 'C'
         WHEN ua LIKE '%Chrome/%' AND RIGHT(SPLIT_PART(ja4,'_',1),2)='h1' THEN 'C'
         WHEN TRY_TO_NUMBER(REGEXP_SUBSTR(ua,'Chrome/([0-9]+)',1,1,'e',1))>=70 AND ja4 LIKE 't12%' THEN 'C' END AS x,
    CASE WHEN r ILIKE '%Basic Render Driver%' AND os='Windows' THEN 'WinRDVM'
         WHEN os IN ('Windows','OS X','Chrome OS') THEN 'Desktop' WHEN os IN ('iOS','iPadOS','Android') THEN 'Mobile'
         WHEN os IN ('GNU/Linux','Ubuntu') THEN 'Linux' ELSE 'Other' END AS grp
  FROM s0
)
