# Recoding rules

The executable controlled rules are in `transformation-rules.csv`; this document
states their operating constraints.

1. Preserve source cells unchanged in the immutable restricted source freeze.
   Validation writes only a cohort ledger; transformation re-reads the bound
   freeze in memory and canonicalizes structured values only through named,
   tested rules.
2. Normalize whitespace and controlled Likert capitalization only when the
   resulting value matches the category codebook.
3. Treat checkbox fields that may contain `Other` text as restricted until exact
   canonical tokens are parsed. Any unmatched remainder produces a
   `partial_invalid` state and is excluded from structured release data.
4. Correct known form contamination only through an explicit rule, rationale,
   transformation audit entry, and adversarial test.
5. Because the frozen export does not provide independently verifiable routing
   metadata, blank structured fields are ordinary missing values in the current
   protocol. No structural skip is inferred from wording or another answer.
6. The direct contribution response is primary. For a missing direct response,
   the primary analysis remains missing. The named internal sensitivity may
   infer No only when the conditional reason field parses as valid under
   `derivation-rules.csv`; raw, invalid, partial-invalid, and structural-skip
   values do not trigger an inference. The sensitivity is not release
   authorization.
7. Incompatible selections in a single-choice field are invalid for that item's
   primary denominator. No imputation is performed.
8. A source, codebook, transformation rule, parser, or category-order change
   requires a new validation, transformation, and analysis run.
