function report = PhantomRadar_figure_v21(dataDir,outDir,mode,executionContext)
%PHANTOMRADAR_FIGURE_V21 Publication plots from original recorded sensor arrays.
% report = PhantomRadar_figure_v21('data','output','paper','matlab_online');
% Analytical figures only: use mode 'analytical'; the paper mode includes both.
% Catalog-parameter link budgets are distinct from the recorded-array figures.
% Quick geometry preview: use mode 'qwerty'. No external M-files are required.
% Native ROS1 recording reanalysis only: use mode 'bag' with the eighth MAT.
% Recorded regional count models only: use mode 'statistics'.
% The paper_plot_order.csv manifest lists exports in manuscript order.
% Regional phantom incidence is a record-level reference/return disagreement.
% Source blocks retain their archive labels; no RF trial condition is inferred.
% v21: linear-distance analytic display, complete direct-source budgets, and
% five-extent original-block incidence bars; recorded observations unchanged.
root=fileparts(mfilename('fullpath'));
if nargin<1||isempty(dataDir),dataDir=fullfile(root,'data');end
if nargin<2||isempty(outDir),outDir=fullfile(root,'output');end
if nargin<3||isempty(mode),mode='paper';end
if nargin<4||isempty(executionContext),executionContext='matlab';end
mode=char(mode);executionContext=char(executionContext);
assert(any(strcmp(mode,{'paper','qwerty','analytical','bag','statistics'})),'Mode must be paper, qwerty, analytical, bag or statistics.');
assert(~exist('OCTAVE_VERSION','builtin'),'This publication entry point requires MATLAB.');
assert(any(strcmp(executionContext,{'matlab','matlab_online'})));
if ~exist(outDir,'dir'),mkdir(outDir);end
resultDir=fullfile(outDir,'results');figDir=fullfile(outDir,'figures');
if ~exist(resultDir,'dir'),mkdir(resultDir);end
if ~exist(figDir,'dir'),mkdir(figDir);end
oldVisibility=get(groot,'DefaultFigureVisible');set(groot,'DefaultFigureVisible','off');
restoreVisibility=onCleanup(@()set(groot,'DefaultFigureVisible',oldVisibility)); %#ok<NASGU>
setappdata(0,'mmaudit_refine_only',false);
report=struct('artifact_version','PhantomRadar_v21','execution_environment',['MATLAB ' version],...
 'execution_context',executionContext,'matlab_online_executed',strcmp(executionContext,'matlab_online'),...
 'mode',mode,'runtime_host_local_time',datestr(now,31),...
 'executed_source_sha256',fileSHA256([mfilename('fullpath') '.m']));
if strcmp(mode,'statistics')
 [N,tests]=record_count_models_v21(dataDir,resultDir);
 report.regional_count_models=N;report.meaningful_tests=tests;report.figure_order={};
 writeJSON(fullfile(outDir,'meaningful_tests_v21.json'),tests);
 writeJSON(fullfile(outDir,'execution_manifest_v21.json'),report);return;
end
if strcmp(mode,'bag')
 [B,tests]=bag_record_association_v21(fullfile(dataDir,'environment_new_v19.mat'),resultDir);
 report.native_bag_study=B;report.meaningful_tests=tests;report.figure_order={};
 writeJSON(fullfile(outDir,'meaningful_tests_v21.json'),tests);
 writeJSON(fullfile(outDir,'execution_manifest_v21.json'),report);return;
end
if strcmp(mode,'analytical')
 [F,tests]=analytical_feasibility_v21(figDir,resultDir,outDir);
 report.analytical_feasibility=F;report.meaningful_tests=tests;
 report.figure_order={'figure_feasibility_passive_v21';'figure_feasibility_active_v21'};
 report.native_export_audit=native_figure_audit_v15(figDir,resultDir);
 writeJSON(fullfile(outDir,'meaningful_tests_v21.json'),tests);
 writeJSON(fullfile(outDir,'execution_manifest_v21.json'),report);return;
end
if strcmp(mode,'qwerty')
 Q=mmSilent_fig6_qwerty_v15(fullfile(dataDir,'qwerty_records_v15.mat'),figDir,resultDir);
 report.regional_study=rmfield(Q,{'fixed_region_checks','adjacent_pairs'});
 report.native_export_audit=native_figure_audit_v15(figDir,resultDir);
 writeJSON(fullfile(outDir,'execution_manifest_v21.json'),report);
 fprintf('PHANTOMRADAR_V21_QWERTY_DONE\n');return;
end
inputs={'coherent_adc_v12.mat','qwerty_records_v15.mat','paired_radar_kinect_records_v12.mat',...
 'supplemental_recordings_v11.mat','adc_inputs.mat','cw_traces_v11.mat','iq_paired_records_v17.mat'};
report.input_hashes=struct('filename',{},'sha256',{},'bytes',{});
for k=1:numel(inputs)
 p=fullfile(dataDir,inputs{k});a=dir(p);assert(~isempty(a)&&a.bytes>1000,'Missing recorded input: %s',inputs{k});
 report.input_hashes(k)=struct('filename',inputs{k},'sha256',fileSHA256(p),'bytes',a.bytes);
end
% I. Preliminary feasibility: common processing and three-view reference.
tests=cfar_kernel_tests_v12();
A=coherent_interference_study_v12(dataDir,figDir,resultDir,true);
[peakAudit,peakTests]=coherent_peak_background_audit_v21(A,resultDir);
report.coherent_peak_background_decomposition=peakAudit;tests=[tests peakTests];
Q=mmSilent_fig6_qwerty_v15(fullfile(dataDir,'qwerty_records_v15.mat'),figDir,resultDir);
report.regional_study=rmfield(Q,{'fixed_region_checks','adjacent_pairs'});
I=iq_paired_spatial_v17(fullfile(dataDir,'iq_paired_records_v17.mat'),resultDir);
report.secondary_paired_spatial_study=I;
[N,countTests]=record_count_models_v21(dataDir,resultDir);report.regional_count_models=N;tests=[tests countTests];
[F,analyticalTests]=analytical_feasibility_v21(figDir,resultDir,outDir);
report.analytical_feasibility=F;tests=[tests analyticalTests];
% II. Evaluation: independent platform views, regional distance, CFAR response.
P=public_adc_measurement_study(dataDir,figDir);assert(~isempty(P));
writeNumeric(fullfile(resultDir,'platform_traces_v16.csv'),P.trace_names,P.traces);
writeNumeric(fullfile(resultDir,'platform_map_cells_v16.csv'),P.map_names,P.maps);
coherent_response_plot_v12(A,figDir);
old=load(fullfile(dataDir,'adc_inputs.mat'),'adc_records');B=figure10_adc_response(old,figDir,true,true);
B=retained_spectral_figure_v12(B,figDir,A.calibration);
writeNumeric(fullfile(resultDir,'retained_IF_spectral_profiles_v16.csv'),B.profile_names,B.profiles);
writeNumeric(fullfile(resultDir,'retained_IF_peak_summary_v16.csv'),B.peak_names,B.peaks);
report.spectral_estimands_audit=iq_spectral_audit_v15(dataDir,resultDir);
% III. Appendix: reference-conditioned phantom incidence and CW endpoints.
C=cw_endpoint_study(dataDir,figDir);assert(~isempty(C));
writeNumeric(fullfile(resultDir,'CW_endpoint_metrics_v16.csv'),C.metric_names,C.metrics);
% Supplemental original-array checks do not change the paper estimands.
S=paired_roi_study_v12(dataDir,figDir,resultDir,false);
tests(end+1)=struct('name','all221_original_radar_rows_retained','passed',Q.inventory.total_radar_points==6971);
tests(end+1)=struct('name','reference_conditioned_phantom52_of221','passed',Q.regional.base_unsupported==52);
tests(end+1)=struct('name','torso_and_whole_cloud_baselines_zero_of221','passed',all(Q.regional.baseline_zero_counts(2:3)==0));
tests(end+1)=struct('name','all15_original_block_extent_counts_match_independent_array_audit', ...
 'passed',isequal(Q.regional.leg_zero_by_scale_then_block,[70 78 17;46 56 9;23 25 4;9 7 2;4 0 0]));
tests(end+1)=struct('name','coherent_reference_calibration_held_out','passed',all(A.summary(:,4)==90|A.summary(:,4)==100));
tests(end+1)=struct('name','secondary32_original_radar_rows_retained','passed',I.n_stored_records==32&&I.total_radar_rows==1432);
tests(end+1)=struct('name','secondary32_regional_baseline_counts','passed',isequal(I.pooled_zero_counts,[2 1 0]));
tests(end+1)=struct('name','secondary32_mapping_matches_independent_array_audit','passed',isequal(I.leg_zero_by_scale,[24 11 2 0 0])&&abs(I.joint_NN_median_m-.21776643129701415)<1e-12);
bagPath=fullfile(dataDir,'environment_new_v19.mat');
if exist(bagPath,'file')==2
 [report.native_bag_study,bagTests]=bag_record_association_v21(bagPath,resultDir);
 tests=[tests bagTests];
 a=dir(bagPath);report.input_hashes(end+1)=struct('filename','environment_new_v19.mat','sha256',fileSHA256(bagPath),'bytes',a.bytes);
end
assert(all([tests.passed]),'Recorded-data validation failed.');
report.meaningful_tests=tests;report.interference_protocol=A.protocol;report.supplemental_roi_protocol=S.protocol;
report.transmit_power_budget=struct('linear_fraction_of_nominal',.9,'IWR6843_nominal_dBm',12,...
 'linear_budget_mW',.9*10^(12/10),'budget_dBm',12+10*log10(.9),...
 'scope','Analytical conducted-power budget; nominal device value and board antenna gain are separate inputs.');
map={...
 'figure26_recorded_interference_rd_v12','figure05_feasibility_interference','Feasibility experiment 1';...
 'fig6_raw_090_v17','figure06_tracking','Feasibility experiment 2: all original returns and front-layer leg display boxes';...
 'figure_feasibility_passive_v21','figure_feasibility_passive_v21','Analytical passive-geometry and receiver-gain envelopes';...
 'figure_feasibility_active_v21','figure_feasibility_active_v21','Analytical catalog-component and stability feasibility envelope';...
 'figure22_recorded_adc_maps','figure_crossplatform','Independent FMCW representation views';...
 'figure25b_qwerty_leg_distance_cdf_v15','figure_region_distance','Reference-joint nearest-return distance';...
 'figure27a_cfar_contrast_v14','figure_cfar_contrast','Corner-to-background contrast';...
 'figure27b_cfar_offlobe_v14','figure_cfar_offlobe','Off-lobe CA-CFAR maxima';...
 'figure16_adc_spectral_profile','figure_adc_spectral','Native IF spectral profiles';...
 'figure_regional_translation','figure_regional_translation','Coordinate registration sensitivity';...
 'figure_regional_incidence','figure_regional_incidence','Reference-qualified record-level regional incidence';...
 'figure23_cw_endpoint_validation','figure_cw_endpoints','External CW recorded endpoint occupancy'};
for k=1:size(map,1)
 for ext={'pdf','svg','fig'}
  src=fullfile(figDir,[map{k,1} '.' ext{1}]);dst=fullfile(figDir,[map{k,2} '.' ext{1}]);
  assert(exist(src,'file')==2,'Missing paper figure: %s',src);
  if ~strcmp(src,dst),copyfile(src,dst,'f');end
 end
end
report.figure_order=map(:,2);report.figure_roles=map(:,3);
writeMappings(fullfile(outDir,'paper_plot_order.csv'),{'native_export','paper_export','role'},map);
report.native_export_audit=native_figure_audit_v15(figDir,resultDir);
writeJSON(fullfile(outDir,'meaningful_tests_v21.json'),tests);
writeJSON(fullfile(outDir,'execution_manifest_v21.json'),report);
fprintf('PHANTOMRADAR_V21_PAPER_DONE: %d checks, %d recorded inputs, %d ordered plots.\n',numel(tests),numel(report.input_hashes),size(map,1));
end



function [detections,threshold,valid,local]=ca_cfar_2d_v12(power,guard,training,pfa)
% Base-MATLAB cell-averaging CFAR, square-law input, interior CUTs only.
% MathWorks primary reference: constant-false-alarm-rate-cfar-detection.html
% Its nominal Pfa factor assumes independent exponential noise; interference
% and correlated FFT cells need not satisfy that false-alarm calibration.
assert(isreal(power)&&all(isfinite(power(:)))&&all(power(:)>=0)&&pfa>0&&pfa<1);
guard=double(guard(:)');training=double(training(:)');outer=guard+training;
nTrain=prod(2*outer+1)-prod(2*guard+1);assert(nTrain>0&&all(size(power)>2*outer));
outerSum=conv2(ones(2*outer(1)+1,1),ones(1,2*outer(2)+1),power,'valid');
innerSum=conv2(ones(2*guard(1)+1,1),ones(1,2*guard(2)+1),power,'valid');
innerSum=innerSum(1+training(1):end-training(1),1+training(2):end-training(2));
noise=max((outerSum-innerSum)/nTrain,0);factor=nTrain*(pfa^(-1/nTrain)-1);
rr=(1+outer(1)):(size(power,1)-outer(1));cc=(1+outer(2)):(size(power,2)-outer(2));
threshold=nan(size(power));threshold(rr,cc)=factor*noise;valid=false(size(power));valid(rr,cc)=true;
local=power>=circshift(power,[1 0])&power>=circshift(power,[-1 0])&power>=circshift(power,[0 1])&power>=circshift(power,[0 -1])&power>=circshift(power,[1 1])&power>=circshift(power,[1 -1])&power>=circshift(power,[-1 1])&power>=circshift(power,[-1 -1]);
detections=valid&power>threshold&local;
end


function [clean,mask]=robust_blanking_v12(raw,kappa)
% Fixed predeclared per-chirp robust amplitude blanking; no attack-label fit.
% Replace detected samples by that chirp's median, then use identical FFT/CFAR.
assert(isreal(raw)&&all(isfinite(raw(:)))&&kappa>0,'Expected real recorded IF samples.');
center=median(raw,1);mad=median(abs(raw-center),1);sigma=1.4826*mad;
floorScale=eps(max(1,max(abs(raw),[],1)));sigma=max(sigma,floorScale);
mask=abs(raw-center)>kappa*sigma;clean=raw;replacement=repmat(center,size(raw,1),1);clean(mask)=replacement(mask);
end


function power=recorded_rd_power_v12(raw)
% Full coherent fast/slow 2D FFT of the actual recorded real-valued IF matrix.
% Same deterministic preprocessing/window/FFT for unmodified and blanked data.
N=size(raw,1);K=size(raw,2);fast=.5-.5*cos(2*pi*(0:N-1)'/(N-1));slow=.5-.5*cos(2*pi*(0:K-1)/(K-1));
x=filter([1 -1],1,double(raw),[],1);x=x-mean(x,1);
F=fft(x.*fast.*slow,[],1);F=fftshift(fft(F,[],2),2);power=abs(F(1:floor(N/2),:)).^2;
end


function tests=cfar_kernel_tests_v12()
P=ones(32,24);P(16,12)=1000;[D,T,V]=ca_cfar_2d_v12(P,[1 1],[4 3],1e-3);assert(D(16,12)&&sum(D(:))==1&&sum(V(:))==22*16);
[D2,T2,V2]=ca_cfar_2d_v12(7*P,[1 1],[4 3],1e-3);assert(isequal(D,D2)&&isequal(V,V2)&&max(abs(T2(V)-7*T(V)))<1e-10);
assert(all(isnan(T(~V))),'CFAR edges cannot be represented as tested negative cells.');
x=repmat((-10:9)',1,8);[y,m]=robust_blanking_v12(x,6);assert(isequal(x,y)&&~any(m(:)));x(5,3)=1e6;[y,m]=robust_blanking_v12(x,6);assert(m(5,3)&&y(5,3)==median(x(:,3)));
names={'cfar_guard_exclusion_and_single_peak','cfar_power_scaling_equivariance','cfar_untested_edges_remain_unavailable','robust_blanking_preserves_inliers_and_replaces_extreme'};tests=struct('name',names,'passed',num2cell(true(size(names))));
end



function S=coherent_interference_study_v12(dataDir,figDir,resultDir,deferResponse)
% Physical recorded interference conditions, not receiver-overload labels.
% Reference-lobe support is a source-matched sensing descriptor, not target
% recall or false-alarm ground truth. No ADC rail or health flag is inferred.
L=load(fullfile(dataDir,'coherent_adc_v12.mat'));R=L.adc_records;if ~iscell(R),R=num2cell(R);end
ids=unique(cellfun(@(a)char(a.source_id),R,'UniformOutput',false),'stable');nodes=unique(cellfun(@(a)char(a.node),R,'UniformOutput',false),'stable');
refID=find(contains(ids,'ref_corner'));absentID=find(strcmp(ids,'meas_0_ref'));assert(isscalar(refID)&&isscalar(absentID),'Corner-present and corner-absent controls required.');
S.ids=ids;S.nodes=nodes;
N=512;K=128;F=100;guard=[1 1];training=[4 3];pfa=1e-3;kappa=6;nCalibration=10;
S.calibration=zeros(numel(nodes),13);cal=cell(numel(nodes),1);S.source_map=cell(numel(R),6);
assert(numel(R)==12&&numel(ids)==6&&numel(nodes)==2,'Expected six conditions and two actual stations.');
for j=1:numel(R)
 a=R{j};assert(isequal(size(a.raw_data),[N K F])&&isreal(a.raw_data)&&all(isfinite(a.raw_data(:))),'Require full recorded512x128x100realIF matrix.');
 assert(a.sample_rate_hz==20e6&&a.slope_hz_s==39.0625e12&&a.pri_s==34e-6&&a.carrier_frequency_hz==76.5e9&&a.single_tx_enabled==1,'Source configuration changed.');
 S.source_map(j,:)={j,char(a.source_id),char(a.node),char(a.source_sha256),numel(a.raw_data),'Full128coherent chirps,RX1,100recordedframes'};
end
for ni=1:numel(nodes)
 ip=find(cellfun(@(a)strcmp(char(a.source_id),ids{refID})&&strcmp(char(a.node),nodes{ni}),R));in=find(cellfun(@(a)strcmp(char(a.source_id),ids{absentID})&&strcmp(char(a.node),nodes{ni}),R));assert(isscalar(ip)&&isscalar(in));a=R{ip};n=R{in};meanPresent=zeros(N/2,K);meanAbsent=meanPresent;backgrounds=zeros(nCalibration,1);
 for f=1:nCalibration,meanPresent=meanPresent+recorded_rd_power_v12(a.raw_data(:,:,f))/nCalibration;meanAbsent=meanAbsent+recorded_rd_power_v12(n.raw_data(:,:,f))/nCalibration;end
 [~,~,valid]=ca_cfar_2d_v12(meanPresent,guard,training,pfa);contrast=max(meanPresent-meanAbsent,0);contrast(~valid)=-Inf;[maxContrast,maxIdx]=max(contrast(:));assert(maxContrast>0,'No positive physical-insertion contrast found.');[rr,dd]=ind2sub(size(contrast),maxIdx);
 roi=false(N/2,K);roi(max(1,rr-1):min(N/2,rr+1),max(1,dd-1):min(K,dd+1))=true;outside=valid&~roi;
 for f=1:nCalibration,P=recorded_rd_power_v12(a.raw_data(:,:,f));backgrounds(f)=median(P(outside));end
 cal{ni}=struct('reference_roi',roi,'valid',valid,'outside',outside,'range_index',rr,'doppler_index',dd,'reference_peak',meanPresent(rr,dd),'reference_background',median(backgrounds));
 S.calibration(ni,:)=[ni refID absentID nCalibration rr-1 dd-1-K/2 meanPresent(rr,dd) meanAbsent(rr,dd) maxContrast median(backgrounds) pfa kappa sum(valid(:))];
end
S.calibration_names={'node_id','corner_present_condition_id','corner_absent_condition_id','n_training_frames_per_control','corner_fast_fft_bin','corner_centered_doppler_bin','present_training_peak_power','absent_training_peak_power','positive_insertion_contrast_power','present_training_background_median','nominal_Cfar_pfa','blanking_kappa','n_valid_CUTs'};
S.frame_names={'condition_id','node_id','recorded_frame_index','method_id','evaluation_frame','blanked_sample_fraction','n_Cfar_local_maxima','n_outside_reference_lobe_maxima','n_valid_CUTs','n_reference_lobe_Cfar_maxima','reference_lobe_Cfar_support','reference_lobe_peak_power','outside_lobe_median_power','reference_lobe_peak_background_db','background_to_training_reference_db','normalized_spectral_entropy','source_corner_present','corner_region_Cfar_score'};
S.frames=zeros(numel(R)*F*2,18);row=0;displayIDs=[refID find(strcmp(ids,'meas_6_int_D')) find(strcmp(ids,'meas_2_int_A'))];assert(numel(displayIDs)==3,'Reference/A/D source conditions required.');
S.example_maps=cell(3,1);S.example_trace=cell(3,1);S.example_detection=cell(3,1);S.example_metadata=zeros(3,7);
for j=1:numel(R)
 a=R{j};ci=find(strcmp(ids,char(a.source_id)));ni=find(strcmp(nodes,char(a.node)));C=cal{ni};
 for f=1:F
  raw=double(a.raw_data(:,:,f));[blank,mask]=robust_blanking_v12(raw,kappa);
  for method=1:2
   if method==1,x=raw;fraction=0;else,x=blank;fraction=mean(mask(:));end
   P=recorded_rd_power_v12(x);[D,T,valid,local]=ca_cfar_2d_v12(P,guard,training,pfa);candidates=C.reference_roi&valid&local;if any(candidates(:)),score=max(P(candidates)./max(T(candidates),realmin));else,score=0;end;peak=max(P(C.reference_roi));floor=median(P(C.outside));q=P(:)/sum(P(:));entropy=-sum(q.*log(max(q,realmin)))/log(numel(q));
   evalFrame=~((ci==refID||ci==absentID)&&f<=nCalibration);row=row+1;
   S.frames(row,:)=[ci ni double(a.frame_indices(f)) method evalFrame fraction sum(D(:)) sum(D(C.outside)) sum(valid(:)) sum(D(C.reference_roi)) any(D(C.reference_roi)) peak floor 10*log10(max(peak,realmin)/max(floor,realmin)) 10*log10(max(floor,realmin)/max(C.reference_background,realmin)) entropy double(ci~=absentID) score];
   e=find(displayIDs==ci);
   displayFrame=1;if ci==refID,displayFrame=nCalibration+1;end;
   if ni==1&&f==displayFrame&&method==1&&~isempty(e),S.example_maps{e}=P;S.example_trace{e}=raw(:,1);S.example_detection{e}=D;S.example_metadata(e,:)=[e ci ni f sum(D(:)) sum(D(C.reference_roi)) any(D(C.reference_roi))];end
  end
 end
 fprintf('V12_RECORDED_INTERFERENCE: %s / %s, %d actual frames processed.\n',char(a.source_id),char(a.node),F);
end
writeNumeric(fullfile(resultDir,'coherent_interference_frame_metrics_v12.csv'),S.frame_names,S.frames);
writeNumeric(fullfile(resultDir,'coherent_interference_calibration_v12.csv'),S.calibration_names,S.calibration);
writeMappings(fullfile(resultDir,'coherent_interference_source_map_v12.csv'),{'capture_id','source_id','node','source_sha256','n_actual_samples','selection'},S.source_map);
writeMappings(fullfile(resultDir,'coherent_interference_condition_map_v12.csv'),{'condition_id','source_id','source_corner_present'},[num2cell((1:numel(ids))') ids(:) num2cell(double((1:numel(ids))'~=absentID))]);
S.summary_names={'condition_id','node_id','method_id','n_evaluation_frames','corner_region_detection_percent','median_peak_background_db','p25_peak_background_db','p75_peak_background_db','median_background_inflation_db','p25_background_inflation_db','p75_background_inflation_db','median_outside_lobe_maxima','p25_outside_lobe_maxima','p75_outside_lobe_maxima','median_blanked_sample_percent'};
S.summary=zeros(numel(ids)*numel(nodes)*2,15);row=0;
for ci=1:numel(ids),for ni=1:numel(nodes),for method=1:2
 z=S.frames(S.frames(:,1)==ci&S.frames(:,2)==ni&S.frames(:,4)==method&S.frames(:,5)==1,:);a=plot_style('quantile',z(:,14),[.25 .5 .75]);b=plot_style('quantile',z(:,15),[.25 .5 .75]);c=plot_style('quantile',z(:,8),[.25 .5 .75]);row=row+1;
 S.summary(row,:)=[ci ni method size(z,1) 100*mean(z(:,11)) a(2) a(1) a(3) b(2) b(1) b(3) c(2) c(1) c(3) 100*median(z(:,6))];
end;end;end
writeNumeric(fullfile(resultDir,'coherent_interference_method_summary_v12.csv'),S.summary_names,S.summary);
S.roc=zeros(0,6);S.detection=zeros(0,8);
for ni=1:numel(nodes),for method=1:2
 neg=S.frames(S.frames(:,1)==absentID&S.frames(:,2)==ni&S.frames(:,4)==method&S.frames(:,5)==1,18);
 for ci=setdiff(1:numel(ids),absentID)
  pos=S.frames(S.frames(:,1)==ci&S.frames(:,2)==ni&S.frames(:,4)==method&S.frames(:,5)==1,18);[curve,auc]=empirical_corner_roc_v12(pos,neg);
  S.roc=[S.roc;repmat([ci ni method],size(curve,1),1) curve];S.detection(end+1,:)=[ci ni method numel(pos) numel(neg) 100*mean(pos>1) 100*mean(neg>1) auc]; %#ok<AGROW>
 end
end;end
writeNumeric(fullfile(resultDir,'coherent_corner_presence_roc_v12.csv'),{'positive_condition_id','node_id','method_id','score_threshold','false_positive_fraction_absent_control','true_positive_fraction_present_condition'},S.roc);
writeNumeric(fullfile(resultDir,'coherent_corner_presence_detection_v12.csv'),{'positive_condition_id','node_id','method_id','n_present_evaluation_frames','n_absent_evaluation_frames','present_detection_percent_score_gt1','absent_false_positive_percent_score_gt1','AUROC_corner_presence_score'},S.detection);

% Three fixed first-frame examples; never chosen to force sparse/empty states.
[fig,old,colors]=plot_style('new',18.1864,7.8);delete(old);traceRows=zeros(0,4);mapRows=zeros(0,5);labels={'Corner reference','Interference D','Interference A'};
traceLimit=1.12*max(cellfun(@(x)max(abs(x)),S.example_trace));
velocity=(-K/2:K/2-1)/(2*K*34e-6)*3e8/76.5e9;range=(0:N/2-1)'*20e6/N*3e8/(2*39.0625e12);denom=cal{1}.reference_peak;
for e=1:3
 P=S.example_maps{e};trace=S.example_trace{e};db=10*log10(max(P,realmin)/max(denom,realmin));traceRows=[traceRows;repmat(e,N,1) (0:N-1)' (0:N-1)'/20e6 trace];[xx,yy]=meshgrid(velocity,range);mapRows=[mapRows;repmat(e,numel(P),1) xx(:) yy(:) P(:) db(:)]; %#ok<AGROW>
 pos=[.055+(e-1)*.325 .73 .25 .18];ax=axes('Parent',fig,'Position',pos);hold(ax,'on');setappdata(ax,'mmaudit_plot_position',pos);plot(ax,(0:N-1)/20,trace,'Color',colors(1,:),'LineWidth',.7);xlabel(ax,'Fast time (us)');ylabel(ax,'Recorded IF value');ylim(ax,[-traceLimit traceLimit]);title(ax,labels{e});
 pos=[.055+(e-1)*.325 .16 .25 .34];ax=axes('Parent',fig,'Position',pos);hold(ax,'on');setappdata(ax,'mmaudit_plot_position',pos);imagesc(ax,velocity,range,db);set(ax,'YDir','normal');clim(ax,[-60 15]);mapColors=[30 70 110;55 103 149;114 188 213;255 230 183;255 208 111;231 98 84]/255;colormap(ax,interp1(linspace(0,1,6),mapColors,linspace(0,1,64)));
 [ri,di]=find(S.example_detection{e});plot(ax,velocity(di),range(ri),'ko','MarkerSize',2,'LineWidth',.5);xlabel(ax,'Configured velocity (m/s)');ylabel(ax,'Beat-range equivalent (m)');xlim(ax,[velocity(1) velocity(end)]);ylim(ax,[range(1) range(end)]);title(ax,sprintf('Maxima (lobe / all): %d / %d',S.example_metadata(e,6),numel(ri)));
 if e==3,cb=colorbar(ax,'Position',[.946 .16 .012 .34]);set(cb,'Ticks',[-60 -30 0 15],'FontName','Times New Roman','FontSize',9);title(cb,'dB');end
end
writeNumeric(fullfile(resultDir,'coherent_interference_example_trace_v12.csv'),{'example_id','sample_index','fast_time_s','recorded_value'},traceRows);
writeNumeric(fullfile(resultDir,'coherent_interference_example_maps_v12.csv'),{'example_id','configured_velocity_mps','beat_range_equivalent_m','actual_FFT_power','power_relative_training_peak_db'},mapRows);
writeNumeric(fullfile(resultDir,'coherent_interference_example_selection_v12.csv'),{'example_id','condition_id','node_id','frame_index','n_Cfar_local_maxima','n_reference_lobe_Cfar_maxima','reference_lobe_Cfar_support'},S.example_metadata);
pad_native_canvas_v12(fig,4,0);
plot_style('finish',fig,figDir,'figure26_recorded_interference_rd_v12');
if nargin<4||~deferResponse,coherent_response_plot_v12(S,figDir);end
S.protocol=struct('source_conditions','Physical captured reference/interference exposures; no receiver-health label assigned','configuration',struct('fs_hz',20e6,'slope_hz_s',39.0625e12,'carrier_hz',76.5e9,'single_TX_PRI_s',34e-6),'processing','RX1,full128coherent chirps,realIF,firstdifferenceHPF,chirpmeanremoval,Hannfast/slow,positivefastFFThalf,centeredslowFFT','Cfar_guard',guard,'Cfar_training',training,'Cfar_nominal_pfa',pfa,'Cfar_scope','Local-max CA-CFAR; exponential-independent noise assumption does not assert calibrated false-alarm rate under interference','blanking','Per-chirp median and1.4826MAD,kappa6fixed; replace outliers by original chirp median','reference_lobe','Maximum positive(mean10corner-present minus mean10corner-absent)power contrast perstation within validCUTs; fixed3x3ROI; first10framesofbothcontrols excluded from all evaluation','physical_object_control','Source documentation states corner introduced in reference1 and retained in A/B/C/D; absent in reference0; no receiver-health labels inferred','evaluation_scope','Perconditioncorner detection uses independent source object-presence annotation; negativecontrol only without interference, so no universal/interfered-absent FPR claim','unobserved_health','No inferred ADC full-scale, compression, receiver-overload or hardware-damage labels','off_lobe_count','All detections outside selected reference lobe, not ground-truth false positives','examples','Station1,firstheldoutcornerreferenceframe11,interferenceDframe1,interferenceAframe1; source-condition order fixed, no frame selected on lobe outcome');
writeJSON(fullfile(resultDir,'coherent_interference_protocol_v12.json'),S.protocol);
end



function coherent_response_plot_v12(S,figDir)
% Two independent figures; all summaries use the same recorded evaluation frames.
ids=S.ids;refID=find(contains(ids,'ref_corner'));absentID=find(strcmp(ids,'meas_0_ref'));assert(isscalar(refID)&&isscalar(absentID),'Missing condition IDs for response labels.');
outputs={'figure27a_cfar_contrast_v14','figure27b_cfar_offlobe_v14'};
for panel=1:2
 [fig,ax,colors]=plot_style('new',8.9,6.2);pos=[.18 .21 .79 .75];set(ax,'Position',pos);setappdata(ax,'mmaudit_plot_position',pos);values=zeros(numel(ids),4);lo=values;hi=values;
 for ni=1:2,for method=1:2,series=(ni-1)*2+method;for ci=1:numel(ids),z=S.summary(S.summary(:,1)==ci&S.summary(:,2)==ni&S.summary(:,3)==method,:);assert(size(z,1)==1);if panel==1,col=6;else,col=12;end;values(ci,series)=z(col);lo(ci,series)=z(col+1);hi(ci,series)=z(col+2);end;end;end
 b=bar(ax,1:numel(ids),values,'grouped','BarWidth',.86);for series=1:4,set(b(series),'FaceColor',colors(series,:),'EdgeColor',[.2 .2 .2],'LineWidth',.55);end;drawnow;
 for series=1:4,xp=b(series).XEndPoints;errorbar(ax,xp,values(:,series),values(:,series)-lo(:,series),hi(:,series)-values(:,series),'k','LineStyle','none','CapSize',2,'LineWidth',.65,'HandleVisibility','off');end
 conditionLabels=shortLabels(ids);conditionLabels{absentID}='Absent';conditionLabels{refID}='Corner';set(ax,'XTick',1:numel(ids),'XTickLabel',conditionLabels,'XGrid','off','YGrid','on');xlabel(ax,'Recorded condition');xlim(ax,[.5 numel(ids)+.5]);
 ymin=min(0,min(lo(:)));ymax=max(hi(:));span=max(1,ymax-ymin);ylim(ax,[ymin ymax+.43*span]);
 if panel==1,ylabel(ax,'Corner contrast (dB)');else,ylabel(ax,'Off-lobe CA-CFAR maxima (n)');end
 lg=legend(ax,b,{'S1 original','S1 blanked','S2 original','S2 blanked'},'Location','northwest','NumColumns',2,'FontSize',9,'Box','off');set(lg,'AutoUpdate','off','ItemTokenSize',[9 7]);
 plot_style('finish',fig,figDir,outputs{panel});
end
end



function [oldWidthPt,oldHeightPt]=pad_native_canvas_v12(fig,leftPt,topPt)
% Add white paper margin without shrinking any plotted data area or font.
set(fig,'PaperUnits','centimeters');old=get(fig,'PaperSize');oldWidthPt=old(1)*72/2.54;oldHeightPt=old(2)*72/2.54;new=old+[leftPt topPt]*2.54/72;
ax=findall(fig,'Type','axes');
for k=1:numel(ax)
 if isappdata(ax(k),'mmaudit_plot_position'),p=getappdata(ax(k),'mmaudit_plot_position');else,set(ax(k),'Units','normalized');p=get(ax(k),'Position');end
 p=[(p(1)*old(1)+leftPt*2.54/72)/new(1) p(2)*old(2)/new(2) p(3)*old(1)/new(1) p(4)*old(2)/new(2)];set(ax(k),'Units','normalized','Position',p);setappdata(ax(k),'mmaudit_plot_position',p);
end
otherKinds={findall(fig,'Type','legend'),findall(fig,'Type','colorbar')};
for typ=1:numel(otherKinds),other=otherKinds{typ};for k=1:numel(other),set(other(k),'Units','normalized');p=get(other(k),'Position');p=[(p(1)*old(1)+leftPt*2.54/72)/new(1) p(2)*old(2)/new(2) p(3)*old(1)/new(1) p(4)*old(2)/new(2)];set(other(k),'Position',p);end;end
set(fig,'Units','centimeters');p=get(fig,'Position');p(3:4)=new;set(fig,'Position',p,'PaperPosition',[0 0 new],'PaperSize',new);
end



function [curve,auc]=empirical_corner_roc_v12(positive,negative)
assert(~isempty(positive)&&~isempty(negative)&&all(isfinite([positive;negative])));
thresholds=[Inf;sort(unique([positive;negative]),'descend');-Inf];curve=zeros(numel(thresholds),3);
for k=1:numel(thresholds),curve(k,:)=[thresholds(k) mean(negative>=thresholds(k)) mean(positive>=thresholds(k))];end
auc=trapz(curve(:,2),curve(:,3));assert(auc>=-1e-12&&auc<=1+1e-12);auc=min(1,max(0,auc));
end



function S=paired_roi_study_v12(dataDir,figDir,resultDir,exportHistoricalPlots)
% Genuine variable-length radar returns and same-file Kinect keypoints.
% The source visualizer's translations/ROI are applied without resampling.
% No acquisition timestamp, calibrated registration or RF cause is inferred.
if nargin<4,exportHistoricalPlots=true;end
path=fullfile(dataDir,'paired_radar_kinect_records_v12.mat');L=load(path);
R=L.records;if ~iscell(R),R=num2cell(R);end
radarTranslation=double(L.radar_translation_from_source_visualizer_m(:)');
referenceTranslation=double(L.reference_translation_from_source_visualizer_m(:)');bounds=double(L.source_hand_ROI_xyz_bounds_m);
assert(isequal(size(bounds),[3 2])&&numel(R)==96&&isequal(bounds,[-.2 .2;1.1 1.5;-.2 .3]),'Unexpected exact source-visualizer ROI.');
S.names={'record_id','source_block','source_index','n_radar_returns','n_radar_returns_in_source_ROI','n_reference_keypoints','n_reference_keypoints_in_source_ROI','min_reference_joint_NN_m','median_reference_joint_NN_m','p90_reference_joint_NN_m'};
S.records=zeros(numel(R),10);sourceRows=cell(numel(R),4);clouds=cell(numel(R),2);
for r=1:numel(R)
 a=R{r};pc=double(a.radar_points_as_stored(:,1:3))+radarTranslation;k=double(a.reference_keypoints_as_stored)+referenceTranslation;
 assert(size(pc,2)==3&&size(k,2)==3&&all(isfinite(pc(:)))&&all(isfinite(k(:))),'Nonfinite source geometry.');
 p=points_inside_roi_v12(pc,bounds);q=points_inside_roi_v12(k,bounds);nearest=[];
 if any(q),delta=reshape(k(q,:),[],1,3)-reshape(pc,1,[],3);nearest=sqrt(min(sum(delta.^2,3),[],2));end
 nq=plot_style('quantile',nearest,[0 .5 .9]);S.records(r,:)=[r str2double(a.session) double(a.file_index) size(pc,1) sum(p) size(k,1) sum(q) nq];
 sourceRows(r,:)={r,char(a.source_member),char(a.source_sha256),char(a.session)};clouds(r,:)={pc,k};
end
ref=S.records(:,7)>0;empty=S.records(:,5)==0;
assert(sum(ref)==94&&sum(ref&empty)==25&&all(S.records(:,4)>0),'Source ROI fixture counts changed.');
S.summary=struct('n_source_snapshots',numel(R),'n_reference_ROI_positive',sum(ref),'n_reference_ROI_joints',sum(S.records(:,7)),'n_ROI_empty_with_reference',sum(ref&empty),'reference_conditioned_ROI_empty_percent',100*mean(empty(ref)), ...
 'all_global_clouds_nonempty',all(S.records(:,4)>0),'acquisition_time_available',false,'calibrated_registration_asserted',false,'receiver_overload_cause_assigned',false);
writeNumeric(fullfile(resultDir,'paired_roi_snapshot_measures_v12.csv'),S.names,S.records);
writeMappings(fullfile(resultDir,'paired_roi_source_map_v12.csv'),{'record_id','source_member','source_sha256','source_block'},sourceRows);
blocks=unique(S.records(:,2));S.blocks=zeros(numel(blocks),7);
for b=1:numel(blocks)
 z=S.records(:,2)==blocks(b);n=sum(z&ref);lost=sum(z&ref&empty);S.blocks(b,:)=[blocks(b) sum(z) n n-lost lost 100*(n-lost)/n 100*lost/n];
end
S.block_names={'source_block','n_snapshots','n_reference_ROI_positive','n_with_radar_ROI_support','n_without_radar_ROI_support','ROI_support_percent_of_reference_positive','ROI_empty_percent_of_reference_positive'};
writeNumeric(fullfile(resultDir,'paired_roi_block_summary_v12.csv'),S.block_names,S.blocks);
% Whole-cloud changes use every stored radar row and filename-adjacent pairs
% within a source folder. Filename order supplies no acquisition clock or RF
% exposure label; these descriptors cannot identify receiver overload.
S.full_cloud_pairs=zeros(0,9);
for r=2:numel(R)
 if S.records(r,2)==S.records(r-1,2)&&S.records(r,3)==S.records(r-1,3)+1
  n0=S.records(r-1,4);n1=S.records(r,4);
  S.full_cloud_pairs(end+1,:)=[S.records(r,2) S.records(r-1,3) S.records(r,3) n0 n1 n1-n0 n1/n0 100*(1-n1/n0) double(n1<=.5*n0)]; %#ok<AGROW>
 end
end
writeNumeric(fullfile(resultDir,'whole_cloud_adjacent_counts_v14.csv'),{'source_block','previous_source_index','current_source_index','previous_full_count','current_full_count','count_delta','retained_fraction','reduction_percent','at_least_half_reduction'},S.full_cloud_pairs);
S.summary.n_filename_adjacent_full_cloud_pairs=size(S.full_cloud_pairs,1);
S.summary.n_at_least_half_full_cloud_reductions=sum(S.full_cloud_pairs(:,9));
S.sensitivity=zeros(55,5);row=0;
for radius=[0 .02 .05]
 if radius==0,offsets=0;else,offsets=[-radius 0 radius];end
 for dx=offsets,for dy=offsets,for dz=offsets
  lost=0;for r=1:numel(R),if ref(r),lost=lost+~any(points_inside_roi_v12(clouds{r,1}+[dx dy dz],bounds));end;end
  row=row+1;S.sensitivity(row,:)=[radius dx dy dz lost];
 end;end;end
end
S.sensitivity=S.sensitivity(1:row,:);writeNumeric(fullfile(resultDir,'paired_roi_registration_sensitivity_v12.csv'),{'max_component_offset_m','delta_x_m','delta_y_m','delta_z_m','n_ROI_empty_reference_positive'},S.sensitivity);
% Original full-cloud decrease/return example, source filenames32/33/34.
chosen=arrayfun(@(i)find(S.records(:,3)==i,1),[32 33 34]);
assert(numel(chosen)==3&&all(chosen>0)&&all(S.records(chosen,2)==1),'Whole-cloud source example identity changed.');S.example_ids=chosen;
exampleReference=vertcat(clouds{chosen,2});exampleBounds=[min(exampleReference,[],1)' max(exampleReference,[],1)'];
pointTable=zeros(0,6);allPoints=zeros(0,3);
for j=1:3
 r=chosen(j);for sensor=1:2,P=clouds{r,sensor};pointTable=[pointTable;repmat([r sensor],size(P,1),1) P double(points_inside_roi_v12(P,exampleBounds))];allPoints=[allPoints;P];end %#ok<AGROW>
end
writeNumeric(fullfile(resultDir,'whole_cloud_example_points_v14.csv'),{'record_id','sensor_id','x_m','y_m','z_m','in_fixed_reference_envelope'},pointTable);
if exportHistoricalPlots
[fig,old,C]=plot_style('new',18.1864,5.8);delete(old);labels={'Before decrease','Reduced full cloud','Count return'};
lo=min([allPoints;exampleBounds(:,1)'],[],1)-.06;hi=max([allPoints;exampleBounds(:,2)'],[],1)+.06;
for j=1:3
 r=chosen(j);pos=[.055+(j-1)*.325 .19 .27 .62];ax=axes('Parent',fig,'Position',pos);hold(ax,'on');setappdata(ax,'mmaudit_plot_position',pos);
 pc=clouds{r,1};k=clouds{r,2};scatter3(ax,pc(:,1),pc(:,2),pc(:,3),14,C(1,:),'filled');scatter3(ax,k(:,1),k(:,2),k(:,3),20,C(4,:),'x','LineWidth',1.1);draw_roi_box_v12(ax,exampleBounds,[82 143 173]/255);
 xlabel(ax,'X (m)');ylabel(ax,'Y (m)');zlabel(ax,'Z (m)');xlim(ax,[lo(1) hi(1)]);ylim(ax,[lo(2) hi(2)]);zlim(ax,[lo(3) hi(3)]);view(ax,[-32 22]);grid(ax,'on');
 title(ax,{sprintf('%s: %d returns',labels{j},S.records(r,4)),sprintf('Source index %02d',S.records(r,3))},'Interpreter','none');
 if j==1,lg=legend(ax,{'Radar returns','Kinect keypoints','Fixed reference envelope'},'Location','southoutside','NumColumns',3,'FontSize',9,'Box','off');set(lg,'AutoUpdate','off','Units','normalized','Position',[.18 .015 .64 .10]);end
end
pad_native_canvas_v12(fig,4,0);
plot_style('finish',fig,figDir,'figure24_paired_roi_examples_v12');
end
% Keep the original 94 source-ROI-qualified snapshots fixed throughout the
% extent sweep. Changing a box does not change the compared record population.
% Extents scale about the original box centre, with all axes scaled together.
scales=[.50 .75 1 1.25 1.50];centre=mean(bounds,2);halfExtent=(bounds(:,2)-bounds(:,1))/2;
S.extent_sweep=zeros(numel(scales)*numel(blocks),9);S.extent_support=zeros(numel(scales),numel(blocks));rr=0;
for si=1:numel(scales)
 box=[centre-scales(si)*halfExtent centre+scales(si)*halfExtent];
 for bi=1:numel(blocks)
  selected=find(ref&S.records(:,2)==blocks(bi));counts=zeros(numel(selected),1);referenceCounts=counts;
  for jj=1:numel(selected),r=selected(jj);counts(jj)=sum(points_inside_roi_v12(clouds{r,1},box));referenceCounts(jj)=sum(points_inside_roi_v12(clouds{r,2},box));end
  rr=rr+1;supported=sum(counts>0);S.extent_support(si,bi)=supported;
  S.extent_sweep(rr,:)=[scales(si) blocks(bi) numel(selected) supported numel(selected)-supported 100*supported/numel(selected) sum(referenceCounts>0) median(counts) mean(counts)];
 end
end
assert(isequal(S.extent_support(3,:),S.blocks(:,4)'),'Baseline extent does not reproduce source ROI.');
writeNumeric(fullfile(resultDir,'paired_roi_extent_sweep_v14.csv'),{'extent_factor','source_block','n_fixed_source_ROI_reference_positive','n_radar_supported','n_radar_empty','radar_supported_percent','n_reference_positive_under_scaled_ROI','median_radar_returns','mean_radar_returns'},S.extent_sweep);
if exportHistoricalPlots
[fig,ax,C]=plot_style('new',18.1864,5.7);pos=[.09 .23 .88 .72];set(ax,'Position',pos);setappdata(ax,'mmaudit_plot_position',pos);
percent=zeros(numel(scales),numel(blocks));for si=1:numel(scales),percent(si,:)=100*S.extent_support(si,:)./S.blocks(:,3)';end
b=bar(ax,1:numel(scales),percent,'grouped','BarWidth',.82);
for bi=1:numel(blocks),set(b(bi),'FaceColor',C(bi,:),'EdgeColor',[.18 .18 .18],'LineWidth',.6);end
set(ax,'XTick',1:numel(scales),'XTickLabel',arrayfun(@(v)sprintf('%.2f',v),scales,'UniformOutput',false),'YTick',0:20:100,'XGrid','off','YGrid','on');
xlabel(ax,'ROI extent / original source extent');ylabel(ax,'Regional support (%)');ylim(ax,[0 132]);xlim(ax,[.5 numel(scales)+.5]);
lab=arrayfun(@(bi)sprintf('Block %03d (n=%d)',blocks(bi),S.blocks(bi,3)),1:numel(blocks),'UniformOutput',false);
lg=legend(ax,b,lab,'Location','northwest','NumColumns',2,'FontSize',9,'Box','off');set(lg,'AutoUpdate','off','ItemTokenSize',[11 7]);
plot_style('finish',fig,figDir,'figure25a_roi_extent_support_v14');
end
% Each CDF observation is one same-file snapshot's median distance from the
% original source-ROI keypoints to its closest unfilled original radar returns.
S.cdf_rows=zeros(0,5);S.distance_summary=zeros(numel(blocks)+1,7);
if exportHistoricalPlots
 [fig,ax,C]=plot_style('new',8.9,6.0);pos=[.18 .21 .79 .74];set(ax,'Position',pos);setappdata(ax,'mmaudit_plot_position',pos);
 colours=[C;[30 70 110]/255];styles={'-','--','-.',':','-'};h=gobjects(numel(blocks)+1,1);
end
lab=cell(numel(blocks)+1,1);
for bi=1:numel(blocks)+1
 if bi<=numel(blocks),selected=find(ref&S.records(:,2)==blocks(bi));blockID=blocks(bi);lab{bi}=sprintf('Block %03d (n=%d)',blockID,numel(selected));else,selected=find(ref);blockID=-1;lab{bi}=sprintf('Pooled (n=%d)',numel(selected));end
 [x,ix]=sort(S.records(selected,9));selected=selected(ix);f=(1:numel(x))'/numel(x);S.cdf_rows=[S.cdf_rows;repmat(blockID,numel(x),1) selected x repmat(numel(x),numel(x),1) f]; %#ok<AGROW>
 q=plot_style('quantile',x,[.1 .25 .5 .75 .9]);S.distance_summary(bi,:)=[blockID numel(x) q];
 if exportHistoricalPlots,h(bi)=stairs(ax,[0;x],[0;f],'Color',colours(bi,:),'LineStyle',styles{bi},'LineWidth',1.25+.4*(bi>numel(blocks)));end
end
if exportHistoricalPlots
xlabel(ax,'Median keypoint-to-return distance (m)');ylabel(ax,'Snapshot CDF');ylim(ax,[0 1.02]);xlim(ax,[0 max(S.records(ref,9))*1.05]);
lg=legend(ax,h,lab,'Location','southeast','NumColumns',1,'FontSize',9,'Box','off');set(lg,'AutoUpdate','off','ItemTokenSize',[14 7]);
end
writeNumeric(fullfile(resultDir,'paired_roi_distance_cdf_v14.csv'),{'source_block_minus1_is_pooled','source_record_id','median_keypoint_nearest_return_m','n_snapshots_in_curve','empirical_cdf'},S.cdf_rows);
writeNumeric(fullfile(resultDir,'paired_roi_distance_summary_v14.csv'),{'source_block_minus1_is_pooled','n_snapshots','p10_m','p25_m','median_m','p75_m','p90_m'},S.distance_summary);
if exportHistoricalPlots,plot_style('finish',fig,figDir,'figure25b_roi_distance_cdf_v14');end

S.protocol=struct('coordinate_transform','Exact source visualizer translations only; no independently calibrated registration asserted','ROI_bounds_m',bounds,'radar_translation_m',radarTranslation,'reference_translation_m',referenceTranslation,'pairing','Same original MAT file; no acquisition timestamps or confidence flags available','feature_scope','Only XYZ used; fourth/fifth radar feature semantics unresolved','example_selection','Whole stored clouds 32/33/34: 38/19/41 returns; fixed Kinect envelope','measurement_scope','Reference-conditioned spatial support and nearest-return distance; not RF cause, attack success, temporal duration, or trained recovery accuracy','sensitivity','Hypothetical source-coordinate translation offsets, not additional collected snapshots','extent_sweep','Fixed original94 source-ROI-reference-positive snapshots; scale all ROI half-extents about the fixed source centre by0.50,0.75,1.00,1.25,1.50; each block denominator remains23,25,25,21','distance_CDF','One median source-ROI-keypoint-to-nearest-unfilled-radar-return distance per original reference-qualified snapshot; four source blocks andpooled94; no temporal or RF-cause interpretation');
writeJSON(fullfile(resultDir,'paired_roi_protocol_v12.json'),S.protocol);
end


function mask=points_inside_roi_v12(P,bounds)
mask=all(P>=bounds(:,1)'&P<=bounds(:,2)',2);
end


function draw_roi_box_v12(ax,bounds,color)
[a,b,c]=ndgrid(bounds(1,:),bounds(2,:),bounds(3,:));v=[a(:) b(:) c(:)];edges=[1 2;1 3;1 5;2 4;2 6;3 4;3 7;4 8;5 6;5 7;6 8;7 8];
for k=1:12,p=v(edges(k,:),:);plot3(ax,p(:,1),p(:,2),p(:,3),'--','Color',color,'LineWidth',.8,'HandleVisibility',onoff_v12(k==1));end
end


function value=onoff_style_v12(j),if j==1,value='-';else,value='--';end;end


function value=onoff_v12(test),if test,value='on';else,value='off';end;end




function map=figureMap()
map={ ...
 'figure04_data_profile','figure08_data_profile','Recorded nonempty group ECDF'; ...
 'figure05_evidence_coverage','figure09_evidence_coverage','Source evidence channels'; ...
 'figure06_replay_states','figure10_replay_states','Seven conditions and eight record aggregates'; ...
 'monitor_violation_tradeoff','figure11_monitor_violation_rates','Paired source-clock and uniform-clock software clearance'; ...
 'monitor_control_tradeoff','figure12_monitor_coverage','Persistence versus software clearance and merged events'; ...
 'figure10_sensitivity','figure13_replay_sensitivity','Recorded group gaps and missing-evidence run duration ECDF'; ...
 'figure09_runtime','figure14_runtime','Frozen measured software timing'; ...
 'figure10_adc_condition_response','figure15_adc_condition_response','Raw, filtered and per-chirp demeaned AC power'; ...
 'figure11_adc_spectral_profile','figure16_adc_spectral_profile','Frame-normalized measured spectra'; ...
 'figure12_message_group_accounting','figure17_message_group_accounting','Point messages and recorded groups'; ...
 'figure13_bearing_conversion_difference','figure18_bearing_conversion_difference','Declared degree/radian conversion'};
end


%% Local implementation: load_real_inputs.m


function S=public_adc_measurement_study(dataDir,outDir)
% Distinct source recordings, not three controlled overload trials.
% Additional records must be paired with explicit waveform/config metadata.
S=[];path=fullfile(dataDir,'supplemental_recordings_v11.mat');
if exist(path,'file')~=2,return;end
L=load(path,'study_records');records=L.study_records;if ~iscell(records),records=num2cell(records);end
n=numel(records);assert(n>=2&&n<=3,'Measurement triptych requires two or three documented sources.');
S.traces=zeros(0,5);S.maps=zeros(0,5);S.sources=cell(n,6);S.metadata=cell(n,1);
[fig,old,C]=plot_style('new',18.1864,8.1);delete(old);
for j=1:n
 a=records{j};if ~isfield(a,'fs_hz'),a.fs_hz=NaN;end;traceXLabel='Recorded time (s)';assert(isfield(a,'source_sha256')&&isfield(a,'device')&&isfield(a,'regime'),'Source metadata missing.');
 X=double(a.adc);assert(all(isfinite(real(X(:))))&&all(isfinite(imag(X(:)))),'Invalid recorded ADC values.');
 if strcmp(a.regime,'CW')
  trace=X(:);fs=a.fs_hz;t=(0:numel(trace)-1)'/fs;
  % CW uses temporal I/Q, not chirp fast time and not range.
  len=min(128,2^floor(log2(numel(trace)/4)));len=max(8,len);step=max(1,floor(len/4));starts=1:step:(numel(trace)-len+1);F=zeros(len,numel(starts));
  window=.5-.5*cos(2*pi*(0:len-1)'/(len-1));
  for q=1:numel(starts),seg=trace(starts(q)+(0:len-1));seg=seg-mean(seg);F(:,q)=abs(fftshift(fft(window.*seg))).^2;end
  mapX=(starts-1+len/2)/fs;mapY=(-len/2:len/2-1)'*fs/len;mapPower=F;mapXLabel='Recorded time (s)';mapYLabel='Temporal frequency (Hz)';traceLimit=min(numel(trace),round(20*fs));
 elseif strcmp(a.regime,'FMCW_COHERENT')
  assert(isfield(a,'pri_s')&&a.pri_s>0&&(isfield(a,'slope_hz_s')||isfield(a,'range_bin_m')),'Physical RD axes require documented range calibration and PRI.');
  if ndims(X)>2,X=X(:,:,1);end
  N=size(X,1);K=size(X,2);assert(K>=8,'At least eight coherent consecutive chirps required.');
  winFast=.5-.5*cos(2*pi*(0:N-1)'/(N-1));winSlow=.5-.5*cos(2*pi*(0:K-1)/(K-1));
  centered=X-mean(X,1);F=fft(centered.*winFast.*winSlow,[],1);F=fftshift(fft(F,[],2),2);Nkeep=floor(N/2);
  mapPower=abs(F(1:Nkeep,:)).^2;if isfield(a,'range_bin_m'),mapY=(0:Nkeep-1)'*a.range_bin_m;else,mapY=(0:Nkeep-1)'*a.fs_hz/N*299792458/(2*a.slope_hz_s);end;mapX=(-floor(K/2):ceil(K/2)-1)/(K*a.pri_s)*299792458/(2*a.fc_hz);
  mapXLabel='Radial-velocity equivalent (m/s)';if contains(a.source_id,'M3D'),mapXLabel='Nominal velocity (m/s)';a.nominal_slow_time_assumption='Configured same-TX PRI516us is assumed inside the fixed first32-captured-chirp window; initial configured-frame alignment and interframe timing are not encoded by ADC-only HSI headers, so physical velocity truth is unverified.';end;mapYLabel='Beat-range equivalent (m)';trace=X(:,1);fs=a.fs_hz;if isfinite(fs),t=(0:numel(trace)-1)'/fs;else,t=(0:numel(trace)-1)';traceXLabel='ADC sample index';end;traceLimit=numel(trace);
 elseif strcmp(a.regime,'FMCW_SELECTED_CHIRPS')
  % INRAS subset has nonuniform retained chirps: no fabricated Doppler FFT.
  N=size(X,1);window=.5-.5*cos(2*pi*(0:N-1)'/(N-1));F=abs(fft((X-mean(X,1)).*window,[],1)).^2;F=reshape(mean(F,2),N,[]);Nkeep=floor(N/2);
  mapPower=F(1:Nkeep,:);mapY=(0:Nkeep-1)'*a.fs_hz/N/1e6;mapX=double(a.frame_indices(:)');mapXLabel='Recorded frame index';mapYLabel='IF frequency (MHz)';trace=X(:,1,1);fs=a.fs_hz;if isfinite(fs),t=(0:numel(trace)-1)'/fs;else,t=(0:numel(trace)-1)';traceXLabel='ADC sample index';end;traceLimit=numel(trace);
 else,error('Unknown documented ADC regime.');end
 trace=trace(1:traceLimit);t=t(1:traceLimit);S.traces=[S.traces;repmat(j,numel(trace),1) (0:numel(trace)-1)' t real(trace) imag(trace)]; %#ok<AGROW>
 left=.055+(j-1)*(.94/n);width=.72/n;
 pos=[left .65 width .25];ax=axes('Parent',fig,'Position',pos);hold(ax,'on');setappdata(ax,'mmaudit_plot_position',pos);
 plot(ax,t,real(trace),'Color',C(1,:),'LineWidth',.65);if ~isreal(trace),plot(ax,t,imag(trace),'Color',C(4,:),'LineWidth',.65,'LineStyle','--');end
 xlabel(ax,traceXLabel);ylabel(ax,'Recorded ADC value');title(ax,a.device,'Interpreter','none');
 % Raster-free vector cells: coarsen linear power in documented adjacent bins
 % before normalization. This limits PDF complexity without interpolated data.
 [power,x,y]=adjacent_power_aggregation(mapPower,mapX,mapY,48,48);db=10*log10(max(power,realmin)/max(power(:)));db=max(db,-60);pos=[left .14 width .34];ax=axes('Parent',fig,'Position',pos);hold(ax,'on');setappdata(ax,'mmaudit_plot_position',pos);
 xe=[x(1)-(x(2)-x(1))/2 (x(1:end-1)+x(2:end))/2 x(end)+(x(end)-x(end-1))/2];ye=[y(1)-(y(2)-y(1))/2;(y(1:end-1)+y(2:end))/2;y(end)+(y(end)-y(end-1))/2];
 % Native2D rectangle cells preserve the exact aggregated linear-power values,
 % bin edges, and scaled64-color indices, while avoiding surface text outlines.
 mapColors=[30 70 110;55 103 149;114 188 213;255 230 183;255 208 111;231 98 84]/255;cellPalette=interp1(linspace(0,1,6),mapColors,linspace(0,1,64));
 colorIndex=min(64,max(1,fix((db+60)/60*64)+1));
 for rr=1:size(db,1),for cc=1:size(db,2),rectangle(ax,'Position',[xe(cc) ye(rr) xe(cc+1)-xe(cc) ye(rr+1)-ye(rr)],'FaceColor',cellPalette(colorIndex(rr,cc),:),'EdgeColor','none');end;end
 set(ax,'YDir','normal');mapColors=[30 70 110;55 103 149;114 188 213;255 230 183;255 208 111;231 98 84]/255;colormap(ax,interp1(linspace(0,1,6),mapColors,linspace(0,1,64)));clim(ax,[-60 0]);
 if j==n,cb=colorbar(ax,'Position',[.947 .14 .012 .34]);set(cb,'Ticks',[-60 -30 0],'FontName','Times New Roman','FontSize',9);title(cb,'dB');end;xlabel(ax,mapXLabel);ylabel(ax,mapYLabel);xlim(ax,[min(x) max(x)]);ylim(ax,[min(y) max(y)]);
 % Do not claim a shared calibration between devices or different ADC units.
 [xx,yy]=meshgrid(x,y);S.maps=[S.maps;repmat(j,numel(xx),1) xx(:) yy(:) power(:) db(:)]; %#ok<AGROW>
 S.sources(j,:)={j,a.source_id,a.device,a.regime,a.source_sha256,fs};S.metadata{j}=rmfield(a,'adc');S.metadata{j}.selected_adc_shape=size(a.adc);S.metadata{j}.trace_x_label=traceXLabel;S.metadata{j}.map_x_label=mapXLabel;S.metadata{j}.map_y_label=mapYLabel;
end
S.trace_names={'source_id','sample_index','trace_axis_coordinate','real_recorded_value','imag_recorded_value'};S.map_names={'source_id','map_x_coordinate','map_y_coordinate','linear_bin_mean_power','relative_display_db'};
pad_native_canvas_v12(fig,6,0);
plot_style('finish',fig,outDir,'figure22_recorded_adc_maps');
end


function [P,x,y]=adjacent_power_aggregation(power,x0,y0,maxX,maxY)
nx=size(power,2);ny=size(power,1);xb=round(linspace(1,nx+1,min(nx,maxX)+1));yb=round(linspace(1,ny+1,min(ny,maxY)+1));P=zeros(numel(yb)-1,numel(xb)-1);x=zeros(1,numel(xb)-1);y=zeros(numel(yb)-1,1);
for c=1:numel(x),ix=xb(c):xb(c+1)-1;x(c)=mean(x0(ix));end
for r=1:numel(y),iy=yb(r):yb(r+1)-1;y(r)=mean(y0(iy));for c=1:numel(x),ix=xb(c):xb(c+1)-1;P(r,c)=mean(power(iy,ix),'all');end;end
end



function E=cw_endpoint_study(dataDir,outDir)
% External 24-GHz CW I/Q endpoint validation, not FMCW overload attribution.
E=[];path=fullfile(dataDir,'cw_traces_v11.mat');if exist(path,'file')~=2,return;end
L=load(path,'records','sample_rate_Hz','endpoint_codes_as_recorded');R=L.records;if ~iscell(R),R=num2cell(R);end
assert(L.sample_rate_Hz==16&&isequal(double(L.endpoint_codes_as_recorded(:)'),[-1024 1023]));
E.metrics=zeros(numel(R),10);E.runs=zeros(0,5);E.trace=zeros(0,4);
for r=1:numel(R)
 a=R{r};I=double(a.I(:));Q=double(a.Q(:));t=double(a.t_s(:));assert(numel(I)==numel(Q)&&numel(I)==numel(t)&&all(diff(t)>0));
 assert(all(I>=-1024&I<=1023&Q>=-1024&Q<=1023),'Unexpected as-recorded endpoint codes.');
 hitI=I==-1024|I==1023;hitQ=Q==-1024|Q==1023;either=hitI|hitQ;
 assert(isfield(a,'generic_error_asserted'),'Generic-error evidence unavailable.');err=logical(a.generic_error_asserted(:));
 E.metrics(r,:)=[r numel(I) sum(hitI) sum(hitQ) sum(either) mean(hitI)*100 mean(hitQ)*100 mean(either)*100 sum(either&~err) sum(err)];
 for ch=1:2
  if ch==1,v=I;else,v=Q;end
  for code=[-1024 1023]
   hit=v==code;on=0;
   for k=1:numel(v)
    if hit(k)
     if on==0,on=k;elseif t(k)-t(k-1)>1.5/16,E.runs(end+1,:)=[r ch code k-on (k-on)/16];on=k;end %#ok<AGROW>
    elseif on>0,E.runs(end+1,:)=[r ch code k-on (k-on)/16];on=0;end %#ok<AGROW>
   end
   if on>0,E.runs(end+1,:)=[r ch code numel(v)-on+1 (numel(v)-on+1)/16];end %#ok<AGROW>
  end
 end
 if r==1
  % Fixed first20s after source-reader startup exclusion; no peak picking.
  ix=t<=t(1)+20;E.trace=[t(ix) I(ix) Q(ix) double(either(ix))];
 end
end
E.metric_names={'record_id','n_samples','n_I_endpoint','n_Q_endpoint','n_either_endpoint','I_endpoint_percent','Q_endpoint_percent','either_endpoint_percent','endpoint_without_generic_error','generic_error_count'};
E.run_names={'record_id','channel_id','endpoint_code','n_samples','duration_s'};E.trace_names={'recorded_time_s','I','Q','either_endpoint'};
[fig,old,C]=plot_style('new',8.89,7.6);delete(old);pos=[.20 .64 .75 .28];ax=axes('Parent',fig,'Position',pos);hold(ax,'on');setappdata(ax,'mmaudit_plot_position',pos);
a=plot(ax,E.trace(:,1),E.trace(:,2),'-','Color',C(1,:),'LineWidth',.9);b=plot(ax,E.trace(:,1),E.trace(:,3),'--','Color',C(4,:),'LineWidth',.9);yline(ax,-1024,':','Color',[.4 .4 .4],'HandleVisibility','off');yline(ax,1023,':','Color',[.4 .4 .4],'HandleVisibility','off');xlabel(ax,'Recorded time (s)');ylabel(ax,'As-recorded I/Q code');ylim(ax,[-1200 1500]);set(ax,'YTick',[-1024 0 1023]);
lg=legend(ax,[a b],{'I','Q'},'Location','northeast','FontSize',9,'Box','off');set(lg,'AutoUpdate','off');
pos=[.20 .18 .64 .30];ax=axes('Parent',fig,'Position',pos);hold(ax,'on');setappdata(ax,'mmaudit_plot_position',pos);yyaxis(ax,'left');b=bar(ax,1:numel(R),E.metrics(:,6:7),'grouped','BarWidth',.8);for k=1:2,set(b(k),'FaceColor',C(k,:),'EdgeColor',[.2 .2 .2],'LineWidth',.5);end
set(ax,'YColor',C(1,:));ylabel(ax,'Endpoint occupancy (%)');ylim(ax,[0 max(E.metrics(:,6:7),[],'all')*1.4]);
yyaxis(ax,'right');h=plot(ax,1:numel(R),E.metrics(:,8),'-o','Color',C(4,:),'MarkerFaceColor',C(4,:),'MarkerSize',3.2,'LineWidth',1.2);set(ax,'YColor',C(4,:));ylabel(ax,'Either channel (%)');ylim(ax,[0 max(E.metrics(:,8))*1.4]);xlabel(ax,'External CW recording');set(ax,'XTick',1:numel(R),'XTickLabel',arrayfun(@(r)sprintf('%02d',r),1:numel(R),'UniformOutput',false));xlim(ax,[.4 numel(R)+.6]);
lg=legend(ax,[b(:);h],{'I endpoint','Q endpoint','Either'},'Location','northeast','FontSize',9,'Box','off');set(lg,'AutoUpdate','off','ItemTokenSize',[11 7]);
plot_style('finish',fig,outDir,'figure23_cw_endpoint_validation');
E.protocol=struct('regime','24GHz continuous-wave I/Q,16Hz','source_role','External recorded-data validation; not TI FMCW reflection or damage experiment','source_reader','As supplied reader-compatible values after initial3s startup exclusion','endpoint_codes',[-1024 1023],'endpoint_interpretation','As-recorded extrema and repeated endpoint codes; not calibrated TI ADC full-scale','trace_selection','First20s of the first preselected archive recording, no peak selection','run_rule','Identical endpoint code in one I/Q channel, broken at non-endpoint value, code change, or timestamp gap>1.5/16s','generic_error','Only report actual supplied generic error fields; no inference that a dedicated saturation monitor was enabled');
end



function A = figure10_adc_response(D,outDir,deferSpectrum,deferPower)
% Offline base MATLAB / GNU Octave ADC descriptors, no failure labels.
cells=D.adc_records;assert(~isempty(cells));
ids={};nodes={};
for k=1:numel(cells)
 a=cells{k};s=char(a.source_id);nd=char(a.node);
 if ~any(strcmp(ids,s)),ids{end+1}=s;end
 if ~any(strcmp(nodes,nd)),nodes{end+1}=nd;end
end
acRows=cell(numel(cells),1);evidence=zeros(numel(cells),11);
frameRows=cell(numel(cells),1);profileRows=cell(numel(cells),1);bandRows=cell(numel(cells),1);data=cell(numel(cells),1);
for k=1:numel(cells)
 a=cells{k};X=double(a.raw_data);N=size(X,1);M=size(X,2);F=size(X,3);
 assert(N==512&&isreal(X)&&all(isfinite(X(:))),'Unexpected real ADC subset.');
 assert(numel(a.frame_indices)==F&&numel(a.chirp_indices)==M);fs=double(a.sample_rate_hz);assert(fs==20e6);
 H=filter([1 -1],1,X,[],1);win=.5-.5*cos(2*pi*(0:N-1)'/(N-1));
 Y=fft(bsxfun(@times,H,reshape(win,N,1,1)),N,1);P=squeeze(mean(abs(Y(1:N/2,:,:)).^2,2));
 rawPower=squeeze(mean(mean(abs(X).^2,1),2));power=squeeze(mean(mean(abs(H).^2,1),2));
 concentration=max(P,[],1)'./sum(P,1)';flatness=exp(mean(log(max(P,realmin)),1))'./mean(P,1)';
 si=find(strcmp(ids,char(a.source_id)));ni=find(strcmp(nodes,char(a.node)));
 ac=bsxfun(@minus,X,mean(X,1));acPower=squeeze(mean(mean(ac.^2,1),2));
 acRows{k}=[repmat(si,F,1),repmat(ni,F,1),double(a.frame_indices(:)),acPower(:),nan(F,1)];
 lo=min(X(:));hi=max(X(:));loRun=maxObservedRun(X==lo);hiRun=maxObservedRun(X==hi);
 evidence(k,:)=[si ni numel(X) lo hi sum(X(:)==lo) sum(X(:)==hi) loRun hiRun 0 0];

 frameRows{k}=[repmat(si,F,1),repmat(ni,F,1),double(a.frame_indices(:)),rawPower(:),power(:),concentration,flatness,nan(F,1)];
 spectrum=mean(P,2);bin=(0:N/2-1)';hz=fs*bin/N;range=3e8/2/(1e9/25.6e-6)*hz;
 normalized=10*log10(max(spectrum,realmin)/sum(spectrum));
 profileRows{k}=[repmat(si,N/2,1),repmat(ni,N/2,1),bin,hz,range,spectrum,normalized];
 frameDb=10*log10(max(bsxfun(@rdivide,P,sum(P,1)),realmin));
 band=zeros(N/2,3);for b=1:N/2,band(b,:)=plot_style('quantile',frameDb(b,:),[.1 .5 .9]);end
 bandRows{k}=[repmat(si,N/2,1),repmat(ni,N/2,1),bin,range,band];
 data{k}=struct('sid',si,'nid',ni,'power',power(:),'F',F,'M',M);
end
A.ac_frames=vertcat(acRows{:});A.evidence=evidence;
A.evidence_names={'measurement_id','node_id','n_samples','observed_minimum','observed_maximum','n_equal_minimum','n_equal_maximum','longest_minimum_run','longest_maximum_run','configured_rails_logged','receiver_health_labels_logged'};
A.frames=vertcat(frameRows{:});A.profiles=vertcat(profileRows{:});A.bands=vertcat(bandRows{:});A.ids=ids;A.nodes=nodes;
A.band_names={'measurement_id','node_id','bin','range_m','p10_frame_normalized_db','median_frame_normalized_db','p90_frame_normalized_db'};
A.frame_names={'measurement_id','node_id','frame_index','raw_mean_square','hpf_mean_square','spectral_concentration','spectral_flatness','relative_hpf_power_db'};
A.profile_names={'measurement_id','node_id','bin','frequency_hz','range_m','mean_spectral_power','normalized_spectral_db'};
refID=find(strcmp(ids,'meas_1_ref_corner'));assert(numel(refID)==1,'Matched corner reference is required.');
A.summary=zeros(numel(data),11);
for k=1:numel(data)
 z=data{k};ref=A.frames(A.frames(:,1)==refID&A.frames(:,2)==z.nid,5);assert(~isempty(ref));
 relative=10*log10(max(z.power,realmin)/median(ref));q=plot_style('quantile',relative,[.1 .25 .5 .75 .9]);
 ix=A.frames(:,1)==z.sid&A.frames(:,2)==z.nid;
 A.summary(k,:)=[z.sid,z.nid,z.F,z.M,q,median(A.frames(ix,6)),median(A.frames(ix,7))];A.frames(ix,8)=relative;
end
A.summary_names={'measurement_id','node_id','n_frames','n_selected_chirps','p10_db','p25_db','median_relative_db','p75_db','p90_db','median_concentration','median_flatness'};
% Style source: mmSpyVR_figure.m lines8--43 and VR_PCT lines508--546.
% Raw and filtered powers use separate matched station/corner references.
% All four series are ratios in dB; neither estimator labels saturation.
A.expanded_power=zeros(28,8);A.expanded_power_names={'measurement_id','node_id','estimator_id','n_frames','p10_db','median_db','p90_db','reference_median_mean_square'};
% Retain the v9 raw/filtered table, and add an independently normalized AC path.
A.power_three=zeros(42,8);medians=zeros(numel(ids),6);low=medians;high=medians;jj=0;oldj=0;
for ni=1:2
 for e=1:3
  series=(ni-1)*3+e;
  if e<=2,frameTable=A.frames;dataColumn=3+e;else,frameTable=A.ac_frames;dataColumn=4;end
  ref=frameTable(frameTable(:,1)==refID&frameTable(:,2)==ni,dataColumn);denom=median(ref);
  for j=1:numel(ids)
   ix=frameTable(:,1)==j&frameTable(:,2)==ni;z=frameTable(ix,dataColumn);
   vals=10*log10(max(z,realmin)/denom);q=plot_style('quantile',vals,[.1 .5 .9]);
   medians(j,series)=q(2);low(j,series)=q(1);high(j,series)=q(3);jj=jj+1;
   A.power_three(jj,:)=[j ni e numel(vals) q denom];
   if e<=2,oldj=oldj+1;A.expanded_power(oldj,:)=[j ni e numel(vals) q denom];else,A.ac_frames(ix,5)=vals;end
   if e==2,row=A.summary(A.summary(:,1)==j&A.summary(:,2)==ni,:);assert(abs(q(2)-row(7))<1e-12);end
  end
 end
end
% The publication entry point exports record-level incidence in place of the former power-ratio plot.

if nargin<3||~deferSpectrum,A=retained_spectral_figure_v12(A,outDir);end
end



function A=retained_spectral_figure_v12(A,outDir,insertionCalibration)
ids=A.ids;nodes=A.nodes;refID=find(strcmp(ids,'meas_1_ref_corner'));C=[55 103 149;114 188 213;255 208 111;231 98 84]/255;
palette=[C(1,:);C(4,:);C(2,:);[239 138 71]/255;[82 143 173]/255;[30 70 110]/255;[.35 .35 .35]];
[fig,ax,~]=plot_style('new',18.1864,5.4);delete(ax);styles={'-','--','-.',':','-','--','-.'};
A.peaks=zeros(14,6);A.peak_names={'measurement_id','node_id','peak_bin','peak_range_m','peak_median_normalized_db','median_spectral_concentration_percent'};
for ni=1:numel(nodes)
 hh=cell(7,1);pos=[.09+(ni-1)*.48 .25 .39 .66];ax=axes('Parent',fig,'Position',pos);hold(ax,'on');setappdata(ax,'mmaudit_plot_position',pos);
 for j=1:numel(ids)
  Q=A.bands(A.bands(:,1)==j&A.bands(:,2)==ni,:);
  frequencyMHz=Q(:,3)*20e6/512/1e6;
  fill(ax,[frequencyMHz;flipud(frequencyMHz)],[Q(:,5);flipud(Q(:,7))],palette(j,:),'FaceAlpha',.055,'EdgeColor','none');
  hh{j}=plot(ax,frequencyMHz,Q(:,6),'color',palette(j,:),'linestyle',styles{j},'linewidth',1.1);
  [peak,pki]=max(Q(:,6));plot(ax,frequencyMHz(pki),peak,'o','Color',palette(j,:),'MarkerFaceColor',palette(j,:),'MarkerEdgeColor',[.15 .15 .15],'MarkerSize',4,'HandleVisibility','off');
  row=A.summary(A.summary(:,1)==j&A.summary(:,2)==ni,:);A.peaks((ni-1)*7+j,:)=[j ni Q(pki,3) Q(pki,4) peak 100*row(10)];
 end
 xlabel(ax,'IF frequency (MHz)');if ni==1,ylabel(ax,'Frame-normalized energy (dB)');end
 title(ax,nodes{ni});xlim(ax,[0 max(A.profiles(:,4))/1e6]);ylim(ax,[-65 12]);set(ax,'YTick',[-60 -40 -20 0]);
 rows=A.summary(A.summary(:,2)==ni,:);candidate=rows(rows(:,1)~=refID,:);[~,hi]=max(candidate(:,7));strongID=candidate(hi,1);
 refPeak=A.peaks(A.peaks(:,1)==refID&A.peaks(:,2)==ni,:);strongPeak=A.peaks(A.peaks(:,1)==strongID&A.peaks(:,2)==ni,:);labels=shortLabels(ids);
 annotationText={sprintf('Global max (corner): %.2f MHz',refPeak(3)*20/512), ...
  sprintf('%s: %.2f MHz; max-bin %.1f%%',labels{strongID},strongPeak(3)*20/512,strongPeak(6))};
 if nargin>=3 && ~isempty(insertionCalibration)
  q=insertionCalibration(insertionCalibration(:,1)==ni,:);assert(size(q,1)==1);
  insertionMHz=q(5)*20/512;assert(abs(insertionMHz-2.3828125)<eps(3));
  xline(ax,insertionMHz,':','Color',[.25 .25 .25],'LineWidth',.8,'HandleVisibility','off','FontName','Times New Roman','FontSize',9);
  annotationText{end+1}=sprintf('Fixed insertion lobe: %.2f MHz',insertionMHz);
 end
 text(ax,.98,.08,annotationText,'Units','normalized','HorizontalAlignment','right','VerticalAlignment','bottom','Color',[.1 .1 .1],'BackgroundColor','w','Margin',1);
 lg=legend(ax,[hh{:}],shortLabels(ids),'Location','northwest','NumColumns',3,'FontSize',9,'FontWeight','bold','Box','off');set(lg,'AutoUpdate','off','ItemTokenSize',[10 7]);
end
plot_style('finish',fig,outDir,'figure11_adc_spectral_profile');
end



function n=maxObservedRun(mask)
% Runs are within one chirp's fast-time samples, never across chirp boundaries.
traces=reshape(mask,size(mask,1),[]);n=0;
for k=1:size(traces,2)
 d=diff([false;traces(:,k);false]);starts=find(d==1);ends=find(d==-1)-1;
 if ~isempty(starts),n=max(n,max(ends-starts+1));end
end
end



function labels=shortLabels(ids)
labels=ids;
for k=1:numel(ids)
 switch ids{k}
  case 'meas_0_ref',labels{k}='No corner';
  case 'meas_1_ref_corner',labels{k}='Corner ref.';
  case 'meas_2_int_A',labels{k}='A';
  case 'meas_3_int_A_pedestrian',labels{k}='A + person';
  case 'meas_4_int_B',labels{k}='B';
  case 'meas_5_int_C',labels{k}='C';
  case 'meas_6_int_D',labels{k}='D';
 end
end
end


%% Local implementation: figure12_adapter_validation.m


function varargout=plot_style(action,varargin)
% Base MATLAB / GNU Octave plotting; no platform is relabeled as MATLAB Online.
switch char(action)
    case 'new'
        width=varargin{1};height=varargin{2};
        fig=figure('Color','w','Units','centimeters','Position',[2 2 width height], ...
            'PaperUnits','centimeters','PaperPosition',[0 0 width height],'PaperSize',[width height]);
        left=1.60/width;
        ax=axes('Parent',fig,'Units','normalized','Position',[left .25 .97-left .63]);hold(ax,'on');
        setappdata(ax,'mmaudit_plot_position',get(ax,'Position'));
        set(ax,'FontName','Times New Roman','FontWeight','bold','FontSize',9, ...
            'LineWidth',1.1,'Box','on','YGrid','on','XGrid','off');
        if isprop(ax,'GridAlpha'),set(ax,'GridAlpha',.28);end
        if isprop(ax,'GridColor'),set(ax,'GridColor',[.82 .82 .82]);end
        set(ax,'GridLineStyle',':');
        if isprop(ax,'XTickLabelRotation'),set(ax,'XTickLabelRotation',0);end
        if isprop(ax,'TickLabelInterpreter'),set(ax,'TickLabelInterpreter','none');end
        colors=[55 103 149;114 188 213;255 208 111;231 98 84]/255;
        varargout={fig,ax,colors};
    case 'finish'
        fig=varargin{1};outDir=varargin{2};name=char(varargin{3});
        map=figureMap();which=find(strcmp(map(:,1),name));
        if ~isempty(which),name=map{which,2};end
        if isappdata(0,'mmaudit_refine_only')&&getappdata(0,'mmaudit_refine_only')&&~any(strcmp(name,{'figure11_monitor_violation_rates','figure12_monitor_coverage','figure13_replay_sensitivity','figure14_runtime','figure15_adc_condition_response','figure16_adc_spectral_profile','figure21_analytical_boundaries','figure22_recorded_adc_maps','figure23_cw_endpoint_validation'}))
            close(fig);return;
        end
        if ~exist(outDir,'dir'),mkdir(outDir);end
        axesList=findall(fig,'Type','axes');
        for k=1:numel(axesList)
            tag=get(axesList(k),'Tag');if strcmp(tag,'legend')||strcmp(tag,'colorbar')||strcmp(tag,'mmauditlegend'),continue;end
            set(axesList(k),'FontName','Times New Roman','FontWeight','bold','FontSize',9,'LineWidth',1.0);
            if isappdata(axesList(k),'mmaudit_plot_position')
                set(axesList(k),'Units','normalized','Position',getappdata(axesList(k),'mmaudit_plot_position'));
            end
            if isprop(axesList(k),'GridColor'),set(axesList(k),'GridColor',[.82 .82 .82]);end
            if isprop(axesList(k),'GridAlpha'),set(axesList(k),'GridAlpha',.28);end
            set(axesList(k),'GridLineStyle',':');
            if isprop(axesList(k),'XTickLabelRotation'),set(axesList(k),'XTickLabelRotation',0);end
            if isprop(axesList(k),'TickLabelInterpreter'),set(axesList(k),'TickLabelInterpreter','none');end
        end
        textList=findall(fig,'Type','text');
        for k=1:numel(textList)
            a=ancestor(textList(k),'axes');sz=9;
            if ~isempty(a)&&strcmp(get(a,'Tag'),'mmauditlegend'),sz=9;end
            set(textList(k),'FontName','Times New Roman','FontWeight','bold','FontSize',sz,'Interpreter','none');
        end
        if exist('OCTAVE_VERSION','builtin')
            legends=findall(fig,'Tag','legend');
        else
            legends=findall(fig,'Type','legend');
        end
        for k=1:numel(legends),set(legends(k),'FontName','Times New Roman','FontWeight','bold','FontSize',9);end
        if exist('OCTAVE_VERSION','builtin')
            % gnuplot's PDF renderer scales line widths down by about four.
            % Correct export strokes, leaving MATLAB-native widths untouched.
            curveLines=findall(fig,'Type','line');
            for k=1:numel(curveLines)
                h=curveLines(k);
                if ~isappdata(h,'mmaudit_original_linewidth'),setappdata(h,'mmaudit_original_linewidth',get(h,'LineWidth'));end
                set(h,'LineWidth',3*getappdata(h,'mmaudit_original_linewidth'));
            end
            for k=1:numel(axesList)
                tag=get(axesList(k),'Tag');if ~strcmp(tag,'legend')&&~strcmp(tag,'colorbar')&&~strcmp(tag,'mmauditlegend'),set(axesList(k),'LineWidth',2.0);end
            end
        end
        for k=1:numel(axesList)
            if isappdata(axesList(k),'mmaudit_plot_position')
                set(get(axesList(k),'XLabel'),'FontSize',10);set(get(axesList(k),'YLabel'),'FontSize',10);
            end
        end
        % Restore geometry last. Native legend listeners can otherwise resize
        % the data axes during font or line updates in gnuplot.
        for k=1:numel(axesList)
            if isappdata(axesList(k),'mmaudit_plot_position')
                if isprop(axesList(k),'PositionConstraint'),set(axesList(k),'PositionConstraint','innerposition');end
                set(axesList(k),'Units','normalized','Position',getappdata(axesList(k),'mmaudit_plot_position'));
            end
        end
        fontObjects=findall(fig,'-property','FontName');set(fontObjects,'FontName','Times New Roman');
        % Keep offscreen: MATLAB Online's floating viewer can block the engine.
        set(fig,'Visible','off');
        fprintf('V14_NATIVE_EXPORT: %s (offscreen Painters).\n',name);
        drawnow nocallbacks;
        pdfPath=fullfile(outDir,[name '.pdf']);
        if exist('OCTAVE_VERSION','builtin')
            print(fig,pdfPath,'-dpdf','-painters');
        else
            % Render to a local temporary file, then register completed bytes
            % with MATLAB Drive. Direct graphics writes can otherwise expose
            % incomplete content to Drive's ZIP/download snapshot.
            temporaryPdf=[tempname '.pdf'];
            print(fig,temporaryPdf,'-dpdf','-painters');
            drawnow;pause(.25);
            fid=fopen(temporaryPdf,'rb');assert(fid>=0,'Cannot open rendered PDF.');
            pdfBytes=fread(fid,Inf,'*uint8');fclose(fid);
            assert(numel(pdfBytes)>1000 && isequal(char(pdfBytes(1:5))','%PDF-'), ...
                'Native PDF renderer did not finish a valid PDF.');
            copyfile(temporaryPdf,pdfPath,'f');delete(temporaryPdf);
        end
        exported=dir(pdfPath);assert(~isempty(exported)&&exported.bytes>1000,'Figure PDF export is empty or incomplete.');
        if exist('OCTAVE_VERSION','builtin')
            hgsave(fig,fullfile(outDir,[name '.ofig']));
        else
            savefig(fig,fullfile(outDir,[name '.fig']));
            recordNativeFonts_v17(fig,fullfile(outDir,[name '.fig']));
            temporarySvg=[tempname '.svg'];print(fig,temporarySvg,'-dsvg','-painters');info=dir(temporarySvg);assert(info.bytes>1000,'Empty SVG export.');copyfile(temporarySvg,fullfile(outDir,[name '.svg']),'f');delete(temporarySvg);
        end
        close(fig);
    case 'manuallegend'
        fig=varargin{1};colors=varargin{2};labels=varargin{3};pos=varargin{4};ncols=varargin{5};kind=varargin{6};
        n=numel(labels);nrows=ceil(n/ncols);styles=repmat({'-'},n,1);
        if numel(varargin)>=7,styles=varargin{7};end
        a=axes('Parent',fig,'Units','normalized','Position',pos,'Tag','mmauditlegend','Visible','off');hold(a,'on');
        set(a,'XLim',[0 1],'YLim',[0 1],'Clipping','off');
        marks={'o','s','^','d'};
        for j=1:n
            col=mod(j-1,ncols);row=floor((j-1)/ncols);x=col/ncols;y=1-(row+.5)/nrows;w=1/ncols;
            if strcmp(kind,'patch')
                % Thick native line swatch also renders in gnuplot when the
                % key axes is hidden; hidden-axes patches can disappear.
                plot(a,x+w*[.02 .22],[y y],'Color',colors(j,:),'LineWidth',6);
            elseif strcmp(kind,'marker')
                plot(a,x+.12*w,y,'LineStyle','none','Marker',marks{mod(j-1,4)+1},'MarkerSize',4.5,'Color',colors(j,:),'MarkerFaceColor',colors(j,:));
            else
                plot(a,x+w*[.02 .22],[y y],'Color',colors(j,:),'LineWidth',1.25,'LineStyle',styles{j});
            end
            text(a,x+.28*w,y,labels{j},'HorizontalAlignment','left','VerticalAlignment','middle','FontName','Times New Roman','FontWeight','bold','FontSize',9,'Interpreter','none');
        end
        varargout={a};
    case 'quantile'
        x=sort(double(varargin{1}(:)));p=varargin{2};x=x(isfinite(x));
        if isempty(x)
            v=nan(size(p));
        elseif numel(x)==1
            v=repmat(x,size(p));
        else
            v=interp1(1:numel(x),x,1+(numel(x)-1)*p,'linear');
        end
        varargout={v};
    otherwise
        error('mmAudit:PlotAction','Unknown plot helper action.');
end
end


%% Validation, optional benchmarking and explicit CSV/JSON output


function writeNumeric(path,names,M)
fid=fopen(path,'w');assert(fid>=0);fprintf(fid,'%s\n',strjoin(names,','));
if ~isempty(M),fmt=[repmat('%.17g,',1,size(M,2)-1),'%.17g\n'];fprintf(fid,fmt,M');end;fclose(fid);
end


function writeMappings(path,header,rows)
fid=fopen(path,'w');assert(fid>=0);fprintf(fid,'%s\n',strjoin(header,','));
for r=1:size(rows,1)
 for c=1:size(rows,2)
  if c>1,fprintf(fid,',');end
  v=rows{r,c};if isnumeric(v),fprintf(fid,'%.17g',v);else,fprintf(fid,'"%s"',strrep(v,'"','""'));end
 end
 fprintf(fid,'\n');
end
fclose(fid);
end


function writeJSON(path,value)
fid=fopen(path,'w');assert(fid>=0);fprintf(fid,'%s\n',jsonencode(value));fclose(fid);
end



function value=fileSHA256(path)
fid=fopen(path,'rb');assert(fid>=0,'Cannot hash input file.');bytes=fread(fid,Inf,'*uint8');fclose(fid);
md=javaMethod('getInstance','java.security.MessageDigest','SHA-256');md.update(typecast(bytes,'int8'));
hash=typecast(md.digest(),'uint8');value=lower(reshape(dec2hex(hash,2).',1,[]));
end



function audit = iq_spectral_audit_v15(dataDir, outputDir, referenceResultDir)
% IQ_SPECTRAL_AUDIT_V15 Recompute two different recorded-IF estimands.
% Draft for integration into the one-file MATLAB Online artifact. No plots.
% Uses original recorded values and source-defined present/absent controls.
% It assigns no overload, clipping, target-loss, or attack labels.
%
% iq_spectral_audit_v15(dataDir, outputDir, referenceResultDir)
% dataDir contains adc_inputs.mat and coherent_adc_v12.mat.
% referenceResultDir is optional; it contains the v14 MATLAB Online CSVs.
% All FFT-bin fields below use zero-based indices; MATLAB arrays use +1.

if nargin < 3, referenceResultDir = ''; end
if ~exist(outputDir,'dir'), mkdir(outputDir); end
selectedFile = fullfile(dataDir,'adc_inputs.mat');
coherentFile = fullfile(dataDir,'coherent_adc_v12.mat');
selected = load(selectedFile,'adc_records'); selected = to_cells_v15(selected.adc_records);
coherent = load(coherentFile,'adc_records'); coherent = to_cells_v15(coherent.adc_records);
assert(numel(selected)==14 && numel(coherent)==12,'Recorded source scope changed.');
ids = unique(cellfun(@(r) char(r.source_id),selected,'UniformOutput',false),'stable');
nodes = unique(cellfun(@(r) char(r.node),selected,'UniformOutput',false),'stable');
assert(numel(ids)==7 && numel(nodes)==2);

peakRows = repmat(struct(),14,1);
identityRows = cell(12,4); representationRows = cell(12,10); identityRow=0;
for k=1:numel(coherent)
    r=coherent{k}; x=double(r.raw_data);
    assert(isequal(size(x),[512 128 100]) && isreal(x) && all(isfinite(x(:))));
    assert(double(r.capture_rails_logged)==0,'Add calibrated code-domain metadata before interpreting rails.');
    representationRows(k,:)={char(r.source_id),char(r.node),'512 x 128 x 100',class(r.raw_data),...
        true,numel(x),min(x(:)),max(x(:)),false,'not_assigned'};
end
for k=1:numel(selected)
    r=selected{k}; x=double(r.raw_data);
    assert(isequal(size(x),[512 8 100]) && isreal(x) && all(isfinite(x(:))));
    assert(isequal(double(r.chirp_indices(:)'),[1 19 37 55 73 91 109 128]));
    assert(isequal(double(r.frame_indices(:)'),1:100) && double(r.sample_rate_hz)==20e6);
    match=find(cellfun(@(q) strcmp(char(q.source_id),char(r.source_id)) && ...
        strcmp(char(q.node),char(r.node)),coherent));
    if ~isempty(match)
        expected=coherent{match}.raw_data(:,double(r.chirp_indices),:);
        identical=isequal(r.raw_data,expected); assert(identical,'Subset is not an original-value slice.');
        identityRow=identityRow+1;
        identityRows(identityRow,:)={char(r.source_id),char(r.node),identical,max(abs(x(:)-double(expected(:))))};
    end
    p=fast_spectral_power_v15(x);
    frameDb=10*log10(max(p./sum(p,1),realmin));
    medianDb=median(frameDb,2); [peakDb,peakIndex]=max(medianDb);
    peakRows(k).measurement_id=find(strcmp(ids,char(r.source_id)));
    peakRows(k).node_id=find(strcmp(nodes,char(r.node)));
    peakRows(k).source_id=string(r.source_id);
    peakRows(k).node=string(r.node);
    peakRows(k).n_chirps=size(x,2);
    peakRows(k).n_frames=size(x,3);
    peakRows(k).global_median_spectral_peak_bin=peakIndex-1;
    peakRows(k).global_median_spectral_peak_MHz=(peakIndex-1)*20/512;
    peakRows(k).global_median_spectral_peak_dB=peakDb;
    peakRows(k).bin61_median_normalized_dB=medianDb(62);
    peakRows(k).bin133_median_normalized_dB=medianDb(134);
end
assert(identityRow==12);
calibrationRows=zeros(2,8); contrastRows=cell(24,10); row=0;
for ni=1:numel(nodes)
    node=nodes{ni}; present=select_source_v15(coherent,'meas_1_ref_corner',node);
    absent=select_source_v15(coherent,'meas_0_ref',node);
    meanPresent=mean_rd_v15(present,1:10); meanAbsent=mean_rd_v15(absent,1:10);
    valid=false(256,128); valid(6:end-5,5:end-4)=true;
    insertion=max(meanPresent-meanAbsent,0); insertion(~valid)=-Inf;
    [contrast,idx]=max(insertion(:)); [rr,dd]=ind2sub(size(insertion),idx);
    calibrationRows(ni,:)=[ni rr-1 (rr-1)*20/512 dd-1-64 ...
        meanPresent(rr,dd) meanAbsent(rr,dd) contrast sum(valid(:))];
    assert(rr-1==61 && dd-1-64==0,'Original fixed insertion lobe changed.');
    splits={1:10,11:100}; splitNames={'calibration_1_10','held_out_11_100'};
    for sp=1:2
        frames=splits{sp}; mp=mean_rd_v15(present,frames); ma=mean_rd_v15(absent,frames);
        for b=[61 133]
            for estimator=1:3
                if estimator==1
                    a=ma(b+1,65); p=mp(b+1,65); label='coherent_RD_zero_Doppler';
                elseif estimator==2
                    chirps=[1 19 37 55 73 91 109 128];
                    pa=fast_spectral_power_v15(absent(:,chirps,frames));
                    pp=fast_spectral_power_v15(present(:,chirps,frames));
                    a=mean(pa(b+1,:)); p=mean(pp(b+1,:)); label='mean_fast_spectral_8chirps';
                else
                    pa=fast_spectral_power_v15(absent(:,:,frames));
                    pp=fast_spectral_power_v15(present(:,:,frames));
                    a=mean(pa(b+1,:)); p=mean(pp(b+1,:)); label='mean_fast_spectral_128chirps';
                end
                row=row+1; contrastRows(row,:)={ni,node,splitNames{sp},label,b,b*20/512,a,p,p-a,10*log10(p/a)};
            end
        end
    end
end
peakTable=struct2table(peakRows);
calibrationTable=array2table(calibrationRows,'VariableNames',{'node_id','insertion_fast_bin',...
    'insertion_frequency_MHz','insertion_centered_doppler_bin','present_training_peak_power',...
    'absent_training_peak_power','positive_insertion_contrast_power','n_valid_CUTs'});
contrastTable=cell2table(contrastRows,'VariableNames',{'node_id','node','split','estimator','fast_bin',...
    'frequency_MHz','absent_power','present_power','present_minus_absent_power','present_over_absent_dB'});
identityTable=cell2table(identityRows,'VariableNames',{'source_id','node','selected_eight_chirps_bit_identical_to_full','maximum_absolute_difference'});
representationTable=cell2table(representationRows,'VariableNames',{'source_id','node','shape','storage_type','is_real',...
    'n_samples','minimum','maximum','native_rails_logged','overload_label'});
writetable(peakTable,fullfile(outputDir,'spectral_estimands_matlab_v15.csv'));
writetable(calibrationTable,fullfile(outputDir,'insertion_calibration_matlab_v15.csv'));
writetable(contrastTable,fullfile(outputDir,'insertion_vs_global_component_matlab_v15.csv'));
writetable(identityTable,fullfile(outputDir,'selected_chirp_identity_matlab_v15.csv'));
writetable(representationTable,fullfile(outputDir,'recorded_IF_representation_matlab_v15.csv'));
audit=struct('n_selected_records',14,'n_coherent_records',12,'n_frames_per_record',100,...
    'source_representation','Real-valued IF; no native complex I/Q channel pair.',...
    'insertion_bin',61,'insertion_frequency_MHz',61*20/512,...
    'station1_shared_global_median_spectral_bin',133,'global_spectrum_is_not_insertion_lobe',true,...
    'adc_native_rails_logged',false,'calibrated_clipping_fraction',[],...
    'overload_label','not_assigned','plots_created',false);
if ~isempty(referenceResultDir)
    old=readtable(fullfile(referenceResultDir,'retained_IF_peak_summary_v12.csv'));
    errors=zeros(height(old),1);
    for k=1:height(old)
        match=peakTable.measurement_id==old.measurement_id(k) & peakTable.node_id==old.node_id(k);
        assert(sum(match)==1);
        assert(peakTable.global_median_spectral_peak_bin(match)==old.peak_bin(k));
        errors(k)=abs(peakTable.global_median_spectral_peak_dB(match)-old.peak_median_normalized_db(k));
    end
    audit.maximum_global_peak_dB_difference_from_v14=max(errors);
    assert(max(errors)<1e-9);
end
fid=fopen(fullfile(outputDir,'iq_spectral_estimands_matlab_v15.json'),'w');
assert(fid>=0); cleanup=onCleanup(@() fclose(fid)); fprintf(fid,'%s',jsonencode(audit,PrettyPrint=true));
end



function records=to_cells_v15(records)
if ~iscell(records), records=num2cell(records); end
end


function x=select_source_v15(records,source,node)
idx=find(cellfun(@(r) strcmp(char(r.source_id),source) && strcmp(char(r.node),node),records));
assert(numel(idx)==1); x=double(records{idx}.raw_data);
end


function power=fast_spectral_power_v15(raw)
N=size(raw,1); x=filter([1 -1],1,double(raw),[],1);
fast=.5-.5*cos(2*pi*(0:N-1)'/(N-1));
F=fft(x.*reshape(fast,N,1,1),[],1);
power=squeeze(mean(abs(F(1:floor(N/2),:,:)).^2,2));
end


function power=mean_rd_v15(raw,frames)
power=zeros(size(raw,1)/2,size(raw,2));
for f=frames
    x=raw(:,:,f); N=size(x,1); K=size(x,2);
    fast=.5-.5*cos(2*pi*(0:N-1)'/(N-1)); slow=.5-.5*cos(2*pi*(0:K-1)/(K-1));
    x=filter([1 -1],1,x,[],1); x=x-mean(x,1);
    F=fft(x.*fast.*slow,[],1); F=fftshift(fft(F,[],2),2);
    power=power+abs(F(1:floor(N/2),:)).^2/numel(frames);
end
end




function Q=mmSilent_fig6_qwerty_v15(inputFile,figDir,resultDir)
% Reconstruct Figure 6 from unmodified author-acquired radar/Kinect records.
% The archive is point-cloud output, not raw ADC/IQ. Numeric file indices
% specify archive order only. No radar points are deleted or predicted.
if nargin<1,inputFile='qwerty_records_v15.mat';end
if nargin<2,figDir='mmSilent_fig6_qwerty_v15';end
if nargin<3,resultDir=figDir;end
if ~exist(figDir,'dir'),mkdir(figDir);end
if ~exist(resultDir,'dir'),mkdir(resultDir);end
Q=struct;Q.input_sha256=qwertyFileSHA_v15(inputFile);
assert(strcmp(Q.input_sha256,'5161b827aa68ba514475c663149e551132eef368c25420af57719cde9c8968ff'),'Canonical input SHA mismatch');
D=load(inputFile);R=D.records;
if ~iscell(R),R=num2cell(R);end
set(groot,'defaultAxesFontName','Times New Roman');
set(groot,'defaultTextFontName','Times New Roman');
set(groot,'defaultAxesFontSize',9.5);
rows=cell(numel(R),1);
sources=strings(numel(R),1); blocks=strings(numel(R),1); fileIndices=zeros(numel(R),1); pointCounts=zeros(numel(R),1); allKeypoints=cell(numel(R),1);
for i=1:numel(R)
    s=R{i};raw=double(s.radar_raw);p=raw(:,1:3)+reshape(D.radar_translation,1,3);
    k=double(s.reference_keypoints_raw)+reshape(D.keypoint_translation,1,3);
    sources(i)=string(s.source);blocks(i)=string(s.block);fileIndices(i)=double(s.file_index);pointCounts(i)=size(raw,1);allKeypoints{i}=k;
    nroi=zeros(1,2);
    for j=1:2,nroi(j)=sum(all(abs(p-D.roi_centres(j,:))<=D.roi_half_widths(j,:),2));end
    rows{i}=table(string(s.source),string(s.source_sha256),double(s.file_index),size(raw,1),nroi(1),nroi(2), ...
        'VariableNames',{'source','source_sha256','file_index','raw_radar_points','fixed_torso_points','fixed_leg_points'});
end
checks=vertcat(rows{:});writetable(checks,fullfile(resultDir,'fig6_unmodified_point_checks_v15.csv'));
% Record90 is fixed before rendering and retains all21measured returns.
pairRows=cell(numel(R)-1,1); npair=0;
for i=2:numel(R)
    if blocks(i)~=blocks(i-1),continue;end
    npair=npair+1;
    shift=norm(mean(allKeypoints{i},1)-mean(allKeypoints{i-1},1));
    pairRows{npair}=table(sources(i-1),sources(i),fileIndices(i)-fileIndices(i-1),pointCounts(i-1),pointCounts(i), ...
        100*(1-pointCounts(i)/pointCounts(i-1)),shift,'VariableNames', ...
        {'source_before','source_after','file_index_step','points_before','points_after','point_drop_percent','keypoint_centroid_shift_m'});
end
pairs=vertcat(pairRows{1:npair});writetable(pairs,fullfile(resultDir,'qwerty_adjacent_pairs_native_v15.csv'));
assert(numel(R)==221 && npair==218 && all(pointCounts>=20) && all(pointCounts<=47),'Archive inventory mismatch');
assert(sum(pointCounts)==6971,'Archive total count mismatch');
chosen=find(sources=="000/pc_ti_kinect_key_90.mat");assert(isscalar(chosen));
for ix=chosen(:)'
    s=R{ix};raw=double(s.radar_raw);
    p=raw(:,1:3)+reshape(D.radar_translation,1,3);
    k=double(s.reference_keypoints_raw)+reshape(D.keypoint_translation,1,3);
    mesh=double(s.reference_surface_raw);
    % Only the grey reference mesh is decimated, never radar points.
    mesh=mesh(mesh(:,1)>=-.8 & mesh(:,1)<=.6,:);
    mesh=mesh(1:12:end,:);
    centres=double(D.roi_centres);half=double(D.roi_half_widths);
    % The display box spans the thigh-to-upper-calf reference region. The
    % statistical leg ROI below remains unchanged and is not this box.
    displayCentre=median(k([19 20 21 23 24 25],:),1);displayHalf=[.16 .10 .30];
    regionCorners=[centres-half;centres+half;displayCentre-displayHalf;displayCentre+displayHalf];
    bounds=[p;k;regionCorners];lo=min(bounds,[],1)-[.04 .04 .04];hi=max(bounds,[],1)+[.04 .04 .04];
    % Every acquired radar row remains visible, including points outside the
    % fixed anatomical display limits in the original visualizer.
    lo=min(lo,[-.50 1.08 -.89]);hi=max(hi,[.50 1.77 .82]);
    fig=figure('Color','w','Units','centimeters','Position',[2 2 18.6 4.7], ...
        'PaperUnits','centimeters','PaperPosition',[0 0 18.6 4.7], ...
        'PaperSize',[18.6 4.7],'Renderer','painters');
    positions=[.065 .16 .245 .62;.395 .16 .245 .62;.725 .16 .245 .62];
    for v=1:3
        ax=axes(fig,'Position',positions(v,:));hold(ax,'on');
        set(ax,'SortMethod','childorder','Layer','top','FontName','Times New Roman', ...
            'FontSize',10.5,'FontWeight','bold','LineWidth',.85,'Box','off', ...
            'XGrid','off','YGrid','off','ZGrid','off','TickDir','out');
        if v==1
            scatter3(ax,mesh(:,1),mesh(:,2),mesh(:,3),1.2,[.80 .80 .80],'.');
            drawSkeleton(ax,k,3);
            hr=scatter3(ax,p(:,1),p(:,2),p(:,3),22,[1 0 0],'filled');
            % Child-order sorting and drawing the box last keep green edges
            % in front of the grey reference mesh in the exported figure.
            drawBox(ax,displayCentre,displayHalf,3);
            view(ax,[-37.5 30]);xlim(ax,[lo(1) hi(1)]);ylim(ax,[lo(2) hi(2)]);zlim(ax,[lo(3) hi(3)]);
            set(ax,'XTick',[-.5 0 .5],'YTick',[1.2 1.4 1.6],'ZTick',[-.5 0 .5]);
        elseif v==2
            scatter(ax,mesh(:,1),mesh(:,2),1.2,[.80 .80 .80],'.');
            drawSkeleton(ax,k,[1 2]);
            hr=scatter(ax,p(:,1),p(:,2),22,[1 0 0],'filled');
            % No anatomical box in the top view, as specified for Figure 6.
            xlim(ax,[lo(1) hi(1)]);ylim(ax,[lo(2) hi(2)]);
            set(ax,'XTick',[-.5 0 .5],'YTick',[1.2 1.4 1.6]);
        else
            scatter(ax,mesh(:,2),mesh(:,3),1.2,[.80 .80 .80],'.');
            drawSkeleton(ax,k,[2 3]);
            hr=scatter(ax,p(:,2),p(:,3),22,[1 0 0],'filled');
            drawBox(ax,displayCentre,displayHalf,[2 3]);
            xlim(ax,[lo(2) hi(2)]);ylim(ax,[lo(3) hi(3)]);
            set(ax,'XTick',[1.2 1.4 1.6],'YTick',[-.5 0 .5]);
        end
        assert(numel(hr.XData)==size(raw,1),'Displayed radar count differs from raw record');
        assert(all(isfinite(p),'all'),'Nonfinite radar coordinates');
        % Visible axes and numeric ticks follow mmSpyVR Figure 3.  Coordinate
        % order is XYZ (isometric), XY (top), and YZ (side), respectively.
    end
    % A dedicated invisible axes anchors a single horizontal, boxed legend
    % without resizing any of the three data axes. NaN handles are legend
    % keys only; they never add points to a measured cloud.
    keyAx=axes(fig,'Position',[.05 .84 .90 .14],'Visible','off');hold(keyAx,'on');
    hm=plot(keyAx,NaN,NaN,'.','Color',[.80 .80 .80],'MarkerSize',8);
    hr=plot(keyAx,NaN,NaN,'o','Color',[1 0 0],'MarkerFaceColor',[1 0 0],'MarkerSize',4.5);
    hs=plot(keyAx,NaN,NaN,'--','Color',[.1 .1 .1],'LineWidth',1.0);
    hb=plot(keyAx,NaN,NaN,'--','Color',[0 .75 0],'LineWidth',1.5);
    lg=legend(keyAx,[hm hr hs hb],{'Human mesh','mmWave point cloud','Skeleton key points','Leg region'}, ...
        'Orientation','horizontal','NumColumns',4,'FontName','Times New Roman', ...
        'FontWeight','bold','FontSize',10.5,'Box','on','EdgeColor',[.25 .25 .25]);
    set(lg,'AutoUpdate','off','Units','normalized','Position',[.07 .845 .86 .135]);
    tag=sprintf('fig6_raw_%03d_v17',double(s.file_index));
    qwertyExport_v15(fig,figDir,tag);
end
Q.inventory=struct('snapshots',numel(R),'total_radar_points',sum(pointCounts),'min_points',min(pointCounts),'max_points',max(pointCounts),'adjacent_pairs',npair);
Q.protocol=struct('figure6_display_box','Thigh-to-upper-calf display box centered on the per-record median of keypoint rows[19,20,21,23,24,25]; half-widths[0.16,0.10,0.30]m; shown only in isometric and side views', ...
    'figure6_layering','Grey mesh first; skeleton and all measured radar points next; green dashed box last; child-order sorting', ...
    'statistical_box','Counts retain the original fixed source000/89 leg half-widths[0.30,0.25,0.38]m and torso box; display box does not redefine them', ...
    'scope','Original point-cloud XYZ and same-file reference; no raw ADC/IQ or exposure label inferred');
Q.fixed_region_checks=checks;Q.adjacent_pairs=pairs;
Q.regional=qwertyRegional_v15(R,D,figDir,resultDir);
Q.newplotfiles={'fig6_raw_090_v17','figure25b_qwerty_leg_distance_cdf_v15','figure_regional_translation','figure_regional_incidence'};
save(fullfile(resultDir,'qwerty_numeric_audit_v15.mat'),'Q','checks','pairs','inputFile');
fprintf('FIG6_QWERTY_OK: all original radar points retained; records=%d; exports=1\n',numel(R));
end



function h=drawSkeleton(ax,k,dims)
parents=1+[0 0 1 2 2 4 5 6 7 8 7 2 11 12 13 14 15 14 0 18 19 20 0 22 23 24 3 26 26 26 26 26];
for n=2:size(k,1)
    a=k(n,:);b=k(parents(n),:);
    if isequal(dims,3),h=plot3(ax,[a(1) b(1)],[a(2) b(2)],[a(3) b(3)],'--','Color',[.10 .10 .10],'LineWidth',.95);
    else,h=plot(ax,[a(dims(1)) b(dims(1))],[a(dims(2)) b(dims(2))],'--','Color',[.10 .10 .10],'LineWidth',.95);end
end
end


function h=drawBox(ax,c,w,dims)
col=[0 .75 0];
if isequal(dims,3)
    [X,Y,Z]=ndgrid(c(1)+[-w(1) w(1)],c(2)+[-w(2) w(2)],c(3)+[-w(3) w(3)]);V=[X(:) Y(:) Z(:)];
    E=[1 2;1 3;1 5;2 4;2 6;3 4;3 7;4 8;5 6;5 7;6 8;7 8];h=gobjects(size(E,1),1);
    for e=1:size(E,1),q=V(E(e,:),:);h(e)=plot3(ax,q(:,1),q(:,2),q(:,3),'--','Color',col,'LineWidth',1.5);end
else
    x=c(dims(1))+[-1 1 1 -1 -1]*w(dims(1));y=c(dims(2))+[-1 -1 1 1 -1]*w(dims(2));
    h=plot(ax,x,y,'--','Color',col,'LineWidth',1.5);
end
end


function S=qwertyRegional_v15(R,D,figDir,resultDir)
% Original per-record counts and deterministic coordinate sensitivity.
scales=[.5 .75 1 1.25 1.5];legRows=[19 20 21 23 24 25];half=[.30 .25 .38];
n=numel(R);counts=zeros(n,5);torso=zeros(n,1);whole=zeros(n,1);centres=zeros(n,3);
distance=zeros(n,1);blocks=strings(n,1);sources=strings(n,1);allP=cell(n,1);
for i=1:n
 s=R{i};p=double(s.radar_raw(:,1:3))+reshape(D.radar_translation,1,3);
 k=double(s.reference_keypoints_raw)+reshape(D.keypoint_translation,1,3);
 assert(size(k,1)==32&&all(isfinite(k),'all'),'Invalid reference keypoints');
 joints=k(legRows,:);centres(i,:)=median(joints,1);allP{i}=p;
 sources(i)=string(s.source);blocks(i)=string(s.block);whole(i)=size(p,1);
 for z=1:5,counts(i,z)=sum(all(abs(p-centres(i,:))<=scales(z)*half,2));end
 torsoCentre=median(k(1:3,:),1);torso(i)=sum(all(abs(p-torsoCentre)<=[.20 .25 .25],2));
 nearest=zeros(6,1);
 for z=1:6,nearest(z)=min(sqrt(sum((p-joints(z,:)).^2,2)));end
 distance(i)=median(nearest);
end
assert(all(diff(counts,1,2)>=0,'all'),'ROI nesting mismatch');
assert(isequal(sum(counts==0,1),[165 111 52 18 4]),'Regional counts mismatch');
assert(all(torso>0)&&all(whole>0),'Reference baseline inventory changed');
T=table(sources,blocks,centres(:,1),centres(:,2),centres(:,3),distance,...
 counts(:,1),counts(:,2),counts(:,3),counts(:,4),counts(:,5),torso,whole,...
 'VariableNames',{'source','block','leg_centre_x_m','leg_centre_y_m','leg_centre_z_m',...
 'median_leg_joint_nearest_return_m','returns_extent_050','returns_extent_075',...
 'returns_extent_100','returns_extent_125','returns_extent_150','torso_returns','whole_cloud_returns'});
writetable(T,fullfile(resultDir,'qwerty_regional_records_v16.csv'));
blockNames=["000" "001" "002"];S.denominators=zeros(1,3);S.zero_counts=zeros(3,3);S.distance_summary=zeros(4,7);
for b=1:3
 m=blocks==blockNames(b);S.denominators(b)=sum(m);
 S.zero_counts(b,:)=[sum(counts(m,3)==0) sum(torso(m)==0) sum(whole(m)==0)];
end
assert(isequal(S.denominators,[100 100 21])&&isequal(S.zero_counts,[23 0 0;25 0 0;4 0 0]));
S.baseline_zero_counts=[sum(counts(:,3)==0) sum(torso==0) sum(whole==0)];
% Re-evaluate the same acquired records at nested declared ROI extents.
% Rows are extent factors; columns are original source blocks (not trials).
S.roi_scale_factors=scales;S.leg_zero_by_scale_then_block=zeros(5,3);
for b=1:3
 m=blocks==blockNames(b);S.leg_zero_by_scale_then_block(:,b)=sum(counts(m,:)==0,1)';
end
assert(isequal(S.leg_zero_by_scale_then_block,[70 78 17;46 56 9;23 25 4;9 7 2;4 0 0]), ...
 'Original-block nested-ROI inventory changed');
extentRows=zeros(15,6);erow=0;
for z=1:5,for b=1:3
 erow=erow+1;extentRows(erow,:)=[scales(z) b-1 S.denominators(b) ...
  S.leg_zero_by_scale_then_block(z,b) 100*S.leg_zero_by_scale_then_block(z,b)/S.denominators(b) n];
end;end
writeNumeric(fullfile(resultDir,'regional_leg_extent_by_block_v21.csv'), ...
 {'leg_ROI_half_extent_factor','source_block','n_records_in_source_block','zero_leg_records', ...
 'zero_leg_percent','n_original_pooled_records'},extentRows);
baselineRows=[(0:2)' S.denominators' S.zero_counts 100*S.zero_counts./S.denominators'];
writeNumeric(fullfile(resultDir,'regional_phantom_baselines_v16.csv'),...
 {'source_block','n_reference_qualified_records','leg_zero_records','torso_zero_records','whole_cloud_zero_records',...
 'leg_zero_percent','torso_zero_percent','whole_cloud_zero_percent'},baselineRows);
C=[55 103 149;114 188 213;255 208 111;30 70 110]/255;
% Main-text nearest-return CDF. Each record contributes one observation.
fig=figure('Color','w','Units','centimeters','Position',[2 2 8.9 6.0],'Renderer','painters');
ax=axes(fig,'Position',[.18 .21 .79 .74]);hold(ax,'on');qwertyAxes_v15(ax);
h=gobjects(4,1);lab=cell(4,1);styles={'-','--','-.','-'};cdfRows=zeros(0,4);
for b=1:4
 if b<=3,m=blocks==blockNames(b);bid=b-1;lab{b}=sprintf('Block %s (n=%d)',char(blockNames(b)),sum(m));
 else,m=true(n,1);bid=-1;lab{b}=sprintf('Pooled (n=%d)',n);end
 x=sort(distance(m));f=(1:numel(x))'/numel(x);
 h(b)=stairs(ax,[0;x],[0;f],'Color',C(b,:),'LineStyle',styles{b},'LineWidth',1.25+.4*(b==4));
 cdfRows=[cdfRows;repmat(bid,numel(x),1) x repmat(numel(x),numel(x),1) f]; %#ok<AGROW>
 probs=[.1 .25 .5 .75 .9];q=interp1(1:numel(x),x,1+(numel(x)-1)*probs,'linear');
 S.distance_summary(b,:)=[bid numel(x) q];
end
xlabel(ax,'Median leg-joint-to-return distance (m)');ylabel(ax,'Snapshot CDF');ylim(ax,[0 1.02]);xlim(ax,[0 max(distance)*1.05]);
legend(ax,h,lab,'Location','southeast','FontSize',9,'Box','off');
qwertyExport_v15(fig,figDir,'figure25b_qwerty_leg_distance_cdf_v15');
writeNumeric(fullfile(resultDir,'qwerty_distance_cdf_v16.csv'),...
 {'source_block_minus1_is_pooled','distance_m','n_records','empirical_CDF'},cdfRows);
writeNumeric(fullfile(resultDir,'qwerty_distance_summary_v16.csv'),...
 {'source_block_minus1_is_pooled','n_records','p10_m','p25_m','median_m','p75_m','p90_m'},S.distance_summary);
% Paired condition labels are not inferred from source-directory names.
% Deterministic translations preserve every acquired radar point.
offsets=[-.05 -.02 0 .02 .05];offsetCounts=zeros(numel(offsets),3);
for axisId=1:3
 for j=1:numel(offsets)
  delta=zeros(1,3);delta(axisId)=offsets(j);empty=0;
  for i=1:n,empty=empty+~any(all(abs((allP{i}+delta)-centres(i,:))<=half,2));end
  offsetCounts(j,axisId)=empty;
 end
end
shiftRows=zeros(numel(offsets)*3,5);r=0;
for axisId=1:3,for j=1:numel(offsets),r=r+1;shiftRows(r,:)=[axisId offsets(j) n offsetCounts(j,axisId) 100*offsetCounts(j,axisId)/n];end;end
writeNumeric(fullfile(resultDir,'regional_phantom_translation_v16.csv'),...
 {'radar_translation_axis_1X_2Y_3Z','translation_m','n_reference_qualified_records','zero_leg_records','incidence_percent'},shiftRows);
% Independent line and grouped-bar figures follow the presentation forms of
% PhantomLiDAR Figures 11 and 12; every plotted value remains this study's
% measured record-level statistic or deterministic registration sensitivity.
palette=[55 103 149;114 188 213;255 208 111;231 98 84]/255;
fig=figure('Color','w','Units','centimeters','Position',[2 2 8.9 5.6], ...
    'PaperUnits','centimeters','PaperPosition',[0 0 8.9 5.6],'PaperSize',[8.9 5.6],'Renderer','painters');
ax=axes(fig,'Position',[.20 .22 .76 .70]);hold(ax,'on');regionalAxes_v17(ax);
hh=gobjects(3,1);markers={'o','s','^'};styles={'-','--','-.'};
for j=1:3
 lineColour=palette(j,:);if j==3,lineColour=palette(4,:);end
 hh(j)=plot(ax,100*offsets,100*offsetCounts(:,j)/n,'Color',lineColour, ...
  'LineStyle',styles{j},'Marker',markers{j},'MarkerFaceColor',lineColour, ...
  'MarkerEdgeColor',[.20 .20 .20],'MarkerSize',5.0,'LineWidth',1.5);
end
yline(ax,100*52/221,':','Color',[.4 .4 .4],'LineWidth',1.0,'HandleVisibility','off');
xlabel(ax,'Radar-coordinate shift (cm)','FontSize',11);ylabel(ax,'Regional phantom incidence (%)','FontSize',11);
set(ax,'XTick',[-5 -2 0 2 5],'YTick',0:10:50);xlim(ax,[-5.5 5.5]);ylim(ax,[0 49]);
lg=legend(ax,hh,{'X shift','Y shift','Z shift'},'Location','northwest', ...
 'FontName','Times New Roman','FontSize',10,'FontWeight','bold','Box','on','NumColumns',1);
set(lg,'AutoUpdate','off','EdgeColor',[.35 .35 .35]);
qwertyExport_v15(fig,figDir,'figure_regional_translation');

fig=figure('Color','w','Units','centimeters','Position',[2 2 8.9 5.6], ...
    'PaperUnits','centimeters','PaperPosition',[0 0 8.9 5.6],'PaperSize',[8.9 5.6],'Renderer','painters');
ax=axes(fig,'Position',[.20 .22 .76 .70]);hold(ax,'on');regionalAxes_v17(ax);
rates=100*S.leg_zero_by_scale_then_block./S.denominators;
bars=bar(ax,1:5,rates,'grouped','BarWidth',.82);
for j=1:3,set(bars(j),'FaceColor',palette(j,:),'EdgeColor',[.25 .25 .25],'LineWidth',.65);end
drawnow;
for b=1:3
 xp=bars(b).XEndPoints;
 for z=1:5
  text(ax,xp(z),rates(z,b)+1.5,sprintf('%d',S.leg_zero_by_scale_then_block(z,b)), ...
   'HorizontalAlignment','center','FontName','Times New Roman','FontWeight','bold','FontSize',9.0);
 end
end
set(ax,'XTick',1:5,'XTickLabel',{'0.50','0.75','1.00','1.25','1.50'},'YTick',0:20:80);
xlabel(ax,'Leg ROI half-extent factor','FontSize',11);ylabel(ax,'Zero-support records (%)','FontSize',11);
xlim(ax,[.5 5.5]);ylim(ax,[0 94]);
lg=legend(ax,bars,{'000 (n=100)','001 (n=100)','002 (n=21)'}, ...
 'Orientation','horizontal','NumColumns',3,'FontName','Times New Roman', ...
 'FontSize',9.2,'FontWeight','bold','Box','on');
set(lg,'AutoUpdate','off','EdgeColor',[.35 .35 .35],'Units','normalized','Position',[.12 .84 .85 .10]);
if isprop(lg,'ItemTokenSize'),set(lg,'ItemTokenSize',[10 7]);end
set(ax,'Position',[.20 .22 .76 .59]);
qwertyExport_v15(fig,figDir,'figure_regional_incidence');
% Preserve the full joint three-axis sensitivity grid as a numerical audit.
sens=zeros(54,5);row=0;
for delta=[.02 .05],for dx=[-delta 0 delta],for dy=[-delta 0 delta],for dz=[-delta 0 delta]
 row=row+1;empty=0;for i=1:n,empty=empty+~any(all(abs(allP{i}-(centres(i,:)+[dx dy dz]))<=half,2));end
 sens(row,:)=[delta dx dy dz empty];
end;end;end;end
writeNumeric(fullfile(resultDir,'qwerty_translation_grid_v16.csv'),{'grid_half_extent_m','reference_dx_m','reference_dy_m','reference_dz_m','zero_leg_records'},sens);
S.base_unsupported=sum(counts(:,3)==0);S.pooled_unsupported_by_scale=sum(counts==0,1);
S.translations=sens;S.one_axis_translation_counts=offsetCounts;S.one_axis_offsets_m=offsets;
S.protocol=struct('event','All declared reference joints finite and zero stored radar returns in the leg ROI',...
 'statistical_unit','One stored paired record, not an independent RF exposure trial',...
 'leg_keypoint_rows_one_based',legRows,'leg_half_widths_m',half,...
 'torso_keypoint_rows_one_based',[1 2 3],'torso_half_widths_m',[.20 .25 .25],...
 'roi_centre','Per-record coordinate-wise median of the specified independent reference joints',...
 'cdf','Median over six leg joints of distance to nearest original radar return',...
 'source_block_denominators',[100 100 21],'mapping_sensitivity','Rigid coordinate translations only; all measured radar rows retained');
end



function S=iq_paired_spatial_v17(inputFile,resultDir)
% Same-file paired-record replication from the uploaded IQ Data archive.
% Its stored TI/GPU point tables are exported spatial outputs. Neither table
% is treated as raw complex ADC/IQ, monitor telemetry or an exposure label.
assert(strcmp(fileSHA256(inputFile),'a15457f2428adf3a0f13b4952caa163040e89722510dab51fdbd2e34c5e7d16a'), ...
 'The supplied 32-record canonical paired input changed.');
L=load(inputFile);R=L.records;if ~iscell(R),R=num2cell(R);end
assert(numel(R)==32);radarTranslation=double(L.radar_translation_from_v16_m(:)');
referenceTranslation=double(L.reference_translation_from_v16_m(:)');
assert(isequal(radarTranslation,[-.13 0 -.2])&&isequal(referenceTranslation,[0 0 -.1]));
legRows=double(L.leg_joint_rows_one_based(:)');half=double(L.leg_half_widths_m(:)');
torsoRows=double(L.torso_joint_rows_one_based(:)');torsoHalf=double(L.torso_half_widths_m(:)');
assert(isequal(legRows,[19 20 21 23 24 25])&&isequal(half,[.30 .25 .38]));
assert(isequal(torsoRows,[1 2 3])&&isequal(torsoHalf,[.20 .25 .25]));
scales=[.5 .75 1 1.25 1.5];rows=zeros(numel(R),13);sourceMap=cell(numel(R),4);
for i=1:numel(R)
 r=R{i};raw=double(r.radar_raw);k=double(r.reference_keypoints_raw)+referenceTranslation;
 P=raw(:,1:3)+radarTranslation;gpu=double(r.gpu_point_table_as_stored);
 assert(size(raw,2)==5&&size(k,1)==32&&size(k,2)==3&&size(gpu,2)==4);
 assert(all(isfinite(P),'all')&&all(isfinite(k),'all')&&isreal(gpu)&&all(isfinite(gpu),'all'));
 legCentre=median(k(legRows,:),1);torsoCentre=median(k(torsoRows,:),1);counts=zeros(1,5);
 for j=1:numel(scales),counts(j)=sum(all(abs(P-legCentre)<=scales(j)*half,2));end
 torso=sum(all(abs(P-torsoCentre)<=torsoHalf,2));nearest=zeros(numel(legRows),1);
 for j=1:numel(legRows),nearest(j)=min(sqrt(sum((P-k(legRows(j),:)).^2,2)));end
 rows(i,:)=[i str2double(r.block) double(r.file_index) size(P,1) size(gpu,1) counts torso size(P,1) median(nearest)];
 sourceMap(i,:)={i,char(r.source),char(r.source_sha256),['B-' char(r.block)]};
end
assert(all(diff(rows(:,6:10),1,2)>=0,'all'));
S=struct('n_stored_records',numel(R),'total_radar_rows',sum(rows(:,4)), ...
 'radar_rows_range',[min(rows(:,4)) max(rows(:,4))],'total_GPU_table_rows',sum(rows(:,5)), ...
 'pooled_zero_counts',[sum(rows(:,8)==0) sum(rows(:,11)==0) sum(rows(:,12)==0)], ...
 'leg_zero_by_scale',sum(rows(:,6:10)==0,1),'joint_NN_median_m',median(rows(:,13)));
assert(S.total_radar_rows==1432&&isequal(S.radar_rows_range,[34 60])&&S.total_GPU_table_rows==505);
assert(isequal(S.pooled_zero_counts,[2 1 0])&&isequal(S.leg_zero_by_scale,[24 11 2 0 0]));
assert(abs(S.joint_NN_median_m-.21776643129701415)<1e-12);
blocks=unique(rows(:,2));summary=zeros(numel(blocks)+1,6);
for j=1:numel(blocks)
 m=rows(:,2)==blocks(j);summary(j,:)=[blocks(j) sum(m) sum(rows(m,4)) ...
  sum(rows(m,8)==0) sum(rows(m,11)==0) sum(rows(m,12)==0)];
end
summary(end,:)=[-1 numel(R) S.total_radar_rows S.pooled_zero_counts];
assert(isequal(summary(1:2,[1 2 4 5 6]),[0 25 2 0 0;1 7 0 1 0]));
S.source_block_summary=summary;
writeMappings(fullfile(resultDir,'iq_paired_block_labels_v21.csv'),{'archive_block','analysis_block'}, ...
 {0,'B-000';1,'B-001';-1,'B-pooled'});
S.protocol=struct('mapping','Reuses the fixed v16 coordinate translations and anatomical ROI definitions without a new alignment calibration', ...
 'statistical_unit','One stored paired record; this collection is kept separate from the original 221 records', ...
 'signal_scope','TI exported point table and an opaque-GPU-object-derived real Nx4 table; no raw ADC or native I/Q interpretation', ...
 'channel_coverage','Global IWR6843-ODS profile is author-attested (nominal 60-GHz class, configured 4000.14-MHz bandwidth,3TX/4RX,RX30dB); per-record exposure-state/distance/monitor-CQ join and calibrated ADC rails are not encoded in the archive', ...
 'preservation','Every original TI radar row and all 32 same-file Kinect joints are used; GPU-derived spatial tables remain separately identified');
writeNumeric(fullfile(resultDir,'iq_paired_spatial_records_v17.csv'), ...
 {'record_id','source_block','file_index','TI_rows','GPU_table_rows','leg_returns_050','leg_returns_075', ...
  'leg_returns_100','leg_returns_125','leg_returns_150','torso_returns','whole_cloud_returns','leg_joint_nearest_median_m'},rows);
writeNumeric(fullfile(resultDir,'iq_paired_block_summary_v17.csv'), ...
 {'source_block_minus1_is_pooled','n_stored_records','TI_rows','leg_zero','torso_zero','whole_cloud_zero'},summary);
writeMappings(fullfile(resultDir,'iq_paired_source_map_v17.csv'),{'record_id','source','source_sha256','source_block'},sourceMap);
writeJSON(fullfile(resultDir,'iq_paired_spatial_summary_v17.json'),S);
fprintf('IQ_PAIRED_V17_OK: %d stored records, %d original radar rows; zero-support leg/torso/whole = %d/%d/%d.\n', ...
 S.n_stored_records,S.total_radar_rows,S.pooled_zero_counts);
end


function regionalAxes_v17(ax)
set(ax,'FontName','Times New Roman','FontSize',10.5,'FontWeight','bold','LineWidth',.9, ...
 'Box','on','YGrid','on','XGrid','off','GridColor',[.82 .82 .82],'GridAlpha',.40, ...
 'GridLineStyle','-','TickDir','out');
end


function qwertyAxes_v15(ax)
set(ax,'FontName','Times New Roman','FontSize',9,'FontWeight','bold','LineWidth',1,'Box','on','YGrid','on','XGrid','off','GridColor',[.82 .82 .82],'GridAlpha',.28,'GridLineStyle',':');
end



function qwertyExport_v15(fig,figDir,tag)
qwertyFontNormalize_v15(fig);
% Export to the host's local temporary directory before copying complete
% bytes to the destination. A successful call can otherwise leave an empty
% file on a synchronized MATLAB Drive path.
staging=tempname;mkdir(staging);cleanup=onCleanup(@()rmdir(staging,'s')); %#ok<NASGU>
drawnow;
for format={'pdf','svg'}
 ext=format{1};localFile=fullfile(staging,[tag '.' ext]);
 try
  exportgraphics(fig,localFile,'ContentType','vector','BackgroundColor','white');
 catch exportError
  fprintf('QWERTY_EXPORT_FALLBACK: %s, %s\n',ext,exportError.identifier);
 end
 if ~qwerty_valid_artifact_v15(localFile,ext)
  if exist(localFile,'file')==2,delete(localFile);end
  set(fig,'Units','centimeters');position=get(fig,'Position');
  set(fig,'PaperUnits','centimeters','PaperPosition',[0 0 position(3:4)],'PaperSize',position(3:4));
  print(fig,localFile,['-d' ext],'-painters');
 end
 assert(qwerty_valid_artifact_v15(localFile,ext),'Local %s export is empty or invalid: %s',ext,tag);
 destination=fullfile(figDir,[tag '.' ext]);[ok,message]=copyfile(localFile,destination,'f');
 assert(ok,'Cannot copy completed %s export: %s',ext,message);
 assert(qwerty_valid_artifact_v15(destination,ext),'Copied %s export is empty or invalid: %s',ext,tag);
end
localFigure=fullfile(staging,[tag '.fig']);savefig(fig,localFigure);
recordNativeFonts_v17(fig,localFigure);
info=dir(localFigure);assert(~isempty(info)&&info.bytes>1000,'Local native FIG is empty.');
[ok,message]=copyfile(localFigure,fullfile(figDir,[tag '.fig']),'f');assert(ok,'Cannot copy native FIG: %s',message);
close(fig);
end



function valid=qwerty_valid_artifact_v15(path,format)
info=dir(path);valid=~isempty(info)&&info.bytes>1000;if ~valid,return;end
fid=fopen(path,'rb');if fid<0,valid=false;return;end
bytes=fread(fid,8192,'*uint8');fclose(fid);header=char(bytes(:)');
if strcmp(format,'pdf'),valid=startsWith(header,'%PDF-');
elseif strcmp(format,'svg'),valid=contains(header,'<svg');
else,valid=false;end
end



function audit=native_figure_audit_v15(figDir,resultDir)
% Inspect plain save-time font evidence without opening/deserializing the
% graphics object tree. Modern FIG files contain opaque MCOS objects, whose
% reconstruction can initialize an unavailable MATLAB Online renderer.
figures=dir(fullfile(figDir,'*.fig'));assert(~isempty(figures),'No native figures exported.');
rows=cell(numel(figures),6);
for k=1:numel(figures)
 path=fullfile(figDir,figures(k).name);
 fid=fopen(path,'rb');assert(fid>=0,'Cannot read native FIG header.');
 header=char(fread(fid,128,'*uint8')');fclose(fid);
 assert(startsWith(header,'MATLAB'),'Native FIG does not have a MATLAB MAT-file header: %s',figures(k).name);
 % Select only the appended plain struct; never load hgM_080000 or restore
 % the contained matlab.graphics.internal.figfile.GraphicsObjects object.
 stored=load(path,'-mat','PhantomRadarFontAudit_v17');
 assert(isfield(stored,'PhantomRadarFontAudit_v17'),'Save-time font evidence missing: %s',figures(k).name);
 saved=stored.PhantomRadarFontAudit_v17;
 assert(strcmp(saved.capture_scope,'FontName properties read from the live figure alongside native save; no graphics objects reopened'));
 names=serializedFontNames_v17(saved.objects);
 assert(~isempty(names)&&numel(names)==saved.n_font_objects,'Font evidence inventory differs: %s',figures(k).name);
 assert(all(strcmp(names,'Times New Roman')),'Save-time native figure fonts differ from Times New Roman: %s',figures(k).name);
 [~,name]=fileparts(figures(k).name);svgPath=fullfile(figDir,[name '.svg']);pdfPath=fullfile(figDir,[name '.pdf']);
 assert(qwerty_valid_artifact_v15(pdfPath,'pdf'),'PDF is empty or has invalid magic: %s',name);
 assert(qwerty_valid_artifact_v15(svgPath,'svg'),'SVG is empty or has invalid header: %s',name);
 svg=dir(svgPath);pdf=dir(pdfPath);
 rows(k,:)={name,numel(names),'Times New Roman',svg.bytes,pdf.bytes, ...
  'Plain save-time FontName snapshots and nonempty MAT/PDF/SVG headers verified; no graphics restoration or PDF font-embedding check'};
end
writeMappings(fullfile(resultDir,'native_figure_font_properties_v17.csv'), ...
 {'figure_name','n_font_objects','requested_font','svg_bytes','pdf_bytes','scope'},rows);
audit=struct('n_native_figures',numel(figures),'every_pdf_svg_bytes_gt1000',true, ...
 'every_pdf_magic_verified',true,'every_svg_header_verified',true, ...
 'every_native_MAT_header_verified',true,'font_name_properties','Times New Roman', ...
 'font_property_scope','Save-time live-figure FontName snapshots stored as a plain struct in each native FIG', ...
 'font_snapshot_variable','PhantomRadarFontAudit_v17','graphics_objects_reopened',false, ...
 'serialized_MCOS_restoration_checked',false,'PDF_font_embedding_checked',false);
end


function recordNativeFonts_v17(fig,path)
% Append a plain metadata variable to the native MAT container. openfig can
% still use its normal HG variables; this evidence can be loaded selectively
% without constructing or attaching any serialized graphics objects.
objects=findall(fig,'-property','FontName');
records=repmat(struct('Type','','FontName',''),numel(objects),1);
for j=1:numel(objects)
 records(j).Type=char(get(objects(j),'Type'));
 records(j).FontName=char(get(objects(j),'FontName'));
end
PhantomRadarFontAudit_v17=struct( ...
 'capture_scope','FontName properties read from the live figure alongside native save; no graphics objects reopened', ...
 'n_font_objects',numel(objects),'objects',records);
assert(numel(objects)>0&&all(strcmp({records.FontName},'Times New Roman')), ...
 'A live native figure font differs from Times New Roman before close.');
save(path,'PhantomRadarFontAudit_v17','-append');
end


function names=serializedFontNames_v17(value)
% Recurse through plain HG-style structs/cells only; never inspect an object.
names={};
if isstruct(value)
 fields=fieldnames(value);
 for row=1:numel(value)
  for field=1:numel(fields)
   v=value(row).(fields{field});
   if strcmp(fields{field},'FontName')
    assert(ischar(v)||isstring(v),'Serialized FontName must be text.');
    names{end+1}=char(v); %#ok<AGROW>
   elseif isstruct(v)||iscell(v)
    names=[names serializedFontNames_v17(v)]; %#ok<AGROW>
   end
  end
 end
elseif iscell(value)
 for row=1:numel(value),names=[names serializedFontNames_v17(value{row})];end %#ok<AGROW>
end
end


function qwertyFontNormalize_v15(fig)
% Normalize all existing text-bearing objects before saving/exporting. Root
% defaults alone do not cover every legend, ruler, or annotation object.
objects=findall(fig,'-property','FontName');
for k=1:numel(objects),set(objects(k),'FontName','Times New Roman');end
legends=findall(fig,'Type','legend');
for k=1:numel(legends),set(legends(k),'FontSize',max(8.5,get(legends(k),'FontSize')));end
objects=findall(fig,'-property','FontName');
for k=1:numel(objects),assert(strcmp(get(objects(k),'FontName'),'Times New Roman'),'Qwerty figure font normalization failed.');end
end



function hash=qwertyFileSHA_v15(path)
fid=fopen(path,'rb');assert(fid~=-1,'Cannot read canonical input');c=onCleanup(@()fclose(fid));
bytes=fread(fid,Inf,'*uint8');md=java.security.MessageDigest.getInstance('SHA-256');md.update(typecast(bytes,'int8'));
hash=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end


function [S,tests]=analytical_feasibility_v21(figDir,resultDir,outDir)
% Conditional link budgets, not empirical attack-success observations.
% PO formulas: A.W. Doerry, SAND2014-0882, pp. 9/11, OSTI1204079.
% TI IWR6843 Rev.F Fig.7-2 gives approximate input-P1dB thresholds.
% Eravant SBP-5037533020-1515-E1: nominal30dB gain,+20dBmP1dB,
% 50--75GHz. SAR-2507-15-S2 horns: nominal25dBi,50--75GHz.
% Isolation40/60dB and margin6dB are declared analytical assumptions.
P=struct('evidence_class','Analytical parameterization using catalog specifications; not a hardware attack measurement', ...
 'c_m_s',299792458,'frequency_hz',62e9,'nominal_radar_tx_dbm',12, ...
 'linear_tx_power_fraction',.9,'victim_tx_gain_dbi_assumed',10, ...
 'victim_rx_gain_dbi_assumed',10,'additional_loss_db_assumed',0, ...
 'rx_gain_db',[30 40 48],'input_compression_dbm_graph_read',[-24 -34 -42], ...
 'graph_read_precision_db_approx',.5,'amplifier_model','Eravant SBP-5037533020-1515-E1', ...
 'stage_gain_db_typical',30,'output_p1db_dbm_nominal',20, ...
 'horn_model','Eravant SAR-2507-15-S2','horn_gain_dbi_nominal',25, ...
 'component_frequency_band_hz',[50e9 75e9],'stability_margin_db_assumed',6, ...
 'horn_outer_dimensions_m',[.040132 .032512], ...
 'image_plane_scope','Infinite perfectly conducting flat plane, normal incidence, co-polarized image-source Friis reference; not a universal passive bound or ADC-first test');
P.lambda_m=P.c_m_s/P.frequency_hz;
P.radar_tx_dbm=P.nominal_radar_tx_dbm+10*log10(P.linear_tx_power_fraction);
P.radar_tx_w=P.linear_tx_power_fraction*10^((P.nominal_radar_tx_dbm-30)/10);
P.horn_aperture_far_field_lower_bound_m=2*sum(P.horn_outer_dimensions_m.^2)/P.lambda_m;
P.geometry_names={'triangular_trihedral','square_trihedral','normal_incidence_circular_plate'};
P.geometry_coefficients=[pi/12 pi/3 pi^3/16];
P.source_urls={'https://www.osti.gov/servlets/purl/1204079', ...
 'https://www.ti.com/lit/ds/symlink/iwr6843.pdf', ...
 'https://sftp.eravant.com/content/datasheets/SBP-5037533020-1515-E1.pdf', ...
 'https://sftp.eravant.com/content/datasheets/SAR-2507-15-S2.pdf', ...
 'https://web.mit.edu/6.013_book/www/chapter12/12.7.html', ...
 'https://web.mit.edu/6.101/www/s2020/handouts/L09.pdf'};
reqK=10.^((P.input_compression_dbm_graph_read-30)/10)*(4*pi)^3/ ...
 (P.radar_tx_w*10^((P.victim_tx_gain_dbi_assumed+P.victim_rx_gain_dbi_assumed)/10)*P.lambda_m^2);
crossings=sqrt(P.geometry_coefficients(:)./reqK(:)');
crossRows=zeros(9,5);row=0;
for gi=1:3,for geometry=1:3
 row=row+1;crossRows(row,:)=[P.rx_gain_db(gi) geometry P.geometry_coefficients(geometry) ...
  10*log10(reqK(gi)) crossings(geometry,gi)];
end;end
writeNumeric(fullfile(resultDir,'passive_crossings_v21.csv'), ...
 {'victim_rx_gain_db','geometry_id','PO_envelope_coefficient','required_rcs_intercept_dbsm','formal_intersection_m'},crossRows);
writeMappings(fullfile(resultDir,'passive_geometry_map_v21.csv'),{'geometry_id','geometry'}, ...
 [num2cell((1:3)') P.geometry_names(:)]);
R=logspace(log10(.03),log10(15),300)';
passiveMax=R.^2*P.geometry_coefficients;required=R.^4*reqK;
% The infinite-plane image is a separate, conditional specular reference.
% Its range-dependent equivalent RCS is not a fourth finite-target PO bound.
imageEquivalentRCS=pi*R.^2;
imagePowerDbm=P.radar_tx_dbm+P.victim_tx_gain_dbi_assumed+P.victim_rx_gain_dbi_assumed+ ...
 20*log10(P.lambda_m./(8*pi*R));
imageCrossings=P.lambda_m/(8*pi)*10.^((P.radar_tx_dbm+ ...
 P.victim_tx_gain_dbi_assumed+P.victim_rx_gain_dbi_assumed-P.input_compression_dbm_graph_read)/20);
writeNumeric(fullfile(resultDir,'image_plane_reference_v21.csv'), ...
 {'range_m','equivalent_rcs_dbsm','image_return_dbm','model_scope_id'}, ...
 [R 10*log10(imageEquivalentRCS) imagePowerDbm ones(size(R))]);
writeNumeric(fullfile(resultDir,'image_plane_crossings_v21.csv'), ...
 {'victim_rx_gain_db','input_receiver_compression_dbm','formal_intersection_m','model_scope_id'}, ...
 [P.rx_gain_db(:) P.input_compression_dbm_graph_read(:) imageCrossings(:) ones(3,1)]);
writeMappings(fullfile(resultDir,'image_plane_scope_v21.csv'),{'model_scope_id','scope'}, ...
 {1,P.image_plane_scope});
writeNumeric(fullfile(resultDir,'passive_distance_curves_v21.csv'), ...
 {'range_m','triangular_max_dbsm','square_max_dbsm','circular_plate_max_dbsm', ...
 'required_rx30_dbsm','required_rx40_dbsm','required_rx48_dbsm'}, ...
 [R 10*log10(passiveMax) 10*log10(required)]);
colors=[55 103 149;114 188 213;255 208 111;231 98 84]/255;
fig=figure('Color','w','Visible','off','Units','centimeters','Position',[2 2 8.509 5.715], ...
 'PaperUnits','centimeters','PaperPosition',[0 0 8.509 5.715],'PaperSize',[8.509 5.715]);
ax=axes('Parent',fig,'Position',[.18 .205 .79 .535]);hold(ax,'on');analyticalAxes_v21(ax);
h=gobjects(7,1);marks={'^','s','o'};imageColor=[30 70 110]/255;
for geometry=1:3
 h(geometry)=plot(ax,R,10*log10(passiveMax(:,geometry)), ...
  'Color',colors(geometry,:),'LineWidth',1.8);
end
h(4)=plot(ax,R,10*log10(imageEquivalentRCS),'Color',imageColor,'LineWidth',1.8);
styles={':','--','-'};
for gi=1:3
 h(4+gi)=plot(ax,R,10*log10(required(:,gi)),'Color',colors(4,:), ...
  'LineStyle',styles{gi},'LineWidth',1.5);
end
% Only RX48 intersections are marked. Lower-gain values remain in the
% numerical exports; fewer markers prevent a crowded analytic display.
gi=3;
for geometry=1:3
 x=crossings(geometry,gi);y=10*log10(P.geometry_coefficients(geometry)*x^2);
 plot(ax,x,y,'LineStyle','none','Marker',marks{geometry},'MarkerSize',4.2, ...
  'Color',colors(geometry,:),'MarkerFaceColor',colors(geometry,:),'LineWidth',.8,'HandleVisibility','off');
end
x=imageCrossings(gi);y=10*log10(pi*x^2);
plot(ax,x,y,'LineStyle','none','Marker','d','MarkerSize',4.2, ...
 'Color',imageColor,'MarkerFaceColor',imageColor,'LineWidth',.8,'HandleVisibility','off');
% Linear distance exposes the closed-form curvature without changing any
% physical value. Analytic power-law curves receive no random perturbation.
set(ax,'XScale','linear','XTick',[.1 .5 1 2 3],'XTickLabel',{'0.1','0.5','1','2','3'}, ...
 'YTick',[-30 -15 0 15 30 45]);xlim(ax,[.1 3]);ylim(ax,[-38 48]);
xlabel(ax,'Reflector distance (m)','FontSize',10.5);ylabel(ax,'RCS (dBsm)','FontSize',10.5);
leg=legend(ax,h,{'Tri. PO','Square PO','Plate PO','Plane ref.','RX 30 dB','RX 40 dB','RX 48 dB'}, ...
 'Orientation','horizontal','NumColumns',4,'Box','on','FontName','Times New Roman', ...
 'FontSize',9.2,'FontWeight','bold','Interpreter','none');
if isprop(leg,'ItemTokenSize'),set(leg,'ItemTokenSize',[14 8]);end
set(leg,'Units','normalized','Position',[.035 .785 .94 .19]);
set(ax,'Position',[.18 .205 .79 .535]);
qwertyExport_v15(fig,figDir,'figure_feasibility_passive_v21');

% A direct in-band source uses the same final-hop transfer as AF output.
% Its required conducted power and EIRP contain no amplifier/isolation term.
% These are conditional link budgets, not measured injection powers.
directRanges=[1.2 2 3 5 10];directRows=zeros(15,10);drow=0;
for ri=1:numel(directRanges),for gi=1:3
 fspl=20*log10(4*pi*directRanges(ri)/P.lambda_m);
 beta=P.horn_gain_dbi_nominal+P.victim_rx_gain_dbi_assumed-fspl-P.additional_loss_db_assumed;
 pa=P.input_compression_dbm_graph_read(gi)-beta;eirp=pa+P.horn_gain_dbi_nominal;
 drow=drow+1;directRows(drow,:)=[directRanges(ri) P.rx_gain_db(gi) ...
  P.horn_gain_dbi_nominal P.victim_rx_gain_dbi_assumed fspl beta pa eirp 10^(pa/10) 10^(eirp/10)];
end;end
writeNumeric(fullfile(resultDir,'direct_source_reference_v21.csv'), ...
 {'range_m','victim_rx_gain_db','source_antenna_gain_dbi','victim_antenna_gain_dbi', ...
 'free_space_path_loss_db','final_hop_transfer_db','required_source_Pa_dbm', ...
 'required_source_EIRP_dbm','required_source_Pa_mW','required_source_EIRP_mW'},directRows);
P.direct_source_scope='Conditional in-band source last-hop link budget; band overlap alone does not establish IF coupling, saturation, target loss or coherent target injection';
% Antenna sensitivity reuses the declared Friis transfer, not new RF trials.
sensitivityRows=zeros(18,8);drow=0;referenceRange=3;
for victimAntenna=[5 10],for sourceAntenna=[15 20 25],for gi=1:3
 fspl=20*log10(4*pi*referenceRange/P.lambda_m);
 beta=sourceAntenna+victimAntenna-fspl-P.additional_loss_db_assumed;
 pa=P.input_compression_dbm_graph_read(gi)-beta;
 drow=drow+1;sensitivityRows(drow,:)=[referenceRange P.rx_gain_db(gi) ...
  victimAntenna sourceAntenna beta pa pa+sourceAntenna 10^(pa/10)];
end;end;end
writeNumeric(fullfile(resultDir,'direct_source_antenna_sensitivity_v21.csv'), ...
 {'range_m','victim_rx_gain_db','victim_antenna_gain_dbi','source_antenna_gain_dbi', ...
 'final_hop_transfer_db','required_source_Pa_dbm','required_source_EIRP_dbm','required_source_Pa_mW'},sensitivityRows);

[antennaSensitivity,antennaTests]=ods_antenna_sensitivity_v21(P,resultDir);

% Nominal one-stage and conditional two-stage chains, including output and
% stability caps. Hardware gain is not treated as measured stable gain.
config=[1 40;2 40;2 60];sampleRanges=[1.2 2 3 5 10];activeRows=zeros(45,18);row=0;
for ri=1:numel(sampleRanges),for gi=1:3,for ci=1:size(config,1)
 [pin,beta,greq,gbar,hmax]=activeBudget_v21(sampleRanges(ri),config(ci,2),config(ci,1),gi,P);
 row=row+1;activeRows(row,:)=[sampleRanges(ri) P.rx_gain_db(gi) P.input_compression_dbm_graph_read(gi) ...
  config(ci,1) P.stage_gain_db_typical*config(ci,1) config(ci,2) P.stability_margin_db_assumed ...
  pin beta greq P.input_compression_dbm_graph_read(gi)-beta ...
  P.stage_gain_db_typical*config(ci,1) config(ci,2)-P.stability_margin_db_assumed ...
  P.output_p1db_dbm_nominal-pin gbar hmax greq+P.stability_margin_db_assumed double(hmax>=0)];
end;end;end
writeNumeric(fullfile(resultDir,'active_component_reference_v21.csv'), ...
 {'range_each_hop_m','victim_rx_gain_db','victim_compression_dbm','nominal_stages', ...
 'nominal_device_gain_db','assumed_isolation_db','assumed_margin_db','amplifier_input_dbm', ...
 'final_hop_transfer_db','required_gain_db','required_output_dbm','gain_cap_device_db', ...
 'gain_cap_stability_db','gain_cap_output_db','available_gain_db','Hmax_db', ...
 'minimum_isolation_to_cross_db','model_boundary_reachable'},activeRows);
rangeLimits=zeros(9,8);row=0;
for ci=1:size(config,1),for gi=1:3
 [~,beta1,greq1]=activeBudget_v21(1,config(ci,2),config(ci,1),gi,P);
 gFixed=min(P.stage_gain_db_typical*config(ci,1),config(ci,2)-P.stability_margin_db_assumed);
 gainRange=10^((gFixed-greq1)/40);
 outputAt1=P.input_compression_dbm_graph_read(gi)-beta1;
 outputRange=10^((P.output_p1db_dbm_nominal-outputAt1)/20);
 row=row+1;rangeLimits(row,:)=[config(ci,:) P.stability_margin_db_assumed P.rx_gain_db(gi) ...
  gainRange outputRange min(gainRange,outputRange) P.horn_aperture_far_field_lower_bound_m];
end;end
writeNumeric(fullfile(resultDir,'active_range_limits_v21.csv'), ...
 {'nominal_stages','assumed_isolation_db','assumed_margin_db','victim_rx_gain_db', ...
 'gain_and_isolation_limited_range_m','output_limited_range_m','modeled_upper_range_m', ...
 'horn_aperture_far_field_lower_bound_m'},rangeLimits);
% Equal-hop range is restricted to >=1.2m, beyond the horn-aperture
% Fraunhofer estimate (1.103m); victim-board aperture is a separate input.
rangeGrid=logspace(log10(1.2),log10(15),160);isoGrid=linspace(20,80,121);
[RR,II]=meshgrid(rangeGrid,isoGrid);HM=nan([size(RR) 3]);mapRows=zeros(numel(RR),5);
for gi=1:3
 [~,~,~,~,HM(:,:,gi)]=activeBudget_v21(RR,II,2,gi,P);
end
mapRows(:,:)=[RR(:) II(:) reshape(HM(:,:,1),[],1) reshape(HM(:,:,2),[],1) reshape(HM(:,:,3),[],1)];
writeNumeric(fullfile(resultDir,'active_feasibility_map_v21.csv'), ...
 {'range_each_hop_m','assumed_isolation_db','Hmax_rx30_db','Hmax_rx40_db','Hmax_rx48_db'},mapRows);
fig=figure('Color','w','Visible','off','Units','centimeters','Position',[2 2 8.509 5.715], ...
 'PaperUnits','centimeters','PaperPosition',[0 0 8.509 5.715],'PaperSize',[8.509 5.715]);
ax=axes('Parent',fig,'Position',[.17 .205 .645 .535]);hold(ax,'on');analyticalAxes_v21(ax);
displayH=max(-30,min(30,HM(:,:,3)));contourf(ax,RR,II,displayH,-30:2:30,'LineStyle','none');
mapColors=[30 70 110;55 103 149;114 188 213;255 230 183;255 208 111;231 98 84]/255;
colormap(ax,interp1(linspace(0,1,size(mapColors,1)),mapColors,linspace(0,1,128)));
clim(ax,[-30 30]);
ch=gobjects(4,1);contourStyles={':','--','-'};
for gi=1:3
 [~,ch(gi)]=contour(ax,RR,II,HM(:,:,gi),[0 0],'LineColor',[.12 .12 .12], ...
  'LineStyle',contourStyles{gi},'LineWidth',1.65);
end
oneRange=rangeLimits(rangeLimits(:,1)==1 & rangeLimits(:,2)==40 & rangeLimits(:,4)==48,7);
assert(isscalar(oneRange));
ch(4)=plot(ax,[oneRange oneRange],[20 80],'Color',[.32 .32 .32],'LineWidth',1.05,'LineStyle','-.');
set(ax,'XScale','log','XTick',[1.2 2 3 5 10 15],'XTickLabel',{'1.2','2','3','5','10','15'},'YTick',[20 40 60 80]);
xlim(ax,[1.2 15]);ylim(ax,[20 80]);
xlabel(ax,'Equal-hop distance (m)','FontSize',10.5);ylabel(ax,'Isolation I (dB)','FontSize',10.5);
leg=legend(ax,ch,{'RX 30 dB','RX 40 dB','RX 48 dB','1 stage, RX 48 dB'}, ...
 'Orientation','horizontal','NumColumns',2,'Box','on','FontName','Times New Roman', ...
 'FontSize',9.2,'FontWeight','bold','Interpreter','none');
set(leg,'Units','normalized','Position',[.04 .785 .92 .19]);
cb=colorbar(ax,'Position',[.848 .205 .035 .535]);
set(cb,'FontName','Times New Roman','FontSize',9.2,'FontWeight','bold','Ticks',[-30 -15 0 15 30]);
ylabel(cb,'Hmax at RX 48 dB (dB)','FontName','Times New Roman','FontSize',9.5,'FontWeight','bold');
set(ax,'Position',[.17 .205 .645 .535]);
qwertyExport_v15(fig,figDir,'figure_feasibility_active_v21');

% Independently check formulas, units, equivalent linear/dB budgets and
% competing caps. These checks do not manufacture experimental outcomes.
names={'linear_90_percent_power_conversion','three_PO_Fraunhofer_geometry_eliminations', ...
 'all_nine_passive_intersections_close','gain_threshold_shifts_preserved', ...
 'active_dB_and_linear_Friis_agree','component_stability_and_output_caps', ...
 'one_stage_3m_shortfall_and_two_stage_3m_headroom','equal_hop_range_limit_closure', ...
 'active_map_excludes_horn_near_field', ...
 'image_reference_equals_independent_two_R_Friis', ...
 'image_reference_crossings_close_receiver_thresholds', ...
 'direct_source_dB_and_linear_Friis_close_receiver_thresholds', ...
 'direct_source_equals_AF_final_hop_output_without_gain_or_isolation'};
ok=false(size(names));
ok(1)=abs(P.radar_tx_dbm-(12+10*log10(.9)))<1e-12 && abs(P.radar_tx_w*1000-14.264038732150023)<1e-12;
testR=3;triA=sqrt(testR*P.lambda_m/4);sqA=sqrt(testR*P.lambda_m/6);plateD=sqrt(testR*P.lambda_m/2);
derived=[4*pi*triA^4/(3*P.lambda_m^2),12*pi*sqA^4/P.lambda_m^2,pi^3*plateD^4/(4*P.lambda_m^2)];
ok(2)=max(abs(derived-P.geometry_coefficients*testR^2))<1e-12;
left=crossings.^4.*reqK;right=crossings.^2.*P.geometry_coefficients(:);
ok(3)=max(abs(left(:)-right(:)))<1e-12;
ok(4)=abs(10*log10(reqK(1)/reqK(3))-18)<1e-12 && abs(10*log10(reqK(2)/reqK(3))-8)<1e-12;
[pin,beta,greq,gbar,hmax]=activeBudget_v21(3,60,2,3,P);
alpha=10^((P.victim_tx_gain_dbi_assumed+P.horn_gain_dbi_nominal)/10)*(P.lambda_m/(4*pi*3))^2;
betaLinear=10^((P.horn_gain_dbi_nominal+P.victim_rx_gain_dbi_assumed)/10)*(P.lambda_m/(4*pi*3))^2;
greqLinear=10^((P.input_compression_dbm_graph_read(3)-30)/10)/(P.radar_tx_w*alpha*betaLinear);
ok(5)=abs(greq-10*log10(greqLinear))<1e-11 && abs(pin-(10*log10(P.radar_tx_w*alpha)+30))<1e-11 && abs(beta-10*log10(betaLinear))<1e-11;
ok(6)=gbar<=60 && gbar<=60-P.stability_margin_db_assumed && pin+gbar<=P.output_p1db_dbm_nominal+1e-12;
[~,~,~,~,singleH]=activeBudget_v21(3,40,1,3,P);
ok(7)=abs(singleH+2.1336591180901507)<1e-9 && abs(hmax-19.1619578937583)<1e-9;
closures=zeros(size(rangeLimits,1),1);
for j=1:size(rangeLimits,1)
 gi=find(P.rx_gain_db==rangeLimits(j,4));
 [~,~,~,~,closures(j)]=activeBudget_v21(rangeLimits(j,7),rangeLimits(j,2),rangeLimits(j,1),gi,P);
end
ok(8)=max(abs(closures))<1e-9;
ok(9)=min(rangeGrid)>P.horn_aperture_far_field_lower_bound_m;
imageViaRadar=P.radar_tx_w*10^((P.victim_tx_gain_dbi_assumed+P.victim_rx_gain_dbi_assumed)/10)* ...
 P.lambda_m^2.*imageEquivalentRCS./((4*pi)^3*R.^4);
imageViaTwoRFriis=P.radar_tx_w*10^((P.victim_tx_gain_dbi_assumed+P.victim_rx_gain_dbi_assumed)/10)* ...
 (P.lambda_m./(4*pi*(2*R))).^2;
ok(10)=max(abs(10*log10(imageViaRadar./imageViaTwoRFriis)))<1e-11 && ...
 max(abs(imagePowerDbm-(10*log10(imageViaTwoRFriis)+30)))<1e-11;
imageAtCross=P.radar_tx_dbm+P.victim_tx_gain_dbi_assumed+P.victim_rx_gain_dbi_assumed+ ...
 20*log10(P.lambda_m./(8*pi*imageCrossings));
ok(11)=max(abs(imageAtCross-P.input_compression_dbm_graph_read))<1e-11 && ...
 max(abs(imageCrossings-[.115162320821790 .364175234427891 .914766830051240]))<1e-12;
% Independent linear-watt Friis closure for every exported direct-source row.
receivedW=directRows(:,9)/1000.*10.^((directRows(:,3)+directRows(:,4))/10).* ...
 (P.lambda_m./(4*pi*directRows(:,1))).^2.*10^(-P.additional_loss_db_assumed/10);
expectedDbm=interp1(P.rx_gain_db,P.input_compression_dbm_graph_read,directRows(:,2));
ok(12)=max(abs(10*log10(receivedW)+30-expectedDbm))<1e-11;
outputEquality=zeros(size(activeRows,1),1);
for k=1:size(activeRows,1)
 dr=directRows(directRows(:,1)==activeRows(k,1)&directRows(:,2)==activeRows(k,2),:);
 outputEquality(k)=dr(7)-activeRows(k,11);
end
ok(13)=max(abs(outputEquality))<1e-11 && ...
 abs((P.horn_gain_dbi_nominal+P.victim_rx_gain_dbi_assumed-20*log10(4*pi*3/P.lambda_m))+42.8380421062417)<1e-9;
tests=[struct('name',names,'passed',num2cell(ok)) antennaTests];assert(all([tests.passed]),'Analytical feasibility validation failed.');
S=struct('parameters',P,'required_rcs_intercept_dbsm',10*log10(reqK), ...
 'formal_crossings_m_by_geometry_then_gain',crossings, ...
 'image_plane_formal_crossings_m_by_gain',imageCrossings, ...
 'image_plane_scope',P.image_plane_scope,'active_at_3m',activeRows(activeRows(:,1)==3,:), ...
 'ODS_antenna_gain_sensitivity',antennaSensitivity,'active_range_limits',rangeLimits,'direct_source_at_3m',directRows(directRows(:,1)==3,:), ...
 'direct_source_antenna_sensitivity_at_3m',sensitivityRows,'direct_source_scope',P.direct_source_scope,'passive_scope','Ideal PEC PO peak envelopes under a Fraunhofer constraint; algebraic intersections are not validated attack distances', ...
 'active_scope','Catalog component budget; isolation, alignment, cascade gain control, bandwidth and victim geometry require independent validation');
writeJSON(fullfile(resultDir,'analytical_feasibility_summary_v21.json'),S);
writeJSON(fullfile(resultDir,'analytical_feasibility_tests_v21.json'),tests);
newFigures={'figure_feasibility_passive_v21','figure_feasibility_active_v21'};
transport=struct('figure',{},'bytes',{},'sha256',{},'text_transport_file',{});
for j=1:numel(newFigures)
 source=fullfile(figDir,[newFigures{j} '.svg']);text=fileread(source);a=dir(source);
 target=fullfile(outDir,['transport_' newFigures{j} '.txt']);
writeTextTransport_v21(target,text);
 transport(j)=struct('figure',newFigures{j},'bytes',a.bytes,'sha256',fileSHA256(source), ...
  'text_transport_file',target);
end
writeJSON(fullfile(outDir,'analytical_svg_manifest_v21.json'),transport);
fprintf('PHANTOMRADAR_V21_ANALYTICAL_DONE: %d validated analytical checks, two native figures.\n',numel(tests));
end

function [pin,beta,greq,gbar,hmax]=activeBudget_v21(R,I,nStages,gi,P)
fspl=20*log10(4*pi*R/P.lambda_m);
pin=P.radar_tx_dbm+P.victim_tx_gain_dbi_assumed+P.horn_gain_dbi_nominal-fspl;
beta=P.horn_gain_dbi_nominal+P.victim_rx_gain_dbi_assumed-fspl;
greq=P.input_compression_dbm_graph_read(gi)-pin-beta;
gbar=min(min(P.stage_gain_db_typical*nStages+zeros(size(R)),I-P.stability_margin_db_assumed), ...
 P.output_p1db_dbm_nominal-pin);
hmax=gbar-greq;
end

function analyticalAxes_v21(ax)
set(ax,'FontName','Times New Roman','FontSize',10,'FontWeight','bold','LineWidth',.9, ...
 'Box','on','XGrid','on','YGrid','on','GridColor',[.82 .82 .82],'GridAlpha',.32, ...
 'GridLineStyle',':','TickDir','out','XMinorGrid','off','YMinorGrid','off', ...
 'TickLabelInterpreter','none');
end

function writeTextTransport_v21(path,value)
% SVG is already text. JSON string lines retain its exact Unicode text;
% no binary file is encoded. Modest lines fit ordinary text-editor views.
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
for first=1:40000:numel(value)
 last=min(numel(value),first+39999);fprintf(fid,'%s\n',jsonencode(value(first:last)));
end
end

function [B,tests]=bag_record_association_v21(path,resultDir)
% Actual recorded bytes only; bag time is receipt time, not exposure sync.
L=load(path);n=numel(L.raw_payloads);assert(n==28&&numel(L.radar_points)==108&&numel(L.body_joints)==185);
rt=L.raw_time_ns(:);pt=L.radar_time_ns(:);bt=L.body_time_ns(:);
assert(isa(rt,'int64')&&isa(pt,'int64')&&isa(bt,'int64'));
names={'raw_index_1based','radar_index_1based','nearest_radar_lag_ms','ordinal_radar_lag_ms','body_index_1based','nearest_body_lag_ms','stored_min','stored_max','int16_endpoints','component_rms','complex_abs_p99','fast_sample_phase_coherence','range_spectral_flatness','n_signed_words','n_complex_samples','n_chirps_from_payload'};
M=zeros(n,numel(names));wnd=.5-.5*cos(2*pi*(0:255)'/255);
for k=1:n
 raw=uint8(L.raw_payloads{k}(:));assert(numel(raw)==1376256);
 w=typecast(raw,'int16');[~,~,endian]=computer;if endian=='B',w=swapbytes(w);end
 q=reshape(double(w),4,[]);z=complex(zeros(numel(w)/2,1));
 z(1:2:end)=complex(q(1,:),q(3,:));z(2:2:end)=complex(q(2,:),q(4,:));
 x=reshape(z,256,4,[]);amp=sort(abs(x(:)));loc=1+.99*(numel(amp)-1);lo=floor(loc);hi=ceil(loc);p99=amp(lo)+(loc-lo)*(amp(hi)-amp(lo));
 cross=x(2:end,:,:).*conj(x(1:end-1,:,:));cross=cross(abs(cross)>0);coherence=abs(mean(exp(1i*angle(cross))));
 spec=abs(fft(x.*wnd,[],1)).^2;s=mean(mean(spec,3),2);s=s/max(sum(s),realmin);flatness=exp(mean(log(max(s,realmin))))/mean(s);
 [lag,ri]=min(abs(pt-rt(k)));[blag,bi]=min(abs(bt-rt(k)));
 M(k,:)=[k ri double(lag)/1e6 double(abs(pt(k)-rt(k)))/1e6 bi double(blag)/1e6 double(min(w)) double(max(w)) sum(w==-32768|w==32767) sqrt(mean(double(w).^2)) p99 coherence flatness numel(w) numel(x) size(x,3)];
end
counts=cellfun(@(x)size(x,1),L.radar_points);
B=struct('input_sha256',fileSHA256(path),'bag_sha256',char(L.raw_source_sha256),...
 'raw_packets',n,'radar_clouds',numel(counts),'body_arrays',numel(L.body_joints),'radar_points_total',sum(counts),...
 'radar_points_min',min(counts),'radar_points_median',median(counts),'radar_points_max',max(counts),...
 'raw_words_total',sum(M(:,14)),'complex_samples_total',sum(M(:,15)),...
 'code_min',min(M(:,7)),'code_max',max(M(:,8)),'int16_endpoint_count',sum(M(:,9)),...
 'nearest_radar_lag_median_ms',median(M(:,3)),'nearest_radar_lag_max_ms',max(M(:,3)),...
 'nearest_radar_within50ms',sum(M(:,3)<=50),'nearest_radar_within100ms',sum(M(:,3)<=100),...
 'ordinal_lag_median_ms',median(M(:,4)),'ordinal_lag_max_ms',max(M(:,4)),...
 'nearest_body_lag_median_ms',median(M(:,6)),'nearest_body_lag_max_ms',max(M(:,6)),...
 'decoder','Little-endian int16, 2I followed by 2Q, four RX, 256 fast samples, 336 chirps per payload; TX order and RF profile not assigned',...
 'phase_metric','Magnitude of mean unit phasor of adjacent fast-sample products; zero products excluded',...
 'flatness_metric','Hann256 fast FFT power averaged across receivers/chirps, normalized to unit sum; geometric mean divided by arithmetic mean',...
 'scope','Recording-time association, not calibrated exposure synchronization. Integer-container endpoints are not calibrated ADC rails. No receiver gain, reflector distance, exposure switch or CQ alarm labels are inferred.',...
 'mapping_status',char(L.mapping_status));
writeNumeric(fullfile(resultDir,'native_bag_packet_metrics_v21.csv'),names,M);
writeJSON(fullfile(resultDir,'native_bag_summary_v21.json'),B);
names={'native_bag_preserves_all_payload_samples','native_bag_stored_code_domain_not_rails','native_bag_int64_nearest_association','native_bag_source_indices_and_gates'};
pass=[B.raw_words_total==19267584&&B.complex_samples_total==9633792&&B.radar_points_total==7626&&all(M(:,16)==336),...
 B.code_min==-649&&B.code_max==588&&B.int16_endpoint_count==0,...
 abs(B.nearest_radar_lag_median_ms-23.170405)<1e-9&&abs(B.ordinal_lag_median_ms-18437.717265)<1e-8,...
 isequal(M(:,2),double(L.nearest_radar_index_1based(:)))&&max(abs(M(:,3)-L.nearest_radar_lag_ms(:)))<1e-10&&B.nearest_radar_within50ms==19&&B.nearest_radar_within100ms==20];
tests=struct('name',names,'passed',num2cell(pass));assert(all(pass),'Native bag data/association validation failed.');
end

function [S,tests]=record_count_models_v21(dataDir,resultDir)
% Descriptive count models from the original author-acquired paired arrays.
% Fits use these same records. Nominal Fisher p-values assume independent
% records and do not remove session dependence or configuration confounding.
A=load(fullfile(dataDir,'qwerty_records_v15.mat'));B=load(fullfile(dataDir,'iq_paired_records_v17.mat'));
[ar,al,as]=countRows_v21(A.records,A.radar_translation,A.keypoint_translation,'A');
[br,bl,bs]=countRows_v21(B.records,B.radar_translation_from_v16_m,B.reference_translation_from_v16_m,'B');
assert(size(ar,1)==221 && size(br,1)==32 && sum(ar(:,7)==0)==52 && sum(br(:,7)==0)==2);
counts=[ar;br];labels=[al;bl];sources=[as;bs];
T=array2table(counts,'VariableNames',{'cohort_id','archive_block','file_index','whole_cloud_returns', ...
 'leg_returns_050','leg_returns_075','leg_returns_100','leg_returns_125','leg_returns_150','torso_returns'});
% Base leg counts occupy column 7, with extent 1.25 in column 8.
assert(sum(ar(:,7)==0)==52&&sum(br(:,7)==0)==2);
T.analysis_block=labels;T.source=sources;
writetable(T,fullfile(resultDir,'paired_record_count_audit_v21.csv'));
groupLabels=["A-pooled";"A-000";"A-001";"A-002";"B-pooled";"B-000";"B-001"];
modelRows=zeros(7,15);
for j=1:numel(groupLabels)
 if j==1,m=counts(:,1)==1;elseif j==5,m=counts(:,1)==2;else,m=labels==groupLabels(j);end
 x=counts(m,7);modelRows(j,:)=countModel_v21(x);
end
models=array2table(modelRows,'VariableNames',{'n_records','total_leg_returns','mean_leg_returns', ...
 'sample_variance','observed_zero_records','observed_zero_probability','poisson_zero_probability', ...
 'poisson_expected_zero_records','NB_MOM_shape','NB_MOM_zero_probability','NB_MOM_expected_zero_records', ...
 'NB_MLE_shape','NB_MLE_zero_probability','NB_MLE_expected_zero_records','NB_log_likelihood_gain_over_Poisson'});
models.analysis_group=groupLabels;writetable(models,fullfile(resultDir,'paired_zero_count_models_v21.csv'));
[fp,odds,probmass]=fisherExact_v21([52 169;2 30]);
% Compare only the common range of observed whole-cloud point counts.
commonLo=max(min(ar(:,4)),min(br(:,4)));commonHi=min(max(ar(:,4)),max(br(:,4)));
am=ar(:,4)>=commonLo&ar(:,4)<=commonHi;bm=br(:,4)>=commonLo&br(:,4)<=commonHi;
overlapTable=[sum(ar(am,7)==0) sum(ar(am,7)>0);sum(br(bm,7)==0) sum(br(bm,7)>0)];
[overlapP,overlapOdds]=fisherExact_v21(overlapTable);
fisherRows=[1 52 169 2 30 odds fp;2 overlapTable(1,:) overlapTable(2,:) overlapOdds overlapP];
writeNumeric(fullfile(resultDir,'paired_fisher_comparison_v21.csv'), ...
 {'comparison_id','A_zero_records','A_nonzero_records','B_zero_records','B_nonzero_records','conditional_odds_ratio','nominal_two_sided_Fisher_p'},fisherRows);
writeMappings(fullfile(resultDir,'paired_fisher_scope_v21.csv'),{'comparison_id','comparison','interpretation'}, ...
 {1,'Original primary221 and additional32','Nominal record-IID conditional comparison; source-block dependence and session/configuration confounding remain'; ...
  2,'Common observed whole-cloud point-count range34to47','Descriptive common-support subset, not randomized matching or an exposure effect'});
strata=zeros(8,5);row=0;bounds=[20 29;30 39;40 49;50 60];
for ci=1:2,for j=1:4
 m=counts(:,1)==ci&counts(:,4)>=bounds(j,1)&counts(:,4)<=bounds(j,2);
 row=row+1;strata(row,:)=[ci bounds(j,:) sum(m) sum(counts(m,7)==0)];
end;end
writeNumeric(fullfile(resultDir,'paired_point_density_strata_v21.csv'), ...
 {'cohort_id_A1_B2','whole_cloud_count_min','whole_cloud_count_max','n_records','zero_leg_records'},strata);
modelScope=['Poisson and negative-binomial models fit observed regional counts without an exposure variable. ' ...
 'NB method of moments uses the sample variance; NB maximum likelihood fits its shape at the empirical mean. ' ...
 'Their zero probabilities are in-sample descriptive predictions, not calibrated attack tests or independent validation.'];
S=struct('fisher_table',[52 169;2 30],'fisher_two_sided_p_nominal',fp,'conditional_odds_ratio',odds, ...
 'fisher_scope','Conditional exact record-IID test; clustering, pose, session and configuration differences are not corrected', ...
 'model_groups',groupLabels,'model_columns',{models.Properties.VariableNames(1:15)},'model_rows',modelRows, ...
 'model_scope',modelScope,'common_point_count_range',[commonLo commonHi],'common_support_table',overlapTable, ...
 'common_support_Fisher_p_nominal',overlapP,'figure18_block002_base_percent',100*sum(ar(ar(:,2)==2,7)==0)/sum(ar(:,2)==2));
writeJSON(fullfile(resultDir,'paired_count_model_summary_v21.json'),S);
expectedMu=[927/221 244/32];expectedVar=[13.957424928013163 27.85483870967742];
nbExpected=[.17126077767272155 .03382905165965447];
names={'paired_count_moments_match_independent_original_array_audit', ...
 'Fisher_exact_distribution_mass_and_independent_two_sided_probability', ...
 'negative_binomial_MLE_improves_Poisson_and_matches_independent_fit', ...
 'Figure18_block002_percent_is_four_of_twentyone_with_count_label'};
ok=[max(abs(modelRows([1 5],3)'-expectedMu))<1e-12&&max(abs(modelRows([1 5],4)'-expectedVar))<1e-11, ...
 abs(probmass-1)<1e-12&&abs(fp-.03494539115976622)<1e-11&&abs(overlapP-1)<1e-12, ...
 all(modelRows([1 5],15)>0)&&max(abs(modelRows([1 5],13)'-nbExpected))<1e-6, ...
 abs(S.figure18_block002_base_percent-19.047619047619047)<1e-12&&isequal(overlapTable,[9 68;2 19])];
tests=struct('name',names,'passed',num2cell(ok));assert(all(ok),'Paired count-model audit failed.');
fprintf('PHANTOMRADAR_V21_COUNT_MODELS_DONE: %d real records; nominal two-sided Fisher p=%.12g.\n',size(counts,1),fp);
end

function [rows,labels,sources]=countRows_v21(R,radarTranslation,keypointTranslation,cohort)
if ~iscell(R),R=num2cell(R);end
n=numel(R);rows=zeros(n,10);labels=strings(n,1);sources=strings(n,1);legRows=[19 20 21 23 24 25];
scales=[.5 .75 1 1.25 1.5];
for i=1:n
 r=R{i};p=double(r.radar_raw(:,1:3))+reshape(double(radarTranslation),1,3);
 k=double(r.reference_keypoints_raw)+reshape(double(keypointTranslation),1,3);
 centre=median(k(legRows,:),1);ct=zeros(1,5);
 for j=1:5,ct(j)=sum(all(abs(p-centre)<=scales(j)*[.30 .25 .38],2));end
 torso=sum(all(abs(p-median(k(1:3,:),1))<=[.20 .25 .25],2));
 ci=1+strcmp(cohort,'B');rows(i,:)=[ci str2double(r.block) double(r.file_index) size(p,1) ct torso];
 labels(i)=string(cohort)+"-"+string(r.block);sources(i)=string(r.source);
end
assert(all(diff(rows(:,5:9),1,2)>=0,'all'));
end

function r=countModel_v21(x)
n=numel(x);mu=mean(x);v=var(x,0);z=sum(x==0);poissonP0=exp(-mu);
if mu==0
 momShape=Inf;momP0=1;mleShape=Inf;mleP0=1;gain=0;
else
 if v>mu,momShape=mu^2/(v-mu);momP0=exp(-momShape*log1p(mu/momShape));
 else,momShape=Inf;momP0=poissonP0;end
 opts=optimset('TolX',1e-10,'Display','off');
 [logk,nbNLL]=fminbnd(@(q)nbNLL_v21(x,mu,exp(q)),-8,15,opts);mleShape=exp(logk);
 mleP0=exp(-mleShape*log1p(mu/mleShape));
 poissonNLL=-sum(x*log(mu)-mu-gammaln(x+1));gain=poissonNLL-nbNLL;
end
r=[n sum(x) mu v z z/n poissonP0 n*poissonP0 momShape momP0 n*momP0 mleShape mleP0 n*mleP0 gain];
end

function v=nbNLL_v21(x,mu,k)
v=-sum(gammaln(x+k)-gammaln(k)-gammaln(x+1)+k*log(k/(k+mu))+x*log(mu/(k+mu)));
end

function [p,odds,mass]=fisherExact_v21(t)
assert(isequal(size(t),[2 2])&&all(t>=0,'all')&&all(t==fix(t),'all'));
n1=sum(t(1,:));n2=sum(t(2,:));N=n1+n2;K=sum(t(:,1));x=(max(0,K-n2):min(n1,K))';
logp=gammaln(n1+1)-gammaln(x+1)-gammaln(n1-x+1)+ ...
 gammaln(n2+1)-gammaln(K-x+1)-gammaln(n2-K+x+1)- ...
 (gammaln(N+1)-gammaln(K+1)-gammaln(N-K+1));
pdf=exp(logp-max(logp));pdf=pdf/sum(pdf);mass=sum(pdf);observed=pdf(x==t(1,1));
p=min(1,sum(pdf(pdf<=observed*(1+1e-12))));
if t(1,2)*t(2,1)==0,odds=Inf;else,odds=t(1,1)*t(2,2)/(t(1,2)*t(2,1));end
end

function [A,tests]=ods_antenna_sensitivity_v21(P,resultDir)
% The TI ODS peak-antenna reference is 5 dBi. The original 10-dBi
% directional-antenna case remains the declared analytical figure reference.
% Horn15/20/25dBi rows are sensitivity assumptions, not assembled-RF tests.
rows=zeros(18,13);row=0;passive=zeros(6,10);pr=0;r=3;
for victimGain=[5 10]
 for hornGain=[15 20 25]
  V=P;V.victim_tx_gain_dbi_assumed=victimGain;V.victim_rx_gain_dbi_assumed=victimGain;V.horn_gain_dbi_nominal=hornGain;
  for gi=1:3
   [pin,beta,greq]=activeBudget_v21(r,60,2,gi,V);
   [~,~,~,~,h1]=activeBudget_v21(r,40,1,gi,V);
   [~,~,~,~,h240]=activeBudget_v21(r,40,2,gi,V);
   [~,~,~,~,h260]=activeBudget_v21(r,60,2,gi,V);
   pout=V.input_compression_dbm_graph_read(gi)-beta;
   planeCross=V.lambda_m/(8*pi)*10^((V.radar_tx_dbm+2*victimGain-V.input_compression_dbm_graph_read(gi))/20);
   row=row+1;rows(row,:)=[r V.rx_gain_db(gi) victimGain hornGain pin beta greq pout ...
    greq+V.stability_margin_db_assumed h1 h240 h260 planeCross];
  end
 end
 for gi=1:3
  requiredK=10^((P.input_compression_dbm_graph_read(gi)-30)/10)*(4*pi)^3/(P.radar_tx_w*10^(2*victimGain/10)*P.lambda_m^2);
  planePower=P.radar_tx_dbm+2*victimGain+20*log10(P.lambda_m/(8*pi*r));
  planeCross=P.lambda_m/(8*pi)*10^((P.radar_tx_dbm+2*victimGain-P.input_compression_dbm_graph_read(gi))/20);
  cross=sqrt(P.geometry_coefficients/requiredK);
  pr=pr+1;passive(pr,:)=[victimGain P.rx_gain_db(gi) 10*log10(requiredK*r^4) planePower ...
   P.input_compression_dbm_graph_read(gi)-planePower planeCross cross P.input_compression_dbm_graph_read(gi)];
 end
end
writeNumeric(fullfile(resultDir,'active_antenna_gain_sensitivity_v21.csv'), ...
 {'equal_hop_range_m','configured_RX_gain_db','victim_TX_and_RX_antenna_gain_dbi', ...
 'AF_receive_and_transmit_horn_gain_dbi','AF_input_dbm','last_hop_transfer_db','required_AF_gain_db', ...
 'required_output_or_direct_source_Pa_dbm','minimum_isolation_db_at_margin6','H1_at_isolation40_db', ...
 'H2_at_isolation40_db','H2_at_isolation60_db','image_plane_crossing_m'},rows);
writeNumeric(fullfile(resultDir,'passive_ODS_gain_reference_v21.csv'), ...
 {'victim_TX_and_RX_antenna_gain_dbi','configured_RX_gain_db','required_RCS_at3m_dbsm', ...
 'image_plane_return_at3m_dbm','image_plane_deficit_at3m_db','image_plane_crossing_m', ...
 'triangular_crossing_m','square_crossing_m','circular_plate_crossing_m','input_analog_boundary_dbm'},passive);
alpha=10.^((rows(:,3)+rows(:,4))/10).*(P.lambda_m./(4*pi*rows(:,1))).^2;
betaLinear=alpha*10^(-P.additional_loss_db_assumed/10);
thresholdDbm=interp1(P.rx_gain_db,P.input_compression_dbm_graph_read,rows(:,2));
Glinear=10.^((thresholdDbm-30)/10)./(P.radar_tx_w*alpha.*betaLinear);
linearOK=max(abs(rows(:,7)-10*log10(Glinear)))<1e-11;
shiftOK=true;
for gi=1:3
 a=rows(rows(:,3)==5&rows(:,4)==25&rows(:,2)==P.rx_gain_db(gi),:);
 b=rows(rows(:,3)==10&rows(:,4)==25&rows(:,2)==P.rx_gain_db(gi),:);
 shiftOK=shiftOK&&abs((a(7)-b(7))-10)<1e-11&&abs((a(8)-b(8))-5)<1e-11 ...
  &&abs((a(9)-b(9))-10)<1e-11&&abs(a(13)/b(13)-1/sqrt(10))<1e-12;
end
names={'ODS_antenna_gain_sensitivity_closes_independent_linear_Friis', ...
 'ODS5_vs_directional10_gain_power_isolation_and_plane_distance_shifts'};
tests=struct('name',names,'passed',num2cell([linearOK shiftOK]));assert(all([tests.passed]),'ODS antenna sensitivity audit failed.');
A=struct('rows',rows,'passive_rows',passive,'victim_ODS_peak_antenna_reference_dbi',5, ...
 'retained_figure_directional_antenna_reference_dbi',10, ...
 'ODS_gain_source','TI SWRA753 (August2022), Table2, printedpage4: IWR6843ISK-ODS peak antenna gain5dBi', ...
 'ODS_gain_source_url','https://www.ti.com/lit/ab/swra753/swra753.pdf', ...
 'scope','Conditional peak-gain sensitivity; actual antenna pattern, placement loss, gain and isolation are not measured by these calculations');
end

function [D,tests]=coherent_peak_background_audit_v21(A,resultDir)
% Compare measured lobe and background separately on held-out frames.
% Absolute log powers retain native FFT scale and are not RF dBm values.
% Training-background inflation and held-out-control shifts have different
% denominators. Medians of differences need not equal differences of medians.
refID=find(contains(A.ids,'ref_corner'));aID=find(strcmp(A.ids,'meas_2_int_A'));
assert(isscalar(refID)&&isscalar(aID));frames=A.frames;
allPeak=10*log10(max(frames(:,12),realmin));allBg=10*log10(max(frames(:,13),realmin));
identityError=max(abs(frames(:,14)-(allPeak-allBg)));
rows=zeros(numel(A.ids)*numel(A.nodes)*2,12);row=0;
for ci=1:numel(A.ids),for ni=1:numel(A.nodes),for method=1:2
 z=frames(:,1)==ci&frames(:,2)==ni&frames(:,4)==method&frames(:,5)==1;
 ref=frames(:,1)==refID&frames(:,2)==ni&frames(:,4)==method&frames(:,5)==1;
 peak=median(allPeak(z));bg=median(allBg(z));contrast=median(frames(z,14));
 refPeak=median(allPeak(ref));refBg=median(allBg(ref));refContrast=median(frames(ref,14));
 row=row+1;rows(row,:)=[ci ni method sum(z) peak bg contrast ...
  median(frames(z,15)) peak-refPeak bg-refBg contrast-refContrast contrast-(peak-bg)];
end;end;end
writeNumeric(fullfile(resultDir,'coherent_peak_background_decomposition_v21.csv'), ...
 {'condition_id','node_id','method_id','n_evaluation_frames','median_lobe_FFT_logpower_native_dB', ...
 'median_offlobe_FFT_logpower_native_dB','median_peak_background_contrast_db', ...
 'median_background_inflation_vs_10_training_frames_db','peak_shift_vs_90_heldout_corner_frames_db', ...
 'background_shift_vs_90_heldout_corner_frames_db','contrast_shift_vs_90_heldout_corner_frames_db', ...
 'median_contrast_minus_difference_of_logpower_medians_db'},rows);
aRows=rows(rows(:,1)==aID&rows(:,3)==1,:);
assert(size(aRows,1)==2&&isequal(aRows(:,2),[1;2]));
expected=[.17338430118947 8.847667189935506 -8.638021340949072; ...
 -.32015442658124 5.678323186137375 -5.994995613378645];
err=abs(aRows(:,9:11)-expected);
names={'coherent_per_frame_peak_background_contrast_identity', ...
 'coherent_conditionA_peak_and_background_medians_match_independent_frame_audit'};
ok=[identityError<1e-10 max(err(:))<1e-9];
tests=struct('name',names,'passed',num2cell(ok));assert(all(ok),'Coherent peak/background decomposition audit failed.');
D=struct('rows',rows,'original_conditionA_rows',aRows, ...
 'native_FFT_power_scope','Uncalibrated native FFT log-power scale; shifts and contrast are dB, not RF input dBm', ...
 'baseline_scope','Peak/background/contrast shifts use 90 held-out corner-control frames; existing inflation uses separate10trainingframes', ...
 'aggregation_scope','Per-frame contrast identity holds; medians of ratios and differences of separately summarized powers are distinct estimands', ...
 'maximum_per_frame_identity_error_db',identityError);
writeJSON(fullfile(resultDir,'coherent_peak_background_decomposition_v21.json'),D);
end
