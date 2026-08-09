close all; clear all; clc

%   THIS CODE:
%       1. PROCESSES dD DATA INTO MATLAB FORMAT
%       2. ESTIMATES ECOSYSTEM AVERAGE EPSILON FOR REGION
%       3. CALCULATES dDprecip
%   FOR CORE NH22P
%
%   (modifed from code from Jess Tierney & Tripti Bhattacharya)
%
%
%   Dervla Meegan Kumar
%   University of Arizona
%   May 2022

%% Paths
%  Reads PROXY_DATA_DIR from the environment, and falls back to parsing
%  config/paths.env directly if it is unset. The fallback matters: MATLAB launched
%  from the Dock does not inherit the shell environment, so `source config/paths.env`
%  in a terminal has no effect on it. This way the script works either way.
%  Outputs go to data/processed.

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
% icevolcorr does a bare `load lr04.mat`, so it resolves that file off the MATLAB path
% rather than from extern_dir. Put extern_dir on the path so the script works however
% MATLAB was launched -- without this it picks up whatever stale saved path entry it finds.
addpath(extern_dir);
out_dir    = fullfile(repo_root, 'data', 'processed');
if ~exist(out_dir, 'dir'); mkdir(out_dir); end
fprintf('proxy_dir = %s\n', proxy_dir);


%% Load data

filename      = fullfile(proxy_dir, 'NH22P', 'dD_nh22p.xls');
opts          = detectImportOptions(filename);
opts.Sheet    = 'dD_nh22p';
dD_nh22p      = readmatrix(filename,opts);
nh22p.age     = dD_nh22p(:,1)./1000; %ka
nh22p.dDraw   = dD_nh22p(:,2);
nh22p.stdev   = dD_nh22p(:,3);       %stdev of IRMS measurements

%% Calculate dD precipitation from dDwax

%%% ice volume correction
% load benthic stack
load(fullfile(extern_dir, 'lr04.mat'))
% do correction
nh22p.dDivc  = icevolcorr(nh22p.age,nh22p.dDraw,2,2);  


%%% calculate dD precip using fixed ecosystem average epsilon 
%       the epislon corrects the raw dD data for changes in plant type
%       inferred from paired d13C measurements

ep     = -97;             %mean epsilon value (based on Tripti calculated offset, C3 = -81 +/- 3.7, C4 = -113 +/- 2.26)
epErr  = 2.98;            %weighted error
iters  = 1000;

% dDraw, not dDivc — matches dDwax_data_processing_d480_d479.m, and matches iCESM output,
% which already carries the ice-sheet isotope effect. dDivc is computed and stored above
% either way.
nh22p_in  = nh22p.dDraw;

avgStDev  = median(nh22p.stdev,"omitnan");          %median analytical error
nh22p.dDp = (1000+normrnd(repmat(nh22p_in,1,iters),avgStDev))./(repmat(normrnd(ep,epErr,1,iters),length(nh22p_in),1)/1000+1)-1000;

%% predict %JAS rainfall
%modified from Tripti's Prediction_from_Regression.m script (May 2022)
load(fullfile(extern_dir,'GoCregressionFINAL.mat'),'tau2_draws_final','b_draws_final')

%P(rainfall) = a prior distribution you specify; 
%assign prior mean, standard deviation, will depend on the variable you're
%predicting - choose the mean and variance based on modern data
prior_mean = 76; 
prior_std  = 12;
%calculate inverse variance b/c will need it below...
prior_inv_var = prior_std^(-2);

%Now do the prediction
timeseries = squeeze(median(nh22p.dDp,2,"omitnan")); %input the correct sites' data here, should dDp estimate;
N_Ts=length(timeseries);

results=NaN(N_Ts,length(tau2_draws_final));
for i=1:length(tau2_draws_final)
    beta_now=b_draws_final(i,1);
    alpha_now=b_draws_final(i,2);
    tau_now=tau2_draws_final(i);
    %calculate the posterior covariance based on iterative formula:
    post_cov=1/(prior_inv_var + beta_now^2/tau_now);
    %now calculate the first factor of the posterior mean, vectorize as you
    %do it:
    mean_first=prior_inv_var*eye(N_Ts) * prior_mean*ones(N_Ts,1) + (1/tau_now) * beta_now * (timeseries - alpha_now);
    
    %then calculate the full mean of the posterior.
    Mean_full=post_cov*eye(N_Ts)*mean_first;
    
    %make a draw from the distribution 
    results(:,i) = normrnd(Mean_full,sqrt(post_cov));
    nh22p.jas     = results;
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

sorted_data = sort(nh22p.dDp,2);

f1 = figure(1); clf; hold on;

Hseb = shadedErrorBar3(nh22p.age,median(nh22p.dDp,2,"omitnan"),...
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

sorted_data = sort(nh22p.jas,2);

f2 = figure(2); clf; hold on;

Hseb = shadedErrorBar3(nh22p.age,median(nh22p.jas,2,"omitnan"),...
    sorted_data(:,[ilowerlower iupperupper])',...
    sorted_data(:,[iinner iouter])','k'); hold on;
set(Hseb.mainLine,'Color',colline,'linewidth',1.2);
set(Hseb.patch1,'facecolor',sig2,'edgecolor','none');
set(Hseb.patch2,'facecolor',sig1,'edgecolor','none');
set(gca,...
    'Ylim',[ymin ymax],...
    'ycolor','k');
ylabel('%JAS')

%% Save data

%  Two copies are written: a dated archive, and a stable undated name that downstream
%  code reads. The stable name is what lets fig3 avoid hardcoding a date -- see CLAUDE.md
%  on how a figure quietly ends up on year-old data.
save(fullfile(out_dir, ['nh22p_FAMEs_',date,'.mat']), 'nh22p');
save(fullfile(out_dir, 'nh22p_FAMEs_current.mat'), 'nh22p');
fprintf('wrote %s\n', fullfile(out_dir, ['nh22p_FAMEs_',date,'.mat']));
