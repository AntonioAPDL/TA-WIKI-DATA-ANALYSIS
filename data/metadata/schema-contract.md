# Live-sheet schema contract

The real-data importer accepts only the frozen authoritative workbook with the
approved sheet structure and exact tracked header order. Its checked schema and
shape contract remain in the restricted source-freeze evidence. Position-only
source mapping is prohibited.

Before a real run, export the workbook only to approved external restricted
storage and create an immutable source-freeze record. Intake copies the approved
staging workbook into the freeze directory, verifies the bytes before and after
copying, and binds validation to that copied artifact rather than to the mutable
staging export. The record captures source provenance and a restricted schema
profile. Promote an exact, respondent-free header manifest to this directory
only after review against the live source.

Validation fails when any of the following occurs:

- the workbook/sheet count, row count, populated-column count, or header order
  differs from the contract;
- required consent/eligibility fields are missing;
- no valid consent record exists, no eligible record exists, or no record meets
  both approved cohort rules;
- the source-freeze evidence does not match the copied frozen-workbook bytes;
- a cohort ledger contains anything other than row identity and cohort flags;
- the frozen source does not match the validation manifest before
  transformation.

Records that lack valid consent or eligibility are excluded from the analytic
cohort and counted in the restricted cohort-flow report; their presence alone is
not a schema failure. A verified routing record is required before any blank can
be labeled a structural skip.

Validation writes a restricted cohort ledger rather than a duplicate raw-source
CSV. Transformation re-opens the immutable freeze, verifies its fingerprint and
header contract, and selects only the controlled structured fields in memory.
Timestamps and open text never enter the transformation derivative.

The controlled derivation registry applies only named internal sensitivities.
For the contribution-status sensitivity, only a valid parsed conditional reason
can support the named inference; raw, invalid, partial-invalid, and structural
skip values do not.
