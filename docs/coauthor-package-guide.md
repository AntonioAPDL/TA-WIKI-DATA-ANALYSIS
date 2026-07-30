# Coauthor manuscript package guide

This branch contains the current structured-only coauthor-review version of the TA Wiki
descriptive survey/evaluation manuscript and the workflow used to generate it.

Status: prepared for focused coauthor review.

## Current review package

Use `main.tex` as the Overleaf manuscript source. When sharing a local review
package, use repository-relative or bundle-relative paths:

1. `main.tex`
2. `manuscript/TA-Wiki-Manuscript.pdf`
3. `manuscript/TA-Wiki-Manuscript.html`
4. `supplement/TA-Wiki-Structured-Supplement.html`
5. `evidence/TA-Wiki-Claim-Ledger.csv`
6. `evidence/TA-Wiki-Table-1-Survey-Record-Context.csv`
7. `evidence/TA-Wiki-Table-2-Engagement-Indicators.csv`
8. `evidence/TA-Wiki-Supplemental-Structured-Indicators.csv`
9. `docs/current-status.md`
10. `docs/reproducibility-guide.md`

Do not use machine-local file paths in coauthor instructions. Raw survey data,
record-level rows, timestamps, open text, raffle/contact material, restricted
governance records, and local authorization files remain outside the repository.

## What the current draft supports

The current draft supports a local descriptive interpretation of 12 eligible,
consenting survey records. It reports counts, item-specific denominators,
missing/invalid responses, direct contribution status, and an extreme-case
deterministic missing-response range for contribution status.

The current draft does **not** support:

- response-rate calculation;
- department-wide prevalence estimates;
- causal claims or intervention-effectiveness claims;
- record-level routing claims;
- unique-person claims beyond the available survey-record evidence;
- qualitative themes, quotations, or paraphrases;
- public/external release under the configured minimum-cell policy.

## Decisions needed from Andrew and Marcela

1. Verify survey context: fielding dates, administration mode, recruitment
   mode/text, eligible population, consent and eligibility wording, duplicate
   handling, display/routing logic, and ethics wording.
2. Confirm that the contribution-status hierarchy is correct: direct item first,
   extreme-case deterministic missing-response range second, and the
   reason-informed diagnostic only in internal supplement/diagnostics until
   routing is verified.
3. Confirm that conditional noncontribution and editathon reason items remain
   out of the main manuscript until parent-item routing is verified.
4. Decide whether open-text material should remain excluded or undergo a
   restricted manual qualitative review.
5. Decide whether the article remains a short descriptive survey/evaluation or
   later expands with additional case evidence.
6. Complete the citation/literature pass and venue-specific formatting after
   the article type is confirmed.
7. Complete declarations: affiliations, corresponding author, ethics statement,
   funding, conflicts, acknowledgments, data/code availability, and author
   contributions.
8. Decide whether and how any broader public version can satisfy disclosure
   thresholds.
