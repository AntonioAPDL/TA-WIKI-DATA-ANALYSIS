#!/usr/bin/env Rscript

# Authoritative local entry point. It resolves the project from its own location
# and dispatches only explicit tasks; Makefile targets are convenience wrappers.
this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)

args <- commandArgs(trailingOnly = TRUE)
targets <- c(
  bootstrap = "00_bootstrap.R",
  intake = "00_capture_source_schema.R",
  validate = "01_validate_input.R",
  transform = "02_transform.R",
  analyze = "02_analyze.R",
  qualitative = "03_prepare_qualitative.R",
  `qualitative-snapshot` = "03_record_qualitative_snapshot.R",
  release = "04_prepare_release.R",
  `verify-release` = "05_verify_release_attestation.R",
  readiness = "check_readiness.R",
  `manuscript-preview` = "build_manuscript_preview.R",
  `manuscript-attested-build` = "build_attested_manuscript.R",
  `coauthor-brief` = "build_coauthor_review_brief.R",
  `full-internal-analysis` = "build_full_internal_analysis.R",
  `journal-style-manuscript` = "build_journal_style_manuscript.R",
  `journal-claim-validation` = "validate_journal_claims.R",
  `coauthor-package` = "package_coauthor_review.R"
)
usage <- c(
  "Usage: Rscript scripts/run.R <command> [arguments]",
  "",
  "Commands:",
  "  bootstrap             Restore the locked R environment.",
  "  privacy [--strict-history]  Scan the tracked-file boundary.",
  "  test                  Run the synthetic test suite.",
  "  intake                Freeze restricted source provenance and schema evidence (signed authorization required).",
  "  validate              Validate a source or create a synthetic validation run.",
  "  transform             Apply controlled transformations (real runs require signed authorization).",
  "  analyze               Produce restricted structured summaries (real runs require signed authorization).",
  "  qualitative           Prepare an empty restricted qualitative workspace (signed authorization required).",
  "  qualitative-snapshot  Record a hash-only qualitative workspace snapshot.",
  "  release               Prepare a restricted release candidate; never publishes (signed authorization required).",
  "  verify-release        Verify a restricted release attestation (signed authorization required).",
  "  readiness             Report technical prerequisites without accessing survey data.",
  "  manuscript-preview    Build a local controlled manuscript preview.",
  "  manuscript-attested-build  Build a restricted PDF from an attested results fragment (signed authorization required).",
  "  coauthor-brief        Build a local results-free coauthor review brief.",
  "  full-internal-analysis  Build the ignored structured aggregate internal analysis package.",
  "  journal-style-manuscript  Build the ignored journal-style manuscript and claim ledger from the full-analysis package.",
  "  journal-claim-validation  Validate journal manuscript tables, ledger hashes, and blocked-item exclusions.",
  "  coauthor-package       Assemble a clean coauthor-review package from generated manuscript artifacts.",
  "",
  "See scripts/README.md and docs/reproducibility-guide.md for command details."
)
if (!length(args) || args[[1]] %in% c("help", "--help", "-h")) {
  cat(paste(usage, collapse = "\n"), "\n")
  quit(status = 0L)
}
task <- args[[1]]
forward <- args[-1]
rscript <- file.path(R.home("bin"), "Rscript")
quote_args <- function(args) {
  if (.Platform$OS.type == "windows") shQuote(args, type = "cmd") else args
}
renv_library_for_child <- function(root) {
  library_root <- file.path(root, "renv", "library")
  if (!dir.exists(library_root)) return("")
  package_dirs <- list.dirs(library_root, recursive = TRUE, full.names = TRUE)
  candidates <- unique(dirname(package_dirs[basename(package_dirs) == "jsonlite"]))
  candidates <- candidates[file.exists(file.path(candidates, "jsonlite"))]
  if (length(candidates)) normalizePath(candidates[[1]], winslash = "/", mustWork = TRUE) else ""
}
if (identical(task, "bootstrap")) {
  status <- system2(rscript, quote_args(c(file.path(root, "scripts", targets[[task]]), forward)))
} else if (identical(task, "privacy")) {
  python <- python_command()
  status <- system2(python$executable, c(python$prefix, file.path(root, "scripts", "privacy_scan.py"), root, forward))
} else if (identical(task, "journal-claim-validation")) {
  renv_lib <- renv_library_for_child(root)
  old_autoloader <- Sys.getenv("RENV_CONFIG_AUTOLOADER_ENABLED", unset = NA)
  old_rlibs <- Sys.getenv("R_LIBS", unset = NA)
  on.exit({
    if (is.na(old_autoloader)) Sys.unsetenv("RENV_CONFIG_AUTOLOADER_ENABLED") else Sys.setenv(RENV_CONFIG_AUTOLOADER_ENABLED = old_autoloader)
    if (is.na(old_rlibs)) Sys.unsetenv("R_LIBS") else Sys.setenv(R_LIBS = old_rlibs)
  }, add = TRUE)
  Sys.setenv(RENV_CONFIG_AUTOLOADER_ENABLED = "FALSE")
  if (nzchar(renv_lib)) Sys.setenv(R_LIBS = renv_lib)
  status <- system2(rscript, quote_args(c(file.path(root, "scripts", targets[[task]]), forward)))
} else {
  activate_project(root)
  if (task %in% names(targets)) {
    status <- system2(rscript, quote_args(c(file.path(root, "scripts", targets[[task]]), forward)))
  } else if (identical(task, "test")) {
    status <- system2(rscript, quote_args(c(file.path(root, "tests", "testthat.R"), forward)))
  } else {
    stop("Unsupported task: ", task)
  }
}
if (is.null(status)) status <- 0L
if (status != 0L) quit(status = status)
