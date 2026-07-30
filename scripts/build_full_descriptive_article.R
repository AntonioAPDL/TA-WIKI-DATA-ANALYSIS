#!/usr/bin/env Rscript

# Legacy disabled entry point.
#
# This command previously generated a superseded internal article that mixed
# structured survey summaries, preliminary qualitative material,
# and sparse exploratory cross-tabs. The supported manuscript path is now the
# structured-only descriptive survey builder:
#
#   Rscript scripts/run.R journal-style-manuscript

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
activate_project(root)

stop("Legacy descriptive article builder is disabled. Use scripts/run.R journal-style-manuscript for the supported structured-only descriptive survey manuscript.")
