"""Independent record-policy references, not receiver-fault detectors.

Input clocks and periods describe an explicitly declared software replay.
The reference monitor uses strong-Kleene OR independently of phantomradar.audit.
"""
from __future__ import annotations

import math

VALID, DEGRADED, UNKNOWN = 1, 2, 3
POLICIES = ('Output', 'Fresh', 'Zero', 'ArrivalHeartbeat', 'SequenceGuard', 'Reference3V', 'PhantomRadar')
# Frozen v10 entry points above/below remain available to verify the historical
# uniform-clock exports byte-for-byte.  v11 makes the replay clock explicit.
POLICIES_V11 = ('Output', 'Fresh', 'Zero', 'ArrivalHeartbeat', 'SequenceGuard',
                'BeatSeq', 'Reference3V', 'PhantomRadar')


def _number(value):
    if value is None or value == '':
        return None
    number = float(value)
    return number if math.isfinite(number) else None


def _or_state(values):
    # True/False/None are violation observations, not ground-truth labels.
    if any(value is True for value in values):
        return DEGRADED
    if any(value is None for value in values):
        return UNKNOWN
    return VALID


def evaluate_record(record, period_s, alpha=1.5):
    """Return seven policy states on identical record observations.

    record fields: slot, payload_count, delivered, payload_id, capture_s,
    publish_s. Missing scalar observations are None or NaN. The expected slot
    schedule begins at time zero. A timestamp is meaningful only under the
    declared, shared replay clock; this routine performs no clock calibration.
    """
    period = _number(period_s)
    threshold = _number(alpha)
    if period is None or period <= 0 or threshold is None or threshold <= 0:
        raise ValueError('period_s and alpha must be finite and positive')
    slot = _number(record['slot'])
    if slot is None or slot < 1 or not slot.is_integer():
        raise ValueError('slot must be a positive integer')
    delivered_value = record['delivered']
    if delivered_value not in (True, False, 0, 1):
        raise ValueError('delivered must be a Boolean or binary delivery observation')
    delivered = bool(delivered_value)
    count = _number(record.get('payload_count'))
    pid = _number(record.get('payload_id'))
    capture = _number(record.get('capture_s'))
    publish = _number(record.get('publish_s'))
    missing = not delivered
    late = None if capture is None or publish is None else publish - capture > threshold * period
    identity = None if pid is None else pid != slot
    arrival = None if publish is None else publish - (slot - 1) * period > 1.5 * period
    flags = [missing, late, identity]
    output = VALID if delivered and count is not None and count > 0 else DEGRADED
    fresh = _or_state([missing, late])
    zero = DEGRADED if any(value is True for value in flags) else VALID
    reference = _or_state(flags)
    # A separate count expression tests agreement with the OR formulation.
    positive = sum(value is True for value in flags)
    unavailable = sum(value is None for value in flags)
    audit = DEGRADED if positive else UNKNOWN if unavailable else VALID
    return dict(zip(POLICIES, [output, fresh, zero,
        _or_state([missing, arrival]), _or_state([missing, identity]), reference, audit]))


def clearance_events(states, period_s, consecutive_valid=3):
    """Observable event clearance on a declared uniform replay schedule.

    Unknown interrupts a valid streak. Events that do not clear are retained
    through the final observed slot and marked right-censored. No event is a
    claim of physical repair, receiver recovery, or target reacquisition.
    """
    period = _number(period_s)
    if period is None or period <= 0:
        raise ValueError('period_s must be finite and positive')
    if isinstance(consecutive_valid, bool) or not isinstance(consecutive_valid, int) or consecutive_valid < 1:
        raise ValueError('consecutive_valid must be a positive integer')
    events, active, streak = [], None, 0
    for index, state in enumerate(states, 1):
        if state not in (VALID, DEGRADED, UNKNOWN):
            raise ValueError('unknown contract state')
        if state == DEGRADED and active is None:
            active = {'onset_slot': index, 'onset_s': (index - 1) * period}
            streak = 0
        if active is not None:
            streak = streak + 1 if state == VALID else 0
            if streak >= consecutive_valid:
                end = (index - 1) * period
                events.append(dict(active, clear_slot=index, clear_s=end,
                    observation_duration_s=end-active['onset_s'], clear_observed=True))
                active, streak = None, 0
    if active is not None:
        end = (len(states) - 1) * period
        events.append(dict(active, clear_slot=None, clear_s=None,
            observation_duration_s=end-active['onset_s'], clear_observed=False))
    return events


def evaluate_record_v11(record, period_s, alpha=1.5):
    """Evaluate eight policies with an explicit expected software-replay time.

    ``expected_s`` is the unmodified source group-message timestamp used to
    schedule a replay slot.  ``capture_s`` and ``publish_s`` are observations
    on the declared replay clock, including software transformations.  None
    is interpreted as a physical acquisition clock or a receiver-health bit.
    No uniform expected clock is invented when expected_s is unavailable.

    BeatSeq combines the arrival watchdog and payload-identity guard, with
    the same delivery observation and strong-Kleene missing-data semantics.
    Its fixed 1.5-period arrival deadline matches ArrivalHeartbeat; alpha
    varies the capture-to-publication age requirement only.  BeatSeq can be
    less informative than the full age monitor when capture_s is withheld.
    """
    # Reuse validated v10 observation semantics for the five age/identity
    # policies; replace only the expected-arrival observation and add BeatSeq.
    old = evaluate_record(record, period_s, alpha)
    period = float(period_s)
    expected = _number(record.get('expected_s'))
    publish = _number(record.get('publish_s'))
    slot = float(record['slot'])
    pid = _number(record.get('payload_id'))
    missing = not bool(record['delivered'])
    arrival = None if expected is None or publish is None else publish - expected > 1.5 * period
    identity = None if pid is None else pid != slot
    old['ArrivalHeartbeat'] = _or_state([missing, arrival])
    old['BeatSeq'] = _or_state([missing, arrival, identity])
    return {name: old[name] for name in POLICIES_V11}


def clearance_events_on_clock(states, expected_times_s, consecutive_valid=3):
    """Measure observable clearance using supplied, irregular replay times.

    A clearance is observed only when the h-th consecutive VALID observation
    is present.  This can legitimately occur at the final timestamp.  An
    active event with fewer than h trailing VALID observations is right-
    censored, including an event first observed at the final timestamp.
    UNKNOWN resets the valid streak.  Event durations concern the software
    monitor only, not physical receiver recovery or target reacquisition.
    """
    states, times = list(states), [_number(value) for value in expected_times_s]
    if len(states) != len(times):
        raise ValueError('states and expected_times_s must have equal lengths')
    if any(value is None for value in times):
        raise ValueError('expected_times_s must contain finite observed replay times')
    if any(right <= left for left, right in zip(times, times[1:])):
        raise ValueError('expected_times_s must be strictly increasing')
    if isinstance(consecutive_valid, bool) or not isinstance(consecutive_valid, int) or consecutive_valid < 1:
        raise ValueError('consecutive_valid must be a positive integer')
    events, active, streak = [], None, 0
    for index, (state, time_s) in enumerate(zip(states, times), 1):
        if state not in (VALID, DEGRADED, UNKNOWN):
            raise ValueError('unknown contract state')
        if state == DEGRADED and active is None:
            active = {'onset_slot': index, 'onset_s': time_s}
            streak = 0
        if active is not None:
            streak = streak + 1 if state == VALID else 0
            if streak >= consecutive_valid:
                events.append(dict(active, clear_slot=index, clear_s=time_s,
                    observation_duration_s=time_s-active['onset_s'], clear_observed=True))
                active, streak = None, 0
    if active is not None:
        events.append(dict(active, clear_slot=None, clear_s=None,
            observation_duration_s=times[-1]-active['onset_s'], clear_observed=False))
    return events
