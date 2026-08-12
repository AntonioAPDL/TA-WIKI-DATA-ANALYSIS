# Scripts

Use the runner from the repository root:

```powershell
Rscript scripts/run.R <command>
```

Available commands:

| Command | Purpose |
|---|---|
| `bootstrap` | Restore the locked R environment from `renv.lock`. |
| `privacy` | Scan the tracked file boundary. |
| `manuscript-check` | Check and optionally compile root `main.tex`. |
| `build-manuscript` | Rebuild manuscript artifacts from aggregate tables. |
| `validate-manuscript` | Validate rebuilt tables, claim ledger, and manuscript files. |
| `reproduce-results` | Rebuild and check the current manuscript from `results/structured-aggregate/`. |

Routine check:

```powershell
Rscript scripts/run.R reproduce-results --check
Rscript scripts/run.R manuscript-check
```
