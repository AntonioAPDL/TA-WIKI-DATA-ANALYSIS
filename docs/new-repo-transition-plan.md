# New-repo transition plan

## Purpose

Use `AntonioAPDL/TA-WIKI-DATA-ANALYSIS` as the clean coauthor-facing
GitHub/Overleaf repository for the TA Wiki descriptive survey/evaluation
manuscript.

The original repository,
`AntonioAPDL/ta-wiki-assessment-publication`, remains the working/provenance
repository. This repository is the collaboration surface for coauthors and the
Overleaf-linked manuscript.

## Migration decision

The migration uses a clean snapshot rather than a full mirror. This is the
appropriate route because the new repository is intended for coauthor review
and Overleaf use, while the prior repository preserves the development history.

The migration preserves:

- source-safe analysis code;
- respondent-free metadata;
- synthetic tests;
- documentation needed to understand the manuscript and workflow;
- the current Overleaf-facing manuscript source as `main.tex`.

The migration excludes:

- raw survey exports;
- row-level derivatives;
- timestamps;
- open-text responses;
- raffle/contact material;
- generated local review artifacts under `reports/internal/`;
- archived internal audit notes not needed for coauthor navigation.

## Source baseline

The source snapshot was prepared from:

```text
repository: AntonioAPDL/ta-wiki-assessment-publication
commit: de5c2d87ad11ce046090c94c048575e45d87fdd1
branch: agent/governed-analysis-readiness
```

The target repository preserves its initial Overleaf import history and adds the
migrated manuscript/analysis snapshot on top of `main`.

## Overleaf operating model

- `main.tex` is the manuscript file Overleaf should compile.
- Coauthors may edit prose, structure, and comments in Overleaf.
- Reported numerical results should not be changed by hand unless the change is
  traced back to the generated aggregate outputs and claim ledger.
- If the analysis changes, regenerate the manuscript package locally, validate
  the claim ledger, and update `main.tex` from the regenerated manuscript TeX.

## Validation gates

Before sharing or pushing updates:

```powershell
Rscript scripts/run.R privacy
Rscript scripts/run.R test
```

When generated aggregate outputs are available locally:

```powershell
Rscript scripts/run.R journal-claim-validation --manuscript-dir reports/internal/journal-manuscript --analysis-dir reports/internal/full-analysis
```

Before asking coauthors to review the manuscript in Overleaf, compile
`main.tex` locally or in Overleaf and confirm there are no stale warning labels
or unsupported empirical claims.

## Current next step

Use this repository for coauthor review of the descriptive manuscript. The main
open items remain survey-context verification, routing/display-logic decisions,
qualitative include/exclude decisions, venue-specific formatting, and final
author declarations.
