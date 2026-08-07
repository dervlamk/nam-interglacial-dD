#!/usr/bin/env python3
"""Strip cell outputs/execution counts from a Jupyter notebook in place.

Used as a git clean filter (see .gitattributes) so notebook diffs stay
readable and large embedded figure outputs never enter git history.
Reads stdlib json only, on purpose, so it has no dependency on
nbformat/jupyter being installed in whatever environment runs `git commit`.

Two jobs, both in service of readable diffs:

1. Clear outputs and execution counts.
2. Normalise every cell's `source` to a list of lines.

The nbformat spec allows `source` to be either a single string or a list of
lines, and both round-trip fine through Jupyter. But a cell stored as one long
string is one long JSON line, so git renders any edit to it as a whole-cell
rewrite instead of a line-by-line diff. Jupyter itself writes the list form;
some programmatic editors write the string form. Normalising here means the
committed notebook always diffs line-by-line no matter what wrote it.
"""
import json
import sys


def _as_lines(value):
    """Return notebook multiline text in nbformat's list-of-lines form."""
    if isinstance(value, str):
        # keepends: nbformat lines carry their own trailing newline, and the
        # last line has none. splitlines(True) reproduces exactly that.
        return value.splitlines(keepends=True)
    return value


def strip(notebook: dict) -> dict:
    for cell in notebook.get("cells", []):
        if cell.get("cell_type") == "code":
            cell["outputs"] = []
            cell["execution_count"] = None
        if "source" in cell:
            cell["source"] = _as_lines(cell["source"])
        # drop per-cell execution metadata that changes on every run
        cell.get("metadata", {}).pop("execution", None)
    notebook.get("metadata", {}).pop("widgets", None)
    return notebook


def main() -> None:
    if len(sys.argv) == 2:
        with open(sys.argv[1]) as f:
            nb = json.load(f)
        stripped = strip(nb)
        with open(sys.argv[1], "w") as f:
            json.dump(stripped, f, indent=1, ensure_ascii=False)
            f.write("\n")
    else:
        # git clean filter mode: read from stdin, write to stdout
        nb = json.load(sys.stdin)
        stripped = strip(nb)
        json.dump(stripped, sys.stdout, indent=1, ensure_ascii=False)
        sys.stdout.write("\n")


if __name__ == "__main__":
    main()
