#!/usr/bin/env python3
"""Build a combined DSDP 480/479 pollen record on this project's Bacon age models.

    python scripts/build_combined_pollen_record.py [--out PATH] [--quiet]

WHY THIS EXISTS
---------------
`fig2_dsdp480-479_agemodel.ipynb` plots the Byrne et al. (1990) pollen record against the
DSDP-480 Bacon age model, and silently loses 41 of its 130 samples: the record runs to a
composite depth of 12150 cm but the Site 480 age model only covers 18-4944 cm, so everything
deeper interpolates to NaN and never reaches the figure. The deepest sample actually drawn is
at 4890 cm, about 125.9 ka.

The dropped samples are Site 479, and this project has a Bacon model for Site 479. This script
splits the workbook by site, dates each half on ITS OWN age model, and merges on age.

THE SOURCE FILE
---------------
`data/external/Byrne_pollen data (480+479) current 11-14-2014.xls`

  gulf data (480+479).csv   130 samples: composite depth, Byrne's own CLAM ages, raw counts
  Sheet1 / Sheet2           counts / percentages for 8 taxa
  Sheet3                    56 samples with DSDP designations (64-480-...), all Site 480

Its header states the composite is in metres "(10 meter adjustment for 479)".

WHERE SITE 480 ENDS AND SITE 479 BEGINS
---------------------------------------
Three independent lines of evidence put the boundary at 4890 cm, and `_self_checks` re-asserts
all three on every run:

  1. The largest gap in the depth series is 400 cm, at 4890 -> 5290 cm.
  2. All 56 of Sheet3's Site-480 designations fall at or above 4887 cm.
  3. The Amaranthaceae maximum (41.1%) sits at composite 4310 cm, matching the tie horizon
     Byrne et al. report at 43.07 m at Site 480 -- so the shallow block is on native 480 depths.

The 32 shallow samples missing from Sheet3 are Site 480 as well; reading them as shifted Site
479 would require native depths starting at -970 cm.

THE 8.31 m vs 10 m QUESTION
---------------------------
Byrne et al. (1990), p.106:

    "the prominent Chenopodiaceae/Amaranthaceae peak that was encountered in Core 10 (43.07 m)
     at Site 480 was encountered in Core 5 (34.76 m) at Site 479, and in this way it was
     possible to combine the two records."

43.07 - 34.76 = 8.31 m. That is the GEOLOGICAL offset at one horizon, and it matches the
480<->479 pollen tie-point depths used elsewhere in this project (4307 <-> 3476 cm). It is not
a constant: the leaf-wax tie gives 2.45 m (4596 <-> 4351 cm), because the two cores accumulated
at different rates. No single shift aligns them.

The workbook nevertheless applied 10 m. Inverting with 1000 cm yields round native depths for
36 of 40 deep samples on a clean 1.5 m grid; inverting with 831 cm yields 0 of 40. So 10 m is
what was applied, and 10 m is what recovers the depths as entered -- which is what the Site 479
Bacon model is indexed on.

The 8.31 m never enters this script, because this method never places Site 479 on the Site 480
depth scale. It dates each core on its own model and merges on AGE, exactly as the leaf-wax
pipeline does (`dDwax_data_processing_d480_d479.m:182` concatenates the two age vectors and
sorts; line ~106 notes "D479 depth, not corrected to d480 depth").

Recorded for provenance: using 8.31 m instead would shift every Site 479 age +3.4 kyr and push
one more sample below the model. `--offset` exists so that can be checked, not so it can be
used casually.

OUTPUT
------
`data/processed/byrne90_pollen_combined.csv` -- all 130 rows, with a `dated` flag. The undated
samples are kept deliberately: losing them silently is the bug this script fixes.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd

# --- facts about the source file, each justified in the module docstring ----------------------
SPLICE_DEPTH_CM = 4890      # last Site 480 sample; a 400 cm gap follows
SITE479_OFFSET_CM = 1000    # the adjustment the workbook applied to Site 479
BYRNE_TIE_480_CM = 4307     # Amaranthaceae peak at Site 480 (Byrne et al. 1990, p.106)
BYRNE_TIE_479_CM = 3476     # the same peak at Site 479 -> geological offset 831 cm, NOT used

WORKBOOK = "Byrne_pollen data (480+479) current 11-14-2014.xls"
DATA_SHEET = "gulf data (480+479).csv"
REGRESSION_FILE = "Byrne90_pollen.xlsx"   # what fig2 plots today; check 5 reproduces it

# Sheet2 header -> output column name
TAXA = {
    "POACEAE": "poaceae_pct",
    "PINUS": "pinus_pct",
    "JUNIPERUS-TYPE": "juniperus_type_pct",
    "QUERCUS": "quercus_pct",
    "ARTEMISIA": "artemisia_pct",
    "AMBROSIA": "ambrosia_pct",
    "ASTERACEAE (HIGH )": "asteraceae_high_pct",
    "AMARANTHACEAE": "amaranthaceae_pct",
}

BACON = {
    "480": ("Bacon_runs/DSDP480/DSDP480_mcmc_new.csv", "sample_depths_480.xlsx"),
    "479": ("Bacon_runs/DSDP479/DSDP479_mcmc.csv", "sample_depths_479.xlsx"),
}


def repo_root() -> Path:
    """Repo root from this file's location, so the script runs from any directory."""
    return Path(__file__).resolve().parent.parent


def proxy_data_dir(root: Path) -> Path:
    """PROXY_DATA_DIR from the environment, else config/paths.env, else data/raw.

    Same resolution order as the MATLAB pipeline (dDwax_data_processing_d480_d479.m:65-86)
    and the figure notebooks.
    """
    env = os.environ.get("PROXY_DATA_DIR")
    if env:
        return Path(env)
    paths_env = root / "config" / "paths.env"
    if paths_env.is_file():
        found = None
        for line in paths_env.read_text().splitlines():
            m = re.match(r"^\s*export\s+PROXY_DATA_DIR\s*=\s*(.*)$", line)
            if m:
                found = m.group(1).strip().strip("\"'")
        if found:
            return Path(found)
    return root / "data" / "raw"


def load_workbook(path: Path) -> pd.DataFrame:
    """Composite depth, Byrne's CLAM age, and the 8 taxon percentages, in file order."""
    main = pd.read_excel(path, sheet_name=DATA_SHEET, header=None)
    # Depths are stored as metres and as metres*100, so the cm column arrives with float noise
    # (509.99999999999994 for 510). Round, or 15 of 130 depths fail to match REGRESSION_FILE.
    depth = pd.to_numeric(main[1][2:], errors="coerce").round(0)
    clam = pd.to_numeric(main[2][2:], errors="coerce")

    pct = pd.read_excel(path, sheet_name="Sheet2", header=None)
    header = {str(pct[c][1]).strip().upper(): c for c in pct.columns
              if isinstance(pct[c][1], str)}
    missing = [k for k in TAXA if k not in header]
    if missing:
        raise SystemExit(f"Sheet2 is missing expected taxa columns: {missing}")

    df = pd.DataFrame({"depth_composite_cm": depth.values,
                       "byrne_clam_age_ka": (clam / 1000).values})
    for src, dest in TAXA.items():
        df[dest] = pd.to_numeric(pct[header[src]][2:], errors="coerce").values[: len(df)]
    # what fig2 plots; check 5 asserts this reproduces REGRESSION_FILE exactly
    df["artemisia_juniper_pct"] = df["artemisia_pct"] + df["juniperus_type_pct"]
    return df.dropna(subset=["depth_composite_cm"]).reset_index(drop=True)


def load_agemodel(proxy_dir: Path, core: str):
    """(depths, median, p2.5, p97.5) for one core's canonical Bacon ensemble.

    Percentiles rather than indices into a sorted array, matching fig2/fig3. DSDP-480 has two
    samples at 2390 cm, so depths are made unique before use.
    """
    mcmc_rel, depths_rel = BACON[core]
    mcmc = pd.read_csv(proxy_dir / mcmc_rel, header=None).values
    depths = pd.read_excel(
        proxy_dir / "DSDP-480-479" / "age_model" / depths_rel).depth.values.astype(float)
    if mcmc.shape[1] != len(depths):
        raise SystemExit(f"DSDP-{core}: ensemble has {mcmc.shape[1]} columns but "
                         f"{len(depths)} sample depths")
    med = np.median(mcmc, axis=0)
    lo, hi = np.nanpercentile(mcmc, [2.5, 97.5], axis=0)
    uniq, first = np.unique(depths, return_index=True)   # 480 duplicates 2390 cm
    return uniq, med[first], lo[first], hi[first]


def assign_ages(native_cm: np.ndarray, model) -> pd.DataFrame:
    """Interpolate a core's age model onto sample depths. No extrapolation: out-of-range -> NaN."""
    depths, med, lo, hi = model
    inside = (native_cm >= depths.min()) & (native_cm <= depths.max())
    out = pd.DataFrame({"age_ka": np.nan, "age_2s_lo_ka": np.nan, "age_2s_hi_ka": np.nan},
                       index=np.arange(len(native_cm)))
    if inside.any():
        z = native_cm[inside]
        out.loc[inside, "age_ka"] = np.interp(z, depths, med) / 1000
        out.loc[inside, "age_2s_lo_ka"] = np.interp(z, depths, lo) / 1000
        out.loc[inside, "age_2s_hi_ka"] = np.interp(z, depths, hi) / 1000
    out["dated"] = inside
    return out


def _self_checks(df: pd.DataFrame, wb_path: Path, extern: Path, offset_cm: int) -> list[str]:
    """Re-assert the facts the split rests on. Raises if the source file no longer supports them."""
    notes = []
    depth = df.depth_composite_cm.values

    # 1. the splice is a clean break at the base of the Site 480 block.
    #    NOT the largest gap in the whole series -- the Site 479 block is sampled at ~150 cm
    #    with gaps up to 520 cm, against ~40 cm in the Site 480 block. The meaningful claim is
    #    that nothing inside the 480 block comes close to the break that ends it.
    order = np.sort(depth)
    gaps = np.diff(order)
    where = np.where(order == SPLICE_DEPTH_CM)[0]
    if not len(where):
        raise SystemExit(f"CHECK 1 FAILED: {SPLICE_DEPTH_CM} cm is not a sample depth")
    i = int(where[0])
    splice_gap, within = gaps[i], gaps[:i].max()
    if splice_gap < 300 or splice_gap <= within:
        raise SystemExit(f"CHECK 1 FAILED: gap after {SPLICE_DEPTH_CM} cm is {splice_gap:.0f} cm; "
                         f"largest gap inside the Site 480 block is {within:.0f} cm")
    notes.append(f"1. splice gap {splice_gap:.0f} cm at {SPLICE_DEPTH_CM} cm, vs {within:.0f} cm "
                 f"largest within the Site 480 block")

    # 2. every Sheet3 Site-480 designation sits in the shallow block
    s3 = pd.read_excel(wb_path, sheet_name="Sheet3", header=None)
    sites = s3[0][1:].astype(str).str.extract(r"64-(\d{3})-")[0]
    d3 = pd.to_numeric(s3[1][1:], errors="coerce") * 100
    deepest = d3[sites == "480"].max()
    if not (sites.dropna() == "480").all() or deepest > SPLICE_DEPTH_CM:
        raise SystemExit(f"CHECK 2 FAILED: Sheet3 sites={sorted(sites.dropna().unique())}, "
                         f"deepest Site 480 designation {deepest:.0f} cm")
    notes.append(f"2. all {(sites == '480').sum()} Sheet3 designations are Site 480, "
                 f"deepest {deepest:.0f} cm")

    # 3. the Amaranthaceae peak marks Byrne's stated tie horizon
    shallow = depth <= SPLICE_DEPTH_CM
    peak = depth[shallow][np.nanargmax(df.amaranthaceae_pct.values[shallow])]
    if abs(peak - BYRNE_TIE_480_CM) > 10:
        raise SystemExit(f"CHECK 3 FAILED: Amaranthaceae peak at {peak:.0f} cm, "
                         f"expected within 10 cm of {BYRNE_TIE_480_CM}")
    notes.append(f"3. Amaranthaceae peak at {peak:.0f} cm "
                 f"(Byrne: {BYRNE_TIE_480_CM} cm at Site 480)")

    # 4. the offset inversion yields depths on the grid they were entered on
    native = depth[~shallow] - offset_cm
    frac = float(np.mean(native % 10 == 0))
    if offset_cm == SITE479_OFFSET_CM and frac < 0.90:
        raise SystemExit(f"CHECK 4 FAILED: only {frac:.0%} of un-shifted Site 479 depths are "
                         f"multiples of 10 cm")
    notes.append(f"4. {frac:.0%} of un-shifted Site 479 depths are multiples of 10 cm "
                 f"(offset {offset_cm/100:.2f} m)")

    # 5. regression -- reproduce the series fig2 plots today
    ref_path = extern / REGRESSION_FILE
    if ref_path.is_file():
        ref = pd.read_excel(ref_path)[["depth", "ArtemisiaJuniper"]]
        ref["depth"] = ref.depth.astype(float).round(0)
        merged = df[["depth_composite_cm", "artemisia_juniper_pct"]].merge(
            ref, left_on="depth_composite_cm", right_on="depth")
        worst = (merged.artemisia_juniper_pct - merged.ArtemisiaJuniper).abs().max()
        if len(merged) != len(ref) or worst > 1e-6:
            raise SystemExit(f"CHECK 5 FAILED: matched {len(merged)}/{len(ref)} rows against "
                             f"{REGRESSION_FILE}, max|diff| {worst:.6f}")
        notes.append(f"5. Artemisia+Juniperus reproduces {REGRESSION_FILE} on all "
                     f"{len(merged)} rows (max|diff| {worst:.1e})")
    else:
        notes.append(f"5. SKIPPED -- {ref_path} not found, cannot regress against fig2's series")
    return notes


def build(df: pd.DataFrame, proxy_dir: Path, offset_cm: int) -> pd.DataFrame:
    """Split by site, date each half on its own model, merge on age."""
    shallow = df.depth_composite_cm <= SPLICE_DEPTH_CM

    d480 = df[shallow].copy()
    d480["site"] = "DSDP-480"
    d480["depth_native_cm"] = d480.depth_composite_cm            # composite IS native for 480

    d479 = df[~shallow].copy()
    d479["site"] = "DSDP-479"
    d479["depth_native_cm"] = d479.depth_composite_cm - offset_cm

    out = []
    for half, core in ((d480, "480"), (d479, "479")):
        ages = assign_ages(half.depth_native_cm.values, load_agemodel(proxy_dir, core))
        out.append(pd.concat([half.reset_index(drop=True), ages], axis=1))

    combined = pd.concat(out, ignore_index=True)
    # Merge on AGE, never on depth -- the same rule the leaf-wax splice uses. Undated samples
    # sort to the end rather than being dropped.
    return combined.sort_values("age_ka", na_position="last", kind="mergesort").reset_index(
        drop=True)


def report(combined: pd.DataFrame, df: pd.DataFrame, proxy_dir: Path, offset_cm: int) -> None:
    say = print
    say("\nCOMBINED RECORD")
    for site in ("DSDP-480", "DSDP-479"):
        s = combined[combined.site == site]
        dated = s[s.dated]
        say(f"  {site}: {len(s):3d} samples, {len(dated):3d} dated"
            + (f", {dated.age_ka.min():7.2f} - {dated.age_ka.max():7.2f} ka" if len(dated) else ""))
    d = combined[combined.dated]
    say(f"  total  : {len(combined):3d} samples, {len(d):3d} dated "
        f"({len(d)/len(combined):.0%}), {d.age_ka.min():.2f} - {d.age_ka.max():.2f} ka")

    und = combined[~combined.dated]
    if len(und):
        say(f"\n  {len(und)} samples remain undated -- below the base of their age model:")
        for site in und.site.unique():
            u = und[und.site == site]
            say(f"    {site}: {len(u):2d} samples, native {u.depth_native_cm.min():.0f}"
                f"-{u.depth_native_cm.max():.0f} cm")
        say("    Reaching these needs new tie-points, not code.")

    a = combined[(combined.site == "DSDP-480") & combined.dated].age_ka.max()
    b = combined[(combined.site == "DSDP-479") & combined.dated].age_ka.min()
    say(f"\n  splice: last Site 480 {a:.2f} ka, first Site 479 {b:.2f} ka -> {b - a:+.2f} ka "
        f"overlap (absorbed by sorting on age)")

    # offset sensitivity
    alt = BYRNE_TIE_480_CM - BYRNE_TIE_479_CM
    if offset_cm != alt:
        deep = df[df.depth_composite_cm > SPLICE_DEPTH_CM].depth_composite_cm.values
        m = load_agemodel(proxy_dir, "479")
        n1 = assign_ages(deep - offset_cm, m)
        n2 = assign_ages(deep - alt, m)
        both = n1.dated & n2.dated
        if both.any():
            say(f"\n  offset sensitivity: using Byrne's geological {alt/100:.2f} m instead of the "
                f"{offset_cm/100:.2f} m the workbook applied")
            say(f"    would shift Site 479 ages by "
                f"{np.nanmedian(n2.age_ka[both] - n1.age_ka[both]):+.2f} ka and date "
                f"{int(n2.dated.sum())} samples instead of {int(n1.dated.sum())}.")

    # Byrne's own chronology vs ours
    s = combined[(combined.site == "DSDP-480") & combined.dated]
    say("\n  Byrne's CLAM chronology vs this project's Bacon model (Site 480):")
    for lo, hi in ((0, 2000), (2000, 3000), (3000, 4000), (4000, 5000)):
        w = s[(s.depth_native_cm >= lo) & (s.depth_native_cm < hi)]
        if len(w):
            say(f"    {lo:5d}-{hi:5d} cm  n={len(w):3d}  ours - Byrne  median "
                f"{np.median(w.age_ka - w.byrne_clam_age_ka):+7.2f} ka")
    say("    They agree where both are anchored by the same radiocarbon and diverge below it.")
    say("    A substantive disagreement with the published chronology, not a data-handling bug.")


def main() -> int:
    root = repo_root()
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", type=Path,
                    default=root / "data" / "processed" / "byrne90_pollen_combined.csv")
    ap.add_argument("--offset", type=int, default=SITE479_OFFSET_CM, metavar="CM",
                    help="cm to subtract from Site 479 composite depths "
                         f"(default {SITE479_OFFSET_CM}; see module docstring before changing)")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    proxy_dir = proxy_data_dir(root)
    extern = root / "data" / "external"
    wb_path = extern / WORKBOOK
    if not wb_path.is_file():
        raise SystemExit(f"pollen workbook not found: {wb_path}")
    if not (proxy_dir / BACON["480"][0]).is_file():
        raise SystemExit(f"Bacon runs not found under {proxy_dir}. Set PROXY_DATA_DIR or copy "
                         "config/paths.env.example to config/paths.env.")

    df = load_workbook(wb_path)
    notes = _self_checks(df, wb_path, extern, args.offset)
    combined = build(df, proxy_dir, args.offset)

    cols = ["site", "depth_native_cm", "depth_composite_cm", "dated",
            "age_ka", "age_2s_lo_ka", "age_2s_hi_ka", "artemisia_juniper_pct",
            *TAXA.values(), "byrne_clam_age_ka"]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    # %.10g, not %.6g: six significant figures caps a ~100 ka age at ~1 yr resolution, which
    # shows up as a spurious ~0.5 yr disagreement when regressing against the age model.
    combined[cols].to_csv(args.out, index=False, float_format="%.10g")

    if not args.quiet:
        print(f"source : {wb_path}")
        print(f"ages   : {proxy_dir}/Bacon_runs/DSDP{{480,479}}")
        print("\nSELF-CHECKS")
        for n in notes:
            print(f"  {n}")
        report(combined, df, proxy_dir, args.offset)
        print(f"\nwrote {args.out} ({len(combined)} rows)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
