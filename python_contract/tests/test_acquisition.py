"""Metadata fixtures test input handling; they are not experiment records."""
import copy
import unittest
from phantomradar.acquisition import assess_recording, assess_manifest, rail_occupancy


def incomplete_record():
    return dict(recording_id='test-fixture',source_kind='recorded_measurement',
        source_path='fixture.bin',source_sha256='a'*64,manufacturer='Fixture vendor',
        device_model='Fixture device',source_documentation_ref='fixture-doc')


class AcquisitionTests(unittest.TestCase):
    def test_uncollected_fields_do_not_become_negative_labels(self):
        report=assess_recording(incomplete_record())
        self.assertTrue(report['missing_acquisition_fields'])
        self.assertFalse(report['paired_evidence_record_complete'])
        for item in report['observations'].values():
            self.assertIsNone(item['value'])
            self.assertEqual(item['status'],'NOT_COLLECTED')

    def test_known_radarbook_bytes_cannot_be_reassigned_to_ti(self):
        r=incomplete_record()
        r.update(source_sha256='316143f1c71a723b6ac207c42f498f95feadb54c5886d307f567c7721c09e585',manufacturer='TI',device_model='IWR6843')
        report=assess_recording(r)
        self.assertEqual(len(report['provenance_conflicts']),2)
        self.assertTrue(all(x['status']=='PROVENANCE_CONFLICT' for x in report['observations'].values()))

    def test_reported_false_requires_observed_monitor_and_references(self):
        r=incomplete_record()
        r['observations']={'receiver_saturation':{'value':False,'collected':True,'monitor_enabled':False}}
        item=assess_recording(r)['observations']['receiver_saturation']
        self.assertEqual(item['status'],'INCOMPLETE_REFERENCES')
        self.assertFalse(item['physical_validity_certified_by_checker'])

    def test_disabled_monitor_cannot_supply_observed_saturation_negative(self):
        r=incomplete_record()
        r['observations']={'receiver_saturation':{'value':False,'collected':True,'monitor_enabled':False,
            'raw_report_ref':'fixture-report','vendor_semantics_ref':'fixture-def','collection_interval_ref':'fixture-clock'}}
        item=assess_recording(r)['observations']['receiver_saturation']
        self.assertIn('monitor_enabled must be true',item['missing_requirements'])

    def test_damage_positive_needs_persistent_change_evidence(self):
        r=incomplete_record()
        r['observations']={'hardware_damage':{'value':True,'collected':True,
            'pre_exposure_health_ref':'pre','post_exposure_health_ref':'post',
            'power_cycle_health_ref':'cycle','assessment_ref':'assessment'}}
        item=assess_recording(r)['observations']['hardware_damage']
        self.assertEqual(item['status'],'INCOMPLETE_REFERENCES')
        self.assertIn('persistent_change_ref',item['missing_requirements'])

    def test_string_booleans_rejected_not_truthy(self):
        r=incomplete_record()
        r['observations']={'receiver_saturation':{'value':'false','collected':True}}
        with self.assertRaises(ValueError):assess_recording(r)

    def test_rail_fraction_is_descriptor_not_a_fault_label(self):
        result=rail_occupancy([-2048,-2048,0,2047],-2048,2047)
        self.assertEqual(result['rail_occupancy_fraction'],.75)
        self.assertEqual(result['longest_rail_run'],2)
        self.assertEqual(result['interpretation'],'descriptor_only_not_a_receiver_fault_label')
        self.assertNotIn('saturation_label',result)

    def test_half_integer_preprocessed_values_not_native_codes(self):
        with self.assertRaisesRegex(ValueError,'decoded integer'):
            rail_occupancy([0,.5,1],-2048,2047)
        with self.assertRaises(ValueError):rail_occupancy([4096],-2048,2047)

    def test_duplicate_recording_identity_rejected(self):
        r=incomplete_record()
        with self.assertRaisesRegex(ValueError,'duplicate'):
            assess_manifest({'schema_version':'1.0','recordings':[r,copy.deepcopy(r)]})

    def test_uppercase_known_hash_does_not_bypass_source_registry(self):
        r=incomplete_record()
        r.update(source_sha256='316143f1c71a723b6ac207c42f498f95feadb54c5886d307f567c7721c09e585'.upper(),manufacturer='TI',device_model='IWR6843')
        self.assertEqual(len(assess_recording(r)['provenance_conflicts']),2)

    def test_label_without_collection_is_not_a_measured_negative(self):
        r=incomplete_record()
        r['observations']={'receiver_saturation':{'value':False,'collected':False}}
        with self.assertRaisesRegex(ValueError,'collected=true'):assess_recording(r)

    def test_collected_but_value_unavailable_stays_unavailable(self):
        r=incomplete_record()
        r['observations']={'receiver_saturation':{'value':None,'collected':True}}
        self.assertEqual(assess_recording(r)['observations']['receiver_saturation']['status'],'VALUE_UNAVAILABLE')

    def test_path_traversal_rejected(self):
        r=incomplete_record();r['source_path']='../../private.bin'
        with self.assertRaisesRegex(ValueError,'repository root'):assess_recording(r,'.')


if __name__=='__main__':unittest.main()
