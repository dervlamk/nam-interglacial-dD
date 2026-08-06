close all; clear all; clc

%   THIS CODE:
%       1. PROCESSES dD DATA INTO MATLAB FORMAT
%       2. ESTIMATES ECOSYSTEM AVERAGE EPSILON FOR REGION
%       3. CALCULATES dDprecip & dDivc
%       4. PROCESSES BACON AGES
%   FOR DSDP SITES 480 & 479
%
%   (modifed from code from Jess Tierney & Tripti Bhattacharya)
%
%
%   Dervla Meegan Kumar
%   University of Arizona
%   May 2022

%% Which dD series feeds the Monte Carlo   [TEMPORARY — delete once verified]
%  true  = dDivc, what this script used historically. Reproduces
%          Guaymas_d480_d479_FAMEs_14-Apr-2025.mat (147 x 1000) exactly, which is the
%          check that the reorganisation changed nothing.
%  false = dDraw, the corrected choice: it puts this core on the same footing as
%          dDwax_data_processing_nh22p.m, which has always used dDraw, and matches iCESM
%          output, which already carries the ice-sheet isotope effect.
%
%  The age model is NOT part of this switch. Bacon_runs/DSDP480 is canonical and is now
%  used unconditionally — the stored products were verified to have been built from it
%  (they match its interpolated ages to 0.0000 ka; the superseded Bacon_runs_new run
%  differs by up to 2.763 ka). It was the committed code that had drifted, not the data.
%
%  Run once with true to confirm the reproduction, then set false and delete this switch.
%  It is the only remaining structural difference from the NH22P script.
USE_DDIVC = false;


%% Paths
%  Resolved from config/paths.env — source it before launching MATLAB:
%      source config/paths.env && matlab
%  Nothing below uses `cd`. The old code cd'd into the data directory and saved there,
%  which under the data/ layout would write into data/raw (immutable). Outputs now go
%  to data/processed.

%  Falls back to parsing config/paths.env if PROXY_DATA_DIR is unset — MATLAB launched
%  from the Dock does not inherit the shell environment, so sourcing the file in a
%  terminal has no effect on it.

%  Locating the repo root. Three candidates are tried, in order, each walked upward
%  looking for the tracked marker config/paths.env.example:
%    1. the file open in the MATLAB editor — the reliable one when running a %% section,
%       because running a section evaluates from a TEMPORARY COPY and mfilename then
%       resolves to /private/var/folders/... rather than the real file;
%    2. mfilename — correct when the whole file is run;
%    3. the Current Folder.
%  Set REPO_ROOT_OVERRIDE below if all three fail.
REPO_ROOT_OVERRIDE = '';

cand_editor = '';
try
    ed = matlab.desktop.editor.getActive;
    if ~isempty(ed); cand_editor = fileparts(ed.Filename); end
catch
    % no desktop (headless / -batch) — fine, fall through to the other candidates
end

repo_root = '';
cands = {REPO_ROOT_OVERRIDE, cand_editor, fileparts(mfilename('fullpath')), pwd};
for ii = 1:numel(cands)
    d = cands{ii};
    while ~isempty(d)
        if isfile(fullfile(d,'config','paths.env.example')); repo_root = d; break; end
        parent = fileparts(d);
        if strcmp(parent,d); break; end
        d = parent;
    end
    if ~isempty(repo_root); break; end
end
if isempty(repo_root)
    error(['Cannot locate the repo root. Tried:\n  override : %s\n  editor   : %s\n' ...
           '  mfilename: %s\n  pwd      : %s\nFix: cd to the analysis-repo directory, ' ...
           'or set REPO_ROOT_OVERRIDE at the top of this section.'], ...
           cands{1}, cands{2}, cands{3}, cands{4});
end

proxy_dir  = getenv('PROXY_DATA_DIR');
if isempty(proxy_dir)
    envfile = fullfile(repo_root, 'config', 'paths.env');
    if ~isfile(envfile)
        error('PROXY_DATA_DIR unset and %s not found. Copy config/paths.env.example to it.', envfile);
    end
    fid = fopen(envfile);
    while true
        ln = fgetl(fid);
        if ~ischar(ln); break; end
        tok = regexp(strtrim(ln), '^export\s+PROXY_DATA_DIR\s*=\s*(.*)$', 'tokens', 'once');
        if ~isempty(tok)
            proxy_dir = strtrim(erase(tok{1}, {'"', ''''}));
        end
    end
    fclose(fid);
    if isempty(proxy_dir)
        error('PROXY_DATA_DIR not set in %s', envfile);
    end
end
extern_dir = fullfile(repo_root, 'data', 'external');
out_dir    = fullfile(repo_root, 'data', 'processed');
if ~exist(out_dir, 'dir'); mkdir(out_dir); end
fprintf('proxy_dir = %s   USE_DDIVC = %d\n', proxy_dir, USE_DDIVC);


%% Load Data

filename    = fullfile(proxy_dir, 'DSDP-480-479', 'd480-479_dD.xlsx');
opts        = detectImportOptions(filename);

% DSDP-480: only using data up until the core break (49 m) since there is no age
% control beyond MIS 5e
opts.Sheet  = 'd480_dD_good';
dD_d480     = readmatrix(filename,opts);
d480.depth  = dD_d480(1:114,1);         %m
d480.dDraw  = dD_d480(1:114,4);
d480.stdev  = dD_d480(1:114,3);


% DSDP-479
opts.Sheet  = 'd479_dD_good';
dD_d479     = readmatrix(filename,opts);
d479.depth  = dD_d479(:,1);         %m (D479 depth, not corrected to d480 depth)
d479.dDraw  = dD_d479(:,4);
d479.stdev  = dD_d479(:,3);              

clearvars dD_d480 dD_d479 filename opts

%% Update ages based on latest Bacon results

% DSDP-480 Bacon output
% CANONICAL age model for DSDP-480 is Bacon_runs/DSDP480 — it is the run that produced
% DSDP480_mcmc_new.csv, which fig2_dsdp480-479_agemodel.ipynb plots. Verified: the median
% column here matches that ensemble's column medians to 0.3 yr (rounding).
% The superseded Bacon_runs_new/DSDP480 is a DIFFERENT MCMC realization of the same
% 165-section configuration, disagreeing by up to 2813 yr. See DATA_MANIFEST.md.
%
% Confirmed empirically: interpolating this file's median ages onto the sample depths
% reproduces the ages stored in d480_FAMEs_14-Apr-2025.mat to 0.0000 ka. Only the
% canonical run is in data/raw; the superseded Bacon_runs_new is not, on purpose.
filename         = fullfile(proxy_dir, 'Bacon_runs', 'DSDP480', 'DSDP480_165_ages.txt');
d480_agedepth    = importdata(filename);
d480_depths      = d480_agedepth.data(:,1)./100;
d480_median_ages = d480_agedepth.data(:,4);
d480.age         = (interp1(d480_depths, d480_median_ages, d480.depth, 'linear', 'extrap'))./1000; %ka

% DSDP-479 Bacon output — only one run exists, no ambiguity either way.
filename         = fullfile(proxy_dir, 'Bacon_runs', 'DSDP479', 'DSDP479_113_ages.txt');
d479_agedepth    = importdata(filename);
d479_depths      = d479_agedepth.data(:,1)./100;
d479_median_ages = d479_agedepth.data(:,4);
d479.age         = (interp1(d479_depths, d479_median_ages, d479.depth, 'linear', 'extrap'))./1000; %ka

clearvars d480_agedepth d480_depths d480_median_ages d479_agedepth d479_depths d479_median_ages filename

%% Calculate dD precipitation from dDwax

%%% ice volume correction
% load benthic stack
load(fullfile(extern_dir, 'lr04.mat'))
% do correction — dDivc is always computed and stored, whether or not it feeds dDp below
d480.dDivc  = icevolcorr(d480.age,d480.dDraw,2,2);
d479.dDivc  = icevolcorr(d479.age,d479.dDraw,2,2);


%%% calculate dD precip using fixed ecosystem average epsilon 
%       the epislon corrects the raw dD data for changes in plant type
%       inferred from paired d13C measurements

ep     = -97;             %mean epsilon value (based on Tripti calculated offset, C3 = -81 +/- 3.7, C4 = -113 +/- 2.26)
epErr  = 2.98;            %weighted error
iters  = 1000;

% dDraw, not dDivc — see the switch at the top of this file. dDraw keeps this core on the
% same footing as NH22P and matches iCESM output, which already carries the ice-sheet
% isotope effect. dDivc is still computed and stored above either way.
if USE_DDIVC
    d480_in = d480.dDivc;   d479_in = d479.dDivc;
else
    d480_in = d480.dDraw;   d479_in = d479.dDraw;
end

% DSDP-480
avgStDev  = median(d480.stdev,"omitnan");          %median analytical error
d480.dDp  = (1000+normrnd(repmat(d480_in,1,iters),avgStDev))./(repmat(normrnd(ep,epErr,1,iters),length(d480_in),1)/1000+1)-1000;
% DSDP-479
avgStDev  = median(d479.stdev,"omitnan");          %median analytical error
d479.dDp  = (1000+normrnd(repmat(d479_in,1,iters),avgStDev))./(repmat(normrnd(ep,epErr,1,iters),length(d479_in),1)/1000+1)-1000;

%% Save DSDP-480 & DSDP-479 Data

save(fullfile(out_dir, ['d480_FAMEs_',date,'.mat']), 'd480');
save(fullfile(out_dir, ['d479_FAMEs_',date,'.mat']), 'd479');

%% Create combined Guaymas Basin record

% load d480_FAMEs_18-May-2022.mat
% load d479_FAMEs_18-May-2022.mat

% concatanate age arrays into combined Guaymas age vector
Guay.age            = cat(1, d480.age, d479.age);
% sort ages into descending order, create index of orders
[Guay.age, sortIdx] = sort(Guay.age);

% concatanate arrays into combined Guaymas vector & sort according to ages
% dDraw
Guay.dDraw = cat(1,d480.dDraw, d479.dDraw);
Guay.dDraw = Guay.dDraw(sortIdx,:);
% dDstdev
Guay.stdev = cat(1,d480.stdev, d479.stdev);
Guay.stdev = Guay.stdev(sortIdx,:);
% dDivc
Guay.dDivc = cat(1,d480.dDivc, d479.dDivc);
Guay.dDivc = Guay.dDivc(sortIdx,:);
% dDp
Guay.dDp = cat(1,d480.dDp, d479.dDp);
Guay.dDp = Guay.dDp(sortIdx,:);

% check to see if combination works
plot(Guay.age, mean(Guay.dDp,2))


%% Predict %JAS rainfall
% modified from Tripti's Prediction_from_Regression.m script (May 2022)

load(fullfile(extern_dir,'GoCregressionFINAL.mat'),'tau2_draws_final','b_draws_final')

% P(rainfall) = a prior distribution you specify; 
% assign prior mean, standard deviation, will depend on the variable you're
% predicting - choose the mean and variance based on modern data
prior_mean = 67; 
prior_std  = 12;
% calculate inverse variance b/c will need it below...
prior_inv_var = prior_std^(-2);

% Do the prediction

% Guaymas Basin - DSDP-480/479
timeseries = squeeze(median(Guay.dDp,2,"omitnan")); %input the correct sites' data here, should dDp estimate;
N_Ts=length(timeseries);

results=NaN(N_Ts,length(tau2_draws_final));
for i=1:length(tau2_draws_final)
    beta_now=b_draws_final(i,1);
    alpha_now=b_draws_final(i,2);
    tau_now=tau2_draws_final(i);
    % calculate the posterior covariance based on iterative formula:
    post_cov=1/(prior_inv_var + beta_now^2/tau_now);
    % now calculate the first factor of the posterior mean, vectorize as you
    % do it:
    mean_first=prior_inv_var*eye(N_Ts) * prior_mean*ones(N_Ts,1) + (1/tau_now) * beta_now * (timeseries - alpha_now);
    
    % then calculate the full mean of the posterior.
    Mean_full=post_cov*eye(N_Ts)*mean_first;
    
    % make a draw from the distribution 
    results(:,i) = normrnd(Mean_full,sqrt(post_cov));
    Guay.jas     = results;
end %; clearvars beta_now alpha_now post_cov tau_now mean_first N_Ts Mean_full timeseries;

%% quick plots to check data

%%% dDprecip

iters = 1000;
% 95% two-tailed
iupperupper = round(iters * 0.025);
ilowerlower = round(iters * 0.975);

% 90% two-tailed
iupper = round(iters * 0.05);
ilower = round(iters * 0.95);

% 68% two-tailed
iouter = round(iters * 0.16);
iinner = round(iters * 0.84);

sig1 = [255 196 0]./255;
sig2 = [255 242 156]./255; 
colline = [235 142 5]./255;
mis_col = [.9 .9 .9];         
xmin = 0;
xmax = 150;
ymin = -80;
ymax = -38;

sorted_data = sort(Guay.dDp,2);

f1 = figure(1); clf; hold on;

Hseb = shadedErrorBar3(Guay.age,median(Guay.dDp,2,"omitnan"),...
    sorted_data(:,[ilowerlower iupperupper])',...
    sorted_data(:,[iinner iouter])','k'); hold on;
set(Hseb.mainLine,'Color',colline,'linewidth',1.2);
set(Hseb.patch1,'facecolor',sig2,'edgecolor','none');
set(Hseb.patch2,'facecolor',sig1,'edgecolor','none');
set(gca,...
    'Ylim',[ymin ymax],...
    'ycolor','k');
ylabel(['\delta D_{precip} (',char(8240),')'])



%%% %JAS

iters = 4000;
% 95% two-tailed
iupperupper = round(iters * 0.025);
ilowerlower = round(iters * 0.975);

% 90% two-tailed
iupper = round(iters * 0.05);
ilower = round(iters * 0.95);

% 68% two-tailed
iouter = round(iters * 0.16);
iinner = round(iters * 0.84);

sig1 = [66 135 245]./255;
sig2 = [152 188 245]./255; 
colline = [4 30 71]./255;
mis_col = [.9 .9 .9];         
xmin = 0;
xmax = 150;
ymin = -20;
ymax = 60;

sorted_data = sort(Guay.jas,2);

f2 = figure(2); clf; hold on;

Hseb = shadedErrorBar3(Guay.age,median(Guay.jas,2,"omitnan"),...
    sorted_data(:,[ilowerlower iupperupper])',...
    sorted_data(:,[iinner iouter])','k'); hold on;
set(Hseb.mainLine,'Color',colline,'linewidth',1.2);
set(Hseb.patch1,'facecolor',sig2,'edgecolor','none');
set(Hseb.patch2,'facecolor',sig1,'edgecolor','none');
set(gca,...
    'Ylim',[ymin ymax],...
    'ycolor','k');
ylabel('%JAS')


%% Save combined Guaymas data

save(fullfile(out_dir, ['Guaymas_d480_d479_FAMEs_',date,'.mat']), 'Guay');
fprintf('wrote %s  (USE_DDIVC = %d)\n', ...
        fullfile(out_dir, ['Guaymas_d480_d479_FAMEs_',date,'.mat']), USE_DDIVC);