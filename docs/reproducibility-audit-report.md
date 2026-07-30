# Reproducibility audit report

Audit date: 2026-07-30  
Repository: `AntonioAPDL/TA-WIKI-DATA-ANALYSIS`  
Local path audited: `C:\Users\anton\Downloads\TA-WIKI-DATA-ANALYSIS`  
Baseline before audit implementation: `db39389 Migrate coauthor manuscript and analysis workflow`

## Executive diagnosis

The repository is suitable as a clean coauthor-facing GitHub/Overleaf project
for the structured descriptive TA Wiki manuscript, with one important boundary:
Git alone intentionally does not contain the restricted survey source, row-level
derivatives, open text, or ignored aggregate review package needed to regenerate
the current empirical values from raw data.

The correct reproducibility target for this repository is therefore:

1. clean-clone code and metadata reproducibility;
2. privacy-boundary reproducibility;
3. synthetic workflow reproducibility;
4. root `main.tex` manuscript-source reproducibility;
5. claim-ledger traceability when the ignored aggregate manuscript package is
   available locally.

This is the right operating model for a coauthor/Overleaf repository. It keeps
restricted material out of Git while preserving a clear route for future
analysis-result changes.

## Implemented audit changes

- Added a tracked file-by-file ledger at
  [`docs/reproducibility-file-ledger.csv`](reproducibility-file-ledger.csv).
- Added this audit report as the human-readable summary of repository wiring,
  verification status, and unresolved reproducibility boundaries.
- Added `Rscript scripts/run.R manuscript-check` as the safe source-level check
  for the root `main.tex` Overleaf manuscript.
- Wired `manuscript-check` into:
  - `scripts/run.R`;
  - `scripts/README.md`;
  - `Makefile`;
  - GitHub Actions CI;
  - pull-request checklist;
  - R test suite.
- Clarified that root `main.tex` is the canonical Overleaf-facing manuscript
  source.
- Clarified that `manuscript/` contains controlled-build/provenance sources and
  is not the primary coauthor editing location.
- Updated the front-door documentation so coauthors can distinguish prose edits
  from numerical result changes.

## File inventory result

The audit ledger is generated from the project file inventory and includes each
tracked or newly added source file expected to be committed with this audit.

Every ledger row records:

- file path;
- file class;
- purpose;
- primary consumer;
- source of truth;
- whether the file contains result values;
- whether it contains restricted material;
- whether the file is reproducible from a clean clone;
- current audit status;
- recommended action.

## Canonical manuscript route

The canonical coauthor/Overleaf file is:

```text
main.tex
```

Coauthors may edit prose, structure, comments, and formatting in `main.tex`.
Counts, denominators, tables, and result claims should not be changed by hand
unless the change is traceable to the aggregate analysis and claim-ledger
validation route.

The supporting `manuscript/` directory remains useful for controlled preview,
attested-build, and provenance files, but it should not be treated as the
current Overleaf entry point.

## Empirical reproducibility boundary

The repository deliberately excludes:

- raw survey exports;
- timestamps;
- row-level derivatives;
- open-text responses;
- raffle/contact material;
- restricted governance records;
- ignored aggregate review packages under `reports/internal/`.

Because of that boundary, a clean clone can validate code, metadata, synthetic
behavior, privacy rules, and `main.tex`, but it cannot independently regenerate
the current empirical values from raw data without approved external inputs.

If exact numerical regeneration from Git alone becomes a requirement, the safe
route is to add a disclosure-safe aggregate package with hashes and a provenance
manifest after coauthor/release review. The raw source data should remain
outside Git.

## Verification commands

The following command set is the repository verification target:

```powershell
git status --short --branch
Rscript scripts/run.R privacy
Rscript scripts/run.R privacy --strict-history
python tests/test_privacy_scan.py
python tests/test_private_handoff.py
Rscript scripts/run.R test
Rscript scripts/run.R manuscript-check
python scripts/verify_private_handoff.py . --strict-history
git diff --check
git status --short
```

When a local TeX engine is installed, also run:

```powershell
Rscript scripts/run.R manuscript-check --require-pdf
```

When ignored aggregate manuscript artifacts are available, also run:

```powershell
Rscript scripts/run.R journal-claim-validation --manuscript-dir reports/internal/journal-manuscript --analysis-dir reports/internal/full-analysis
```

## Verification status

Final command results are recorded below after implementation checks:

| Check | Status | Notes |
|---|---|---|
| Git baseline/status | passed | Started from clean `main...origin/main` at `db39389`; final audit implementation commit is recorded in Git history. |
| Privacy scan | passed | `Rscript scripts/run.R privacy` passed. |
| Strict-history privacy scan | passed | `Rscript scripts/run.R privacy --strict-history` passed. |
| Python privacy tests | passed | `python tests/test_privacy_scan.py` passed. |
| Private handoff tests | passed | `python tests/test_private_handoff.py` passed. |
| R synthetic/testthat suite | passed | `Rscript scripts/run.R test` passed on a clean committed baseline with no skips; one temp-fixture Git warning was reported. |
| `manuscript-check` | passed | `Rscript scripts/run.R manuscript-check --require-pdf` passed. |
| Local required PDF compile | passed | `main.tex` compiled successfully in a temporary directory through `manuscript-check --require-pdf`. |
| Private-handoff verifier | passed | `python scripts/verify_private_handoff.py . --strict-history` passed after unreachable local amend objects were pruned. |
| Claim-ledger validation | not run; artifacts absent | `reports/internal/` contains only `.gitkeep`, so the ignored full-analysis and journal-manuscript packages are not available in this clone. |
| Final Git hygiene | passed | `git diff --check` passed; final clean status is required after this report-status refresh is committed. |

## Remaining technical risks

1. **Exact claim regeneration depends on ignored/external artifacts.**  
   This is expected, but it should remain visible. Do not present the coauthor
   repo as raw-data-self-contained.

2. **`main.tex` and generated analysis artifacts can drift.**  
   Any future result-facing edit should be validated against the claim ledger
   before sharing with coauthors.

3. **Full PDF compilation may depend on local or Overleaf TeX availability.**  
   The new `manuscript-check` command compiles locally when `pdflatex` exists
   and otherwise still checks the source boundary. For final sharing, require a
   local or Overleaf compile.

4. **Older controlled-build files can confuse reviewers if undocumented.**  
   The README and `manuscript/README.md` now identify root `main.tex` as the
   coauthor source. Keep that distinction in future edits.

## Coauthor-facing operating rule

Use this simple rule:

- prose and structure: edit `main.tex`;
- numerical results: regenerate/validate through the analysis and claim-ledger
  route;
- raw or restricted material: never store in this repository.
