# nam-interglacial-dD

Analysis of isotope-enabled CESM1.2 (iCESM1.2) paleoclimate simulations of the **Last Interglacial**
(LIG, ~127 ka) and **Last Glacial Maximum** (LGM, ~21 ka), compared against a pre-industrial (PI)
control and against proxy water-isotope (δD) records. The focus is on precipitation, moisture
transport, and water isotopes over North America (including the North American Monsoon region),
evaluated seasonally (ANN / JFM / JAS).

The proxy records are leaf-wax δD (C30 fatty-acid methyl esters) from two Gulf of California
sediment cores — NH22P and DSDP-480/479 — converted to δD of precipitation and to percent-of-annual
July–August–September rainfall, the monsoon-strength metric.

This is a research-analysis repository, not a software package: there is no build/test suite, and
the "output" is the set of Jupyter notebooks and the figures they produce.

## Two halves, two machines

Neither machine holds all the data, deliberately:

| | Model half | Proxy half |
|---|---|---|
| Runs on | **NCAR HPC only** (Casper/Derecho, `/glade`) | **Laptop only** (OneDrive) |
| Language | NCL + NCO + Python | MATLAB + Python |
| Notebooks | `LGM_analyses`, `LIG127k_analyses_*` | `fig1`–`fig3` |

iCESM output is never copied off `/glade`; proxy and observational data is never copied onto it.
Only small derived products cross, and they cross *through this repo* — which is why
`proxy_data/*.csv` is tracked. The MATLAB under `scripts/matlab/` is present in a Casper clone
for provenance and editing but **cannot run there** (it needs a local MATLAB plus toolbox
functions outside this repo). That is expected.

## Repository structure

```
.
├── LGM_analyses.ipynb                          # MODEL: LGM vs. PI analysis and figures
├── LIG127k_analyses_PALEOCALADJUSTED.ipynb     # MODEL: LIG vs. PI (calendar-adjusted, canonical)
├── LIG127k_analyses_NOT_paleocaladjust.ipynb   # MODEL: LIG vs. PI (calendar not adjusted)
├── fig1_swna_modern_climate.ipynb              # PROXY: modern SW-NA climatology (OIPC/IMERG/ETOPO5)
├── fig2_dsdp480-479_agemodel.ipynb             # PROXY: Bacon age-depth models + the 480/479 splice
├── fig3_dDwax_timeseries.ipynb                 # PROXY: δD records vs. LR04; writes proxy_data/*.csv
├── environment.yml                             # gcm_analysis conda environment spec
├── config/
│   └── paths.env.example                       # Template for local path overrides (copy to paths.env)
├── proxy_data/                                 # Timeslice-mean proxy δD by core; see its README
├── deprecated/                                 # Superseded code, frozen for provenance — reference only
├── tools/                                      # Repo tooling (notebook-output stripping)
└── scripts/
    ├── matlab/                                 # PROXY pipeline: dDwax → dDp → %JAS (laptop only)
    ├── ncl/                                    # Concatenate/regrid raw CESM output into intermediate netCDFs
    ├── nco/                                    # NCO (ncks/ncap2) isotope post-processing
    ├── py_functions/                           # Shared xarray/cartopy plotting & data helpers
    └── claude_casper.sh                        # Interactive Casper compute node (stay off login nodes)
```

### Which LIG notebook to use

`LIG127k_analyses_PALEOCALADJUSTED.ipynb` is the canonical version — paleoclimate orbital-forcing
runs shift month boundaries relative to a modern fixed calendar, and this notebook corrects for
that before computing monthly climatologies. `LIG127k_analyses_NOT_paleocaladjust.ipynb` is kept
for comparison but should not be treated as the primary result.

## Data pipeline

Raw iCESM1.2 output is not stored in this repo — it lives on NCAR's `/glade/campaign/...`
filesystem. The pipeline runs in four stages:

1. **NCL concatenation** (`scripts/ncl/make_*.ncl`, `scripts/ncl/maketimeseries.ncl`) — build
   per-experiment netCDF files from raw CESM history/timeseries output (2D/3D atmosphere, ocean,
   SST, D/H and O isotope variables).
2. **Pressure-level regridding** (`scripts/ncl/pressureRegrid*.ncl`) — interpolate 3D fields from
   the model's hybrid sigma-pressure levels onto standard pressure levels via `vinth2p`.
3. **NCO isotope post-processing** (`scripts/nco/*.sh`) — extract/derive isotope tracer variables
   (requires `module load nco`).
4. **Python analysis** (top-level notebooks) — load the intermediate netCDFs with xarray, compute
   isotope ratios in per-mil (‰) notation, precipitation-weight them, take LIG−PI / LGM−PI
   differences, and produce figures, validating against `proxy_data/*.csv` (see
   `proxy_data/README.md`) and external observational datasets (e.g. IMERG precipitation, ETOPO
   topography).

Each stage's output path is consumed by the next stage's input path (e.g. an NCL script's `opath`
is the shell script's `DATADIR`, which is the notebook's `dpath0`) — see `CLAUDE.md` for the full
file-by-file breakdown, and "Path configuration" below for how those paths are set.

### Path configuration

Raw/scratch directory paths are read from environment variables rather than hardcoded, so a new
clone only needs one file edited:

```bash
cp config/paths.env.example config/paths.env
# edit config/paths.env for your own SCRATCH_DIR / WORK_DATA_DIR / etc.
source config/paths.env
```

- `scripts/nco/*.sh` source `config/paths.env` automatically (and fail with a clear error if it's
  missing).
- `scripts/ncl/*.ncl` read these via NCL's `getenv()`, so `source config/paths.env` in your shell
  before running `ncl`.
- Notebooks read `WORK_DATA_DIR` via `os.environ.get(...)`, falling back to the original
  `/glade/work/dervlamk` if it's unset, so they still run out-of-the-box without any setup.

`config/paths.env` is gitignored — it holds machine/user-specific paths, not something to commit.

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
