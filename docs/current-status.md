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
- The root manuscript source, structured supplement snapshots, compact tables,
  and claim ledger are reproducible from the tracked disclosure-safe aggregate
  bundle by script.
- A modest citation/reporting-standard pass has been applied to support the
  framing and reporting choices without adding new empirical claims.

## Current manuscript package

Primary coauthor-review files tracked in this repository:

- `main.tex`
- `results/structured-aggregate/README.md`
- `results/structured-aggregate/manifest.json`
- `results/structured-aggregate/aggregate-data/*.csv`
- `results/structured-aggregate/expected/journal-manuscript/*.csv`
- `results/structured-aggregate/expected/journal-manuscript/*.md`
- `results/structured-aggregate/expected/journal-manuscript/journal-style-manuscript.tex`

Local PDFs, HTML review copies, and coauthor ZIP packages can be generated when
needed, but they are not tracked. The tracked Overleaf source is `main.tex`.

## Current reproducibility state

The clean-clone reproducibility target for this coauthor repository is:

- restore the locked R environment;
- run privacy and synthetic tests;
- verify tracked metadata and documentation wiring;
- check the root `main.tex` manuscript source;
- compile `main.tex` locally when a TeX engine is available, or in Overleaf
  during coauthor review;
- regenerate and check the current empirical values, main tables, structured
  supplement snapshots, claim ledger, and manuscript TeX from
  `results/structured-aggregate/`.

Run:

```powershell
Rscript scripts/run.R reproduce-results --check
```

This does not make the repository raw-data-reproducible. It makes the current
result-bearing manuscript clone-reproducible from reviewed aggregate artifacts
while still excluding respondent rows, timestamps, open text, contact/raffle
material, and restricted governance records. The file-by-file repository audit
is recorded in [reproducibility audit report](reproducibility-audit-report.md)
and [reproducibility file ledger](reproducibility-file-ledger.csv).

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
