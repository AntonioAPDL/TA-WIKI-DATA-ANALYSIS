#!/usr/bin/env Rscript

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
root <- normalizePath(file.path(dirname(this_script), ".."), winslash = "/", mustWork = TRUE)
source(file.path(root, "scripts", "lib", "project_context.R"))
activate_project(root)
if (!requireNamespace("testthat", quietly = TRUE)) stop("testthat is required for the test suite.")
testthat::test_dir(file.path(root, "tests", "testthat"), reporter = "summary", stop_on_failure = TRUE)
