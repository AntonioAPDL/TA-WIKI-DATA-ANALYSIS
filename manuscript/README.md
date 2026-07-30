# Manuscript sources and local builds

For normal coauthor review and Overleaf editing, use the repository-root
`main.tex` file. That is the canonical Overleaf-facing manuscript source.

The files in this directory are supporting controlled-build and review sources.
They are retained for reproducibility/provenance and for specific local build
commands, but they are not the primary file coauthors should open in Overleaf.

Run this from the repository root before sharing manuscript-facing edits:

```powershell
Rscript scripts/run.R manuscript-check
```

## Controlled-build sources

article.tex contains only evidence-bounded methods, limitations, and declaration
placeholders. generated-results.tex is intentionally nonnumeric until a
disclosure-approved candidate exists.

Use the [manuscript finalization evidence matrix](finalization-evidence-matrix.md)
to prepare the claim-by-claim and declaration-by-declaration record needed for
the final manuscript. The tracked matrix is deliberately blank: complete a copy
only in approved restricted storage, without putting result values, source
locators, approval records, or identities in Git.

Before building a submission-ready manuscript:

1. Complete governance, coauthor, and disclosure decisions in the controlled
   plan.
2. Generate a disclosure-approved result artifact in restricted storage and
   record the exact candidate/attestation lineage.
3. Use the generated-results.tex artifact emitted inside the attested restricted
   release candidate only as a staged restricted-build input. It never replaces
   the tracked repository placeholder; do not type numerical claims into
   article.tex.
4. Confirm setting, recruitment, ethics/governance, CRediT, funding, conflicts,
   acknowledgments, and availability wording against verified records.
5. Document the TeX engine and version, then build from a clean clone. Do not
   substitute a PDF whose provenance cannot be verified.

The finalization sequence and its evidence requirements are detailed in the
[restricted finalization runbook](../docs/restricted-finalization-runbook.md).
The matrix is the manuscript-facing crosswalk; the runbook remains the
controlling operational procedure.

The manuscript remains a structured descriptive departmental survey/evaluation: state
denominators, avoid causal language, do not report an unverified response rate,
and preserve the distinction between internal analysis and disclosure-approved
release artifacts.

## Coauthor review brief

`coauthor-review-brief.tex` is a separate, self-contained, results-free
discussion document for Andrew and Marcela. It summarizes the technical state,
external decisions, and ordered finalization path without making manuscript
claims. Build its ignored local PDF with:

```powershell
$env:TA_WIKI_PDFLATEX = 'C:\path\to\pdflatex.exe' # omit when pdflatex is on PATH
Rscript scripts/run.R coauthor-brief
```

The resulting `coauthor-review-brief.pdf` and sidecar build record are not a
submission-ready manuscript or a disclosure-approved release artifact. See the
[coauthor review guide](../docs/coauthor-review-guide.md) for the reading path.

## Controlled draft preview

For layout and source-build review only, `Rscript scripts/run.R
manuscript-preview` stages the two tracked TeX inputs in a temporary directory
and creates the ignored local artifact `article-preview.pdf`. It also inserts a
preview-only notice into the staged copy during that isolated build. It requires
a local `pdflatex` executable (set `TA_WIKI_PDFLATEX` when it is not on
`PATH`). The preview remains nonnumeric and is not a submission-ready manuscript
or an approved release artifact.

The ignored sidecar `article-preview.build.json` records the current source and
output hashes, TeX version, compile arguments, and the pre-build Git state. The
two TeX inputs must match `HEAD`, so a manuscript-source edit must be committed
before a controlled preview is rebuilt. The record is local reproducibility
evidence, not a release artifact.

An optional `--output manuscript/<name>.pdf` argument changes only the ignored
local preview name and cannot write outside this directory.

## Restricted attested-results integration build

After the restricted candidate has passed manual disclosure review, received a
byte-bound attestation, and passed `verify-release`, the following command can
build a PDF that integrates the exact approved results fragment without copying
that fragment into this repository:

```powershell
Rscript scripts/run.R manuscript-attested-build `
  --candidate-manifest <restricted-release-candidate-manifest.json> `
  --approval-id <restricted-attestation-id>
```

It requires `TA_WIKI_RESTRICTED_ROOT`, uses only an approved restricted
workspace, and writes a PDF plus hash-bound build record under that workspace's
`reports/manuscript-builds/` directory. The tracked
`generated-results.tex` file must remain the nonnumeric placeholder. The command
does not publish, deliver, or make a submission-ready manuscript: verified study
facts, declarations, references, venue requirements, and a separate authorized
delivery decision still remain necessary.
