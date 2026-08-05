load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"

begin

;====== I/O ====
; input path
; dpath = "/glade/campaign/cgd/ppc/jiangzhu/iCESM1.2/b.e12.B1850C5.f19_g16.iPI.01/climo/" 
dpath = "/glade/campaign/cesm/development/palwg/LastInterglacial/iCESM1.2/b.e12.B1850C5.f19_g16.iLIG127k.001/atm/proc/tseries/month_1/"

; netcdf output
opath = "/glade/derecho/scratch/dervlamk/LIG/"
ofile = "dh.precIsotopes.tseries.iLIG127K.nc"
pthNc = opath+ofile
ncdf = addfile(pthNc,"c")
fAtt = True
fAtt@title = "Hydrogen Isotopes in Precipitation"
fAtt@case = "b.e12.B1850C5.f19_g16.iLIG127k.001" ; "b.e12.B1850C5.f19_g16.iPI.01"
fAtt@clim = "Simulation Years 401-500" ; 801-900
fAtt@Conventions = "None"
fAtt@creation_date = systemfunc("date")
fileattdef(ncdf,fAtt)
filedimdef(ncdf,"time",-1,True) ; makes time and unlimited dimension

;======Concatenate variable data and create netcdf====
vars = (/"PRECRC_H2Or","PRECRL_H2OR","PRECSC_H2Os", "PRECSL_H2OS", "PRECRC_HDOr", "PRECRL_HDOR", "PRECSC_HDOs", "PRECSL_HDOS"/);
do n=0,7,1

   varn = vars(n) ; variable name
   ; all_files = systemfunc("cd "+dpath+"; ls b.e12.B1850C5.f19_g16.iPI.01.cam.h0.0801-0900.climo.nc")

   all_files = systemfunc("cd "+dpath+"; ls b.e12.B1850C5.f19_g16.iLIG127k.001.cam.h0."+varn+".040101-045012.nc b.e12.B1850C5.f19_g16.iLIG127k.001.cam.h0."+varn+".045101-050012.nc") ; list files from last 100 years of sim for var

   data_all = addfiles (dpath+all_files, "r") ; read var files
   var = data_all[:]->$varn$ ; create variable
   ; var_monthly = clmMonTLL(var) ; calculate monthly climatology
   
   ; write to netcdf
   ncdf->$varn$ = var ;_monthly
   
end do
  
end

