close all; clear all; clc;
% Make figure of modern wind and precip data compared to iCESM PI simulations
% processing of ERA wind data and code for plotting thanks to Matt Osman
% (2022). 

% load in CESM PI precip data and define seasonal averages
cd '/Volumes/lab/iCESM/LGMclimatologies'
load('icesm_atm.mat','lat','lon','precip_pi')
precipPI.lon  = lon; precipPI.lat  = lat;
precipPI.mean = squeeze(mean(precip_pi,3));
precipPI.jfm  = permute(squeeze(mean(precip_pi(:,:,1:3),3)),[2,1]);
precipPI.jas  = permute(squeeze(mean(precip_pi(:,:,7:9),3)),[2,1]);         clearvars lat lon precip_pi

% load in CESM PI wind data and define seasonal averages
cd '/Users/dervlakumar/Google_Drive/Research/iCESM'
load('UV_winds_CESM.mat','lat','lon','usfc_pi','vsfc_pi');
uPI.lat = lat; uPI.lon = lon;
uPI.jfm = squeeze(mean(usfc_pi(1:3,:,:),1));
uPI.jas = squeeze(mean(usfc_pi(7:9,:,:),1));
vPI.lat = lat; vPI.lon = lon;
vPI.jfm = squeeze(mean(vsfc_pi(1:3,:,:),1));
vPI.jas = squeeze(mean(vsfc_pi(7:9,:,:),1));                                clearvars lat lon usfc_pi vsfc_pi

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

%% Make Fig

% create vector of panel labels
label = {'a.'; 'b.'; 'c.'; 'd.'};

cLim = [0 8]; 
latLim = [10 40];
lonLim = [-120 -90];

% assign colormap
% cd 'cbrewer' 
%     colors = cbrewer('div','RdBu' ,25);  colors(colors<0) = 0; colors(colors>1) = 1;
% cd ../
colors = brewermap(24,'Blues');

% load continents for plotting
land = shaperead('landareas.shp','UseGeoCoords',true);
% load coastlines.mat % loads coastlat and coastlon
     
h = figure; hold on; 
    set(h,'units','centimeters','position',[2,1,28,14]);
    set(h,'PaperPositionMode','auto','PaperOrientation','landscape'); ax = gca; ax.Visible = 'off';

% labels:
axa = axes('position', [0.275 0.86 0.10 0.10]); set(gca, 'visible', 'off'); text(0,0,'JFM - observed','Fontsize',12,'Fontweight','Bold','HorizontalAlignment','center');
axb = axes('position', [0.70 0.86 0.10 0.10]); set(gca, 'visible', 'off'); text(0,0,'JAS - observed','Fontsize',12,'Fontweight','Bold','HorizontalAlignment','center');

% JFM - observed
projection = 'eqdcylin'; % eqdcylin, robinson
ax1 = axes('Position',[0.05 0.5 0.45 0.40],'LineWidth',1.0); 
	set(gca,'Visible','off'); 
    ax = axesm(projection,'MapLatLimit',latLim,'MapLonLimit',lonLim,'Fontsize',10,'Fontweight','Bold','Frame','on'); % axis off; hold on;    
    gridm('on'); ax.Clipping = 'off';  mlabel on; plabel on; tightmap; % warning('off');
    gridm('PLabelLocation',10,'MLabelLocation',10); 
    pcolorm(gpcc.lat,gpcc.lon,gpcc.jfm); shading flat; 
        quivFreq = 1;
        latAdj = U.lat(1:quivFreq:end); lonAdj = U.lon(1:quivFreq:end); 
        latOrig = repmat(U.lat,[1,size(U.jfm,1)])'; lonOrig = repmat(U.lon',[size(U.jfm,2),1])';
        umap = griddata(lonOrig,latOrig,U.jfm,lonAdj,latAdj')';
        vmap = griddata(lonOrig,latOrig,V.jfm,lonAdj,latAdj')';
        latAdj = repmat(latAdj',[size(umap,1),1]); lonAdj = repmat(lonAdj,[1,size(umap,2)]); 
        q = quiverm(latAdj,lonAdj,vmap,umap,'k',1.5,'filled'); shading flat; % 
        %q = quiverm(-115,22,10,0,'k',1.3,'filled'); shading flat; %
    % define colormap, etc
    setm(gca,'FLineWidth',1.0,'Frame', 'on','Grid', 'off')
    colormap(ax,colors); % flipped the colormap vertically, so cold = blue, hot = red ... 
    caxis(cLim);  % set colormap  
    geoshow(land,'FaceColor', 'none','Linewidth',1.0,'EdgeColor','k'); 
    text(0.935,.05,label{1,:},'units','normalized','fontsize',12,...
        'fontweight','bold','HorizontalAlignment','left');
    
% JAS - observed
projection = 'eqdcylin'; % eqdcylin, robinson
ax1 = axes('Position',[0.475 0.5 0.45 0.40],'LineWidth',1.0); 
	set(gca,'Visible','off'); 
    ax = axesm(projection,'MapLatLimit',latLim,'MapLonLimit',lonLim,'Fontsize',10,'Fontweight','Bold','Frame','on'); % axis off; hold on;    
    gridm('on'); ax.Clipping = 'off';  mlabel on; plabel on; tightmap; % warning('off');
    gridm('PLabelLocation',10,'MLabelLocation',10); 
    pcolorm(gpcc.lat,gpcc.lon,gpcc.jas); shading flat; 
        quivFreq = 1;
        latAdj = U.lat(1:quivFreq:end); lonAdj = U.lon(1:quivFreq:end); 
        latOrig = repmat(U.lat,[1,size(U.jas,1)])'; lonOrig = repmat(U.lon',[size(U.jas,2),1])';
        umap = griddata(lonOrig,latOrig,U.jas,lonAdj,latAdj')';
        vmap = griddata(lonOrig,latOrig,V.jas,lonAdj,latAdj')';
        latAdj = repmat(latAdj',[size(umap,1),1]); lonAdj = repmat(lonAdj,[1,size(umap,2)]); 
        q = quiverm(latAdj,lonAdj,vmap,umap,'k',1.5,'filled'); shading flat; % 
    % define colormap, etc
    setm(gca,'FLineWidth',1.0,'Frame', 'on','Grid', 'off')
    colormap(ax,colors); % flipped the colormap vertically, so cold = blue, hot = red ... 
    caxis(cLim);  % set colormap  
    geoshow(land,'FaceColor', 'none','Linewidth',1.0,'EdgeColor','k'); 
    text(0.935,.05,label{2,:},'units','normalized','fontsize',12,...
        'fontweight','bold','HorizontalAlignment','left');
    
    % colorbar
    c=colorbar('eastoutside'); c.LineWidth = 1.0; 
    	c.Label.String = ['mm day^{-1}']; set(c,'Fontsize',10); 
    	c.Position = [0.90 0.35 0.015 0.25];
        
% JFM - iCESM
projection = 'eqdcylin'; % eqdcylin, robinson
ax1 = axes('Position',[0.05 0.025 0.45 0.40],'LineWidth',1.0); 
	set(gca,'Visible','off'); 
    ax = axesm(projection,'MapLatLimit',latLim,'MapLonLimit',lonLim,'Fontsize',10,'Fontweight','Bold','Frame','on'); % axis off; hold on;    
    gridm('on'); ax.Clipping = 'off';  mlabel on; plabel on; tightmap; % warning('off');
    gridm('MLineLocation',10,'PLineLocation',10,'PLabelLocation',10,'MLabelLocation',10); 
    pcolorm(precipPI.lat,precipPI.lon,precipPI.jfm); shading flat; 
        quivFreq = 1;
        latAdj = uPI.lat(1:quivFreq:end); lonAdj = uPI.lon(1:quivFreq:end); 
        latOrig = repmat(uPI.lat,[1,size(uPI.jfm,2)])'; lonOrig = repmat(uPI.lon',[size(uPI.jfm,1),1])';
        umap = griddata(lonOrig,latOrig,permute(uPI.jfm,[2,1]),lonAdj,latAdj')';
        vmap = griddata(lonOrig,latOrig,permute(vPI.jfm,[2,1]),lonAdj,latAdj')';
        latAdj = repmat(latAdj',[size(umap,1),1]); lonAdj = repmat(lonAdj,[1,size(umap,2)]); 
        q = quiverm(latAdj,lonAdj,vmap,umap,'k',1.5,'filled'); shading flat; % 
    % define colormap, etc
    setm(gca,'FLineWidth',1.0,'Frame', 'on','Grid', 'off')
    colormap(ax,colors); % flipped the colormap vertically, so cold = blue, hot = red ... 
    caxis(cLim);  % set colormap  
    geoshow(land,'FaceColor', 'none','Linewidth',1.0,'EdgeColor','k');   
    text(0.935,.05,label{3,:},'units','normalized','fontsize',12,...
        'fontweight','bold','HorizontalAlignment','left');
    
% JAS - iCESM
projection = 'eqdcylin'; % eqdcylin, robinson
ax1 = axes('Position',[0.475 0.025 0.45 0.40],'LineWidth',1.0); 
	set(gca,'Visible','off'); 
    ax = axesm(projection,'MapLatLimit',latLim,'MapLonLimit',lonLim,'Fontsize',10,'Fontweight','Bold','Frame','on'); % axis off; hold on;    
    gridm('on'); ax.Clipping = 'off';  mlabel on; plabel on; tightmap; % warning('off');
    gridm('PLabelLocation',10,'MLabelLocation',10); 
    pcolorm(precipPI.lat,precipPI.lon,precipPI.jas); shading flat; 
        quivFreq = 1;
        latAdj = uPI.lat(1:quivFreq:end); lonAdj = uPI.lon(1:quivFreq:end); 
        latOrig = repmat(uPI.lat,[1,size(uPI.jas,2)])'; lonOrig = repmat(uPI.lon',[size(uPI.jas,1),1])';
        umap = griddata(lonOrig,latOrig,permute(uPI.jas,[2,1]),lonAdj,latAdj')';
        vmap = griddata(lonOrig,latOrig,permute(vPI.jas,[2,1]),lonAdj,latAdj')';
        latAdj = repmat(latAdj',[size(umap,1),1]); lonAdj = repmat(lonAdj,[1,size(umap,2)]); 
        q = quiverm(latAdj,lonAdj,vmap,umap,'k',1.5,'filled'); shading flat; hold on
        %qp = quiverm(repmat(x,5), repmat(y,5), u, v, 'k', 1.5, 'filled'); shading flat; hold on
    % define colormap, etc
    setm(gca,'FLineWidth',1.0,'Frame', 'on','Grid', 'on')
    colormap(ax,colors); % flipped the colormap vertically, so cold = blue, hot = red ... 
    caxis(cLim);  % set colormap  
    geoshow(land,'FaceColor', 'none','Linewidth',1.0,'EdgeColor','k'); 
    text(0.935,.05,label{4,:},'units','normalized','fontsize',12,...
        'fontweight','bold','HorizontalAlignment','left');    
    
            
%print('-h','-bestfit','-painters','seasonal_SST_wind_2x2era','-dpdf');