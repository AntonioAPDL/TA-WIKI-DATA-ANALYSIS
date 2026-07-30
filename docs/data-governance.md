# Data-governance boundary

## Data classes

| Class | Examples | Storage and Git rule |
|---|---|---|
| Public-safe source | Code, controlled metadata, synthetic fixtures, safe documentation | May be tracked after scanner/review checks. |
| Restricted source | Survey export, timestamps, row-level derivatives, raw text | External approved restricted storage only; never Git. |
| Restricted administration | Raffle/contact material, access records, governance evidence | Separate approved restricted storage; excluded from analysis repository. |
| Internal aggregate | Unsuppressed tables, data-quality reports, coding artifacts | Restricted storage only; never Git. |
| Release candidate | Suppressed primary-summary CSV, generated manuscript-results TeX, and candidate manifest | Restricted by default; not a public or tracked artifact. |
| Approved release artifact | Exact reviewed aggregate result used for sharing/manuscript | May move only after policy, byte-bound attestation, linkage review, scan, and explicit delivery decision. |

## Required controls

1. Real-data storage must be outside both this repository and the Downloads
   workspace. A local preflight checks path/ACL conditions; institutional
   security, retention, backup, and incident requirements must be evidenced
   separately.
2. A verified exempt research determination establishes the approved study
   activity and collection boundary; it does not, by itself, establish a
   restricted-data location, encryption, retention, disclosure threshold, or
   delivery authorization. Keep the detailed institutional record outside Git.
3. A passing restricted-root preflight is technical evidence only. Before any
   restricted command, a current human-signed, off-repository operating
   authorization must bind the approved root, exact clean Git baseline,
   authorized actions, data categories, and required operating controls. See
   the [restricted-operation authorization](restricted-operation-authorization.md)
   record contract. The code validates its scope and signed-artifact hash but
   cannot authenticate the signer's authority.
4. Survey and raffle/contact processes remain technically and administratively
   separated. Manuscript wording must use only the verified collection boundary.
   The confirmed live survey source is a restricted source even if raffle or
   contact columns are absent: timestamps and open text can still create
   identity or linkage risk. Export it only directly into approved restricted
   storage, preserve the live source unchanged, and never reconstruct it from
   raffle material. Store source locator/revision values only in the required
   restricted source-access context; never pass them on a command line.
5. Source intake preserves original bytes and records provenance in restricted
   storage. The tracked header manifest is respondent-free only.
6. Git ignore rules do not authorize a file. Scanner checks, hooks, review, a
   full-history scan, and protected remote settings provide defense in depth.
7. A source, metadata, listed analytical control, lockfile, policy, or
   analytical-output change requires a new lineage and fresh downstream review.
   An editorial-only manuscript or layout change instead requires a separately
   recorded authorized build and downstream review; it does not by itself
   require an analytical rerun or authorize a later checkout. Candidate
   creation and attestation verification mechanically require the bound
   validation, transformation, and analysis manifests to share the selected
   clean analysis baseline, canonical Git-blob lockfile, controlled metadata,
   release-policy fingerprint, run identity, and source provenance.
8. Release candidates never transfer automatically. An attestation must bind
   the exact candidate manifest and output hashes, along with the analysis
   manifest and release-policy hashes.

## Sharing boundary

Authorized review of internal outputs occurs only within approved restricted
storage. Sharing an exact aggregate artifact with coauthors requires the
disclosure candidate, manual review, attestation, and a separate delivery
decision. External/public delivery requires those same controls plus the
destination-specific authorization. These distinctions prevent a necessary
restricted scientific review from being confused with publication approval.

## Prohibited tracked material

Raw exports, spreadsheets, archives, timestamps, respondent-level data,
qualitative source text, internal reports, raffle/contact records, credentials,
restricted paths, approval identities, and unreviewed candidates are prohibited
from Git.
