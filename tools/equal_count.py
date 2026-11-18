"""Exact probability of an empty region under uniform thinning of observed detections."""
import argparse,csv,json,math
from collections import Counter
from pathlib import Path
import numpy as np

def run(data_dir,out):
    records=json.loads((data_dir/'dual_point_clouds_manifest.json').read_text())
    rows=[]
    with np.load(data_dir/'dual_point_clouds_and_joints.npz',allow_pickle=False) as arrays:
        for rec in records:
            if rec['collection']!='Normal':
                continue
            key=rec['record_id']
            centre=np.median(arrays[key+'_joints_xyz'][[18,19,20,22,23,24]],axis=0)
            n,k=[],[]
            for kind in ('native','offline'):
                xyz=arrays[key+'_'+kind+'_xyz'].astype(float)+[-.13,0,-.1]
                n.append(len(xyz))
                k.append(int(np.all(np.abs(xyz-centre)<=[.30,.25,.38],axis=1).sum()))
            if n[0]<n[1]:
                continue
            total,sample=n
            outside=total-k[0]
            probability=math.comb(outside,sample)/math.comb(total,sample) if outside>=sample else 0.
            rows.append((key,total,k[0],sample,k[1],probability))
    out.mkdir(parents=True,exist_ok=True)
    with (out/'equal_count_records.csv').open('w',newline='') as f:
        writer=csv.writer(f)
        writer.writerow(['id','native_n','native_region_n','offline_n','offline_region_n','expected_empty_probability'])
        writer.writerows(rows)
    summary=dict(n=len(rows),total_available=sum(r['collection']=='Normal' for r in records),native_empty=sum(r[2]==0 for r in rows),offline_empty=sum(r[4]==0 for r in rows),expected_empty_sum=sum(r[5] for r in rows),condition='native count at least offline count',per_block={})
    for block in sorted(set(r[0].rsplit('_',1)[0] for r in rows)):
        group=[r for r in rows if r[0].rsplit('_',1)[0]==block]
        summary['per_block'][block]=[len(group),sum(r[5] for r in group),sum(r[4]==0 for r in group)]
    (out/'equal_count_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('data_dir',type=Path);p.add_argument('out',type=Path)
    a=p.parse_args();run(a.data_dir,a.out)
