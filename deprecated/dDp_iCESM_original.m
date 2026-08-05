%assign ncfiles
cd '/Users/dervlamk/OneDrive/NCAR/CESM1.2/';
dh_lig='LIG/dh.precIsotopes.atm.iLIG127K.nc';
cam_lig='LIG/atm.2d.vars.iLIG127K.climo.nc';

%get lon and lat and vertical levels which are the same for both runs
lat=ncread(cam_lig,'lat');
lon=ncread(cam_lig,'lon');

%now grab dD precip variables from LIG: convective precip, stable precip,
%and snow
h2or=ncread(dh_lig,'PRECRC_H2Or');
h2oR=ncread(dh_lig,'PRECRL_H2OR');
h2os=ncread(dh_lig,'PRECSC_H2Os');
h2oS=ncread(dh_lig,'PRECSL_H2OS');
hdor=ncread(dh_lig,'PRECRC_HDOr');
hdoR=ncread(dh_lig,'PRECRL_HDOR');
hdos=ncread(dh_lig,'PRECSC_HDOs');
hdoS=ncread(dh_lig,'PRECSL_HDOS');

ph2=h2or + h2oR + h2os + h2oS;
phd=hdor + hdoR + hdos + hdoS;

ptiny=1e-18;
ph2(ph2 < ptiny)=ptiny;

dDp_lig=double((phd./ph2 - 1).*1000);

%also go ahead and grab total precip (snow+rain). units are m/s
precip_lig=double(ncread(cam_lig,'PRECC') + ncread(cam_lig,'PRECL'));
%convert to mm/day:
precip_lig=precip_lig.*1000.*60.*60.*24;


%Calculate Precip weighted dD averages
%Calculate Avg d18O and dD weighted by precipitation:
precip_lig_total = sum(precip_lig,3);
%Weight by month
pWeights_lig = precip_lig./precip_lig_total;
%Multiply values by weights
%dOweightedvalues_lig = d18Op_lgm.*pWeights_lgm;
dDweightedvalues_lig = dDp_lig.*pWeights_lig;
%Calculate Weighted Avg
%d18Op_lig_avg = sum(dOweightedvalues_lig,3);
dDp_lig_avg = sum(dDweightedvalues_lig,3);



%save into a mat file
save('icesm_dh.mat','lat','lon','dDp_lig','dDp_lig_avg','dDweightedvalues_lig','precip_lig');
%% make nc file
ncid = netcdf.create('icesm_dh_lig.nc','dDp_lig'); %,'dDp_lig_avg','dDweightedvalues_lig','precip_lig');
lond = netcdf.defDim(ncid,'lon',lon);
latd = netcdf.defDim(ncid,'lat',lat);
monthd = netcdf.defDim(ncid,'month',month);
varid = netcdf.defVar(ncid,'dDp_lig','NC_DOUBLE',lond,latd,monthd);
%varid = netcdf.defVar(ncid,'dDp_lig_avg','NC_DOUBLE',lond,latd,monthd);
%varid = netcdf.defVar(ncid,'dDweightedvalues_lig','NC_DOUBLE',lond,latd,monthd);
%varid = netcdf.defVar(ncid,'precip_lig','NC_DOUBLE',lond,latd,monthd);
netcdf.endDef(ncid)

netcdf.putVar(ncid,varid,dDp_lig)
netcdf.close(ncid)
%% NOW get variables from the pop files...Ocean Data
clc,clear all
%assign ncfiles - the rect files have been regridded on a rectangular grid
nc_pop_lgm='pop_LGM_rect_HDO.nc';
nc_pop_pi='pop_PI_rect_HDO.nc';

%get long and lat from pop files
lat_pop=ncread(nc_pop_lgm,'lat');
lon_pop=ncread(nc_pop_lgm,'lon');

%grab the R18O,RHDO, salinity, and potential temperature from the ocean (pop)
%results:
R18O_lgm=ncread(nc_pop_lgm,'R18O'); %Returns a 4-D double variable: dimensions are Long, Lat, z_depth, time
RHDO_lgm=ncread(nc_pop_lgm,'RHDO');
salt_lgm=ncread(nc_pop_lgm,'SALT');
TOS_lgm=ncread(nc_pop_lgm,'TOS');

R18O_pi=ncread(nc_pop_pi,'R18O');
RHDO_pi=ncread(nc_pop_pi,'RHDO');
salt_pi=ncread(nc_pop_pi,'SALT');
TOS_pi=ncread(nc_pop_pi,'TOS');

%turn isotopes into permil notation:
d18Oocean_lgm=double((R18O_lgm-1)*1000);
d18Oocean_pi=double((R18O_pi-1)*1000);
dDocean_lgm=double((RHDO_lgm-1)*1000);
dDocean_pi=double((RHDO_pi-1)*1000);

%save into a mat file
save('icesm_pop.mat','lat_pop','lon_pop','d18Oocean_lgm','d18Oocean_pi','dDocean_lgm','dDocean_pi','salt_lgm','salt_pi','TOS_lgm','TOS_pi');

%% Get surface ocean variables only
%assign ncfiles - the rect files have been regridded on a rectangular grid
nc_pop_lgm='pop_LGM_rect_HDO.nc';
nc_pop_pi='pop_PI_rect_HDO.nc';

%get long and lat from pop files
lat_pop=ncread(nc_pop_lgm,'lat');
lon_pop=ncread(nc_pop_lgm,'lon');

%grab the R18O,RHDO, salinity, and potential temperature from the ocean (pop)
%results:
R18O_lgm=squeeze(ncread(nc_pop_lgm,'R18O',[1 1 1 1],[Inf Inf 1 Inf])); %Returns a 4-D double variable: dimensions are Long, Lat, z_depth, time
RHDO_lgm=squeeze(ncread(nc_pop_lgm,'RHDO',[1 1 1 1],[Inf Inf 1 Inf]));
salt_lgm=squeeze(ncread(nc_pop_lgm,'SALT',[1 1 1 1],[Inf Inf 1 Inf]));
TOS_lgm=squeeze(ncread(nc_pop_lgm,'TOS',[1 1 1 1],[Inf Inf 1 Inf]));

R18O_pi=squeeze(ncread(nc_pop_pi,'R18O',[1 1 1 1],[Inf Inf 1 Inf]));
RHDO_pi=squeeze(ncread(nc_pop_pi,'RHDO',[1 1 1 1],[Inf Inf 1 Inf]));
salt_pi=squeeze(ncread(nc_pop_pi,'SALT',[1 1 1 1],[Inf Inf 1 Inf]));
TOS_pi=squeeze(ncread(nc_pop_pi,'TOS',[1 1 1 1],[Inf Inf 1 Inf]));

% turn isotopes into permil notation:
d18Oocean_lgm=double((R18O_lgm-1)*1000);
d18Oocean_pi=double((R18O_pi-1)*1000);
dDocean_lgm=double((RHDO_lgm-1)*1000);
dDocean_pi=double((RHDO_pi-1)*1000);

%save into a mat file
save('icesm_pop_surf.mat','lat_pop','lon_pop','d18Oocean_lgm','d18Oocean_pi','dDocean_lgm','dDocean_pi','salt_lgm','salt_pi','TOS_lgm','TOS_pi');
