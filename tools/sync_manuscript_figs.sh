#!/usr/bin/env bash
#
# Copy the current manuscript figures from the figure-output directory into its
# for_manuscript/ subdirectory.
#
#   tools/sync_manuscript_figs.sh [-n|--dry-run]
#
# The figure-output directory is a working scratch space: it holds figures going back to 2019,
# screenshots, and stray MATLAB scripts. for_manuscript/ is meant to hold exactly the figures
# the manuscript uses, so this script syncs an explicit named set rather than globbing.
#
# ADDING A FIGURE TO THE MANUSCRIPT = adding a line to FIGURES below. That is deliberate: an
# automatic rule would either sweep in the scratch files or silently skip a figure whose
# savefig() happens to be commented out.
#
# A figure is copied only when it is newer than the copy already in for_manuscript/, so running
# this repeatedly is a no-op and it is safe to run out of habit. Timestamps are preserved
# (cp -p) so that comparison stays meaningful across runs.
#
# Exit status: 0 if every figure is present, 1 if any is missing (so it can gate a release step).

set -euo pipefail

# --- the manuscript figure set ---------------------------------------------------------------
# "<filename>|<notebook that produces it>"
FIGURES=(
  "modern_climo.png|fig1_swna_modern_climate.ipynb"
  "dsdp_480-479.agemodel.pdf|fig2_dsdp480-479_agemodel.ipynb"
  "dDp_timeseries.pdf|fig3_dDwax_timeseries.ipynb"
)

# --- arguments ---------------------------------------------------------------------------------
DRY_RUN=0
case "${1:-}" in
  -n|--dry-run) DRY_RUN=1 ;;
  -h|--help)    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "")           ;;
  *)            echo "unknown argument: $1 (try --help)" >&2; exit 2 ;;
esac

# --- locate the repo and the figure-output directory -------------------------------------------
if ! REPO_ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null); then
  REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)   # works outside a git checkout too
fi

# Environment first, then config/paths.env. There is deliberately NO third fallback: this
# script used to default to $REPO_ROOT/../outputs while the notebooks defaulted to a repo-local
# outputs/, so an unsourced Jupyter session wrote figures somewhere this script never looked and
# the two directories diverged unnoticed. Erroring out is the point.
if [ -z "${FIG_OUTPUT_DIR:-}" ] && [ -f "$REPO_ROOT/config/paths.env" ]; then
  # shellcheck disable=SC1091
  . "$REPO_ROOT/config/paths.env"
fi
SRC="${FIG_OUTPUT_DIR:-}"

if [ -z "$SRC" ]; then
  echo "FIG_OUTPUT_DIR is not set and $REPO_ROOT/config/paths.env did not set it." >&2
  echo "Copy config/paths.env.example to config/paths.env, or export FIG_OUTPUT_DIR." >&2
  exit 2
fi
if [ ! -d "$SRC" ]; then
  echo "figure-output directory not found: $SRC" >&2
  echo "Check FIG_OUTPUT_DIR in config/paths.env." >&2
  exit 2
fi
SRC=$(cd "$SRC" && pwd)   # normalise ../ away so the messages below are readable
DEST="$SRC/for_manuscript"

echo "from: $SRC"
echo "to:   $DEST"
[ "$DRY_RUN" -eq 1 ] && echo "(dry run — nothing will be written)"
echo

[ "$DRY_RUN" -eq 1 ] || mkdir -p "$DEST"

# --- sync ---------------------------------------------------------------------------------------
copied=0; current=0; missing=0; stale=0

for entry in "${FIGURES[@]}"; do
  name="${entry%%|*}"
  notebook="${entry##*|}"
  src_file="$SRC/$name"
  dest_file="$DEST/$name"

  if [ ! -f "$src_file" ]; then
    printf '  MISSING   %-32s run %s\n' "$name" "$notebook"
    missing=$((missing + 1))
    continue
  fi

  # Warn if the notebook has been edited since the figure was written — the figure is then
  # built from code that no longer exists. Not an error: the edit may not affect the figure.
  if [ -f "$REPO_ROOT/$notebook" ] && [ "$REPO_ROOT/$notebook" -nt "$src_file" ]; then
    printf '  STALE?    %-32s %s is newer than the figure — re-run it\n' "$name" "$notebook"
    stale=$((stale + 1))
  fi

  if [ -f "$dest_file" ] && [ ! "$src_file" -nt "$dest_file" ]; then
    printf '  up to date %-31s\n' "$name"
    current=$((current + 1))
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  would copy %-31s\n' "$name"
  else
    cp -p "$src_file" "$dest_file"
    printf '  copied     %-31s %s\n' "$name" "$(date -r "$dest_file" '+%Y-%m-%d %H:%M')"
  fi
  copied=$((copied + 1))
done

# --- summary --------------------------------------------------------------------------------------
echo
if [ "$DRY_RUN" -eq 1 ]; then verb="to copy"; else verb="copied"; fi
summary="$copied $verb, $current up to date, $missing missing"
[ "$stale" -gt 0 ] && summary="$summary, $stale possibly stale"
echo "$summary"

[ "$missing" -eq 0 ] || exit 1
