import sys, re
R='/home/user/Detection_Product_Apps/di_similarity_shadow/results/2026-11-25_layer-1-v3/'
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
def build(pre, sess, wl, tail):
    core=open(R+'_core_template_v3.sql').read()
    return core.replace('{PRE}',pre).replace('{SESS_RAW}',sess).replace('{WL_RAW}',wl)+tail
if __name__=='__main__':
    src=sys.argv[1]; dst=sys.argv[2]
    open(dst,'w').write('EXECUTE IMMEDIATE $$'+minify(open(src).read())+'$$')
    print(len(open(dst).read()))
