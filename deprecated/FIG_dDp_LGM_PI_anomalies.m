close all; clear all; clc;
%  FIG: iCESM PRECIP ISOTOPES VS. PROXY DATA
%
%
%   Dervla Meegan Kumar
%   April 2022
%

% Set Figure defaults
set(0,'DefaultAxesFontWeight','bold','DefaultAxesFontSize',12);
set(0,'DefaultTextFontWeight','bold','DefaultTextFontSize',12);
set(groot, 'DefaultAxesLineWidth',.5,...
           'DefaultAxesXColor', [0,0,0],...
           'DefaultAxesYColor', [0,0,0],...
           'DefaultAxesZColor', [0,0,0]);
       
%% LOAD & PROCESS DATA

% Read in proxy data, calculate dDp LGM-PI anomalies based on raw dDwax
% values rather than dDivc for comparison with with iCESM dDp data as the
% latter includes the effects of the ice sheets (i.e. dDp during glacial
% will be more positive than otherwise due to light isotopes locked up in
% ice sheets)

cd '/Users/dervlakumar/Google_Drive/Research/GoC_Cores/Data/NH22P'
load nh22p_FAMEs_19-May-2022.mat
Holocene_ages = nh22p.age < 4;                   
Glacial_ages  = nh22p.age < 24 & nh22p.age > 18.5; 
dDpMean22p    = nanmean(nh22p.dDp,2);
dDpAnom22p    = mean(dDpMean22p(Glacial_ages==1,1)) - mean(dDpMean22p(Holocene_ages==1,1));


cd '/Users/dervlakumar/Google_Drive/Research/GoC_Cores/Data/DSDP480-479'
load Guaymas_d480_d479_FAMEs_19-May-2022.mat
Holocene_ages  = Guay.age < 4;                   
Glacial_ages   = Guay.age < 24 & Guay.age > 18.5; 
dDpMean480    = nanmean(Guay.dDp,2);
dDpAnom480    = mean(dDpMean480(Glacial_ages==1,1)) - mean(dDpMean480(Holocene_ages==1,1));

clearvars Holocene_ages Glacial_ages dDpMean22p dDpMean480

% iCESM model data
cd '/Users/dervlakumar/Google_Drive/Research/iCESM'
load('UV_winds_CESM.mat','usfc_lgm','usfc_pi','vsfc_lgm','vsfc_pi')
uAnom      = usfc_lgm - usfc_pi;
vAnom      = vsfc_lgm - vsfc_pi;

% iCESM data from lab drive
cd '/Volumes/lab/iCESM/LGMclimatologies'
load('icesm_atm.mat','lat','lon','dDp_lgm','dDp_pi','precip_lgm','precip_pi')

% need to calculate precipitation-weighted dDp to compare with proxy dD
% data. First, permute matrices so dimensions are [time x lat x lon], then
% weight by precipitation amount to calculate seasonal and mean dDp.
dDp_lgm     = permute(dDp_lgm,[3,2,1]);
dDp_pi      = permute(dDp_pi,[3,2,1]);
precip_lgm  = permute(precip_lgm,[3,2,1]);
precip_pi   = permute(precip_pi,[3,2,1]);

%%% LGM %%%
% weight monthly dDp values by monthly precipitation
dDp_WtMonthly_lgm = NaN(12,96,144);
for i=1:12
    dDp_WtMonthly_lgm(i,:,:) = squeeze(dDp_lgm(i,:,:) .* precip_lgm(i,:,:));
end; clearvars i

% Calculate weighted mean annual dDp
precipTotal_lgm = zeros(96,144);
for i = 1:12
    p               = squeeze(precip_lgm(i,:,:));
    precipTotal_lgm = precipTotal_lgm + p;
end; clearvars i p

a = zeros(96,144);
for i = 1:12
    b = squeeze(dDp_WtMonthly_lgm(i,:,:));
    a = a + b;
end
dDp_WtMean_lgm = a ./ precipTotal_lgm; clearvars a b i


% Calculate weighted winter (DJF) dDp
precipDJF_lgm = zeros(96,144);
for i = [1,2,12]
    p             = squeeze(precip_lgm(i,:,:));
    precipDJF_lgm = precipDJF_lgm + p;
end; clearvars i p

a = zeros(96,144);
for i = [1,2,12]
    b = squeeze(dDp_WtMonthly_lgm(i,:,:));
    a = a + b;
end
dDp_WtDJF_lgm = a ./ precipDJF_lgm; clearvars a b i


% Calculate weighted winter (JFM) dDp
precipJFM_lgm = zeros(96,144);
for i = 1:3
    p             = squeeze(precip_lgm(i,:,:));
    precipJFM_lgm = precipJFM_lgm + p;
end; clearvars i p

a = zeros(96,144);
for i = 1:3
    b = squeeze(dDp_WtMonthly_lgm(i,:,:));
    a = a + b;
end
dDp_WtJFM_lgm = a ./ precipJFM_lgm; clearvars a b i


% Calculate weighted winter (JJA) dDp
precipJJA_lgm = zeros(96,144);
for i = 6:8
    p             = squeeze(precip_lgm(i,:,:));
    precipJJA_lgm = precipJJA_lgm + p;
end; clearvars i p

a = zeros(96,144);
for i = 6:8
    b = squeeze(dDp_WtMonthly_lgm(i,:,:));
    a = a + b;
end
dDp_WtJJA_lgm = a ./ precipJJA_lgm; clearvars a b i


% Calculate weighted summer (JAS) dDp
precipJAS_lgm = zeros(96,144);
for i = 7:9
    p             = squeeze(precip_lgm(i,:,:));
    precipJAS_lgm = precipJAS_lgm + p;
end; clearvars i p

a = zeros(96,144);
for i = 7:9
    b = squeeze(dDp_WtMonthly_lgm(i,:,:));
    a = a + b;
end
dDp_WtJAS_lgm = a ./ precipJAS_lgm; clearvars a b i


                     
%%%%%%%%%%%%% PI %%%%%%%%%%%%%%%%%
dDp_WtMonthly_pi = NaN(12,96,144);
for i=1:12
    dDp_WtMonthly_pi(i,:,:) = dDp_pi(i,:,:) .* precip_pi(i,:,:);
end; clearvars i


% Calculate weighted mean annual dDp
precipTotal_pi = zeros(96,144);
for i = 1:12
    p               = squeeze(precip_pi(i,:,:));
    precipTotal_pi = precipTotal_pi + p;
end; clearvars i p

a = zeros(96,144);
for i = 1:12
    b = squeeze(dDp_WtMonthly_pi(i,:,:));
    a = a + b;
end
dDp_WtMean_pi = a ./ precipTotal_pi; clearvars a b i


% Calculate weighted winter (DJF) dDp
precipDJF_pi = zeros(96,144);
for i = [1,2,12]
    p             = squeeze(precip_pi(i,:,:));
    precipDJF_pi = precipDJF_pi + p;
end; clearvars i p

a = zeros(96,144);
for i = [1,2,12]
    b = squeeze(dDp_WtMonthly_pi(i,:,:));
    a = a + b;
end
dDp_WtDJF_pi = a ./ precipDJF_pi; clearvars a b i


% Calculate weighted winter (JFM) dDp
precipJFM_pi = zeros(96,144);
for i = 1:3
    p             = squeeze(precip_pi(i,:,:));
    precipJFM_pi = precipJFM_pi + p;
end; clearvars i p

a = zeros(96,144);
for i = 1:3
    b = squeeze(dDp_WtMonthly_pi(i,:,:));
    a = a + b;
end
dDp_WtJFM_pi = a ./ precipJFM_pi; clearvars a b i


% Calculate weighted winter (JJA) dDp
precipJJA_pi = zeros(96,144);
for i = 6:8
    p             = squeeze(precip_pi(i,:,:));
    precipJJA_pi = precipJJA_pi + p;
end; clearvars i p

a = zeros(96,144);
for i = 6:8
    b = squeeze(dDp_WtMonthly_pi(i,:,:));
    a = a + b;
end
dDp_WtJJA_pi = a ./ precipJJA_pi; clearvars a b i


% Calculate weighted summer (JAS) dDp
precipJAS_pi = zeros(96,144);
for i = 7:9
    p             = squeeze(precip_pi(i,:,:));
    precipJAS_pi = precipJAS_pi + p;
end; clearvars i p

a = zeros(96,144);
for i = 7:9
    b = squeeze(dDp_WtMonthly_pi(i,:,:));
    a = a + b;
end
dDp_WtJAS_pi = a ./ precipJAS_pi; clearvars a b i

                    
% calculate iCESM dDp LGM-PI anomalies
dDp_WtMeanAnom = dDp_WtMean_lgm - dDp_WtMean_pi;
dDp_WtDJFAnom  = dDp_WtDJF_lgm  - dDp_WtDJF_pi;
dDp_WtJFMAnom  = dDp_WtJFM_lgm  - dDp_WtJFM_pi;
dDp_WtJJAAnom  = dDp_WtJJA_lgm  - dDp_WtJJA_pi;
dDp_WtJASAnom  = dDp_WtJAS_lgm  - dDp_WtJAS_pi;

%% MAKE FIG

f1 = figure(1); clf; 

% define parameters
nh22pCoords   = [253.4817, 22.5183];
dsdp480Coords = [248.38, 27.85];
labels        = {'a. MEAN ANNUAL'; 'b. JFM'; 'c. JAS'};
[X,Y]         = meshgrid(lon,lat);
contour_scl   = [-35:1:30];
colorbar_scl  = [-17 17];
lonlim        = [230 295];
latlim        = [-5 40];

for i=1:3
    subplot(3,1,i); hold on; box on;
    title(labels{i,1});
    m_proj('Miller','lon',lonlim,'lat',latlim);
    if i == 1
        %LGM-PI dDp mean annual
        m_contourf(X,Y,dDp_WtMeanAnom,...
                   contour_scl,'color','none');
                   colormap(brewermap(60,'PuOr'));
    elseif i == 2
        %LGM-PI dDp DJF
        m_contourf(X,Y,dDp_WtJFMAnom,...
                   contour_scl,'color','none');
                   colormap(brewermap(60,'PuOr'));
    else
        %LGM-PI dDp JJA
        m_contourf(X,Y,dDp_WtJASAnom,...
                   contour_scl,'color','none');
                   colormap(brewermap(34,'PuOr'));
    end
    caxis(colorbar_scl);
    %plot basemap
    m_coast('color','k',...
            'linewidth',.75);
    m_gshhs('fb1',...
            'color','k',...
            'linewidth',.75);
    %plot dDp core anomalies
    m_scatter(nh22pCoords(:,1),nh22pCoords(:,2),...
              50,...
              dDpAnom22p,'o','filled',...
              'markeredgecolor','k');
    m_scatter(dsdp480Coords(:,1),dsdp480Coords(:,2),...
              50,...
              dDpAnom480,'o','filled',...
              'markeredgecolor','k');
    %subfig properties
    m_grid('xtick',[200:20:300],...
           'xaxisloc','bottom',...
           'ytick',[-5:10:35],...
           'linewidth',1,...
           'tickdir','out');
    cbx = colorbar('position',[.9 0.4 0.02 0.2],'orientation','vertical');
    set(get(cbx,'title'),'string',{char(8240),''});
    %cbarrow
end
    
    
% Fig properties
set(f1,'PaperOrientation','portrait',...
       'Position',  [0, 0, 700, 900])
cd '/Users/dervlakumar/Google_Drive/Research/NAM'
%print('-f1','-bestfit','-painters','dDp_LGM-PI_anomalies_iCESMvsCores_weighted','-dpdf')


%% MAKE FIG - climatologies

f2 = figure(2); clf; 

% define parameters
nh22pCoords   = [253.4817, 22.5183];
dsdp480Coords = [248.38, 27.85];
labels        = {'a. MEAN ANNUAL'; 'b. DJF'; 'c. JJA'};
[X,Y]         = meshgrid(lon,lat);
contour_scl   = [-150:5:10];
colorbar_scl  = [-150 10];
lonlim        = [240 285];
latlim        = [5 45];
vecscl1       = 80;
headlength    = 1.2;
shwidth       = 0.001;

for i=1:3
    subplot(1,3,i); hold on; box on;
    title(labels{i,1});
    m_proj('Miller','lon',lonlim,'lat',latlim);
    if i == 1
        %LGM-PI dDp mean annual
        m_contourf(X,Y,dDp_WtMean_lgm,...
                   contour_scl,'color','none');
                   colormap(brewermap(60,'PuOr'));
        %plot surface wind vectors
        m_vec(vecscl1,X,Y,...
            squeeze(mean(usfc_lgm,1)),...
            squeeze(mean(vsfc_lgm,1)),...
            'k',...
            'centered','yes','shaftwidth',shwidth,'headlength',headlength,'edgeclip','on');
    elseif i == 2
        %LGM-PI dDp JFM
        m_contourf(X,Y,dDp_WtJFM_lgm,...
                   contour_scl,'color','none');
                   colormap(brewermap(60,'PuOr'));
        %plot surface wind vectors
        m_vec(vecscl1,X,Y,...
            squeeze(mean(usfc_lgm(1:3,:,:),1)),...
            squeeze(mean(vsfc_lgm(1:3,:,:),1)),...
            'k',...
            'centered','yes','shaftwidth',shwidth,'headlength',headlength,'edgeclip','on');
    else
        %LGM-PI dDp JAS
        m_contourf(X,Y,dDp_WtJAS_lgm,...
                   contour_scl,'color','none');
                   colormap(brewermap(34,'PuOr'));
        %plot surface wind vectors
        m_vec(vecscl1,X,Y,...
            squeeze(mean(usfc_lgm(7:9,:,:),1)),...
            squeeze(mean(vsfc_lgm(7:9,:,:),1)),...
            'k',...
            'centered','yes','shaftwidth',shwidth,'headlength',headlength,'edgeclip','on');
    end
    caxis(colorbar_scl);
    %plot basemap
    m_coast('color','k',...
            'linewidth',.75);
    m_gshhs('fb1',...
            'color','k',...
            'linewidth',.75);
    %plot dDp core anomalies
    m_scatter(nh22pCoords(:,1),nh22pCoords(:,2),...
              50,...
              dDpAnom22p,'o','filled',...
              'markeredgecolor','k');
    m_scatter(dsdp480Coords(:,1),dsdp480Coords(:,2),...
              50,...
              dDpAnom480,'o','filled',...
              'markeredgecolor','k');
    %subfig properties
    m_grid('xtick',[200:20:300],...
           'xaxisloc','bottom',...
           'ytick',[-5:10:35],...
           'linewidth',1,...
           'tickdir','out');
    cbx = colorbar('position',[.9 0.4 0.02 0.2],'orientation','vertical');
    set(get(cbx,'title'),'string',{char(8240),''});
    %cbarrow
end
    
    
% Fig properties
set(f1,'PaperOrientation','portrait',...
       'Position',  [0, 0, 700, 900])
cd '/Users/dervlakumar/Google_Drive/Research/NAM'
%print('-f1','-bestfit','-painters','dDp_LGM-PI_anomalies_iCESMvsCores_weighted','-dpdf')
