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

Paths are either repo-relative (`data/raw/`, `data/external/`) or relative to the env vars in
`config/paths.env`. Each row says which. As of 2026-08-09 only IMERG still sits outside the
repo tree, so `$OBS_DATA_DIR` resolves exactly one dataset.

---

## Provenance of the proxy inputs

### 1. The `*_processed_dD*.xlsx` round trip — closed 2026-08-09

**`fig3` no longer reads these spreadsheets.** It reads the MATLAB pipeline's `.mat` output
directly. The files are still on disk and are still worth understanding, because everything
published before this date came through them — but they are now orphaned, and nothing in the
repo reads them. **See §1c for what replaced them and what changed.**

`handpicked` vs `autopicked` refers to how the chromatographic peaks were integrated — manual
versus software peak-picking of the GC-IRMS traces. `fig3` used **handpicked**; that is a
scientific choice, not a stale filename, and it is preserved — the `.mat` it now reads is built
from the handpicked raw file.

**What these files actually were.** Despite the name, they are not the MATLAB pipeline's input.
MATLAB reads the raw instrument files — `NH22P/dD_nh22p.xls` (sheet `dD_nh22p`) and
`DSDP-480-479/d480-479_dD.xlsx` — whose columns are age, δD<sub>raw</sub>, stdev. The
`*_processed_dD*.xlsx` files sit entirely *downstream*: all three of their sheets are copies of
numbers MATLAB had already computed.

| Sheet | Content | Origin |
|---|---|---|
| `Sheet1` | `age`, `dDraw`, `stdev`, `dDivc` | hand-copied — `age`/`dDraw`/`stdev` from the raw instrument file, `dDivc` computed by `icevolcorr` against LR04 |
| `dDp` | (samples × ensemble) δD<sub>p</sub> | output of `scripts/matlab/dDwax_data_processing_*.m`, pasted in |
| `pJAS` | (samples × ensemble) %JAS | output of the same script's Bayesian regression, pasted in |

So the round trip was: raw → MATLAB → *by hand* into a second spreadsheet → `fig3`. That hand
step is where silent drift lived, and the ensemble widths show it had already happened:

| File | `Sheet1` rows | `dDp` members | `pJAS` members |
|---|---|---|---|
| NH22P handpicked | 118 | 1000 | 4000 |
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
- **NH22P handpicked was 1020 wide until 2026-08-06 — a paste error, now fixed.** The canonical
  1000-member ensemble sat in columns 21–1020; twenty foreign columns (real δD<sub>p</sub>
  values, but from no run that matches any stored `.mat`) preceded it. Dropping the first twenty
  leaves the sheet exactly equal to `nh22p_FAMEs_18-Apr-2025.mat`'s `dDp`. `Sheet1` and `pJAS`
  were not touched. The pre-edit file is kept as
  `nh22p_processed_dD_handpicked_PRE-COLTRIM-20260806.xlsx`.

### 1b. `fig3` percentile indexing — resolved 2026-08-07

`fig3_dDwax_timeseries.ipynb` used to hardcode `iters = 1000`, derive its shading indices from it,
and apply the same indices to both cores. That was correct only for as long as both `dDp` sheets
stayed exactly 1000 members wide.

It was wrong while the NH22P sheet was 1020: index 975 is the 97.5th percentile of 1000 but only
the 95.6th of 1020, so that band was drawn too narrow at the top. Fixing the sheet fixed the
figure at the time; no code change was required then.

**Both `fig3` and `fig2` now use `np.nanpercentile(..., [2.5, 16, 84, 97.5])`** over the ensemble
axis, which is correct at any ensemble width. The hardcoded `iters` is gone from both, so this
particular failure cannot recur. `fig2`'s bands were verified bit-identical to the old
sorted-index version; the largest disagreement anywhere was 78 yr on a 137,000-yr axis, which is
the expected index-vs-interpolation difference (index 3900 of 4000 is the 97.525th percentile,
not the 97.5th).

### 1c. What replaced it — `fig3` reads the `.mat` directly

The fix turned out to need no new export step at all: **the `.mat` files already carry every
field `fig3` reads** — `age`, `dDraw`, `stdev`, `dDivc`, `dDp`, `jas`, for both cores. So rather
than have MATLAB `writematrix` the ensembles to a third location, `fig3` now reads the pipeline
output where it already lands. The data flow is one-directional:

```
raw instrument .xls/.xlsx  ->  MATLAB  ->  data/processed/*_FAMEs_current.mat  ->  fig3
```

Two changes made that possible (both 2026-08-09):

- `dDwax_data_processing_{nh22p,d480_d479}.m` now save **twice**: the dated archive copy as
  before, plus a stable undated `*_FAMEs_current.mat`. `fig3` names the undated one, so no
  figure can quietly end up on a year-old `.mat` because a date was left behind in the code.
- `fig3` cell 1's six `pd.read_excel` calls became two `sio.loadmat` calls via a `load_fames()`
  helper, which rebuilds the same `xr.Dataset` objects the rest of the notebook already
  expected. Nothing downstream of cell 1 changed. `fig3` now imports no pandas and reads
  nothing from `$PROXY_DATA_DIR`.

**The drift this caught.** Re-running the MATLAB and comparing the DSDP sheet against it:

| | NH22P | DSDP-480/479 |
|---|---|---|
| sheet date | 2026-08-06 | **2025-04-14** |
| `age` | identical | **33 of 147 differ, ≤67 yr, all in the d479 half (107.8–152.4 ka)** |
| `dDraw`, `stdev` | identical | identical |
| `dDp` | identical (0.0000‰) | rigid offset, mean −0.12‰ |
| `pJAS` | identical | **systematic +3.6 percentage points on all 147 rows** |

`pJAS` is the decisive one: NH22P matched to 6e-14 while DSDP was off by a uniform +3.6, so the
regression code and the `GoCregressionFINAL.mat` calibration had not changed — the DSDP sheet
simply predated a re-run. **Nothing consumed it** (`pJAS` is loaded in `fig3` and never read
again; the only other consumer is `deprecated/`), so no published number is affected.

**Effect on the figures.** Verified by re-running `fig3` before and after:

- `data/processed/timeslice_mean_proxy_dDraw.csv` — **byte-identical**. This is the file the
  model-side notebooks read, and it is built from `dDraw` (unchanged) and timeslice membership
  (verified: zero samples change window, no sample sits within 67 yr of a boundary).

  > *Later the same day*, this file changed for an unrelated reason: `fig3` gained two timeslice
  > windows and its error columns were renamed `_1serr` → `_stddev`. The header is no longer the
  > one described above, but **every value carried over is still bit-identical** — the old
  > `holocene_dD` column is now `late_holocene_dD` (both 0–4 ka). See `data/processed/README.md`
  > §Columns. The byte-identity claim above remains true of the `.mat` repointing in isolation.
- δD<sub>C30</sub> figure — changes only in the DSDP panel, only between 107 and 152 ka, and only
  along *x*: the d479 age fix moving 33 points by ≤67 yr. The δD values are element-wise
  identical, and the NH22P panel is pixel-identical.
- δD<sub>p</sub> figure — the DSDP median moves by a **rigid common offset**, mean −0.12‰
  (per-sample std 0.093‰, uncorrelated with age or δD<sub>raw</sub>). That is the expected
  signature of the shared-ε design, not a bias: ε is one shared draw per Monte Carlo iteration,
  so a single draw moves the whole curve by ~2.5‰ and the median inherits an SE of ~0.12‰. The
  worst-case sample moves 0.33‰ against a 12.6‰ 2σ band — 2.6% of the band. NH22P's median moves
  by exactly 0.0000‰, confirming MATLAB's fixed seed still reproduces bit-identically.

> Note for future comparisons: "signs scattered both ways" is **not** a valid noise test for
> these ensembles. A shared-ε draw shifts every sample the same direction by construction. The
> test that distinguishes noise from bias is whether the shift is a rigid offset small compared
> with the per-draw ε spread.

**The spreadsheets are left in place, unmodified.** Their `dDp`/`pJAS` sheets are now a record of
what was previously plotted. Stripping them is irreversible surgery on a hand-edited file and is
a separate decision; there is no longer any reason to *update* them.

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

**`fig2` was refactored onto this tree on 2026-08-07, and the refactor was numerically inert.**
It had always read the canonical `DSDP480_mcmc_new.csv`; what it could not do was find it, since
its paths pointed at a deleted OneDrive tree. It now resolves `PROXY_DATA_DIR`. Confirmed at the
same time:

- The MCMC ensembles **did not need regenerating.** `DSDP480_mcmc_new.csv` column medians match
  `DSDP480_165_ages.txt`'s `median` to 0.49 yr and its 2.5/97.5 column percentiles match that
  file's `min`/`max` to 0.50 yr — integer rounding. Same for DSDP-479 (0.50 yr). The ensemble
  `fig2` plots and the ages file the MATLAB uses are the same Bacon run.
- Every tie-point age previously hardcoded in `fig2` re-derives **exactly** from these files
  (`108572.80059` @ 4307 cm, `118676.66515` @ 4596, `106559.5` @ 3476, `124952.8383` @ 4351,
  and `[39.3945251, 71.98959448, 123.61099118]` ka). They are now computed, not pasted.

**The ¹⁴C tie points — fixed 2026-08-07.** `DSDP480.csv` mixes two timescales, which is the whole
of the problem. The `cc` column says which: `cc=0` rows carry calendar ages Bacon uses as given;
the six `cc=2, dR=300` Keigwin & Jones planktic dates carry *uncalibrated radiocarbon* ages that
Bacon converts internally against the marine curve. The age-depth model comes back in calendar
years, so `fig2` was drawing radiocarbon years on a calendar-year axis — a unit error.

All six fell outside the Bacon 95% band, always too young, offset growing monotonically:

| depth (cm) | 1051 | 1081 | 1311 | 1351 | 1536 | 1806 |
|---|---|---|---|---|---|---|
| offset (yr) | +790 | +942 | +1517 | +1706 | +2199 | +3008 |

Monotonic growth is the shape of the radiocarbon–calendar conversion through the deglaciation plus
a constant reservoir offset. The decisive evidence that the age model is fine is internal: the
`cc=0` ties over the same depth interval need no conversion and land within ~85 yr. A bad age
model would miss both kinds; only the ones needing a unit conversion were off.

They are now plotted at Bacon's calibrated calendar age for their depth, with the model's 95%
interval as the error bar. **Caveat, recorded because it limits what the panel proves:** those six
markers are now model-dependent — they lie on the median line by construction and are no longer an
independent check of the fit. They show which depths carry radiocarbon control. The `cc=0` markers
are still drawn at their own input ages and remain independent checks. Restoring an independent
check for the ¹⁴C dates means vendoring Marine20 and recalibrating at ΔR = 300 ± 20; there is no
calibration curve in this repo today, which is why the fix stops where it does.

The same commit also repaired a second inconsistency: the old code drew the `cc=2` error bars at
`age - dR` while drawing the markers at `age`, so bar and marker sat at different x positions.

Separately and pre-existing: `d479_tie-2` (125 ka @ 4596 cm) and `d18O-1` (130 ka @ 4839 cm) fall
*outside* the Bacon 95% band by ~6.3 and ~5.1 ka — the accumulation-rate prior pulling the base of
the core younger than those ±2000 yr tie points ask for. Not introduced by any recent change.

---

## Where the data lives

Two answers, reconciled by `config/paths.env` — see `data/README.md`.

- **Reproducing these results:** download the datasets below into the repo's own
  `data/` tree (`raw/`, `external/`, `interim/`, `processed/`). The tree is tracked; the data
  is not. Set `PROXY_DATA_DIR=./data/raw`; `OBS_DATA_DIR` only needs to point at wherever you
  keep IMERG.
- **The author's machine:** proxy data is in `data/raw/` and external data in `data/external/`,
  both inside the repo. Only IMERG is still on OneDrive, under `~/OneDrive/data/obs`.

No script hardcodes a location, **with one exception**: `fig1` reaches IMERG by absolute path
rather than through `$OBS_DATA_DIR`. That is a portability bug, left in place while the IMERG
version is still being chosen.

## Proxy data — `$PROXY_DATA_DIR` → `data/raw/` (author: `~/OneDrive/data/proxies`)

| Dataset | Path | Read by | |
|---|---|---|---|
| NH22P raw δD<sub>C30</sub> | `eastern_pacific_cores/NH22P/data/dD_nh22p.xls` (sheet `dD_nh22p`) | `dDp_epsilon_calculation.m`, `dDwax_data_processing_nh22p.m` | ✅ |
| DSDP-480/479 raw δD<sub>C30</sub> | `eastern_pacific_cores/DSDP-480-479/data/d480-479_dD.xlsx` (sheets `d480_dD_good`, `d479_dD_good`) | `dDp_epsilon_calculation.m`, `dDwax_data_processing_d480_d479.m` | ⚠️ a second copy exists at `proxies/DSDP-480-479/leaf_waxes/d480-479_dD.xlsx`; unverified whether identical |
| LR04 benthic stack (MATLAB) | `global_paleo_timeseries/lr04.mat` | all MATLAB (`icevolcorr`) | ✅ |
| LR04 benthic stack (Python) | ~~`global_paleo_timeseries/LR04stack_d18O.csv`~~ | nothing | ❌ **the CSV is gone from this machine** — the OneDrive `research/global_paleo_data/` directory it lived in no longer exists, and no copy survives anywhere under `data/`. No longer referenced by any code; both `fig2` and `fig3` were repointed on 2026-08-07. |
| LR04 benthic stack (Python) | `data/external/lr04.mat`, variable `delob` = `[age (ka), d18O, error]`, 2115 rows | `fig2`, `fig3`, all MATLAB (`icevolcorr`) | ✅ **as of 2026-08-07 both figure notebooks read the `.mat` directly** rather than the missing CSV. One canonical copy, shared with the MATLAB pipeline. Note `delob[:,0]` is already in **ka** — `fig2`/`fig3` plot it on a ka axis without dividing, unlike the Bacon-derived series which are in years. |
| GoC δD→%JAS calibration | `coretops/GoCregressionFINAL.mat` (`b_draws_final`, `tau2_draws_final`) | `dDwax_data_processing_*.m` | ⚠️ location known; **provenance undocumented** — which core-top compilation, which publication, how many sites |
| Bacon DSDP-479 | `Bacon_runs/DSDP479/` (`DSDP479_mcmc.csv`, `DSDP479.csv`, `DSDP479_113_ages.txt`) | `fig2`, `dDwax_data_processing_d480_d479.m` | ✅ |
| Bacon DSDP-480 | `Bacon_runs/DSDP480/` (`DSDP480_mcmc_new.csv`, `DSDP480.csv`, `DSDP480_165_ages.txt`) | `fig2`, `dDwax_data_processing_d480_d479.m` | ✅ settled — see section 2. `fig2` reads the MCMC ensemble, the MATLAB reads the ages file; verified 2026-08-07 to be the same run (medians agree to 0.5 yr) |
| Sample depths | `DSDP-480-479/age_model/sample_depths_{480,479}.xlsx` | `fig2` | ✅ 152 rows for 480 (2390 cm appears **twice** — two samples at one depth), 34 for 479; both match their MCMC column counts |
| Age-model tie points | `DSDP-480-479/age_model/{ShackletonHall82,KeigwinJones90}_d18O.xlsx`, `Byrne90_pollen.xlsx` | `fig2` | ✅ published sources, cited in filenames |
| ~~`fig3` processed records — NH22P~~ | `eastern_pacific_cores/NH22P/data/nh22p_processed_dD_handpicked.xlsx` | **nothing** | ✅ orphaned 2026-08-09 — `fig3` now reads `data/processed/nh22p_FAMEs_current.mat`. Left on disk unmodified as the record of what was plotted before. See section 1/1c. |
| ~~`fig3` processed records — DSDP~~ | `eastern_pacific_cores/DSDP-480-479/data/d480_d479_processed_dD.xlsx` | **nothing** | ✅ same — orphaned 2026-08-09. Its `pJAS` sheet was the one that had drifted +3.6 points; nothing ever consumed it. |
| NH22P autopicked variant | `.../nh22p_processed_dD_autopicked.xlsx` | nothing | ✅ software peak-picking; the handpicked record is the one carried forward |
| **`fig3` proxy records** | `data/processed/{nh22p,Guaymas_d480_d479}_FAMEs_current.mat` | `fig3` | ✅ **current, as of 2026-08-09.** Written by `dDwax_data_processing_*.m` under a stable undated name alongside the dated archive copy. Carries `age`, `dDraw`, `stdev`, `dDivc`, `dDp` (×1000), `jas` (×4000). The Guaymas struct is already the 147-sample d480+d479 composite. |

### Derived intermediates — the `*_FAMEs_*.mat` sprawl

**25 dated `.mat` files** exist across the proxy tree, spanning 2022-05 to 2025-05. They are
outputs, not inputs, but they are the only record of what each pipeline run produced, and
several figures load them *by explicit date*, which is how a figure silently ends up on stale
data.

**The ones that matter — now the undated pair in `data/processed/`:**

- `data/processed/nh22p_FAMEs_current.mat` — `dDp` 118 × 1000, `jas` 118 × 4000
- `data/processed/Guaymas_d480_d479_FAMEs_current.mat` — `dDp` 147 × 1000, `jas` 147 × 4000

These are what `fig3` reads (since 2026-08-09), and `dDwax_data_processing_*.m` rewrites them on
every run, so "current" is true by construction rather than by remembering to update a date.
The dated copies are still written beside them as the archive.

Their predecessors — `nh22p_FAMEs_18-Apr-2025.mat` and
`Guaymas_d480_d479_FAMEs_14-Apr-2025.mat` — are the provenance of every number published before
that date, because they are what the `*_processed_dD*.xlsx` sheets were pasted from. Keep them.

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

## Observational data

**Moved into the repo on 2026-08-09.** OIPC and ETOPO5 now live in `data/external/` and are read
from there, so they resolve identically whether or not `config/paths.env` has been sourced.
`$OBS_DATA_DIR` is now down to a single dataset. `data/external/` holds every external input the
proxy-side notebooks need **except IMERG**:

| Dataset | Path | Read by | |
|---|---|---|---|
| OIPC monthly isoscape | `data/external/OIPC_monthly_data.nc` (397 MB) | `fig1` | ✅ treated as already flux-weighted — see `CLAUDE.md`. **Its grid registration is wrong in the source file** and `fig1` corrects it; see the note below. Read by `fig1` only as of 2026-08-09: the OIPC isoscape maps moved there from `fig3`, and they were `fig3`'s only use of it. |
| ETOPO5 topography | `data/external/obs.etopo5.zsurf.nc` (36 MB) | `fig1` | ✅ |
| LR04 benthic stack | `data/external/lr04.mat` | `fig2`, `fig3`, MATLAB | ✅ see the row in the proxy table above |
| GoC δD→%JAS calibration | `data/external/GoCregressionFINAL.mat` | `dDwax_data_processing_*.m` | ⚠️ provenance still undocumented |

> **Duplicates.** OIPC and ETOPO5 also still exist at their old `$OBS_DATA_DIR` locations
> (`OIPC_monthly_data.nc`, `topography/obs.etopo5.zsurf.nc`) — 433 MB duplicated. Nothing reads
> those copies any more. Note the repo copies are **gitignored, so git does not back them up**;
> the OneDrive originals currently are the backup. Decide whether to keep them on that basis
> rather than deleting them as mere clutter.

> **OIPC grid registration.** The file's coordinates place the field ~0.5° east and ~0.25° south
> of where it belongs — plotted raw, the land mask sits southeast of the coastline. `fig1` applies
> `lon − 0.50, lat + 0.25` before subsetting. Measured against the Natural Earth 50 m polygons
> cartopy draws: coastal-cell agreement 0.82 → 0.96, with the same shift recovered independently
> from the Gulf of Mexico, the US Pacific NW, northern South America and the western
> Mediterranean, so it is a global property of the file. The offsets are exactly 6 and 3 cells of
> the 1/12° grid. **This is an empirical registration, not a documented correction** — the root
> cause in the source file is unknown. If a corrected OIPC file appears, drop the shift.

### `$OBS_DATA_DIR` (`~/OneDrive/data/obs`) — IMERG only

| Dataset | Path | Read by | |
|---|---|---|---|
| IMERG precipitation | `satellite/imerg/imerg.gn.timeseries.2001-2018.nc` | `fig1` | ⚠️ deliberately still outside the repo while the version to use is decided. **`fig1` reaches it by absolute path, not via `$OBS_DATA_DIR`**, so `obspath` is defined but unused in `fig1` — wiring it up would close the last hardcoded path in the proxy-side notebooks. A second candidate, `imerg_V07_19980101-20241231_monthly_gn.nc`, sits beside it in a disabled block in the same cell. `fig3` no longer defines `obspath` at all: it reads nothing from outside the repo. |
| IMERG precipitation (model side) | `$WORK_DATA_DIR/obs_data/obs.imerg.precip.2001-2018.nc` → derived `imerg.gn.2001-2018.climo.nc` | `LGM_analyses.ipynb` | ⚠️ **2001–2018 is the project-wide baseline** (decided 2026-08-05). The notebook has been updated from 2011–2018, but **the derived climo has not been rebuilt** — the regeneration block in that cell must be run once on Casper, and `obs.imerg.precip.2001-2018.nc` must exist there. Until then the cell will not load. |

---

## Model data — `/glade` (Casper only)

| Case | Run ID | Path | |
|---|---|---|---|
| PI control | `b.e12.B1850C5.f19_g16.iPI.01` | `$PI_CLIMO_DIR` = `/glade/campaign/univ/uazn0018/jiangzhu/archive/.../climo` | ✅ |
| LIG 127 ka | `b.e12.B1850C5.f19_g16.iLIG127k.001` | `$LIG_CASE_DIR` = `/glade/campaign/cesm/development/palwg/LastInterglacial/iCESM1.2/...` | ✅ |
| LGM 21 ka | `b.e12.B1850C5.f19_g16.i21ka.03` | `$LGM_CASE_DIR` = `/glade/campaign/cesm/community/palwg/iCESM1.2-DeglacialSlice/...` | ✅ located 2026-08-09. Per-variable monthly tseries (years 0001-0900), not a climo dir — subset via `scripts/nco/subset_deglacial_tseries.sh`. |
| PI per-year tseries | `b.e12.B1850C5.f19_g16.iPI.01` | `$PI_CASE_DIR` = same `iCESM1.2-DeglacialSlice` tree, sibling of `LGM_CASE_DIR` | ✅ located 2026-08-09. Distinct from `PI_CLIMO_DIR` above (that path is climo-only). |
| LIG ocean timeseries | — | `$LIG_TIMESERIES_JS_DIR` = `/glade/scratch/jschnaubelt/...` | ⚠️ a **collaborator's scratch space**. Scratch is purged on a timer; this will disappear without warning. Copy what is needed to `/glade/work` or campaign storage. |

All three cases are iCESM1.2 `f19_g16` (96×144 atmosphere, gx1v6 ocean). The LGM climatology
`LGM_analyses.ipynb` reads is years 0801–0900; the *existing* PI climatology it reads is years
0400–0499 (`$WORK_DATA_DIR/PI/b.e12.B1850C5.f19_g16.iPI.01.400-499.climo.nc`), not 0801–0900 —
correcting a previous version of this line that claimed all three cases shared the 0801–0900
window. As of the per-year subsetting work (see `scripts/nco/subset_deglacial_tseries.sh`), the
notebook rebuilds its own PI/LGM climatologies from years 0801–0900 for both cases, so this
window mismatch no longer propagates into the notebook's figures going forward.

---

## Data that is *not* external

`data/processed/*.csv` is tracked in this repo on purpose — it is how the Casper clone receives proxy
numbers without any raw proxy data crossing to `/glade`. See `data/processed/README.md` for its
provenance and the ε caveat.
