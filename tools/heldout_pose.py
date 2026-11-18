"""Held-out radar-only six-joint predictions; the regional flag is evaluated afterwards."""
import argparse
import csv
import json
from pathlib import Path
import numpy as np

def read_records(directory):
    with np.load(directory / "author_owned_numeric_records_v21.npz", allow_pickle=False) as arrays:
        records = json.loads((directory / "records_manifest_v21.json").read_text())["records"]
        features, responses, absences = [], [], []
        for rec in records:
            xyz = np.asarray(arrays[rec["radar_array_key"]][:, :3], dtype=float) + [-.13, 0., -.2]
            leg = np.asarray(arrays[rec["joints_array_key"]][[18,19,20,22,23,24]], dtype=float) + [0., 0., -.1]
            quartiles = np.quantile(xyz, [.25, .50, .75], axis=0)
            features.append(np.r_[len(xyz), quartiles[1], quartiles[2] - quartiles[0]])
            responses.append(leg.ravel())
            offsets = np.abs(xyz - np.median(leg, axis=0))
            absences.append(not np.any(np.all(offsets <= [.30, .25, .38], axis=1)))
    return records, np.array(features), np.array(responses), np.array(absences)

def predict(x_train, y_train, x_test):
    center = x_train.mean(axis=0)
    scale = x_train.std(axis=0)
    scale[scale == 0.] = 1.
    z = (x_train-center)/scale
    y_mean = y_train.mean(axis=0)
    reg = len(z) * np.eye(z.shape[1])
    slopes = np.linalg.solve(z.T @ z + reg, z.T @ (y_train-y_mean))
    estimated = (x_test-center)/scale @ slopes + y_mean
    prior = np.broadcast_to(np.median(y_train, axis=0), estimated.shape)
    return estimated, prior

def run(data_dir, output):
    records, features, target, absence = read_records(data_dir)
    block = np.array([r["block"] for r in records])
    primary = np.array([r["collection"] == "A" for r in records])
    predictions = np.zeros((len(block), 2))
    for b in np.unique(block):
        test = block == b
        train = primary & ~test
        fit = predict(features[train], target[train], features[test])
        for i, preds in enumerate(fit):
            errors = (preds - target[test]).reshape(-1,6,3)
            predictions[test,i] = np.linalg.norm(errors,axis=2).mean(axis=1)*100.
    output.mkdir(parents=True,exist_ok=True)
    with (output/"pose_record_errors.csv").open("w",newline="") as f:
        w=csv.writer(f); w.writerow(["record","block","leg_empty","cloud_count","ridge_mpjpe_cm","median_prior_mpjpe_cm"])
        for i,r in enumerate(records):
            w.writerow([r["record_id"],block[i],int(absence[i]),int(features[i,0]),*predictions[i]])
    with (output/"pose_summary.csv").open("w",newline="") as f:
        w=csv.writer(f);w.writerow(["cohort_or_block","regional_group","n","ridge_mean_cm","prior_mean_cm","ridge_median_cm","prior_median_cm"])
        for name,cohort in [("A",primary),("B",~primary)]+[(b,b==block) for b in np.unique(block)]:
            for group,flag in [("all",np.ones(len(block),dtype=bool)),("empty",absence),("supported",~absence)]:
                values=predictions[cohort & flag]
                if len(values):
                    w.writerow([name,group,len(values),*values.mean(axis=0),*np.median(values,axis=0)])

if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir",type=Path)
    parser.add_argument("output_dir",type=Path)
    args=parser.parse_args()
    run(args.data_dir,args.output_dir)
