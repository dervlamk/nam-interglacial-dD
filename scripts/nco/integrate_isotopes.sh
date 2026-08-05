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
export OFILE=$DATADIR/dDp_pi.nc

ncap2 -O -s 'dDp=(HDOR.total($lev))' $IFILE $OFILE

ncatted -O -a source_file,global,a,c,"b.e12.B1850C5.f19_g16.iPI.01.cam.h0.0801-0900.climo.nc" $OFILE

