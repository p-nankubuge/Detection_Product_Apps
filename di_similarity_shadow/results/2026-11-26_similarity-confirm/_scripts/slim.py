import re
def drop_items(m, names):
    """remove ', <expr> AS name' items from SELECT lists (expr has balanced parens, no top-level comma)"""
    for nm in names:
        pat=' AS '+nm+','
        pat2=' AS '+nm+' '
        k=m.find(pat)
        if k<0: k=m.find(pat2)
        assert k>=0, nm
        # walk back to the comma that starts this item at depth 0
        depth=0; i=k-1; inq=False
        while i>0:
            ch=m[i]
            if ch=="'": inq=not inq
            elif not inq:
                if ch==')': depth+=1
                elif ch=='(':
                    if depth==0: break
                    depth-=1
                elif ch==',' and depth==0: break
            i-=1
        end=k+len(' AS '+nm)
        if m[i]==',': m=m[:i]+m[end:]
        else: m=m[:i+1]+m[end+1:].lstrip()   # first item after '(' : drop trailing comma
    return m
SLIM_COLS=['pk_s1','pk1','score1','code1','sb1','p_ua_dp','p_scr_dp','p_scr_gl','p_scr_pg','w_scr1','c_ua_dp','c_scr_dp',
  'g_scr_dp','g_scr_gl','g_scr_pg','g_w_scr','scr_seen_pg','sp_seen_pg','osv_status','n3x','n4','t4','band_v2','ng','tg','bs1','bs2','th','bs3','sg']
def slim_exec(m):
    m=drop_items(m, SLIM_COLS)
    m=m.replace(" LEFT JOIN lmx l ON l.line = s.line","")
    i=m.index(", lv AS ("); j=m.index(", c AS (",i); m=m[:i]+m[j:]
    return m
