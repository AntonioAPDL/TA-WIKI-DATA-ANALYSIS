# Documentation guide

This directory contains the coauthor-facing record of the study design,
workflow, controls, and current project state. It contains no respondent data,
restricted paths, internal results, cloud locators, or approval identities.

No source export, response material, restricted result, or candidate artifact
is stored here. See the [current status](current-status.md) for the shortest
summary of the active manuscript package, tracked source boundary, generated
artifacts, and remaining coauthor-review work.

## Start with the project state

- [Current status](current-status.md) - the shortest coauthor-facing summary of
  what is complete, what is excluded, and what decisions remain.
- [Reproducibility audit report](reproducibility-audit-report.md) - current
  file-by-file audit findings, verification commands, and remaining technical
  risks for the coauthor/Overleaf repository.
- [Clone-reproducible results plan](clone-reproducible-results-plan.md) -
  options and recommended path for making manuscript values, tables,
  supplement, and claim ledger reproducible from a clean clone without tracking
  raw survey rows.
- [Reproducibility file ledger](reproducibility-file-ledger.csv) - one-row-per
  tracked-file inventory documenting purpose, consumer, and reproducibility
  status.
- [Coauthor manuscript package guide](coauthor-package-guide.md) - current package
  contents, supported claims, and coauthor decision list.
- [Final manuscript completion plan](final-manuscript-completion-plan.md) -
  staged plan for factual verification, routing review, qualitative decision,
  disclosure review, citations, declarations, and final verification.
- [Coauthor review guide](coauthor-review-guide.md) - the concise reading path,
  discussion agenda, and decisions for Andrew and Marcela.
- [Project roadmap](project-roadmap.md) - the single canonical plan: current
  source state, stages, dependencies, roles, gates, and remaining work.
- [Implementation status](implementation-status.md) - completed technical work
  and the external decisions that remain.
- [Results inventory](results-inventory.csv) - source-safe status of the
  current internal structured outputs, release fragment, exploratory
  diagnostics, and deferred qualitative workspace.
- [Reporting crosswalk](reporting-crosswalk.md) - source-safe CROSS, STROBE,
  CHERRIES, and AAPOR checklist template for the final manuscript.
- [Open decisions](open-decisions.md) - the specific items that need coauthor
  or governance resolution before sharing results.
- [Completion evidence tracker template](evidence-tracker-template.md) - a
  restricted-workspace tracker for acceptance evidence and claim crosswalks.
- [Restricted finalization runbook](restricted-finalization-runbook.md) - the
  safe execution template for authorized governance, source, analysis,
  disclosure, manuscript, and handoff actions.

## Study design and analysis

- [Analysis overview](analysis-overview.md) - a concise statement of scope and
  nonclaims.
- [Analysis specification](analysis-specification.md) - the manifest-bound
  description of cohort, denominators, transformations, and planned artifacts
  for the frozen analysis baseline; use the implementation status for its
  current execution state.
- [Workflow architecture](workflow-architecture.md) - repository and
  restricted-storage boundaries, lineage, and invalidation rules.
- [Qualitative protocol](qualitative-protocol.md) - the restricted manual
  coding and disclosure-review process.

## Governance, release, and handoff

- [Data-governance boundary](data-governance.md) - permitted data classes,
  sharing boundary, and required controls.
- [Restricted-operation authorization](restricted-operation-authorization.md) -
  the signed off-repository record required before any restricted command, and
  the source-context route that keeps locator identifiers off the command line.
- [Release checklist](release-checklist.md) - requirements for any candidate
  delivery.
- [Private-repository handoff](private-repository-handoff.md) - private remote,
  review, and preservation steps.
- [Reproducibility guide](reproducibility-guide.md) - local checks, restricted
  analysis, and release verification commands.

The ignored full internal structured aggregate package is built with
`Rscript scripts/run.R full-internal-analysis ...` and written under
`reports/internal/`. It is the working aggregate analysis package for
authorized review; it does not extract or automatically code open text and is
not part of the public-safe repository contents.

## Registers and templates

- [Decision log](decision-log.md) and
  [decision-record template](decision-record-template.md) - controlled,
  non-sensitive decision documentation.
- [Source register](source-register.csv) - authoritative and contextual sources
  represented only by safe aliases.
- [Results inventory](results-inventory.csv) - lineage status and release
  conditions for planned artifacts.
- [Evidence index](evidence-index.csv) - verification evidence for the tracked
  workflow.
- [Literature evidence matrix](literature-evidence-matrix.md) - source-safe
  template for adding claim-targeted citations after article type and venue are
  selected.
- [New-repo transition plan](new-repo-transition-plan.md) - migration record
  and operating model for the GitHub/Overleaf collaboration repository.

For an orientation to the code and metadata, see the repository
[README](../README.md), [scripts guide](../scripts/README.md), and
[metadata guide](../data/metadata/README.md).
