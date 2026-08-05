load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"

begin

;dpath = "/glade/campaign/univ/uazn0018/jiangzhu/archive/b.e12.B1850C5.f19_g16.iPI.01/climo/"
;filen = "b.e12.B1850C5.f19_g16.iPI.01.cam.h0.0801-0900.climo.nc"
all_files = systemfunc("ls ")
data_clim = addfiles(all_files,"r")

temp = data_clim[:]->T
omega = data_clim[:]->OMEGA
uwind = data_clim[:]->U
vwind = data_clim[:]->V

hyam = data_clim[:]->hyam
hybm = data_clim[:]->hybm
PS = data_clim[:]->PS;

P0mb   = 1000. ;
pnew = (/1000., 850., 700., 500., 300., 200. /)
interp = 2
extrap = False

tempP = vinth2p(temp(:,:,:,:),hyam,hybm,pnew,PS(:,:,:),interp,P0mb,1,extrap)
omegaP = vinth2p(omega(:,:,:,:),hyam,hybm,pnew,PS(:,:,:),interp,P0mb,1,extrap)
vwindP = vinth2p(vwind(:,:,:,:),hyam,hybm,pnew,PS(:,:,:),interp,P0mb,1,extrap)
uwindP = vinth2p(uwind(:,:,:,:),hyam,hybm,pnew,PS(:,:,:),interp,P0mb,1,extrap)

;======Write out netcdf file====

opath = "/glade/scratch/dervlamk/PI/"
ofile = "atm.3d.vars.iCESM1pt2.PI.nc"
pthNc = opath+ofile
ncdf = addfile(pthNc,"c")
fAtt = True
fAtt@title = "3D atmospheric vars on pressure levels, PI climatologies"
fAtt@source_file = "b.e12.B1850C5.f19_g16.iPI.01.cam.h0.0801-0900.climo.nc"
fAtt@Conventions = "None"
fAtt@creation_date = systemfunc("date")
fileattdef(ncdf,fAtt)

filedimdef(ncdf,"time",-1,True)

ncdf->T = tempP
ncdf->OMEGA = omegaP
ncdf->V = vwindP
ncdf->U = uwindP

end
