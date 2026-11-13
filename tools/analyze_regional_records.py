#!/usr/bin/env python3
"""Recompute descriptive zero-count models and nominal Fisher test from public arrays.

The source data are recorded radar/reference rows. The fitted Poisson/NB models
are descriptive count baselines, not new measurement samples or causal tests.
"""
from pathlib import Path
import json,csv,math,hashlib
import numpy as np
from scipy.io import loadmat
from scipy.stats import fisher_exact
from scipy.optimize import minimize_scalar
from scipy.special import gammaln
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output_statistics';OUT.mkdir(exist_ok=True)
rows=[]
record_manifest=json.loads((ROOT/'data/records_manifest_v21.json').read_text())
arrays=np.load(ROOT/'data/author_owned_numeric_records_v21.npz',allow_pickle=False)
for r in record_manifest['records']:
 cohort=r['collection'];radar=arrays[r['radar_array_key']];key=arrays[r['joints_array_key']]
 p=radar[:,:3].astype(float)+np.array([-.13,0.,-.2]);k=key.astype(float)+np.array([0.,0.,-.1])
 c=np.median(k[[18,19,20,22,23,24]],axis=0);half=np.array([.30,.25,.38])
 cnt=[int(np.all(np.abs(p-c)<=s*half,axis=1).sum()) for s in [.5,.75,1.,1.25,1.5]]
 torso=int(np.all(np.abs(p-np.median(k[[0,1,2]],axis=0))<=np.array([.20,.25,.25]),axis=1).sum())
 rows.append(dict(cohort=cohort,block=r['block'],source=r['record_id'],file_index=r['file_index'],whole=len(p),leg=cnt[2],torso=torso,counts=cnt))
def model(rs,label):
 x=np.array([r['leg'] for r in rs]);n=len(x);mu=float(x.mean());v=float(x.var(ddof=1));z=int((x==0).sum());p0=math.exp(-mu)
 if v>mu and mu>0:
  k=mu*mu/(v-mu);np0=(k/(k+mu))**k
 else:k=None;np0=None
 def nll(q):
  kk=math.exp(q);return -float(np.sum(gammaln(x+kk)-gammaln(kk)-gammaln(x+1)+kk*np.log(kk/(kk+mu))+x*np.log(mu/(kk+mu))))
 fit=minimize_scalar(nll,bounds=(-8,15),method='bounded',options={'xatol':1e-11});mle=math.exp(fit.x);mp0=math.exp(-mle*math.log1p(mu/mle));pnll=-float(np.sum(x*np.log(mu)-mu-gammaln(x+1)))
 return dict(group=label,n_records=n,leg_sum=int(x.sum()),mean_leg_returns=mu,sample_variance=v,observed_zero_records=z,observed_zero_fraction=z/n,poisson_zero_probability=p0,poisson_expected_zero_records=n*p0,nb_mom_shape=k,nb_zero_probability=np0,nb_expected_zero_records=None if np0 is None else n*np0,NB_MLE_shape=mle,NB_MLE_zero_probability=mp0,NB_MLE_expected_zero_records=n*mp0,NB_log_likelihood_gain_over_Poisson=pnll-float(fit.fun),min_leg_count=int(x.min()),max_leg_count=int(x.max()))
models=[]
for cohort in ['A','B']:
 rs=[r for r in rows if r['cohort']==cohort];models.append(model(rs,cohort+'-pooled'))
 for b in sorted(set(r['block'] for r in rs)):models.append(model([r for r in rs if r['block']==b],b))
with (OUT/'zero_count_models_independent_v21.csv').open('w') as f:
 w=csv.DictWriter(f,fieldnames=list(models[0]));w.writeheader();w.writerows(models)
f=fisher_exact([[52,169],[2,30]],alternative='two-sided')
summary=dict(fisher_table=[[52,169],[2,30]],fisher_odds_ratio=float(f.statistic),fisher_two_sided_p=float(f.pvalue),fisher_scope='Nominal conditional test under independent stored-record sampling; within-block correlation and session/configuration confounding are not removed.',models=models,fig18_zero_counts=[sum(r['counts'][i]==0 for r in rows if r['cohort']=='A') for i in range(5)],figure18_block002_base_percent=100*4/21)
summary['point_density_strata']=[]
for cohort in ['A','B']:
 for lo,hi in [(20,29),(30,39),(40,49),(50,60)]:
  rs=[r for r in rows if r['cohort']==cohort and lo<=r['whole']<=hi];summary['point_density_strata'].append(dict(cohort=cohort,min_whole_cloud=lo,max_whole_cloud=hi,n_records=len(rs),zero_leg_records=sum(r['leg']==0 for r in rs)))
summary['density_overlap_34_47']=[dict(cohort=c,n_records=sum(r['cohort']==c and 34<=r['whole']<=47 for r in rows),zero_leg_records=sum(r['cohort']==c and 34<=r['whole']<=47 and r['leg']==0 for r in rows)) for c in ['A','B']]
(OUT/'summary_independent_v21.json').write_text(json.dumps(summary,indent=2))
with (OUT/'record_counts_independent_v21.csv').open('w') as f:
 w=csv.DictWriter(f,fieldnames=['cohort','block','source','file_index','whole','leg','torso']);w.writeheader();w.writerows([{k:r[k] for k in w.fieldnames} for r in rows])
print(json.dumps(summary,indent=2))

# Independent conditional Friis/sensitivity reconstruction, with TI ODS peak5dBi.
C=299792458;lam=C/62e9;ptw=.9*10**((12-30)/10);ptdb=10*math.log10(ptw)+30;fspl=20*math.log10(4*math.pi*3/lam)
gainrows=[];passive=[]
for vg in [5,10]:
 for hg in [15,20,25]:
  pin=ptdb+vg+hg-fspl;beta=vg+hg-fspl
  for rx,threshold in zip([30,40,48],[-24,-34,-42]):
   req=threshold-pin-beta;pout=threshold-beta
   gainrows.append(dict(range_m=3,configured_RX_gain_db=rx,victim_antenna_gain_dbi=vg,horn_gain_dbi=hg,AF_input_dbm=pin,final_hop_transfer_db=beta,required_AF_gain_db=req,required_output_or_direct_Pa_dbm=pout,direct_Pa_mW=10**(pout/10),direct_EIRP_dbm=pout+hg,minimum_isolation_db=req+6,H1_at_I40=min(30,34,20-pin)-req,H2_at_I40=min(60,34,20-pin)-req,H2_at_I60=min(60,54,20-pin)-req,plane_crossing_m=lam/(8*math.pi)*10**((ptdb+2*vg-threshold)/20)))
with (OUT/'active_antenna_gain_sensitivity_independent_v21.csv').open('w') as f:
 w=csv.DictWriter(f,fieldnames=list(gainrows[0]));w.writeheader();w.writerows(gainrows)
summary['active_ODS5_horn25_at3m']=[r for r in gainrows if r['victim_antenna_gain_dbi']==5 and r['horn_gain_dbi']==25]
(OUT/'summary_independent_v21.json').write_text(json.dumps(summary,indent=2))
