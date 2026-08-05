load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"

begin

;======List and open all files related to desired variable====
dpath     = getenv("LIG_TIMESERIES_JS_DIR")+"/" ; set LIG_TIMESERIES_JS_DIR in config/paths.env
all_files = systemfunc("cd "+dpath+"; ls b.e12.B1850C5.f19_g16.iLIG127k.001.pop.h.R18O.*")
data_all  = addfiles (dpath+all_files, "r")

;======Concatenate data for specific vars====
;== OCN Vars ==
r18o = data_all[:]->R18O
;salt = data_all[:]->SALT
;otemp = data_all[:]->TEMP

;printVarSummary(hdol)
;======Write out netcdf file====

opath = getenv("SCRATCH_DIR")+"/LIG/" ; set SCRATCH_DIR in config/paths.env
ofile = "R18O.pop.iLIG127k.nc"
pthNc = opath+ofile
ncdf = addfile(pthNc,"c")
fAtt = True
fAtt@title = ""
fAtt@Conventions = "None"
fAtt@creation_date = systemfunc("date")
fileattdef(ncdf,fAtt)

filedimdef(ncdf,"time",-1,True) ; makes time and unlimited dimension 


ncdf->R18O = r18o

end

