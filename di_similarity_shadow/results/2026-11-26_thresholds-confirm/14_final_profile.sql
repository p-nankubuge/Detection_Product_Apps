-- {FINAL} for 11_: one compact row per session matching {COND} (profile of a weak spot).
-- Output: time|dict|group|matched signature id (first 6 hex of MD5)|ST count|limit m5 f11 (= max(11, expected x 5 x d))|expected|share x 1e4|High|verified|challenged|
--   challenged-not-solved|clean|IP|ASN|ISP|OS|UA (browser token)|today ST breached
SELECT TO_CHAR(ts,'HH24:MI')||'|'||d||'|'||grp||'|'||LEFT(MD5(ms),6)||'|'||stc||'|'||ROUND(GREATEST(11,share*vol*5*dfac),1)||'|'||ROUND(share*vol,2)||'|'||ROUND(share*1e4,2)
  ||'|'||hi||'|'||ver||'|'||chl||'|'||chns||'|'||cl||'|'||COALESCE(ip,'')||'|'||COALESCE(asn::STRING,'')||'|'||LEFT(COALESCE(isp,''),24)||'|'||COALESCE(os,'')
  ||'|'||COALESCE(REGEXP_SUBSTR(ua,'(Edg|OPR|Firefox|Chrome|Version)/[0-9]+'),'')||'|'||r0 r
FROM s4 WHERE {COND} ORDER BY ts
