# PhantomRadar observation guard

An offline, standard-library Python 3.10+ component for normalized telemetry. It preserves unavailable evidence and reports VALID, DEGRADED, or UNKNOWN for the configured observation contract. It does not control a radar, infer a physical cause from point counts, or reconstruct missing target observations.

Install from the release root with `python -m pip install -e ./python_contract`. Run:

```sh
python -m phantomradar normalized_telemetry.csv --output output_guard --config python_contract/config/diagnostics.json
```

The input schema is `schema/input_contract.json`; `data/MEASUREMENT_SCHEMA_ONLY.csv` contains headers only. Missing nullable cells remain unknown, observed zero remains negative, and an observed required violation has priority over unavailable evidence. Capture/publication timestamps must already have a documented common clock. Source-kind declarations are not proof of physical acquisition.

Run `python -m unittest discover -s tests -v` from this subdirectory. The tests are software checks, not experimental receiver faults. The optional `phantomradar.acquisition` utility checks source identities and evidence references; it does not certify the truth of an acquisition claim. The replay-reference module is a semantic regression reference, not an empirical baseline result.

The parent `README.md` describes original recordings, optional MAT readers, the legacy checkpoints, and the single MATLAB plotting program. Python here does not generate publication plots.

## Real snapshot example

Install NumPy and SciPy, then run from the release root:

```sh
python -m phantomradar.regional examples/paired_snapshots --output output_regional --fixed-reference examples/paired_snapshots/pc_ti_kinect_key_89.mat
```

The paired-record CSV preserves source hashes and reports original point counts and reference-qualified regional support. It requires no assumed acquisition clock. The timestamps required by the telemetry guard must come from an actual timed acquisition.

The optional `reference_qualified` and `region_point_count` columns implement the regional predicate. A positive reference and zero region count yield a violation even when the whole cloud is nonempty. Missing or unqualified reference evidence remains UNKNOWN. `config/physical_sensing.json` requires regional support together with receiver-health evidence. Supply the predeclared region and independent reference in the source provenance.
