#!/bin/bash

module load nco

export DATADIR=/glade/scratch/dervlamk/PI
export IFILE=/glade/campaign/univ/uazn0018/jiangzhu/archive/b.e12.B1850C5.f19_g16.iPI.01/climo/b.e12.B1850C5.f19_g16.iPI.01.cam.h0.0801-0900.climo.nc
export OFILE=$DATADIR/dDp_pi.nc

ncap2 -O -s 'dDp=(HDOR.total($lev))' $IFILE $OFILE

ncatted -O -a source_file,global,a,c,"b.e12.B1850C5.f19_g16.iPI.01.cam.h0.0801-0900.climo.nc" $OFILE

