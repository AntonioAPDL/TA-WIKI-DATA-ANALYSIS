# Restricted finalization runbook

**Purpose:** prepare and execute the remaining governance, restricted-analysis,
review, release, manuscript, and handoff work without placing sensitive
evidence in Git. This tracked document is a blank operational template;
completed records belong in approved restricted storage or the designated
project-governance system.

## Operating rules

1. Use the preflight and G0b preparation steps only to establish a candidate
   environment. Do not perform any restricted-data, result, or delivery step
   until the relevant authority has authorized the environment and role.
2. Record role names, approvals, source locators, source hashes, restricted
   paths, response material, and result values only in approved restricted
   records.
3. Preserve superseded evidence as historic rather than overwriting it.
4. Do not bypass a failed gate by copying an older run, editing a manifest, or
   transcribing numbers into the manuscript.
5. The only release-eligible analysis is a current full
validation-to-transformation-to-analysis chain whose manifests match the
current code, canonical lockfile, controlled metadata, policy, run identity,
and source provenance.

## Current source state

The authoritative live survey source is available to the authorized study team.
This resolves the source-discovery question but does not create an approved
analysis input. The live source is mutable and restricted because timestamps
and open text remain present. Do not request or reconstruct a second survey
file from the raffle archive; preserve raffle/contact records as separate
administrative material.

For v0.4, first determine whether the historic immutable freeze is compatible
with the selected authorization and baseline. Reuse it only after that review;
otherwise export the live source directly into the approved restricted root and
run intake. Do not stage an export in Downloads, the repository, email, or a
synced local folder.

## G0b: Governance authorization

| Confirm before a real-data command | Restricted record to create | Acceptance check |
|---|---|---|
| Permitted analysis and sharing scope | Governance authorization record | Scope distinguishes internal review, coauthor sharing, and public delivery. |
| Access roles and approved environment | Access/security record | Authorized analyst and reviewer roles are designated. |
| Storage, encryption, retention, backup, and incident process | Security/retention record | Controls are confirmed by the responsible authority. |
| Survey and raffle/contact separation | Collection-boundary record | Manuscript wording has a verified source. |
| Disclosure and delivery authority | Role/approval record | Reviewer and delivery authority are identified. |

**Acceptance:** authorization is recorded. The technical restricted-root
preflight is necessary but does not substitute for this step.

Before the first restricted command, create the paired, human-signed operating
authorization and its machine-readable record under the approved restricted
root. It must bind the selected clean Git commit, current preflight fingerprint,
permitted actions/data categories, and all listed controls. Use the exact
format in [restricted-operation authorization](restricted-operation-authorization.md).
The record is selected only for the authorized session; do not place its ID or
the restricted-root path in Git or command history.

## G1a: Source availability and handoff record

| Task | Record | Acceptance check |
|---|---|---|
| Record the confirmed source-access route by a safe local alias | Source-access/handoff record | The team can identify the authoritative source in approved storage without putting a locator, revision, or response material in Git. |
| Preserve the live source unchanged and retain survey/raffle separation | Collection-boundary record | No raffle/contact material is used to reconstruct, clean, or analyze survey responses. |

Store the source locator and revision in the required restricted
`source-access-context.json` record after the `intake` authorization is in
place. Intake reads that record; never supply those values in an email,
repository file, or command-line argument.

**Acceptance:** source availability is documented without treating the live
spreadsheet as a frozen or de-identified analysis file.

## G1b: Immutable source freeze and schema compatibility

| Task | Record | Acceptance check |
|---|---|---|
| Decide whether to reuse or create a source freeze | Source-freeze review | Reuse only a current-format freeze whose copied workbook and restricted provenance prove the intended authoritative revision; otherwise create a new freeze. |
| Export the closed live source directly to the approved restricted root | Immutable source export | Original bytes are preserved outside Git and Downloads until intake has copied and hash-checked them into the freeze. |
| Record source revision/provenance and run intake | Source-freeze record | The locator, revision, copied-workbook hash, and provenance remain only in restricted storage. |
| Compare the intake candidate header against the controlled header contract | Schema-compatibility record | Any discrepancy stops the run for controlled review; a freeze alone is not run-ready. |

**Acceptance:** a current hash-bound source freeze exists, its copied workbook
and provenance pass integrity checks, and it has passed exact schema
compatibility review. A legacy provenance record that lacks the copied workbook
cannot be used for a current validation run.

## G1c: Study context and claim boundaries

| Task | Record | Acceptance check |
|---|---|---|
| Verify live routing and administration | Context review | Structural-skip treatment remains evidence-based. |
| Verify recruitment, eligibility, and invitation denominator | Context review | A response rate is reported only if the denominator is verified. |
| Record unresolved limitations | Study-context memo | Manuscript language reflects only verified facts. |

**Acceptance:** the claim inventory distinguishes verified context from
limitations. Missing context blocks only the affected claim, not the restricted
descriptive lineage.

## G2: v0.4 restricted structured lineage

Complete G4a before this stage so the policy fingerprint is stable. Then run the
exact commands in the [reproducibility guide](reproducibility-guide.md)
inside approved restricted storage:

```text
intake/freeze as needed -> validate -> transform -> analyze
```

Retain the restricted `01-validation.json`, `02-transformation.json`, and
`03-analysis.json` manifests, plus internal audit outputs. Confirm that each
stage was generated by the current clean commit, canonical Git-blob lockfile,
controlled metadata, policy, run identity, and source provenance. Do not copy
the manifests or internal outputs into Git.

**Acceptance:** the selected v0.4 analysis manifest is a hash-bound descendant
of its v0.4 transformation and validation manifests and has passed internal
audit review.

## G3a: Structured scientific review

| Review item | Required decision/evidence |
|---|---|
| Structured claims | Claim inventory links each proposed claim to a restricted artifact, denominator, and limitation. |
| Data quality | Coauthors review cohort flow, missingness, anomalies, and transformation audit. |
| Contribution uncertainty | Coauthors record the disposition of direct contribution results, deterministic missing-response range, and any internal reason-informed diagnostic. |
| Exploratory analysis | Cross-tabs remain labelled exploratory and are reviewed separately for linkage risk. |
| Exploratory questions | Relationships, prediction, and outreach effectiveness remain exploratory descriptive associations, not causal or predictive claims. |

**Acceptance:** structured scientific claim boundaries are approved before a
disclosure candidate is generated.

## G3b: Qualitative scope decision

| Review item | Required decision/evidence |
|---|---|
| Qualitative scope | Record `included` with a manual coding/adjudication protocol, or `deferred` with no themes, paraphrases, quotations, or qualitative interpretation claims. |
| Disclosure feasibility | If the approved threshold suppresses the intended numeric artifact, record a different approved scope or stop external delivery; do not weaken the threshold. |

**Acceptance:** the qualitative boundary is explicit before candidate review.

## G4a: Disclosure readiness that can be prepared now

| Task | Record | Acceptance check |
|---|---|---|
| Approve integer minimum cell threshold | Controlled policy change and restricted decision record | Policy is reviewed by the designated authority before G2; later policy changes require a new lineage. |
| Designate disclosure reviewer and delivery authority | Restricted role record | Manual review and external delivery are separate responsibilities. |
| Prepare candidate-review worksheet | Restricted disclosure worksheet | It covers direct, indirect, linkage, differencing, rare-combination, and cross-artifact risk. |

## G4b: Candidate, attestation, and delivery

After G2, G3a, and G3b are complete, generate the restricted candidate from the
current `03-analysis.json`, complete manual review, create the byte-bound
attestation, and run `verify-release`. Then record a separate delivery decision
that names the exact approved files and destination. If suppression leaves no
artifact that supports the intended paper, record the feasibility outcome rather
than weakening the approved threshold.

**Acceptance:** automated controls, manual review, attestation, and delivery
authorization all bind the same candidate bytes.

## G5: Manuscript facts and final build

Before replacing the nonnumeric results placeholder, verify and record:

| Fact group | Evidence required |
|---|---|
| Results | Disclosure-approved generated TeX fragment; no manual numerical entry. |
| Study context | Setting, recruitment, eligibility, administration, and invitation-denominator wording. |
| Governance | Ethics/approval/exemption wording from verified institutional records. |
| Authorship and declarations | Author order, affiliations, CRediT, funding, conflicts, acknowledgments, and availability statement. |
| Scholarship and venue | Verified reference list, target venue/template, and any required reporting checklist. |
| Build | Final TeX/PDF record with source hashes, approved fragment hash, TeX engine/version, Git commit/tag, and output hash. |

**Acceptance:** every factual, numerical, and qualitative statement has a
verified evidence source and the final PDF rebuilds from a clean clone.

## G6a: Private hosting readiness that can be prepared now

Select the approved private host, visibility, owner, least-privilege roles,
reviewers, branch protections, and retention/archive plan. Record the remote
URL and named access roles outside Git.

## G6b: Final handoff and preservation

From a fresh clone of the verified private remote, run the strict-history scan,
locked-environment bootstrap, full test suite, final PDF build, and clean-tree
check. Tag the approved commit and retain the final handoff record and restricted
evidence under the verified retention plan.

**Acceptance:** the private package rebuilds independently and no restricted
material enters version control.
