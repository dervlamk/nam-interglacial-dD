"""
Loading and deriving fields from iCESM1.2 monthly output.

Shared by the model-side notebooks (LGM_analyses.ipynb,
LIG127k_analyses_PALEOCALADJUSTED.ipynb). The isotope/precipitation-weighting math has one
source here rather than a copy per notebook, which is what kept the two from drifting apart.

Every function in here works off two explicit non-dimension coordinates on the time axis,
`month` and `year`, rather than reading `.dt.month` / `.dt.year` off the timestamps. That is
not stylistic: the two experiments stamp their time axes differently and neither one can be
read naively (see assign_cesm_month_year and assign_paleocal_month_year below).
"""

import numpy as np
import pandas as pd
import xarray as xr

from data_funcs import get_season


# Canonical identity for every field derive_dat() produces. Stamped explicitly onto each
# output (see the end of the loop below) rather than left to propagate.
# Also fills in units/long_name for the five pressure-level fields, which arrive from
# pressureRegrid_tseries.ncl with no attributes at all (ncl vinth2p does not carry them through).
DAT_META = {
    'TS':    {'units': 'K',      'long_name': 'surface temperature (radiative)'},
    'OMEGA': {'units': 'Pa/s',   'long_name': 'vertical pressure velocity'},
    'U':     {'units': 'm/s',    'long_name': 'zonal wind'},
    'V':     {'units': 'm/s',    'long_name': 'meridional wind'},
    'PSL':   {'units': 'Pa',     'long_name': 'sea level pressure'},
    'Q':     {'units': 'kg/kg',  'long_name': 'specific humidity'},
    'Z3':    {'units': 'm',      'long_name': 'geopotential height'},
    'PRECC': {'units': 'mm/day', 'long_name': 'convective precipitation rate'},
    'PRECL': {'units': 'mm/day', 'long_name': 'large-scale precipitation rate'},
    'PRECT': {'units': 'mm/day', 'long_name': 'total precipitation', 'source': 'PRECC + PRECL'},
    # NOTE: these are plain per-mil ratios per month. The precipitation weighting is applied by
    # seasonal_means(), not here -- see WEIGHTED_VARNS and the note in that function.
    'dDp':   {'units': u'‰',     'long_name': u'δD of precipitation',
              'source': 'PREC{RC,RL,SC,SL}_HDO over H2O equivalents; PRECT-weighted by seasonal_means()'},
    'd18Op': {'units': u'‰',     'long_name': u'δ18O of precipitation',
              'source': 'PREC{RC,RL,SC,SL}_H218O over H216O equivalents; PRECT-weighted by seasonal_means()'},
}

# Fields that must be averaged over time weighted by precipitation rather than as a plain mean.
# The weighting is applied in seasonal_means(), where the set of months being averaged is known.
WEIGHTED_VARNS = ('dDp', 'd18Op')

# pass-through fields: loaded and relabelled, no unit conversion or derivation
PASSTHROUGH_VARNS = ['TS', 'OMEGA', 'U', 'V', 'PSL', 'Q', 'Z3']


def assign_cesm_month_year(da, shift_days=2):
    """Attach `month` and `year` coords to raw CESM h0 output.

    CESM h0 timestamps the END of each averaging period (January's mean is stamped
    0801-02-01), so a raw .dt.month/.dt.year read mislabels every record by one month and
    misassigns December into the following year. Nudging the axis back by two days puts every
    stamp inside its own month, after which .dt is trustworthy.

    The shifted axis is what gets returned -- downstream code should never need the original,
    but it is kept in attrs for reference.
    """
    # deep=False on purpose: it copies the container so assigning `time` below does not mutate
    # the caller's array, but shares the data buffer, so the field stays lazy. A deep copy here
    # pulls all 25 variables x 2 cases into memory at load time (~3 GB) for no benefit.
    da = da.copy(deep=False)
    da['time'] = da.time - pd.Timedelta(days=shift_days)
    da.attrs['original_time_values'] = da.time + pd.Timedelta(days=shift_days)
    return da.assign_coords(month=('time', da.time.dt.month.values),
                            year=('time', da.time.dt.year.values))


def assign_paleocal_month_year(da, first_year):
    """Attach `month` and `year` coords to PaleoCalAdjust output, POSITIONALLY.

    Do not read months off these timestamps. A calendar-adjusted file carries paleo month
    boundaries, which under 127 ka orbital forcing drift far enough that April is stamped
    0401-05-01 05:36 -- five and a half hours into May. `.dt.month` therefore returns no April
    at all and two Mays, silently folding two months into one. The `- 2 days` nudge the old
    LIG notebook used happens to repair that particular file, but April clears the boundary by
    only a few hours; a different orbital configuration or a re-run at a different tolerance
    moves it, and the failure is silent.

    The record order, on the other hand, is guaranteed: cal_adjust.f90 writes exactly twelve
    records per simulation year in paleo Jan-Dec order. So months are assigned by position and
    the timestamps are used for nothing.

    Raises if the file is not a whole number of 12-month years, which is the one assumption
    this makes.
    """
    nt = da.sizes['time']
    if nt % 12:
        raise ValueError(f'expected a whole number of 12-month years, got {nt} records')
    nyears = nt // 12
    month = np.tile(np.arange(1, 13), nyears)
    year = np.repeat(np.arange(first_year, first_year + nyears), 12)
    da = da.copy(deep=False)   # container only -- see assign_cesm_month_year()
    da.attrs['original_time_values'] = da.time
    da.attrs['month_assignment'] = ('positional (12 records/year, paleo Jan-Dec); timestamps '
                                    'carry paleo month boundaries and are NOT used')
    return da.assign_coords(month=('time', month), year=('time', year))


def derive_dat(raw, cases, dat_varns):
    """Build the dat_varns-keyed derived dict (unit conversions, PRECT, dDp, d18Op) from a
    raw[case][varn] dict. Used once for the climatology and once for the per-year subset --
    the math is identical either way, which is why this takes no argument naming the time axis.
    Factored out so the dDp/d18Op formula has one source, not two copies that can drift apart.

    dDp/d18Op come out as plain per-mil ratios, one per record. They are NOT weighted here:
    weighting by each month's share of its own ANNUAL total precipitation cannot produce a
    correct sub-annual mean, because the weights over any subset of months sum to that subset's
    share of the year rather than to 1. seasonal_means() does the weighting instead, where the
    months being averaged are known.

    Every output is stamped with its DAT_META name/units/long_name before being returned, so a
    derived field never carries the identity of whichever raw variable happened to be operand #1.
    """
    dat = {case: {} for case in cases}
    for case in cases:
        for varn in dat_varns:
            if varn in PASSTHROUGH_VARNS:
                dat[case][varn] = raw[case][varn]
            elif varn in ['PRECC', 'PRECL']:
                dat[case][varn] = raw[case][varn]*1000*60*60*24 # convert from m/s to mm/day
            elif varn in ['PRECT']:
                # calculate total precip from convective and large-scale prec vars (snow+rain).
                dat[case][varn] = dat[case]['PRECC'] + dat[case]['PRECL']
            else:
                #== calculate isotope ratios of precipitation (unweighted -- see the docstring)
                # the ptiny constant floors the denominator of the isotope ratio equation to prevent divide by zero
                ptiny=1e-18
                if varn=='dDp':
                    # Hydrogen
                    phyd = raw[case]['PRECRC_H2Or'] + raw[case]['PRECRL_H2OR'] + raw[case]['PRECSC_H2Os'] + raw[case]['PRECSL_H2OS']
                    pdeu = raw[case]['PRECRC_HDOr'] + raw[case]['PRECRL_HDOR'] + raw[case]['PRECSC_HDOs'] + raw[case]['PRECSL_HDOS']
                    # replace very small ph values with a tiny value
                    phyd = phyd.where(phyd > ptiny, ptiny)
                    # turn into per mil notation
                    dd = (pdeu/phyd - 1)*1000
                    dat[case][varn] = dd
                elif varn=='d18Op':
                    # Oxygen
                    p16o = raw[case]['PRECRC_H216Or'] + raw[case]['PRECRL_H216OR'] + raw[case]['PRECSC_H216Os'] + raw[case]['PRECSL_H216OS']
                    p18o = raw[case]['PRECRC_H218Or'] + raw[case]['PRECRL_H218OR'] + raw[case]['PRECSC_H218Os'] + raw[case]['PRECSL_H218OS']
                    # replace very small ph values with a tiny value
                    p16o = p16o.where(p16o > ptiny, ptiny)
                    # turn into per mil notation
                    do = (p18o/p16o - 1)*1000
                    dat[case][varn] = do
                else:
                    # raise, don't print -- an unassigned key surfaces much later as a confusing
                    # KeyError somewhere downstream instead of here.
                    raise KeyError(f'{varn} not recognized by derive_dat()')

            #== stamp identity (see DAT_META above). The .copy(deep=False) is required, not
            # decorative: in the pass-through branch dat[case][varn] IS raw[case][varn], and
            # .rename() returns self when the name is already correct -- so assigning .attrs
            # would clobber the raw array's own CESM metadata (verified: it did, for all seven
            # pass-through vars). deep=False shares the data buffer, so this stays lazy.
            da = dat[case][varn].rename(varn).copy(deep=False)
            da.attrs = dict(DAT_META[varn])
            dat[case][varn] = da
    return dat


def monthly_climatology(raw, cases, raw_varns):
    """Collapse a per-year raw[case][varn] dict to a 12-month climatology, keyed the same way.

    Groups on the `month` coord, not `time.month` -- see the module docstring.
    """
    return {case: {varn: raw[case][varn].groupby('month').mean('time') for varn in raw_varns}
            for case in cases}


def seasonal_means(dat_ts, cases, dat_varns, seasons, weight_varn='PRECT'):
    """Seasonal means of a per-year derived dict, both collapsed and per-year.

    The isotope fields in WEIGHTED_VARNS are averaged weighted by `weight_varn`, everything
    else as a plain mean. The weighting lives here rather than in derive_dat() because it can
    only be done once the set of months is known: a weight formed as a month's share of its
    ANNUAL precipitation does not renormalise over a season, so pre-multiplying and then taking
    a plain mean returns the seasonal weighted mean scaled by (season's share of annual precip)
    / (number of months) -- for JAS roughly a tenth of the right answer, and by a factor that
    varies year to year and grid cell to grid cell rather than a constant.

    Returns
    -------
    seas_mean     : [case][varn][season] -- mean over every month in the season, all years.
    ann_seas_mean : [case][varn][season] -- one value per simulation year, which is the
                    sample the significance tests in stats_funcs.py consume.
    """
    if any(varn in WEIGHTED_VARNS for varn in dat_varns) and weight_varn not in dat_varns:
        # the weighted branch reaches into dat_ts for this field; without it the isotope means
        # would silently fall back to unweighted, which is the bug this function exists to avoid
        raise KeyError(f'{weight_varn} must be in dat_varns to weight '
                       f'{[v for v in dat_varns if v in WEIGHTED_VARNS]}')

    seas_mean     = {case: {varn: {} for varn in dat_varns} for case in cases}
    ann_seas_mean = {case: {varn: {} for varn in dat_varns} for case in cases}
    for case in cases:
        for varn in dat_varns:
            for season in seasons:
                # get_season() returns 0-based POSITIONAL indices (see its use via
                # .isel(month=...) in map_plot_tools.py/line_plot_tools.py) -- not calendar
                # month numbers, so +1 to compare against the `month` coord.
                cal_months = [m + 1 for m in get_season(season=season)]
                da = dat_ts[case][varn]
                da = da.sel(time=da['month'].isin(cal_months))
                if varn in WEIGHTED_VARNS:
                    p = dat_ts[case][weight_varn]
                    p = p.sel(time=p['month'].isin(cal_months))
                    # Weight months by precipitation WITHIN each year, then average the years
                    # equally -- deliberately not one pooled Sum(dD*P)/Sum(P) over the whole
                    # record, which would let wet years count for more. Two consequences that
                    # the code downstream relies on: seas_mean is exactly the mean of
                    # ann_seas_mean (so the difference the maps plot is the difference of the
                    # two samples sigtest2n() actually compares -- for the unweighted fields
                    # that has always been true for free), and the anomaly figure's central
                    # value is the mean of the very per-year sample whose spread it shows as an
                    # error bar. Pooling gives a JAS box mean ~0.19 permil different; the
                    # choice is equal-year.
                    per_year = ((da * p).groupby('year').sum('time')
                                / p.groupby('year').sum('time'))
                    ann_seas_mean[case][varn][season] = per_year
                    seas_mean[case][varn][season] = per_year.mean('year')
                else:
                    seas_mean[case][varn][season] = da.mean(dim='time')
                    ann_seas_mean[case][varn][season] = da.groupby('year').mean(dim='time')
    return seas_mean, ann_seas_mean


def windSpd(u, v):
    return np.sqrt(u**2 + v**2)
