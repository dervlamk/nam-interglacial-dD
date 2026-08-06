# DATA_MANIFEST

Every external dataset this repo consumes, where it actually lives today, which code reads it,
and **how confident we are that it is the canonical copy.**

Written 2026-08-05 after gathering the analysis code from four scattered locations; verified
against a full pipeline rerun 2026-08-06. Where an entry is still uncertain that is stated
explicitly. Resolve uncertainties by editing this file, not by guessing in code.

Confidence legend:

| | Meaning |
|---|---|
| ✅ | Single unambiguous source, verified to exist, one consumer path. |
| ⚠️ | Exists and is read, but there are competing copies or the provenance is undocumented. |
| ❌ | **Unresolved.** Either the file has no traceable producer, or two consumers disagree about which copy is canonical. Do not build new work on these until settled. |

Paths are relative to the env vars in `config/paths.env` (`$PROXY_DATA_DIR`, `$OBS_DATA_DIR`).

---

## Provenance of the proxy inputs

### 1. `fig3`'s inputs are hand-entered GC-IRMS data

`nh22p_processed_dD_handpicked.xlsx` and `d480_d479_processed_dD.xlsx` were **hand-generated
from GC-IRMS output**. They are primary data entry, upstream of the MATLAB pipeline rather than
downstream of it. No script produces them and none should be written.

`handpicked` vs `autopicked` refers to how the chromatographic peaks were integrated — manual
versus software peak-picking of the GC-IRMS traces. `fig3` uses **handpicked**; that is a
scientific choice, not a stale filename.

**The caveat:** only `Sheet1` is instrument-derived. Each file carries three sheets, and the
other two are *computed ensembles pasted in by hand*:

| Sheet | Content | Origin |
|---|---|---|
| `Sheet1` | `age`, `dDraw`, `stdev`, `dDivc` | hand-compiled from GC-IRMS — **except `dDivc`**, which is computed by `icevolcorr` against LR04 |
| `dDp` | (samples × ensemble) δD<sub>p</sub> | output of `scripts/matlab/dDwax_data_processing_*.m`, pasted in |
| `pJAS` | (samples × ensemble) %JAS | output of the same script's Bayesian regression, pasted in |

So the round trip is: spreadsheet → MATLAB → back into the same spreadsheet, by hand. That is
where silent drift lives, and the ensemble widths show it has already happened:

| File | `Sheet1` rows | `dDp` members | `pJAS` members |
|---|---|---|---|
| NH22P handpicked | 118 | **1020** | 4000 |
| NH22P autopicked | 97 | 1000 | 4000 |
| DSDP-480/479 | 147 | 1000 | 4000 |

- **`pJAS` = 4000 everywhere is exactly right** and confirms provenance: `pJAS_calculation.m`
  runs 10 chains × 1000 draws, discards the first 200, and thins by 2 → 10 × 800 / 2 = 4000.
- **`dDp` = 1000 is correct for the script that actually produced it.** The sheets came from
  `dDwax_data_processing_*.m`, which runs 1000 iterations — verified against the stored `.mat`
  dimensions (`nh22p_FAMEs_18-Apr-2025.mat` is 118 × 1000 + jas 118 × 4000;
  `Guaymas_..._14-Apr-2025.mat` is 147 × 1000 + jas 147 × 4000; both match the sheets exactly).
  `dDp_epsilon_calculation.m`'s 2500-member `dDp_raw` output was never pasted in and is read by
  nothing. If you want 2500 downstream, change it in `dDwax_data_processing_*.m`.
- **NH22P handpicked has 1020 members: a paste artifact, confirmed.** Every stored `.mat` is
  exactly 1000 wide — there is no run anywhere that produced 1020. Twenty columns were
  duplicated during the manual copy into Excel. This has a downstream consequence; see
  "Percentile indexing" below.

**Worth fixing:** keep the hand entry for `Sheet1` — that is legitimate — but stop pasting
computed ensembles back into it. Have the MATLAB `writematrix` the `dDp`/`pJAS` ensembles to
their own files and have `fig3` read `Sheet1` from the spreadsheet and the ensembles from those.
The manual paste is what produced the 1020-column error.

### 1b. Percentile indexing is wrong for NH22P in `fig3`

`fig3_dDwax_timeseries.ipynb` hardcodes `iters = 1000` and derives the shading indices from it
(`round(iters*0.025)`, `round(iters*0.975)`, …), then applies **the same indices to both cores**.
DSDP-480/479 has 1000 members, so its bands are correct. NH22P has 1020, so its bands are not:

| Intended | Index used | Actual percentile of 1020 |
|---|---|---|
| 97.5th | 975 | **95.6th** |
| 84th | 840 | 82.4th |
| 16th | 160 | 15.7th |
| 2.5th | 25 | 2.45th |

The upper 2σ bound is the worst case — it should be index 994. **The NH22P uncertainty envelope
is drawn too narrow at the top**, asymmetrically, on the paper's main record figure. The effect
is modest (a few tenths of a ‰) but systematic and affects only one of the two panels.

**Fix:** derive the indices from the array's own width, or drop the index arithmetic and use
`np.nanpercentile(dDp, [2.5, 16, 84, 97.5], axis=1)` — which is correct for any ensemble size
and removes the failure mode entirely.

### 2. DSDP-480 age model — settled

The canonical age model is **`Bacon_runs/DSDP480`**: `DSDP480_165_ages.txt` for the MATLAB
pipeline, `DSDP480_mcmc_new.csv` for `fig2_dsdp480-479_agemodel.ipynb`. The two are consistent
— the CSV's column medians match the ages file to 0.3 yr (rounding).

Every stored product from April 2025 onward was built from it, confirmed by interpolating each
candidate onto the 114 DSDP-480 sample depths and comparing against the ages actually stored:

| Production era | Age model | Divergence from canonical |
|---|---|---|
| 2022 (`d480_FAMEs_18-May-2022`) | `DSDP480_84` | 3.765 ka |
| 2023–24 (`22-Sep-2023`, `21-May-2024`) | `Bacon_runs_new/DSDP480` | 2.763 ka |
| **2025 onward** (`14-Apr-2025`, 2026-08 rerun) | **`Bacon_runs/DSDP480`** | **0.00000 ka** |

Superseded runs have been moved to `Bacon_runs/DSDP480_superseded/`, which carries a README with
this lineage. `Bacon_runs/DSDP480/` now holds one age model and one only.

`Bacon_runs/DSDP480_oldLGM/` was deliberately left in place: it is a complete run with different
**LGM tie points**, diverging by 1.000 ka — an alternative hypothesis, not a stale version.

**Why this needed pinning down:** three of the seven candidates diverge from canonical by less
than 3 ka. That is small enough to look like noise on a plot and large enough to move samples
between timeslices. Filename, section count, directory and modification date are all
insufficient to tell them apart — several share them. Only the interpolated ages distinguish
them.

**DSDP-479 has no such problem** — one run (`_113`), one MCMC file, unambiguous.
---

## Where the data lives

Two answers, reconciled by `config/paths.env` — see `data/README.md`.

- **Reproducing these results:** download the datasets below into the repo's own
  `data/` tree (`raw/`, `external/`, `interim/`, `processed/`). The tree is tracked; the data
  is not. Set `PROXY_DATA_DIR=./data/raw` and `OBS_DATA_DIR=./data/external`.
- **The author's machine:** the copies live on OneDrive under `~/OneDrive/data/{proxies,obs}`
  and are staying there. The paths below are those locations.

Either way, no script hardcodes a location.

## Proxy data — `$PROXY_DATA_DIR` → `data/raw/` (author: `~/OneDrive/data/proxies`)

| Dataset | Path | Read by | |
|---|---|---|---|
| NH22P raw δD<sub>C30</sub> | `eastern_pacific_cores/NH22P/data/dD_nh22p.xls` (sheet `dD_nh22p`) | `dDp_epsilon_calculation.m`, `dDwax_data_processing_nh22p.m` | ✅ |
| DSDP-480/479 raw δD<sub>C30</sub> | `eastern_pacific_cores/DSDP-480-479/data/d480-479_dD.xlsx` (sheets `d480_dD_good`, `d479_dD_good`) | `dDp_epsilon_calculation.m`, `dDwax_data_processing_d480_d479.m` | ⚠️ a second copy exists at `proxies/DSDP-480-479/leaf_waxes/d480-479_dD.xlsx`; unverified whether identical |
| LR04 benthic stack (MATLAB) | `global_paleo_timeseries/lr04.mat` | all MATLAB (`icevolcorr`) | ✅ |
| LR04 benthic stack (Python) | `global_paleo_timeseries/LR04stack_d18O.csv` | `fig2`, `fig3` | ⚠️ also present as `.xls`, `.xlsx`, `LR04_d18O.txt`, and a copy under `DSDP-480-479/data/`; assumed identical, never checked |
| GoC δD→%JAS calibration | `coretops/GoCregressionFINAL.mat` (`b_draws_final`, `tau2_draws_final`) | `dDwax_data_processing_*.m` | ⚠️ location known; **provenance undocumented** — which core-top compilation, which publication, how many sites |
| Bacon DSDP-479 | `Bacon_runs/DSDP479/` (`DSDP479_mcmc.csv`, `DSDP479.csv`, `DSDP479_113_ages.txt`) | `fig2`, `dDwax_data_processing_d480_d479.m` | ✅ |
| Bacon DSDP-480 | see blocking problem 2 | | ❌ |
| Sample depths | `DSDP-480-479/age_model/sample_depths_{480,479}.xlsx` | `fig2` | ✅ |
| Age-model tie points | `DSDP-480-479/age_model/{ShackletonHall82,KeigwinJones90}_d18O.xlsx`, `Byrne90_pollen.xlsx` | `fig2` | ✅ published sources, cited in filenames |
| `fig3` processed records — NH22P | `eastern_pacific_cores/NH22P/data/nh22p_processed_dD_handpicked.xlsx` | `fig3` | ⚠️ `Sheet1` is hand-entered GC-IRMS data (primary, correct); the `dDp`/`pJAS` sheets are pasted-in computed ensembles that no longer match the scripts. See problem 1. |
| `fig3` processed records — DSDP | `eastern_pacific_cores/DSDP-480-479/data/d480_d479_processed_dD.xlsx` | `fig3` | ⚠️ same structure |
| NH22P autopicked variant | `.../nh22p_processed_dD_autopicked.xlsx` | nothing | ✅ software peak-picking; `fig3` deliberately uses the handpicked file instead |

### Derived intermediates — the `*_FAMEs_*.mat` sprawl

**25 dated `.mat` files** exist across the proxy tree, spanning 2022-05 to 2025-05. They are
outputs, not inputs, but they are the only record of what each pipeline run produced, and
several figures load them *by explicit date*, which is how a figure silently ends up on stale
data.

**The ones that matter** — these are what the `*_processed_dD*.xlsx` sheets were pasted from,
so they are the provenance of every downstream number:

- `NH22P/data/nh22p_FAMEs_18-Apr-2025.mat` — `dDp` 118 × 1000, `jas` 118 × 4000
- `DSDP-480-479/data/Guaymas_d480_d479_FAMEs_14-Apr-2025.mat` — `dDp` 147 × 1000, `jas` 147 × 4000

The newer `*_FAMEs_01-May-2025.mat` pair (from `dDp_epsilon_calculation.m`, `dDp_raw` at 2500
members, per-core and unspliced) is **not** used by anything. Don't mistake the later date for
currency.

Variants that are **not** simple date bumps and need a decision:

| File | What it is |
|---|---|
| `nh22p_FAMEs_var_drift_07-Jun-2024.mat` / `..._constant_drift_...` | two instrument-drift corrections; `deprecated/matlab_figures/` plots both |
| `Guaymas_FAMEs_06-May-2024_ivcSECOND.mat` | a second ice-volume-correction attempt |
| `NH22PFAMEs_ReprocessedResults_fromJess.xlsx` | J. Tierney's repicks; the note `# might need to recalculate based on Jess' repicks` in `deprecated/LIG127k_pre-glade.ipynb` refers to this |

**To resolve:** pick the canonical run per core, record it here, and move the rest to a dated
`superseded/` directory. Then stop loading `.mat` by hardcoded date.

---

## Observational data — `$OBS_DATA_DIR` (`~/OneDrive/data/obs`)

| Dataset | Path | Read by | |
|---|---|---|---|
| OIPC monthly isoscape | `OIPC_monthly_data.nc` | `fig1`, `fig3` | ✅ treated as already flux-weighted — see `CLAUDE.md` |
| ETOPO5 topography | `topography/obs.etopo5.zsurf.nc` | `fig1` | ✅ |
| IMERG precipitation | `satellite/imerg/imerg.gn.timeseries.2001-2018.nc` | `fig1` | ✅ |
| IMERG precipitation (model side) | `$WORK_DATA_DIR/obs_data/obs.imerg.precip.2001-2018.nc` → derived `imerg.gn.2001-2018.climo.nc` | `LGM_analyses.ipynb` | ⚠️ **2001–2018 is the project-wide baseline** (decided 2026-08-05). The notebook has been updated from 2011–2018, but **the derived climo has not been rebuilt** — the regeneration block in that cell must be run once on Casper, and `obs.imerg.precip.2001-2018.nc` must exist there. Until then the cell will not load. |

---

## Model data — `/glade` (Casper only)

| Case | Run ID | Path | |
|---|---|---|---|
| PI control | `b.e12.B1850C5.f19_g16.iPI.01` | `$PI_CLIMO_DIR` = `/glade/campaign/univ/uazn0018/jiangzhu/archive/.../climo` | ✅ |
| LIG 127 ka | `b.e12.B1850C5.f19_g16.iLIG127k.001` | `$LIG_CASE_DIR` = `/glade/campaign/cesm/development/palwg/LastInterglacial/iCESM1.2/...` | ✅ |
| LGM 21 ka | `b.e12.B1850C5.f19_g16.i21ka.03` | **not located on glade** | ❌ only known copy is `/Volumes/lab/iCESM/LGMclimatologies` on an unmounted lab volume. Search glade before transferring — the PI sibling is already there and these are NCAR-produced runs. |
| LIG ocean timeseries | — | `$LIG_TIMESERIES_JS_DIR` = `/glade/scratch/jschnaubelt/...` | ⚠️ a **collaborator's scratch space**. Scratch is purged on a timer; this will disappear without warning. Copy what is needed to `/glade/work` or campaign storage. |

All three cases are iCESM1.2 `f19_g16` (96×144 atmosphere, gx1v6 ocean), 100-year climatologies
over simulation years 0801–0900.

---

## Data that is *not* external

`data/processed/*.csv` is tracked in this repo on purpose — it is how the Casper clone receives proxy
numbers without any raw proxy data crossing to `/glade`. See `data/processed/README.md` for its
provenance and the ε caveat.
