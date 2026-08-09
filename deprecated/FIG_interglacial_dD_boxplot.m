close all; clear all; clc;

%  FIG: BOX PLOT OF INTERGLACIAL dDp VALUES
%
%
%   Dervla Meegan Kumar
%   June 2022
%

% Set Figure defaults
set(0,'DefaultAxesFontWeight','bold','DefaultAxesFontSize',12);
set(0,'DefaultTextFontWeight','bold','DefaultTextFontSize',12);
set(groot, 'DefaultAxesLineWidth',.5,...
           'DefaultAxesXColor', [0,0,0],...
           'DefaultAxesYColor', [0,0,0],...
           'DefaultAxesZColor', [0,0,0]);
       
%%
cd '/Users/dervlamk/Library/CloudStorage/OneDrive-UCIrvine/research/eastern_pacific_cores/NH22P/data'
load nh22p_FAMEs_var_drift_07-Jun-2024.mat
Holocene_ages = nh22p.age < 11.7;                  
LIG_ages      = nh22p.age < 130 & nh22p.age > 117; 
LGM_ages      = nh22p.age < 27 & nh22p.age > 11.7; 
Hol22p        = median(nh22p.dDp(Holocene_ages==1,:),2,'omitnan');
LIG22p        = median(nh22p.dDp(LIG_ages==1,:),2,'omitnan');
LGM22p        = median(nh22p.dDp(LGM_ages==1,:),2,'omitnan');


cd '/Users/dervlamk/Library/CloudStorage/OneDrive-UCIrvine/research/eastern_pacific_cores/DSDP-480-479/data'
load Guaymas_d480_d479_FAMEs_06-May-2024.mat
Holocene_ages = Guay.age < 11.7;                   
LIG_ages      = Guay.age < 130 & Guay.age > 117; 
LGM_ages      = Guay.age < 27 & Guay.age > 11.7; 
Hol480        = median(Guay.dDp(Holocene_ages==1,:),2,'omitnan');
LIG480        = median(Guay.dDp(LIG_ages==1,:),2,'omitnan');
LGM480        = median(Guay.dDp(LGM_ages==1,:),2,'omitnan');

%%
f1 = figure(1); clf; hold on;

% combine data into a single vector
intglc = [Hol480; LIG480; Hol22p; LIG22p];

% create grouping variable
g1 = repmat({'Hol480'},size(Hol480));
g2 = repmat({'LIG480'},size(LIG480));
g3 = repmat({'Hol22p'},size(Hol22p));
g4 = repmat({'LIG22p'},size(LIG22p));
g = [g1; g2; g3; g4];

ymin = -80;
ymax = -42;

boxplot(intglc, g, 'Whisker', 1, 'color', 'k')
ylabel('\delta D_{precip}');
set(gca,...
    'Ylim',[ymin ymax],...
    'YTick',[-80:5:-40]);  

% Fig properties
set(f1,'PaperOrientation','portrait',...
       'Position',  [0, 0, 700, 500])
%cd '/Users/dervlamk/Google Drive/My Drive/Research/NAM'
%print('-f1','-bestfit','-painters','Interglacial_dDwax_boxplot','-dpdf')