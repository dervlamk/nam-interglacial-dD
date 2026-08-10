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
    'dDp':   {'units': u'‰',     'long_name': u'precipitation-weighted δD of precipitation',
              'source': 'PREC{RC,RL,SC,SL}_HDO over H2O equivalents, weighted by PRECT'},
    'd18Op': {'units': u'‰',     'long_name': u'precipitation-weighted δ18O of precipitation',
              'source': 'PREC{RC,RL,SC,SL}_H218O over H216O equivalents, weighted by PRECT'},
}

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


def derive_dat(raw, cases, dat_varns, time_dim):
    """Build the dat_varns-keyed derived dict (unit conversions, PRECT, dDp, d18Op) from a
    raw[case][varn] dict. Used once for the climatology (time_dim='month') and once for the
    per-year subset (time_dim='time') -- the isotope/precip-weighting math is identical, only
    the name of the shared time axis differs. Factored out so the dDp/d18Op formula has one
    source, not two copies that can drift apart.

    With time_dim='time' the arrays must carry a `year` coord (assign_cesm_month_year or
    assign_paleocal_month_year put one there); precipitation weights are formed within each
    year, not across the whole record.

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
                #== calculate precipitation-weighted fields
                # Weights are each month's share of its OWN year's total precipitation, so they sum to 1 per year on either axis.
                if time_dim == 'month':
                    annual_total_p = dat[case]['PRECT'].sum(dim='month')
                    pWeights = dat[case]['PRECT']/annual_total_p
                else:
                    annual_total_p = dat[case]['PRECT'].groupby('year').sum('time')
                    pWeights = dat[case]['PRECT'].groupby('year')/annual_total_p
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
                    # Multiply isotope values by weights
                    dat[case][varn] = dd*pWeights
                elif varn=='d18Op':
                    # Oxygen
                    p16o = raw[case]['PRECRC_H216Or'] + raw[case]['PRECRL_H216OR'] + raw[case]['PRECSC_H216Os'] + raw[case]['PRECSL_H216OS']
                    p18o = raw[case]['PRECRC_H218Or'] + raw[case]['PRECRL_H218OR'] + raw[case]['PRECSC_H218Os'] + raw[case]['PRECSL_H218OS']
                    # replace very small ph values with a tiny value
                    p16o = p16o.where(p16o > ptiny, ptiny)
                    # turn into per mil notation
                    do = (p18o/p16o - 1)*1000
                    # Multiply isotope values by weights
                    dat[case][varn] = do*pWeights
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


def seasonal_means(dat_ts, cases, dat_varns, seasons):
    """Seasonal means of a per-year derived dict, both collapsed and per-year.

    Returns
    -------
    seas_mean     : [case][varn][season] -- mean over every month in the season, all years.
    ann_seas_mean : [case][varn][season] -- one value per simulation year, which is the
                    sample the significance tests in stats_funcs.py consume.
    """
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
                seas_mean[case][varn][season] = da.mean(dim='time')
                ann_seas_mean[case][varn][season] = da.groupby('year').mean(dim='time')
    return seas_mean, ann_seas_mean


def windSpd(u, v):
    return np.sqrt(u**2 + v**2)
