# TA Wiki descriptive analysis

This repository contains the Overleaf manuscript source and the minimal
reproducible files needed to check the current descriptive analysis.

The Overleaf main file is:

```text
main.tex
```

## What is included

| Path | Purpose |
|---|---|
| `main.tex` | Manuscript source used by Overleaf. |
| `results/structured-aggregate/` | Aggregate tables, expected manuscript/table snapshots, and a manifest. |
| `scripts/` | Small command interface for rebuilding/checking the manuscript from the aggregate tables. |
| `renv.lock`, `renv/` | Locked R environment metadata. |
| `.github/workflows/ci.yml` | Reproducibility checks run on GitHub. |

Raw survey exports, row-level records, timestamps, open-text responses, and
raffle/contact information are not stored in this repository.

## Reproduce the current manuscript values

From a clean clone:

```powershell
$env:TA_WIKI_ALLOW_RENV_BOOTSTRAP='1'
Rscript scripts/run.R bootstrap
Rscript scripts/run.R reproduce-results --check
Rscript scripts/run.R manuscript-check
```

`reproduce-results --check` rebuilds the manuscript tables, claim ledger,
structured supplement snapshot, and manuscript TeX from
`results/structured-aggregate/`. It then checks that the rebuilt manuscript TeX
matches `main.tex`.

`manuscript-check` verifies the root manuscript source and compiles it in a
temporary directory when `pdflatex` is available.

## Repository boundary

This is an aggregate-result reproducibility repository, not a raw-data
repository. The current descriptive numbers can be regenerated from the tracked
aggregate tables, but individual survey records cannot be reconstructed from
this repository.

If a result changes, regenerate the aggregate bundle through the approved
analysis workflow, replace the files under `results/structured-aggregate/`, and
rerun:

```powershell
Rscript scripts/run.R reproduce-results --check
```
