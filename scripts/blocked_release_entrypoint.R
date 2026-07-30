#!/usr/bin/env Rscript

# Fail-closed compatibility entry point. The authoritative runner dispatches to
# 04_prepare_release.R, which additionally requires an approved policy and a
# restricted manual-disclosure attestation.
this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
activate_project(root)

stop("Release rendering is blocked until the approved minimum_cell_count is set and a restricted manual-disclosure attestation is available.")
