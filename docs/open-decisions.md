# Open decisions

The controlled workflow is implemented. The decisions below require designated
human authority or restricted evidence; they are not inferred by code. Record
the detailed rationale and approvals in the approved restricted governance or
project record, then update the completion tracker.

**Known input status:** the authorized source was frozen and processed through
the current v0.4 restricted lineage. Validation, transformation, structured
analysis, candidate generation, restricted attestation, independent release
verification, and the results-integrated author-review manuscript build have
completed outside Git. No source, row-level derivative, internal result, or
candidate artifact is stored in this repository. The raffle archive remains
excluded from analysis.

An official exempt determination and the high-level collection boundary have
also been verified from institutional correspondence. The detailed record stays
outside Git. That determination does not substitute for the operating, storage,
disclosure, or delivery decisions below.

| ID | Decision | Authority role | Required evidence | Needed by | Consequence if unresolved | Status |
|---|---|---|---|---|---|---|
| OD-01 | Confirm the authorized restricted access, security, retention, backup, incident-response, and sharing boundary for the selected v0.4 checkout. | Study lead / PI; governance authority | restricted operating record; the exempt determination is already verified separately | G0b | No v0.4 restricted action may begin from an unmatched authorization. | recorded_restricted |
| OD-02 | Complete verified study-context facts: live routing, administration, recruitment, eligibility, and invitation denominator. | Restricted-data analyst; study lead | restricted context review | G1c, G5 | A response-rate claim or unsupported method claim remains unavailable. | partly_recorded |
| OD-03 | Review denominators, anomaly treatment, contribution uncertainty, canonical checkbox categories, and exploratory boundaries for the v0.4 internal outputs once G2 completes. | Methods lead; coauthors | restricted scientific-review record | G3a | No approved structured claim inventory. | recorded_structured_only |
| OD-04 | Preserve the selected structured-only scope: qualitative findings are deferred. If the scope changes later, require the manual coding, independent review/adjudication, snapshot, and disclosure process before including qualitative material. | Study lead / PI; qualitative lead | restricted scope decision | G3b | No qualitative themes, paraphrases, quotations, or interpretation claims. | not_applicable_recorded |
| OD-05 | Complete exact-candidate disclosure review, attestation, and delivery decision. The controlled public minimum-cell threshold is configured as five. | Study lead / PI; disclosure reviewer | restricted candidate-review and approval record | G4b, G5 | Candidate sharing and the result-bearing manuscript build remain unavailable; a later policy change invalidates the v0.4 lineage and requires a rerun. | recorded_author_review_delivery |
| OD-06 | Confirm manuscript declarations and submission facts: setting, recruitment, ethics/governance, authorship/CRediT, funding/COI, acknowledgments, availability statement, references, and venue requirements if submitting. | Manuscript lead; all authors | verified factual records | G5 | Final manuscript is not submission-ready. | awaiting_coauthor_review |
| OD-07 | Confirm the technical private remote's access model, reviewers, branch-protection settings, and retention/archive process. | Repository maintainer; study lead; governance/IT | private-handoff record and technical remote verification | G6a | The technical remote is available, but no durable governed handoff or final release authorization exists. | partly_ready |

See the [completion plan](project-roadmap.md) for task order and the
[evidence tracker template](evidence-tracker-template.md) for the non-sensitive
acceptance record structure.
