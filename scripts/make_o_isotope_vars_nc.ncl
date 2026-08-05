load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"

begin

;====== I/O ====
;== input
; dpath = "/glade/campaign/cgd/ppc/jiangzhu/iCESM1.2/b.e12.B1850C5.f19_g16.iPI.01/climo/"
dpath = "/glade/campaign/cesm/development/palwg/LastInterglacial/iCESM1.2/b.e12.B1850C5.f19_g16.iLIG127k.001/atm/proc/tseries/month_1/"

;== output
opath = "/glade/derecho/scratch/dervlamk/LIG/"
ofile = "o.precIsotopes.atm.iLIG127k.nc"
; opath = "/glade/scratch/dervlamk/PI/"
; ofile = "o.precIsotopes.atm.iPI.nc"
pthNc = opath+ofile
ncdf = addfile(pthNc,"c")

;== nc attributes
fAtt = True
fAtt@title = "Oxygen Isotopes in Precipitation Variables"
fAtt@case = "b.e12.B1850C5.f19_g16.iLIG127k.001"
fAtt@span = "Simulation Years 401-500"
; fAtt@case = "b.e12.B1850C5.f19_g16.iPI.01"
; fAtt@span = "Simulation Years 801-900"
fAtt@Conventions = "None"
fAtt@creation_date = systemfunc("date")
fileattdef(ncdf,fAtt)
filedimdef(ncdf,"time",-1,True) ; makes time and unlimited dimension


;======Concatenate variable data and create netcdf====
vars = (/"PRECRC_H216Or","PRECRL_H216OR","PRECSC_H216Os", "PRECSL_H216OS", "PRECRC_H218Or", "PRECRL_H218OR", "PRECSC_H218Os", "PRECSL_H218OS"/);
do n=0,7,1

   varn = vars(n) ; variable name
;   all_files = systemfunc("cd "+dpath+"; ls b.e12.B1850C5.f19_g16.iPI.01.cam.h0.0801-0900.climo.nc") 

   all_files = systemfunc("cd "+dpath+"; ls  b.e12.B1850C5.f19_g16.iLIG127k.001.cam.h0."+varn+".040101-045012.nc b.e12.B1850C5.f19_g16.iLIG127k.001.cam.h0."+varn+".045101-050012.nc") ; list files from last 100 years of sim for var

   data_all = addfiles (dpath+all_files, "r") ; read var files
   var = data_all[:]->$varn$ ; create variable
   ; var_monthly = clmMonTLL(var)
   
   ; write to netcdf
   ncdf->$varn$ = var; _monthly
   
end do
  
end

