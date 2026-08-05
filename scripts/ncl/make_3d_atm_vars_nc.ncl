load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"

begin

;====== I/O ======
;== input
dpath = getenv("LIG_CASE_DIR")+"/atm/proc/tseries/month_1/" ; set LIG_CASE_DIR in config/paths.env
;== output
opath = getenv("SCRATCH_DIR")+"/LIG/" ; set SCRATCH_DIR in config/paths.env
ofile = "atm.3d.vars.iLIG127K.tseries.nc"
pthNc = opath+ofile
ncdf = addfile(pthNc,"c")
;== nc attributes
fAtt = True
fAtt@case = "b.e12.B1850C5.f19_g16.iLIG127k.001"
fAtt@title = "3D Atmospheric Variables"
fAtt@clim = "Simulation Years 401-500"
fAtt@Conventions = "CF-1.0"
fAtt@initial_file = "b.e12.B1850C5.f19_g16.iPI.01.cam.i.0901-01-01-00000.nc"
fAtt@topography_file = "/glade/p/cesmdata/cseg/inputdata/atm/cam/topo/USGS-gtopo30_1.9x2.5_remap_c050602.nc"
fAtt@creation_date = systemfunc("date")
fileattdef(ncdf,fAtt)
filedimdef(ncdf,"time",-1,True) ; makes time and unlimited dimension


;======Concatenate variable data and create netcdf====
vars = (/"T", "U", "V", "OMEGA", "CLOUD"/) ; 3D vars

do n=0,4,1
	varn = vars(n) ; variable name
	all_files = systemfunc("cd "+dpath+"; ls b.e12.B1850C5.f19_g16.iLIG127k.001.cam.h0."+varn+".040101-045012.nc b.e12.B1850C5.f19_g16.iLIG127k.001.cam.h0."+varn+".045101-050012.nc") ; list files from last 100 years of sim for var
	data_all = addfiles (dpath+all_files, "r") ; read var files
	var = data_all[:]->$varn$ ; create variable
	; var_monthly = clmMonTLLL(var)

	; write to netcdf
	ncdf->$varn$ = var ;_monthly

	end do
  
end

