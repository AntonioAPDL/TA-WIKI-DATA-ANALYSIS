# Current status

Status: coauthor-review manuscript package in active preparation. In this
GitHub/Overleaf repository, the current manuscript source is the root
`main.tex` file.

## What is complete

- The structured survey data have been reduced to aggregate, reproducible
  tables for internal coauthor review.
- The current manuscript is a short descriptive survey/evaluation, not an
  inferential analysis and not a case-study article with qualitative findings.
- The manuscript reports counts and item-specific denominators, separates
  missing/invalid responses, and avoids response-rate, causal, and
  department-wide prevalence claims.
- The contribution result is reported in a conservative hierarchy:
  direct structured item first, then an extreme-case deterministic
  missing-response range. The reason-informed diagnostic remains internal and
  routing-dependent.
- The main PDF/HTML manuscript, structured supplement, and claim ledger are
  generated from the ignored internal aggregate package by script.
- A modest citation/reporting-standard pass has been applied to support the
  framing and reporting choices without adding new empirical claims.

## Current manuscript package

Primary coauthor-review files:

- `main.tex`
- `manuscript/TA-Wiki-Manuscript.pdf`
- `manuscript/TA-Wiki-Manuscript.html`
- `supplement/TA-Wiki-Structured-Supplement.html`
- `evidence/TA-Wiki-Claim-Ledger.csv`
- `evidence/TA-Wiki-Table-1-Survey-Record-Context.csv`
- `evidence/TA-Wiki-Table-2-Engagement-Indicators.csv`
- `evidence/TA-Wiki-Supplemental-Structured-Indicators.csv`

The generated working copies live under `reports/internal/journal-manuscript/`
when the manuscript builder is run locally. Those outputs are ignored because
they are review artifacts. The tracked Overleaf source is `main.tex`.

## Current reproducibility state

The clean-clone reproducibility target for this coauthor repository is:

- restore the locked R environment;
- run privacy and synthetic tests;
- verify tracked metadata and documentation wiring;
- check the root `main.tex` manuscript source;
- compile `main.tex` locally when a TeX engine is available, or in Overleaf
  during coauthor review.

Exact regeneration of the empirical values in `main.tex` requires the approved
restricted source or the ignored disclosure-safe aggregate manuscript package.
Those inputs are intentionally not stored in Git. The file-by-file repository
audit is recorded in [reproducibility audit report](reproducibility-audit-report.md)
and [reproducibility file ledger](reproducibility-file-ledger.csv).

The recommended next reproducibility upgrade is to track a reviewed
disclosure-safe aggregate bundle and add a `reproduce-results --check` command.
The options and implementation stages are documented in
[clone-reproducible results plan](clone-reproducible-results-plan.md).

## What is deliberately excluded

The current manuscript does not include:

- raw survey rows or timestamps;
- record-level routing checks;
- raffle/contact material;
- open-text quotations, paraphrases, or themes;
- small-cell public-release tables;
- unverified survey-administration facts;
- venue-specific declarations not confirmed by the coauthor team.

## Remaining decisions before external circulation

1. Verify fielding dates, administration mode, recruitment route, eligible
   population, consent/eligibility wording, duplicate handling, display/routing
   logic, and ethics wording.
2. Decide whether to keep the manuscript structured-only or add a separately
   reviewed qualitative component.
3. If qualitative material is added, complete restricted human coding,
   adjudication, snapshotting, and disclosure review before including any theme,
   quotation, or close paraphrase.
4. Complete venue-specific formatting and any additional citation adjustments
   after the target outlet is selected.
5. Finalize title, author order, affiliations, corresponding author,
   acknowledgments, funding, conflicts, ethics statement, data/code availability,
   and author contributions.
6. Decide whether a broader public version is needed; if yes, apply the
   disclosure threshold and suppress or aggregate small-cell results.

## Current recommended path

Circulate the coauthor-review manuscript and supplement for focused review.
Do not expand the analysis before the team first resolves survey-context,
routing, qualitative-review, disclosure, citation, and declaration decisions.
