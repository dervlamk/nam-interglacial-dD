load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"

begin

;====== I/O ====
dpath = getenv("LIG_CASE_DIR")+"/ocn/proc/tseries/day_1/" ; set LIG_CASE_DIR in config/paths.env

opath = getenv("SCRATCH_DIR")+"/LIG/" ; set SCRATCH_DIR in config/paths.env
ofile = "SST.iLIG127K.nc"
pthNc = opath+ofile
ncdf = addfile(pthNc,"c")
fAtt = True
fAtt@case = "b.e12.B1850C5.f19_g16.iLIG127k.001"
fAtt@title = ""
fAtt@Conventions = "CF-1.0"
fAtt@source = "CCSM POP2, the CCSM Ocean Component"
fAtt@creation_date = systemfunc("date")
fileattdef(ncdf,fAtt)

filedimdef(ncdf,"time",-1,True) ; makes time and unlimited dimension


;======Concatenate variable data and create netcdf====
varn = "SST" ; variable name
all_files = systemfunc("cd "+dpath+"; ls b.e12.B1850C5.f19_g16.iLIG127k.001.pop.h.nday1."+varn+".*") ; list all files for var
data_all = addfiles (dpath+all_files, "r") ; read var files
var = data_all[:]->$varn$ ; create variable

;== write to netcdf ==
ncdf->$varn$ = var

  
end

