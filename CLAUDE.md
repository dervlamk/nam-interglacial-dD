# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A paleoclimate research project analyzing iCESM1.2 (isotope-enabled CESM) simulations of the Last
Interglacial (LIG, ~127ka) and Last Glacial Maximum (LGM, ~21ka), compared against pre-industrial
(PI) control and proxy records (water isotopes in speleothems/sediment cores, expressed as δD).
It is not a software package — there is no build, lint, or test suite. The deliverables are the
three top-level Jupyter notebooks and the figures they produce.

This is an NCAR HPC (Casper/Derecho, "glade" filesystem) workflow, not portable off that system.
Raw/scratch data-directory paths are read from `config/paths.env` (see "Path configuration"
below) rather than hardcoded, but everything else (case names, per-file variable lists) is still
hand-edited per script.

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
  - `data_funcs.py` — the canonical source for `get_xy_coords`/`get_season`, plus
    `longitude_flip`, `regrid_like`, `latitude_weighted_mean`, used to work with xarray
    DataArrays whose lat/lon/time coordinate names vary between datasets.
  - `map_plot_tools.py`, `line_plot_tools.py`, `plot_tools.py` all `from data_funcs import *`
    rather than redefining `get_xy_coords`/`get_season` locally — don't reintroduce local copies
    of those two functions when editing these files.
  - `map_plot_tools.py` — cartopy-based map plotting (`quick_map` and friends).
  - `line_plot_tools.py` — line/seasonal-cycle plotting.
  - `colorbar_funcs.py` — colormap construction/clipping/combination utilities (works with
    matplotlib, cmocean, colorcet).
  - `plot_tools.py` — still not imported by any notebook (superseded by `map_plot_tools.py`), but
    it is now a valid, working module if something starts depending on it.
- `scripts/ncl/` — NCL scripts that build intermediate netCDF files from raw CESM history/
  timeseries output on `/glade/campaign/...`. Each is a standalone, hand-edited script (variable
  lists are edited in place, not passed as arguments); base directories come from
  `config/paths.env` via `getenv()`:
  - `make_2d_atm_vars_nc.ncl`, `make_3d_atm_vars_nc.ncl`, `make_ocn_vars_nc.ncl`,
    `make_sst_nc.ncl`, `make_dh_isotope_vars_nc.ncl`, `make_o_isotope_vars_nc.ncl`,
    `maketimeseries.ncl` — concatenate per-variable CESM output files (atmosphere/ocean, 2D/3D,
    D/H and O isotopes) into single per-experiment netCDF files.
  - `pressureRegrid.ncl`, `pressureRegrid_LIG.ncl`, `pressureRegrid_PI_climo.ncl`,
    `pressureRegrid_isotopes.ncl` — interpolate 3D fields (and isotope tracers) from the model's
    hybrid sigma-pressure levels onto fixed pressure levels via `vinth2p`.
    **Note:** despite its name, `pressureRegrid_LIG.ncl`'s actual output is PI-climatology data,
    functionally overlapping with `pressureRegrid_PI_climo.ncl` — this predates any of the
    reorganization work and hasn't been resolved; confirm which one you mean before relying on it.
- `scripts/nco/` — NCO (`ncks`/`ncap2`) wrappers for isotope post-processing (extracting isotope
  tracer variables, integrating isotope ratios over levels). Require `module load nco`; source
  `config/paths.env` themselves (fail with an explicit error if it doesn't exist yet).
- `proxy_data/*.csv` — timeslice-mean proxy δD records (Holocene, LGM, LIG) by core, with lon/lat
  and 1-sigma error, used in the notebooks to validate model output against real-world records.
  Only `timeslice_mean_proxy_dDraw.csv` is actually read by the notebooks; see
  `proxy_data/README.md` for the (inferred, unconfirmed) relationship between the two files and
  what's still undocumented about their provenance.

## Data pipeline (order of operations)

1. Raw CESM output lives on `/glade/campaign/.../iCESM1.2/...` (per-experiment, per-variable
   timeseries or climatology files) — not in this repo.
2. `scripts/ncl/make_*.ncl` scripts concatenate/select variables into per-experiment intermediate
   netCDF files (written to `$SCRATCH_DIR/PI` or `$SCRATCH_DIR/LIG`).
3. `scripts/ncl/pressureRegrid*.ncl` regrid 3D fields onto standard pressure levels where needed.
4. `scripts/nco/*.sh` scripts extract/derive isotope-related variables from climo files.
5. Notebooks load the resulting netCDF files with xarray, compute derived quantities (isotope
   ratios in per-mil notation, precipitation-weighted isotope values, LIG−PI / LGM−PI
   differences), and produce figures — compared where relevant against `proxy_data/*.csv` and
   external obs/reanalysis (e.g. IMERG precip, ETOPO topography) under `$WORK_DATA_DIR`.

Each stage's output path is still consumed by the next stage's input path by construction (e.g.
an NCL script's `opath` == the shell script's `DATADIR` == the notebook's `dpath0`) — changing
where one stage writes still requires updating the next stage's read location to match. See
"Path configuration" for how those base directories are set today.

## Path configuration

Base data directories (`SCRATCH_DIR`, `WORK_DATA_DIR`, `PI_CLIMO_DIR`, `LIG_CASE_DIR`,
`LIG_TIMESERIES_JS_DIR`) live in `config/paths.env` (gitignored; copy from
`config/paths.env.example`):

- `scripts/nco/*.sh` source it directly.
- `scripts/ncl/*.ncl` read it via NCL's `getenv()` — `source config/paths.env` in your shell
  before invoking `ncl`.
- Notebooks read `WORK_DATA_DIR` via `os.environ.get('WORK_DATA_DIR', '/glade/work/dervlamk')`, so
  they still work with no setup at all, defaulting to the original hardcoded path.

Everything else (CESM case/file names, per-variable lists inside each script) is still hardcoded
per script, matching the specific simulation each script was written for.

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

This only works if the notebook is run from the repo root (so `'.'` resolves there).

## Environment

Notebooks run under a Jupyter kernel named `gcm_analysis` (see notebook metadata
`kernelspec.name`). `environment.yml` mirrors that env (`conda env create -f environment.yml`).
NCL scripts require an NCL install with `NCARG_ROOT` set (loaded via `module load ncl` or similar
on Casper/Derecho, not conda-installable); shell scripts require `module load nco` (also handled
by `environment.yml` via conda-forge's `nco`/`cdo` packages if you'd rather not rely on modules).

## Repo tooling (not part of the science pipeline)

`tools/strip_notebook_output.py` clears notebook cell outputs/execution counts; wired up as a git
clean filter via `.gitattributes` (`*.ipynb filter=stripoutput`). Run `tools/setup_git_filters.sh`
once per clone to register the filter locally (git filter config isn't versioned). This keeps
embedded figure outputs out of git history — don't remove the filter setup without replacing it
with something equivalent, or the notebooks will balloon back to multi-MB commits.

## Working with the notebooks

- These notebooks are long and stateful — cells build up dictionaries (`dat`, `files`, `dDp`,
  `d18Op`, etc.) keyed by simulation (`'pi'`, `'lig'`, `'lgm'`) and variable name, and later cells
  depend on earlier ones having been run in order.
- Isotope ratios are computed as per-mil (‰) deviations: `(heavy/light - 1) * 1000`, with a tiny
  floor value substituted for near-zero denominators to avoid divide-by-zero.
- Precipitation-weighted isotope averages are standard here: isotope ratios are weighted by each
  month's fraction of annual total precipitation before combining across months.
- When editing a notebook, use a notebook-aware tool (e.g. Claude Code's NotebookEdit) rather than
  treating the file as plain text/JSON — the plain Edit tool refuses `.ipynb` files outright.
