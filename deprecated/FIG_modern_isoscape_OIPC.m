close all; clear all; clc;
% FIG: Modern Climate Isotope Anomalies (OIPC)
%
%       Dervla Meegan Kumar
%       May, 2022
%

% Set Figure defaults
set(0,'DefaultAxesFontWeight','bold',...
      'DefaultAxesFontSize',12);
set(0,'DefaultTextFontWeight','bold',...
      'DefaultTextFontSize',12);
set(groot, 'DefaultAxesLineWidth',.5,...
           'DefaultAxesXColor', [0,0,0],...
           'DefaultAxesYColor', [0,0,0],...
           'DefaultAxesZColor', [0,0,0]);
       
%% Load & Process Data

cd '/Users/dervlakumar/Google_Drive/Research/NAM'
filename      = 'OIPC_monthly_data.nc';
lat           = ncread(filename,'Lat');
lon           = ncread(filename,'Lon');
oipc          = permute(ncread(filename,'isotopes'),[1,3,2]);
[oipc,lon,~]  = longitude_flip(oipc,lat,lon);

seasonalAnom  = squeeze(mean(oipc(7:9,:,:),1)-mean(oipc(1:3,:,:),1));

%% MAKE FIG - Mean and Seasonal Climatologies

f1 = figure(1); clf; 

% define parameters
nh22pCoords   = [253.4817, 22.5183];
dsdp480Coords = [248.38, 27.85];
labels        = {'a. MEAN ANNUAL'; 'b. JFM'; 'c. JAS'};
[X,Y]         = meshgrid(lon,lat);
contour_scl   = [-150:5:30];
colorbar_scl  = [-80 20];
lonlim        = [230 295];
latlim        = [-5 40];

for i=1:3
    subplot(1,3,i); hold on; box on;
    title(labels{i,1});
    m_proj('Miller','lon',lonlim,'lat',latlim);
    if i == 1
        %LGM-PI dDp mean annual
        m_contourf(X,Y,squeeze(mean(oipc,1)),...
                   contour_scl,'color','none');
                   colormap(brewermap(20,'*RdPu'));
    elseif i == 2
        %LGM-PI dDp JFM
        m_contourf(X,Y,squeeze(mean(oipc(1:3,:,:),1)),...
                   contour_scl,'color','none');
                   colormap(brewermap(20,'*RdPu'));
    else
        %LGM-PI dDp JAS
        m_contourf(X,Y,squeeze(mean(oipc(7:9,:,:),1)),...
                   contour_scl,'color','none');
                   colormap(brewermap(20,'*RdPu'));
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
              50);%,...
              %'o','filled',...
              %'markeredgecolor','k');
    m_scatter(dsdp480Coords(:,1),dsdp480Coords(:,2),...
              50);%,...
              %'o','filled',...
              %'markeredgecolor','k');
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
%print('-f1','-bestfit','-painters','dDp_LGM-PI_anomalies_iCESMvsCores_weighted','-dpdf')

%% MAKE FIG - JAS--JFM seasonal anomalies

f2 = figure(2); clf; hold on
set(gcf,'color',[.9 .9 .9])

% define parameters
nh22pCoords   = [253.4817, 22.5183];
dsdp480Coords = [248.38, 27.85];
[X,Y]         = meshgrid(lon,lat);
contour_scl   = [-150:5:150];
colorbar_scl  = [-70 70];
lonlim        = [240 280];
latlim        = [5 40];

title('Summer-Winter \deltaD_{precip} Anomalies')
m_proj('Miller','lon',lonlim,'lat',latlim);
m_contourf(X,Y,seasonalAnom,...
           contour_scl,'color','none');
           colormap(brewermap(28,'RdPu'));
           caxis(colorbar_scl);
           cbx = colorbar('position',[.25 0.05 0.6 0.02],...
               'orientation','horizontal');
            set(get(cbx,'title'),'string',{char(8240),''});
            cbarrow
%plot basemap
m_coast('color','k',...
        'linewidth',.75);
m_gshhs('fb1',...
        'color','k',...
        'linewidth',.75);
%plot core locations
m_scatter(nh22pCoords(:,1),nh22pCoords(:,2),...
          50,...
          'o','filled',...
          'markerfacecolor','k',...
          'markeredgecolor','k');
m_scatter(dsdp480Coords(:,1),dsdp480Coords(:,2),...
          50,...
          'o','filled',...
          'markerfacecolor','k',...
          'markeredgecolor','k');
%fig properties
m_grid('xtick',[200:10:300],...
       'xaxisloc','bottom',...
       'ytick',[-10:10:50],...
       'linewidth',1,...
       'tickdir','in');
    
    
% Fig properties
set(f2,'PaperOrientation','landscape',...
       'Position',  [0, 0, 600, 500])
%print('-f2','-bestfit','-painters','modern_isoscape_OIPC','-dpdf')
saveas(gcf,'modern_isoscape_OIPC', 'epsc')
