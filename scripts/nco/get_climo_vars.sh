#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../../config/paths.env"
if [ ! -f "$CONFIG" ]; then
    echo "Missing $CONFIG -- copy config/paths.env.example to config/paths.env and edit it first." >&2
    exit 1
fi
source "$CONFIG"

module load nco

export DATADIR=$SCRATCH_DIR/PI
export IFILE=$PI_CLIMO_DIR/b.e12.B1850C5.f19_g16.iPI.01.cam.h0.0801-0900.climo.nc
export OFILE=$DATADIR/dh.vars.PI.hybrid_lev.nc  #atm.2d.vars.iCESM1pt2.PI.nc

ncks -A -h -v H2OR $IFILE $OFILE
ncks -A -h -v H2Or $IFILE $OFILE
ncks -A -h -v H2OL $IFILE $OFILE
ncks -A -h -v H2OV $IFILE $OFILE
ncks -A -h -v HDOR $IFILE $OFILE #TS $IFILE $OFILE
ncks -A -h -v HDOr $IFILE $OFILE #TAUX $IFILE $OFILE
ncks -A -h -v HDOL $IFILE $OFILE #TAUY $IFILE $OFILE
ncks -A -h -v HDOV $IFILE $OFILE #LHFLX $IFILE $OFILE
#ncks -A -h -v SHFLX $IFILE $OFILE
#ncks -A -h -v PRECC $IFILE $OFILE 
#ncks -A -h -v PRECL $IFILE $OFILE

ncatted -O -a source_file,global,a,c,"b.e12.B1850C5.f19_g16.iPI.01.cam.h0.0801-0900.climo.nc" $OFILE

