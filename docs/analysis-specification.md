# Analysis specification

**Status:** Version 0.4 controls the current restricted structured lineage. The
v0.4 validation, transformation, internal quantitative analysis, release
candidate, attestation, verification, and ignored full internal analysis package
have been generated from the current baseline. The earlier lineage is retained
only as a restricted audit reference; it cannot support a candidate from this
revised analytical baseline. Full internal outputs remain ignored/restricted and
are not public-release artifacts.

**Version:** 0.4

**Applies to:** the frozen authoritative TA Wiki survey source only.

**Current-version note:** Version 0.4 makes one coherent methodological update:
it minimizes restricted derivatives, uses the direct contribution response as
the primary treatment, records the former inference only as a sensitivity, and
specifies the internal exploratory pairs. It also records an explicit
analytical-control fingerprint. The current lineage has been run; any material
change to source, controlled metadata, policy, analytical code, or analytical
outputs requires a rerun.

## Purpose

This post-collection specification fixes the analytical scope for the
frozen-source transformation and analysis. It is not preregistration. A material
change after source freeze requires a decision record, an updated version, and a
rerun of affected outputs.

## Research objective

Describe, within this departmental implementation context, survey records'
awareness of, use of, prior contribution to, contribution-process perceptions
about, and perceived value of a collaboratively maintained TA Wiki, together
with structured preferences for a useful departmental teaching resource.

## Analytical cohort

The cohort is every frozen-export record that passes the approved consent and
eligibility rules. The restricted cohort-flow report distinguishes exported,
valid-consent, eligible, and analytic-cohort records. Item outputs also report
valid, missing, invalid, inferred, and structural-skip counts as applicable.

No response rate will be reported unless a verified invitation denominator and
definition are available in the source-freeze record.

## Primary descriptive outputs

For each approved structured item, report internally:

- eligible cohort N;
- item applicability, valid-response, missing-response, invalid-response, and
  structural-skip N where applicable;
- count and percentage with an explicit denominator;
- category order from the controlled codebook rather than alphabetical or
  observed-frequency order.

Primary domains are background/teaching context, resource ecosystem, Wiki
awareness/use, contribution/barriers, GitHub-related attitudes, editathon
experience, and perceived value/maintenance.

## Missingness, invalidity, and sensitivity

- Preserve source cells unchanged in the immutable restricted source freeze.
  Validation writes only a cohort ledger (row identity and cohort flags), and
  transformation re-reads the bound freeze in memory to select the structured
  fields required for analysis.
- The frozen export does not contain independently verifiable branch/routing
  metadata. For v0.4, blank structured responses are ordinary nonresponse; no
  structural skips are inferred without verified routing metadata. New verified
  routing evidence requires a controlled metadata update and new run.
- Do not impute missing values.
- Incompatible selections in a single-choice field are invalid for that item's
  primary denominator.
- The direct contribution response is the primary treatment. A missing direct
  response remains missing in the primary summary. The principal sensitivity is
  the extreme-case deterministic full-cohort missing-response range produced by
  assigning all missing direct responses to No for the lower bound and Yes for
  the upper bound. A secondary reason-informed diagnostic records a conditional
  No inference only when the reason checkbox parses as valid; it is internal and
  routing-dependent and is not main-manuscript evidence.
- The conditional non-contribution-reason item is retained for internal quality
  and sensitivity work but is blocked from the candidate release universe
  because routing cannot be verified from the frozen export. The distinction is:
  source applicability is unknown without live display logic; an
  analysis-eligible parent-confirmed subset requires an observed direct No
  response; and the reason-informed scenario is a separate internal sensitivity,
  not a primary contribution estimate.
- Checkbox parsing uses exact canonical tokens. An unmatched remainder remains
  restricted and is excluded from structured release data.
- Every rule application and unresolved disposition appears in the restricted
  transformation audit.

## Exploratory analysis

The following limited descriptive cross-tabs may be generated after primary
tables. They are not causal, inferential, or population-generalizable, have no
p-values or model-based inference, and remain internal unless separately
reviewed for disclosure risk. Each output records eligible, applicable, valid,
pairwise-complete, and excluded counts.

| Pair ID | Row item | Column item | Purpose |
|---|---|---|---|
| EXP-001 | Reported Git/GitHub comfort | Reported GitHub-hosting effect on willingness to contribute | Describe the joint distribution of the two reports. |
| EXP-002 | Reported interest in developing teaching skills | Reported GitHub-hosting effect on willingness to contribute | Describe the joint distribution of the two reports. |
| EXP-003 | Graduate-program year | Reported prior TA Wiki visitation | Describe the joint distribution of the two reports. |
| EXP-004 | TA quarters in the department | Directly reported TA Wiki contribution | Describe the joint distribution of the two reports. |

## Qualitative boundary

Open text is restricted and is not read by the quantitative pipeline. The
workspace template, coding ledger, adjudication process, theme audit, and
qualitative disclosure review are documented in
[`qualitative-protocol.md`](qualitative-protocol.md). No coding or synthesis has
yet been represented as complete.

## Artifact and claim inventory

| ID | Artifact | Input domains | Status | Release condition |
|---|---|---|---|---|
| T1 | Cohort flow and item completeness | Cohort and missingness | current v0.4 internal output generated | Internal full-analysis report; separate disclosure review for external release |
| T2 | Awareness and use | Wiki awareness/use | current v0.4 internal output generated | Internal full-analysis report; separate disclosure review for external release |
| T3 | Contribution and GitHub attitudes | Contribution and GitHub | current v0.4 internal output generated | Internal full-analysis report; separate disclosure review for external release |
| T4 | Editathon and perceived value | Editathon and perceived value | current v0.4 internal output generated; perceived-value fragment release-approved | Internal full-analysis report; only approved fragment in release manuscript |
| T5 | Contribution uncertainty | Direct status plus extreme-case deterministic missing-response range and secondary reason-informed diagnostic | current v0.4 internal output generated, internal only | Direct item and deterministic range may be used in the internal manuscript; diagnostic remains supplement/internal only |
| T6 | Conditional noncontribution-reason summaries | Valid direct No response with parsed reason | current v0.4 internal output generated, internal only | Blocked from candidate release pending independently verifiable routing evidence |
| E1 | Exploratory structured cross-tabs and completeness ledger | Explicit controlled pairs | current v0.4 internal output generated, internal only | Separate linkage review |
| Q1 | Manual qualitative workspace | Restricted open text | template available; no coding or synthesis represented as complete | Qualitative review before quotation, paraphrase, or external release |

[`results-inventory.csv`](results-inventory.csv) is the controlled mapping of artifact status,
source domain, lineage status, denominator rule, and future release artifact.

## Explicit nonclaims

The study will not claim that the Wiki, GitHub hosting, editathon participation,
or another measured factor caused an outcome. It will not extrapolate beyond the
implementation context or calculate a response rate without a verified
denominator.
