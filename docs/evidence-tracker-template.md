# Completion evidence tracker template

Use this template in the approved restricted workspace to coordinate the final
stages in the [completion plan](project-roadmap.md). It is intentionally safe
to copy, but completed restricted records must remain outside Git.

## How to use this tracker

- Keep one row per acceptance claim, not one row per command.
- Refer to restricted evidence by a local record alias only. Do not enter raw
  data, source hashes, paths, names, email addresses, cloud locators, approval
  identities, or result values.
- Use the machine-readable status value in the right-hand column below. The
  plan's display labels map to these values; do not invent near-synonyms in
  restricted records.

| Plan display label | Tracker status value |
|---|---|
| Complete - current | `complete_current` |
| Complete - historic; refresh required | `complete_historic` or `requires_refresh`, according to whether the historic evidence remains useful or is being replaced now |
| Ready | `ready` |
| Partly ready | `partly_ready` |
| Awaiting external decision | `awaiting_external` |
| Blocked by dependency | `blocked_by_dependency` |
| Not started | `not_started` |
| Not applicable - recorded | `not_applicable_recorded` |
- The accountable role confirms the row; the governing authority records any
  approval in the restricted governance system.
- When a change invalidates evidence, preserve the old row as historic and add
  a replacement row rather than overwriting provenance.

## Baseline record

| Field | Record |
|---|---|
| Controlled baseline label | `<repository release or review label>` |
| Intended Git commit | `<commit recorded only in approved handoff record if required>` |
| Analysis-specification version | `<controlled version label>` |
| Release-policy status | `<unapproved / approved under restricted record>` |
| Source availability | `<available but unfrozen / freeze identifier>` |
| Qualitative scope | `<pending / included / deferred>` |
| Tracker owner role | `<role>` |
| Last reviewed date | `<YYYY-MM-DD>` |

## Stage evidence log

The rows below are placeholders for a copied restricted tracker. Replace every
angle-bracketed field and status with the actual restricted record; do not let
the examples override the current status in the tracked project roadmap.

| Evidence ID | Stage | Acceptance claim | Status | Accountable role | Restricted evidence alias | Verification method | Date reviewed | Dependency / next action |
|---|---|---|---|---|---|---|---|---|
| `EV-001` | G0a | Current code-and-policy baseline is reproducible and public-safe checks passed. | `<status>` | Repository maintainer | `<local verification record>` | clean worktree, privacy scan, synthetic suite | `<YYYY-MM-DD>` | `<action>` |
| `EV-002` | G0b | Governance and operating boundary are authorized. | `<status>` | Study lead / PI | `<governance record alias>` | authorized review | `<YYYY-MM-DD>` | `<action>` |
| `EV-003` | G1a | Source availability and handoff are recorded without copying the live source. | `<status>` | Restricted-data analyst | `<source-access record alias>` | authorized access review | `<YYYY-MM-DD>` | `<action>` |
| `EV-004` | G1b | Immutable source freeze and exact schema compatibility are complete. | `<status>` | Restricted-data analyst | `<source-freeze record alias>` | intake provenance and header review | `<YYYY-MM-DD>` | `<action>` |
| `EV-005` | G1c | Claim-specific study context and limitations are verified. | `<status>` | Study lead | `<context-review record alias>` | authoritative context review | `<YYYY-MM-DD>` | `<action>` |
| `EV-006` | G2 | Selected v0.4 restricted validation-to-analysis lineage is complete. | `<status>` | Restricted-data analyst | `<v0.4 lineage record alias>` | manifest and audit review | `<YYYY-MM-DD>` | `<action>` |
| `EV-007` | G3a | Structured claims and sensitivity treatment are reviewed. | `<status>` | Methods lead | `<scientific-review record alias>` | coauthor review | `<YYYY-MM-DD>` | `<action>` |
| `EV-008` | G3b | Qualitative scope is included with controls or formally deferred. | `<status>` | Study lead / PI | `<qualitative-scope record alias>` | authorized scope review | `<YYYY-MM-DD>` | `<action>` |
| `EV-009` | G4a | Disclosure threshold and accountable review roles are authorized. | `<status>` | Study lead / PI | `<policy and role record alias>` | authorized review | `<YYYY-MM-DD>` | `<action>` |
| `EV-010` | G4b | Candidate disclosure review, byte-bound attestation, and delivery decision are complete. | `<status>` | Disclosure reviewer | `<attestation record alias>` | `verify-release` plus manual review | `<YYYY-MM-DD>` | `<action>` |
| `EV-011` | G5 | Manuscript claims and final PDF are reproducible. | `<status>` | Manuscript lead | `<claim crosswalk/build record>` | clean-clone TeX build and review | `<YYYY-MM-DD>` | `<action>` |
| `EV-012` | G6a | Private remote and review controls are ready. | `<status>` | Repository maintainer | `<hosting record alias>` | access and branch-protection review | `<YYYY-MM-DD>` | `<action>` |
| `EV-013` | G6b | Private handoff and preservation are complete. | `<status>` | Repository maintainer | `<handoff record alias>` | protected remote, tag, clean-clone verification | `<YYYY-MM-DD>` | `<action>` |

## Claim-to-evidence crosswalk

Complete this table before adding an approved finding to the manuscript or
supplement. It supports traceability without copying counts or results into the
tracker.

| Claim ID | Draft location | Claim type | Approved artifact alias | Denominator / limitation reviewed | Disclosure approval alias | Coauthor review status |
|---|---|---|---|---|---|---|
| `CLM-001` | `<section>` | `<structured / qualitative / contextual>` | `<restricted or approved artifact alias>` | `<review note>` | `<attestation or decision alias>` | `<pending / approved>` |

## Final release confirmation

- [ ] Selected v0.4 restricted lineage is marked `complete_current`.
- [ ] Every manuscript claim has a completed crosswalk row.
- [ ] The approved policy threshold, candidate, manual review, attestation, and
  exact delivery decision are recorded in restricted evidence.
- [ ] Final manuscript source and PDF were rebuilt from a fresh clone of the
  verified private remote.
- [ ] The approved commit is tagged and the handoff/retention record is
  complete.
