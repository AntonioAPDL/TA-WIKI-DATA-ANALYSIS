# Workflow scripts

Use `Rscript scripts/run.R <command>` as the supported interface. The numbered
files in this directory are implementation modules; invoke them through the
runner unless a test or maintenance task explicitly requires otherwise.

Run `Rscript scripts/run.R help` to print the current command list.

Every command that reads or writes restricted material validates an
action-specific human-signed operating authorization held outside Git. A
restricted-root preflight alone is insufficient. See
[`docs/restricted-operation-authorization.md`](../docs/restricted-operation-authorization.md)
for the required record and source-context contract; synthetic commands and
`readiness` do not require it.

## Commands

| Command | Purpose | Preconditions and outputs |
|---|---|---|
| `bootstrap` | Restore the locked R environment. | Requires opt-in bootstrap on a new machine. |
| `privacy` | Scan the tracked files, or all history with `--strict-history`. | Must pass before a handoff or private push. |
| `test` | Run the synthetic and adversarial test suite. | Uses only synthetic fixtures. |
| `intake` | Freeze source provenance and schema evidence. | Requires signed `intake` authorization and a restricted source-access context; copies the approved restricted staging workbook into a hash-bound freeze; accepts only `--freeze-id`, never locator IDs. |
| `validate` | Validate a frozen source or create a synthetic validation run. | Real runs require signed `validate` authorization and an approved source freeze; validation writes a cohort ledger only, while synthetic runs are separate. |
| `transform` | Apply controlled transformations. | A real manifest requires signed `transform` authorization; it re-opens the hash-bound freeze in memory and selects only controlled structured fields. |
| `analyze` | Produce restricted structured summaries. | A real manifest requires signed `analyze` authorization before structured derivatives are read. |
| `qualitative` | Create an empty restricted qualitative workspace. | Requires signed `qualitative` authorization and a real transformation manifest; never reads open text. |
| `qualitative-snapshot` | Record a hash-only snapshot of a restricted qualitative workspace. | Requires signed `qualitative-snapshot` authorization and an authorized manual-review workspace. |
| `release` | Prepare a restricted release candidate. | Requires signed `release` authorization, approved threshold, and a complete current `01` → `02` → `03` real-data chain. It does not publish. |
| `verify-release` | Verify a restricted, byte-bound release attestation. | Requires signed `verify-release` authorization, an exact candidate, and approval identifier; v0.4 records analytical, verifier, and manuscript-build provenance separately without authorizing a later checkout. |
| `readiness` | Report machine-enforceable real-data prerequisites. | Does not access the survey, create a run, or claim institutional approval. |
| `manuscript-check` | Check the root `main.tex` Overleaf manuscript source. | Uses only tracked TeX source. It verifies the canonical source structure and stale-label boundary, then compiles in a temporary directory when `pdflatex` is available. Use `--require-pdf` to fail if no TeX engine is found. |
| `manuscript-preview` | Build a local, controlled manuscript preview. | Uses only tracked manuscript inputs; output is ignored. |
| `manuscript-attested-build` | Build a restricted manuscript-integration PDF. | Requires signed `manuscript-attested-build` authorization, exact candidate, byte-bound attestation, and prior verification. It stages results only in restricted storage and never delivers or copies them into Git. |
| `coauthor-brief` | Build a local, results-free coauthor review brief. | Uses one tracked self-contained TeX source; output is ignored and not submission-ready. |
| `full-internal-analysis` | Build the ignored structured aggregate internal analysis package. | Reads a completed run directory and writes quantitative aggregate tables to `reports/internal/`. It does not accept `--source-xlsx`, extract open text, or perform automatic qualitative coding. |
| `journal-style-manuscript` | Build the structured-only coauthor-review manuscript. | Reads the ignored `reports/internal/full-analysis/` package, creates a claim-to-evidence ledger, concise main tables, separate supplement artifacts, PDF/HTML/Markdown review artifacts, and optional local review copies. The main article excludes qualitative claims and routing-dependent diagnostics. |
| `journal-claim-validation` | Validate the journal manuscript snapshot. | Checks generated main tables, claim-ledger hashes, blocked routing-dependent items, compact table scope, fixed PDF table placement, line-number configuration, and manuscript-profile exclusions without generating manuscript prose. |
| `reproduce-results` | Rebuild and check the current manuscript values from the tracked aggregate bundle. | Reads only `results/structured-aggregate/`, rebuilds the journal manuscript/tables/ledger in a temporary directory, validates the claim ledger, and confirms the rebuilt TeX matches root `main.tex`. Use `--check` for the standard read-only verification. |
| `coauthor-package` | Assemble a clean coauthor-review package. | Reads the generated journal manuscript directory and creates a package directory, manifest, cleanly named manuscript/supplement/evidence files, and ZIP when the local zip utility is available. |

## Common paths

For routine code verification:

```powershell
$env:TA_WIKI_ALLOW_RENV_BOOTSTRAP='1'
Rscript scripts/run.R bootstrap
Rscript scripts/run.R privacy
Rscript scripts/run.R test
Rscript scripts/run.R manuscript-check
Rscript scripts/run.R reproduce-results --check
```

For a real-data workflow, follow the
[reproducibility guide](../docs/reproducibility-guide.md) exactly. The
repository is never a restricted-data workspace.

`preflight_restricted_root.ps1` checks the local restricted-data location before
real-data work. `blocked_release_entrypoint.R` is retained as a fail-closed
entry point for an older release route; it always stops and does not render or
deliver results.

For final private handoff, use `python scripts/verify_private_handoff.py` from
a fresh clean clone. It is read-only and can check repository hygiene, privacy
history, hooks, and a credential-free `origin`; hosting controls remain a
separate human review.
