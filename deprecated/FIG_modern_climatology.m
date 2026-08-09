close all; clear all; clc;
% Make figure of modern NAM climatology
% processing of ERA wind data and code for plotting thanks to Matt Osman
% (2022). 

% load in GPCC data and define seasonal averages
cd '/Users/dervlakumar/Google_Drive/Research/reanalysis_products/GPCC'
load gpcc_1891-2019_monthly_averages.mat
gpcc.lat = double(lat); gpcc.lon = double(lon); 
gpcc.jfm = squeeze((gpccMonthly(1,:,:)+gpccMonthly(2,:,:)+gpccMonthly(3,:,:))./90); 
gpcc.jas = squeeze((gpccMonthly(7,:,:)+gpccMonthly(8,:,:)+gpccMonthly(9,:,:))./92);
%gpcc.jas = squeeze(nanmean(gpccMonthly(7:9,:,:),1));                        clearvars lat lon month gpccMonthly precip

% load in ERA5 wind data, define seasonal averages, & regrid to 2° x 2°
cd '/Users/dervlakumar/Google_Drive/Research/reanalysis_products/ERA'
load era5_850mb_winds.mat % load uwind_mon, vwind_mon, lat_era, lon_era
U.lat = lat_era; U.lon = lon_era; 
U.jfm = squeeze(nanmean(uwind_mon(1:3,:,:))); 
U.jas = squeeze(nanmean(uwind_mon(7:9,:,:))); 
V.lat = lat_era; V.lon = lon_era; 
V.jfm = squeeze(nanmean(vwind_mon(1:3,:,:))); 
V.jas = squeeze(nanmean(vwind_mon(7:9,:,:)));                               clearvars lat_era lon_era time uwind_mon vwind_mon
% define lat / lon based on resolution 
res = 2; 
lon = [(0 + res/2):res:(360 - res/2)]'; 
lat = [(-90 + res/2):res:(90 - res/2)]'; 
% regrid each year and each timestep
lon2D = double(repmat(U.lon,[1,size(U.jfm,2)])); 
lat2D = double(repmat(U.lat',[size(U.jfm,1),1])); 
U.jfm = griddata(lon2D,lat2D,U.jfm,lon,lat')';
U.jas = griddata(lon2D,lat2D,U.jas,lon,lat')';
V.jfm = griddata(lon2D,lat2D,V.jfm,lon,lat')';
V.jas = griddata(lon2D,lat2D,V.jas,lon,lat')';
% redefine lat lon in U/V
U.lat = lat; U.lon = lon; 
V.lat = lat; V.lon = lon;                                                   clearvars lat lon lon2D lat2D res

%%
h = figure(1); clf; hold on; 
    set(h,'units','centimeters','position',[2,1,20,24]);
    set(h,'PaperPositionMode','auto','PaperOrientation','portrait'); ax = gca; ax.Visible = 'off';
    
% set figure parameters
nh22pCoords   = [253.4817, 22.5183];
dsdp480Coords = [248.3443, 27.90167]; %-111.6557
dsdp479Coords = [248.3752, 27.846];   %-111.6248
colors = brewermap(24,'Blues');
cLim   = [0 8]; 
latLim = [5 45];
lonLim = [-140 -90];
land   = shaperead('landareas.shp','UseGeoCoords',true); % load continents for plotting

projection = 'eqdcylin'; % eqdcylin, robinson
ax1 = axes('Position',[0.2 0.1 0.6 0.8],'LineWidth',1.0); 
	%set(gca,'Visible','off'); 
    ax = axesm(projection,'MapLatLimit',latLim,'MapLonLimit',lonLim,'Fontsize',10,'Fontweight','Bold','Frame','on'); % axis off; hold on;    
    gridm('on'); ax.Clipping = 'off';  mlabel on; plabel on; tightmap; % warning('off');
    gridm('PLabelLocation',10,'MLabelLocation',10); 
    pcolorm(gpcc.lat,gpcc.lon,gpcc.jas); shading flat; 
        quivFreq = 1;
        latAdj   = U.lat(1:quivFreq:end); lonAdj = U.lon(1:quivFreq:end); 
        latOrig  = repmat(U.lat,[1,size(U.jas,1)])'; lonOrig = repmat(U.lon',[size(U.jas,2),1])';
        umap     = griddata(lonOrig,latOrig,U.jas,lonAdj,latAdj')';
        vmap     = griddata(lonOrig,latOrig,V.jas,lonAdj,latAdj')';
        latAdj   = repmat(latAdj',[size(umap,1),1]); lonAdj = repmat(lonAdj,[1,size(umap,2)]); 
        q        = quiverm(latAdj,lonAdj,vmap,umap,'k',1.5,'filled'); shading flat; % 
    % draw land outline
    setm(gca,'FLineWidth',1.0,'Frame', 'on','Grid', 'off')
    geoshow(land,'FaceColor', 'none','Linewidth',1.0,'EdgeColor','k'); 
    % add site markers
    scatterm(dsdp480Coords(:,2), dsdp480Coords(:,1),125,'filled','markerfacecolor','y','markeredgecolor','k');
    scatterm(dsdp479Coords(:,2), dsdp479Coords(:,1),125,'filled','markerfacecolor','y','markeredgecolor','k');
    scatterm(nh22pCoords(:,2),   nh22pCoords(:,1),  125,'filled','markerfacecolor','y','markeredgecolor','k');
    % define colormap, colorbar
    colormap(ax,colors);
    caxis(cLim);  % set colormap  
    c=colorbar('eastoutside'); c.LineWidth = 1.0; 
    	c.Label.String = ['mm day^{-1}']; set(c,'Fontsize',10); 
    	c.Position = [0.85 0.3 0.025 0.35];
