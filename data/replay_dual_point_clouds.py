"""Compare two point representations stored in the same author MAT file."""
from pathlib import Path
import numpy as np
import json
from collections import defaultdict
root=Path(__file__).resolve().parent
arrays=np.load(root/'dual_point_clouds_and_joints.npz',allow_pickle=False)
records=json.loads((root/'dual_point_clouds_manifest.json').read_text())
for off in [[-.13,0,-.1],[0,0,0]]:
    groups=defaultdict(lambda:np.zeros((2,2),dtype=int))
    for rec in records:
        key=rec['record_id']
        c=np.median(arrays[key+'_joints_xyz'][[18,19,20,22,23,24]],axis=0)
        def has_support(suffix):
            p=arrays[key+suffix]
            return int(np.all(abs(p+off-c)<=[.30,.25,.38],axis=1).any())
        result=(has_support('_native_xyz'),has_support('_offline_xyz'))
        groups[rec['collection']][result]+=1
    print(json.dumps({'offset_m':off,'tables_native_by_offline':{g:q.tolist() for g,q in groups.items()}},sort_keys=True))
