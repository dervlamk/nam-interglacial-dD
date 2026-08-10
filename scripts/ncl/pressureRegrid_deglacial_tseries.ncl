load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"

begin

work_data_dir = getenv("WORK_DATA_DIR")

; case, file-tag, output-subdir -- parallel arrays, same shape as
; subset_deglacial_tseries.sh's CASE_TAG/OUT_SUBDIR
cases       = (/ "pi", "lgm" /)
file_tags   = (/ "iPI.01", "i21ka.03" /)
out_subdirs = (/ "PI", "LGM" /)

vars3d = (/ "U", "V", "OMEGA", "Q", "Z3" /)

pnew   = (/ 850., 700., 500., 300., 200. /)
P0mb   = 1000.
interp = 2
extrap = False

do ic = 0, dimsizes(cases)-1
    tag    = file_tags(ic)
    outdir = work_data_dir + "/" + out_subdirs(ic) + "/tseries_0801-0900"

    ps_file = addfile(outdir + "/PS." + tag + ".0801-0900.tseries.nc", "r")
    PS      = ps_file->PS

    do iv = 0, dimsizes(vars3d)-1
        var = vars3d(iv)
        print("Regridding " + cases(ic) + "/" + var + " to pressure levels...")

        ifile = addfile(outdir + "/" + var + "." + tag + ".0801-0900.tseries.nc", "r")
        field = ifile->$var$
        hyam  = ifile->hyam
        hybm  = ifile->hybm

        fieldonP = vinth2p(field, hyam, hybm, pnew, PS, interp, P0mb, 1, extrap)

        ofile_path = outdir + "/" + var + "_plev.nc"
        system("rm -f " + ofile_path)
        ncdf = addfile(ofile_path, "c")

        fAtt = True
        fAtt@title = var + " on pressure levels, iCESM1.2 " + cases(ic) + " per-year 0801-0900"
        fAtt@source_file = var + "." + tag + ".0801-0900.tseries.nc"
        fAtt@Conventions = "None"
        fAtt@creation_date = systemfunc("date")
        fileattdef(ncdf, fAtt)

        filedimdef(ncdf, "time", -1, True)
        ncdf->$var$ = fieldonP
        ncdf->time  = ifile->time

        delete(field)
        delete(fieldonP)
        delete(hyam)
        delete(hybm)
        delete(ifile)
        delete(ncdf)
    end do
    delete(PS)
    delete(ps_file)
end do

end
