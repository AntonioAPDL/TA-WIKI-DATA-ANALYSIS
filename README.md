# TA Wiki platform evaluation

This repository contains the Overleaf manuscript source and the minimal
reproducible files needed to check the current descriptive analysis of the
GitHub-hosted TA Wiki as a departmental teaching-resource platform.

The Overleaf main file is:

```text
main.tex
```

## What is included

| Path | Purpose |
|---|---|
| `main.tex` | Manuscript source used by Overleaf. |
| `results/structured-aggregate/` | Aggregate structured tables, disclosure-safe open-text theme summaries, expected manuscript/table snapshots, and a manifest. |
| `scripts/` | Small command interface for rebuilding/checking the manuscript from the aggregate tables. |
| `renv.lock`, `renv/` | Locked R environment metadata. |
| `.github/workflows/ci.yml` | Reproducibility checks run on GitHub. |

Raw survey exports, row-level records, timestamps, raw open-text responses,
direct quotations, and raffle/contact information are not stored in this
repository.

## Reproduce the current manuscript values

From a clean clone:

```powershell
$env:TA_WIKI_ALLOW_RENV_BOOTSTRAP='1'
Rscript scripts/run.R bootstrap
Rscript scripts/run.R reproduce-results --check
Rscript scripts/run.R manuscript-check
```

`reproduce-results --check` rebuilds the manuscript tables, claim ledger,
aggregate supplement snapshot, and manuscript TeX from
`results/structured-aggregate/`. It then checks that the rebuilt manuscript TeX
matches `main.tex`.

`manuscript-check` verifies the root manuscript source and compiles it in a
temporary directory when `pdflatex` is available.

## Repository boundary

This is an aggregate-result reproducibility repository, not a raw-data
repository. The current descriptive numbers and disclosure-safe open-text theme
summaries can be regenerated from the tracked aggregate files, but individual
survey records and raw open-text responses cannot be reconstructed from this
repository.

If a result changes, regenerate the aggregate bundle through the approved
analysis workflow, replace the files under `results/structured-aggregate/`, and
rerun:

```powershell
Rscript scripts/run.R reproduce-results --check
```
