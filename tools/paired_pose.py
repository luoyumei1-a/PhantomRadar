"""Compare paired exported representations using a common held-out pose regressor."""
import argparse,csv,json
from collections import Counter
from pathlib import Path
import numpy as np
from heldout_pose import predict

def run(data_dir,output):
    selected=[r for r in json.loads((data_dir/"dual_point_clouds_manifest.json").read_text()) if r["collection"]=="Normal"]
    rows=[]
    with np.load(data_dir/"dual_point_clouds_and_joints.npz",allow_pickle=False) as streams:
        for r in selected:
            key=r["record_id"]; parent=key.split("_")[1]
            leg=streams[key+"_joints_xyz"][[18,19,20,22,23,24]].astype(float)
            center=np.median(leg,axis=0)
            for version in ("native","offline"):
                cloud=streams[key+"_"+version+"_xyz"].astype(float)+[-.13,0,-.1]
                q=np.quantile(cloud,[.25,.50,.75],axis=0)
                x=np.r_[len(cloud),q[1],q[2]-q[0]]
                supported=bool(np.any(np.all(np.abs(cloud-center)<=[.30,.25,.38],axis=1)))
                rows.append((key,parent,version,x,leg.ravel(),supported))
    parent=np.array([r[1] for r in rows]);features=np.array([r[3] for r in rows]);target=np.array([r[4] for r in rows])
    errors=np.empty((len(rows),2))
    for seq in np.unique(parent):
        test=parent==seq
        for i,est in enumerate(predict(features[~test],target[~test],features[test])):
            errors[test,i]=np.linalg.norm((est-target[test]).reshape(-1,6,3),axis=2).mean(axis=1)*100.
    output.mkdir(parents=True,exist_ok=True)
    pairlist=[]
    for i in range(0,len(rows),2):
        na,off=rows[i:i+2]
        assert na[0]==off[0] and np.array_equal(na[4],off[4])
        pairlist.append((na[0],na[1],int(na[-1]),int(off[-1]),errors[i,0],errors[i+1,0],errors[i,1]))
    with (output/"paired_pose_records.csv").open("w",newline="") as f:
        w=csv.writer(f);w.writerow(["record","held_out_parent","native_support","offline_support","native_error_cm","offline_error_cm","prior_error_cm"]);w.writerows(pairlist)
    values=np.array([r[2:] for r in pairlist]);a,b,nat,off,prior=values.T
    disc=a!=b;missing=np.where(a[disc]==0,nat[disc],off[disc]);present=np.where(a[disc]==1,nat[disc],off[disc])
    report=dict(n_files=len(pairlist),parent_count=len(set(parent)),native_mean_cm=nat.mean(),offline_mean_cm=off.mean(),prior_mean_cm=prior.mean(),discordant=int(disc.sum()),empty_mean_cm=missing.mean(),supported_mean_cm=present.mean(),empty_minus_supported_cm=(missing-present).mean(),median_paired_diff_cm=np.median(missing-present),larger_error_when_empty=int(np.sum(missing>present)),equal_error=int(np.sum(missing==present)),support_by_parent={p:sum(x[1]==p for x in pairlist) for p in set(parent)})
    (output/"paired_pose_summary.json").write_text(json.dumps(report,indent=2,sort_keys=True)+"\n")
if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("data_dir",type=Path);p.add_argument("out",type=Path)
    args=p.parse_args();run(args.data_dir,args.out)
