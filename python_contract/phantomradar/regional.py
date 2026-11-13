"""Reference-conditioned support in original paired radar/Kinect snapshots.

This module has no acquisition-clock, attack-switch, or receiver-fault inference.
It reads the three arrays stored in each MAT and counts existing radar rows.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path

LEG_ROWS = (18, 19, 20, 22, 23, 24)  # zero-based source joint indices
TORSO_ROWS = (0, 1, 2)
RADAR_TRANSLATION = (-0.13, 0.0, -0.2)
KEY_TRANSLATION = (0.0, 0.0, -0.1)
LEG_HALF_EXTENT = (0.30, 0.25, 0.38)
TORSO_HALF_EXTENT = (0.20, 0.25, 0.25)


def load_snapshot(path):
    import numpy as np
    from scipy.io import loadmat

    path = Path(path)
    fields = loadmat(path)
    radar = np.array(fields['pc_xyziv_ti'], dtype=float, copy=True)
    key = np.array(fields['pc_xyz_key'], dtype=float, copy=True)
    if radar.ndim != 2 or radar.shape[1] < 3:
        raise ValueError('Expected a two-dimensional radar array with XYZ columns')
    if key.ndim != 2 or key.shape[0] < 25 or key.shape[1] < 3:
        raise ValueError('Expected source reference joints with XYZ columns')
    radar[:, :3] += np.asarray(RADAR_TRANSLATION)
    key[:, :3] += np.asarray(KEY_TRANSLATION)
    return radar, key


def reference_center(key, rows):
    import numpy as np
    joints = key[list(rows), :3]
    if not np.isfinite(joints).all():
        return None
    return np.median(joints, axis=0)


def count_support(radar, center, half_extent, scale=1.0):
    import numpy as np
    if center is None:
        return None
    if scale <= 0:
        raise ValueError('ROI scale must be positive')
    xyz = radar[:, :3]
    inside = (np.abs(xyz - center) <= np.asarray(half_extent) * scale).all(axis=1)
    return int(inside.sum())


def summarize_snapshot(path, *, scale=1.0, fixed_key=None):
    radar, key = load_snapshot(path)
    region_key = key if fixed_key is None else fixed_key
    leg = count_support(radar, reference_center(region_key, LEG_ROWS), LEG_HALF_EXTENT, scale)
    torso = count_support(radar, reference_center(region_key, TORSO_ROWS), TORSO_HALF_EXTENT, scale)
    return {
        'source_file': Path(path).name,
        'source_sha256': hashlib.sha256(Path(path).read_bytes()).hexdigest(),
        'original_radar_rows': int(radar.shape[0]),
        'roi_scale': scale,
        'roi_reference': 'same_snapshot' if fixed_key is None else 'fixed_reference',
        'leg_reference_qualified': leg is not None,
        'leg_point_count': leg,
        'leg_zero_support': None if leg is None else leg == 0,
        'torso_reference_qualified': torso is not None,
        'torso_point_count': torso,
        'torso_zero_support': None if torso is None else torso == 0,
        'whole_cloud_zero_support': radar.shape[0] == 0,
    }


def summarize_collection(paths, *, scale=1.0, fixed_key=None):
    records = [summarize_snapshot(p, scale=scale, fixed_key=fixed_key) for p in paths]
    rates = {}
    for region in ('leg', 'torso'):
        eligible = [r for r in records if r[f'{region}_reference_qualified']]
        numerator = sum(r[f'{region}_zero_support'] for r in eligible)
        rates[region] = {'zero_support_records': numerator,
                         'reference_qualified_records': len(eligible),
                         'record_proportion': numerator / len(eligible) if eligible else None}
    return {'unit': 'stored_paired_record', 'roi_scale': scale,
            'record_count': len(records), 'regions': rates, 'records': records}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--scale', type=float, default=1.0)
    parser.add_argument('--fixed-reference', type=Path,
                        help='Use one reference snapshot to define identical regions for all input snapshots')
    args = parser.parse_args()
    paths = sorted(args.directory.glob('pc_ti_kinect_key_*.mat'),
                   key=lambda p: int(p.stem.rsplit('_', 1)[1]))
    if not paths:
        parser.error('No paired MAT snapshots found')
    fixed_key = load_snapshot(args.fixed_reference)[1] if args.fixed_reference else None
    report = summarize_collection(paths, scale=args.scale, fixed_key=fixed_key)
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'regional_support.json').write_text(json.dumps(report, indent=2) + '\n')
    with (args.output / 'regional_support.csv').open('w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=list(report['records'][0]))
        writer.writeheader()
        writer.writerows(report['records'])
    print(json.dumps({k: v for k, v in report.items() if k != 'records'}, indent=2))


if __name__ == '__main__':
    main()
