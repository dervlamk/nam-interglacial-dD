# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A paleoclimate research project analyzing iCESM1.2 (isotope-enabled CESM) simulations of the Last
Interglacial (LIG, ~127ka) and Last Glacial Maximum (LGM, ~21ka), compared against pre-industrial
(PI) control and proxy records (water isotopes in speleothems/sediment cores, expressed as δD).
It is not a software package — there is no build, lint, or test suite. The deliverables are the
three top-level Jupyter notebooks and the figures they produce.

This is an NCAR HPC (Casper/Derecho, "glade" filesystem) workflow. Scripts contain hardcoded
absolute paths under `/glade/...` and are not portable off that system.

## Repository layout

- `LGM_analyses.ipynb`, `LIG127k_analyses_NOT_paleocaladjust.ipynb`,
  `LIG127k_analyses_PALEOCALADJUSTED.ipynb` — the analysis notebooks. Each is self-contained: it
  sets file paths, loads netCDF output with xarray, derives isotope ratios, and produces
  publication figures. These are large (multi-MB) notebooks with embedded plot outputs.
  - `NOT_paleocaladjust` vs `PALEOCALADJUSTED` are two versions of the LIG analysis that differ in
    whether the model's simulated-calendar output has been adjusted to a fixed calendar
    (paleoclimate orbital-forcing runs shift month boundaries relative to modern calendars — see
    the calendar-adjustment cell in the PALEOCALADJUSTED notebook, which nudges timestamps by a
    couple of days before grouping by month). Prefer the `PALEOCALADJUSTED` version for anything
    LIG-related unless there's a specific reason to compare against the unadjusted output.
- `scripts/py_functions/` — shared Python helpers imported by the notebooks via `sys.path` (see
  "Import pattern" below):
  - `data_funcs.py` — coordinate-agnostic helpers (`get_xy_coords`, `get_season`,
    `longitude_flip`, `regrid_like`, `latitude_weighted_mean`) used to work with xarray
    DataArrays whose lat/lon/time coordinate names vary between datasets.
  - `map_plot_tools.py` — cartopy-based map plotting (`quick_map` and friends).
  - `line_plot_tools.py` — line/seasonal-cycle plotting.
  - `colorbar_funcs.py` — colormap construction/clipping/combination utilities (works with
    matplotlib, cmocean, colorcet).
  - `plot_tools.py` — **dead code**, imports a nonexistent `misc_functions` module and is not
    imported by any notebook or script. Do not build on it without fixing the missing import.
- `scripts/*.ncl` — NCL scripts that build intermediate netCDF files from raw CESM history/
  timeseries output on `/glade/campaign/...`. Each is a standalone, hand-edited script (paths and
  variable lists are edited in place, not passed as arguments):
  - `make_2d_atm_vars_nc.ncl`, `make_3d_atm_vars_nc.ncl`, `make_ocn_vars_nc.ncl`,
    `make_sst_nc.ncl`, `make_dh_isotope_vars_nc.ncl`, `make_o_isotope_vars_nc.ncl`,
    `maketimeseries.ncl` — concatenate per-variable CESM output files (atmosphere/ocean, 2D/3D,
    D/H and O isotopes) into single per-experiment netCDF files.
  - `pressureRegrid.ncl`, `pressureRegrid_LIG.ncl`, `pressureRegrid_PI_climo.ncl`,
    `pressureRegrid_isotopes.ncl` — interpolate 3D fields (and isotope tracers) from the model's
    hybrid sigma-pressure levels onto fixed pressure levels via `vinth2p`.
- `scripts/*.sh` — NCO (`ncks`/`ncap2`) wrappers for isotope post-processing (extracting isotope
  tracer variables, integrating isotope ratios over levels). Require `module load nco`.
- `proxy_data/*.csv` — timeslice-mean proxy δD records (Holocene, LGM, LIG) by core, with lon/lat
  and 1-sigma error, used in the notebooks to validate model output against real-world records.
  `_dD` and `_dDraw` variants differ in whether values are pre-processed/normalized.

## Data pipeline (order of operations)

1. Raw CESM output lives on `/glade/campaign/.../iCESM1.2/...` (per-experiment, per-variable
   timeseries or climatology files) — not in this repo.
2. `scripts/*.ncl` scripts concatenate/select variables into per-experiment intermediate netCDF
   files (written to scratch, e.g. `/glade/derecho/scratch/dervlamk/...` or
   `/glade/scratch/dervlamk/...`).
3. `scripts/pressureRegrid*.ncl` regrid 3D fields onto standard pressure levels where needed.
4. `scripts/*.sh` (NCO) scripts extract/derive isotope-related variables from climo files.
5. Notebooks load the resulting netCDF files with xarray, compute derived quantities (isotope
   ratios in per-mil notation, precipitation-weighted isotope values, LIG−PI / LGM−PI
   differences), and produce figures — compared where relevant against `proxy_data/*.csv` and
   external obs/reanalysis (e.g. IMERG precip, ETOPO topography) referenced by absolute path.

Because each stage's output path is hardcoded and consumed by the next stage's hardcoded input
path, changing an NCL/shell script's `opath`/`ofile` requires updating every downstream
consumer (including the notebook's `files{}` dict) to match.

## Import pattern used in notebooks

Notebooks add `scripts/py_functions` to `sys.path` relative to the notebook's own directory, then
do wildcard imports:

```python
module_path = os.path.abspath(os.path.join('.'))
if module_path not in sys.path:
    sys.path.append(module_path + "/scripts/py_functions")
from map_plot_tools import *
from line_plot_tools import *
from colorbar_funcs import *
from data_funcs import *
```

This only works if the notebook is run from the repo root (so `'.'` resolves there). When editing
files in `scripts/py_functions/`, check both `data_funcs.py` (canonical version of helpers like
`get_xy_coords`/`get_season`) and the near-duplicate definitions re-implemented locally in
`line_plot_tools.py`/`plot_tools.py` — they are not shared via a single import and can drift.

## Environment

Notebooks run under a Jupyter kernel named `gcm_analysis` (see notebook metadata
`kernelspec.name`). There is no `environment.yml`/`requirements.txt` in this repo; the kernel's
package set (xarray, netCDF4, metpy, cartopy, cmocean, colorcet, seaborn, scipy) must already
exist in that conda environment. NCL scripts require an NCL install with `NCARG_ROOT` set (loaded
via `module load ncl` or similar on Casper/Derecho); shell scripts require `module load nco`.

## Working with the notebooks

- These notebooks are long and stateful — cells build up dictionaries (`dat`, `files`, `dDp`,
  `d18Op`, etc.) keyed by simulation (`'pi'`, `'lig'`, `'lgm'`) and variable name, and later cells
  depend on earlier ones having been run in order.
- Isotope ratios are computed as per-mil (‰) deviations: `(heavy/light - 1) * 1000`, with a tiny
  floor value substituted for near-zero denominators to avoid divide-by-zero.
- Precipitation-weighted isotope averages are standard here: isotope ratios are weighted by each
  month's fraction of annual total precipitation before combining across months.
- When editing a notebook, prefer editing it as JSON/via nbformat-aware tools rather than treating
  it as plain text — these files are large and cell outputs (embedded images) make naive
  text-diffing impractical.
