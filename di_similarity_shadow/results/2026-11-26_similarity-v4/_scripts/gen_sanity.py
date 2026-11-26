import sys
sys.path.insert(0,'.')
from build import build, R, EPS, minify
v2=open(R+'../2026-11-25_layer-1-v2/sanity_test_v2.sql').read().split('\n')
start=[i for i,l in enumerate(v2) if l.startswith('WITH raw AS')][0]
rows=v2[start:start+27]   # WITH raw ... through w9 row
assert rows[-1].endswith("16,16,16,16')),"), rows[-1]
rows[-1]=rows[-1][:-2]+','
MACUA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Safari/605.1.15'
MACDP='MacIntel::0::1::30::10::1::1::0::1::0::0::0::M1M1M'
MACGL='~cApple M2::16,16,16,16'
new=[
# item 6: available size differs, physical size seen
"('s','macOS 9 [item 6] window resized (avail differs, physical seen)','OS X::10.15.7||t13d2014h2_a09f3c656075_14788d8d241b||1512,862::1512,982||%s||%s||%s')"%(MACDP,MACUA,MACGL),
"('s','Windows 9 [item 6] resized window + coarse UAxDP fail','Windows::10||t13d1516h2_8daaf6152771_02713d6af862||1920,1040::1920,1080||Win32::0::1::24::8~e0::0::0::AAAAA||Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101 Firefox/150.0||~c~d::16,16,16,16')",
# item 5: coarse fail + exact-only warning; two exact-only warnings alone
"('s','Windows 10 [item 5] coarse UAxDP fail + exact-only SCRxDP warning','Windows::10||t13d1516h2_8daaf6152771_02713d6af862||1920,1032::1920,1080||Win32::0::1::24::8~e0::0::0::FFFFF||Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101 Firefox/150.0||~c~d::16,16,16,16')",
"('s','Windows 11 [item 5] two exact-only warnings, no failed check','Windows::10||t13d1516h2_8daaf6152771_02713d6af862||1920,1032::1920,1080||Win32::0::1::24::8~e0::0::0::FFFFF||~a||~c~d::16,16,16,16')",
# item 9: two unparsed UAs; empty screen
"('s','macOS 10 [item 9] all but UA, both UAs unparsed','OS X::10.15.7||t13d1516h2_8daaf6152771_02713d6af862||1440,875::1440,900||MacIntel::0::1::24::8::1::1::0::1::0::0::0::M2M2M||SomeApp/1.0 (Macintosh)||~cApple M1::16,16,16,16')",
"('s','Windows 12 [item 9] everything matches, both screens empty','Windows::10||t13d1516h2_8daaf6152771_02713d6af862||::||Win32::0::1::24::12~e0::0::0::EEEEE||~a||~c~d::16,16,16,16')",
"('w','w10','Windows::10||t13d0000h2_gggggggggggg_gggggggggggg||800,600::800,600||Win32::0::1::24::8~e0::0::0::FFFFF||Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36||~cANGLE (AMD, Radeon RX 580)::16,16,16,16')",
"('w','w11','OS X::10.15.7||t13d2014h2_a09f3c656075_14788d8d241b||1512,945::1512,982||%s||%s||%s')"%(MACDP,MACUA,MACGL),
"('w','w12','OS X::10.15.7||t13d1516h2_8daaf6152771_02713d6af862||1440,875::1440,900||MacIntel::0::1::24::8::1::1::0::1::0::0::0::M2M2M||OtherApp/2.0 (Macintosh)||~cApple M1::16,16,16,16')",
"('w','w13','Windows::10||t13d1516h2_8daaf6152771_02713d6af862||::||Win32::0::1::24::12~e0::0::0::EEEEE||~a||~c~d::16,16,16,16'))",
]
rows[0]=rows[0][5:]
raw='\n'.join(rows+[r+',' for r in new[:-1]]+[new[-1]])+',\n'
sess="SELECT session, 0 AS d, h, NULL AS risk, NULL AS verified, NULL AS va, NULL AS ch, NULL AS solved FROM raw WHERE kind = 's'"
wl="SELECT h, 1 AS n FROM raw WHERE kind = 'w'"
tail="""SELECT LEFT(session,14)||'|'||ROUND(score3,3)||'|'||band||band4||'|'||nfail||'|'||nwarn||'/'||nwarn4||'|'||warns4||'|'||pgn||':'||COALESCE(ROUND(fuc*pgn)::VARCHAR,'-')||','||COALESCE(ROUND(fux*pgn)::VARCHAR,'-')||','||COALESCE(ROUND(fsc*pgn)::VARCHAR,'-')||','||COALESCE(ROUND(fsx*pgn)::VARCHAR,'-')||','||COALESCE(ROUND(fsg*pgn)::VARCHAR,'-')||','||COALESCE(ROUND(fsp*pgn)::VARCHAR,'-')||'|'||IFF(ta,'a','')||IFF(tb,'b','')||IFF(tc,'c','')||IFF(tabc,'X','') AS r FROM res ORDER BY session
"""
hdr="""-- Similarity v4 sanity test: the 22 hand-built rows of ../2026-11-25_layer-1-v3/sanity_test_v3.sql (14 spec.md worked examples,
-- 2 v2 rows, 6 v3 rows) and its 14-row whitelist (n = 1 each), unchanged, run through _core_template_v4.sql twice:
--   EPS run: every cut-off = 1e-12, so "rare" = exact pair never seen only  -> v4 band must equal v3 band on every row.
--   HALF run: every cut-off = 0.5 (any pair on fewer than half the group's whitelist sessions is rare) -> exercises the rare flags.
-- Output: session | v3 score | v3 band, v4 band | failed checks | warnings v3/v4 | v4 warnings | whitelist sessions in group:
--   pair counts UAxDP coarse, exact, SCRxDP coarse, exact, SCRxGL, SCRxPG ('-' = not applicable) | what-if triggers fired (a, b, c, X=abc)
"""
for nm,cuts in [('EPS',EPS),('HALF',{k:'0.5' for k in EPS})]:
    sql=hdr+'-- Run: '+nm+'\n'+build(raw,sess,wl,tail,cuts)
    open(R+'sanity_test_v4_'+nm.lower()+'.sql','w').write(sql)
    m='EXECUTE IMMEDIATE $$'+minify(sql)+'$$'
    open(__import__('os').environ.get('SCRATCH','/tmp/')+'san_'+nm.lower()+'.sql','w').write(m); print(nm,len(m))
