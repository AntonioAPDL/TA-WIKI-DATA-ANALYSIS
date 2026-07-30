# Manuscript finalization evidence matrix

**Purpose:** use this source-free template to turn the controlled manuscript
draft into a reproducible final manuscript without inserting unreviewed facts,
restricted data, or manually transcribed numerical results.

This tracked copy is intentionally blank. Complete a copy only in the approved
restricted workspace or designated governance system. Do not put completed
aliases, source locators, identities, hashes, result values, quotations, or
approval records in this repository.

## Current boundary

At the current stage, `article.tex` is a controlled, nonnumeric draft and
`generated-results.tex` is a required placeholder. The placeholder remains in
Git even after a restricted result build: an exact, disclosure-approved
replacement is staged only inside approved restricted storage by
`manuscript-attested-build`. A locally built `article-preview.pdf` is useful for
layout review, but is neither a result release nor a submission-ready PDF.

The [restricted finalization runbook](../docs/restricted-finalization-runbook.md)
is the controlling operational sequence. This matrix is the manuscript-facing
crosswalk used after the required evidence exists.

## Section-by-section crosswalk

| Manuscript component | What can remain in the controlled draft now | Evidence required before final wording or inclusion | Required review boundary |
|---|---|---|---|
| Title, authors, affiliations, and target venue | A working title and existing author placeholders may support internal discussion. | Author consensus on title, order, affiliations, corresponding-author details, and target journal or format. | All authors; venue requirements checked against the selected venue. |
| Abstract | Descriptive purpose and noncausal scope may be drafted without findings. | Approved result artifact for every numerical or empirical statement; verified context for every factual statement. | Scientific review, disclosure approval where applicable, and author review. |
| Study context and purpose | The implementation-specific, descriptive purpose and explicit nonclaims. | Verified setting and implementation facts. | Study-context review; no claim beyond verified records. |
| Design, governance, and ethics | General description of the restricted workflow and its limits. | Exact approved or exempt-determination wording and any required governance statement from the authoritative institutional record. | Responsible institutional/study authority; do not infer wording from email or a draft instrument. |
| Eligibility, recruitment, and participation | The statement that a response rate is not reported without a verified denominator. | Verified eligibility, recruitment, administration, and invitation-denominator records. | Study-context review; omit a response rate if its denominator remains unverified. |
| Instrument and measures | High-level domains and the distinction between structured and open-text material. | Frozen-source and controlled-metadata confirmation of analyzed wording, options, and routing. | Restricted source/context review. |
| Data handling and analysis | The description of restricted storage, separate raffle handling, item-specific denominators, no imputation, and descriptive scope. | Current validation-to-transformation-to-analysis lineage and any approved update to the analysis specification. | Restricted internal review; keep the manuscript aligned with the manifest-bound specification. |
| Quantitative results | The section heading and the generated-results import only. | Exact disclosure-approved generated TeX fragment, candidate manifest, attestation, and verification record. | Disclosure review and byte-bound attestation; never type counts, percentages, or tables into `article.tex`. |
| Qualitative material | A statement that no qualitative findings are reported until the approved protocol is completed. | Formal scope decision plus, if included, restricted coding, adjudication, and qualitative disclosure-review evidence. | Study/qualitative review; otherwise defer the material without themes, paraphrases, or quotations. |
| Discussion and limitations | Context-specific, noncausal framing; small-sample, voluntary-participation, and disclosure limitations when verified by the final record. | Every interpretation linked to an approved result or verified context record. | Scientific and author review; avoid population, predictive, or causal claims. |
| Tables, figures, supplement, and appendices | Captions or placeholders without findings may be planned. | Exact disclosure-approved aggregate artifact(s), including any suppression treatment and required explanatory notes. | Disclosure review; do not reuse internal tables or screenshots. |
| Data and code availability | A distinction between shareable code/metadata and restricted survey material. | Final repository/archive location and approved availability wording. | Study authority and repository maintainer. |
| Author declarations | Nothing beyond controlled placeholders. | Verified CRediT roles, funding, conflicts, acknowledgments, consent/ethics wording, and any venue-specific declarations. | All authors and the relevant authority. |
| References and venue formatting | Structural placeholders only. | Verified bibliographic records and the selected venue's current instructions/template. | Manuscript lead and author review. |
| Final PDF and delivery | Local controlled preview for layout only. | A clean-clone build record with source hashes, approved-fragment hash, TeX engine/version, PDF hash, author approval, and a separately authorized delivery decision. | Private handoff/repository review and delivery authority. |

## Claim and evidence record

Create one row for every factual, numerical, or qualitative statement that is
added or materially revised. Keep the completed version restricted. The rows
may point to an approved aggregate artifact or a verified context record, but
never reproduce restricted content.

| Claim ID | Draft location | Statement type | Evidence alias | Denominator or boundary reviewed | Disclosure status | Scientific/author review | Final status |
|---|---|---|---|---|---|---|---|
| `<ID>` | `<section / table / figure>` | `<contextual / structured / qualitative / declaration>` | `<restricted or verified-record alias>` | `<applicable limitation or denominator>` | `<not needed / pending / approved>` | `<pending / approved>` | `<omit / retain / revise>` |

For a structured result, the evidence alias must identify the exact approved
artifact and the associated candidate/attestation lineage. For a contextual
statement, it must identify the verified record that supports the wording. A
claim without a completed row stays out of the final manuscript.

## Final-build record

Record the following in the approved restricted handoff record after the final
build. This list documents reproducibility without copying sensitive material
into Git.

| Field | Record in the restricted handoff |
|---|---|
| Controlled code baseline | `<approved Git commit or tag>` |
| Manuscript source identity | `<article source hash / tracked revision>` |
| Results identity | `<approved fragment, candidate, and attestation aliases/hashes>` |
| Context and declaration review | `<verified-record aliases and review status>` |
| Build environment | `<TeX engine, version, command, and package/template version>` |
| Output identity | `<PDF filename, hash, and build-record alias>` |
| Review and delivery | `<author-approval and separately authorized delivery-decision aliases>` |

## Ordered finalization use

1. Copy this template into the approved restricted workspace and record the
   evidence needed for each planned manuscript section.
2. Complete the selected v0.4 restricted lineage and scientific review before
   drafting empirical findings. Resolve or omit any claim whose evidence is
   incomplete.
3. After disclosure review, use `Rscript scripts/run.R manuscript-attested-build`
   to integrate only the exact approved results fragment in restricted storage.
4. Complete author/declaration/reference/venue review, then build and inspect a
   clean-clone PDF. Record its provenance in the final-build record.
5. Deliver only the exact approved files through the separately authorized
   delivery process. A successful build does not itself authorize circulation or
   submission.

## Pre-delivery check

- [ ] Every claim, table, figure, and declaration has a completed crosswalk row.
- [ ] Numerical findings derive only from the approved generated fragment.
- [ ] Qualitative material is either formally deferred or has completed its
  restricted coding and disclosure review.
- [ ] Context, governance, and response-rate wording have verified sources.
- [ ] The final PDF rebuilt from a clean clone and its provenance is recorded.
- [ ] All authors completed the agreed review and the delivery decision names
  the exact approved files and destination.
