"""Sensitivity of native return support to separate left and right leg regions."""
import argparse,csv,json
from pathlib import Path
import numpy as np

def segment_distance(points, first, second):
    direction=second-first
    squared_length=float(direction@direction)
    if squared_length==0.0:
        return np.linalg.norm(points-first,axis=1)
    position=np.clip((points-first)@direction/squared_length,0.,1.)
    return np.linalg.norm(points-(first+position[:,None]*direction),axis=1)

def run(data_dir, out):
    records=json.loads((data_dir/"records_manifest_v21.json").read_text())["records"]
    out.mkdir(parents=True,exist_ok=True)
    rows=[]
    with np.load(data_dir/"author_owned_numeric_records_v21.npz",allow_pickle=False) as arrays:
        for r in records:
            xyz=arrays[r["radar_array_key"]][:,:3].astype(float)+[-.13,0,-.2]
            joints=arrays[r["joints_array_key"]].astype(float)+[0,0,-.1]
            offsets=np.abs(xyz-np.median(joints[[18,19,20,22,23,24]],axis=0))
            box_empty=not np.any(np.all(offsets<=[.30,.25,.38],axis=1))
            paths=[segment_distance(xyz,joints[a],joints[b]) for a,b in [(18,19),(19,20),(22,23),(23,24)]]
            rows.append((r["record_id"],r["collection"],r["block"],int(box_empty),float(np.min(paths))))
    with (out/"limb_distances.csv").open("w",newline="") as f:
        w=csv.writer(f);w.writerow(["record","cohort","block","box_empty","min_to_leg_segments_m"]);w.writerows(rows)
    with (out/"limb_summary.csv").open("w",newline="") as f:
        w=csv.writer(f);w.writerow(["cohort","radius_m","n","nominal_box_empty","capsule_union_empty","both_empty"])
        for c in ["A","B"]:
            sub=[r for r in rows if r[1]==c]
            for radius in [.1,.15,.2]:
                w.writerow([c,radius,len(sub),sum(r[3] for r in sub),sum(r[4]>radius for r in sub),sum(r[3] and r[4]>radius for r in sub)])
if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("data_dir",type=Path);p.add_argument("out",type=Path)
    a=p.parse_args();run(a.data_dir,a.out)
