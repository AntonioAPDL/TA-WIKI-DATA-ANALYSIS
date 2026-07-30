# Restricted qualitative protocol

**Status:** workspace template and hash-only snapshot mechanism implemented;
coding and disclosure review pending.

**Applies to:** open-text survey fields stored only in the approved restricted
root.

## Boundary

Open text is not read by the quantitative pipeline, is never committed to this
repository, and is not automatically coded. The default releasable form is an
aggregate theme. Direct quotations, distinctive paraphrases, respondent-level
examples, and reviewer identities are blocked unless separately approved in a
restricted disclosure record.

## Unit, process, and audit trail

1. Use one de-identified response fragment as the coding unit. Keep source text
   and any mapping to a record identifier only in the restricted workspace.
2. Create a codebook with definitions, inclusion/exclusion criteria, and a
   non-identifying example reference. Record code changes by version.
3. Record each coding decision in the restricted coding ledger. A second
   reviewer or documented adjudication process is required before a theme is
   described as reviewed.
4. Produce a theme audit with supporting-unit counts, limitations, and a
   disclosure disposition. Counts alone do not authorize release.
5. Before sharing, complete qualitative disclosure review for linkage,
   distinctive-language, small-group, quote, and paraphrase risk.

## Reproducibility

Run `Rscript scripts/run.R qualitative --manifest <transformation-manifest>`
inside the approved restricted root to create empty codebook, ledger, theme, and
disclosure-review templates bound to the quantitative transformation manifest.
This command does not access open-text values and does not perform qualitative
analysis.

After each authorized coding or adjudication round, record a byte-hash snapshot
with `scripts/run.R qualitative-snapshot`. The snapshot contains no text; it
binds the current restricted workspace to the controlled protocol and lineage.
It is audit evidence, not release authorization.
