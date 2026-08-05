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

%% Load data

cd '/Users/dervlamk/Library/CloudStorage/OneDrive-UCIrvine/research/eastern_pacific_cores/NH22P/data'
filename      = 'dD_nh22p.xls';
opts          = detectImportOptions(filename);
opts.Sheet    = 'dD_nh22p';
dD_nh22p      = readmatrix(filename,opts);
nh22p.age     = dD_nh22p(:,1)./1000; %ka
nh22p.dDraw   = dD_nh22p(:,2);
nh22p.stdev   = dD_nh22p(:,3);       %stdev of IRMS measurements

%% Calculate dD precipitation from dDwax

%%% ice volume correction
% load benthic stack
load '/Users/dervlamk/Library/CloudStorage/OneDrive-UCIrvine/research/global_paleo_data/lr04.mat' 
% do correction
nh22p.dDivc  = icevolcorr(nh22p.age,nh22p.dDraw,2,2);  


%%% calculate dD precip using fixed ecosystem average epsilon 
%       the epislon corrects the raw dD data for changes in plant type
%       inferred from paired d13C measurements

ep     = -97;             %mean epsilon value (based on Tripti calculated offset, C3 = -81 +/- 3.7, C4 = -113 +/- 2.26)
epErr  = 2.98;            %weighted error
iters  = 1000;

avgStDev  = median(nh22p.stdev,"omitnan");          %median analytical error
%nh22p.dDp = (1000+normrnd(repmat(nh22p.dDivc,1,iters),avgStDev))./(repmat(normrnd(ep,epErr,1,iters),length(nh22p.dDivc),1)/1000+1)-1000; 
nh22p.dDp = (1000+normrnd(repmat(nh22p.dDraw,1,iters),avgStDev))./(repmat(normrnd(ep,epErr,1,iters),length(nh22p.dDraw),1)/1000+1)-1000;

%% predict %JAS rainfall
%modified from Tripti's Prediction_from_Regression.m script (May 2022)
cd '/Users/dervlamk/Library/CloudStorage/OneDrive-UCIrvine/research/modern_swna'
load('GoCregressionFINAL.mat','tau2_draws_final','b_draws_final')

%P(rainfall) = a prior distribution you specify; 
%assign prior mean, standard deviation, will depend on the variable you're
%predicting - choose the mean and variance based on modern data
prior_mean = 76; 
prior_std  = 12;
%calculate inverse variance b/c will need it below...
prior_inv_var = prior_std^(-2);

%Now do the prediction
timeseries = squeeze(nanmedian(nh22p.dDp,2)); %input the correct sites' data here, should dDp estimate;
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
    'Ylim',[0 60],...
    'ycolor','k');
ylabel('%JAS')

%% Save data

cd '/Users/dervlamk/Library/CloudStorage/OneDrive-UCIrvine/research/eastern_pacific_cores/NH22P/data'
save(['nh22p_FAMEs_',date,'.mat'],'nh22p');
