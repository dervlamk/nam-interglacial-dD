# deprecated/

Superseded code, kept for provenance. **Reference only — nothing here is a live code path.**

Every file here still contains hardcoded absolute paths pointing at directories that no longer
exist (`/Users/dervlakumar/Google_Drive/...`, `/Users/dervlamk/OneDrive/research/...`,
`/Volumes/lab/...`). **That is left alone on purpose.** These are a frozen record of how a
result was produced, not something to repair; "fixing" the paths would destroy the record
without making anything runnable.

## What's here

| File | What it was | Superseded by |
|---|---|---|
| `calc_dDp.m` | T. Bhattacharya's original (2022) δD<sub>p</sub> Monte Carlo | `scripts/matlab/dDp_epsilon_calculation.m` |
| `GoC_regression_original/` | Original Bayesian univariate regression for the Gulf of California calibration | `scripts/matlab/pJAS_calculation.m` |
| `dDp_iCESM_original.m` | First MATLAB implementation of iCESM δD<sub>p</sub> from PRECRC/PRECRL/PRECSC/PRECSL H2O and HDO tracers, run against local netCDF copies | the Python isotope-ratio cells in `LGM_analyses.ipynb` / `LIG127k_analyses_PALEOCALADJUSTED.ipynb` |
| `LIG127k_pre-glade.ipynb` | Earlier LIG analysis notebook (`climate` kernel, local data, no calendar adjustment) | `LIG127k_analyses_PALEOCALADJUSTED.ipynb` |
| `fig_LIG-PI_dD_box_plot.ipynb` | LIG-vs-Holocene δD box plot; also built intermediate `dD.*.nc` files nothing else reads | the time-series treatment in `fig3_dDwax_timeseries.ipynb` |
| `matlab_figures/FIG_*.m` | The 2022–2025 MATLAB figure scripts — the whole figure set before the Python rewrite | `fig1`–`fig3` notebooks and the LIG/LGM notebooks |

## Why `dDp_iCESM_original.m` is worth keeping

It is the clearest written statement of the isotope-ratio and precipitation-weighting
convention the Python notebooks now implement. If a weighting question ever comes up, this is
the reference implementation to diff against.

`matlab_figures/FIG_dDp_LGM_PI_anomalies.m` and `FIG_Anoms_iCESM_dD_precip_omega_winds.m`
likewise carry the per-season precipitation-weighted δD<sub>p</sub> derivation in full
(`dDp_WtMonthly = dDp * precip`, accumulated per season, divided by accumulated precip).

## Not copied here

`GoCregressionFINAL.mat` — the regression calibration — is data, not code, and `*.mat` is
gitignored. It lives at
`$PROXY_DATA_DIR/coretops/GoCregressionFINAL.mat` (OneDrive).
