# data/

**The directory tree is tracked; the data is not.** A fresh clone gets these four empty
directories so there is a defined place to download data to. Nothing in here except this
README and the small tracked tables in `processed/` is under version control.

`DATA_MANIFEST.md` at the repo root is the authoritative list of what each dataset is, where it
came from, and which files are still ambiguous. This file only says *where to put things*.

```
data/
├── raw/         Original, immutable. Never edited, never written to by any script.
├── external/    Third-party datasets not produced by this project.
├── interim/     Intermediate products of the pipeline.
└── processed/   Final, analysis-ready.
```

## What belongs where

### `raw/` — original and immutable
| | |
|---|---|
| `dD_nh22p.xls` | NH22P raw δD<sub>C30</sub> (sheet `dD_nh22p`) |
| `d480-479_dD.xlsx` | DSDP-480/479 raw δD<sub>C30</sub> (sheets `d480_dD_good`, `d479_dD_good`) |
| `nh22p_processed_dD_handpicked.xlsx` | NH22P record, hand-compiled from GC-IRMS output (manual peak-picking). **Primary data despite the "processed" name** — nothing generates it. |
| `d480_d479_processed_dD.xlsx` | as above, for DSDP-480/479 |
| `Bacon_runs/DSDP480/`, `Bacon_runs/DSDP479/` | Bacon age-depth model output. See the canonical-run note in `DATA_MANIFEST.md` before using DSDP-480. |
| `sample_depths_{480,479}.xlsx` | sample depth registers |
| `ShackletonHall82_d18O.xlsx`, `KeigwinJones90_d18O.xlsx`, `Byrne90_pollen.xlsx` | published age-model tie points |

### `external/` — third-party
| | |
|---|---|
| `LR04stack_d18O.csv`, `lr04.mat` | LR04 benthic δ¹⁸O stack (Lisiecki & Raymo 2005) |
| `OIPC_monthly_data.nc` | OIPC monthly isoscape (~396 MB) |
| `imerg.gn.timeseries.2001-2018.nc` | IMERG precipitation (~3.1 GB) |
| `obs.etopo5.zsurf.nc` | ETOPO5 topography |
| `GoCregressionFINAL.mat` | Gulf of California δD→%JAS calibration. Provenance still undocumented — see `DATA_MANIFEST.md`. |

### `interim/`
`*_FAMEs_*.mat` from the MATLAB pipeline, and the netCDFs the NCL/NCO stages build from raw
iCESM output.

### `processed/`
`timeslice_mean_proxy_dDraw.csv` and `timeslice_mean_proxy_dD.csv` — **tracked**, because they
are how the Casper clone receives proxy numbers without any raw proxy data crossing to `/glade`.
Read `proxy_data/README.md` for their provenance and the ε caveat: use `dDraw`; the other came
from a cell its author disabled.

## What is currently populated

`raw/` holds a **copy** of the raw, immutable inputs, made 2026-08-05 and verified
byte-identical (md5) against the originals. **Nothing was moved** — every original is still in
place on OneDrive.

```
raw/NH22P/                 dD_nh22p.xls, nh22p_processed_dD_{hand,auto}picked.xlsx
raw/DSDP-480-479/          d480-479_dD.xlsx, d480_d479_processed_dD.xlsx
raw/DSDP-480-479/age_model/ sample_depths_{480,479}.xlsx + the three published tie-point sources
raw/Bacon_runs/DSDP480/    canonical run only — mcmc_new.csv, 165_ages.txt, DSDP480.csv, depths, 165.pdf
raw/Bacon_runs/DSDP479/    mcmc.csv, 113_ages.txt, DSDP479.csv, depths
```

Two deliberate exclusions, both to avoid re-importing ambiguity that has already been resolved:

- **Only the canonical DSDP-480 Bacon run was copied.** The five superseded configurations
  (`_84`, `_162`, `_990`, `_1681`) and the `DSDP480_old*` sibling directories remain on OneDrive
  only. See `DATA_MANIFEST.md` §2 for which run is canonical and why.
- **`external/` and `interim/` are empty.** The observational datasets are large (IMERG is
  3.1 GB, OIPC 396 MB) and the interim products are pipeline outputs, not inputs. Download or
  regenerate them as needed.

## Two things this layout does not change

**iCESM model output stays on `/glade`.** It is far too large to download and is
collaborator-staged on NCAR campaign storage. `data/` is for the proxy and observational side
plus locally-derived intermediates. Model paths still come from the `/glade` block of
`config/paths.env`.

**The author's own copies live on OneDrive** (`~/OneDrive/data/{proxies,obs}`) and are not being
moved. `config/paths.env` is what reconciles the two: point `PROXY_DATA_DIR` / `OBS_DATA_DIR` at
`./data/raw` and `./data/external` for a fresh clone, or at OneDrive if that is where your copy
already is. That is exactly what the path config is for — nothing else needs to know.
