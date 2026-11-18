from pathlib import Path
import json
from collections import Counter
import numpy as np
base=Path(__file__).resolve().parent
arrays=np.load(base/'author_owned_numeric_records_v21.npz',allow_pickle=False)
manifest=json.loads((base/'records_manifest_v21.json').read_text())
rows=[]
from csv import DictWriter
for record in manifest['records']:
    radar=arrays[record['radar_array_key']][:,:3].astype(float)+[-.13,0,-.2]
    joints=arrays[record['joints_array_key']].astype(float)+[0,0,-.1]
    offset=np.abs(radar-np.median(joints[[18,19,20,22,23,24]],axis=0))
    halfsize=np.array([.30,.25,.38])
    count=lambda width: int(np.all(offset<=width,axis=1).sum())
    rows.append(dict(id=record['record_id'],cohort=record['collection'],block=record['block'],number=len(radar),leg=count(halfsize),leg5cmWide=count(halfsize+.05),leg5cmCore=count(halfsize-.05)))
def summary(group):
    z=sum(r['leg']==0 for r in group);n=len(group)
    sorted_groups={}
    for r in group:
        k=(r['block'],r['number'])
        p=sorted_groups.setdefault(k,[0,0]);p[r['leg']==0]+=1
    mixed=[v for v in sorted_groups.values() if min(v)>0]
    return dict(records=n,n_zero=z,all_shifts_zero=sum(r['leg5cmWide']==0 for r in group),common_point_all_shifts=sum(r['leg5cmCore']>0 for r in group),mixed_block_count_strata=len(mixed),n_in_those_strata=sum(sum(v) for v in mixed),n_zero_those_strata=sum(v[1] for v in mixed),min_classification_errors_using_only_total_count_and_block=sum(min(v) for v in mixed),cloud_size_20_33=(sum(r['leg']==0 and r['number']<34 for r in group),sum(r['number']<34 for r in group)),cloud_size_34_47=(sum(r['leg']==0 and 34<=r['number']<=47 for r in group),sum(34<=r['number']<=47 for r in group)))
d={k:summary([r for r in rows if r['cohort']==k or r['block']==k]) for k in ('A','B','A-000','A-001','A-002','B-000','B-001')}
print(json.dumps(d,indent=1));(base/'regional_ambiguity_summary.json').write_text(json.dumps(d,indent=2)+'\n')
with (base/'regional_ambiguity_records.csv').open('w') as f:
    w=DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
