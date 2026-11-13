"""Check referenced acquisition evidence without manufacturing fault labels.

This checker verifies schema, byte identity, source consistency and evidence
completeness. It does not certify that a document, annotation, or measurement
is physically correct. A reported label always retains its supplied reference.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

KNOWN_SOURCE = {
    '316143f1c71a723b6ac207c42f498f95feadb54c5886d307f567c7721c09e585': {
        'manufacturer': 'INRAS', 'device_model': 'Radarbook',
        'scope': 'Recorded floating-point ADC subset from the documented 77-GHz Radarbook collection',
    },
}


def _missing(value):
    return value is None or value == ''


def _refs(block, names):
    return [name for name in names if _missing(block.get(name))]


def _boolean(value, name):
    if value is not None and type(value) is not bool:
        raise ValueError(f'{name} must be true, false, or null')
    return value


def rail_occupancy(samples, low_rail, high_rail):
    """Count equality to explicitly documented, decoded integer ADC rails.

    The result is a descriptor, never a saturation or analog-compression label.
    Observed minima/maxima must not be passed as rails without calibration.
    Out-of-range or fractional values require a decoding/representation fix.
    """
    low, high = float(low_rail), float(high_rail)
    if not all(math.isfinite(v) and v.is_integer() for v in (low, high)) or low >= high:
        raise ValueError('declared rails must be finite, ordered integer codes')
    count = hits = 0
    longest = run = 0
    for value in samples:
        if isinstance(value, bool):
            raise ValueError('Boolean samples are not ADC codes')
        code = float(value)
        if not math.isfinite(code) or not code.is_integer() or not low <= code <= high:
            raise ValueError('sample is not a decoded integer code within the declared rails')
        at_rail = code == low or code == high
        count += 1
        hits += int(at_rail)
        run = run + 1 if at_rail else 0
        longest = max(longest, run)
    if not count:
        raise ValueError('empty sample sequence')
    return {'sample_count': count, 'at_declared_rails': hits,
            'rail_occupancy_fraction': hits / count, 'longest_rail_run': longest,
            'interpretation': 'descriptor_only_not_a_receiver_fault_label'}


def assess_recording(record, root=None):
    identity = ['recording_id', 'source_kind', 'source_path', 'source_sha256',
                'manufacturer', 'device_model', 'source_documentation_ref']
    missing = _refs(record, identity)
    source_hash = record.get('source_sha256')
    conflicts = []
    if record.get('source_kind') != 'recorded_measurement':
        conflicts.append('source_kind is not recorded_measurement')
    if source_hash and (not isinstance(source_hash, str) or len(source_hash) != 64 or any(c not in '0123456789abcdef' for c in source_hash.lower())):
        raise ValueError('source_sha256 must contain 64 hexadecimal characters')
    if source_hash:
        source_hash = source_hash.lower()
    if source_hash and source_hash in KNOWN_SOURCE:
        known = KNOWN_SOURCE[source_hash]
        for key in ('manufacturer', 'device_model'):
            actual = record.get(key)
            if actual and str(actual).casefold() != known[key].casefold():
                conflicts.append(f'{key} conflicts with the immutable recorded-input provenance ({known[key]})')
    checked_hash = None
    if root is not None and record.get('source_path'):
        base = Path(root).resolve()
        source = (base / record['source_path']).resolve()
        if source != base and base not in source.parents:
            raise ValueError('source_path must stay within the repository root')
        if not source.is_file():
            conflicts.append('referenced source_path is absent')
        else:
            checked_hash = hashlib.sha256(source.read_bytes()).hexdigest()
            if source_hash and checked_hash != source_hash:
                conflicts.append('source byte hash differs from source_sha256')
    representation = record.get('representation') or {}
    rep_required = ['native_sample_format', 'adc_bit_width', 'decoded_to_native_codes',
                    'rail_low', 'rail_high', 'decoder_ref', 'full_scale_calibration_ref']
    rep_missing = _refs(representation, rep_required)
    bits = representation.get('adc_bit_width')
    if bits is not None and (type(bits) is not int or not 1 <= bits <= 32):
        raise ValueError('adc_bit_width must be an integer from 1 to 32 or null')
    decoder = _boolean(representation.get('decoded_to_native_codes'), 'decoded_to_native_codes')
    if decoder is False:
        rep_missing.append('decoded_to_native_codes must be true for a native-code claim')
    if not _missing(representation.get('rail_low')) and not _missing(representation.get('rail_high')):
        low, high = float(representation['rail_low']), float(representation['rail_high'])
        if not math.isfinite(low) or not math.isfinite(high) or low >= high:
            raise ValueError('invalid declared ADC rails')
    configuration = record.get('configuration') or {}
    config_missing = _refs(configuration, ['rx_gain_db', 'configuration_ref', 'clock_alignment_ref'])
    gain = configuration.get('rx_gain_db')
    if gain is not None and (isinstance(gain, bool) or not isinstance(gain, (int, float)) or not math.isfinite(gain)):
        raise ValueError('rx_gain_db must be finite numeric or null')
    labels = record.get('observations') or {}
    definitions = {
        'receiver_saturation': ['raw_report_ref', 'vendor_semantics_ref', 'collection_interval_ref'],
        'target_loss': ['point_cloud_ref', 'independent_ground_truth_ref', 'target_association_ref', 'clock_alignment_ref'],
        'hardware_damage': ['pre_exposure_health_ref', 'post_exposure_health_ref', 'power_cycle_health_ref', 'assessment_ref'],
    }
    output = {}
    for name, references in definitions.items():
        block = labels.get(name) or {}
        value = _boolean(block.get('value'), f'{name}.value')
        collected = _boolean(block.get('collected'), f'{name}.collected')
        if value is not None and collected is not True:
            raise ValueError(f'{name}.value requires collected=true')
        gaps = _refs(block, references)
        if name == 'receiver_saturation':
            enabled = _boolean(block.get('monitor_enabled'), f'{name}.monitor_enabled')
            if enabled is not True:
                gaps.append('monitor_enabled must be true')
            gaps += ['representation.' + item for item in rep_missing]
            gaps += ['configuration.' + item for item in config_missing]
        elif name == 'hardware_damage' and value is True:
            gaps += _refs(block, ['persistent_change_ref'])
        gaps += ['identity.' + item for item in missing]
        if conflicts:
            status = 'PROVENANCE_CONFLICT'
        elif collected is not True:
            status = 'NOT_COLLECTED'
        elif value is None:
            status = 'VALUE_UNAVAILABLE'
        elif gaps:
            status = 'INCOMPLETE_REFERENCES'
        else:
            status = 'REFERENCED_OBSERVATION'
        output[name] = {'value': value, 'status': status,
                        'missing_requirements': sorted(set(gaps)),
                        'references': {key: block.get(key) for key in references},
                        'physical_validity_certified_by_checker': False}
    core_missing = missing + ['representation.' + x for x in rep_missing] + ['configuration.' + x for x in config_missing]
    return {'recording_id': record.get('recording_id'), 'source_sha256': source_hash,
            'checked_source_sha256': checked_hash, 'provenance_conflicts': conflicts,
            'missing_acquisition_fields': sorted(set(core_missing)), 'observations': output,
            'paired_evidence_record_complete': not conflicts and not core_missing and
                all(x['status'] == 'REFERENCED_OBSERVATION' for x in output.values()),
            'hardware_overload_or_damage_inferred_from_sample_extrema': False}


def assess_manifest(manifest, root=None):
    if manifest.get('schema_version') != '1.0':
        raise ValueError('unsupported paired-acquisition schema_version')
    records = manifest.get('recordings')
    if not isinstance(records, list) or not records:
        raise ValueError('recordings must be a nonempty list')
    identifiers = [x.get('recording_id') for x in records]
    if len(identifiers) != len(set(identifiers)):
        raise ValueError('duplicate recording_id')
    return {'schema_version': '1.0', 'checker_scope': 'completeness_and_source_consistency_not_physical_ground_truth',
            'recordings': [assess_recording(x, root) for x in records]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--root', type=Path, default=Path.cwd())
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report = assess_manifest(json.loads(args.manifest.read_text()), args.root)
    rendered = json.dumps(report, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + '\n')
    else:
        print(rendered)


if __name__ == '__main__':
    main()
