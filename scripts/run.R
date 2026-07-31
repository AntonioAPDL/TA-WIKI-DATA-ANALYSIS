#!/usr/bin/env Rscript

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)

args <- commandArgs(trailingOnly = TRUE)
targets <- c(
  bootstrap = "00_bootstrap.R",
  `manuscript-check` = "check_main_manuscript.R",
  `journal-style-manuscript` = "build_journal_style_manuscript.R",
  `journal-claim-validation` = "validate_journal_claims.R",
  `reproduce-results` = "reproduce_results_from_aggregate.R"
)

usage <- c(
  "Usage: Rscript scripts/run.R <command> [arguments]",
  "",
  "Commands:",
  "  bootstrap                  Restore the locked R environment.",
  "  privacy [--strict-history] Scan the tracked-file boundary.",
  "  manuscript-check           Check root main.tex; compiles when pdflatex is available.",
  "  journal-style-manuscript   Rebuild manuscript artifacts from aggregate tables.",
  "  journal-claim-validation   Validate rebuilt manuscript artifacts.",
  "  reproduce-results          Rebuild/check manuscript values from the tracked aggregate bundle."
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

if (identical(task, "privacy")) {
  python <- python_command()
  status <- system2(python$executable, c(python$prefix, file.path(root, "scripts", "privacy_scan.py"), root, forward))
} else if (task %in% names(targets)) {
  status <- system2(rscript, quote_args(c(file.path(root, "scripts", targets[[task]]), forward)))
} else {
  stop("Unsupported task: ", task)
}

if (is.null(status)) status <- 0L
if (status != 0L) quit(status = status)
