# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A paleoclimate research project reconstructing North American Monsoon strength across the last
two interglacials, with **two halves that run on different machines**:

| | Model half | Proxy half |
|---|---|---|
| What | iCESM1.2 simulations of LIG (~127 ka), LGM (~21 ka) vs. PI control | Leaf-wax δD from two Gulf of California cores (NH22P, DSDP-480/479) |
| Where | **NCAR HPC only** (Casper/Derecho, `/glade`) | **Laptop only** (proxy + obs data on OneDrive) |
| Language | NCL + NCO + Python notebooks | MATLAB + Python notebooks |
| Notebooks | `LGM_analyses`, `LIG127k_analyses_*` | `fig1_swna_modern_climate`, `fig2_dsdp480-479_agemodel`, `fig3_dDwax_timeseries` |

It is not a software package — there is no build, lint, or test suite. The deliverables are the
top-level Jupyter notebooks and the figures they produce.

**Neither machine has all the data, and that is deliberate.** iCESM output is never copied off
`/glade`; proxy and observational data is never copied onto it. Only small derived products
cross, and they cross *through this repo* — `data/processed/*.csv` is how the model notebooks
receive proxy numbers, which is why those CSVs are tracked. Paths for both halves come from
`config/paths.env` (see "Path configuration"); everything else (case names, per-file variable
lists) is still hand-edited per script.

**The MATLAB code in `scripts/matlab/` cannot run on Casper** — it needs a local MATLAB plus
four toolbox functions that live in `~/Documents/MATLAB/toolbox/`, outside this repo:
`icevolcorr`, `ebisuzaki`, `longitude_flip`, `shadedErrorBar3`. It is cloned to Casper for
provenance and editing only. That is expected, not broken. Vendoring those four into the repo
would make it self-contained; check redistribution first — `longitude_flip` is a port of an NCL
function by Donald Shea, and `ebisuzaki` implements a published method.

> **Read `DATA_MANIFEST.md` before building on the proxy side.**
>
> **Verified 2026-08-06:** the MATLAB pipeline was re-run from the reorganised tree and
> reproduces the stored products. NH22P is bit-identical on every field including both Monte
> Carlo ensembles; the DSDP-480/479 timeslice means reproduce
> `data/processed/timeslice_mean_proxy_dDraw.csv` to the last digit. Both cores are built from
> `dDraw` and from the canonical `Bacon_runs/DSDP480` age model.
>
> One residual, pre-existing and harmless: d479 ages differ by ≤67 yr from every stored vintage
> back to 2022, because `DSDP479_113_ages.txt` was re-run and `d479_FAMEs_*.mat` never
> regenerated. Zero samples change timeslice membership.

## Outstanding cleanup

Recorded here because it is not obvious from the code, and because doing these in the wrong
order costs rework.

### The MATLAB pipeline — verified 2026-08-06

`dDwax_data_processing_nh22p.m` then `dDwax_data_processing_d480_d479.m`, both on the laptop.
**Not** `dDp_epsilon_calculation.m`, whose output nothing reads (see below). They read from
`$PROXY_DATA_DIR` and write `*_FAMEs_<date>.mat` to `data/processed/`.

Re-run from the reorganised tree, they reproduce the stored products:

| | result |
|---|---|
| NH22P | **bit-identical** — `age`, `dDraw`, `stdev`, `dDivc`, and both Monte Carlo ensembles |
| DSDP-480 ages | 0.00000 ka |
| Guaymas `dDraw`, `stdev` | element-wise identical |
| Guaymas timeslice means | reproduce the committed CSV to the last digit |
| Guaymas `dDp` medians | 0.275‰ — the Monte Carlo floor (ε is one shared draw per iteration, so its median has SE ≈ 0.12‰) |

MATLAB seeds its RNG identically each session, which is why bit-identical reproduction is
achievable at all — a difference beyond ~0.3‰ means something real changed, not noise.

**Optional hardening:** `fig3` hardcodes `iters = 1000` and derives its shading indices from it.
That is correct now that both `dDp` sheets are 1000 wide, but
`np.nanpercentile(dDp, [2.5, 16, 84, 97.5], axis=1)` would be correct at any width and remove
the possibility of the two drifting apart again.

If the ensembles are ever regenerated, paste them into `*_processed_dD*.xlsx` leaving `Sheet1`
(the hand-entered GC-IRMS data) alone, re-run `fig3` to regenerate `data/processed/*.csv`, push,
and only then does Casper pull.

Better than repeating that manual paste: have the MATLAB `writematrix` the two ensembles to
their own files and repoint `fig3`. The paste is what produced the 1020-column error.

### Known duplication and rough edges

- **Two parallel MATLAB pipelines, and the newer one is not the one that matters.**
  `dDwax_data_processing_{nh22p,d480_d479}.m` (2024) is the pipeline everything downstream
  actually traces to. It runs end to end — raw δD → Bacon ages → ice-volume correction →
  δD<sub>p</sub> Monte Carlo → %JAS regression → save — and it is the **only** place the age
  assignment, the %JAS regression, and the DSDP-480/479 splice exist.

  `dDp_epsilon_calculation.m` (2025) was run more recently, but its output is consumed by
  nothing. Verified from the stored `.mat` dimensions:

  | File | Contents | From |
  |---|---|---|
  | `nh22p_FAMEs_01-May-2025.mat` | `dDp_raw` (118 × **2500**) | `dDp_epsilon_calculation.m` |
  | `nh22p_FAMEs_18-Apr-2025.mat` | `dDp` (118 × **1000**) + `jas` (118 × 4000) | `dDwax_data_processing_nh22p.m` |
  | `Guaymas_..._14-Apr-2025.mat` | `dDp` (147 × **1000**) + `jas` (147 × 4000) | `dDwax_data_processing_d480_d479.m` |

  The `dDp`/`pJAS` sheets in `*_processed_dD*.xlsx` — which `fig3` reads, which produce
  `data/processed/*.csv`, which the model notebooks then compare against — are 1000 and 4000
  wide at 118 and 147 rows. They came from the 2024 pipeline. **To regenerate anything the
  figures use, run `dDwax_data_processing_*.m`, not `dDp_epsilon_calculation.m`.**

  Neither is a superset of the other. Target: four single-purpose stages (process → assign ages
  → dDp → %JAS) with explicit inputs and outputs and no shared filename pattern.
- **The DSDP-480/479 splice happens in MATLAB, not by hand** —
  `dDwax_data_processing_d480_d479.m` lines 96–118 concatenate d480 (143 samples) and d479 (33)
  and sort by age. The saved `Guay` struct is already the 147-sample composite.
- **The NH22P `dDp` sheet was 1020 wide until 2026-08-06** — twenty foreign columns ahead of the
  canonical 1000, from the manual Excel paste. Trimmed; the sheet now equals
  `nh22p_FAMEs_18-Apr-2025.mat` exactly. The concrete argument for having the MATLAB
  `writematrix` the ensembles to their own files rather than pasting them by hand.
- **The two live pipeline scripts read `config/paths.env`; the rest do not.**
  `dDwax_data_processing_{nh22p,d480_d479}.m` resolve `PROXY_DATA_DIR` from the environment and
  fall back to parsing the file directly — necessary because MATLAB launched from the Dock does
  not inherit the shell environment. They use no `cd`. The remaining `.m` files
  (`dDp_epsilon_calculation.m`, `pJAS_calculation.m`, `SST_dD_correlation.m`, and the two
  `swna`/Tucson helpers) still `cd` to hardcoded absolute paths, all of which are dead. `cd` is
  not only a path problem — it mutates the working directory, making the scripts
  order-dependent.
- **`pJAS_calculation.m` is not self-contained** — it expects `X` and `Y` to already exist in the
  workspace, so it silently uses whatever is lying around if the precondition is wrong. Make it
  a function.
- **The spreadsheet round trip.** `Sheet1` of `*_processed_dD*.xlsx` is legitimate hand-entered
  GC-IRMS data, but the `dDp`/`pJAS` sheets beside it are computed ensembles pasted back in by
  hand. That is how they fell out of sync with `iters`. Have the MATLAB write ensembles to their
  own files instead.
- **`pressureRegrid_LIG.ncl` outputs PI-climatology data** despite its name, overlapping
  `pressureRegrid_PI_climo.ncl`. Confirm which produced the data in use before relying on either.
- **`scripts/py_functions/plot_tools.py` is imported by nothing** — superseded by
  `map_plot_tools.py`. Delete or move to `deprecated/`; an unused near-duplicate of the plotting
  layer invites divergence.
- **Stop loading `.mat` by hardcoded date.** Several figure scripts name a specific
  `*_FAMEs_<date>.mat`, which is how a figure quietly ends up on year-old data. There are 25 of
  them spanning 2022–2025.

### Don't "fix" these — they are deliberate

Beyond the scientific invariants above: don't unify the timeslice windows, don't switch
δD<sub>p</sub> to the ice-volume-corrected series, don't retune the endmembers, and don't repair
the dead paths in `deprecated/`. Don't port the MATLAB to Python as part of a restructure either
— that is a separate decision with its own verification burden, and mixing it in makes any
numerical difference impossible to attribute.

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
- `data/processed/*.csv` — timeslice-mean proxy δD records (Holocene, LGM, LIG) by core, with lon/lat
  and 1-sigma error, used in the notebooks to validate model output against real-world records.
  Only `timeslice_mean_proxy_dDraw.csv` is actually read by the notebooks — that is correct;
  the other file came from a cell its author disabled. `data/processed/README.md` documents the
  provenance of both, the ε offset between them, and the caveat about anomaly cancellation.
- `scripts/matlab/` — the proxy pipeline (laptop only). See "The proxy half" above.
- `fig1_swna_modern_climate.ipynb`, `fig2_dsdp480-479_agemodel.ipynb`,
  `fig3_dDwax_timeseries.ipynb` — the proxy-side figure notebooks (laptop only).
- `deprecated/` — superseded code kept for provenance, **reference only**. Its hardcoded
  absolute paths are dead and are left that way deliberately; see `deprecated/README.md`.
- `scripts/claude_casper.sh` — grabs an interactive Casper compute node. Do not run agentic
  tooling on a login node; the login-node policy reaps sustained CPU/memory/I/O and drops the
  SSH session.

## The proxy half — `scripts/matlab/` and `fig*.ipynb`

Runs on the laptop only. Reads from `$PROXY_DATA_DIR` and `$OBS_DATA_DIR` (OneDrive).

**Pipeline order** (each stage hands off by file, not by call — MATLAB writes `.mat`/`.xlsx`
into the OneDrive proxy tree and the notebooks read those):

1. `dDwax_data_processing_{nh22p,d480_d479}.m` — process raw δD<sub>C30</sub> measurements.
2. `dDp_epsilon_calculation.m` — a δD<sub>p</sub>-only Monte Carlo (2500 iterations) over C3/C4
   endmembers → fraction C4 → apparent fractionation ε → δD<sub>p</sub>. One `%%` section per
   core. **Its output is a dead end — nothing downstream reads it.** See the note below.
3. `pJAS_calculation.m` — Bayesian univariate regression (Gibbs, 10 chains × 1000 draws,
   first 200 discarded, thinned by 2, R̂ diagnostic) mapping δD<sub>p</sub> → %JAS rainfall.
   **Not self-contained** — expects `X` (%JAS) and `Y` (δD) already in the workspace.
4. `SST_dD_correlation.m` — δD<sub>p</sub> against SST and LR04 δ¹⁸O.
5. `fig1`/`fig2`/`fig3` notebooks — figures.

`avg_monthly_precip_Tucson.m` and `jas_instrumental_precip_timeseries.m` are standalone
instrumental-record helpers feeding the modern-climatology figure.

### Scientific invariants — deliberate, do not "correct" them

**The ε method is settled: a constant ε = −97 ± 2.98‰**, applied as one shared draw per Monte
Carlo iteration across all samples. That is what `dDwax_data_processing_{nh22p,d480_d479}.m` do
and what every published number reflects. Both cores use `dDraw` as the input series.

`src/deprecated/`-bound `dDp_epsilon_calculation.m` implements an alternative — a per-sample
variable ε derived from a C3/C4 mixture driven by prescribed δ¹³C, with Desert Museum
endmembers and `iters = 2500`. It was never adopted: its output was never propagated into the
spreadsheets and is read by nothing. The bullets below document its parameters for provenance
only; **they do not describe the live pipeline.**

- **δD<sub>p</sub> is computed from raw δD<sub>C30</sub>, not the ice-volume-corrected series.**
  The `dDivc` line is commented out and `dDraw` is used. This is intentional: it makes the proxy
  directly comparable to iCESM δD<sub>p</sub>, which already contains the ice-sheet isotope
  effect. `dDivc` is still computed and stored, and is what the `dDivc_timeseries` figure plots.
  Know which one a figure uses before changing anything.
- **δ¹³C is prescribed by climate state, not measured per sample** — glacial/interglacial means
  from Bhattacharya et al. (2018): −27.16‰ glacial, −26.67‰ interglacial, switched at
  18.5 / 115 / 130 ka.
- **Endmembers come from the Desert Museum compilation**, not literature defaults: δ¹³C
  `c4end = −24.2 ± 3.2`, `c3end = −32.7 ± 4`; ε `c4dd = −107.8 ± 3.7`, `c3dd = −82 ± 1`. The
  `c3dd` value deliberately departs from Sachse et al. (2012)'s −113; the code comment records
  both. Don't retune these.
- **Beta prior on fraction-C4 is uniform** (`m = 0.5`, `n = 2`) with pseudo-sample size
  `N = 5000`; `iters = 2500`; analytical uncertainty added as 2‰ (1σ) Gaussian noise.
- **Autocorrelated series are correlated with the Ebisuzaki phase-randomization test**, never
  `corrcoef` — see the header of `SST_dD_correlation.m`.
- **Ensembles are carried, not collapsed.** δD<sub>p</sub> and %JAS are `(age × ensemble)`
  arrays; bands are percentiles of the *sorted* ensemble (2.5/97.5 for 2σ, 16/84 for 1σ) and
  the central line is the **median**, not the mean. Bacon age models are the same shape.
- **Timeslice windows differ between figures on purpose** — see `data/processed/README.md`. The
  CSV exports use Holocene 0–4, LGM 18–24, LIG 117–130, PGM 135–150 ka; `fig3`'s interglacial
  bands are HOL 0–11.7, LIG 117–130; the MATLAB box plots use Holocene <11.7, LGM 11.7–27.
  Do not unify them.
- **OIPC is treated as already flux-weighted**, so seasonal isotope means are plain unweighted
  month means. IMERG is converted mm/hr → mm/day with `* 24`.
- Box plots constrain whiskers to the 5th/95th percentiles, not Tukey 1.5·IQR.

## Data pipeline (order of operations)

1. Raw CESM output lives on `/glade/campaign/.../iCESM1.2/...` (per-experiment, per-variable
   timeseries or climatology files) — not in this repo.
2. `scripts/ncl/make_*.ncl` scripts concatenate/select variables into per-experiment intermediate
   netCDF files (written to `$SCRATCH_DIR/PI` or `$SCRATCH_DIR/LIG`).
3. `scripts/ncl/pressureRegrid*.ncl` regrid 3D fields onto standard pressure levels where needed.
4. `scripts/nco/*.sh` scripts extract/derive isotope-related variables from climo files.
5. Notebooks load the resulting netCDF files with xarray, compute derived quantities (isotope
   ratios in per-mil notation, precipitation-weighted isotope values, LIG−PI / LGM−PI
   differences), and produce figures — compared where relevant against `data/processed/*.csv` and
   external obs/reanalysis (e.g. IMERG precip, ETOPO topography) under `$WORK_DATA_DIR`.

Each stage's output path is still consumed by the next stage's input path by construction (e.g.
an NCL script's `opath` == the shell script's `DATADIR` == the notebook's `dpath0`) — changing
where one stage writes still requires updating the next stage's read location to match. See
"Path configuration" for how those base directories are set today.

## Path configuration

Base data directories live in `config/paths.env` (gitignored; copy from
`config/paths.env.example`). Two blocks, one per machine — set the block for the machine you
are on and leave the other unset:

- **HPC:** `SCRATCH_DIR`, `WORK_DATA_DIR`, `PI_CLIMO_DIR`, `LIG_CASE_DIR`,
  `LIG_TIMESERIES_JS_DIR`, and `LGM_CASE_DIR` (**not yet set** — the LGM case
  `b.e12.B1850C5.f19_g16.i21ka.03` has not been located on glade; the only known copy is on an
  unmounted lab volume. Search glade before transferring anything.)
- **Laptop:** `PROXY_DATA_DIR`, `OBS_DATA_DIR`, `FIG_OUTPUT_DIR`.

Env vars rather than a YAML/Python config because NCL `getenv()`, the NCO shell scripts, and
Python all read them; a Python-only config would strand two-thirds of the pipeline.

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

All six notebooks run under a Jupyter kernel named **`nam_dD_lig`** (see notebook metadata
`kernelspec.name`), defined by `environment.yml` (`conda env create -f environment.yml`). It is
**project-specific on purpose** — it replaced the shared `gcm_analysis` env, which other projects
also use and so could not be pinned or extended safely. One environment serves both halves: it
carries the model-side stack plus `openpyxl` and `xlrd` for the proxy spreadsheets. Register the
kernel once per machine:

```bash
conda activate nam_dD_lig
python -m ipykernel install --user --name nam_dD_lig --display-name "nam_dD_lig"
```

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
