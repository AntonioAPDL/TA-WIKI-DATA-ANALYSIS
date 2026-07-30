# Final manuscript completion plan

This plan covers the work needed after the current coauthor-review manuscript.
It is source-safe: it does not include raw survey rows, open text, timestamps,
reviewer identities, local paths, or institutional identifiers.

## Stage 1: coauthor factual verification

Goal: replace only the manuscript facts that require coauthor or restricted
source confirmation.

Required decisions:

- fielding dates;
- administration mode;
- recruitment route and invitation wording;
- eligible population and sampling frame;
- consent and eligibility wording;
- duplicate-submission handling;
- survey display/routing logic;
- final ethics/exempt wording.

Exit condition: each fact is either approved for manuscript use or explicitly
left unspecified with a defensible limitation statement.

## Stage 2: routing and invalid-response verification

Goal: decide whether conditional items can be promoted beyond internal
diagnostics.

Checks:

- parent-item to conditional-item concordance for contribution reasons;
- parent-item to conditional-item concordance for editathon nonparticipation
  reasons;
- review of invalid structured responses and whether they reflect true invalid
  selections, parsing artifacts, or ambiguous source entries;
- decision on whether any partial-token sensitivity is warranted.

Exit condition: conditional items remain excluded, or a verified routing table
is approved for supplement/main-text use with its denominator rule.

## Stage 3: qualitative review decision

Goal: decide whether open-text material stays excluded or is reviewed.

If excluded:

- keep all qualitative themes, quotations, and close paraphrases out of the
  manuscript;
- state that open-text material was not analyzed for this draft.

If included:

- conduct restricted human coding;
- retain a coding ledger and adjudication record outside Git;
- snapshot only hashes/status metadata;
- apply disclosure review before including any theme, quotation, or close
  paraphrase.

Exit condition: a documented include/exclude decision and, if included, a
reviewed qualitative evidence table.

## Stage 4: disclosure review

Goal: determine what can leave the coauthor-review boundary.

Checks:

- apply the selected minimum-cell threshold;
- suppress, aggregate, or generalize sparse structured cells;
- review whether supplement tables are internal-only or external-safe;
- ensure no record-level, timestamp, open-text, raffle/contact, or governance
  material is exposed.

Exit condition: public/external manuscript and supplement profile approved, or
the package remains limited to coauthor review.

## Stage 5: citation and venue pass

Goal: convert the draft from an internal coauthor manuscript into a target-outlet
submission draft. A preliminary citation/reporting-standard frame has been
applied; the remaining work is venue-specific.

Tasks:

- choose article type and target outlet;
- maintain `literature-evidence-matrix.md`;
- add or remove citations only when they support the manuscript's actual claims;
- align headings, abstract length, tables, references, declarations, and
  supplemental-materials style with the venue.

Exit condition: every citation has a claim-level purpose, and no citation is
used as decoration.

## Stage 6: final declarations

Goal: finalize submission metadata.

Required declarations:

- title;
- author order;
- affiliations;
- corresponding author;
- acknowledgments;
- funding;
- conflicts of interest;
- ethics statement;
- data availability;
- code availability;
- author contributions.

Exit condition: the manuscript can be circulated or submitted without
placeholder metadata.

## Stage 7: reproducibility and package verification

Goal: confirm that the package is rebuildable and internally coherent.

Checks:

- rebuild the manuscript and supplement from the aggregate package;
- run the journal claim validator;
- run source-safe privacy and repository tests;
- confirm no obsolete generated artifacts remain in the package;
- confirm the claim ledger links each manuscript claim to an aggregate source.

Exit condition: clean validation output, clean Git status except intended
generated/ignored artifacts, and an updated review package.
