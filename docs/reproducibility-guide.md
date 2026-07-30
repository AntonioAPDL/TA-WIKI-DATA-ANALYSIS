# Reproducibility guide

## Purpose and boundary

This guide defines three distinct reproducibility layers without recording
restricted paths, source hashes, access identities, or respondent material.

1. **Code reproducibility:** an authorized coauthor restores the locked R
   environment and runs the synthetic checks.
2. **Restricted-analysis reproducibility:** an authorized analyst reruns a
   frozen source inside the approved restricted root from the recorded lineage.
3. **Release reproducibility:** a reviewer verifies an approved, disclosure-safe
   candidate against its policy and byte-bound restricted attestation.

The repository is not a data workspace. Never use it or the Downloads folder
for a real export, internal table, open-text coding file, or attestation.

## Prerequisites

The documented restricted-data route uses Windows PowerShell. Install the
following tools before starting; no restricted input is needed for the code
checks.

| Tool | Requirement | Notes |
|---|---|---|
| Git | A current Git installation | Required for the privacy scan, source control, and hooks. |
| R | R 4.5.2, matching `renv.lock` | Make `Rscript` available on `PATH`, or substitute its full path in the commands below. |
| Python | A real Python 3 installation | Required by the privacy scanner. Put it on `PATH`, use the Windows `py -3` launcher, or set `TA_WIKI_PYTHON` to its executable. |
| Network access | Needed only for the first locked-environment restore | `renv.lock` records the dependencies; later restores may use the local cache. |
| TeX | Optional | Required only to build a local manuscript preview with `pdflatex`. |

For example, if R is not on `PATH`, invoke the runner with its full executable
path, such as `& 'C:\Program Files\R\R-4.5.2\bin\Rscript.exe' scripts/run.R help`.

## What is tracked and what stays local

| Material | Location | Git status |
|---|---|---|
| Code, controlled metadata, documentation, and synthetic fixtures | Repository | Tracked after review and privacy checks. |
| Synthetic run artifacts | `tests/artifacts/` | Ignored; safe to recreate. |
| Coauthor brief or manuscript preview PDF and build record | `manuscript/` | Ignored; local build evidence only. |
| Real runs, internal outputs, qualitative workspace, candidate, attestation, and attested manuscript build | Approved restricted root | Outside the repository and never tracked. |
| Local execution tracker | `reports/internal/` | Ignored and never a release artifact. |

## Code layer

From the repository root:

```powershell
$env:TA_WIKI_ALLOW_RENV_BOOTSTRAP='1'
Rscript scripts/run.R bootstrap
Rscript scripts/run.R privacy
Rscript scripts/run.R test
Rscript scripts/run.R manuscript-check
```

The lockfile controls the R dependency set. A platform-local locale warning may
be reported by R; it is not a data or test failure. Any failed test, privacy
scan, lockfile mismatch, or unexpected tracked-file change blocks a handoff.

`manuscript-check` reads the tracked root `main.tex`, verifies that it is the
standalone Overleaf-facing manuscript source, checks for stale internal-review
labels, and compiles the manuscript in a temporary directory when `pdflatex` is
available. Use `Rscript scripts/run.R manuscript-check --require-pdf` when a
local PDF build is required rather than optional.

## Coauthor-facing manuscript layer

The canonical coauthor manuscript source in this repository is the root
`main.tex` file. It is the file linked to Overleaf and the file coauthors should
read or edit for prose, structure, and comments.

Numerical result changes are different. Do not hand-edit counts, denominators,
tables, or result claims in `main.tex` unless the change is traceable to the
aggregate analysis package and claim-ledger validation route:

```powershell
Rscript scripts/run.R journal-style-manuscript --analysis-dir reports/internal/full-analysis --out-dir reports/internal/journal-manuscript
Rscript scripts/run.R journal-claim-validation --manuscript-dir reports/internal/journal-manuscript --analysis-dir reports/internal/full-analysis
```

Those generated folders are ignored. If they are unavailable in a local clone,
the clone can still validate code, metadata, privacy boundaries, and the
manuscript source, but it cannot independently regenerate the current empirical
numbers from Git alone.

## Coauthor review brief

The results-free coauthor brief is the current presentation-safe PDF. It is
self-contained, requires its tracked TeX source to match `HEAD`, and writes an
ignored local PDF plus build record under `manuscript/`.

```powershell
$env:TA_WIKI_PDFLATEX = 'C:\path\to\pdflatex.exe' # omit when pdflatex is on PATH
Rscript scripts/run.R coauthor-brief
```

The default output is `manuscript/coauthor-review-brief.pdf`. It contains no
restricted or approved numerical results and is not a submission-ready
manuscript. Use it with the [coauthor review guide](coauthor-review-guide.md).

If a local MiKTeX installation reports that its user setup is unfinished, finish
that user-level setup in a writable profile before building. Do not replace a
failed controlled build with a manually exported or unverified PDF.

## Manuscript preview

The tracked manuscript can be compiled into a local controlled draft preview
without reading restricted storage or adding numerical results. The command
requires the tracked manuscript inputs to match `HEAD`, verifies their hashes,
and writes an ignored PDF plus a local build record under `manuscript/`.

```powershell
$env:TA_WIKI_PDFLATEX = 'C:\path\to\pdflatex.exe' # omit when pdflatex is on PATH
Rscript scripts/run.R manuscript-preview
```

The default output is `manuscript/article-preview.pdf`. It is a draft preview,
not a submission-ready manuscript. Use `--output manuscript/<name>.pdf` for
another ignored output name; destinations outside `manuscript/` are rejected.
The final manuscript build remains contingent on approved generated results,
verified governance wording, and a clean-clone verification.

## Governance and restricted-root precondition

Before any real-data command, identify an external candidate restricted root.
It may be preflighted while it contains no restricted material, but the
applicable governance authority must authorize the environment, access roles,
storage, retention, and permitted analysis/sharing scope before any restricted
operation. Run the preflight against the candidate root:

```powershell
.\scripts\preflight_restricted_root.ps1 -RestrictedRoot <approved-root>
```

The preflight verifies path and broad ACL conditions and writes a restricted
record. It does **not** prove institutional approval, encryption, backup,
retention, or incident-response coverage. The governance authorization is an
entry condition for real-data commands, not a later release formality. Set
`TA_WIKI_RESTRICTED_ROOT` only in the authorized execution environment; do not
save its value in a tracked file.

After the selected clean code baseline is in place, rerun the preflight once
immediately before the responsible authority creates the current human-signed
authorization described in
[restricted-operation authorization](restricted-operation-authorization.md).
The signed record must bind that newly written preflight fingerprint; do not
rerun the preflight after signing, because its changed fingerprint will
intentionally invalidate the authorization.
Prompt for its restricted record ID only in the active authorized session so
the value is not written into normal shell history:

```powershell
$authorizationId = Read-Host 'Restricted operating authorization ID'
$env:TA_WIKI_GOVERNANCE_AUTHORIZATION_ID = $authorizationId
```

Every restricted command rejects a missing, expired, out-of-scope, altered, or
baseline-mismatched record. `readiness` remains a read-only technical status
report: it can check the record and signed-artifact fields without accessing
survey data, but cannot authenticate the human signer or authorize a run.

## Source intake and lineage

The live authoritative survey source is known to be available to the authorized
team, but it is not itself a reproducible analysis input. Before intake:

If the G1b compatibility review accepts the historic immutable freeze, begin
validation from its approved freeze ID instead of exporting or intaking a new
copy. Otherwise use the intake route below; do not substitute an unreviewed
legacy derivative for either route.

1. Complete governance authorization for the restricted environment and source
   handling.
2. Confirm that the configured disclosure threshold of five and the designated
   review roles apply to the intended restricted workflow. Verify the exact
   clean code-and-policy baseline before beginning a real lineage.
3. Export the closed live source directly from the approved environment to
   `raw/TA Wiki Feedback Survey (Responses).xlsx` under the restricted root.
   Never stage the export in Downloads, the repository, email, or a synced
   local folder.
4. Record the approved source handoff, file locator, and revision in the
   external `governance/source-access-context.json` record described in the
   authorization guide. Never place them in Git, this guide, or a command-line
   argument.
5. Preserve the original export unchanged until intake has completed. Do not
   replace it while a freeze is being created.

The source is then frozen through an immutable intake record. Intake verifies
that the staging workbook resolves inside the approved restricted root, copies
it into `governance/source-freezes/<freeze-id>/source-workbook.xlsx`, verifies
the source remained byte-identical during copying, and profiles that frozen
copy. The provenance record binds the copied workbook hash, byte count, source
context, header manifest, and schema profile. It does not write source values
into the repository or use the mutable `raw/` staging file for later
validation.

```powershell
Rscript scripts/run.R intake --freeze-id <freeze-id>
```

The intake command reads the locator and revision only from the approved
restricted source-access context after the signed `intake` authorization has
passed. This prevents those identifiers from being retained in shell or process
command history. Later validation reads the hash-bound frozen workbook rather
than the raw staging export, and stops if the frozen workbook or provenance
artifacts have changed.

Use the resulting source-freeze ID for a real validation run. The variables
below point to the manifests that each stage writes; do not substitute a
similarly named file from another run.

```powershell
$runId = '<run-id>'
Rscript scripts/run.R validate --run-id $runId --source-freeze-id <freeze-id>
$runDirectory = Join-Path $env:TA_WIKI_RESTRICTED_ROOT "runs\real-$runId"
$validationManifest = Join-Path $runDirectory 'manifests\01-validation.json'
Rscript scripts/run.R transform --manifest $validationManifest
$transformationManifest = Join-Path $runDirectory 'manifests\02-transformation.json'
Rscript scripts/run.R analyze --manifest $transformationManifest
$analysisManifest = Join-Path $runDirectory 'manifests\03-analysis.json'
```

The only accepted restricted lineage is:

| Stage | Manifest | Required predecessor | Purpose |
|---|---|---|---|
| Validation | `01-validation.json` | immutable source-freeze record | validates schema, forms the analytic cohort, and writes a restricted cohort ledger only |
| Transformation | `02-transformation.json` | validation manifest | applies controlled recodes and writes data-quality/transformation audits |
| Internal analysis | `03-analysis.json` | transformation manifest | produces restricted structured summaries, sensitivity output, and exploratory tables |

Each downstream stage verifies predecessor output hashes and the controlled
metadata hash set. A source, header, metadata, listed analytical control,
policy, or environment change requires a new lineage and invalidates dependent
artifacts. An editorial-only manuscript or layout change is handled through a
separate authorized build and downstream review, not an analytical rerun by
itself.

Intake creates a candidate live-header manifest in restricted storage. Compare
it with the tracked header contract before validation. A frozen export with a
header discrepancy is preserved as evidence but is not run-ready: stop and
resolve source drift or controlled metadata changes before continuing.

For the current repository version, run the complete validation-to-analysis
sequence again in approved restricted storage before a release candidate is
prepared. The earlier restricted structured run is historic evidence only.
Transformation re-opens the immutable freeze and verifies its source and
header contract in memory; it does not read a duplicate raw CSV derivative.
Candidate generation rejects an analysis manifest unless its clean Git commit,
analytical-control fingerprint, controlled metadata, and release-policy
fingerprint match the selected baseline. A policy-byte change, including a
comment/whitespace change, is intentionally a rerun trigger.

## Synthetic runs

Synthetic runs do not require a restricted root and must remain separate from
real runs:

```powershell
$syntheticRoot = Join-Path $PWD 'tests\artifacts'
$runId = 'smoke-001'
Rscript scripts/run.R validate --synthetic --run-id $runId --synthetic-root $syntheticRoot
$runDirectory = Join-Path $syntheticRoot "synthetic-$runId"
$validationManifest = Join-Path $runDirectory 'manifests\01-validation.json'
Rscript scripts/run.R transform --manifest $validationManifest
$transformationManifest = Join-Path $runDirectory 'manifests\02-transformation.json'
Rscript scripts/run.R analyze --manifest $transformationManifest
```

`tests/artifacts/` is ignored. Do not relabel a synthetic manifest as real or
reuse a real run directory.

## Qualitative workflow

The quantitative pipeline never reads or codes open text. After transformation,
an authorized reviewer may create a restricted template:

```powershell
Rscript scripts/run.R qualitative --manifest $transformationManifest
```

Manual reviewers populate the restricted template under
[`qualitative-protocol.md`](qualitative-protocol.md). After each coding or
adjudication round, record a hash-only snapshot without printing text:

```powershell
Rscript scripts/run.R qualitative-snapshot --workspace <restricted-workspace> --snapshot-id <id> --governance-reference <restricted-record-id>
```

Snapshots are audit evidence, not publication authorization.

## Release workflow

The controlled policy currently uses `minimum_cell_count: 5`. The code may
prepare a restricted candidate containing primary structured summaries and a
generated TeX results fragment only after G2 and internal scientific review
have passed; it excludes sensitivity variants, cross-tabs, qualitative
material, timestamps, and respondent-level data.

Before it creates candidate outputs, `release` verifies the full bound
`01-validation.json` → `02-transformation.json` → `03-analysis.json` chain.
Each stage must record the selected clean analysis commit, canonical Git-blob
lockfile, analytical-control fingerprint, controlled metadata, and policy
fingerprint; each predecessor hash and source identity must agree. For a v0.4
candidate, verification and manuscript builds record their own verifier and
builder provenance alongside the frozen analytical controls. This separate
provenance is not an authorization expansion: every restricted action still
requires the exact authorized checkout. A legacy candidate remains tied to its
original strict full-checkout route.

```powershell
Rscript scripts/run.R release --manifest $analysisManifest
```

The command cannot publish. A human reviewer creates a restricted attestation
that binds the candidate manifest, analysis manifest, policy, and exact output
hashes, then a verifier records the check:

```powershell
Rscript scripts/run.R verify-release --candidate-manifest <release-candidate-manifest.json> --approval-id <attestation-id>
```

External delivery is a separate, manually authorized operation. Follow the
[`release checklist`](release-checklist.md) before any move
to a release path or manuscript result source.

## Restricted attested-results manuscript build

After `verify-release` has recorded a current verification for the exact
candidate and byte-bound attestation, build the restricted integration PDF from
a clean, provenance-compatible checkout:

```powershell
$env:TA_WIKI_PDFLATEX = 'C:\path\to\pdflatex.exe' # omit when pdflatex is on PATH
Rscript scripts/run.R manuscript-attested-build `
  --candidate-manifest <restricted-release-candidate-manifest.json> `
  --approval-id <restricted-attestation-id>
```

The command stages `article.tex` with the attested generated-results fragment
only inside the approved restricted root and creates an immutable PDF plus
hash-bound build record under `reports/manuscript-builds/`. For a v0.4
candidate, the record keeps the analytical baseline separate from the
manuscript-source and builder provenance; a later analytical-control change is
a rerun trigger. The tracked placeholder remains unchanged. This is an
integration build, not publication: verified factual declarations, references,
venue requirements, author approval, and a separate delivery decision still
remain necessary.

## Git and handoff checks

Enable the tracked hook templates in each working clone:

```powershell
git config core.hooksPath .githooks
```

Before a private push or final handoff, run the strict scan in the designated
publication repository:

```powershell
Rscript scripts/run.R privacy --strict-history
```

For the final fresh clone, use the stricter read-only verifier as well. It
checks the clean worktree, unreachable-object boundary, strict privacy scan,
hooks, and credential-free `origin`, but cannot verify hosting-service controls:

```powershell
$python = 'C:\path\to\python.exe' # a real Python 3 executable, not a Windows Store alias
& $python scripts/verify_private_handoff.py . --strict-history `
  --require-hooks --require-origin --require-origin-only
```

The earlier development repository's history must never be copied, cloned, or
pushed as part of publication. See the
[`private-repository handoff guide`](private-repository-handoff.md).

## Clean-clone handoff check

Run this check from a newly cloned copy of the verified private repository. It
is the final strict-history and rebuild environment, rather than an accumulated
development workspace. It validates the tracked workflow only; it does not
rerun restricted analysis or authorize a result release.

```powershell
git clone <verified-private-repository-url> ta-wiki-assessment-publication
Set-Location ta-wiki-assessment-publication
git config core.hooksPath .githooks
$env:TA_WIKI_ALLOW_RENV_BOOTSTRAP='1'
Rscript scripts/run.R bootstrap
Rscript scripts/run.R privacy --strict-history
Rscript scripts/run.R test
$python = 'C:\path\to\python.exe' # a real Python 3 executable, not a Windows Store alias
& $python scripts/verify_private_handoff.py . --strict-history `
  --require-hooks --require-origin --require-origin-only
git diff --exit-code
if (git status --porcelain) { throw 'The verification commands changed the working tree.' }
```

If TeX is installed, also run `Rscript scripts/run.R coauthor-brief` and
`Rscript scripts/run.R manuscript-preview`, then inspect the ignored local
PDFs. A final submission build still requires approved generated results and
verified governance wording.
