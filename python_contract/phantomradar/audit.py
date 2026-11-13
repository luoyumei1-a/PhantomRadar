"""Traceable offline diagnostics. Candidate flags are not hardware root causes."""
from __future__ import annotations

import csv
import hashlib
import json
import math
import random
from collections import defaultdict
from pathlib import Path

POSITIVE, NEGATIVE, UNKNOWN = 'POSITIVE', 'NEGATIVE', 'UNKNOWN'
METRICS = [
    'adc_clipping', 'vendor_saturation', 'receiver_evidence',
    'publication_late', 'queue_pressure', 'transport_gap', 'empty_output',
    'regional_support',
]
DEFAULT_CONFIG = {
    'adc_clip_fraction_threshold': 0.01,
    'publication_lateness_factor': 1.0,
    'queue_fraction_threshold': 0.8,
    'packet_loss_threshold': 0.0,
    'recovery_consecutive_frames': 3,
    'recovery_max_capture_gap_factor': 2.0,
    'bootstrap_replicates': 1000,
    'bootstrap_seed': 20261030,
    'confidence_level': 0.95,
    'monitor_thresholds': [0.0, 0.001, 0.005, 0.01, 0.02, 0.05, 0.1],
    'required_flags': ['receiver_evidence', 'publication_late', 'queue_pressure', 'transport_gap'],
}
REQUIRED = [
    'source_kind', 'device_id', 'session_id', 'trial_id', 'frame_id',
    'capture_time_s', 'publish_time_s', 'expected_period_s', 'point_count',
    'adc_clip_fraction', 'vendor_sat', 'queue_fraction', 'packet_loss',
]


def numeric(value, name, nullable=False, low=None, high=None, integer=False):
    if value is None or str(value).strip() == '':
        if nullable:
            return None
        raise ValueError(f'Missing {name}')
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f'Invalid {name}: {value!r}') from exc
    if not math.isfinite(number):
        raise ValueError(f'Nonfinite {name}')
    if low is not None and number < low or high is not None and number > high:
        raise ValueError(f'Out of range {name}: {number}')
    if integer:
        if number != int(number):
            raise ValueError(f'Noninteger {name}')
        return int(number)
    return number


def boolean(value, name):
    if value is None or str(value).strip() == '':
        return None
    key = str(value).strip().lower()
    if key in ('1', 'true'):
        return True
    if key in ('0', 'false'):
        return False
    raise ValueError(f'Invalid {name}: expected blank, true/false, or 1/0')


def validate_config(config=None):
    supplied = config or {}
    unknown = set(supplied) - set(DEFAULT_CONFIG)
    if unknown:
        raise ValueError(f'Unknown config keys: {sorted(unknown)}')
    out = dict(DEFAULT_CONFIG, **supplied)
    for name in ['adc_clip_fraction_threshold', 'queue_fraction_threshold', 'packet_loss_threshold']:
        out[name] = numeric(out[name], name, low=0, high=1)
    out['publication_lateness_factor'] = numeric(out['publication_lateness_factor'], 'publication_lateness_factor', low=0.000001)
    out['recovery_max_capture_gap_factor'] = numeric(out['recovery_max_capture_gap_factor'], 'recovery_max_capture_gap_factor', low=1)
    for name in ['recovery_consecutive_frames', 'bootstrap_replicates']:
        out[name] = numeric(out[name], name, low=1, integer=True)
    out['bootstrap_seed'] = numeric(out['bootstrap_seed'], 'bootstrap_seed', integer=True)
    out['confidence_level'] = numeric(out['confidence_level'], 'confidence_level', low=0.01, high=0.999)
    out['monitor_thresholds'] = sorted(set(numeric(v, 'monitor_thresholds', low=0, high=1) for v in out['monitor_thresholds']))
    if not out['monitor_thresholds']:
        raise ValueError('monitor_thresholds must not be empty')
    required = out['required_flags']
    if not isinstance(required, list) or not required or any(not isinstance(v, str) or v not in METRICS for v in required) or len(set(required)) != len(required):
        raise ValueError('required_flags must be a nonempty list of unique supported metric names')
    out['required_flags'] = list(required)
    return out


def validate_rows(rows, demo=False):
    if not rows:
        raise ValueError('No frame records')
    parsed, seen, kinds = [], set(), set()
    for row_number, row in enumerate(rows, 2):
        if set(REQUIRED) - set(row):
            raise ValueError(f'Row {row_number}: missing columns {sorted(set(REQUIRED)-set(row))}')
        r = {}
        for name in ['source_kind', 'device_id', 'session_id', 'trial_id']:
            r[name] = str(row[name]).strip()
            if not r[name]:
                raise ValueError(f'Row {row_number}: missing {name}')
        if r['source_kind'] not in ('measurement', 'synthetic_demo'):
            raise ValueError(f'Row {row_number}: unsupported source_kind')
        kinds.add(r['source_kind'])
        r['frame_id'] = numeric(row['frame_id'], 'frame_id', low=0, integer=True)
        for name in ['capture_time_s', 'publish_time_s']:
            r[name] = numeric(row[name], name, nullable=name == 'publish_time_s', low=0)
        r['expected_period_s'] = numeric(row['expected_period_s'], 'expected_period_s', low=0.000000001)
        r['point_count'] = numeric(row['point_count'], 'point_count', nullable=True, low=0, integer=True)
        for name in ['adc_clip_fraction', 'queue_fraction', 'packet_loss']:
            r[name] = numeric(row[name], name, nullable=True, low=0, high=1)
        r['vendor_sat'] = boolean(row['vendor_sat'], 'vendor_sat')
        r['sensor_frame_counter'] = numeric(row.get('sensor_frame_counter'), 'sensor_frame_counter', nullable=True, low=0, integer=True)
        r['reference_qualified'] = boolean(row.get('reference_qualified'), 'reference_qualified')
        r['region_point_count'] = numeric(row.get('region_point_count'), 'region_point_count', nullable=True, low=0, integer=True)
        if r['region_point_count'] is not None and r['point_count'] is not None and r['region_point_count'] > r['point_count']:
            raise ValueError(f'Row {row_number}: regional count exceeds whole-cloud count')
        if r['publish_time_s'] is not None and r['publish_time_s'] < r['capture_time_s']:
            raise ValueError(f'Row {row_number}: publish precedes capture; synchronize clocks before audit')
        key = tuple(r[k] for k in ['device_id', 'session_id', 'trial_id', 'frame_id'])
        if key in seen:
            raise ValueError(f'Duplicate frame key: {key}')
        seen.add(key)
        parsed.append(r)
    if len(kinds) != 1:
        raise ValueError('Mixed source_kind values are forbidden; audit measurement and synthetic data separately')
    kind = next(iter(kinds))
    if kind == 'synthetic_demo' and not demo:
        raise ValueError('Synthetic input cannot produce an empirical report; pass --demo for explicitly marked demonstration outputs')
    if kind == 'measurement' and demo:
        raise ValueError('--demo is reserved for synthetic_demo inputs')
    return sorted(parsed, key=lambda r: (r['device_id'], r['session_id'], r['trial_id'], r['capture_time_s'], r['frame_id']))


def flag(value, predicate):
    return UNKNOWN if value is None else POSITIVE if predicate(value) else NEGATIVE


def tri_or(*flags):
    if POSITIVE in flags:
        return POSITIVE
    return UNKNOWN if UNKNOWN in flags else NEGATIVE


def diagnose(rows, config):
    previous = {}
    output = []
    for r in rows:
        d = dict(r)
        key = (r['device_id'], r['session_id'], r['trial_id'])
        prior = previous.get(key)
        counter_flag = UNKNOWN
        current_counter = r['sensor_frame_counter']
        if prior is not None and current_counter is not None and prior['sensor_frame_counter'] is not None:
            delta = current_counter - prior['sensor_frame_counter']
            # A reset/wrap/duplicate counter is ambiguous without a device-specific modulus.
            if delta > 0:
                counter_flag = POSITIVE if delta > 1 else NEGATIVE
        d['counter_gap_flag'] = counter_flag
        d['adc_clipping_flag'] = flag(r['adc_clip_fraction'], lambda x: x > config['adc_clip_fraction_threshold'])
        d['vendor_saturation_flag'] = flag(r['vendor_sat'], bool)
        d['receiver_evidence_flag'] = tri_or(d['adc_clipping_flag'], d['vendor_saturation_flag'])
        d['publication_latency_s'] = None if r['publish_time_s'] is None else r['publish_time_s'] - r['capture_time_s']
        d['publication_late_flag'] = flag(d['publication_latency_s'], lambda x: x > config['publication_lateness_factor'] * r['expected_period_s'])
        d['queue_pressure_flag'] = flag(r['queue_fraction'], lambda x: x >= config['queue_fraction_threshold'])
        loss_flag = flag(r['packet_loss'], lambda x: x > config['packet_loss_threshold'])
        d['transport_gap_flag'] = tri_or(loss_flag, counter_flag)
        d['empty_output_flag'] = flag(r['point_count'], lambda x: x == 0)
        d['regional_support_flag'] = (
            flag(r['region_point_count'], lambda x: x == 0)
            if r['reference_qualified'] is True else UNKNOWN
        )
        required = [(name, d[name + '_flag']) for name in config['required_flags']]
        if any(value == POSITIVE for _, value in required):
            d['observable_state'] = 'DEGRADED'
        elif any(value == UNKNOWN for _, value in required):
            d['observable_state'] = 'UNKNOWN'
        else:
            d['observable_state'] = 'VALID'
        d['observable_reasons'] = ';'.join(f'{name}:{value}' for name, value in required if value != NEGATIVE) or 'all_required_flags_negative'
        d['output_interpretation'] = 'OUTPUT_UNKNOWN' if r['point_count'] is None else 'EMPTY_OUTPUT_AMBIGUOUS' if r['point_count'] == 0 else 'NONEMPTY_OUTPUT_NOT_TARGET_VALIDATION'
        output.append(d)
        previous[key] = r
    return output


def trial_summaries(frames):
    groups = defaultdict(list)
    for f in frames:
        groups[tuple(f[k] for k in ['source_kind', 'device_id', 'session_id', 'trial_id'])].append(f)
    result = []
    for key, items in sorted(groups.items()):
        r = dict(zip(['source_kind', 'device_id', 'session_id', 'trial_id'], key))
        r['frame_count'] = len(items)
        for metric in METRICS:
            observed = [f[metric + '_flag'] for f in items if f[metric + '_flag'] != UNKNOWN]
            positive = sum(v == POSITIVE for v in observed)
            r[metric + '_observed_count'] = len(observed)
            r[metric + '_positive_count'] = positive
            r[metric + '_unknown_count'] = len(items) - len(observed)
            r[metric + '_rate'] = positive / len(observed) if observed else None
        latencies = [f['publication_latency_s'] for f in items if f['publication_latency_s'] is not None]
        r['publication_latency_observed_count'] = len(latencies)
        r['mean_publication_latency_s'] = sum(latencies) / len(latencies) if latencies else None
        result.append(r)
    return result


def quantile(values, q):
    v = sorted(values)
    at = (len(v) - 1) * q
    low, high = math.floor(at), math.ceil(at)
    return v[low] + (v[high] - v[low]) * (at - low)


def grouped_summary(trials, config):
    rng = random.Random(config['bootstrap_seed'])
    results = []
    groupings = [('device', ['device_id']), ('session', ['device_id', 'session_id'])]
    for level, keys in groupings:
        groups = defaultdict(list)
        for t in trials:
            groups[tuple(t[k] for k in keys)].append(t)
        for key, items in sorted(groups.items()):
            for metric in METRICS:
                values = [t[metric + '_rate'] for t in items if t[metric + '_rate'] is not None]
                low = high = None
                if len(values) >= 2:
                    draws = [sum(rng.choices(values, k=len(values))) / len(values) for _ in range(config['bootstrap_replicates'])]
                    alpha = (1 - config['confidence_level']) / 2
                    low, high = quantile(draws, alpha), quantile(draws, 1 - alpha)
                r = {'source_kind': items[0]['source_kind'], 'group_level': level, 'device_id': key[0], 'session_id': key[1] if len(key) > 1 else 'ALL', 'metric': metric,
                     'estimand': 'equal_weight_mean_of_observed_trial_rates', 'trial_count': len(items), 'observed_trial_count': len(values),
                     'observed_frame_count': sum(t[metric + '_observed_count'] for t in items),
                     'mean_rate': sum(values) / len(values) if values else None, 'ci_low': low, 'ci_high': high,
                     'confidence_level': config['confidence_level'], 'resampling_unit': 'trial_within_group', 'bootstrap_replicates': config['bootstrap_replicates']}
                results.append(r)
    return results


def recovery_events(frames, config):
    groups = defaultdict(list)
    for f in frames:
        groups[tuple(f[k] for k in ['source_kind', 'device_id', 'session_id', 'trial_id'])].append(f)
    results = []
    for key, items in sorted(groups.items()):
        active, streak, previous_time, event_num = None, 0, None, 0
        for f in items:
            now = f['capture_time_s']
            if f['observable_state'] == 'DEGRADED' and active is None:
                event_num += 1
                active = dict(zip(['source_kind', 'device_id', 'session_id', 'trial_id'], key))
                active.update(event_id=event_num, onset_capture_time_s=now, unknown_frame_count=0)
            if active is not None:
                if f['observable_state'] == 'UNKNOWN':
                    active['unknown_frame_count'] += 1
                if previous_time is not None and now - previous_time > config['recovery_max_capture_gap_factor'] * f['expected_period_s']:
                    streak = 0
                clear = f['observable_state'] == 'VALID'
                streak = streak + 1 if clear else 0
                if streak >= config['recovery_consecutive_frames']:
                    active.update(clear_observed=1, clear_capture_time_s=now, observation_duration_s=now-active['onset_capture_time_s'], candidate_clear_time_s=now-active['onset_capture_time_s'])
                    results.append(active)
                    active, streak = None, 0
            previous_time = now
        if active is not None:
            active.update(clear_observed=0, clear_capture_time_s=None, observation_duration_s=items[-1]['capture_time_s']-active['onset_capture_time_s'], candidate_clear_time_s=None)
            results.append(active)
    return results


def threshold_sensitivity(frames, config):
    groups = defaultdict(list)
    for f in frames:
        groups[(f['source_kind'], f['device_id'])].append(f)
    output = []
    for (kind, device), items in sorted(groups.items()):
        observed = [f['adc_clip_fraction'] for f in items if f['adc_clip_fraction'] is not None]
        for threshold in config['monitor_thresholds']:
            alerts = sum(v > threshold for v in observed)
            output.append({'source_kind': kind, 'device_id': device, 'threshold': threshold, 'frame_count': len(items), 'observed_count': len(observed),
                           'unknown_count': len(items)-len(observed), 'alert_count': alerts,
                           'alert_fraction_observed': alerts/len(observed) if observed else None,
                           'telemetry_coverage': len(observed)/len(items) if items else None,
                           'interpretation': 'diagnostic_threshold_sensitivity_not_accuracy_or_ROC'})
    return output


def write_csv(path, rows, fieldnames=None):
    names = fieldnames or (list(rows[0]) if rows else [])
    with path.open('w', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=names)
        writer.writeheader()
        writer.writerows(rows)


def audit_file(input_path, output_dir, config_path=None, demo=False):
    input_path, output_dir = Path(input_path), Path(output_dir)
    config = validate_config(json.loads(Path(config_path).read_text()) if config_path else None)
    with input_path.open(newline='', encoding='utf-8-sig') as handle:
        rows = validate_rows(list(csv.DictReader(handle)), demo=demo)
    frames = diagnose(rows, config)
    trials = trial_summaries(frames)
    groups = grouped_summary(trials, config)
    recoveries = recovery_events(frames, config)
    sensitivity = threshold_sensitivity(frames, config)
    output_dir.mkdir(parents=True, exist_ok=True)
    prefix = 'DEMO_' if demo else ''
    tables = {'frame_diagnostics.csv': frames, 'per_trial.csv': trials, 'group_summary.csv': groups, 'recovery_events.csv': recoveries, 'threshold_sensitivity.csv': sensitivity}
    for name, data in tables.items():
        fields = None
        if name == 'recovery_events.csv':
            fields = ['source_kind','device_id','session_id','trial_id','event_id','onset_capture_time_s','unknown_frame_count','clear_observed','clear_capture_time_s','observation_duration_s','candidate_clear_time_s']
        write_csv(output_dir/(prefix+name), data, fields)
    config_bytes = (json.dumps(config, sort_keys=True, indent=2)+'\n').encode()
    (output_dir/(prefix+'resolved_config.json')).write_bytes(config_bytes)
    provenance = {
        'project': 'PhantomRadar', 'version': '0.2.0', 'source_kind': rows[0]['source_kind'], 'demo': demo,
        'label': 'SYNTHETIC DEMO - NOT HARDWARE MEASUREMENTS' if demo else 'OFFLINE DIAGNOSTIC ANALYSIS OF USER-SUPPLIED MEASUREMENT',
        'input_filename': input_path.name, 'input_sha256': hashlib.sha256(input_path.read_bytes()).hexdigest(),
        'resolved_config_sha256': hashlib.sha256(config_bytes).hexdigest(), 'frame_count': len(frames), 'trial_count': len(trials),
        'empirical_hardware_findings_established_by_this_artifact': False,
        'observable_state_definition': 'Any configured required flag positive => DEGRADED; otherwise any required flag unknown => UNKNOWN; otherwise VALID.',
        'limitations': ['Flags and contract states describe supplied observables only.', 'VALID does not establish target/reference completeness, correct scene perception or task safety.', 'No physical root cause or hardware damage is inferred.', 'Point count is not target-detection correctness.', 'CIs resample trials within each group; they do not establish cross-session or cross-device generalization.', 'Threshold sensitivity is not detection accuracy or an ROC curve.'],
        'outputs': [{'filename': prefix+name, 'sha256': hashlib.sha256((output_dir/(prefix+name)).read_bytes()).hexdigest()} for name in tables],
    }
    (output_dir/(prefix+'provenance.json')).write_text(json.dumps(provenance, indent=2)+'\n')
    return provenance
