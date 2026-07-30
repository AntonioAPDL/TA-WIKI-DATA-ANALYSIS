#!/usr/bin/env Rscript

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)

# The initial renv bootstrap is opt-in when it would download code. Once renv
# is available, restore exactly the lockfile before any test or analysis run.
project_library <- file.path(
  root, "renv", "library", "windows",
  paste0("R-", R.version$major, ".", strsplit(R.version$minor, "\\.")[[1]][[1]]),
  R.version$platform
)
dir.create(project_library, recursive = TRUE, showWarnings = FALSE)
if (!requireNamespace("renv", quietly = TRUE)) {
  if (Sys.getenv("TA_WIKI_ALLOW_RENV_BOOTSTRAP") != "1") {
    stop("renv is unavailable. Re-run with TA_WIKI_ALLOW_RENV_BOOTSTRAP=1 to bootstrap and restore the lockfile.")
  }
  install.packages("renv", lib = project_library, repos = "https://cloud.r-project.org")
  .libPaths(c(project_library, .libPaths()))
}
activate_project(root)
renv::restore(project = root, prompt = FALSE)
required <- c("digest", "jsonlite", "readxl", "renv", "testthat", "writexl")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Locked restore incomplete: ", paste(missing, collapse = ", "))
renv::status(project = root)
message("Locked R environment is available.")
