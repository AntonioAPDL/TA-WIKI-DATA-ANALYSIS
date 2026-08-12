# Aggregate result bundle

This directory contains the disclosure-safe aggregate inputs and expected
manuscript outputs needed to reproduce the current TA Wiki platform-evaluation
manuscript from a clean clone.

It deliberately does not contain:

- raw survey rows;
- timestamps;
- raw open-text responses or direct quotations;
- contact or raffle material;
- source workbook locators;
- restricted governance records;
- local PDF/log/build intermediates.

The bundle is generated from the aggregate-only manuscript package whose TeX
output is text-identical to the repository-root `main.tex` file after
LF/CRLF-normalization. Use:

```powershell
Rscript scripts/run.R reproduce-results --check
```

The command stages the tracked aggregate inputs in a temporary directory,
rebuilds the journal-style manuscript artifacts, validates the claim ledger, and
checks that rebuilt outputs match the tracked expected snapshots and `main.tex`.

The aggregate inputs include structured item summaries and a disclosure-safe
summary of open-text themes. They do not include row-level records.

Directory layout:

| Path | Purpose |
|---|---|
| `aggregate-data/` | Aggregate analysis inputs consumed by the manuscript builder. |
| `expected/journal-manuscript/` | Expected rebuilt manuscript/tables/claim-ledger snapshots. |
| `manifest.json` | Bundle metadata and LF-normalized text hashes. |

If result values change, regenerate this bundle from the approved aggregate
analysis package; do not edit CSV values by hand.
