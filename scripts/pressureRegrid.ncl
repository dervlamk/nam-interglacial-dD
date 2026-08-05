load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"

begin

all_files = systemfunc("ls ")
data_clim = addfiles(all_files,"r")

uwind   = data_clim[:]->U
hyam = data_clim[:]->hyam
hybm = data_clim[:]->hybm
PS = data_clim[:]->PS;

P0mb   = 1000. ;
pnew = (/ 850., 700., 500., 300., 200. /)
interp = 2
extrap = False

uwindonP = vinth2p(uwind(:,:,:,:),hyam,hybm,pnew,PS(:,:,:),interp,P0mb,1,extrap)

;======Write out netcdf file====

ncdf = addfile("U.i21ka.0801-0900.climo.nc","c")
fAtt = True
fAtt@title = "U winds on pressure levels, iCESM1.2 LGM 21ka full-forcing"
fAtt@source_file = "b.e12.B1850C5.f19_g16.i21ka.03.cam.h0.0801-0900.climo.nc"
fAtt@Conventions = "None"
fAtt@creation_date = systemfunc("date")
fileattdef(ncdf,fAtt)

filedimdef(ncdf,"time",-1,True)

ncdf->U = uwindonP

end
