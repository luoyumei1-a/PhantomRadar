#!/usr/bin/env python3
"""Verify the privacy-minimized numerical release and its recorded ROI counts."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def verify(root: Path) -> dict:
    manifest = json.loads((root / 'data/records_manifest_v21.json').read_text())
    recorded = np.load(root / 'data/author_owned_numeric_records_v21.npz', allow_pickle=False)
    leg_rows = [18, 19, 20, 22, 23, 24]
    torso_rows = [0, 1, 2]
    scales = [.50, .75, 1., 1.25, 1.50]
    zero = {'A': [0] * 5, 'B': [0] * 5}
    torso_zero = {'A': 0, 'B': 0}
    counts = {'A': 0, 'B': 0}
    radar_rows = {'A': 0, 'B': 0}
    for rec in manifest['records']:
        group = rec['collection']
        radar = recorded[rec['radar_array_key']]
        key = recorded[rec['joints_array_key']]
        assert radar.ndim == 2 and radar.shape[1] >= 3
        assert key.shape == (32, 3)
        assert np.isfinite(radar).all() and np.isfinite(key).all()
        assert len(radar) == rec['radar_rows']
        points = radar[:, :3].astype(float) + [-.13, 0., -.2]
        joints = key.astype(float) + [0., 0., -.1]
        centre = np.median(joints[leg_rows], axis=0)
        for k, scale in enumerate(scales):
            zero[group][k] += int(not np.any(np.all(np.abs(points - centre) <= np.array([.30, .25, .38]) * scale, axis=1)))
        torso = np.median(joints[torso_rows], axis=0)
        torso_zero[group] += int(not np.any(np.all(np.abs(points - torso) <= [.20, .25, .25], axis=1)))
        counts[group] += 1
        radar_rows[group] += len(radar)
    assert counts == {'A': 221, 'B': 32}
    assert radar_rows == {'A': 6971, 'B': 1432}
    assert zero == {'A': [165, 111, 52, 18, 4], 'B': [24, 11, 2, 0, 0]}
    assert torso_zero == {'A': 0, 'B': 1}
    checks = [
        '253 recorded record identities and finite numeric arrays',
        'primary221 and secondary32 record counts',
        '6971 and1432 unchanged radar rows',
        'five-extent zero-support counts in both collections',
        'primary0/221 and secondary1/32 torso zero-support counts',
    ]
    if (root / 'PUBLIC_RELEASE_MANIFEST_v21.json').exists():
        release = json.loads((root / 'PUBLIC_RELEASE_MANIFEST_v21.json').read_text())
        for entry in release['files']:
            p = (root / entry['path']).resolve()
            assert root.resolve() in p.parents
            assert p.stat().st_size == entry['bytes'] and sha256(p) == entry['sha256']
        checks.append('every public release file SHA256 and byte count')
    return {'version': 'v21', 'record_counts': counts, 'radar_rows': radar_rows,
            'roi_scales': scales, 'leg_zero_counts': zero,
            'torso_zero_counts': torso_zero, 'checks_passed': checks,
            'statistical_unit': 'stored paired record; ROI extents are repeated analyses'}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    print(json.dumps(verify(args.root), indent=2))


if __name__ == '__main__':
    main()
