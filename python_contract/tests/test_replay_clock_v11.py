"""Checks for composition, observation scope and censored replay events."""
import unittest
from phantomradar.replay_reference import (
    evaluate_record_v11, clearance_events_on_clock, POLICIES_V11,
    VALID, DEGRADED, UNKNOWN)


def record(**changes):
    value = dict(slot=3, payload_count=10, delivered=True, payload_id=3,
                 expected_s=.0615, capture_s=.0615, publish_s=.0673)
    value.update(changes)
    return value


class ExplicitClockTests(unittest.TestCase):
    def test_irregular_source_clock_is_used_for_arrival(self):
        states = evaluate_record_v11(record(), .0582)
        self.assertEqual(tuple(states), POLICIES_V11)
        self.assertEqual(states['BeatSeq'], VALID)
        self.assertEqual(states['ArrivalHeartbeat'], VALID)

    def test_composition_catches_stale_and_late_observations(self):
        stale = evaluate_record_v11(record(payload_id=2), .0582)
        self.assertEqual(stale['ArrivalHeartbeat'], VALID)
        self.assertEqual(stale['BeatSeq'], DEGRADED)
        late = evaluate_record_v11(record(publish_s=.24), .0582)
        self.assertEqual(late['SequenceGuard'], VALID)
        self.assertEqual(late['BeatSeq'], DEGRADED)

    def test_age_and_arrival_require_different_observations(self):
        states = evaluate_record_v11(record(capture_s=None), .0582)
        self.assertEqual(states['BeatSeq'], VALID)
        self.assertEqual(states['PhantomRadar'], UNKNOWN)
        states = evaluate_record_v11(record(expected_s=None), .0582)
        self.assertEqual(states['BeatSeq'], UNKNOWN)
        self.assertEqual(states['PhantomRadar'], VALID)

    def test_positive_violation_dominates_missing_clock(self):
        states = evaluate_record_v11(record(expected_s=None, payload_id=2), .0582)
        self.assertEqual(states['BeatSeq'], DEGRADED)
        states = evaluate_record_v11(record(delivered=False, publish_s=None), .0582)
        self.assertTrue(all(value == DEGRADED for value in states.values()))

    def test_duration_uses_observed_nonuniform_clock(self):
        states = [VALID, DEGRADED, VALID, UNKNOWN, VALID, VALID, VALID]
        times = [0, .0600, .0615, .1200, .1213, .1800, .1812]
        events = clearance_events_on_clock(states, times, 3)
        self.assertEqual(events[0]['clear_slot'], 7)
        self.assertAlmostEqual(events[0]['observation_duration_s'], .1212)

    def test_hth_valid_at_endpoint_is_observed_not_censored(self):
        events = clearance_events_on_clock([DEGRADED, VALID, VALID, VALID], [0, .01, .2, .21], 3)
        self.assertTrue(events[0]['clear_observed'])
        self.assertEqual(events[0]['clear_slot'], 4)

    def test_insufficient_tail_and_terminal_fault_remain_censored(self):
        for states in ([VALID, DEGRADED, VALID], [VALID, VALID, DEGRADED]):
            events = clearance_events_on_clock(states, [0, .01, .2], 3)
            self.assertFalse(events[0]['clear_observed'])
            self.assertIsNone(events[0]['clear_s'])

    def test_invalid_clock_rejected(self):
        for times in ([0], [0, 0], [0, None], [1, 0]):
            with self.assertRaises(ValueError):
                clearance_events_on_clock([VALID, DEGRADED], times)


if __name__ == '__main__':
    unittest.main()
