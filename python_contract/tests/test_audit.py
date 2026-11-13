import csv
import json
import tempfile
import unittest
from pathlib import Path

from phantomradar.audit import (
    DEFAULT_CONFIG, NEGATIVE, POSITIVE, UNKNOWN, audit_file, diagnose,
    grouped_summary, recovery_events, trial_summaries, validate_config, validate_rows,
)


def row(**changes):
    r = dict(source_kind='measurement',device_id='D1',session_id='S1',trial_id='T1',frame_id='0',capture_time_s='0',publish_time_s='0.01',expected_period_s='0.05',point_count='10',adc_clip_fraction='',vendor_sat='',queue_fraction='',packet_loss='',sensor_frame_counter='')
    r.update(changes)
    return r


class AuditTests(unittest.TestCase):
    def test_missing_telemetry_is_unknown_and_empty_is_ambiguous(self):
        f = diagnose(validate_rows([row(point_count='0')]), validate_config())[0]
        self.assertEqual(f['receiver_evidence_flag'], UNKNOWN)
        self.assertEqual(f['transport_gap_flag'], UNKNOWN)
        self.assertEqual(f['empty_output_flag'], POSITIVE)
        self.assertEqual(f['output_interpretation'], 'EMPTY_OUTPUT_AMBIGUOUS')
        self.assertNotIn('damage', f)

    def test_observed_clipping_flag_does_not_require_vendor_counter(self):
        f = diagnose(validate_rows([row(adc_clip_fraction='0.02')]), validate_config())[0]
        self.assertEqual(f['adc_clipping_flag'], POSITIVE)
        self.assertEqual(f['receiver_evidence_flag'], POSITIVE)
        self.assertEqual(f['vendor_saturation_flag'], UNKNOWN)

    def test_measured_zero_is_distinct_from_missing(self):
        rows = validate_rows([row(adc_clip_fraction='0', vendor_sat='0', queue_fraction='0', packet_loss='0')])
        f = diagnose(rows, validate_config())[0]
        self.assertEqual(f['receiver_evidence_flag'], NEGATIVE)
        self.assertEqual(f['queue_pressure_flag'], NEGATIVE)
        self.assertEqual(f['transport_gap_flag'], UNKNOWN)  # no counter history

    def test_missing_counter_cannot_be_inferred_from_frame_ids(self):
        rows = validate_rows([row(), row(frame_id='7',capture_time_s='0.1',publish_time_s='0.11')])
        f = diagnose(rows, validate_config())[1]
        self.assertEqual(f['counter_gap_flag'], UNKNOWN)
        self.assertEqual(f['transport_gap_flag'], UNKNOWN)

    def test_counter_jump_positive_reset_unknown(self):
        rows = validate_rows([row(sensor_frame_counter='10'), row(frame_id='1',capture_time_s='.05',publish_time_s='.06',sensor_frame_counter='12'), row(frame_id='2',capture_time_s='.1',publish_time_s='.11',sensor_frame_counter='0')])
        f = diagnose(rows, validate_config())
        self.assertEqual(f[1]['counter_gap_flag'], POSITIVE)
        self.assertEqual(f[2]['counter_gap_flag'], UNKNOWN)

    def test_denominators_exclude_unknown_not_zero(self):
        rows = validate_rows([row(adc_clip_fraction='0.02'),row(frame_id='1',capture_time_s='.05',publish_time_s='.06'),row(frame_id='2',capture_time_s='.10',publish_time_s='.11',adc_clip_fraction='0')])
        summary = trial_summaries(diagnose(rows,validate_config()))[0]
        self.assertEqual(summary['adc_clipping_positive_count'],1)
        self.assertEqual(summary['adc_clipping_observed_count'],2)
        self.assertEqual(summary['adc_clipping_unknown_count'],1)
        self.assertEqual(summary['adc_clipping_rate'],.5)
        self.assertIsNone(summary['queue_pressure_rate'])

    def test_duplicate_frames_fail_even_if_timestamp_differs(self):
        with self.assertRaisesRegex(ValueError,'Duplicate frame'):
            validate_rows([row(),row(capture_time_s='1',publish_time_s='1.01')])

    def test_mixed_sources_fail(self):
        with self.assertRaisesRegex(ValueError,'Mixed source_kind'):
            validate_rows([row(),row(frame_id='1',source_kind='synthetic_demo')],demo=True)

    def test_demo_cannot_be_empirical(self):
        with self.assertRaisesRegex(ValueError,'cannot produce an empirical'):
            validate_rows([row(source_kind='synthetic_demo')])

    def test_missing_publish_time_not_zero_latency(self):
        f=diagnose(validate_rows([row(publish_time_s='')]),validate_config())[0]
        self.assertIsNone(f['publication_latency_s'])
        self.assertEqual(f['publication_late_flag'],UNKNOWN)

    def test_timing_threshold_boundary(self):
        frames=diagnose(validate_rows([row(publish_time_s='.05'),row(frame_id='1',capture_time_s='.1',publish_time_s='.16')]),validate_config())
        self.assertEqual(frames[0]['publication_late_flag'],NEGATIVE)
        self.assertEqual(frames[1]['publication_late_flag'],POSITIVE)

    def test_group_mean_weights_trials_and_bootstrap_is_repeatable(self):
        frames=diagnose(validate_rows([row(adc_clip_fraction='.1'),row(trial_id='T2',adc_clip_fraction='0'),row(trial_id='T2',frame_id='1',capture_time_s='.1',publish_time_s='.11',adc_clip_fraction='0')]),validate_config())
        t=trial_summaries(frames)
        a,b=grouped_summary(t,validate_config()),grouped_summary(t,validate_config())
        self.assertEqual(a,b)
        m=next(x for x in a if x['group_level']=='device' and x['metric']=='adc_clipping')
        self.assertEqual(m['mean_rate'],.5)
        self.assertEqual(m['observed_trial_count'],2)

    def test_no_ci_for_single_trial_or_no_observations(self):
        g=grouped_summary(trial_summaries(diagnose(validate_rows([row()]),validate_config())),validate_config())
        self.assertTrue(all(x['ci_low'] is None for x in g))
        self.assertIsNone(next(x for x in g if x['metric']=='adc_clipping')['mean_rate'])

    def test_recovery_requires_consecutive_observed_clear_frames(self):
        r=[row(adc_clip_fraction='.1',vendor_sat='1',queue_fraction='0',packet_loss='0',sensor_frame_counter='10')]
        for i in range(1,4):
            r.append(row(frame_id=str(i),capture_time_s=str(i*.05),publish_time_s=str(i*.05+.01),adc_clip_fraction='0',vendor_sat='0',queue_fraction='0',packet_loss='0',sensor_frame_counter=str(10+i),point_count='0'))
        events=recovery_events(diagnose(validate_rows(r),validate_config()),validate_config())
        self.assertEqual(events[0]['clear_observed'],1)
        self.assertAlmostEqual(events[0]['candidate_clear_time_s'],.15)
        r[-1]['vendor_sat']=''
        events=recovery_events(diagnose(validate_rows(r),validate_config()),validate_config())
        self.assertEqual(events[0]['clear_observed'],0)
        self.assertIsNone(events[0]['candidate_clear_time_s'])

    def test_observable_valid_allows_observed_empty_scene(self):
        r=[row(adc_clip_fraction='0',vendor_sat='0',queue_fraction='0',packet_loss='0',sensor_frame_counter='10'),
           row(frame_id='1',capture_time_s='.05',publish_time_s='.06',adc_clip_fraction='0',vendor_sat='0',queue_fraction='0',packet_loss='0',sensor_frame_counter='11',point_count='0')]
        f=diagnose(validate_rows(r),validate_config())[1]
        self.assertEqual(f['observable_state'],'VALID')
        self.assertEqual(f['empty_output_flag'],POSITIVE)
        self.assertEqual(f['observable_reasons'],'all_required_flags_negative')
        self.assertEqual(f['output_interpretation'],'EMPTY_OUTPUT_AMBIGUOUS')

    def test_observable_unknown_when_required_evidence_missing(self):
        f=diagnose(validate_rows([row(adc_clip_fraction='0',vendor_sat='0',queue_fraction='0')]),validate_config())[0]
        self.assertEqual(f['observable_state'],'UNKNOWN')
        self.assertIn('transport_gap:UNKNOWN',f['observable_reasons'])
        self.assertNotIn('empty_output',f['observable_reasons'])

    def test_degraded_has_priority_over_missing_required_flags(self):
        f=diagnose(validate_rows([row(adc_clip_fraction='.2')]),validate_config())[0]
        self.assertEqual(f['observable_state'],'DEGRADED')
        self.assertIn('receiver_evidence:POSITIVE',f['observable_reasons'])
        self.assertIn('queue_pressure:UNKNOWN',f['observable_reasons'])

    def test_only_configured_flags_control_observable_state(self):
        f=diagnose(validate_rows([row(point_count='0')]),validate_config({'required_flags':['publication_late']}))[0]
        self.assertEqual(f['observable_state'],'VALID')
        self.assertEqual(f['receiver_evidence_flag'],UNKNOWN)

    def test_invalid_required_flag_configuration_rejected(self):
        for value in [[],['hardware_damage'],['receiver_evidence','receiver_evidence'],'receiver_evidence']:
            with self.assertRaisesRegex(ValueError,'required_flags'):
                validate_config({'required_flags':value})

    def test_demo_exports_marked_and_provenance_hashed(self):
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp)/'demo.csv'
            r=row(source_kind='synthetic_demo')
            with p.open('w',newline='') as f:
                w=csv.DictWriter(f,fieldnames=list(r)); w.writeheader(); w.writerow(r)
            report=audit_file(p,Path(temp)/'out',demo=True)
            self.assertTrue(all(x['filename'].startswith('DEMO_') for x in report['outputs']))
            self.assertEqual(len(report['input_sha256']),64)
            self.assertIn('NOT HARDWARE MEASUREMENTS',report['label'])

    def test_invalid_fraction_and_clock_order_rejected(self):
        for r in [row(adc_clip_fraction='1.1'),row(publish_time_s='-1'),row(point_count='NaN')]:
            with self.assertRaises(ValueError):
                validate_rows([r])


if __name__=='__main__':
    unittest.main()
