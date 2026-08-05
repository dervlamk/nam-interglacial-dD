%%  CODE TO CORRECT FOR d13C (C3/C4) CONTRIBUTION & ESTIMATE dDprecip BASED ON VARIABLE EPSILON
%   (modified code originally written by Jess Tierney & Tripti Bhattacharya)
%
%
%   Dervla Meegan Kumar
%   April 2022
%

%%  NH22P

%load data
cd '/Users/dervlamk/OneDrive/research/eastern_pacific_cores/NH22P/data'
load lr04.mat                                  %LR04 data for calculating ice volume correction
filename     = 'dD_nh22p.xls';
opts         = detectImportOptions(filename);
opts.Sheet   = 'dD_nh22p';
dD_nh22p     = readmatrix(filename,opts);
nh22p.age    = dD_nh22p(:,1)./1000; %ka
nh22p.dDraw  = dD_nh22p(:,2);
nh22p.stddev = dD_nh22p(:,3);
%do ice volume correction of dD data
nh22p.dDivc  = icevolcorr(nh22p.age,nh22p.dDraw,2,2);                       clearvars delob delob_age deloscaled filename opts dD_nh22p


%set d13C endmembers
c4end  = -24.2;        %C4 mean -22;
c4std  = 3.2;          %C4 standard error, adjusted 9/17/2021 for Desert Museum Samples
c3end  = -32.7;        %C3 mean -34
c3std  = 4;            %C3 stdev/sqrt number of samples


%set dD epilson endmembers
c4dd   = -107.8;      %Desert Museum Compilation, only includes 3 taxa, but in ballpark of western US measurements of Sachse
c4dd_s = 3.7;         %stdev/n-1
c3dd   = -82;         %C3 dicots, Sachse et al. 2012 -113
c3dd_s = 1;           %stdev/n-1


%set number of iterations
iters = 2500;


%uniform assumption:
m = 0.5;
n = 2;


age = ones(length(nh22p.dDraw));

%create vector of d13C values corresponding to glacial/interglacial mean
%values based on Bhattacharya et al., 2018, where:
%       mean glacial d13Cwax      = -27.16
%       mean interglacial d13Cwax = -26.67
d13C_glc      = -27.16;
d13C_intglc   = -26.67;
Holocene_ages = nh22p.age < 18.5;                   d13C(Holocene_ages==1,1) = d13C_intglc;
Glacial_ages  = nh22p.age < 115 & nh22p.age > 18.5; d13C(Glacial_ages==1,1)  = d13C_glc;
LIG_ages      = nh22p.age > 115 & nh22p.age < 130;  d13C(LIG_ages==1,1)      = d13C_intglc;
LGlacial_ages = nh22p.age > 130;                    d13C(LGlacial_ages==1,1) = d13C_glc;

%d13c = Coretop_d13C;
%d13c = -34.*ones(length(IVcorr),1)+2.*randn(length(IVcorr),1);
%d13c = interp1(d13C_raw(:,1),d13C_raw(:,2),dD(:,1),'previous','extrap');
std_d = ones(length(nh22p.dDivc),1)*2;


%define output matrices
f4      = NaN(length(age),iters);
dDp_est = NaN(length(age),iters);
%calculate estimated fraction of C4 & epsilon via Monte Carlo
for i=1:iters
    %likelihood of C4 plant:
    c4 = normrnd(c4end,c4std);
    c3 = normrnd(c3end,c3std);
    N  = 5000;
    %enter d13c data here
    Y  = ((d13C(:,1)+normrnd(0,0.2))-c3)./(c4-c3)*N;
    %Bayesian posterior
    a       = Y + (n*m)-1;
    b       = N-Y + (n*(1-m)) - 1;
    f4(:,i) = betarnd(a,b);
    c4d     = normrnd(c4dd,c4dd_s);
    c3d     = normrnd(c3dd,c3dd_s);
    ep      = (f4(:,i).*c4d)+((1-f4(:,i)).*c3d);                            %epsilon value
    %add in analytical standard dev to ice volume corrected dD values
    stddev_anl   = 2;                                                       %set analytical standard dev
    %dD_WithErr   = nh22p.dDivc + stddev_anl*randn(length(nh22p.dDivc),1);
    dD_WithErr   = nh22p.dDraw + stddev_anl*randn(length(nh22p.dDraw),1);   %do with raw dD values to compare directly to iCESM output (which has ice effects included)
    %apply epsilon to dDp estimate
    dDp_est(:,i) = (1000+dD_WithErr)./(ep/1000+1)-1000;
end


%plot mean to check values
plot(nh22p.age,nanmean(dDp_est,2),'-r')


%save data
nh22p.dDp_raw   = dDp_est;
%nh22p.epsilon   = ep;
%nh22p.d13c      = d13C;
%nh22p.fC4       = f4;
save(['nh22p_FAMEs_',date,'.mat'],'nh22p');

%% DSDP-480

%load data
cd '/Users/dervlamk/OneDrive/research/eastern_pacific_cores/DSDP-480-479/data'
load lr04.mat                                  %LR04 data for calculating ice volume correction
filename    = 'd480-479_dD.xlsx';
opts        = detectImportOptions(filename);

%DSDP-480
opts.Sheet  = 'd480_dD_good';
dD_d480     = readmatrix(filename,opts);
d480.depth  = dD_d480(:,1);         %m
d480.age    = dD_d480(:,2)./1000;   %ka
d480.dDraw  = dD_d480(:,4);
d480.stddev = dD_d480(:,3);
%do ice volume correction of dD data
d480.dDivc  = icevolcorr(d480.age,d480.dDraw,2,2);                       clearvars dD_d480

%DSDP-479
opts.Sheet  = 'd479_dD_good';
dD_d479     = readmatrix(filename,opts);
d479.depth  = dD_d479(:,1);         %m
d479.age    = dD_d479(:,2)./1000;   %ka
d479.dDraw  = dD_d479(:,4);
d479.stddev = dD_d479(:,3);
%do ice volume correction of dD data
d479.dDivc  = icevolcorr(d479.age,d479.dDraw,2,2);                       clearvars delob delob_age deloscaled filename opts dD_d479


%create vector of d13C values corresponding to glacial/interglacial mean
%values based on NH8P d13C measurements from Bhattacharya et al., 2018
%   where:
%       mean glacial d13Cwax      = -27.16
%       mean interglacial d13Cwax = -26.67
d13C_glc      = -27.16;
d13C_intglc   = -26.67;
Holocene_ages = d480.age < 18.5;                   d13C(Holocene_ages==1,1) = d13C_intglc;
Glacial_ages  = d480.age < 115 & d480.age > 18.5;  d13C(Glacial_ages==1,1)  = d13C_glc;
LIG_ages      = d480.age > 115 & d480.age < 130;   d13C(LIG_ages==1,1)      = d13C_intglc;
LGlacial_ages = d480.age > 130;                    d13C(LGlacial_ages==1,1) = d13C_glc;


%set d13C endmembers based on Desert Museum Samples
c4end  = -24.2;        %C4 mean -22;
c4std  = 3.2;          %C4 standard error, adjusted 9/17/2021 for Desert Museum Samples
c3end  = -32.7;        %C3 mean -34
c3std  = 4;            %C3 stdev/sqrt number of samples


%set dD epilson endmembers based on Desert Museum Samples
c4dd   = -107.8;      %Desert Museum Compilation, only includes 3 taxa, but in ballpark of western US measurements of Sachse
c4dd_s = 3.7;         %stdev/n-1
c3dd   = -82;         %C3 dicots, Sachse et al. 2012 -113
c3dd_s = 1;           %stdev/n-1


%set number of iterations
iters = 2500;

%uniform assumption:
m = 0.5;
n = 2;

% >> I'm not sure what the following three lines are for from Tripti's
% >> original code
age = ones(length(d480.dDraw));
%d13c = -34.*ones(length(IVcorr),1)+2.*randn(length(IVcorr),1);             >> seems to be for creating a random d13C vector?
%std_d = ones(length(d480.dDivc),1)*2;


%define output matrices
f4      = NaN(length(age),iters);
dDp_est = NaN(length(age),iters);
%calculate estimated fraction of C4 & epsilon via Monte Carlo
for i=1:iters
    %likelihood of C4 plant:
    c4 = normrnd(c4end,c4std);
    c3 = normrnd(c3end,c3std);
    N  = 5000;
    %enter d13c data here
    Y  = ((d13C(:,1)+normrnd(0,0.2))-c3)./(c4-c3)*N;
    %Bayesian posterior
    a       = Y + (n*m)-1;
    b       = N-Y + (n*(1-m)) - 1;
    f4(:,i) = betarnd(a,b);
    c4d     = normrnd(c4dd,c4dd_s);
    c3d     = normrnd(c3dd,c3dd_s);
    ep      = (f4(:,i).*c4d)+((1-f4(:,i)).*c3d);                            %epsilon
    %add in analytical standard dev to ice volume corrected dD
    std_anl      = 2;                                                       %set analytical standard dev
    %dD_WithErr   = d480.dDivc + std_anl*randn(length(d480.dDivc),1);
    dD_WithErr   = d480.dDraw + std_anl*randn(length(d480.dDraw),1);
    %apply epsilon to dDp estimate
    dDp_est(:,i) = (1000+dD_WithErr)./(ep/1000+1)-1000;
end


%plot mean to check values
plot(d480.age,nanmean(dDp_est,2),'-r')


%save data
d480.dDp_raw     = dDp_est;
%d480.epsilon     = ep;
%d480.d13c        = d13C;
%d480.fC4         = f4;
save(['d480_FAMEs_',date,'.mat'],'d480');

