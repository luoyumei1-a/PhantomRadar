"""Independent checks against original stored example records, not plot geometry."""
import unittest
from pathlib import Path

from phantomradar.regional import load_snapshot, summarize_collection, count_support

ROOT = Path(__file__).resolve().parents[2]


class RegionalSupportTests(unittest.TestCase):
    def test_fixed_reference_retains_measured_whole_cloud_and_regional_counts(self):
        paths = [ROOT / 'examples/paired_snapshots' / f'pc_ti_kinect_key_{i}.mat'
                 for i in (89, 90, 91)]
        key = load_snapshot(paths[0])[1]
        records = summarize_collection(paths, fixed_key=key)['records']
        self.assertEqual([r['original_radar_rows'] for r in records], [36, 21, 24])
        self.assertEqual([r['leg_point_count'] for r in records], [12, 0, 12])
        self.assertEqual([r['torso_point_count'] for r in records], [6, 10, 12])

    def test_unknown_reference_is_not_negative(self):
        import numpy as np
        self.assertIsNone(count_support(np.array([[0., 0., 0.]]), None, [1., 1., 1.]))

    def test_larger_fixed_region_cannot_reduce_point_support(self):
        import numpy as np
        radar, _ = load_snapshot(ROOT / 'examples/paired_snapshots/pc_ti_kinect_key_90.mat')
        center = np.array([0., 1.4, -0.5])
        counts = [count_support(radar, center, [.3, .25, .38], s) for s in (.5, 1., 1.5)]
        self.assertEqual(counts, sorted(counts))


if __name__ == '__main__':
    unittest.main()
