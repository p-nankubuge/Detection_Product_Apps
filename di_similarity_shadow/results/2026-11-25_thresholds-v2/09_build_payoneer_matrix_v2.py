# v2 (D-11) per-key matrices for the 3 Payoneer keys from 08_payoneer_key_base.sql. Same rule as 03_build_matrix_v2.py:
# key cell if >= 500 clean sig-windows; else (a) key x dict pooled if >= 500 (capped at the key's current ST/LT); else (b) current.
# Prints one line per cell and the VALUES list (k8, d, grp, ST, LT) for 10_replay_L1_payoneer_v2.sql.
raw = """EE844FC3|-1|ALL|152|17.5 EE844FC3|-1|Desktop|92|19.3 EE844FC3|-1|Mobile|72|10.0 EE844FC3|-1|Other|29|3.4
EE844FC3|1|ALL|2192|12.1 EE844FC3|1|Desktop|315|13.0 EE844FC3|1|Linux|1|1.0 EE844FC3|1|Mobile|1779|12.0 EE844FC3|1|Other|95|5.1 EE844FC3|1|WinRDVM|2|1.0
EE844FC3|3|ALL|17085|189.2 EE844FC3|3|Desktop|4587|231.0 EE844FC3|3|Linux|413|136.0 EE844FC3|3|Mobile|11723|115.0 EE844FC3|3|Other|320|20.1 EE844FC3|3|WinRDVM|377|68.7
EE844FC3|7|ALL|76876|41.0 EE844FC3|7|Desktop|51752|49.0 EE844FC3|7|Linux|2535|16.7 EE844FC3|7|Mobile|21256|10.0 EE844FC3|7|WinRDVM|5866|12.0
EE844FC3|15|ALL|234665|39.0 EE844FC3|15|Desktop|96808|12.0 EE844FC3|15|Linux|3459|11.0 EE844FC3|15|Mobile|130173|53.0 EE844FC3|15|WinRDVM|6815|8.9
EE844FC3|31|ALL|106780|19.0 EE844FC3|31|Desktop|82512|19.0 EE844FC3|31|Linux|1748|13.5 EE844FC3|31|Mobile|19822|14.0 EE844FC3|31|WinRDVM|7452|8.0
EE844FC3|63|ALL|257431|51.0 EE844FC3|63|Desktop|62443|15.0 EE844FC3|63|Linux|857|8.4 EE844FC3|63|Mobile|190035|148.7 EE844FC3|63|WinRDVM|4096|12.0
E3EFEFBF|-1|ALL|27|7.7 E3EFEFBF|-1|Desktop|5|6.9 E3EFEFBF|-1|Mobile|22|7.8
E3EFEFBF|1|ALL|177|7.0 E3EFEFBF|1|Desktop|11|3.9 E3EFEFBF|1|Mobile|149|7.0 E3EFEFBF|1|Other|17|6.8
E3EFEFBF|3|ALL|4295|73.0 E3EFEFBF|3|Desktop|1141|35.0 E3EFEFBF|3|Linux|211|27.9 E3EFEFBF|3|Mobile|2894|80.0 E3EFEFBF|3|Other|49|6.5 E3EFEFBF|3|WinRDVM|111|11.0
E3EFEFBF|7|ALL|13711|14.0 E3EFEFBF|7|Desktop|7903|15.0 E3EFEFBF|7|Linux|528|10.0 E3EFEFBF|7|Mobile|4953|10.0 E3EFEFBF|7|WinRDVM|624|7.0
E3EFEFBF|15|ALL|44209|15.0 E3EFEFBF|15|Desktop|10966|8.0 E3EFEFBF|15|Linux|648|9.0 E3EFEFBF|15|Mobile|32077|16.0 E3EFEFBF|15|WinRDVM|563|7.0
E3EFEFBF|31|ALL|23405|11.0 E3EFEFBF|31|Desktop|14129|9.7 E3EFEFBF|31|Linux|331|7.7 E3EFEFBF|31|Mobile|8284|12.0 E3EFEFBF|31|WinRDVM|810|7.0
E3EFEFBF|63|ALL|49746|21.0 E3EFEFBF|63|Desktop|9668|10.0 E3EFEFBF|63|Linux|126|9.0 E3EFEFBF|63|Mobile|39395|23.0 E3EFEFBF|63|WinRDVM|557|8.4
7CC24C4A|-1|ALL|13|5.6 7CC24C4A|-1|Desktop|8|2.0 7CC24C4A|-1|Mobile|5|5.9
7CC24C4A|1|ALL|26|10.5 7CC24C4A|1|Desktop|1|1.0 7CC24C4A|1|Mobile|24|10.6 7CC24C4A|1|Other|1|2.0
7CC24C4A|3|ALL|1028|27.0 7CC24C4A|3|Desktop|514|12.9 7CC24C4A|3|Linux|102|19.0 7CC24C4A|3|Mobile|408|29.9 7CC24C4A|3|Other|3|1.0 7CC24C4A|3|WinRDVM|15|3.9
7CC24C4A|7|ALL|2502|9.0 7CC24C4A|7|Desktop|1751|9.0 7CC24C4A|7|Linux|86|7.2 7CC24C4A|7|Mobile|585|7.2 7CC24C4A|7|WinRDVM|107|15.8
7CC24C4A|15|ALL|4269|8.3 7CC24C4A|15|Desktop|1842|7.0 7CC24C4A|15|Linux|110|6.8 7CC24C4A|15|Mobile|2241|9.0 7CC24C4A|15|WinRDVM|77|9.7
7CC24C4A|31|ALL|4767|8.0 7CC24C4A|31|Desktop|2952|8.0 7CC24C4A|31|Linux|58|6.4 7CC24C4A|31|Mobile|1629|10.0 7CC24C4A|31|WinRDVM|139|10.5
7CC24C4A|63|ALL|6384|11.0 7CC24C4A|63|Desktop|2097|7.0 7CC24C4A|63|Linux|19|7.8 7CC24C4A|63|Mobile|4180|12.0 7CC24C4A|63|WinRDVM|88|6.1"""
cells={}
for t in raw.split():
    k,d,g,n,p=t.split('|'); cells[(k,int(d),g)]=(int(n),float(p))
cur={'EE844FC3':(35,2100),'E3EFEFBF':(15,900),'7CC24C4A':(60,3600)}
mult={-1:(1,1),1:(1,1),3:(1,1),7:(1.5,2),15:(2,4),31:(2,4),63:(2,6)}
MIN=500; vals=[]
for k in cur:
  for d in [-1,1,3,7,15,31,63]:
    for g in ['Desktop','Mobile','Linux','WinRDVM','Other']:
      ms,ml=mult[d]
      if g=='WinRDVM': ms,ml=min(ms,1.5),min(ml,2)
      kc=cells.get((k,d,g),(0,None)); pc=cells.get((k,d,'ALL'),(0,None))
      if kc[0]>=MIN: src='key'; st=round(kc[1]*ms,2); lt=round(kc[1]*ml*60,1)
      elif pc[0]>=MIN: src='(a)'; st=min(round(pc[1]*ms,2),cur[k][0]); lt=min(round(pc[1]*ml*60,1),cur[k][1])
      else: src='(b)'; st,lt=cur[k]
      vals.append(f"('{k}',{d},'{g}',{st},{lt})")
      print(f"{k}|{d}|{g}|key={kc}|pool={pc}|{src}|ST={st}|LT={lt}")
print(','.join(vals))
