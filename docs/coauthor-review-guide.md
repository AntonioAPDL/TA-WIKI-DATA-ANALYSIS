# Coauthor review guide

**Purpose:** provide Andrew, Marcela, and the study team with a concise,
privacy-safe entry point for reviewing the current v0.4 author-review package
and finishing manuscript decisions.

The authoritative source remains restricted and live. The current v0.4
restricted lineage, candidate, attestation, release verification, and
results-integrated manuscript build exist in approved restricted storage. A
historic candidate also remains restricted audit context only. This guide does
not provide access to raw source material, row-level derivatives, internal
tables, open text, timestamps, or candidate artifacts.

## Read this first

The current presentation artifact is the local author-review manuscript PDF
generated from the verified v0.4 candidate. It is the best available article
draft for coauthor review, but it is not submission-ready until author facts,
declarations, venue requirements, and coauthor approval are complete.

The locally built `manuscript/coauthor-review-brief.pdf` remains a
source-safe technical companion. It summarizes status, evidence boundaries,
decisions, and the path to completion, but it contains no numerical findings.

The controlled manuscript preview is a separate layout review artifact. It is
also nonnumeric and should not be described as a final manuscript.

## What is safe to review or circulate now

- The local author-review manuscript PDF generated from the verified candidate,
  within the authorized coauthor-review boundary.
- This guide and the [coauthor review brief](../manuscript/coauthor-review-brief.tex).
- The [project roadmap](project-roadmap.md), [analysis specification](analysis-specification.md),
  [data-governance boundary](data-governance.md), and
  [reproducibility guide](reproducibility-guide.md).
- Controlled metadata, synthetic fixtures, tests, and the public-safe workflow
  documentation.

Do not circulate restricted source material, timestamps, respondent-level
derivatives, open text, internal tables, governance records, release candidates,
attestations, or unreviewed numerical findings.

## What coauthors are being asked to decide

| Topic | Decision | Evidence available for review now | Outcome record |
|---|---|---|---|
| Scientific scope | Confirm descriptive claim boundaries, denominators, missingness limitations, and sensitivity treatment for the current v0.4 outputs. | Author-review manuscript, analysis specification, and controlled metadata; exact internal outputs remain restricted. | Restricted scientific-review record. |
| Qualitative scope | Selected: structured analysis only; keep qualitative findings out of this manuscript. | Qualitative protocol. | Restricted scope record. |
| Disclosure readiness | Confirm that the present author-review package remains within the approved structured-only, disclosure-controlled scope. | Release checklist, policy, and author-review manuscript. | Restricted governance/disclosure record. |
| Manuscript facts | Identify verified sources for setting, recruitment, declarations, authorship, funding/COI, and venue requirements. | Manuscript structure and finalization runbook. | Manuscript factual-record checklist. |
| Handoff | Select private hosting, reviewers, access roles, and branch protection. | Private-repository handoff guide. | Restricted/project handoff record. |

## What coauthors do not need to do

- Inspect raw survey responses or open text outside the approved restricted
  environment.
- Reproduce the restricted analysis on a personal machine or in this repository.
- Treat the historic candidate as a v0.4 result input or any candidate as
  approved for broader sharing beyond the recorded author-review decision.
- Infer missing governance, recruitment, or denominator facts from a draft
  questionnaire or from repository documentation.

## Suggested review meeting

1. Confirm the study's descriptive scope and explicit nonclaims.
2. Confirm the v0.4 analysis rules now; review exact internal outputs for
   missingness, denominators, sensitivity, and exploratory-analysis boundaries
   only after its approved restricted run.
3. Confirm the selected deferral of qualitative findings.
4. After scientific review, review the exact candidate and assign/confirm the
   disclosure, attestation, manuscript-facts, and private-handoff
   responsibilities.
5. Confirm the finalization route in the
   [new-repo transition plan](new-repo-transition-plan.md) and
   [restricted finalization runbook](restricted-finalization-runbook.md).

## Compact glossary

| Term | Meaning |
|---|---|
| v0.4 analysis baseline | The clean tracked code, metadata, policy, lockfile, and compatible source freeze selected for the current restricted lineage. |
| Current v0.4 candidate | The restricted, disclosure-controlled output bundle from the v0.4 baseline; it is used only through exact review, attestation, verification, and delivery records. |
| Manuscript-build provenance | The tracked manuscript source and builder details recorded for a restricted build; it does not authorize a later checkout to handle restricted artifacts. |
| Historic restricted evidence | An earlier restricted run and candidate retained for context but not used by the v0.4 result path. |
| Restricted review | Authorized inspection of internal material inside approved storage. |
| Disclosure-approved sharing | Sharing an exact aggregate artifact after candidate review, attestation, and a delivery decision. |
| v0.4 lineage | The bound validation, transformation, and analysis manifest chain produced from the selected v0.4 baseline. |
| Controlled preview | A locally built, nonnumeric layout artifact; not a submission or release artifact. |

## Reading order after the meeting

1. [Restricted finalization runbook](restricted-finalization-runbook.md)
2. [Open decisions](open-decisions.md)
3. [Completion evidence tracker template](evidence-tracker-template.md)
4. [Release checklist](release-checklist.md)
5. [Private-repository handoff](private-repository-handoff.md)
