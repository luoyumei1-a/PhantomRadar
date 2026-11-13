"""Dimensional and boundedness checks for the conditional physical model."""
import math
import unittest
from phantomradar.link_budget import monostatic_echo_dbm,direct_input_dbm,threshold_rcs_dbsm,bounded_relay_input_dbm,fractional_nominal_power_dbm


class LinkBudgetTests(unittest.TestCase):
    def test_nominal_fraction_scales_linear_power(self):
        p = fractional_nominal_power_dbm(12, 0.9)
        self.assertAlmostEqual(10**(p/10), 0.9 * 10**(12/10))
        self.assertAlmostEqual(p, 11.542425094393248)
        for fraction in (0, -0.1, 1.01, float('nan')):
            with self.assertRaises(ValueError):
                fractional_nominal_power_dbm(12, fraction)

    def test_two_way_and_one_way_distance_dependence(self):
        common=(12,10,10,77e9)
        echo1=monostatic_echo_dbm(*common,1,2)
        echo2=monostatic_echo_dbm(*common,1,4)
        self.assertAlmostEqual(echo1-echo2,40*math.log10(2))
        direct1=direct_input_dbm(*common,2)
        direct2=direct_input_dbm(*common,4)
        self.assertAlmostEqual(direct1-direct2,20*math.log10(2))

    def test_boundary_inverts_echo_equation(self):
        boundary=threshold_rcs_dbsm(-30,12,10,10,60e9,3,2)
        power=monostatic_echo_dbm(12,10,10,60e9,10**(boundary/10),3,2)
        self.assertAlmostEqual(power,-30)

    def test_fixed_gain_relay_is_two_hop_until_output_limited(self):
        args=(12,10,10,10,10,30,100,77e9)
        p1=bounded_relay_input_dbm(*args,2,2)
        p2=bounded_relay_input_dbm(*args,4,4)
        self.assertAlmostEqual(p1['victim_input_dbm']-p2['victim_input_dbm'],40*math.log10(2))
        self.assertFalse(p1['output_limited'])

    def test_more_gain_cannot_exceed_relay_output_bound(self):
        p1=bounded_relay_input_dbm(12,10,10,10,10,100,10,77e9,1,1)
        p2=bounded_relay_input_dbm(12,10,10,10,10,150,10,77e9,1,1)
        self.assertTrue(p1['output_limited'])
        self.assertEqual(p1['victim_input_dbm'],p2['victim_input_dbm'])

    def test_isolation_bound_is_enforced(self):
        with self.assertRaises(ValueError):
            bounded_relay_input_dbm(12,10,10,10,10,50,10,77e9,1,1,isolation_db=50,stability_margin_db=3)

    def test_invalid_geometry_is_rejected(self):
        for value in (0,-1,float('nan'),True):
            with self.assertRaises(ValueError):
                monostatic_echo_dbm(12,10,10,77e9,1,value)


if __name__=='__main__':unittest.main()
