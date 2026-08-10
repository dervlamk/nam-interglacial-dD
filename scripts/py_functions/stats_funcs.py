"""
Statistical significance testing of differences between two model experiments.

Shared by the model-side notebooks (LGM_analyses.ipynb,
LIG127k_analyses_PALEOCALADJUSTED.ipynb) so the two experiments are tested the same way.
Both notebooks use sigtest2n() -- the cases being differenced are independent simulations,
not paired samples.
"""

import numpy as np
from scipy.stats import ttest_rel, ttest_ind


def sigtest(yearmean1, yearmean2, timemean1, timemean2, alpha=0.05):
    """Student's t-test (for data with identical sample sizes)."""
    ptvals = ttest_rel(yearmean1, yearmean2, axis=0)
    diff = timemean1 - timemean2
    return diff, mask_insignificant(diff, ptvals.pvalue, alpha), ptvals


def sigtest2n(yearmean1, yearmean2, timemean1, timemean2, alpha=0.05):
    """Welch's t-test (for data with different sample sizes)."""
    ptvals = ttest_ind(yearmean1, yearmean2, axis=0, equal_var=False)
    diff = timemean1 - timemean2
    return diff, mask_insignificant(diff, ptvals.pvalue, alpha), ptvals


def mask_insignificant(diff, pvals, alpha):
    """
    Blank out cells where the difference is not significant at `alpha`, KEEPING the xarray
    structure of `diff` (dims, coords, attrs).

    The previous form -- np.ma.masked_where(pvals > alpha, diff) -- returned a bare numpy
    MaskedArray, which drops every coordinate. That is why
    lgm_pi_diff_mask['OMEGA'][season].sel(lev_p=500.0) raised: after masking there was no
    lev_p coordinate left to select on, so the 3D fields could only be plotted unmasked.

    .where() keeps the DataArray and marks insignificant cells NaN. pcolormesh and quiver
    leave NaN cells blank exactly as they did masked ones, so the figures look the same --
    but .sel(lev_p=...) now works on the masked field too.
    """
    # same dims/coords as diff, carrying the p-values instead of the differences
    pvals = diff.copy(data=pvals)
    pvals.attrs = {'long_name': 'two-tailed p-value', 'units': '1'}
    return diff.where(pvals <= alpha)
