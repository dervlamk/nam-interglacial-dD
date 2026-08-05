#!/usr/bin/env python3
"""Strip cell outputs/execution counts from a Jupyter notebook in place.

Used as a git clean filter (see .gitattributes) so notebook diffs stay
readable and large embedded figure outputs never enter git history.
Reads stdlib json only, on purpose, so it has no dependency on
nbformat/jupyter being installed in whatever environment runs `git commit`.
"""
import json
import sys


def strip(notebook: dict) -> dict:
    for cell in notebook.get("cells", []):
        if cell.get("cell_type") == "code":
            cell["outputs"] = []
            cell["execution_count"] = None
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
