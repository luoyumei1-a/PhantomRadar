"""Independent dimensional checks for direct-source versus relay budgets."""
import math
import unittest

from phantomradar.link_budget import (
    direct_source_requirements, direct_input_dbm, relay_gain_headroom_db,
)


class DirectSourceTests(unittest.TestCase):
    def test_linear_friis_reaches_each_receiver_boundary(self):
        wavelength = 299792458 / 62e9
        for threshold in (-24, -34, -42):
            result = direct_source_requirements(threshold, 25, 10, 62e9, 3)
            input_mw = result['required_conducted_mw'] * 10**(25/10) * 10 \
                * (wavelength/(4*math.pi*3))**2
            self.assertAlmostEqual(10*math.log10(input_mw), threshold, places=11)
        nominal = direct_source_requirements(-42, 25, 10, 62e9, 3)
        self.assertAlmostEqual(nominal['required_conducted_dbm'], .8380421062417)
        self.assertAlmostEqual(nominal['required_conducted_mw'], 1.2128419517290625)
        self.assertAlmostEqual(direct_input_dbm(0, 25, 10, 62e9, 3), -42.8380421062417)

    def test_source_gain_changes_conducted_power_not_required_eirp(self):
        rows = [direct_source_requirements(-42, g, 10, 62e9, 3) for g in (15, 20, 25)]
        self.assertAlmostEqual(rows[0]['required_conducted_dbm'] - rows[2]['required_conducted_dbm'], 10)
        for row in rows:
            self.assertAlmostEqual(row['required_eirp_dbm'], 25.8380421062417)
        victim5 = direct_source_requirements(-42, 25, 5, 62e9, 3)
        self.assertAlmostEqual(victim5['required_eirp_dbm'] - rows[2]['required_eirp_dbm'], 5)

    def test_identical_outgoing_hop_matches_relay_output_requirement(self):
        for threshold in (-24, -34, -42):
            direct = direct_source_requirements(threshold, 25, 10, 62e9, 3)
            relay = relay_gain_headroom_db(threshold, 11.542425094393248,
                10, 10, 25, 25, 60, 20, 60, 6, 62e9, 3, 3)
            self.assertAlmostEqual(direct['required_conducted_dbm'], relay['required_output_dbm'])


if __name__ == '__main__':
    unittest.main()
