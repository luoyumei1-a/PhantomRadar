"""Sensing-requirement behavior across unavailable and contradictory observations."""
import unittest
from phantomradar.audit import diagnose, validate_rows, validate_config, POSITIVE, NEGATIVE, UNKNOWN


def sample(**updates):
    item = dict(source_kind='measurement',device_id='device',session_id='session',
                trial_id='trial',frame_id='0',capture_time_s='0',publish_time_s='',
                expected_period_s='.05',point_count='21',adc_clip_fraction='',
                vendor_sat='',queue_fraction='',packet_loss='')
    item.update(updates)
    return item


class RegionalContractTests(unittest.TestCase):
    def outcome(self, **updates):
        return diagnose(validate_rows([sample(**updates)]),
                        validate_config({'required_flags':['receiver_evidence','regional_support']}))[0]

    def test_populated_cloud_cannot_mask_reference_qualified_regional_loss(self):
        out = self.outcome(reference_qualified='true',region_point_count='0')
        self.assertEqual(out['empty_output_flag'],NEGATIVE)
        self.assertEqual(out['regional_support_flag'],POSITIVE)
        self.assertEqual(out['receiver_evidence_flag'],UNKNOWN)
        self.assertEqual(out['observable_state'],'DEGRADED')

    def test_unqualified_reference_does_not_certify_a_negative(self):
        for value in ('', 'false'):
            out = self.outcome(reference_qualified=value,region_point_count='0',adc_clip_fraction='0',vendor_sat='0')
            self.assertEqual(out['regional_support_flag'],UNKNOWN)
            self.assertEqual(out['observable_state'],'UNKNOWN')

    def test_region_and_health_must_both_be_observed_to_clear_physical_contract(self):
        out = self.outcome(reference_qualified='true',region_point_count='10',adc_clip_fraction='0',vendor_sat='0')
        self.assertEqual(out['regional_support_flag'],NEGATIVE)
        self.assertEqual(out['receiver_evidence_flag'],NEGATIVE)
        self.assertEqual(out['observable_state'],'VALID')

    def test_missing_region_count_remains_unknown(self):
        out = self.outcome(reference_qualified='true',region_point_count='')
        self.assertEqual(out['regional_support_flag'],UNKNOWN)

    def test_region_count_cannot_exceed_original_whole_cloud(self):
        with self.assertRaisesRegex(ValueError,'exceeds whole-cloud'):
            self.outcome(reference_qualified='true',region_point_count='22')


if __name__=='__main__':
    unittest.main()
