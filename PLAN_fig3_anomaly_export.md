# Plan — export timeslice anomalies and their two uncertainties from `fig3`

**Run this on the laptop.** It is the remaining half of the 2026-08-13 model-vs-proxy work; the
Casper half is committed (`d71ba58`). Delete this file once the export is done and pushed.

## Why

`LGM_analyses.ipynb` now draws a model-vs-proxy ΔδD<sub>p</sub> figure: the model's LGM−PI box
mean with its interannual spread, beside the proxy's LGM − late-Holocene anomaly with its own
uncertainty. The proxy half needs numbers that only exist on this machine, because they come
from the Monte Carlo ensembles in `data/processed/*_FAMEs_current.mat`, and those `.mat` files
never go to Casper. Only the CSV crosses.

Until this lands, the model notebook runs on a fallback path — it recomputes the anomaly and the
sample-spread σ from the timeslice means already in the CSV, and draws no Monte Carlo whisker.
It prints which path it took, so nothing is silently wrong in the meantime. **This is not
blocking anything; it is the better-uncertainty upgrade.**

## Scope

One cell: `notebooks/dDwax_timeslice-means_timeseries.ipynb`, **cell 3** (`# --- DEFINE AGE
BOUNDS (ka) & META INFO --- #`, cell id `12cfee62`). Its `# --- CREATE DATA FRAME AND EXPORT
--- #` block is what changes. Nothing else in the notebook, and no MATLAB re-run.

The cell already computes `differences[core][modern_ref][interval]` and then throws it away —
it is only printed. The job is to export it, plus a sample count and two separately-named σ.

## Columns to add

**Append after the existing 13. Do not redefine or reorder any existing column** — this file has
been bitten by a silent redefinition before (`data/processed/README.md`, the `holocene_*` window
swap, which flips the sign of the DSDP LIG anomaly).

Reference window is `late_holocene` (0–4 ka) only. `{interval}` runs over `lgm`, `lig`, `pgm`.

| Column | Definition |
|---|---|
| `{interval}_n`, `late_holocene_n` | `dDtimeslice[core][interval].sizes['age']` |
| `{interval}_minus_late_holocene_dD` | `interval_mean[core][interval] − interval_mean[core]['late_holocene']` |
| `{interval}_minus_late_holocene_dD_stddev_samples` | `np.hypot(interval_stddev[core][interval], interval_stddev[core]['late_holocene'])` |
| `{interval}_minus_late_holocene_dD_stddev_mc` | ensemble-propagated, below |

**Export full precision.** The existing `differences` dict is built with `np.round(..., 2)` for
the printed summary; do not route the export through it, or read from it and re-derive. The
existing `_dD` columns carry full float repr and these should match.

### The Monte Carlo σ

Difference member by member, so the shared ε draw cancels — that cancellation is the whole point
and is what makes this the right pairing:

```python
a = dDtimeslice[core][interval]            # (age, ensemble_n_dDp)
b = dDtimeslice[core]['late_holocene']
delta_ens = a.mean(dim='age') - b.mean(dim='age')   # aligns on ensemble_n_dDp -> (ensemble,)
mc_sd = float(delta_ens.std())             # ddof=0, matching the existing _stddev columns
```

Two things to know:

- **This is deliberately not centred on the exported anomaly.** The central value uses
  `median(ensemble).mean(age)` (what cell 3 already does for ensemble variables); this uses
  `mean(age)` per member. Only `.std()` is taken, so the difference doesn't matter — but don't
  "fix" it into agreement by changing how `interval_mean` is computed. That would move published
  numbers.
- With the live pipeline's constant `ep = -97 ± 2.98` applied as one shared draw per iteration, ε
  cancels almost exactly in the difference, so this ends up being essentially the propagated 2‰
  analytical noise. **That is why it earns its place:** `_stddev_samples` is a hard `0.0` for
  NH22P's late-Holocene window, which holds a single sample, and a zero whisker there reads as a
  confident measurement rather than an unconstrained one.

### Variables with no ensemble

Cell 3 is templated on `varn` and also runs for `dDraw`/`dDivc`, which have no ensemble
dimension — it already branches on `varn in ['dDraw','dDivc']` when computing
`interval_mean`/`interval_stddev`. Introduce a named flag from that same condition and guard the
MC block with it:

```python
HAS_ENSEMBLE = varn not in ('dDraw', 'dDivc')
```

(The earlier draft of this plan claimed the notebook already had a `HAS_ENSEMBLE` idiom. It does
not — you are adding it. Reuse the existing condition rather than inventing a second one.)

Write an **empty field** for `_stddev_mc` when there's no ensemble, so all the CSVs keep an
identical header.

### Row order

Keep `cores = ['d480_479', 'nh22p']` — DSDP first. The model notebooks now index by
`core_name` rather than by row position (that was hardened on the Casper side), so this is no
longer load-bearing, but there's no reason to churn it.

## Run it

Re-run cell 3 for **`varn = 'dDp'`** and then **`varn = 'dDraw'`**, so both tracked CSVs get the
new header. (`dDivc` and `pJAS` write untracked files; harmless either way.)

## Verification

1. **The existing numbers must not move.** Diff both CSVs against git: the **first 13 columns
   must be byte-identical**. This is the check that matters most.
   ```bash
   git diff --word-diff data/processed/timeslice_mean_proxy_dDp.csv
   ```
2. **The anomalies match what the cell already prints:**

   | | `lgm_minus_late_holocene_dD` |
   |---|---|
   | DSDP-480/479 | −7.725053 (prints as −7.73) |
   | NH22P | +5.265872 (prints as +5.27) |

   These are exactly `lgm_dD − late_holocene_dD` from the committed `dDp` CSV, so they are
   checkable without re-running anything.
3. `late_holocene_n` is **1** for NH22P, and `late_holocene_dD_stddev` stays `0.0` — the two are
   the same fact, and the figure annotates it.
4. `lgm_minus_late_holocene_dD_stddev_mc` is **small but strictly nonzero** for both cores. If it
   comes out as exactly zero, the member-by-member alignment silently collapsed — check that both
   arrays still carry the `ensemble_n_dDp` coord.
5. For `varn='dDraw'`, the `_stddev_mc` fields are empty and the header still matches the `dDp`
   file's.

## Handoff

```bash
git add data/processed/timeslice_mean_proxy_dDp.csv data/processed/timeslice_mean_proxy_dDraw.csv \
        notebooks/dDwax_timeslice-means_timeseries.ipynb
git commit -m "Export timeslice anomalies and their two uncertainties from fig3"
git push
```

Then on Casper: `git pull`, re-run `LGM_analyses.ipynb`. The proxy-anomaly cell will print
`Proxy anomaly source: exported columns` instead of `FALLBACK`, and the figure will grow the
thick Monte Carlo whisker. **The model markers must be identical between the two runs** — only
the proxy whiskers change. That is the check that the fallback and the exported path agree.

## Don't

- Don't re-run the MATLAB. The `.mat` files already carry everything needed.
- Don't paste anything back into `*_processed_dD*.xlsx`. That round trip was closed 2026-08-09
  and nothing reads those sheets now.
- Don't unify the timeslice windows, and in particular don't difference against `holocene`
  (0–11.7 ka) instead of `late_holocene` (0–4 ka).
- Don't switch the input series from `dDraw` to `dDivc`, or retune the endmembers.

Full context: `CLAUDE.md` (scientific invariants) and `data/processed/README.md` (the column
spec, already written up under "Anomaly columns").
