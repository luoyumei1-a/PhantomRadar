"""Compare post-capture global IQ descriptors to regional support on one session."""
from pathlib import Path
import json, csv
import numpy as np
from scipy.io import loadmat

root=Path(__file__).resolve().parent
rec=loadmat(root/'environment_new_v19.mat')
times=[rec[k][:,0] for k in ['raw_time_ns','radar_time_ns','body_time_ns']]
R=rec['radar_points'][:,0]
J=rec['body_joints'][:,0]
rows=[]
tilt=np.deg2rad(6)
rot=np.array([[1,0,0],[0,np.cos(tilt),-np.sin(tilt)],[0,np.sin(tilt),np.cos(tilt)]])
for i,t in enumerate(times[0]):
    ci=int(np.argmin(np.abs(times[1]-t)))
    bi=int(np.argmin(np.abs(times[2]-times[1][ci])))
    span=(max(t,times[1][ci],times[2][bi])-min(t,times[1][ci],times[2][bi]))/1e6
    p=R[ci];k=J[bi]@rot
    k=np.column_stack((k[:,0],k[:,2],-k[:,1])); c=np.median(k[[18,19,20,22,23,24]],axis=0)
    side=np.column_stack((-p[:,1]-.1,p[:,0]-.1,p[:,2]))
    up=np.column_stack((-p[:,1],p[:,2]+1,-p[:,0]+2.5))
    nleg=lambda p: int(np.all(np.abs(p-c)<=[.30,.25,.38],axis=1).sum())
    # File-format decoding only. Preserve the supplied fast-time / receiver axes.
    v=rec['raw_payloads'][i,0].ravel().tobytes()
    words=np.frombuffer(v,dtype='<i2').reshape(-1,4).astype(float)
    z=(words[:,:2]+1j*words[:,2:]).reshape(-1,4,256)
    a=z[:,:,1:]*z[:,:,:-1].conj()
    coh=abs((a[a!=0]/abs(a[a!=0])).mean())
    rows.append(dict(iq_id=i+1,cloud_id=ci+1,body_id=bi+1,span_ms=span,
             extent_side=nleg(side),extent_up=nleg(up),whole=len(p),
             iq_abs_p99=float(np.percentile(abs(z),99)),coherence=float(coh)))
def report(window):
    subset=[r for r in rows if r['span_ms']<=window]
    result={'window_ms':window,'total':len(subset),'unique_clouds':len(set(r['cloud_id'] for r in subset)),'unique_bodies':len(set(r['body_id'] for r in subset)),'up_leg_zero':sum(r['extent_up']==0 for r in subset)}
    for label,predicate in [('empty',lambda r:r['extent_side']==0),('supported',lambda r:r['extent_side']>0)]:
        group=[r for r in subset if predicate(r)]
        result[label]={'n':len(group)}
        for col in ['iq_abs_p99','coherence','whole']:
            data=np.array([r[col] for r in group])
            if data.size: result[label][col+'_min_med_max']=np.array([data.min(),np.median(data),data.max()]).tolist()
    return result
res=[report(t) for t in [25,50,100,250]]
print(json.dumps(res,indent=2))
(root/'recording_iq_and_support_summary.json').write_text(json.dumps(res,indent=2)+'\n')
with (root/'recording_iq_and_support_records.csv').open('w') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
