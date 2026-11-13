import unittest
from phantomradar.replay_reference import evaluate_record, clearance_events, VALID, DEGRADED, UNKNOWN


def record(**changes):
    value = dict(slot=2, payload_count=10, delivered=True, payload_id=2, capture_s=1, publish_s=1.1)
    value.update(changes)
    return value


class ReplayReferenceTests(unittest.TestCase):
    def test_reference_and_audit_agree_across_missing_patterns(self):
        for delivered in (True, False):
            for capture in (None, 0.0, 1.0):
                for publish in (None, 1.1, 5.0):
                    for pid in (None, 1, 2):
                        states=evaluate_record(record(delivered=delivered,capture_s=capture,publish_s=publish,payload_id=pid),1)
                        self.assertEqual(states['Reference3V'],states['PhantomRadar'])

    def test_arrival_watchdog_can_accept_stale_payload(self):
        states=evaluate_record(record(payload_id=1,capture_s=0),1)
        self.assertEqual(states['ArrivalHeartbeat'],VALID)
        self.assertEqual(states['SequenceGuard'],DEGRADED)
        self.assertEqual(states['PhantomRadar'],DEGRADED)

    def test_sequence_guard_can_accept_late_publication(self):
        states=evaluate_record(record(publish_s=4),1)
        self.assertEqual(states['SequenceGuard'],VALID)
        self.assertEqual(states['ArrivalHeartbeat'],DEGRADED)
        self.assertEqual(states['PhantomRadar'],DEGRADED)

    def test_metadata_withholding_keeps_missing_observations_unknown(self):
        states=evaluate_record(record(capture_s=None,payload_id=None),1)
        self.assertEqual(states['Zero'],VALID)
        self.assertEqual(states['PhantomRadar'],UNKNOWN)
        self.assertEqual(states['ArrivalHeartbeat'],VALID)

    def test_delivered_empty_is_distinct_from_failed_delivery(self):
        states=evaluate_record(record(payload_count=0),1)
        self.assertEqual(states['Output'],DEGRADED)
        self.assertEqual(states['PhantomRadar'],VALID)
        states=evaluate_record(record(delivered=False,payload_count=None,payload_id=None,capture_s=None,publish_s=None),1)
        self.assertTrue(all(state==DEGRADED for state in states.values()))

    def test_freshness_alpha_changes_only_declared_age_threshold(self):
        sample=record(publish_s=2)
        self.assertEqual(evaluate_record(sample,1,.5)['PhantomRadar'],DEGRADED)
        self.assertEqual(evaluate_record(sample,1,1.5)['PhantomRadar'],VALID)
        self.assertEqual(evaluate_record(sample,1,.5)['SequenceGuard'],VALID)

    def test_recovery_count_changes_clearance_not_slot_classification(self):
        states=[VALID,DEGRADED,VALID,UNKNOWN,VALID,VALID,VALID]
        one=clearance_events(states,1,1)
        three=clearance_events(states,1,3)
        self.assertEqual(one[0]['clear_slot'],3)
        self.assertEqual(three[0]['clear_slot'],7)
        self.assertEqual(states,[VALID,DEGRADED,VALID,UNKNOWN,VALID,VALID,VALID])

    def test_endpoint_clearance_is_right_censored(self):
        events=clearance_events([VALID,DEGRADED,VALID],.1,3)
        self.assertFalse(events[0]['clear_observed'])
        self.assertIsNone(events[0]['clear_s'])
        self.assertAlmostEqual(events[0]['observation_duration_s'],.1)

    def test_invalid_configuration_fails(self):
        for period in (0,-1,None,float('nan')):
            with self.assertRaises(ValueError):evaluate_record(record(),period)
        for h in (0,1.5,True):
            with self.assertRaises(ValueError):clearance_events([VALID],1,h)


if __name__=='__main__':unittest.main()
