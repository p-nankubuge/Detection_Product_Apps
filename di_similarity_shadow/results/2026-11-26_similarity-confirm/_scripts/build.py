import sys, re
R='/home/user/Detection_Product_Apps/di_similarity_shadow/results/2026-11-26_similarity-confirm/'
def strip_comments(sql):
    out=[];i=0;inq=False
    while i<len(sql):
        ch=sql[i]
        if inq:
            out.append(ch)
            if ch=="'": inq=False
            i+=1; continue
        if ch=="'": inq=True; out.append(ch); i+=1; continue
        if sql.startswith('--',i):
            j=sql.find('\n',i); i=len(sql) if j<0 else j; continue
        out.append(ch); i+=1
    return ''.join(out)
def minify(sql):
    s=strip_comments(sql)
    # collapse whitespace outside quotes
    out=[];inq=False;prev_sp=False
    for ch in s:
        if inq:
            out.append(ch)
            if ch=="'": inq=False
            continue
        if ch=="'": inq=True; out.append(ch); prev_sp=False; continue
        if ch.isspace():
            if not prev_sp: out.append(' ')
            prev_sp=True
        else: out.append(ch); prev_sp=False
    return ''.join(out).strip()
EPS={'CUT_UADP_C':'1e-12','CUT_UADP_X':'1e-12','CUT_SCRDP_C':'1e-12','CUT_SCRDP_X':'1e-12','CUT_SCRGL':'1e-12','CUT_SCRPG':'1e-12'}
def build(pre, sess, wl, tail, cuts=EPS):
    core=open(R+'_core_template_v4.sql').read()
    for k,v in cuts.items(): core=core.replace('{'+k+'}',str(v))
    assert '{CUT' not in core
    return core.replace('{PRE}',pre).replace('{SESS_RAW}',sess).replace('{WL_RAW}',wl)+tail
if __name__=='__main__':
    src=sys.argv[1]; dst=sys.argv[2]
    open(dst,'w').write('EXECUTE IMMEDIATE $$'+minify(open(src).read())+'$$')
    print(len(open(dst).read()))
