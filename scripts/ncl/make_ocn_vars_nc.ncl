load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"

begin

;====== I/O ====
dpath = getenv("LIG_CASE_DIR")+"/ocn/proc/tseries/month_1/" ; set LIG_CASE_DIR in config/paths.env

opath = getenv("SCRATCH_DIR")+"/LIG/" ; set SCRATCH_DIR in config/paths.env
ofile = "ocn.vars.iLIG127K.nc"
pthNc = opath+ofile
ncdf = addfile(pthNc,"c")
fAtt = True
fAtt@case = "b.e12.B1850C5.f19_g16.iLIG127k.001"
fAtt@title = ""
fAtt@Conventions = "CF-1.0"
fAtt@initial_file = "b.e12.B1850C5.f19_g16.iPI.01.cam.i.0901-01-01-00000.nc"
fAtt@topography_file = "/glade/p/cesmdata/cseg/inputdata/atm/cam/topo/USGS-gtopo30_1.9x2.5_remap_c050602.nc"
fAtt@creation_date = systemfunc("date")
fileattdef(ncdf,fAtt)

filedimdef(ncdf,"time",-1,True) ; makes time and unlimited dimension


;======Concatenate variable data and create netcdf====
vars = (/"R18O", "TEMP", "SALT"/) ; 3D vars 

do n=0,2,1
varn = vars(n) ; variable name
all_files = systemfunc("cd "+dpath+"; ls b.e12.B1850C5.f19_g16.iLIG127k.001.pop.h."+varn+".*") ; list all files for var
data_all = addfiles (dpath+all_files, "r") ; read var files
var = data_all[:]->$varn$(:,0,:,:) ; create variable, extracting only top depth level

;== write to netcdf ==
ncdf->$varn$ = var

end do
  
end

