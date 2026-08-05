#!/bin/bash
# Run once after cloning: registers the git clean filter that strips
# Jupyter notebook outputs before they're committed (see .gitattributes).
set -e
git config filter.stripoutput.clean "python3 tools/strip_notebook_output.py"
git config filter.stripoutput.smudge cat
git config filter.stripoutput.required true
echo "Registered git filter: notebook outputs will be stripped on commit."
