load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"

begin

dpath = "/glade/campaign/univ/uazn0018/jiangzhu/archive/b.e12.B1850C5.f19_g16.iPI.01/climo/"
filen = "b.e12.B1850C5.f19_g16.iPI.01.cam.h0.0801-0900.climo.nc"
all_files = systemfunc("ls /glade/campaign/univ/uazn0018/jiangzhu/archive/b.e12.B1850C5.f19_g16.iPI.01/climo/b.e12.B1850C5.f19_g16.iPI.01.cam.h0.0801-0900.climo.nc")
data_clim = addfiles(all_files,"r")

hdor = data_clim[:]->HDOR
hdor_ = data_clim[:]->HDOr
hdov = data_clim[:]->HDOV
hdol = data_clim[:]->HDOL
h2or = data_clim[:]->H2OR
h2or_ = data_clim[:]->H2Or
h2ov = data_clim[:]->H2OV
h2ol = data_clim[:]->H2OL

hyai = data_clim[:]->hyai
hybi = data_clim[:]->hybi
PS = data_clim[:]->PS;

P0mb   = 1000. ;
pnew = (/1000., 850., 700., 500., 300., 200. /)
interp = 2
extrap = False

hdorP = vinth2p(hdor(:,:,:,:),hyai,hybi,pnew,PS(:,:,:),interp,P0mb,1,extrap)
hdor_P = vinth2p(hdor_(:,:,:,:),hyai,hybi,pnew,PS(:,:,:),interp,P0mb,1,extrap)
hdovP = vinth2p(hdov(:,:,:,:),hyai,hybi,pnew,PS(:,:,:),interp,P0mb,1,extrap)
hdolP = vinth2p(hdol(:,:,:,:),hyai,hybi,pnew,PS(:,:,:),interp,P0mb,1,extrap)
h2orP = vinth2p(h2or(:,:,:,:),hyai,hybi,pnew,PS(:,:,:),interp,P0mb,1,extrap)
h2or_P = vinth2p(h2or_(:,:,:,:),hyai,hybi,pnew,PS(:,:,:),interp,P0mb,1,extrap)
h2ovP = vinth2p(h2ov(:,:,:,:),hyai,hybi,pnew,PS(:,:,:),interp,P0mb,1,extrap)
h2olP = vinth2p(h2ol(:,:,:,:),hyai,hybi,pnew,PS(:,:,:),interp,P0mb,1,extrap)

;======Write out netcdf file====

opath = "/glade/scratch/dervlamk/PI/"
ofile = "DH.isotopes.iCESM1pt2.PI.nc"
pthNc = opath+ofile
ncdf = addfile(pthNc,"c")
fAtt = True
fAtt@title = "Hydrogen isotope vars on pressure levels, PI climatologies"
fAtt@source_file = "b.e12.B1850C5.f19_g16.iPI.01.cam.h0.0801-0900.climo.nc"
fAtt@Conventions = "None"
fAtt@creation_date = systemfunc("date")
fileattdef(ncdf,fAtt)

filedimdef(ncdf,"time",-1,True)

ncdf->HDOR = hdorP
ncdf->HDOr = hdor_P
ncdf->HDOV = hdovP
ncdf->HDOL = hdolP
ncdf->H2OR = h2orP
ncdf->H2Or = h2or_P
ncdf->H2OV = h2ovP
ncdf->H2OL = h2olP

end
