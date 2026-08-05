#!/bin/bash
# Launch an interactive CASPER compute-node session for running Claude Code
# (or any agentic / sustained dev tooling) OFF the login nodes.
#
# WHY: the login-node policy reaps processes that use excessive CPU, >a few GB
# of memory, or heavy I/O — and terminates the SSH session. An agent loop
# (subprocess spawns, tree searches, a long-lived session) is exactly that
# workload, so it belongs on a compute node.
#
# This does NOT run Claude Code in batch — an agent needs an interactive TTY.
# `qsub -I` gets you an interactive shell on a Casper compute node with real
# resources; you then launch `claude` yourself (see the banner it prints).
#
# BILLING: Casper is a SHARED queue billed per CORE requested — keep ncpus
# small. Claude Code itself is a light Node process; the interactive session is
# for editing plus CHEAP dev checks. Full climatology processing belongs in
# batch scripts under src/process/, submitted from this shell with `qsub`.
#
# NOTE: the MATLAB stages in src/analysis/ and src/process/dDwax_*.m do not run
# here at all — they need a local MATLAB and the ~/Documents/MATLAB/toolbox
# functions. They are in this clone for provenance and editing only.
#
# USAGE (run from a Casper login node — `ssh casper.hpc.ucar.edu`):
#   scripts/claude_casper.sh                 # defaults below
#   NCPUS=8 MEM=64GB WALLTIME=08:00:00 scripts/claude_casper.sh   # heavier dev run
#
# Override any of ACCOUNT / QUEUE / NCPUS / MEM / WALLTIME / PRIORITY via env.

set -euo pipefail

ACCOUNT="${ACCOUNT:-uazn0018}"
QUEUE="${QUEUE:-casper}"
NCPUS="${NCPUS:-4}"
MEM="${MEM:-32GB}"
WALLTIME="${WALLTIME:-04:00:00}"
PRIORITY="${PRIORITY:-economy}"        # economy is cheapest

echo "Requesting interactive Casper session:"
echo "  account=${ACCOUNT} queue=${QUEUE} ncpus=${NCPUS} mem=${MEM} walltime=${WALLTIME} priority=${PRIORITY}"
echo "Once you land on the compute node, start Claude Code with:"
echo "    module load conda && conda activate gcm_analysis && claude"
echo

# -I = interactive; -l select pins the resources. Single node — the work is a
# light Node process plus single-threaded numpy dev checks, never MPI.
exec qsub -I \
    -A "${ACCOUNT}" \
    -q "${QUEUE}" \
    -l job_priority="${PRIORITY}" \
    -l select=1:ncpus="${NCPUS}":mem="${MEM}" \
    -l walltime="${WALLTIME}"
