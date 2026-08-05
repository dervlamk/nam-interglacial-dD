# nam-lastinterglacial

Analysis of isotope-enabled CESM1.2 (iCESM1.2) paleoclimate simulations of the **Last Interglacial**
(LIG, ~127 ka) and **Last Glacial Maximum** (LGM, ~21 ka), compared against a pre-industrial (PI)
control and against proxy water-isotope (δD) records. The focus is on precipitation, moisture
transport, and water isotopes over North America (including the North American Monsoon region),
evaluated seasonally (ANN / JFM / JAS).

This is a research-analysis repository, not a software package: there is no build/test suite, and
the "output" is the set of Jupyter notebooks and the figures they produce.

## Repository structure

```
.
├── LGM_analyses.ipynb                          # LGM vs. PI analysis and figures
├── LIG127k_analyses_PALEOCALADJUSTED.ipynb     # LIG vs. PI analysis (calendar-adjusted, canonical)
├── LIG127k_analyses_NOT_paleocaladjust.ipynb   # LIG vs. PI analysis (calendar not adjusted)
├── proxy_data/                                 # Timeslice-mean proxy δD records by core (Holocene/LGM/LIG)
└── scripts/
    ├── *.ncl                                   # Concatenate/regrid raw CESM output into intermediate netCDFs
    ├── *.sh                                    # NCO (ncks/ncap2) isotope post-processing
    └── py_functions/                           # Shared xarray/cartopy plotting & data helpers used by the notebooks
```

### Which LIG notebook to use

`LIG127k_analyses_PALEOCALADJUSTED.ipynb` is the canonical version — paleoclimate orbital-forcing
runs shift month boundaries relative to a modern fixed calendar, and this notebook corrects for
that before computing monthly climatologies. `LIG127k_analyses_NOT_paleocaladjust.ipynb` is kept
for comparison but should not be treated as the primary result.

## Data pipeline

Raw iCESM1.2 output is not stored in this repo — it lives on NCAR's `/glade/campaign/...`
filesystem. The pipeline runs in four stages:

1. **NCL concatenation** (`scripts/make_*.ncl`, `scripts/maketimeseries.ncl`) — build per-experiment
   netCDF files from raw CESM history/timeseries output (2D/3D atmosphere, ocean, SST, D/H and O
   isotope variables).
2. **Pressure-level regridding** (`scripts/pressureRegrid*.ncl`) — interpolate 3D fields from the
   model's hybrid sigma-pressure levels onto standard pressure levels via `vinth2p`.
3. **NCO isotope post-processing** (`scripts/*.sh`) — extract/derive isotope tracer variables
   (requires `module load nco`).
4. **Python analysis** (top-level notebooks) — load the intermediate netCDFs with xarray, compute
   isotope ratios in per-mil (‰) notation, precipitation-weight them, take LIG−PI / LGM−PI
   differences, and produce figures, validating against `proxy_data/*.csv` and external
   observational datasets (e.g. IMERG precipitation, ETOPO topography).

Each stage's output path is currently hardcoded in the script/notebook that produced it and in the
one that consumes it — see `CLAUDE.md` for the full file-by-file breakdown.

## Environment

Notebooks run under a Jupyter kernel named `gcm_analysis`. Recreate it with:

```bash
conda env create -f environment.yml
conda activate gcm_analysis
python -m ipykernel install --user --name gcm_analysis
```

This installs xarray, netCDF4, metpy, cartopy, cmocean, colorcet, seaborn, scipy, pandas, and the
command-line `nco`/`cdo` tools used by `scripts/*.sh`. NCL scripts additionally require a separate
NCL install (`module load ncl` or similar on NCAR systems — NCL is not conda-installable here).
This workflow assumes an NCAR HPC environment (Casper/Derecho) — paths are not portable elsewhere
without editing.

## Running a notebook

Notebooks import shared helpers from `scripts/py_functions/` via a relative `sys.path` addition, so
they must be launched with the repository root as the working directory:

```python
module_path = os.path.abspath(os.path.join('.'))
sys.path.append(module_path + "/scripts/py_functions")
```

See `CLAUDE.md` for more detail on the codebase's internal structure and conventions.

## Setup

After cloning, run:

```bash
./tools/setup_git_filters.sh
```

This registers a git clean filter that strips notebook cell outputs (embedded figures,
execution counts) before they're committed, so notebook diffs stay readable and git history
doesn't balloon with binary image data. See `.gitattributes` / `tools/strip_notebook_output.py`.
