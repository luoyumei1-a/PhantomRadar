#!/usr/bin/env python3
"""Decode recorded 2I/2Q byte payloads and report descriptive IQ statistics."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from scipy.io import loadmat


def decode_2i2q(raw: np.ndarray, receivers: int = 4, fast_samples: int = 256):
    raw = np.asarray(raw, dtype=np.uint8).reshape(-1)
    words = np.frombuffer(raw.tobytes(), dtype='<i2')
    if words.size % (2 * receivers * fast_samples):
        raise ValueError('Payload length does not match the declared stored framing')
    groups = words.reshape(-1, 4).astype(np.float64)
    samples = np.empty(words.size // 2, dtype=np.complex128)
    samples[0::2] = groups[:, 0] + 1j * groups[:, 2]
    samples[1::2] = groups[:, 1] + 1j * groups[:, 3]
    cube = samples.reshape(-1, receivers, fast_samples).transpose(1, 2, 0)
    return words, cube


def inspect(path: Path) -> dict:
    data = loadmat(path, squeeze_me=True, struct_as_record=False)
    packets = np.asarray(data['raw_payloads'], dtype=object).reshape(-1)
    rows = []
    for i, payload in enumerate(packets):
        raw = np.asarray(payload, dtype=np.uint8).reshape(-1)
        words, cube = decode_2i2q(raw)
        cross = cube[:, 1:, :] * np.conj(cube[:, :-1, :])
        phase = np.angle(cross[np.abs(cross) > 0])
        power = np.mean(np.abs(np.fft.fft(cube * np.hanning(256)[None, :, None], axis=1)) ** 2, axis=(0, 2))
        safe_power = np.maximum(power, np.finfo(float).tiny)
        rows.append({'excerpt_packet': i + 1,
                     'raw_sha256': hashlib.sha256(raw.tobytes()).hexdigest(),
                     'raw_bytes': raw.size, 'complex_shape_rx_sample_chirp': list(cube.shape),
                     'signed_word_min': int(words.min()), 'signed_word_max': int(words.max()),
                     'signed_container_endpoints': int(np.sum((words == -32768) | (words == 32767))),
                     'signed_word_rms': float(np.sqrt(np.mean(words.astype(float) ** 2))),
                     'complex_amplitude_p99': float(np.percentile(np.abs(cube), 99)),
                     'fast_sample_phase_coherence': float(abs(np.mean(np.exp(1j * phase)))),
                     'range_spectral_flatness': float(np.exp(np.mean(np.log(safe_power))) / np.mean(safe_power))})
    return {'clock': 'relative ROS bag receipt time',
            'quantity_scope': 'Descriptive stored-code statistics; integer endpoints are not calibrated ADC rails.',
            'framing_scope': '4 receivers and256 stored fast-time samples; no TX scheduling is inferred.',
            'raw_packet_count': len(rows), 'radar_cloud_count': len(data['radar_points']),
            'reference_joint_array_count': len(data['body_joints']), 'packets': rows}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mat', nargs='?', type=Path,
                        default=Path(__file__).resolve().parents[1] / 'data/bag_numeric_excerpt_v21.mat')
    args = parser.parse_args()
    print(json.dumps(inspect(args.mat), indent=2))


if __name__ == '__main__':
    main()
