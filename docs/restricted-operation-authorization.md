# Restricted-operation authorization

## Purpose

A passing restricted-root preflight proves only local path and broad access
conditions. It is not permission to read the survey, create a restricted
derivative, inspect an internal aggregate, or produce a candidate. Every
restricted operation therefore requires a separate, human-signed operating
authorization stored outside Git in the approved restricted root.

The technical gate verifies the record's structure, scope, expiry, selected
analysis baseline, preflight binding, and the presence and hash of its signed
artifact. It cannot authenticate a human signature or decide whether an
institutional approval is substantively adequate. The responsible authority
must establish those facts before the record is created.

`Rscript scripts/run.R readiness` deliberately remains read-only. It can check
the selected record's machine-verifiable fields and signed-artifact hash, but
cannot authenticate the signer or confer authorization.

## Record placement and session selection

Keep the following two records only in the approved restricted root:

```text
governance/
  restricted-root-preflight.json
  operating-authorizations/<authorization-id>.json
  operating-authorizations/<signed-artifact>
  source-access-context.json
```

Prompt for the root and authorization ID only in the current authorized
session. `Read-Host` keeps the entered values out of the command itself and
therefore out of normal shell history:

```powershell
$restrictedRoot = Read-Host 'Approved restricted root'
$authorizationId = Read-Host 'Restricted operating authorization ID'
$env:TA_WIKI_RESTRICTED_ROOT = $restrictedRoot
$env:TA_WIKI_GOVERNANCE_AUTHORIZATION_ID = $authorizationId
```

Unset the two environment variables and remove the local variables when the
authorized session ends. Do not put either value in a tracked file, shell
profile, shared command history, issue, pull request, or manuscript. Do not
create a record from this template without the required human approval.

## Required operating-authorization record

The selected file must be
`governance/operating-authorizations/<authorization-id>.json` and use this
schema. Angle-bracketed values are placeholders; completed values remain
restricted.

```json
{
  "schema_version": "1.0",
  "record_type": "restricted_data_operating_authorization",
  "authorization_id": "<3-64 character identifier>",
  "status": "authorized",
  "issued_at_utc": "<YYYY-MM-DDTHH:MM:SSZ>",
  "expires_at_utc": "<YYYY-MM-DDTHH:MM:SSZ>",
  "authorization_basis_reference": "<restricted approval-record alias>",
  "authorization_scope": {
    "authorized_operations": ["intake", "validate"],
    "restricted_data_categories": ["survey_source"],
    "authorized_git_commit": "<40 lowercase-hex commit>",
    "restricted_root_preflight_sha256": "<64 lowercase-hex hash>",
    "operating_controls": {
      "storage": true,
      "encryption": true,
      "backup": true,
      "retention": true,
      "incident_response": true,
      "access_roles": true,
      "analysis_scope": true,
      "sharing_scope": true
    }
  },
  "human_signature": {
    "signer_name": "<authorized signer>",
    "signer_role": "<role>",
    "signed_at_utc": "<YYYY-MM-DDTHH:MM:SSZ>",
    "method": "institutional_e_signature",
    "signed_artifact": {
      "filename": "<basename of signed artifact beside this JSON>",
      "sha256": "<64 lowercase-hex hash>"
    }
  }
}
```

`method` must be `institutional_e_signature` or `wet_signature_scan`. The
signed artifact must be a nonempty, same-directory file whose hash matches the
JSON. The signer must review and sign a document that identifies the
authorization ID, selected Git commit, root-preflight fingerprint, scope, and
the operating controls represented by the record. The JSON itself and the
signed artifact are both restricted governance evidence.

The authorization is rejected if it is expired, its time fields are invalid or
out of order, the signed artifact is missing or altered, the selected
authorized commit or preflight hash differs, a mandatory control is false, or
the requested operation/category is outside scope. Do not edit a prior record
to make it appear current.

Every restricted action, including candidate verification and an attested
manuscript build, remains bound to the exact authorized checkout. The code
records editorial provenance separately, but it does not treat a later prose or
layout commit as authorized to operate on restricted artifacts. A future
cross-commit workflow would require an independently verifiable signed scope
binding; it is intentionally not inferred from an editable JSON field.

## Operation scope

Each action needs both the named operation and its required restricted-data
category in the signed record.

| Action | Required category |
|---|---|
| `intake`, `validate` | `survey_source` |
| `transform`, `analyze` | `row_level_derivatives` |
| `qualitative`, `qualitative-snapshot` | `qualitative_material` |
| `release` | `internal_aggregate` |
| `verify-release`, `manuscript-attested-build` | `release_candidate` |

The gate applies in the command scripts and in candidate/attestation helper
entry points. Synthetic validation, transformation, and analysis stay outside
this route and do not require a restricted root or authorization.

## Source-access context: no locator IDs on the command line

Source intake accepts only `--freeze-id`. It reads the source file and revision
identifiers from the required external record
`governance/source-access-context.json`, so they are not retained in shell or
process command history:

```json
{
  "schema_version": "1.0",
  "record_type": "restricted_source_access_context",
  "status": "authorized_for_intake",
  "recorded_at_utc": "<YYYY-MM-DDTHH:MM:SSZ>",
  "authorization_id": "<selected authorization id>",
  "authorized_git_commit": "<same 40 lowercase-hex commit>",
  "source_access_record_reference": "<restricted source-handoff alias>",
  "source": {
    "id": "survey_final",
    "filename": "TA Wiki Feedback Survey (Responses).xlsx",
    "drive_file_id": "<restricted locator>",
    "drive_revision_id": "<restricted revision>"
  }
}
```

If the G1b compatibility review accepts the historic immutable freeze, start
validation from its approved freeze ID and retain the accepted restricted
provenance record. Otherwise, the source must already have been exported
directly to `raw/TA Wiki Feedback Survey (Responses).xlsx` under the approved
restricted root. The context record is read only after the signed `intake`
authorization passes. Intake copies that staging workbook into its immutable
freeze directory, checks that the source bytes did not change during copying,
and records the frozen-copy hash, safe reference, restricted locator, and
revision in the restricted provenance record. Later validation uses the frozen
copy, not the mutable `raw/` staging file. Nothing from this context is written
to Git or console output.

## Practical sequence

1. Select the final clean code-and-policy commit and run the restricted-root
   technical preflight.
2. Have the responsible authority create and sign the operating authorization
   for the required actions and categories.
3. Place the signed artifact and matching JSON beside one another in approved
   restricted storage; do not store either in the repository.
4. Record the source-access context in that same restricted root after the
   source handoff is approved.
5. Set the two session environment variables and run intake without locator
   arguments:

   ```powershell
   Rscript scripts/run.R intake --freeze-id <freeze-id>
   ```

6. Continue only with actions explicitly listed in the authorization. A policy,
   code, preflight, role, or scope change requires the responsible authority to
   review whether a new authorization is needed.

The automated tests construct temporary synthetic records solely to test the
validator. They are not evidence of, and must never be substituted for, a real
institutional authorization.
