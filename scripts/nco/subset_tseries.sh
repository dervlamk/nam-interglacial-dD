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

# Years 801-900 (1-based, inclusive) as 0-based monthly record indices.
START_REC=9600
END_REC=10799

# Notebook's raw_varns (24) plus PS (25th, subset-only -- needed by
# pressureRegrid_tseries.ncl for vinth2p, never loaded directly by the notebook).
VARS="PRECRC_H2Or PRECRL_H2OR PRECSC_H2Os PRECSL_H2OS PRECRC_HDOr PRECRL_HDOR PRECSC_HDOs PRECSL_HDOS \
PRECRC_H216Or PRECRL_H216OR PRECSC_H216Os PRECSL_H216OS PRECRC_H218Or PRECRL_H218OR PRECSC_H218Os PRECSL_H218OS \
PRECC PRECL TS U V OMEGA Q Z3 PSL PS"

declare -A CASE_DIR=( [pi]="$PI_CASE_DIR" [lgm]="$LGM_CASE_DIR" )
declare -A CASE_PREFIX=( [pi]="b.e12.B1850C5.f19_g16.iPI.01" [lgm]="b.e12.B1850C5.f19_g16.i21ka.03" )
declare -A CASE_TAG=( [pi]="iPI.01" [lgm]="i21ka.03" )

# Flat, not per-case subdirectories -- the case tag in the filename (below) is what
# distinguishes PI from LGM output. Matches notebooks/LGM_analyses.ipynb's file-path cell.
OUTDIR="$REPO_ROOT/data/raw"
mkdir -p "$OUTDIR"

for case in pi lgm; do
    SRC_DIR="${CASE_DIR[$case]}/atm/proc/tseries/monthly"
    PREFIX="${CASE_PREFIX[$case]}"

    for VAR in $VARS; do
        IFILE="$SRC_DIR/$VAR/$PREFIX.cam.h0.$VAR.0001-0900.nc"
        OFILE="$OUTDIR/$VAR.${CASE_TAG[$case]}.0801-0900.tseries.nc"
        if [ ! -f "$IFILE" ]; then
            echo "Missing source file: $IFILE" >&2
            exit 1
        fi
        echo "Subsetting $case/$VAR..."
        # -O overwrite, -d time,START,END is a hyperslab read -- does not read/copy the
        # full 10800-record file, only the requested 1200-record window.
        ncks -O -d time,$START_REC,$END_REC $IFILE $OFILE
        ncatted -O -a source_file,global,a,c,"$PREFIX.cam.h0.$VAR.0001-0900.nc (records $START_REC-$END_REC, years 0801-0900)" $OFILE
    done
done

# Time-invariant surface fields, PI only. PHIS is what the LIG notebook contours as model
# topography, the way LGM_analyses.ipynb contours the 21 ka topo file -- and since the LIG's
# ice sheets and land surface are essentially modern, the PI boundary condition is the right
# one for it. One record is enough: neither field varies in time within a case.
# Named '.constant.nc' rather than '.0801-0900.tseries.nc' so the filename does not imply a
# 1200-record window it does not have.
for VAR in PHIS LANDFRAC; do
    IFILE="$PI_CASE_DIR/atm/proc/tseries/monthly/$VAR/${CASE_PREFIX[pi]}.cam.h0.$VAR.0001-0900.nc"
    OFILE="$OUTDIR/$VAR.${CASE_TAG[pi]}.constant.nc"
    if [ ! -f "$IFILE" ]; then
        echo "Missing source file: $IFILE" >&2
        exit 1
    fi
    echo "Subsetting pi/$VAR (time-invariant, first record only)..."
    ncks -O -d time,0,0 $IFILE $OFILE
    ncatted -O -a source_file,global,a,c,"${CASE_PREFIX[pi]}.cam.h0.$VAR.0001-0900.nc (record 0; field is time-invariant)" $OFILE
done

echo "Done. Output: \$REPO_ROOT/data/raw/"
