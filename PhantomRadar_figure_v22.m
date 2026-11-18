function summary = PhantomRadar_figure_v22(dataDir,outDir,privateMeshInput,rangeOnly)
% Recreate the paper's recorded-data plots in manuscript order (MATLAB R2024b+).
% Unzip the companion code/data package, then call PhantomRadar_figure_v22().
% For full native re-rendering of the private Figure 6 background, supply
% the original qwerty_records_v15.mat as the optional third argument.
if nargin < 3, privateMeshInput = ''; end
if nargin < 4, rangeOnly = false; end
root = fileparts(mfilename('fullpath'));
if nargin < 1 || isempty(dataDir), dataDir = fullfile(root,'data'); end
if nargin < 2 || isempty(outDir), outDir = fullfile(root,'output'); end
if ~isfolder(outDir), mkdir(outDir); end
D = load(fullfile(dataDir,'registered_geometry.mat'));
n = numel(D.radar);
cohort = D.cohort(:);
block = D.block(:);
index = D.file_index(:);
primary = cohort == 'A';
assert(n == 253 && sum(primary) == 221);
legJoints = [19 20 21 23 24 25];
halfWidth = [.30 .25 .38];
clouds = cell(n,1);
centres = zeros(n,3);
distance = zeros(n,1);
legCount = zeros(n,1);
for i = 1:n
    clouds{i} = double(D.radar{i}(:,1:3)) + D.radar_translation;
    ref = double(D.joints{i}) + D.keypoint_translation;
    leg = ref(legJoints,:);
    centres(i,:) = median(leg,1);
    nearest = zeros(6,1);
    for j = 1:6
        nearest(j) = min(vecnorm(clouds{i} - leg(j,:),2,2));
    end
    distance(i) = median(nearest);
    legCount(i) = sum(all(abs(clouds{i} - centres(i,:)) <= halfWidth,2));
end
assert(sum(legCount(primary)==0)==52 && sum(legCount(~primary)==0)==2);
range = vecnorm(centres - D.radar_translation,2,2);
summary = table(cohort,block,index,legCount,distance,range, ...
    'VariableNames',{'collection','block','record','leg_returns','joint_to_return_m','reference_range_m'});
writetable(summary,fullfile(outDir,'regional_observations.csv'));
% Optional numeric-only path for a MATLAB session without a graphics server.
if rangeOnly
    writeRangeSVG(range,primary,outDir);
    return
end
E = load(fullfile(dataDir,'external_plot_examples.mat'));
% Figs. 1–4 are editable framework artwork. The first independent data figure
% is an attributed reference measurement. Figures 6–9 concern author records.
interferenceExample(E,outDir);                                  % Figure 5
i = find(primary & block==0 & index==90);
assert(isscalar(i));
if strlength(string(privateMeshInput)) > 0
    original = load(privateMeshInput,'records');
    r = original.records; if ~iscell(r), r = num2cell(r); end
    match = cellfun(@(x) strcmp(char(x.source),'000/pc_ti_kinect_key_90.mat'),r);
    assert(nnz(match)==1,'Figure 6 needs the exact published record.');
    mesh = double(r{match}.reference_surface_raw);
    mesh = mesh(mesh(:,1)>=-.8 & mesh(:,1)<=.6,:);
    trackingExample(D,i,clouds{i},mesh(1:12:end,:),outDir,'figure06_tracking');
else
    % Recompute every nonprivate analytical layer. The exact published
    % composite is provided as two-dimensional artwork for the public run.
    trackingExample(D,i,clouds{i},zeros(0,3),outDir,'figure06_numeric_layers');
    for ext = [".pdf",".png"]
        file = "figure06_tracking"+ext;
        copyfile(fullfile(dataDir,'paper_artwork',file),fullfile(outDir,file),'f');
    end
end                          % Figure 6
distanceCDF(distance(primary),block(primary),outDir);            % Figure 7
shiftSensitivity(clouds(primary),centres(primary,:),halfWidth,outDir); % Figure 8
rangeCoverage(range,primary,outDir);                             % Figure 9
fprintf('PhantomRadar plots complete: %d recorded pairs, five figures.\n',n);
end

function interferenceExample(E,outDir)
fig = newFigure(18.2,7.8);
names = {'Corner reference','Interference D','Interference A'};
palette = [30 70 110;55 103 149;114 188 213;255 230 183;255 208 111;231 98 84]/255;
traceLimit = 1.12*max(abs(E.trace),[],'all');
for e = 1:3
    left = .063+(e-1)*.32;
    ax = axes(fig,'Position',[left .73 .24 .18]);
    plot(ax,E.time_us,E.trace(:,e),'Color',palette(2,:),'LineWidth',.7);
    formatAxis(ax); ylim(ax,[-traceLimit traceLimit]);
    xlabel(ax,'Fast time (µs)'); ylabel(ax,'Recorded IF value'); title(ax,names{e});
    ax = axes(fig,'Position',[left .16 .24 .34]);
    imagesc(ax,E.velocity,E.range_m,E.rd_db(:,:,e)); hold(ax,'on');
    colormap(ax,interp1(linspace(0,1,6),palette,linspace(0,1,64)));
    set(ax,'YDir','normal'); clim(ax,[-60 15]); formatAxis(ax);
    hits = ca_cfar_2d_v12(E.rd_power(:,:,e),[1 1],[4 3],1e-3);
    [r,v] = find(hits);
    assert(numel(r)==E.metadata(e,5),'CFAR and reference metadata disagree.');
    plot(ax,E.velocity(v),E.range_m(r),'ko','MarkerSize',2,'LineWidth',.5);
    xlim(ax,E.velocity([1 end])); ylim(ax,E.range_m([1 end]));
    xlabel(ax,'Configured velocity (m/s)'); ylabel(ax,'Beat-range equivalent (m)');
    title(ax,sprintf('Maxima (lobe / all): %d / %d',E.metadata(e,6),numel(r)));
    if e == 3
        cb = colorbar(ax,'Position',[.955 .16 .012 .34]);
        cb.Ticks = [-60 -30 0 15]; title(cb,'dB');
    end
end
exportPlot(fig,outDir,'figure_motivation_rd');
end

function trackingExample(D,i,p,mesh,outDir,name)
k = double(D.joints{i}) + D.keypoint_translation;
centres = D.display_bounds_centres; half = D.display_bounds_half;
displayCentre = median(k([19 20 21 23 24 25],:),1); displayHalf = [.16 .10 .30];
regionCorners = [centres-half;centres+half;displayCentre-displayHalf;displayCentre+displayHalf];
bounds = [p;k;regionCorners];
lo = min(min(bounds,[],1)-[.04 .04 .04],[-.50 1.08 -.89]);
hi = max(max(bounds,[],1)+[.04 .04 .04],[.50 1.77 .82]);
    fig=figure('Visible','off','Color','w','Units','centimeters','Position',[2 2 18.6 4.7], ...
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
        assert(numel(hr.XData)==size(p,1),'Displayed radar count differs from raw record');
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
    exportPlot(fig,outDir,name);
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


function distanceCDF(distance,blocks,outDir)
fig = newFigure(8.9,6.0);
ax = axes(fig,'Position',[.18 .21 .78 .73]); hold(ax,'on'); formatAxis(ax);
colors = [55 103 149;114 188 213;255 208 111;30 70 110]/255;
styles = {'-','--','-.','-'};
lines = gobjects(4,1); labels = cell(4,1);
for b = 1:4
    if b < 4
        values = sort(distance(blocks==b-1));
        labels{b} = sprintf('Block %03d (n=%d)',b-1,numel(values));
    else
        values = sort(distance); labels{b} = sprintf('Pooled (n=%d)',numel(values));
    end
    cdf = (1:numel(values))'/numel(values);
    lines(b) = stairs(ax,[0;values],[0;cdf],'LineStyle',styles{b}, ...
        'Color',colors(b,:),'LineWidth',1.2+.4*(b==4));
end
xlabel(ax,'Median leg-joint-to-return distance (m)'); ylabel(ax,'Snapshot CDF');
ylim(ax,[0 1.02]); xlim(ax,[0 max(distance)*1.05]);
legend(ax,lines,labels,'Location','southeast','FontSize',8.5,'Box','off');
exportPlot(fig,outDir,'figure_region_distance');
end

function shiftSensitivity(clouds,centres,halfWidth,outDir)
offsets = [-.05 -.02 0 .02 .05];
empty = zeros(numel(offsets),3);
for axisID = 1:3
    for j = 1:numel(offsets)
        delta = zeros(1,3); delta(axisID) = offsets(j);
        for i = 1:numel(clouds)
            inside = all(abs(clouds{i}+delta-centres(i,:))<=halfWidth,2);
            empty(j,axisID) = empty(j,axisID) + ~any(inside);
        end
    end
end
assert(all(empty(3,:)==52));
fig = newFigure(8.9,5.6); ax = axes(fig,'Position',[.20 .22 .76 .70]);
hold(ax,'on'); formatAxis(ax);
palette = [55 103 149;114 188 213;231 98 84]/255;
markers = {'o','s','^'}; styles = {'-','--','-.'};
for j = 1:3
    plot(ax,100*offsets,100*empty(:,j)/numel(clouds),'Color',palette(j,:), ...
        'LineStyle',styles{j},'Marker',markers{j},'MarkerFaceColor',palette(j,:), ...
        'MarkerSize',5,'LineWidth',1.5);
end
yline(ax,100*empty(3,1)/numel(clouds),':','HandleVisibility','off');
legend(ax,{'X shift','Y shift','Z shift'},'Location','northwest','Box','on');
xlabel(ax,'Radar-coordinate shift (cm)'); ylabel(ax,'Zero-support records (%)');
xticks(ax,[-5 -2 0 2 5]); yticks(ax,0:10:50); xlim(ax,[-5.5 5.5]); ylim(ax,[0 49]);
exportPlot(fig,outDir,'figure_regional_translation');
end

function rangeCoverage(range,primary,outDir)
writeRangeSVG(range,primary,outDir);
fig = newFigure(9.7,6.1);
colors = [55 103 149;231 98 84]/255;
for panel = 1:2
    if panel == 1
        ax = axes(fig,'Position',[.22 .66 .73 .26]);
        set(ax,'XScale','log'); xlim(ax,[.1 30]); xticks(ax,[.1 .3 1 3 10 30]);
        xticklabels(ax,{'0.1','0.3','1','3','10','30'});
        xlabel(ax,'Reference range (m, log scale)');
    else
        ax = axes(fig,'Position',[.22 .17 .73 .26]);
        xlim(ax,[1.59 2.03]); xticks(ax,[1.6 1.7 1.8 1.9 2]);
        xlabel(ax,'Detail of the observed range (m)');
    end
    hold(ax,'on'); formatAxis(ax);
    for j = 1:2
        values = sort(range(primary==(j==1)));
        level = 3-j;
        % Draw the empirical span and every return reference as a vertical
        % tick on the same y level. Overlap represents repeated distances.
        plot(ax,values([1 end]),[level level],'Color',colors(j,:),'LineWidth',1.1);
        plot(ax,values,repmat(level,size(values)),'|','Color',colors(j,:), ...
            'LineStyle','none','MarkerSize',6);
        plot(ax,median(values),level,'d','MarkerFaceColor',colors(j,:), ...
            'MarkerEdgeColor','k','MarkerSize',5);
    end
    ylim(ax,[.50 2.5]); yticks(ax,[1 2]); yticklabels(ax,{'Additional','Primary'});
    set(ax,'YGrid','off','XGrid','on');
end
exportPlot(fig,outDir,'figure_range_coverage');
end

function fig = newFigure(w,h)
fig = figure('Color','white','Visible','off','Units','centimeters','Position',[2 2 w h], ...
    'PaperUnits','centimeters','PaperPosition',[0 0 w h],'PaperSize',[w h]);
end

function formatAxis(ax)
set(ax,'FontName','Times New Roman','FontSize',9,'FontWeight','bold','Box','on', ...
    'TickDir','out','YGrid','on','GridAlpha',.2,'LineWidth',.85);
end

function exportPlot(fig,outDir,name)
fontObjects = findall(fig,'-property','FontName');
set(fontObjects,'FontName','Times New Roman');
tempDir = tempname; mkdir(tempDir);
cleanup = onCleanup(@()rmdir(tempDir,'s')); %#ok<NASGU>
drawnow;
print(fig,fullfile(tempDir,[name '.pdf']),'-dpdf','-painters');
print(fig,fullfile(tempDir,[name '.png']),'-dpng','-r220','-painters');
for ext = [".pdf",".png"]
    file = string(name)+ext; info = dir(fullfile(tempDir,file));
    assert(~isempty(info) && info.bytes>1000,'Empty figure export: %s',file);
    copyfile(fullfile(tempDir,file),fullfile(outDir,file),'f');
end
close(fig);
end

function writeRangeSVG(range,primary,outDir)
% Render the empirical spans and individual observations in a portable vector.
fid = fopen(fullfile(outDir,'figure_range_coverage.svg'),'wt');
assert(fid>=0,'Cannot open the vector output');
finish = onCleanup(@()fclose(fid));
fprintf(fid,'<svg xmlns="http://www.w3.org/2000/svg" width="370" height="232" viewBox="0 0 370 232"><rect width="370" height="232" fill="white"/><g font-family="Times New Roman, Liberation Serif, serif" font-size="13" fill="#262626">');
colors = {'#376795','#e76254'};
names = {'Primary','Additional'};
for panel = 1:2
    top = 8+(panel-1)*114;
    if panel==1
        xpos = @(d) 77+272*(log(d)-log(.1))/(log(30)-log(.1));
        ticks = [.1 .3 1 3 10 30];
        label = 'Reference range (m, log scale)';
    else
        xpos = @(d) 77+272*(d-1.59)/(2.03-1.59);
        ticks = 1.6:.1:2;
        label = 'Detail of the observed range (m)';
    end
    fprintf(fid,'<rect x="77" y="%g" width="272" height="53" fill="none" stroke="#444"/>',top);
    for t=ticks
        x=xpos(t);
        fprintf(fid,'<path d="M%.3f %.2f v53" stroke="#d6d6d6" stroke-width=".65"/><text x="%.3f" y="%g" text-anchor="middle">%g</text>',x,top,x,top+70,t);
    end
    fprintf(fid,'<text x="213" y="%g" text-anchor="middle" font-weight="bold">%s</text>',top+89,label);
    for j=1:2
        v=sort(range(primary==(j==1)));
        x=xpos(v(:)); y=top+13+(j-1)*26;
        fprintf(fid,'<text x="70" y="%g" text-anchor="end">%s</text>',y+4,names{j});
        fprintf(fid,'<path d="M%.3f %g H%.3f" stroke="%s" stroke-width="1.5"/>',x(1),y,x(end),colors{j});
        fprintf(fid,'<path stroke="%s" d="',colors{j});
        fprintf(fid,'M%.3f %.2f v7 ',[x';repmat(y-3.5,1,numel(x))]);
        fprintf(fid,'"/><path d="M%.3f %g l4 4 -4 4 -4 -4 z" fill="%s" stroke="#212121" stroke-width=".6"/>',xpos(median(v)),y-4,colors{j});
    end
end
fprintf(fid,'</g></svg>');
end
