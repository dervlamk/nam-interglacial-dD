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
        pass
    return mons

def longitude_flip(var):
    """ Convert longitude values from the -180:180 to 0:360 convention or vice versa.
        
        ** Only works for global data. Do not apply to data with a clipped longitude range **
        
        Parameters
        ----------
        var : Data Array
    """    
    # get var info
    x,_=get_xy_coords(var) # extract original longitude values
    lon_name=x.name        # store name of longitude coordinate
    nx=len(x)              # longitude resolution
    
    # determine longitude format and create an array of new lons in opposite convention
    if min(x)<0: 
        # if there are negative values, data is -180:180 and need to switch to 0:360
        new_lons=np.linspace((min(x)+180), (max(x)+180), nx)
    elif max(x)>180:
        # if the max value is >180, data is in 0:360 format and need to switch to -180:180
        new_lons=np.linspace((min(x)-180), (max(x)-180), nx)
        
    # shift the data by 180° of longitude
    nshift=nx//2
    var=var.roll({lon_name: nshift}, roll_coords=False)
            
    # update longitude coord with new values
    var=var.assign_coords({lon_name: new_lons})
    
    # add attributes documenting change
    timestamp=datetime.now().strftime("%B %d, %Y, %r")
    var.attrs['history']=f'flipped longitudes {timestamp}'
    var.attrs['original_lons']=x.values
    
    return(var)

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
