# TA Wiki assessment: completion plan and coauthor tracker

**Document status:** controlled, coauthor-facing implementation plan

**Version:** 1.3

**Last reviewed:** 2026-07-27

## Purpose and control boundary

This is the canonical plan for completing the private, reproducible,
disclosure-controlled structured descriptive survey/evaluation. It records current status,
dependencies, roles, evidence, and decision points without including respondent
material, restricted paths, source hashes, approval identities, or internal
results. It is intended to let a coauthor determine what is complete, what is
historic only, and exactly what evidence is needed next.

Use the ignored companion tracker in `reports/internal/` only for local
execution coordination. Neither tracker substitutes for institutional
governance records, manual qualitative review, disclosure approval, or a
delivery authorization.

For a short coauthor-facing entry point, start with the
[coauthor review guide](coauthor-review-guide.md). The
[restricted finalization runbook](restricted-finalization-runbook.md) is the
safe operational template for the authorized team; it deliberately does not
contain restricted records or results.

## Status key and sharing boundary

| Status | Meaning |
|---|---|
| Complete - current | Implemented or verified for the current controlled baseline. |
| Complete - historic; refresh required | A real restricted activity occurred, but its lineage cannot support the current release. |
| Ready | The tracked workflow and inputs are prepared; no external decision is missing for this item. |
| Partly ready | Preparatory work is complete, but a named gate still prevents final completion. |
| Awaiting external decision | Requires evidence or authority that the repository cannot create. |
| Blocked by dependency | Cannot start until the named preceding stage is complete. |
| Not started | No approved work has begun. |
| Not applicable - recorded | A team decision formally removes the item from this manuscript. |

The word "sharing" has three different meanings in this plan:

1. **Authorized restricted review**: approved people inspect restricted outputs
   inside the approved environment.
2. **Disclosure-approved coauthor sharing**: exact reviewed aggregate artifacts
   are shared with the authorized coauthor group after candidate attestation and
   a delivery decision.
3. **External/public delivery**: an approved artifact is used in a manuscript,
   supplement, presentation, or other public destination.

Only the second and third activities require a release candidate, manual
disclosure review, byte-bound attestation, and separate delivery decision.

## Current baseline

The tracked repository has a complete technical workflow: restricted intake,
validation, transformation, structured internal analysis, qualitative workspace
setup, disclosure-controlled candidate generation, attestation verification,
privacy scanning, synthetic tests, and a controlled manuscript preview. The
release scripts now reject a candidate unless the complete validation,
transformation, and analysis manifest chain records the current clean Git
commit, canonical lockfile, controlled metadata, and release-policy
fingerprint. This prevents an older or mixed-version run from silently becoming
release-eligible.

A historic restricted structured lineage and candidate exist in approved
restricted storage as audit context only. The current release input is the
separate v0.4 lineage executed from the selected clean baseline. Its validation,
transformation, structured analysis, release candidate, manual attestation,
independent verification, and results-integrated manuscript build completed in
restricted storage. Values, source provenance, manifests, candidate files,
verification records, timestamps, and open text remain restricted.

The v0.4 tracked baseline minimizes restricted derivatives, makes the
contribution sensitivity explicit and internal-only, blocks an ambiguously
routed conditional item from candidate release, and records analytical-control
fingerprints. Separate manuscript-build provenance improves traceability. A new
restricted run remains necessary after any change to controlled code, metadata,
lockfile, source, policy, or analytical output.

The official exempt determination for the approved study activity and the core
collection boundary have also been verified from institutional correspondence.
This supports the survey-only scope, general recruitment boundary, eligibility
screening, and separate raffle/contact process. It does not itself establish an
approved data location, encryption, retention, disclosure policy, or delivery
authorization; detailed evidence remains in restricted governance records.

A current restricted-root preflight remains necessary but deliberately
insufficient for execution. Restricted commands require an operating
authorization that binds the exact clean Git baseline and preflight
fingerprint. Source locator and revision identifiers are kept in the paired
restricted source-access context, never command-line arguments. See
[restricted-operation authorization](restricted-operation-authorization.md).

### Current restricted source state

The authoritative source was frozen and processed through the current v0.4
restricted lineage. The exact source provenance and revision remain only in the
restricted record system. The raffle archive and its transparency materials are
separate administrative records and are never analysis input.

Unprovenanced legacy derivatives are excluded from all current routes. The live
source remains mutable and restricted because it includes timestamps and open
text. Its locator, revision, export, response values, and provenance stay only
in approved restricted storage. No mutable export, legacy derivative, or raffle
artifact may substitute for the reviewed immutable freeze.

## Accountable roles

| Role | Accountable for |
|---|---|
| Study lead / PI | governance scope, scientific decisions, disclosure and delivery authority. |
| Governance or data-security authority | permitted access, storage, retention, backup, incident, and sharing controls. |
| Restricted-data analyst | source freeze, approved-environment execution, and restricted lineage evidence. |
| Methods lead | controlled specification, transformation, denominator, and sensitivity review. |
| Qualitative lead and reviewers | scope decision, coding, adjudication, and qualitative disclosure review. |
| Disclosure reviewer | candidate linkage review and restricted attestation. |
| Manuscript lead | claim crosswalk, manuscript build, and coauthor revision workflow. |
| Repository maintainer | source baseline, tests, private remote, clean-clone verification, and preservation. |

Roles are deliberately not named here. Named approvals and access records belong
only in the approved restricted governance record.

## Critical path

```text
G1a source record -> G0b governance -> G4a policy/roles -> G0a baseline
                                                            |
                                                         G1b freeze
                                                            |
                                                       G2 lineage -> G3a review
                                                                         |
                                          G3b scope decision --------------+
                                                                         |
                                      G4b candidate/review/attestation/delivery
                                                                         |
                                            G5 manuscript -> G6b private handoff

Parallel after G0b: G1c study-context evidence and G3b qualitative scope.
Parallel after G0a where authorized: G6a private-hosting preparation.
```

Governance preparation, private-remote selection, manuscript non-result prose,
and qualitative setup may proceed in parallel. They do not bypass the critical
path for restricted results or public claims.

## Completion tracker

| ID | Work item | Status | Accountable role | Entry inputs | Deliverable and public-safe evidence | Verification / next action | Depends on |
|---|---|---|---|---|---|---|---|
| G0a | v0.4 technical baseline | Complete - current | Repository maintainer | selected clean code-and-policy baseline | clean worktree, strict-history privacy scan, full suite, clean-clone evidence, and results-free PDF builds | preserve this baseline; rerun checks after source edits | none |
| G0b | Institutional governance and operating boundary | Complete - current | Study lead / PI; governance authority | verified study determination, collection boundary, and selected v0.4 commit | restricted operating record and paired artifact | retain restricted authorization evidence outside Git | G0a |
| G1a | Source availability and handoff record | Complete - current | Restricted-data analyst | authorized source access | restricted source-access context and handoff record | preserve source provenance outside Git | G0b |
| G1b | Immutable source freeze and schema compatibility | Complete - current | Restricted-data analyst | reviewed immutable freeze, G0b authorization, and G1a record | immutable freeze, provenance, and exact schema-validation record | use this freeze only for the current lineage; rerun on any source change | G0a, G0b, G1a |
| G1c | Study-context and claim-boundary evidence | Partly ready | Study lead; restricted-data analyst | verified collection boundary, G0b authorization, and authoritative context records | restricted context review and verified method statements | confirm exact routing, administration, recruitment, and invitation-denominator evidence; record limitations that remain unresolved | G0b |
| G2 | v0.4 restricted structured lineage | Complete - current | Restricted-data analyst; methods lead | compatible freeze, policy, and selected baseline | restricted validation, transformation, and analysis manifests | preserve the completed lineage unchanged | G1b, G4a |
| G3a | Structured scientific review | Complete - current | Methods lead; coauthors | G2 internal outputs | structured claim inventory and sensitivity disposition | coauthors should review the narrow released claim boundary before submission | G2 |
| G3b | Qualitative scope decision | Not applicable - recorded | Study lead / PI; qualitative lead | authorized structured-only scope | recorded defer decision | qualitative findings remain deferred; do not use themes, paraphrases, quotations, or qualitative interpretation claims | G0b |
| G4a | Disclosure readiness | Complete - current | Study lead / PI; disclosure reviewer | configured policy and v0.4 authorization | configured threshold of five and candidate-review controls | any policy-byte change requires a new lineage | G0b |
| G4b | Disclosure-safe result package and delivery decision | Complete - current | Disclosure reviewer; study lead / PI; restricted-data analyst | G2 lineage, G3a review, G3b scope decision, and G4a readiness | candidate manifest, controlled output bundle, attestation, verification, and author-review delivery record | preserve restricted evidence outside Git; do not broaden delivery without a new decision | G2, G3a, G3b, G4a |
| G5 | Manuscript and supplement | Partly ready | Manuscript lead; all authors | G4b approved artifacts | claim crosswalk, TeX source, restricted PDF build record, and author-review PDF | complete author facts, declarations, coauthor review, and venue formatting before submission | G4b |
| G6a | Private-hosting readiness | Partly ready | Repository maintainer; study lead; governance/IT | G0a current code baseline | technical remote, protected-workflow configuration, CI, and fresh-clone evidence are in place; access model, reviewer roles, and retention plan remain to be recorded | record and confirm the human-governance hosting controls without pushing restricted material | G0a |
| G6b | Private handoff and preservation | Partly ready | Repository maintainer; study lead; governance/IT | reviewed final source, G4b delivery decision, and G6a hosting plan | protected remote review record, clean-clone evidence, and retention/handoff record | push the public-safe branch, rebuild from a fresh clone, then tag only after coauthor/venue review | G4b, G5, G6a |

## Ordered work from the current v0.4 candidate

The historic source freeze and candidate are not rerun inputs. The current
defensible route has been completed through candidate verification and the
restricted author-review manuscript build. Remaining work is therefore focused
on coauthor review, manuscript facts, venue requirements, and durable private
handoff rather than a second analysis run.

| Phase | Stage(s) | Action | Stop condition / acceptance gate |
|---|---|---|---|
| 0 | G0a | Source-only checks were run and the selected v0.4 baseline was used for the restricted lineage. | Rerun checks after any tracked source edit. |
| 1 | G0b, G1a, G1b | Authorization, source access, and immutable-freeze compatibility were recorded in restricted storage. | Keep these records outside Git. |
| 2 | G2 | Validation, transformation, and analysis were run once from the selected baseline. | Do not rerun unless source, policy, metadata, code, or controlled analytical inputs change. |
| 3 | G3a, G3b | Structured-only scientific boundaries were applied; qualitative findings remain deferred. | Coauthors should review the narrow claim boundary before submission. |
| 4 | G4b | The candidate was generated, disclosure-reviewed, attested, independently verified, and used for the restricted manuscript build. | Do not broaden delivery without a new delivery decision. |
| 5 | G1c, G5, G6a | Finish manuscript facts, declarations, venue requirements, and private-hosting controls. | These items do not authorize a response-rate, qualitative, or unsupported method claim. |
| 6 | G5, G6b | Use the author-review PDF for coauthor review, then rebuild from a clean clone and complete the private handoff/tag only after review. | No submission-ready claim until author facts, declarations, venue formatting, and coauthor approval are complete. |

## Stage instructions and acceptance criteria

The tracker above is the authoritative statement of current status. The
instructions below are retained both as evidence of the completed route and as
a controlled rerun template. They do not direct a second source freeze or
analysis run merely because they are present; reuse them only after a material
controlled change or a newly selected baseline requires a new lineage.

### G0a - Current technical baseline

**Objective:** establish a public-safe, reproducible starting point without
claiming anything about restricted data or institutional approval.

1. Review the tracked source and confirm the working tree is clean.
2. When the policy decision has been committed, select that exact clean
   code-and-policy baseline for the upcoming real run. Do not verify a baseline
   and then change its policy before intake.
3. Run the locked-environment bootstrap where needed, the synthetic suite, and
   the appropriate privacy scan.
4. Record a current-baseline evidence row only after these checks have run on
   the intended code baseline.
5. Keep the final publishing route separate: a fresh clone of the verified
   private remote, not an accumulated development workspace, is the final
   strict-history and rebuild environment.

**Acceptance:** all tracked checks pass and the evidence index distinguishes
current technical verification from historic checks.

### G0b - Institutional governance and operating boundary

**Objective:** turn technical safeguards into authorized practice before a new
real-data run.

1. Record permitted analysis and sharing scope, access roles, encryption or
   storage controls, retention, backup, incident process, and approved sharing
   boundary in restricted governance records.
2. Preserve the verified exempt determination and collection-boundary evidence
   in those restricted records. It permits no inference about storage,
   disclosure, or delivery controls beyond its documented study scope.
3. Confirm survey material remains separate from raffle/contact administration
   and identify the verified collection-boundary wording available to the
   manuscript.
4. Designate the authority for scientific decisions, disclosure review,
   attestation, and external delivery.
5. Create the human-signed, action-scoped operating authorization in approved
   restricted storage and bind it to the selected clean Git commit and current
   preflight fingerprint. Do not place its ID in a shell command or tracked
   file.

**Acceptance:** the required restricted governance records exist. A local
restricted-root preflight is technical evidence only; it is not approval. The
authorization contract passes the documented machine checks and is confirmed by
the responsible human authority.

### G1a - Source availability and handoff record

**Objective:** document that the authoritative source is available without
turning a live restricted spreadsheet into an informal analysis export.

1. File a restricted source-access/handoff record using a safe local alias.
   The record may name the authorized access route and source revision only in
   approved restricted storage.
2. Leave the live source unchanged. Do not download it through Downloads, copy
   it into the repository, reconstruct it from raffle material, or use the
   raffle archive to infer survey responses.
3. Record that timestamps and open text remain restricted even if contact or
   raffle fields are absent from the survey source.
4. After the source handoff is approved, create the restricted source-access
   context bound to the selected intake authorization. It is the sole source of
   locator/revision values for intake; never provide those values on the
   command line.

**Acceptance:** the team can identify the authoritative source in its approved
record system, while no locator, source export, row-level value, or result
appears in Git.

### G1b - Immutable source freeze and schema compatibility

**Objective:** establish the immutable source basis for the current restricted
lineage and any later controlled rerun.

**Current status:** the current v0.4 lineage used a reviewed immutable freeze
and passed exact schema validation in restricted storage.

1. If a rerun is required, treat the then-live source as available but
   unfrozen. Reuse an existing immutable freeze only if restricted evidence
   proves it is the intended authoritative revision; otherwise create a new
   freeze.
2. From the approved environment, export the closed live source directly to
   the restricted root as the expected workbook. Preserve those bytes unchanged
   and record the source locator and revision only in restricted provenance.
   A live spreadsheet, a local Downloads copy, and a raffle archive are not
   acceptable substitutes for the immutable freeze.
3. Run intake with only its freeze ID and stop on any schema discrepancy. The candidate header
   manifest must match the tracked contract before validation begins.

**Acceptance:** a restricted source-freeze record identifies the immutable
export and confirms compatibility with the controlled header contract. A frozen
source is not automatically a claim-ready study-context record.

### G1c - Study-context and claim-boundary evidence

**Objective:** obtain only the authoritative context needed for a method or
manuscript claim, without delaying the restricted descriptive run when a claim
can remain appropriately limited.

1. Verify live-form routing, administration, recruitment, eligibility, and
   invitation-denominator context from authoritative records.
   The verified collection boundary supports general recruitment, eligibility
   screening, and separate raffle/contact collection, but it does not establish
   the exact invitation denominator or every live-form configuration.
2. Record any limitation that remains unresolved. In particular, do not infer
   structural skips from blanks and do not report a response rate without a
   verified denominator.
3. Supply only verified context to the claim inventory and manuscript. A
   missing invitation denominator blocks a response-rate claim, not the
   descriptive analysis itself.

**Acceptance:** a restricted context review identifies the permissible method
statements and the limitations that must remain in the manuscript.

### G2 - Current restricted structured lineage

**Objective:** create the analysis lineage eligible for the current release
decision and preserve it unchanged.

**Current status:** the current v0.4 validation, transformation, and structured
analysis lineage has completed in restricted storage.

1. Before the first real-data command, complete G4a. The release-policy
   fingerprint is bound into every manifest, so an unapproved or later-changed
   threshold would force a complete rerun.
2. From the approved restricted environment, follow the exact sequence in the
   [reproducibility guide](reproducibility-guide.md): intake/freeze as needed,
   validation, transformation, then analysis.
3. Retain the restricted `01`, `02`, and `03` manifests and internal audit
   outputs. Do not copy them into Git or this tracker.
4. Confirm source, predecessor output, metadata, policy, and environment
   fingerprints; review cohort flow, denominators, anomalies, and sensitivity
   outputs before proposing any claim.

**Acceptance:** the current `03-analysis.json` is a clean, manifest-bound
descendant of the approved source whose bound `01` and `02` predecessors record
the same controlled code, canonical lockfile, metadata, and policy baseline.
Historic artifacts remain reference evidence only and are not release inputs.

### G3a - Structured scientific review

**Objective:** determine what the study can responsibly claim before any
aggregate result is considered for sharing.

1. Review internal structured outputs with the methods lead and coauthors:
   denominator rules, missingness, anomalies, contribution uncertainty,
   and controlled checkbox categories.
2. Create a claim inventory mapping each proposed structured claim to a
   restricted artifact, its denominator, and its limitation.
3. Classify each question as a primary descriptive summary, an exploratory
   descriptive association, a qualitative-only question, or unsupported by the
   instrument. Perceived benefits are reported as perceptions; relationships,
   predictions, and outreach effectiveness are not causal claims.

**Acceptance:** coauthors have a reviewed structured claim inventory. No
structured candidate is attested, delivered, or used in a result-bearing
manuscript until its denominators, limitations, and exploratory status are
recorded.

### G3b - Qualitative scope decision

**Objective:** make the qualitative boundary explicit early enough that open
text is never read or represented informally.

1. Choose one path in a restricted decision record:
   - **Include qualitative findings:** authorize manual restricted coding,
     independent review/adjudication, hash-only snapshots, theme audit, and
     qualitative disclosure review; or
   - **Defer qualitative findings:** record the decision and make no themes,
     paraphrases, quotations, or qualitative interpretation claims in this
     manuscript.
2. If the disclosure threshold makes the structured candidate infeasible,
   consider a process-focused or methods-focused manuscript only if the team
   records that scope separately. Do not weaken the threshold to preserve a
   numeric result.

**Acceptance:** the scope decision is recorded. Structured work may proceed
without qualitative work only when the latter is formally deferred.

#### Question-to-claim triage for the first paper draft

Use this map during G3a rather than treating every questionnaire prompt as a
publication claim. It gives the paper a coherent descriptive focus while
preserving the limits of the small departmental survey.

| Paper question area | Planned evidence route | Required claim boundary |
|---|---|---|
| Awareness, use, helpfulness, and desired improvements | Primary structured awareness/use, needs, and perceived-value summaries | Describe survey-record reports; do not claim that the Wiki improves teaching. |
| Existing teaching-support resources and the Wiki's place among them | Primary structured resource-ecosystem summaries | Describe the reported landscape and stated fit only. |
| GitHub accessibility, advantages, disadvantages, and contribution barriers | Primary structured GitHub-attitude and barrier summaries | Report perceptions and reported barriers; do not claim that platform choice causes use or contribution. |
| Editathon awareness, participation, and perceived experience | Primary structured editathon summaries | Report awareness and reported experience; whether outreach was effective is, at most, an exploratory descriptive question. |
| Teaching interest or GitHub comfort in relation to Wiki engagement | Predeclared exploratory structured cross-tabs, if disclosure-safe | Label as exploratory descriptive association; never call it prediction, explanation, or causal evidence. |
| Ideal resource, missing content, and suggestions | Structured selected options; open text only if G3b authorizes manual coding | Keep open-text themes, paraphrases, and quotations out unless the qualitative path is completed. |

Any question not supported by this map requires a new controlled decision before
it enters the claim inventory.

### G4a - Disclosure readiness

**Objective:** make the policy and role decisions that allow an authorized
candidate review to begin, without generating or sharing a result artifact.

1. The controlled policy specifies `minimum_cell_count: 5`. Any policy-byte
   change is intentionally a rerun trigger.
2. Record the designated reviewer roles for manual disclosure review,
   attestation, and delivery in restricted governance records.
3. Confirm that the selected threshold and roles apply to the intended sharing
   boundary; this does not authorize a specific result artifact.

**Acceptance:** the policy and roles are recorded under the approved governance
process. Candidate generation may prepare a restricted review artifact only
after G2 and G3a are complete; candidate attestation, delivery, and
result-bearing manuscript use remain unavailable until G3a, G3b, and G4b are
complete.

### G4b - Disclosure-safe result package and delivery decision

**Objective:** decide whether exact aggregate artifacts may move beyond
authorized restricted review.

1. Generate a restricted candidate from the reviewed v0.4 primary structured
   summaries only. The implementation rejects stale commits, canonical
   lockfile, controlled metadata, policy fingerprints, and stale `01`/`02`
   predecessors before it creates candidate outputs.
2. Complete manual direct, indirect, linkage, differencing, rare-combination,
   and cross-artifact reconstruction review.
3. Create the restricted attestation binding the candidate manifest, analysis
   manifest, policy, and exact output hashes; run `verify-release`.
4. Make a separate delivery decision naming the exact approved files and the
   allowed destination. No script transfers a candidate automatically.
5. If suppression leaves no disclosure-safe result artifact that supports the
   intended paper, record the feasibility outcome and select a different
   approved scope or stop external result delivery. Do not relax the threshold
   or substitute internal values.

**Acceptance:** an exact artifact is both mechanically valid and manually
approved. Without that record, the fallback deliverable is code, metadata, and
synthetic tests only.

### G5 - Manuscript and supplement

**Objective:** produce a readable scholarly record whose claims are bounded by
approved evidence.

1. Populate numerical Results only from the approved generated results
   fragment. Never transcribe counts or percentages manually.
2. Confirm setting, recruitment, eligibility, administration,
   ethics/governance, authorship/CRediT, funding/COI, acknowledgments, and
   data/code availability wording against verified records.
3. Keep claims descriptive and implementation-specific; report denominators and
   limitations, not causality, unverified response rates, or unsupported
   generalization.
4. Build and inspect the final PDF from a clean clone with the TeX engine and
   version recorded.

**Acceptance:** every factual, numerical, and qualitative statement maps to a
reviewed artifact or verified record, and the manuscript compiles
reproducibly.

### G6a - Private-hosting readiness

**Objective:** choose the durable private-review environment before the final
manuscript is ready, without treating it as a publishing action.

1. The technical private remote is in place. Record and confirm its
   least-privilege access, reviewer roles, branch-protection settings, and
   retention/archive expectations in the private-handoff record; the remote's
   existence and CI status do not stand in for those human decisions.
2. Confirm that the remote receives only the public-safe repository history and
   never restricted data, candidates, approval records, or generated results.

**Acceptance:** the hosting and access plan is approved for use when the final
source is ready. No final tag or handoff claim is made at this stage.

### G6b - Private handoff and preservation

**Objective:** deliver a durable, auditable private project package.

1. Push through a review branch and protected review flow; do not use an
   unrelated development history as a remote source.
2. From a fresh clone of the verified remote, run strict-history scanning,
   bootstrap, tests, safe documentation checks, and the final manuscript build.
3. Tag the approved commit and retain restricted artifact hashes, governance
   evidence, and retention/handoff records outside Git.

**Acceptance:** the private package rebuilds independently, the tag identifies
the reviewed source, and restricted material remains outside version control.

## Evidence rules and change control

- Track only public-safe descriptions and restricted-record aliases here. Keep
  raw data, names, locators, source hashes, approval identities, and restricted
  paths in approved restricted storage.
- Mark evidence as `complete_current`, `complete_historic`,
  `requires_refresh`, `ready`, `awaiting_external`,
  `blocked_by_dependency`, `not_started`, or `not_applicable_recorded`.
  Never call historic verification current.
- A source, routing, controlled metadata, listed analytical control, lockfile,
  policy, or analytical output change requires a new analytical lineage. An
  editorial-only manuscript or layout change instead requires a separately
  recorded authorized build and downstream review; it does not by itself
  require an analytical rerun or authorize a later checkout.
- A current code check, a current restricted analysis lineage, and a final
  clean-clone manuscript build are distinct evidence claims. Record each
  separately.
- Use the [evidence tracker template](evidence-tracker-template.md) in the
  approved restricted workspace for role/date/status evidence without placing
  sensitive details in Git.
- Use the [restricted finalization runbook](restricted-finalization-runbook.md)
  for the execution sequence and the [coauthor review guide](coauthor-review-guide.md)
  for review preparation; neither file records approvals or result values.

## Definition of done

The project is complete only when G0a through G6b are satisfied: governance and
disclosure evidence are recorded; the current restricted lineage has been
reviewed; every released claim maps to an approved artifact; the manuscript and
supplement rebuild from a clean clone; the final private commit is tagged; and
restricted material is retained outside Git under the verified plan.
