# Clone-reproducible results implementation record

Date: 2026-07-30  
Scope: make the coauthor GitHub/Overleaf repository able to reproduce the
current manuscript values, tables, supplement, and claim ledger from a clean
clone.

Implementation status: implemented through `results/structured-aggregate/` and
`Rscript scripts/run.R reproduce-results --check`.

## 1. The core issue

Before this implementation, the repository was reproducible for code, metadata,
privacy checks, synthetic tests, and the root `main.tex` manuscript source, but
not for the empirical manuscript values because the actual results source was
outside Git:

- raw survey export is excluded;
- row-level derivatives are excluded;
- open text is excluded;
- timestamps and contact/raffle material are excluded;
- the aggregate manuscript package under `reports/internal/` is ignored.

That boundary is correct for privacy, but it means a coauthor who clones the
repo can verify the workflow and compile the manuscript without independently
regenerating the empirical values.

The implementation therefore tracks one additional source of empirical truth:
the reviewed aggregate result bundle. There is no way around that dependency;
code cannot regenerate values if neither row-level data nor aggregate results
are present.

## 2. What "fully reproducible" can mean

There are three different reproducibility targets. They should not be mixed.

| Target | What a coauthor can reproduce from a clone | What must be tracked | Privacy risk | Recommended? |
|---|---|---|---|---|
| A. Raw-data reproduction | Cleaning, recoding, analysis, tables, manuscript, and PDF from the original export. | Raw or near-raw survey rows. | Highest: small-N records, timestamps, open text, routing patterns, and possible identifiers. | No, unless the repo is treated as restricted storage. |
| B. De-identified row-level analytic reproduction | Structured cleaning/recoding/analysis from a minimized row-level dataset. | A de-identified structured analytic dataset with no timestamps, open text, contact data, or free-text fields. | Medium: small-N row patterns can still identify people. | Possible for a private coauthor repo after explicit review. |
| C. Aggregate-results reproduction | Manuscript values, tables, supplement, claim ledger, and PDF from disclosure-safe aggregate tables. | A reviewed aggregate result bundle. | Lowest: no respondent rows, no timestamps, no open text. | Yes; this is the recommended path. |

The practical goal for this repository is target C: a coauthor can clone the
repo and regenerate every number, table, supplement entry, claim ledger row,
and manuscript build from tracked aggregate results.

That is not the same as raw-data reproduction, but it is the right
coauthor-facing standard for this small departmental survey. Raw-row review can
remain a separate restricted workflow.

## 3. Recommended design

Add a tracked disclosure-safe aggregate bundle and a deterministic build/check
command.

Implemented tracked directory:

```text
results/structured-aggregate/
```

Implemented structure:

```text
results/structured-aggregate/
  README.md
  manifest.json
  aggregate-data/
    quantitative-cohort-flow.csv
    quantitative-contribution-sensitivity.csv
    quantitative-item-completeness.csv
    quantitative-structured-summary-labeled.csv
  expected/journal-manuscript/
    journal-claim-ledger.csv
    journal-style-manuscript.md
    journal-style-manuscript.tex
    journal-style-manuscript-supplement.md
    main-table-survey-record-context.csv
    main-table-engagement-indicators.csv
    supplemental-structured-indicators.csv
```

The directory name should make clear that these are not raw data and not
row-level survey records. The bundle should contain only the minimum aggregate
values needed to regenerate the manuscript and tables.

## 4. Required source bundle rules

The tracked aggregate bundle satisfies these rules:

1. No respondent-level rows.
2. No timestamps.
3. No open-text responses, quotations, close paraphrases, or text snippets.
4. No contact/raffle material.
5. No source workbook paths, cloud file IDs, approval identities, or private
   storage locations.
6. No routing-dependent conditional findings unless they are explicitly approved
   for the tracked aggregate bundle.
7. Every value must have a clear denominator and item label.
8. Every file is generated from the approved current analysis package, not
   manually typed.
9. Every file is hash-recorded in `manifest.json` using LF-normalized text
   SHA-256 values for cross-platform reproducibility.
10. The bundle passes the repository privacy scanner through an exact-path
    allowlist; the scanner does not globally permit arbitrary CSV files.

## 5. Implemented build command

The implemented runner command is:

```powershell
Rscript scripts/run.R reproduce-results
```

Supported behavior:

```powershell
Rscript scripts/run.R reproduce-results --check
Rscript scripts/run.R reproduce-results --out-dir reports/reproducibility/rebuilt
Rscript scripts/run.R reproduce-results --write-main
```

The command:

1. read `results/structured-aggregate/manifest.json`;
2. verify the LF-normalized SHA-256 hash of every aggregate input file and
   expected output snapshot;
3. rebuild the main manuscript tables;
4. rebuild the structured supplement;
5. rebuild the claim ledger;
6. rebuild the manuscript TeX in a temporary or ignored output directory;
7. compare regenerated result blocks against tracked `main.tex`;
8. invokes the existing manuscript builder, which compiles a local PDF when
   `pdflatex` is available;
9. fail if any number, denominator, table, or claim-ledger hash drifts.

`--check` is safe for CI: it does not modify tracked files.

`--write-main` is explicit and updates `main.tex` only after the
aggregate bundle has passed validation.

## 6. Privacy scanner changes

The privacy scanner continues blocking arbitrary CSV files. It adds exact
allowlist entries only for the approved aggregate bundle files:

```text
results/structured-aggregate/aggregate-data/quantitative-cohort-flow.csv
results/structured-aggregate/aggregate-data/quantitative-contribution-sensitivity.csv
results/structured-aggregate/aggregate-data/quantitative-item-completeness.csv
results/structured-aggregate/aggregate-data/quantitative-structured-summary-labeled.csv
results/structured-aggregate/expected/journal-manuscript/journal-claim-ledger.csv
results/structured-aggregate/expected/journal-manuscript/main-table-survey-record-context.csv
results/structured-aggregate/expected/journal-manuscript/main-table-engagement-indicators.csv
results/structured-aggregate/expected/journal-manuscript/supplemental-structured-indicators.csv
```

Privacy-scanner regression tests show:

- approved aggregate CSV paths pass;
- an unapproved CSV under `results/` fails;
- aggregate files containing email-like text, timestamps, or open-text markers
  fail.

## 7. CI changes

CI now runs:

```yaml
- name: Reproduce result-bearing manuscript artifacts
  run: Rscript scripts/run.R reproduce-results --check
```

The CI sequence is:

1. restore locked R environment;
2. strict privacy scan;
3. Python privacy tests;
4. private-handoff tests;
5. synthetic/testthat suite;
6. `manuscript-check`;
7. `reproduce-results --check`;
8. private-handoff verifier;
9. clean-worktree check.

This gives coauthors a clear standard: if CI is green, the tracked aggregate
bundle and manuscript source agree.

## 8. Documentation changes

Updated:

- `README.md`;
- `docs/current-status.md`;
- `docs/reproducibility-guide.md`;
- `docs/reproducibility-audit-report.md`;
- `docs/reproducibility-file-ledger.csv`;
- `scripts/README.md`.

The front-door text now says:

> From a clean clone, the repo can reproduce the manuscript values, tables,
> supplement, claim ledger, and manuscript PDF from the tracked
> disclosure-safe aggregate bundle. It still does not contain raw survey rows,
> timestamps, open text, or contact/raffle material.

## 9. Implementation stages

### Stage 1: Locate the current aggregate source package

Status: complete. The current aggregate package that produced `main.tex` was
located and verified by matching the generated TeX to root `main.tex`.

Source package pattern:

```text
reports/internal/full-analysis/
reports/internal/journal-manuscript/
```

Rule retained for future updates: if those directories are unavailable,
regenerate them from the approved restricted analysis environment. Do not
reconstruct aggregate files by manually copying values from the manuscript.

### Stage 2: Create the tracked aggregate bundle

Status: complete. Disclosure-safe aggregate files were written to:

```text
results/structured-aggregate/
```

`manifest.json` records:

- bundle schema version;
- date generated;
- analysis baseline commit;
- source alias, not source locator;
- builder script and command;
- list of files;
- LF-normalized SHA-256 hash for each file;
- explicit statement that the bundle contains aggregate results only.

Exit criterion met: no raw rows, timestamps, open text, contact/raffle
material, or private paths appear in the bundle.

### Stage 3: Add the reproduction builder

Status: complete. Added:

```text
scripts/reproduce_results_from_aggregate.R
```

Wired through:

```text
scripts/run.R
Makefile
scripts/README.md
```

Exit criterion met: `Rscript scripts/run.R reproduce-results --check` rebuilds
and validates result-bearing manuscript artifacts without modifying tracked
files.

### Stage 4: Add tests

Status: complete. Tests cover:

- privacy scanner allowlist behavior;
- runner command visibility;
- full aggregate-bundle reproduction through the testthat suite.

Exit criterion: full local test suite must pass before push.

### Stage 5: Update CI

Status: complete. `reproduce-results --check` runs in GitHub Actions after
`manuscript-check`.

Exit criterion: remote CI passes from a fresh clone after push.

### Stage 6: Update coauthor instructions

Status: complete. Docs now use this coauthor workflow:

```powershell
Rscript scripts/run.R bootstrap
Rscript scripts/run.R privacy
Rscript scripts/run.R test
Rscript scripts/run.R manuscript-check
Rscript scripts/run.R reproduce-results --check
```

Exit criterion: a coauthor can clone, run the commands, and regenerate/check
all manuscript values and tables without any external data access.

## 10. Implementation decision

Decision implemented: track a disclosure-safe aggregate result bundle in the
private coauthor/Overleaf repository.

Do not track raw or de-identified row-level data unless the team specifically
decides that row-level review is necessary inside Git. For this manuscript, the
aggregate bundle is enough to make the published descriptive values and tables
clone-reproducible.

## 11. What this will and will not solve

This implementation solves:

- clone-only reproduction of manuscript numbers;
- clone-only reproduction of main tables;
- clone-only reproduction of the structured supplement;
- clone-only claim-ledger validation;
- CI enforcement that `main.tex` and tracked aggregate results agree.

This implementation does not solve:

- independent audit of each original survey response from Git alone;
- qualitative coding from open text;
- validation of timestamps, routing/display logic, or source workbook export
  history;
- governance review for public release of the aggregate bundle.

Those remain restricted-source or coauthor-review tasks.
