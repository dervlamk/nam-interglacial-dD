#!/bin/bash
#
# Build the two derived IMERG products the model-side notebooks read, from the 2001-2018 monthly
# timeseries. Run this once per machine; the notebooks then just open the results.
#
#   imerg.gn.2001-2018.climo.nc          12-month climatology, global, 0:360, mm/day
#   imerg.gn.2001-2018.swna.tseries.nc   the SW-NA window of the monthly timeseries, 0:360, mm/day
#
# WHY THIS IS NOT DONE IN THE NOTEBOOK. The source is 216 monthly records on a 0.1 deg global
# grid -- 5.6 GB once it is in memory as float32. The notebook used to build the climatology with
# `.transpose(...).groupby("time.month").mean("time")` followed by a coordinate sort and a write,
# which materialises the whole field several times over and kills the Jupyter kernel. NCO streams
# the record dimension instead: `ncra` averages one calendar month at a time and never holds more
# than a few records, so peak memory is a few hundred MB and the whole thing takes about a minute.
#
# The SW-NA subset exists for the same reason: the annual-cycle figure needs the *interannual
# spread*, which a climatology cannot provide, and re-reading the global timeseries in the kernel
# to get it puts the memory problem straight back. The window (10-42N, 125-85W) is the same one
# the ETOPO subset uses, so it covers every map in the model notebooks with room to spare, and the
# notebook applies the exact NAM domain polygon to it in Python.
#
# The longitude wrap is the other reason to do this here. An earlier in-notebook version relabelled
# lon with np.linspace(0, 360, nlon) and rolled by nlon (a no-op), which left correct data on an
# axis whose every label was 180 deg out -- silently, for months. `ncks --msa` reorders the actual
# slabs, so the data and the labels move together.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../../config/paths.env"
if [ ! -f "$CONFIG" ]; then
    echo "Missing $CONFIG -- copy config/paths.env.example to config/paths.env and edit it first." >&2
    exit 1
fi
source "$CONFIG"

module load nco

OBSDIR="$WORK_DATA_DIR/obs_data"
IFILE="$OBSDIR/imerg.gn.timeseries.2001-2018.nc"
CLIMO="$OBSDIR/imerg.gn.2001-2018.climo.nc"
SWNA="$OBSDIR/imerg.gn.2001-2018.swna.tseries.nc"

if [ ! -f "$IFILE" ]; then
    echo "Missing source file: $IFILE" >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# SW-NA window, in the source file's -180:180 convention. Matches the etopoSWNA subset the
# notebooks already take (235-275E, 10-42N).
LAT_MIN=10.0 ; LAT_MAX=42.0
LON_MIN=-125.0 ; LON_MAX=-85.0

echo "Source: $IFILE"

# --- 1. 12-month climatology -------------------------------------------------------------------
# One ncra pass per calendar month: -F -d time,$m,,12 averages records m, m+12, m+24, ... (1-based),
# i.e. every January, then every February, and so on. Each pass streams the file; none of them
# holds more than one record at a time.
for m in $(seq 1 12); do
    printf 'Averaging month %02d...\n' "$m"
    ncra -O -F -d time,"$m",,12 "$IFILE" "$TMP/$(printf 'mon%02d.nc' "$m")"
done
ncrcat -O "$TMP"/mon??.nc "$TMP/climo.nc"

# mm/hr -> mm/day
ncap2 -O -s 'precipitation=precipitation*24.0f' "$TMP/climo.nc" "$TMP/climo.nc"

# -180:180 -> 0:360. --msa reorders the data slabs (eastern hemisphere first, then western), and
# ncap2 then relabels the negative half. Data and labels move together, which is the whole point.
ncks -O --msa -d lon,0.0,180.0 -d lon,-180.0,0.0 "$TMP/climo.nc" "$TMP/climo.nc"
ncap2 -O -s 'where(lon<0) lon=lon+360.0;' "$TMP/climo.nc" "$TMP/climo.nc"

# the source is (time,lon,lat); the notebooks want (month,lat,lon)
ncpdq -O -a time,lat,lon "$TMP/climo.nc" "$TMP/climo.nc"

# the record dim is a climatological month now, not a date -- rename it and drop the inherited
# time attributes, which would otherwise claim these are seconds since 1970
ncrename -O -d time,month -v time,month "$TMP/climo.nc"
ncap2 -O -s 'month(:)={1,2,3,4,5,6,7,8,9,10,11,12};' "$TMP/climo.nc" "$TMP/climo.nc"
for a in DimensionNames LongName Units axis bounds calendar cell_methods fullnamepath origname standard_name; do
    ncatted -O -a "$a,month,d,," "$TMP/climo.nc"
done
ncatted -O \
    -a units,month,o,c,'1' \
    -a long_name,month,o,c,'calendar month (1=January)' \
    -a units,precipitation,o,c,'mm/day' \
    -a Units,precipitation,o,c,'mm/day' \
    -a source_file,global,o,c,"$(basename "$IFILE") (2001-2018 monthly climatology, scripts/nco/make_imerg_climo.sh)" \
    "$TMP/climo.nc"
mv "$TMP/climo.nc" "$CLIMO"
echo "Wrote $CLIMO"

# --- 2. SW-NA monthly timeseries ---------------------------------------------------------------
# Keeps the real time axis: the annual-cycle figure groups it by calendar month to get both the
# mean and the interannual standard deviation.
echo "Subsetting the SW-NA window..."
ncks -O -d lat,"$LAT_MIN","$LAT_MAX" -d lon,"$LON_MIN","$LON_MAX" "$IFILE" "$TMP/swna.nc"
ncap2 -O -s 'precipitation=precipitation*24.0f' "$TMP/swna.nc" "$TMP/swna.nc"
# the window is entirely west of the prime meridian, so the wrap is a relabel with no reordering
ncap2 -O -s 'where(lon<0) lon=lon+360.0;' "$TMP/swna.nc" "$TMP/swna.nc"
ncpdq -O -a time,lat,lon "$TMP/swna.nc" "$TMP/swna.nc"
ncatted -O \
    -a units,precipitation,o,c,'mm/day' \
    -a Units,precipitation,o,c,'mm/day' \
    -a source_file,global,o,c,"$(basename "$IFILE") (${LAT_MIN}-${LAT_MAX}N, ${LON_MIN}-${LON_MAX}E, scripts/nco/make_imerg_climo.sh)" \
    "$TMP/swna.nc"
mv "$TMP/swna.nc" "$SWNA"
echo "Wrote $SWNA"

echo "Done."
