# Clone-reproducible results plan

Date: 2026-07-30  
Scope: make the coauthor GitHub/Overleaf repository able to reproduce the
current manuscript values, tables, supplement, and claim ledger from a clean
clone.

## 1. The core issue

The current repository is reproducible for code, metadata, privacy checks,
synthetic tests, and the root `main.tex` manuscript source. It is not currently
clone-reproducible for the empirical manuscript values because the actual
results source is outside Git:

- raw survey export is excluded;
- row-level derivatives are excluded;
- open text is excluded;
- timestamps and contact/raffle material are excluded;
- the aggregate manuscript package under `reports/internal/` is ignored.

That boundary is correct for privacy, but it means a coauthor who clones the
repo can verify the workflow and compile the manuscript without independently
regenerating the empirical values.

To make the repo reproduce the current results from a clone, the repo must
track one additional source of empirical truth. There is no way around that:
the code cannot regenerate values if neither row-level data nor aggregate
results are present.

## 2. What "fully reproducible" can mean

There are three different reproducibility targets. They should not be mixed.

| Target | What a coauthor can reproduce from a clone | What must be tracked | Privacy risk | Recommended? |
|---|---|---|---|---|
| A. Raw-data reproduction | Cleaning, recoding, analysis, tables, manuscript, and PDF from the original export. | Raw or near-raw survey rows. | Highest: small-N records, timestamps, open text, routing patterns, and possible identifiers. | No, unless the repo is treated as restricted storage. |
| B. De-identified row-level analytic reproduction | Structured cleaning/recoding/analysis from a minimized row-level dataset. | A de-identified structured analytic dataset with no timestamps, open text, contact data, or free-text fields. | Medium: small-N row patterns can still identify people. | Possible for a private coauthor repo after explicit review. |
| C. Aggregate-results reproduction | Manuscript values, tables, supplement, claim ledger, and PDF from disclosure-safe aggregate tables. | A reviewed aggregate result bundle. | Lowest: no respondent rows, no timestamps, no open text. | Yes; this is the recommended path. |

The practical goal for this repository should be target C: a coauthor can clone
the repo and regenerate every number, table, supplement entry, claim ledger row,
and manuscript build from tracked aggregate results.

That is not the same as raw-data reproduction, but it is the right
coauthor-facing standard for this small departmental survey. Raw-row review can
remain a separate restricted workflow.

## 3. Recommended design

Add a tracked disclosure-safe aggregate bundle and a deterministic build/check
command.

Suggested tracked directory:

```text
results/structured-aggregate/
```

Suggested structure:

```text
results/structured-aggregate/
  README.md
  manifest.json
  tables/
    cohort-flow.csv
    structured-item-summary.csv
    contribution-sensitivity.csv
    main-table-1-survey-record-context.csv
    main-table-2-engagement-indicators.csv
    supplemental-structured-indicators.csv
  evidence/
    journal-claim-ledger.csv
    aggregate-source-hashes.json
```

The directory name should make clear that these are not raw data and not
row-level survey records. The bundle should contain only the minimum aggregate
values needed to regenerate the manuscript and tables.

## 4. Required source bundle rules

Before any aggregate file is tracked, it should satisfy these rules:

1. No respondent-level rows.
2. No timestamps.
3. No open-text responses, quotations, close paraphrases, or text snippets.
4. No contact/raffle material.
5. No source workbook paths, cloud file IDs, approval identities, or private
   storage locations.
6. No routing-dependent conditional findings unless they are explicitly approved
   for the tracked aggregate bundle.
7. Every value must have a clear denominator and item label.
8. Every file must be generated from the approved current analysis package, not
   manually typed.
9. Every file must be hash-recorded in `manifest.json`.
10. The bundle must pass the repository privacy scanner through an exact-path
    allowlist; the scanner should not globally permit arbitrary CSV files.

## 5. Build command to add

Add a new runner command:

```powershell
Rscript scripts/run.R reproduce-results
```

Recommended behavior:

```powershell
Rscript scripts/run.R reproduce-results --check
Rscript scripts/run.R reproduce-results --out-dir reports/reproducibility/rebuilt
Rscript scripts/run.R reproduce-results --write-main
```

The command should:

1. read `results/structured-aggregate/manifest.json`;
2. verify the SHA-256 hash of every aggregate input file;
3. rebuild the main manuscript tables;
4. rebuild the structured supplement;
5. rebuild the claim ledger;
6. rebuild the manuscript TeX in a temporary or ignored output directory;
7. compare regenerated result blocks against tracked `main.tex`;
8. compile the rebuilt manuscript when `pdflatex` is available;
9. fail if any number, denominator, table, or claim-ledger hash drifts.

`--check` should be safe for CI: it should not modify tracked files.

`--write-main` should be explicit and should update `main.tex` only after the
aggregate bundle has passed validation.

## 6. Privacy scanner changes

The privacy scanner should continue blocking arbitrary CSV files. Add exact
allowlist entries only for the approved aggregate bundle files, for example:

```text
results/structured-aggregate/tables/cohort-flow.csv
results/structured-aggregate/tables/structured-item-summary.csv
results/structured-aggregate/tables/contribution-sensitivity.csv
results/structured-aggregate/tables/main-table-1-survey-record-context.csv
results/structured-aggregate/tables/main-table-2-engagement-indicators.csv
results/structured-aggregate/tables/supplemental-structured-indicators.csv
results/structured-aggregate/evidence/journal-claim-ledger.csv
```

Add privacy-scanner regression tests showing:

- approved aggregate CSV paths pass;
- an unapproved CSV under `results/` fails;
- aggregate files containing email-like text, timestamps, or open-text markers
  fail.

## 7. CI changes

After the aggregate bundle and command exist, CI should run:

```yaml
- name: Reproduce result-bearing manuscript artifacts
  run: Rscript scripts/run.R reproduce-results --check
```

The CI sequence should become:

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

Update:

- `README.md`;
- `docs/current-status.md`;
- `docs/reproducibility-guide.md`;
- `docs/reproducibility-audit-report.md`;
- `docs/reproducibility-file-ledger.csv`;
- `scripts/README.md`.

The front-door text should then say:

> From a clean clone, the repo can reproduce the manuscript values, tables,
> supplement, claim ledger, and manuscript PDF from the tracked
> disclosure-safe aggregate bundle. It still does not contain raw survey rows,
> timestamps, open text, or contact/raffle material.

## 9. Implementation stages

### Stage 1: Locate the current aggregate source package

Find or regenerate the latest local package that produced `main.tex`:

```text
reports/internal/full-analysis/
reports/internal/journal-manuscript/
```

If those directories are unavailable, regenerate them from the approved
restricted analysis environment. Do not reconstruct aggregate files by manually
copying values from the manuscript.

Exit criterion:

- the exact aggregate files and claim ledger used for the current manuscript are
  available locally for review.

### Stage 2: Create the tracked aggregate bundle

Write only disclosure-safe aggregate files to:

```text
results/structured-aggregate/
```

Create `manifest.json` with:

- bundle schema version;
- date generated;
- analysis baseline commit;
- source alias, not source locator;
- builder script and command;
- list of files;
- SHA-256 hash for each file;
- explicit statement that the bundle contains aggregate results only.

Exit criterion:

- no raw rows, timestamps, open text, contact/raffle material, or private paths
  appear in the bundle.

### Stage 3: Add the reproduction builder

Add:

```text
scripts/reproduce_results_from_aggregate.R
```

Wire it through:

```text
scripts/run.R
Makefile
scripts/README.md
```

Exit criterion:

- `Rscript scripts/run.R reproduce-results --check` rebuilds and validates
  result-bearing manuscript artifacts without modifying tracked files.

### Stage 4: Add tests

Add tests for:

- manifest validation;
- missing aggregate files;
- hash mismatch;
- result/table drift against `main.tex`;
- privacy scanner allowlist behavior;
- no tracked-file modifications in `--check` mode.

Exit criterion:

- full local test suite passes.

### Stage 5: Update CI

Add `reproduce-results --check` to GitHub Actions after `manuscript-check`.

Exit criterion:

- remote CI passes from a fresh clone.

### Stage 6: Update coauthor instructions

Update docs to make the new workflow simple:

```powershell
Rscript scripts/run.R bootstrap
Rscript scripts/run.R privacy
Rscript scripts/run.R test
Rscript scripts/run.R manuscript-check
Rscript scripts/run.R reproduce-results --check
```

Exit criterion:

- a coauthor can clone, run the commands, and regenerate/check all manuscript
  values and tables without any external data access.

## 10. Decision needed before implementation

One decision is needed:

> Should the repo track a disclosure-safe aggregate result bundle?

Recommended answer: yes, for the private coauthor/Overleaf repository.

Do not track raw or de-identified row-level data unless the team specifically
decides that row-level review is necessary inside Git. For this manuscript, the
aggregate bundle is enough to make the published descriptive values and tables
clone-reproducible.

## 11. What this will and will not solve

This plan will solve:

- clone-only reproduction of manuscript numbers;
- clone-only reproduction of main tables;
- clone-only reproduction of the structured supplement;
- clone-only claim-ledger validation;
- CI enforcement that `main.tex` and tracked aggregate results agree.

This plan will not solve:

- independent audit of each original survey response from Git alone;
- qualitative coding from open text;
- validation of timestamps, routing/display logic, or source workbook export
  history;
- governance review for public release of the aggregate bundle.

Those remain restricted-source or coauthor-review tasks.
