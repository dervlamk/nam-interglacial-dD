close all; clear all; clc;
% Fig: Correlation between SST and dDp
%
%   When correlating two time-series that contain autocorrelation, need to
%   do an Ebisuzaki method rather than just use corrcoef
%
%
%       Dervla Meegan Kumar
%       May 2022
%

% Set Figure defaults
set(0,'DefaultAxesFontWeight','bold','DefaultAxesFontSize',12);
set(0,'DefaultTextFontWeight','bold','DefaultTextFontSize',12);
set(groot, 'DefaultAxesLineWidth',.5,...
           'DefaultAxesXColor', [0,0,0],...
           'DefaultAxesYColor', [0,0,0],...
           'DefaultAxesZColor', [0,0,0]);
       
%% NH22P

cd '/Users/dervlakumar/Google_Drive/Research/NH22P_SST'
load nh22p_uk_sst.mat

cd '/Users/dervlakumar/Google_Drive/Research/GoC_Cores/Data/NH22P'
load nh22p_FAMEs_19-May-2022.mat
load('lr04.mat','delob')


% Interpolate SST Data to match dDp
SSTint = interp1(age_nh22p,byspln_nh22p.SST(:,2),nh22p.age,'linear','extrap');

% Do Ebisuzaki Significance Test - SST & dDp
[F1,R1] = ebisuzaki(SSTint(1:54,:),squeeze(nanmean(nh22p.dDp(1:54,:),2)));
fprintf('NH22P SST vs. dDp R (0-60 ka): %f\n', R1)
[F2,R2] = ebisuzaki(SSTint(55:end,:),squeeze(nanmean(nh22p.dDp(55:end,:),2)));
fprintf('NH22P SST vs. dDp R (61-144 ka): %f\n', R2)

f1 = figure(1); clf;
scatter(SSTint(1:54,:),squeeze(nanmean(nh22p.dDp(1:54,:),2)),100,'markerfacecolor','r','markeredgecolor','k'); hold on
scatter(SSTint(55:end,:),squeeze(nanmean(nh22p.dDp(55:end,:),2)),100,'markerfacecolor','b','markeredgecolor','k'); box on
xlabel('SST (°C)');
ylabel('\deltaD_{rain}');
legend('0-60 ka','61-144 ka','location','northeast');

%%
% Interpolate LR04 data to match dDp resolution
delob_int = interp1(delob(1:145,1),delob(1:145,2),nh22p.age,'linear','extrap');

% Do Ebisuzaki Significance Test - d18O & dDp
% [F1,R1] = ebisuzaki(squeeze(nanmean(nh22p.dDp(1:58,:),2)),delob_int(1:58,:));
% fprintf('NH22P dDp (ivc) vs. LR04 d18O R (0-64 ka): %f\n', R1)
[F2,R2] = ebisuzaki(squeeze(nanmean(nh22p.dDp(30:108,:),2)),delob_int(30:108,:));
fprintf('NH22P dDp (ivc) vs. LR04 d18O R (35-130 ka): %f\n', R2)

f3 = figure(3); clf;
scatter(delob_int(1:58,:),squeeze(nanmean(nh22p.dDp(1:58,:),2)),100,'markerfacecolor','r','markeredgecolor','k'); hold on
scatter(delob_int(30:108,:),squeeze(nanmean(nh22p.dDp(30:108,:),2)),100,'markerfacecolor','b','markeredgecolor','k'); box on
xlabel('LR04 \delta^{18}O_{benthic}');
ylabel('\deltaD_{rain}');
legend('0-64 ka','35-130 ka','location','southeast');

%% DSDP-480

%cd '/Users/dervlakumar/Google_Drive/Research/NH22P_SST'
%load nh22p_uk_sst.mat

cd '/Users/dervlakumar/Google_Drive/Research/GoC_Cores/Data/DSDP480-479'
load Guaymas_d480_d479_FAMEs_19-May-2022.mat
load('lr04.mat','delob')

%%
% % Interpolate SST Data to match dDp
% SSTint = interp1(age_nh22p,byspln_nh22p.SST(:,2),nh22p.age,'linear','extrap');
% 
% % Do Ebisuzaki Significance Test - SST & dDp
% [F1,R1] = ebisuzaki(SSTint(1:54,:),squeeze(nanmean(nh22p.dDp(1:54,:),2)));
% fprintf('NH22P SST vs. dDp R (0-60 ka): %f\n', R1)
% [F2,R2] = ebisuzaki(SSTint(55:end,:),squeeze(nanmean(nh22p.dDp(55:end,:),2)));
% fprintf('NH22P SST vs. dDp R (61-144 ka): %f\n', R2)
% 
% f1 = figure(1); clf;
% scatter(SSTint(1:54,:),squeeze(nanmean(nh22p.dDp(1:54,:),2)),100,'markerfacecolor','r','markeredgecolor','k'); hold on
% scatter(SSTint(55:end,:),squeeze(nanmean(nh22p.dDp(55:end,:),2)),100,'markerfacecolor','b','markeredgecolor','k'); box on
% xlabel('SST (°C)');
% ylabel('\deltaD_{rain}');
% legend('0-60 ka','61-144 ka','location','northeast');


% Interpolate LR04 data to match dDp resolution
delob_int = interp1(delob(1:153,1),delob(1:153,2),Guay.age,'linear','extrap');

% Do Ebisuzaki Significance Test - d18O & dDp
[F1,R1] = ebisuzaki(squeeze(nanmean(Guay.dDp,2)),delob_int);
fprintf('DSDP-480/479 dDp vs. LR04 d18O R (0-152 ka): %f\n', R1)
[F2,R2] = ebisuzaki(squeeze(nanmean(Guay.dDp(26:end,:),2)),delob_int(26:end,:));
fprintf('DSDP-480/479 dDp vs. LR04 d18O R (35-152 ka): %f\n', R2)
[F3,R3] = ebisuzaki(squeeze(nanmean(Guay.dDp(1:25,:),2)),delob_int(1:25,:));
fprintf('DSDP-480/479 dDp vs. LR04 d18O R (0-34 ka): %f\n', R3)

f2 = figure(2); clf;
%scatter(delob_int,squeeze(nanmean(Guay.dDp,2)),100,'markerfacecolor','r','markeredgecolor','k'); hold on
scatter(delob_int(1:25,:),squeeze(nanmean(Guay.dDp(1:25,:),2)),100,'markerfacecolor','r','markeredgecolor','k'); hold on
scatter(delob_int(26:end,:),squeeze(nanmean(Guay.dDp(26:end,:),2)),100,'markerfacecolor','b','markeredgecolor','k'); box on
xlabel('LR04 \delta^{18}O_{benthic}');
ylabel('\deltaD_{rain}');
legend('0-34 ka','35-152 ka','location','southwest');