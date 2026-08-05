# proxy_data

Timeslice-mean proxy hydrogen isotope (δD) records used in the notebooks to compare against
simulated precipitation δD. Both files cover the same two cores and the same three timeslices
(Holocene, LGM, LIG); only the δD values differ between them.

## Files

- `timeslice_mean_proxy_dDraw.csv` — the file actually read by the notebooks
  (`LGM_analyses.ipynb`, `LIG127k_analyses_PALEOCALADJUSTED.ipynb`) via
  `pd.read_csv('proxy_data/timeslice_mean_proxy_dDraw.csv')`.
- `timeslice_mean_proxy_dD.csv` — not currently loaded by any notebook.

The two files' δD values differ by a near-constant offset of about **+91 to +92‰**
(`dD ≈ dDraw + ~91‰` for every cell). That consistent offset is in the range typical of the
apparent fractionation between a leaf-wax biomarker's measured δD and its source/precipitation
water δD — which would make `dDraw` the as-measured proxy values and `dD` a source-water-corrected
version — **but this is an inference from the data pattern, not something documented anywhere in
the repo.** If you know which correction (if any) was applied, it's worth adding here.

## Columns

| Column | Description |
|---|---|
| `core_name` | Identifier for the sediment/ice core or site |
| `lon`, `lat` | Site coordinates (decimal degrees; `lon` in -180:180 convention) |
| `holocene_dD`, `holocene_dD_1serr` | Holocene timeslice mean δD (‰) and 1σ standard error |
| `lgm_dD`, `lgm_dD_1serr` | LGM (~21 ka) timeslice mean δD (‰) and 1σ standard error |
| `lig_dD`, `lig_dD_1serr` | LIG (~127 ka) timeslice mean δD (‰) and 1σ standard error |

## Provenance

Not documented in the repo or notebooks — no citation, DOI, or source publication is recorded for
this compilation. Fill this in with where these timeslice means come from (e.g. the underlying
proxy database/publication and how the timeslice means and errors were computed) so results built
on this data can be traced back to their source.
