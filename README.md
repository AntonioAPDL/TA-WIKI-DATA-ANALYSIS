# TA Wiki data analysis and manuscript

This is the coauthor-facing repository for the TA Wiki descriptive
survey/evaluation manuscript and reproducible analysis workflow.

The repository is connected to Overleaf. The Overleaf main file is:

```text
main.tex
```

Use `main.tex` for manuscript reading and coauthor prose edits. Use the analysis
workflow, metadata, and claim ledger process for any future changes to reported
counts, denominators, tables, or result claims.

## Start here

1. Open the Overleaf project and compile `main.tex`.
2. Read [current status](docs/current-status.md) for what the manuscript
   supports, what is excluded, and what remains for coauthor review.
3. Read [coauthor package guide](docs/coauthor-package-guide.md) for the
   manuscript/supplement/evidence files used in review packages.
4. Read [analysis overview](docs/analysis-overview.md) for the scope and
   explicit nonclaims.
5. Read [reproducibility guide](docs/reproducibility-guide.md) before rerunning
   or modifying the analysis workflow.
6. Read [new-repo transition plan](docs/new-repo-transition-plan.md) for the
   migration record and operating model for this GitHub/Overleaf repository.

## Current manuscript scope

The manuscript is a structured-only departmental descriptive survey/evaluation.
It reports observed survey-record counts, item-specific denominators,
missing/invalid responses, direct contribution status, and an extreme-case
deterministic missing-response range.

It does not report raw survey rows, timestamps, open-text responses,
raffle/contact material, response rates, causal effects, department-wide
prevalence, or routing-dependent conditional findings.

## Repository map

| Location | Purpose |
|---|---|
| `main.tex` | Overleaf-facing manuscript source. |
| [`docs/`](docs/README.md) | Current status, coauthor guidance, analysis design, and reproducibility documentation. |
| [`data/metadata/`](data/metadata/README.md) | Respondent-free schema, codebook, and transformation contracts. |
| [`scripts/`](scripts/README.md) | Reproducible workflow commands and implementation modules. |
| [`tests/`](tests) | Synthetic fixtures and automated checks. |
| [`config/`](config) | Controlled project configuration. |

## Data boundary

Raw survey exports, timestamps, respondent rows, open text, raffle/contact
records, and restricted governance records are not stored in this repository.
The tracked files contain source-safe code, respondent-free metadata, synthetic
tests, manuscript source, and documentation.

## Validation

For routine repository checks:

```powershell
Rscript scripts/run.R privacy
Rscript scripts/run.R test
```

For the generated manuscript package workflow:

```powershell
Rscript scripts/run.R journal-style-manuscript --analysis-dir reports/internal/full-analysis --out-dir reports/internal/journal-manuscript
Rscript scripts/run.R journal-claim-validation --manuscript-dir reports/internal/journal-manuscript --analysis-dir reports/internal/full-analysis
Rscript scripts/run.R coauthor-package --manuscript-dir reports/internal/journal-manuscript
```

The generated package paths under `reports/internal/` are ignored because they
are local review artifacts. The Overleaf-facing manuscript source is the tracked
`main.tex`.

## Migration record

This repository was prepared from the clean manuscript workflow at source commit
`de5c2d87ad11ce046090c94c048575e45d87fdd1` of
`AntonioAPDL/ta-wiki-assessment-publication`. The original repository remains
the provenance/working repository; this repository is the clean
coauthor/Overleaf collaboration repository.
