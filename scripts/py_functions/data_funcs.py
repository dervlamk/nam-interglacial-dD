import os
import sys
import xarray as xr
import netCDF4 as nc
import numpy as np
import metpy.calc as mp
from datetime import datetime


#############################

def get_xy_coords(var):
    """
    Get lon and lat arrays without knowing coordinate names
    """
    if isinstance(var, xr.DataArray):
        x,y=var.metpy.coordinates('x','y')
        return(x,y)
    if isinstance(var, xr.Dataset):
        print('This is a dataset. Please use an xarray DataArray')

def get_season(season='ann'):
    """
    Index months to average over to derive an annual or seasonal mean
        - can only be applied to monthly climatologies
    """
    mons = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    if season in ['ANNUAL', 'ANN', 'ann']:
        mons = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    if season in ['DJF', 'djf']:
        mons = [0, 1, 11]
    if season in ['JFM', 'jfm']:
        mons = [0, 1, 2]
    if season in ['MAM', 'mam']:
        mons = [2, 3, 4]
    if season in ['JJA', 'jja']:
        mons = [5, 6, 7]
    if season in ['JJAS', 'jjas']:
        mons = [5, 6, 7, 8]
    if season in ['JAS', 'jas']:
        mons = [6, 7, 8]
    if season in ['SON', 'son']:
        mons = [8, 9, 10]
    if season==None:
        mons = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    return mons


def lonFlip(var):
    """
    Convert longitude values from the -180:180 to 0:360 convention or vice versa.

    ** Works for both global data due to auto-detection of longitude convention **
    More efficient than rolling: only relabels coordinates + sorts.

    Parameters
    ----------
    var : xr.DataArray or xr.Dataset
    """

    #=== Get var info
    try:
        lon_name = var.cf.axes["X"][0]
    except KeyError:
        # fallback: find coordinate with 'lon' in its name
        lon_name = [c for c in var.coords if 'lon' in c.lower()][0]
    # extract lon array
    lon=var[lon_name]

    #=== Detect current longitude convention and wrap values
    if lon.min() < 0:
        # -180:180 -> 0:360
        new_lon = lon % 360
        target_range = "0:360"
    else:
        # 0:360 -> -180:180
        new_lon = ((lon + 180) % 360) - 180
        target_range = "-180:180"

    #=== Assign and sort
    var = var.assign_coords({lon_name: new_lon}).sortby(lon_name)

    #=== Add history
    timestamp = datetime.now().strftime("%B %d, %Y, %r")
    hist_message = f"wrapped longitudes to {target_range} on {timestamp}"
    if isinstance(var, xr.DataArray):
        var.attrs["history"] = hist_message
    else: # Dataset
        var.attrs["history"] = var.attrs.get("history","") + "\n" + hist_message

    return var

def regrid_like(ref, var):
    """
    Regrid data to match a reference 
    ** Only works for global data **
    
    Parameters
    ----------
    ref : reference array
    var : variable array to regrid
    """ 
    x_ref,y_ref=get_xy_coords(ref) # lat lon coords from reference variable
    x_var,_=get_xy_coords(var) # lat lon coords from variable to be regridded
    
    # if longitudes are referenced differently, flip lons of variable
    if np.sign(min(x_ref)) != np.sign(min(x_var)):
        var=longitude_flip(var)
        x_var,y_var=get_xy_coords(var)
    
    # rename coordinates to match reference
    var=var.rename({x_var.name:x_ref.name, y_var.name:y_ref.name})
    
    # interpolate var data
    var_regridded=var.interp_like(ref, method='linear')
    return(var_regridded)

def latitude_weighted_mean(var):
    """
    Calculate the mean of geospatial data taking into account unequal grid cell area
    """
    # get x and y coordinate data
    lons,lats = get_xy_coords(var)
    # determine weight based on latitude value
    weights = np.cos(np.deg2rad(lats))
    weights.name = 'weights'
    # calculate area-weighted values
    weighted_var = var.weighted(weights)
    # calculate global mean of weighted data
    weighted_mean = weighted_var.mean(dim=[lats.name,lons.name], keep_attrs=True)
    return(weighted_mean)
