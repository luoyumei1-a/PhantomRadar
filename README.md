# PhantomRadar: code and recorded numerical examples

This release contains the observation guard, conditional RF link-budget models,
the single MATLAB publication-plotting program, and recorded numerical examples.
The guard reports which declared observations are satisfied, violated or
unavailable. Regional point counts describe recorded support under the stated
reference and ROI; they do not authenticate a physical target or identify an RF
cause by themselves.

## Quick start

Use Python 3.10 or later:

```sh
python -m pip install -r requirements.txt
python -m pip install -e ./python_contract
python tools/verify_public_data.py
python tools/inspect_iq_excerpt.py
python tools/analyze_regional_records.py
python -m phantomradar.regional examples/paired_snapshots --output output_regional --fixed-reference examples/paired_snapshots/pc_ti_kinect_key_89.mat
python -m unittest discover -s python_contract/tests -v
```

The three example MAT files retain the recorded radar and joint arrays for
records 89–91. With the fixed record 89 reference, they reproduce whole-cloud
counts 36/21/24, leg counts 12/0/12, and torso counts 6/10/12. Their public containers
omit the dense reference surface; an original-source hash records the source
identity without claiming byte identity for a privacy-minimized MAT container.

`data/author_owned_numeric_records_v21.npz` contains every recorded radar row and
all 32 reference joints from 221 primary and 32 secondary records. The accompanying
JSON identifies each array, collection and source block. No participant names,
RGB frames or dense reference surfaces are included. The secondary blocks use
the distinct prefixes B-000/B-001. NPZ arrays are loaded with `allow_pickle=False`.

`data/bag_numeric_excerpt_v21.mat` contains the first 3 unchanged raw-byte payloads
and all 108 radar clouds / 185 reference-joint arrays from the recorded ROS bag.
The absolute recording time is removed by exact integer subtraction; relative
timing and sample values are retained. Bag receipt times do not establish
hardware exposure synchronization. The complete source recording and matched
configuration remain necessary for a complete acquisition replay.

## Acquisition protocol and evidence

The authors identify the paired acquisition platform as IWR6843-ODS with 3TX/4RX,
nominal 60-GHz operation, 4000.14-MHz bandwidth and 30-dB RX gain. These are
author-confirmed protocol facts. The bandwidth gives approximately 3.75-cm
free-space range resolution through `c/(2B)`; it does not imply 0.75-cm resolution.
The source records do not encode a per-record reflector distance, exposure
switch, CQ enable flag, CQ payload or calibrated ADC full-scale voltage. Those
fields are not filled by inference from the protocol description.

Human-participant acquisition and this analysis follow the applicable approved
institutional protocol and informed-consent conditions confirmed by the authors.
This public numeric view omits RGB and dense surfaces. The code package treats
protocol statements and recorded fields as separate provenance entries.

## MATLAB figures

The current publication plotting entry point is `PhantomRadar_figure_v21.m`.
Open it in MATLAB Online. The analytical mode requires no external data:

```matlab
report = PhantomRadar_figure_v21('data','output_analytic','analytical','matlab_online');
```

The paper mode produces twelve plots in manuscript order using its complete
canonical inputs. These public numeric examples support the regional analysis;
they are not substituted silently for the full canonical inputs. Source-specific
external records and the complete plotting inputs are described by the source
notices and the publication artifact's input manifest. All reported experimental
arrays are recorded measurements. The analytical curves are exact model
evaluations without random perturbations.

## External data and rights

`external_examples/INRAS/` contains the retained IF excerpt by Lukas Rienessl and
Reinhard Feger, DOI 10.5281/zenodo.21933926, distributed under CC BY 4.0 with its
source notice. Its native configuration is 76–77 GHz; it is kept distinct from
the author's nominal 60-GHz acquisition and the 62-GHz analytical budget.

Other source records are retrieved from their original publishers under their
own terms:

* BGT60TR13C gesture data: <https://zenodo.org/records/15178095>, CC BY 4.0.
* M3D IWR6843AOP recordings: <https://zenodo.org/records/21802513>, CC BY 4.0.
* UW AWR1843 raw-ADC source: <https://github.com/Xiangyu-Gao/Raw_ADC_radar_dataset_for_automotive_object_detection>.
* CW breathing data: <https://radarmimo.com/download/contactless-radar-based-breathing-monitoring-raw-data/>.

An open download link or a software license does not create a separate raw-data
license. The public example release excludes raw UW/CW material whose distinct
redistribution license was not established. `DATA_NOTICE.md` separates author
data, source-licensed excerpts and software fixtures.

## Conditional physical models

The code distinguishes conducted power from EIRP, two-way passive propagation
from a direct source's one-way path, and amplifier gain from stable loop gain.
At 3 m with the stated 62-GHz/25-dBi-source/10-dBi-victim reference scenario, a 48-dB receiver
gain boundary corresponds to approximately 0.84 dBm conducted source power.
This is a conditional budget, not measured attack success. The antenna gains
and receiver input compression references remain explicit model assumptions.
The sensitivity CSV separately includes a 5-dBi ODS antenna case; the author
acquisition protocol uses 30-dB RX gain, so the 48-dB case is not its measured
operating point.

## License

The active Python software and new release utilities use the MIT license in
`LICENSE`; original notices are retained. Author-owned numerical examples use
CC BY 4.0 as stated in `data/LICENSE.md`. External examples retain their own
authors, citations and licenses. The license does not authorize identifying
participants or apply a software grant to third-party data.

The v21 full publication entry point was executed in MATLAB Online R2026b Update 2: 37/37 checks passed, with 8 exact canonical inputs and 12 ordered plots. `results/MATLAB_Online_Verification_v21.json` records its source hash and input identities. The privacy-minimized public view remains distinct from the complete canonical inputs.
