# Release checklist

Complete this checklist for every candidate delivery. Signed approvals, named
reviewers, source hashes, and restricted paths stay outside Git.

- [ ] Institutional governance records authorize the restricted environment,
  analysis scope, sharing boundary, and accountable review roles. Restricted-root
  preflight alone is not approval.
- [ ] The source export, raffle archive, row-level derivatives, timestamps,
  open text, and internal tables are absent from the candidate and the
  strict-history privacy scan passes.
- [ ] The candidate traces to the current immutable survey-source freeze, not
  a mutable live spreadsheet, a local download, or the raffle archive. The
  source locator and revision remain only in restricted provenance.
- [ ] The approved `minimum_cell_count` is recorded as an integer in
  `config/release-policy.yml`; policy controls still block free text,
  timestamps, and respondent-level rows.
- [ ] The candidate was generated from the current-version `03-analysis.json`
  using the primary structured-summary universe only. Sensitivity variants,
  exploratory cross-tabs, qualitative material, and the conditional
  noncontribution-reason item remain excluded unless separately specified and
  reviewed.
- [ ] `release` confirmed that the bound `01` validation, `02` transformation,
  and `03` analysis manifests share the selected clean analysis commit,
  canonical Git-blob lockfile, analytical-control fingerprint, controlled
  metadata and release-policy fingerprints, run identity, and source
  provenance. The candidate manifest binds the same policy and canonical
  release-builder source as its analysis manifest.
- [ ] Automated suppression fully suppresses any affected table. A reviewer has
  assessed direct, indirect, differencing, linkage, rare-combination, and
  cross-artifact reconstruction risk.
- [ ] The restricted attestation uses schema version 1.1 and status `approved`.
- [ ] The attestation records the applicable approval and manual disclosure
  review using restricted governance identifiers, not names in Git.
- [ ] The attestation binds the exact candidate-manifest hash, analysis-manifest
  hash, release-policy hash, and all candidate-output hashes, including the
  generated manuscript results.
- [ ] `verify-release` succeeds without modifying the candidate, repeats the
  analytical-baseline check, records the verifier provenance, and retains the
  restricted verification record with the attestation.
- [ ] A separately authorized delivery decision identifies the exact approved
  files. No script automatically copies candidates to Git, a manuscript, or a
  public location.
- [ ] A fresh clone of the verified private remote restores the locked
  environment, passes synthetic tests and privacy scanning, and produces no
  unexpected tracked-file changes.
