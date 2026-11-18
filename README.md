# PhantomRadar

## Recorded data for review

| Observation | Anonymous files |
|---|---|
| Paired device and IQ-derived point clouds with Kinect joints | [Paired numeric arrays](data/dual_point_clouds_and_joints.npz) and [record inventory](data/dual_point_clouds_manifest.json) |
| Native IQ, point clouds and reference joints from the timed recording | [Quick sample](data/bag_numeric_excerpt_v21.mat) and [complete numeric session in parts](data/native_parts/parts.json) |
| Vehicle display recordings | [Two cropped video excerpts](media/README.md) |

The links above index the data used in the analyses. The broader acquisition corpus is described separately in the manuscript.

## Reproduce the figures

Extract this repository and open its root in MATLAB R2024b or later. Run the single plotting entry point.

```matlab
PhantomRadar_figure_v22
```

For the exact Figure 9 SVG on MATLAB Online, run `PhantomRadar_figure_v22([],[],[],true)`. This path reads the measured coordinates and emits the vector independently of MATLAB’s interactive graphics driver. The paper uses a vector PDF conversion of this SVG.

The plotting order follows the paper. Figures 1–4 are editable artwork in the companion slide deck. Figure 5 uses the external reference capture listed below. Figure 6 uses the recorded regional example, followed by the empirical distance distribution in Figure 7, the coordinate-shift comparison in Figure 8 and the range plot in Figure 9. The output directory also contains one observation per record.

Figure 6 includes the published two-dimensional projection. The public run redraws the measured returns, reference skeleton, and display box separately as `figure06_numeric_layers`. An author with the original permitted `qwerty_records_v15.mat` can supply its path as the third argument to re-render the full three-dimensional background. The closed-form regional checks and range summaries use each stored radar point and reference joint.

## Reproduce the numerical results

Use Python 3.10 or newer from this directory. The paired-cloud inputs comprise two radar representations from the same source MAT and reference joints; the leg analysis uses six joints. Repeated source hashes identify shared records across collections.

```sh
python -m pip install -r requirements.txt
python tools/restore_capture.py
python data/measure_regional_ambiguity.py
python data/replay_dual_point_clouds.py
python data/standardize_cloud_density.py
python data/recording_iq_and_support.py
python tools/inspect_iq_excerpt.py
python tools/heldout_pose.py data results
python tools/limb_segments.py data results
python tools/paired_pose.py data results
python tools/equal_count.py data results
```

`data/environment_new_v19.mat` holds the entire numeric ROS session needed to reproduce the packet/cloud/reference comparisons. Its six arrays contain the recorded payloads, cloud coordinates, reference joints, and three integer time vectors on a common elapsed clock. The three-packet excerpt provides a smaller input for checking the IQ format. Camera images, raw video audio, point-cloud surfaces, account identifiers and absolute bag timestamps are excluded.

**Statistical unit.** Each regional outcome counts one saved point-cloud/reference pair. A paired source file can contain different native and offline point lists. Each point representation has its own count; IQ magnitude and phase summaries in the separate session aggregate all receivers and fast-time samples. The study preserves recording-block and condition provenance.

**Media.** See [dashboard clips](media/README.md) for durations and source intervals.

**Third-party source.** Figure 5 uses the recorded corner reference and interference D/A from the INRAS dataset by Lukas Rienessl and Reinhard Feger, DOI 10.5281/zenodo.21933926 (CC BY 4.0). `data/external_plot_examples.mat` contains numerical range–Doppler matrices and traces in the source’s native band. The [source attribution](external_examples/INRAS/ATTRIBUTION.json) provides the original citation. Regional, IQ-session, and dual-output data in this package are author-provided measurements.

**Licensing.** The code license is in [LICENSE](LICENSE). Author-owned released numerical examples are covered by [data/LICENSE.md](data/LICENSE.md). Publication artwork and demonstration video excerpts are included for research review. Each cited third-party asset retains its source terms.
