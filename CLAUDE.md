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
| Notebooks (all under `notebooks/`) | `LGM_analyses`, `LIG127k_analyses_PALEOCALADJUSTED` | `swna_modern_climatology` (fig1), `dsdp-480-479_age-model` (fig2), `dDwax_timeslice-means_timeseries` (fig3) |

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
> **Resolved 2026-08-09.** The ≤67 yr d479 age residual was between the *spreadsheets* and the
> `.mat`, not between the `.mat` and `DSDP479_113_ages.txt` — the 2026-08-06 rerun had already
> picked up the re-run ages, and the current `.mat` matches that file to 0.000000 ka. What
> lagged was `d480_d479_processed_dD.xlsx`, dated 2025-04-14, which `fig3` read until it was
> repointed at the `.mat`. Zero samples changed timeslice membership, so no published number
> moved. See `DATA_MANIFEST.md` §1c.

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

**Percentile hardening — done 2026-08-07.** `fig2` and `fig3` both used to hardcode an ensemble
width (`iters = 4000` / `1000`) and index into a sorted array. Both now use
`np.nanpercentile(..., [2.5, 16, 84, 97.5])` over the ensemble axis, which is correct at any
width. Don't reintroduce the index form.

**The spreadsheet round trip is closed — done 2026-08-09.** To regenerate the ensembles: re-run
the two `dDwax_data_processing_*.m` scripts, re-run `fig3` to regenerate `data/processed/*.csv`,
push, and only then does Casper pull. **There is no manual paste step any more.** The scripts
save twice — the dated archive copy plus a stable undated `data/processed/*_FAMEs_current.mat` —
and `fig3` reads the undated pair directly. Do not paste ensembles back into
`*_processed_dD*.xlsx`; nothing reads those sheets now. See `DATA_MANIFEST.md` §1c.

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
  `nh22p_FAMEs_18-Apr-2025.mat` exactly. This was the concrete argument for cutting the paste
  out entirely, which is what happened on 2026-08-09.
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
- ~~**The spreadsheet round trip.**~~ **Fixed 2026-08-09.** `fig3` reads
  `data/processed/*_FAMEs_current.mat`, not `*_processed_dD*.xlsx`. The `.mat` already carried
  every field `fig3` needed, so no new export was required — only a stable undated filename.
  The spreadsheets are untouched on disk and now read by nothing; the DSDP one had already
  drifted (its `pJAS` off by a uniform +3.6 points, its ages by a year's vintage). `DATA_MANIFEST.md`
  §1c has the before/after numbers.
- **`pressureRegrid_LIG.ncl` outputs PI-climatology data** despite its name, overlapping
  `pressureRegrid_PI_climo.ncl`. Confirm which produced the data in use before relying on either.
- **`scripts/py_functions/plot_tools.py` is imported by nothing** — superseded by
  `map_plot_tools.py`. Delete or move to `deprecated/`; an unused near-duplicate of the plotting
  layer invites divergence.
- **Stop loading `.mat` by hardcoded date.** Several figure scripts name a specific
  `*_FAMEs_<date>.mat`, which is how a figure quietly ends up on year-old data. There are 25 of
  them spanning 2022–2025. The pattern to follow is the one `fig3` now uses: the MATLAB writes a
  stable `*_FAMEs_current.mat` beside the dated archive copy, and the reader names the stable
  one. Still to do for the remaining MATLAB figure scripts, all of which are in `deprecated/`.

### Don't "fix" these — they are deliberate

Beyond the scientific invariants above: don't unify the timeslice windows, don't switch
δD<sub>p</sub> to the ice-volume-corrected series, don't retune the endmembers, and don't repair
the dead paths in `deprecated/`. Don't port the MATLAB to Python as part of a restructure either
— that is a separate decision with its own verification burden, and mixing it in makes any
numerical difference impossible to attribute.

## Repository layout

- `notebooks/LGM_analyses.ipynb`, `notebooks/LIG127k_analyses_PALEOCALADJUSTED.ipynb` — the two
  model-side analysis notebooks. They set file paths, load netCDF output with xarray, derive
  isotope ratios, and produce publication figures. These are large (multi-MB) notebooks with
  embedded plot outputs. They are **launched from `notebooks/`**, and resolve
  `scripts/py_functions` and `data/` relative to `..`.
  - **The two are deliberately parallel and share their machinery.** Loading, derivation,
    seasonal averaging and significance testing all live in `scripts/py_functions/icesm_funcs.py`
    and `stats_funcs.py`, imported by both — that is not incidental, it is what stops the
    isotope/precip-weighting math and the t-test from drifting into two versions. If you change
    how one notebook processes data, you are changing both; re-run both and check their figures.
    Both use JAS, both difference against `iPI.01` years 801–900, both mask at p ≤ 0.05 (Welch's,
    unpaired), and both compare against `data/processed/timeslice_mean_proxy_dDp.csv`.
  - **The LIG output is calendar-adjusted, and its months come from record position.**
    Paleoclimate orbital-forcing runs shift month boundaries relative to modern calendars;
    PaleoCalAdjust corrects for it. The adjusted files then carry *paleo* month boundaries on
    their time axis, so April is stamped `0401-05-01 05:36` and `.dt.month` returns no April and
    two Mays. An older version of the notebook nudged the timestamps back two days to work around
    that; it now assigns months positionally instead (twelve records per year, Jan–Dec), which is
    what `cal_adjust.f90` actually guarantees. **Don't reintroduce the nudge.** The notebook's
    header cell documents the whole adjustment, and there is an assertion in the processing cell
    that fails if a re-adjusted file ever breaks the assumption.
  - **The LIG notebook has no dynamics panel, on purpose.** Only 19 variables were
    calendar-adjusted (16 isotope tracers + `PRECC`, `PRECL`, `TS`) — there is no adjusted
    `U`/`V`/`OMEGA`/`Q`/`Z3`/`PSL`, so where `LGM_analyses` shows Δω₅₀₀ and 850 mb winds, the LIG
    figure shows ΔTS. Producing the missing fields means re-running `cal_adjust.f90` (the rows are
    already in `cal_adj_info_lig127ka.csv`) plus an adjusted `PS` and a `vinth2p` regrid; don't
    paper over the gap by plotting unadjusted winds beside adjusted precipitation.
  - `deprecated/LIG127k_analyses_NOT_paleocaladjust.ipynb` is the unadjusted version, reference
    only. Prefer the adjusted notebook for anything LIG-related.
- `scripts/py_functions/` — shared Python helpers imported by the notebooks via `sys.path` (see
  "Import pattern" below):
  - `icesm_funcs.py` — `DAT_META` (canonical units/long_name for every derived field),
    `derive_dat` (unit conversions, `PRECT`, precipitation-weighted `dDp`/`d18Op`),
    `monthly_climatology`, `seasonal_means`, `windSpd`, and the two time-axis handlers
    `assign_cesm_month_year` (raw CESM h0: end-of-period stamps, shift back two days) and
    `assign_paleocal_month_year` (PaleoCalAdjust: positional). Everything downstream reads the
    `month`/`year` coords these attach, never `.dt.month`/`.dt.year` — see the module docstring
    for why.
  - `stats_funcs.py` — `sigtest` (paired), `sigtest2n` (Welch's, what both notebooks use), and
    `mask_insignificant`, which uses `.where()` so the masked field keeps its coords. Don't
    revert it to `np.ma.masked_where`; that returns a bare MaskedArray and breaks `.sel()`.
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
  - `pressureRegrid_tseries.ncl` — same `vinth2p` regrid, but for the LGM/PI per-year subset (see
    `subset_tseries.sh` below), and the one script in this directory that reads/writes this
    repo's own `data/raw/` and `data/interim/` (via `$REPO_ROOT`) instead of
    `$SCRATCH_DIR`/`$WORK_DATA_DIR` like its siblings above — a deliberate, not yet reconciled,
    convention split. Both cases' files sit flat in each directory (no per-case subdirectory),
    named `{var}.{tag}.0801-0900.tseries.nc` (raw, hybrid-sigma levels, `subset_tseries.sh`'s
    output) and `{var}.{tag}.0801-0900.tseries.plev.nc` (interim, this script's output), where
    `tag` is `iPI.01` or `i21ka.03`.
- `scripts/nco/` — NCO (`ncks`/`ncap2`) wrappers for isotope post-processing (extracting isotope
  tracer variables, integrating isotope ratios over levels). Require `module load nco`; source
  `config/paths.env` themselves (fail with an explicit error if it doesn't exist yet).
  - `make_imerg_climo.sh` builds the two derived IMERG products the model notebooks read — the
    global 12-month climatology and the SW-NA window of the monthly timeseries (which keeps its
    time axis, so the annual-cycle figure can get an interannual standard deviation from it).
    **This must not move back into a notebook.** The source is 216 records on a 0.1° global grid,
    5.6 GB in memory as float32; deriving the climatology in-kernel materialises that several
    times over and kills the Jupyter kernel. `ncra` streams the record dimension instead — one
    pass per calendar month, ~95 s, a few hundred MB. The script also does the 0:360 wrap with
    `ncks --msa`, which moves data and labels together; the in-notebook version that relabelled
    `lon` and rolled by `nlon` left every label 180° out for months without erroring. Both
    notebooks validate the axis on load and raise rather than trust it.
  - `subset_tseries.sh` is the exception to that isotope-post-processing description: it
    hyperslabs 25 raw variables (years 801-900) out of `$LGM_CASE_DIR`/`$PI_CASE_DIR` and writes
    into `data/raw/`, this repo's own tree, not `$WORK_DATA_DIR`. It also extracts one record of
    PI `PHIS`/`LANDFRAC` as `{VAR}.iPI.01.constant.nc` — time-invariant fields, so the filename
    deliberately does not claim a 1200-record window. `PHIS` is the model topography the LIG
    notebook contours; `LGM_analyses` contours the 21 ka topo file instead, because the LGM's
    ice-sheet topography is not the modern one and the LIG's essentially is.
- `data/processed/*.csv` — timeslice-mean proxy δD records (Holocene, LGM, LIG) by core, with lon/lat
  and 1-sigma error, used in the notebooks to validate model output against real-world records.
  **Both model notebooks read `timeslice_mean_proxy_dDp.csv`** (δD<sub>p</sub>, after the C3/C4 ε
  correction), because the model quantity they are compared against is itself δD<sub>p</sub>
  (precipitation) — comparing δD<sub>wax</sub> to δD<sub>p</sub> would mix in the leaf-wax/
  precipitation offset. (The LIG notebook read `timeslice_mean_proxy_dDraw.csv` until 2026-08-10;
  it no longer does.) `timeslice_mean_proxy_dDraw.csv` is still what the proxy-side figure
  notebook writes and plots, as-measured δD<sub>C30</sub>; `timeslice_mean_proxy_dD.csv`, the
  older 3-timeslice file, is read by nothing. `data/processed/README.md` documents the ε offset
  between `dDraw` and `dD`/`dDp` and the caveat about anomaly cancellation, though it predates
  `dDp.csv` and should be read with that in mind.
- `scripts/matlab/` — the proxy pipeline (laptop only). See "The proxy half" above.
- `notebooks/swna_modern_climatology.ipynb`, `notebooks/dsdp-480-479_age-model.ipynb`,
  `notebooks/dDwax_timeslice-means_timeseries.ipynb` — the proxy-side figure notebooks (laptop
  only). These are the notebooks referred to elsewhere in this file as `fig1`/`fig2`/`fig3`.
- `deprecated/` — superseded code kept for provenance, **reference only**. Its hardcoded
  absolute paths are dead and are left that way deliberately; see `deprecated/README.md`.
- `scripts/claude_casper.sh` — grabs an interactive Casper compute node. Do not run agentic
  tooling on a login node; the login-node policy reaps sustained CPU/memory/I/O and drops the
  SSH session.

## The proxy half — `scripts/matlab/` and `fig*.ipynb`

Runs on the laptop only. Reads from `$PROXY_DATA_DIR` and `$OBS_DATA_DIR` (OneDrive).

**Pipeline order** (each stage hands off by file, not by call — MATLAB writes `.mat` into
`data/processed/` and the notebooks read those):

1. `dDwax_data_processing_{nh22p,d480_d479}.m` — process raw δD<sub>C30</sub> measurements.
   Reads the raw instrument files (`NH22P/dD_nh22p.xls`, `DSDP-480-479/d480-479_dD.xlsx`) under
   `$PROXY_DATA_DIR`; writes `data/processed/*_FAMEs_{<date>,current}.mat`. **`fig3` reads the
   `current` pair** — everything it plots comes from here, with no spreadsheet in between.
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
- **Timeslice windows differ between figures on purpose** — see `data/processed/README.md`. As
  of 2026-08-09 the CSV export carries all five `fig3` windows: late-holocene 0–4,
  holocene 0–11.7, lgm 18–24, lig 117–130, pgm 135–150 ka. `fig3`'s interglacial bands are
  HOL 0–11.7, LIG 117–130; the MATLAB box plots use Holocene <11.7, LGM 11.7–27. Do not unify
  them, and in particular **do not collapse the two Holocene windows** — the model notebooks
  difference against `late_holocene_dD` (0–4 ka), which is the window every published anomaly
  reflects. Switching them to `holocene_dD` (0–11.7 ka) flips the sign of the DSDP-480/479 LIG
  anomaly.
- **CSV error columns are `_stddev`, not `_1serr`** (renamed 2026-08-09, no values changed).
  They are `.std(dim=['age'])` over the samples inside each window — the spread of the data,
  not the standard error of the mean. Don't rename them back or divide by √n.
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
  `LIG_TIMESERIES_JS_DIR`, `LGM_CASE_DIR`, `PI_CASE_DIR`, and `REPO_ROOT`. `LIG_CASE_DIR` moved
  2026-08-10: it was under `/glade/campaign/cesm/**development**/palwg/...`, which no longer
  exists, and is now on `community` storage alongside the deglacial-slice cases. There is
  deliberately no variable for the calendar-adjusted LIG output — it lives in `data/raw/`, see
  the layout section above. `LGM_CASE_DIR`/
  `PI_CASE_DIR` were located on campaign storage 2026-08-09 at
  `/glade/campaign/cesm/community/palwg/iCESM1.2-DeglacialSlice/b.e12.B1850C5.f19_g16.{i21ka.03,iPI.01}`
  — per-variable monthly tseries (years 0001-0900, one file per variable), distinct from the
  climatology-only `PI_CLIMO_DIR` above. See `scripts/nco/subset_tseries.sh`, which writes the
  subset into this repo's own `data/raw/` (not `$WORK_DATA_DIR`) using `$REPO_ROOT` —
  see `data/README.md`.
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
module_path = os.path.abspath(os.path.join('..'))
if module_path not in sys.path:
    sys.path.append(module_path + "/scripts/py_functions")
from map_plot_tools import *
from line_plot_tools import *
from colorbar_funcs import *
from data_funcs import *
```

`'..'`, not `'.'` — the notebooks live in `notebooks/` and must be launched from there, so
`module_path` resolves to the repo root. `module_path` is then reused for data paths
(`f'{module_path}/data/raw/...'`), and the small relative reads use `'../data/processed/...'`.
Don't hardcode an absolute `/glade/...` path to reach `data/` — there is more than one clone of
this repo on Casper, and an absolute path silently reads the wrong one.

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

`tools/strip_notebook_output.py` does two things, both so notebook diffs stay readable: it clears
cell outputs/execution counts, and it normalises every cell's `source` to nbformat's
list-of-lines form. It is wired up as a git clean filter via `.gitattributes`
(`*.ipynb filter=stripoutput`). Run `tools/setup_git_filters.sh` once per clone to register the
filter locally (git filter config isn't versioned).

- Clearing outputs keeps embedded figures out of git history — don't remove the filter setup
  without replacing it with something equivalent, or the notebooks will balloon back to
  multi-MB commits.
- Normalising `source` matters because nbformat permits `source` to be either a list of lines or
  one long string, and both load fine in Jupyter. A cell stored as a string is a single JSON
  line, so git renders any edit to it as a whole-cell rewrite rather than a line-by-line diff.
  Jupyter writes the list form; programmatic editors (including Claude Code's NotebookEdit)
  write the string form. All six notebooks were normalised on 2026-08-07. The filter is
  idempotent, so it will not fight the working tree.

`tools/sync_manuscript_figs.sh` copies the current manuscript figures from `$FIG_OUTPUT_DIR` into
its `for_manuscript/` subdirectory. `$FIG_OUTPUT_DIR` is a working scratch space holding figures
back to 2019 plus screenshots and stray `.m` files, so the script syncs an **explicit named set**
(the `FIGURES` array at the top) rather than globbing — adding a figure to the manuscript means
adding a line there. Deliberate: any automatic rule would either sweep in the scratch files or
silently skip a figure whose `savefig()` is commented out.

- Copies only when the source is newer, and preserves timestamps, so re-running is a no-op.
- Exits 1 if any listed figure is missing, so it can gate a release step. `--dry-run` to preview.
- Warns `STALE?` when a notebook is newer than the figure it produced — the figure is then built
  from code that no longer exists. This is the "figure quietly on old data" failure mode that
  `DATA_MANIFEST.md` flags elsewhere; here it is caught rather than documented.

## Working with the notebooks

- These notebooks are long and stateful — cells build up dictionaries keyed by simulation
  (`'pi'`, `'lig'`, `'lgm'`), variable name, and season, and later cells depend on earlier ones
  having been run in order. Both model notebooks use the same names in the same order:
  `files` → `raw` → `dat_ts` (per-year) and `dat_climo` (12-month climatology) →
  `seas_mean`/`ann_seas_mean` → `{lgm,lig}_pi_diff`, `_diff_mask`, `_ptvals` → `panels` →
  figures. The `_mask` variant is what the figures plot; the unmasked one is what the box means
  and pattern correlations use.
- Isotope ratios are computed as per-mil (‰) deviations: `(heavy/light - 1) * 1000`, with a tiny
  floor value substituted for near-zero denominators to avoid divide-by-zero.
- Precipitation-weighted isotope averages are standard here: isotope ratios are weighted by each
  month's fraction of annual total precipitation before combining across months.
- When editing a notebook, use a notebook-aware tool (e.g. Claude Code's NotebookEdit) rather than
  treating the file as plain text/JSON — the plain Edit tool refuses `.ipynb` files outright.
