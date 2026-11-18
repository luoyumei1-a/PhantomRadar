"""Direct standardization on exactly observed total count; descriptive only."""
import csv,json
from collections import Counter
from pathlib import Path
root=Path(__file__).resolve().parent
def read(n):
    with (root/n).open() as f: return list(csv.DictReader(f))
a=[(int(r['number']),int(r['leg'])==0) for r in read('regional_ambiguity_records.csv') if r['cohort']=='A']
n=[(int(r['native_n']),int(r['native_leg'])==0) for r in read('normal_baseline_records.csv')]
allgroups=[a,n]
shared=sorted(set(x for x,z in a)&set(x for x,z in n))
cnt=[Counter(x for x,z in g) for g in allgroups]
zero=[Counter(x for x,z in g if z) for g in allgroups]
den=sum(sum(c[x] for x in shared) for c in cnt)
weights={x:(cnt[0][x]+cnt[1][x])/den for x in shared}
out={'exact_shared_counts':shared,'pooled_weights':weights,'common':[]}
for i,name in enumerate(['A','Normal']):
    out['common'].append({'collection':name,'n':sum(cnt[i][x] for x in shared),'zeros':sum(zero[i][x] for x in shared),'whole_n':len(allgroups[i]),'whole_zeros':sum(z for x,z in allgroups[i]),'direct_standardized_rate':sum(weights[x]*zero[i][x]/cnt[i][x] for x in shared)})
(root/'standardized_density_summary.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out['common']))
