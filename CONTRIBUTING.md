# Contributing

This repository is a reproducible research workflow, not a data workspace.
Contributions should keep the documentation, code, metadata, and tests aligned
while preserving the project’s privacy and disclosure boundaries.

## Before making a change

1. Read the [project roadmap](docs/project-roadmap.md), the
   [data-governance boundary](docs/data-governance.md), and the relevant
   analysis or release document.
2. For manuscript prose, read [STYLE_PROFILE.md](STYLE_PROFILE.md).
3. Do not add survey exports, timestamps, respondent-level records, open text,
   contact or raffle material, restricted paths, internal tables, credentials,
   or approval identities.

## Verify a change

Run the applicable checks from the repository root:

```powershell
$env:TA_WIKI_ALLOW_RENV_BOOTSTRAP='1'
Rscript scripts/run.R bootstrap
Rscript scripts/run.R privacy
Rscript scripts/run.R test
```

Before a private push, release review, or final handoff, also run:

```powershell
Rscript scripts/run.R privacy --strict-history
```

For the final private-handoff clone, enable the repository hooks and run the
read-only handoff verifier with the selected credential-free private `origin`:

```powershell
git config core.hooksPath .githooks
python scripts/verify_private_handoff.py . --strict-history `
  --require-hooks --require-origin --require-origin-only
```

The verifier does not establish remote visibility, branch protection, or
governance approval; record those checks outside Git.

Inspect `git status --short` and the staged diff before committing. Keep real
data work and internal results in approved restricted storage, never in this
repository or its ignored workspaces.

## Keep the record clear

Use descriptive file names, update the relevant guide when an interface or
workflow changes, and record decisions that affect methods, privacy, release,
or interpretation. The [documentation guide](docs/README.md) identifies the
controlling documents and registers.
