import numpy as np


def rotated_box(lon0, lat0, width, height, angle_deg):
    """Return the four corners of a rotated rectangular polygon centered at (lon0, lat0).

    Parameters
    ----------
    lon0, lat0   : center longitude and latitude
    width, height: full width and height in degrees
    angle_deg    : counter-clockwise rotation angle in degrees
    """
    angle = np.deg2rad(angle_deg)
    dx, dy = width / 2, height / 2
    corners = np.array([[-dx, -dy], [dx, -dy], [dx, dy], [-dx, dy]])
    R = np.array([[np.cos(angle), -np.sin(angle)],
                  [np.sin(angle),  np.cos(angle)]])
    rotated = corners @ R.T
    rotated[:, 0] += lon0
    rotated[:, 1] += lat0
    return rotated


def lonlat_box(lon_min, lon_max, lat_min, lat_max):
    """An axis-aligned lon/lat rectangle as a shapely Polygon.

    For drawing a region on a cartopy map with
    ``ax.add_geometries([...], crs=ccrs.PlateCarree())`` — the same call used for
    nam_domain_outline(), so maps have one way of putting a region on an axis rather than
    mixing add_geometries with LinearRing or matplotlib patches.
    """
    from shapely.geometry import box
    return box(lon_min, lat_min, lon_max, lat_max)


def core_site_boxes():
    """The two core-site sampling regions, as shapely Polygons keyed by site.
    """
    return {
        'Guaymas':  lonlat_box(-114, -109, 26, 30),
        'Mazatlan': lonlat_box(-111, -106, 20, 24),
    }


def polygon_mask(da, poly):
    """Boolean mask of the grid cells of `da` whose centres fall inside shapely `poly`.

    The regionmask-free counterpart to regional_weighted_mean() below — `nam_dD_lig` does not
    carry regionmask, and this only needs shapely, which it does carry.

    Longitude convention is handled here: the polygons in this module are -180:180 (that is the
    convention the proxy lon/lat columns use, and what cartopy's PlateCarree wants for
    add_geometries), while the model and IMERG grids are 0:360. Cell centres are wrapped to
    -180:180 before the containment test, and the mask comes back on `da`'s own coordinates, so
    the caller never has to think about it.

    Parameters
    ----------
    da   : xr.DataArray with 'lat' and 'lon' coordinates
    poly : shapely Polygon in the -180:180 convention, e.g. nam_domain_outline()
    """
    import xarray as xr
    from shapely import contains_xy

    lon = ((da['lon'].values + 180) % 360) - 180
    lon2d, lat2d = np.meshgrid(lon, da['lat'].values)
    mask = contains_xy(poly, lon2d, lat2d)
    return xr.DataArray(mask, coords={'lat': da['lat'], 'lon': da['lon']}, dims=('lat', 'lon'))


def polygon_weighted_mean(da, poly):
    """cos(lat)-weighted mean of `da` over the cells inside `poly`.

    Same weighting as regional_weighted_mean() below and as the core-site box means in the
    model notebooks, so a domain mean and a box mean are computed the same way. Cells outside
    the polygon are set to NaN and skipped, which is what makes this differ from slicing a
    lat/lon rectangle: an angled or non-rectangular domain keeps its actual shape.
    """
    weights = np.cos(np.deg2rad(da['lat']))
    return da.where(polygon_mask(da, poly)).weighted(weights).mean(('lat', 'lon'))


def regional_weighted_mean(da, regions):
    """Area-weighted mean of da for all regions, returning a DataArray with a 'region' dim.

    Parameters
    ----------
    da      : xr.DataArray with 'lat' and 'lon' coordinates
    regions : regionmask.Regions object

    Returns
    -------
    xr.DataArray with a named 'region' coordinate; use .sel(region=name) to extract one.
    """
    mask3d = regions.mask_3D(da)
    weights = np.cos(np.deg2rad(da.lat))
    result = da.where(mask3d).weighted(weights).mean(("lat", "lon"))
    return result.assign_coords(region=mask3d.names)


def nam_domain_coords():
    """Return the NAM south/north sub-domain corner arrays.

    Geometry only — no regionmask dependency, so this is usable for plotting in environments
    where regionmask is not installed (which includes the `nam_dD_lig` env as it stands).

    Returns
    -------
    dict with keys 'south' and 'north', values are (4,2) corner arrays in the (-180:180)
    longitude convention — ready for matplotlib patches or shapely.
    """
    coords = {}

    # North: axis-aligned box
    coords['north'] = rotated_box(-110.5, 32.5, 8, 6, angle_deg=0)

    # South: a lobe whose top edge is north's southern edge (reusing north's two southern
    # corners is what makes the shared edge exact, which lets nam_domain_outline() dissolve it)
    # and whose southern corner is placed by two constraints:
    #
    #   * the southernmost corner sits at exactly SOUTH_CORNER_LAT
    #   * the southwest diagonal — which runs from that corner up to north's SW corner —
    #     passes west of the southern tip of the Baja Peninsula, so the cape is inside the
    #     domain rather than cut off by the boundary
    #
    # Those two fix the corner completely: it is where the line from the Baja anchor to north's
    # SW corner crosses SOUTH_CORNER_LAT. BAJA_CAPE is the southernmost point of the peninsula
    # in Natural Earth 10m; the margin pushes the edge west of it so the tip sits inside with
    # clearance rather than balanced on the line (anchoring on the cape exactly would leave it
    # on the boundary, and on a rounded 23N/110W it falls ~0.04 deg outside).
    SOUTH_CORNER_LAT = 20.0            # southern edge of the domain: BOTH bottom corners
    SOUTH_EAST_LON = -103.0            # eastern end of that southern edge
    BAJA_CAPE = (-109.954, 22.872)     # Cabo San Lucas, Natural Earth 10m
    BAJA_MARGIN = 0.15                 # deg of longitude west of the cape

    nw = coords['north'][0]            # north's SW corner: the top of the diagonal
    anchor = (BAJA_CAPE[0] - BAJA_MARGIN, BAJA_CAPE[1])
    t = (SOUTH_CORNER_LAT - anchor[1]) / (nw[1] - anchor[1])
    south_corner = np.array([anchor[0] + t * (nw[0] - anchor[0]), SOUTH_CORNER_LAT])

    # The bottom edge is horizontal, both corners on SOUTH_CORNER_LAT. Its western end is fixed
    # by the two constraints above; its eastern end is set outright. The original 35 deg tilt and
    # 4.5 deg width are gone — with both ends now pinned there is nothing left for them to set.
    bottom_right = np.array([SOUTH_EAST_LON, SOUTH_CORNER_LAT])

    coords['south'] = np.array([
        south_corner,        # bottom-left corner,  on the 20 N line
        bottom_right,        # bottom-right corner, on the 20 N line
        coords['north'][1],  # top-right = north's SE corner
        coords['north'][0],  # top-left  = north's SW corner
    ])
    return coords


def nam_domain_outline():
    """Return ONE polygon outlining the whole NAM domain, with no internal division.

    The south and north sub-domains share their entire boundary edge exactly (south's top two
    corners ARE north's bottom two, see nam_domain_coords), so a union dissolves that edge and
    leaves a single closed outline. Use this to draw the domain as one shape; use
    nam_domain_coords() when you want the sub-regions drawn separately.

    Returns
    -------
    shapely Polygon in the (-180:180) longitude convention. Pass straight to cartopy's
    ax.add_geometries([...], crs=ccrs.PlateCarree()), or take np.array(poly.exterior.coords)
    for the 6 corner vertices.
    """
    from shapely.geometry import Polygon
    from shapely.ops import unary_union

    coords = nam_domain_coords()
    merged = unary_union([Polygon(coords['south']), Polygon(coords['north'])])
    if merged.geom_type != 'Polygon':
        raise ValueError(f"sub-domains did not merge into a single polygon (got "
                         f"{merged.geom_type}); check that they still share an exact edge")
    return merged


def nam_regions():
    """Return the standard NAM south/north domain polygons and regionmask object.

    Requires regionmask. If you only need the geometry — to draw the domain on a map, say —
    use nam_domain_coords() or nam_domain_outline() instead and avoid the dependency.

    Returns
    -------
    coords_map : dict with keys 'south' and 'north', values are (4,2) corner arrays
                 in (-180:180) longitude convention — ready for matplotlib patches
    regions    : regionmask.Regions with names ['south', 'north']
                 coordinates are in (0:360) convention for regionmask masking
    """
    coords_map = nam_domain_coords()
    coords_calc = {k: [((lon + 360) % 360, lat) for lon, lat in v]
                   for k, v in coords_map.items()}

    import regionmask
    regions = regionmask.Regions(
        outlines=[coords_calc['south'], coords_calc['north']],
        names=["south", "north"],
        abbrevs=["south", "north"],
    )
    return coords_map, regions
