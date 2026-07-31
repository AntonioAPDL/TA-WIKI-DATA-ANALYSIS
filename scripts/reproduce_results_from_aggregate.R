#!/usr/bin/env Rscript

# Reproduce the current result-bearing manuscript artifacts from the tracked
# disclosure-safe aggregate bundle. This command never reads row-level survey
# data, timestamps, open text, contact material, or restricted storage.

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
activate_project(root)
source(file.path(dirname(this_script), "lib", "run_manifest.R"))
require_manifest_packages()

cli <- parse_cli(commandArgs(trailingOnly = TRUE))
allowed_flags <- c("check", "write-main")
bad_flags <- setdiff(cli$flags, allowed_flags)
if (length(bad_flags)) stop("Unsupported flag(s): ", paste(bad_flags, collapse = ", "))
if (has_flag(cli, "check") && has_flag(cli, "write-main")) {
  stop("Use either --check or --write-main, not both.")
}

bundle_dir <- option_value(cli, "bundle-dir", default = file.path(root, "results", "structured-aggregate"))
out_dir <- option_value(cli, "out-dir", default = "")
check_mode <- has_flag(cli, "check") || !has_flag(cli, "write-main")
write_main <- has_flag(cli, "write-main")

bundle_dir <- normalizePath(bundle_dir, winslash = "/", mustWork = TRUE)
manifest_path <- file.path(bundle_dir, "manifest.json")
if (!file.exists(manifest_path)) stop("Missing aggregate bundle manifest: ", manifest_path)
manifest <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)

rel_to_root <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  root_prefix <- paste0(normalizePath(root, winslash = "/", mustWork = TRUE), "/")
  if (startsWith(path, root_prefix)) substring(path, nchar(root_prefix) + 1L) else path
}

project_path <- function(relative) {
  if (!is.character(relative) || length(relative) != 1L || is.na(relative) || !nzchar(relative)) {
    stop("Manifest path entries must be non-empty strings.")
  }
  if (grepl("(^|/|\\\\)\\.\\.($|/|\\\\)", relative) || grepl("^[A-Za-z]:|^/", relative)) {
    stop("Manifest contains an unsafe path: ", relative)
  }
  file.path(root, relative)
}

canonical_text_sha256 <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  raw <- readBin(path, what = "raw", n = file.info(path)[["size"]])
  text <- rawToChar(raw)
  text <- enc2utf8(gsub("\r\n?", "\n", text, perl = TRUE))
  temporary <- tempfile("ta-wiki-canonical-text-", fileext = ".txt")
  on.exit(unlink(temporary, force = TRUE), add = TRUE)
  writeBin(charToRaw(text), temporary)
  sha256_file(temporary)
}

manifest_files <- c(manifest$aggregate_inputs, manifest$expected_outputs)
if (!length(manifest_files)) stop("Aggregate manifest contains no files.")
for (entry in manifest_files) {
  path <- project_path(entry$path)
  if (!file.exists(path)) stop("Missing aggregate bundle file: ", entry$path)
  actual <- canonical_text_sha256(path)
  if (!identical(tolower(actual), tolower(entry$sha256))) {
    stop("Aggregate bundle hash mismatch for ", entry$path, ": expected ",
         entry$sha256, ", got ", actual)
  }
}

privacy <- manifest$privacy_boundary
required_privacy <- c(
  "contains_raw_rows",
  "contains_timestamps",
  "contains_open_text",
  "contains_contact_or_raffle_material",
  "contains_source_locator_or_private_path"
)
for (field in required_privacy) {
  if (!identical(privacy[[field]], FALSE)) {
    stop("Aggregate bundle privacy boundary is not acceptable: ", field, " must be false.")
  }
}
if (!identical(privacy$contains_aggregate_results_only, TRUE)) {
  stop("Aggregate bundle must declare contains_aggregate_results_only = true.")
}
manuscript_date <- manifest$manuscript_version_date %||% ""
if (nzchar(manuscript_date) && !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", manuscript_date)) {
  stop("manifest.json manuscript_version_date must use YYYY-MM-DD format.")
}

stage_parent <- if (nzchar(out_dir)) {
  normalizePath(out_dir, winslash = "/", mustWork = FALSE)
} else {
  tempfile("ta-wiki-reproduce-results-")
}
if (dir.exists(stage_parent)) unlink(stage_parent, recursive = TRUE, force = TRUE)
dir.create(stage_parent, recursive = TRUE, showWarnings = FALSE)
if (!nzchar(out_dir)) on.exit(unlink(stage_parent, recursive = TRUE, force = TRUE), add = TRUE)

analysis_dir <- file.path(stage_parent, "full-analysis")
tables_dir <- file.path(analysis_dir, "tables")
rebuilt_dir <- file.path(stage_parent, "journal-manuscript")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

for (entry in manifest$aggregate_inputs) {
  source <- project_path(entry$path)
  target <- file.path(tables_dir, basename(entry$path))
  if (!file.copy(source, target, overwrite = TRUE)) stop("Unable to stage aggregate input: ", entry$path)
}

rscript <- file.path(R.home("bin"), "Rscript")
build_args <- c(
  file.path(root, "scripts", "run.R"),
  "journal-style-manuscript",
  "--analysis-dir", analysis_dir,
  "--out-dir", rebuilt_dir
)
if (nzchar(manuscript_date)) {
  build_args <- c(build_args, "--manuscript-date", manuscript_date)
}
build_output <- suppressWarnings(system2(rscript, build_args, stdout = TRUE, stderr = TRUE))
build_status <- attr(build_output, "status") %||% 0L
if (build_status != 0L) {
  stop("Aggregate manuscript rebuild failed:\n", paste(tail(build_output, 80), collapse = "\n"))
}

validate_args <- c(
  file.path(root, "scripts", "run.R"),
  "journal-claim-validation",
  "--manuscript-dir", rebuilt_dir,
  "--analysis-dir", analysis_dir
)
validation_output <- suppressWarnings(system2(rscript, validate_args, stdout = TRUE, stderr = TRUE))
validation_status <- attr(validation_output, "status") %||% 0L
if (validation_status != 0L) {
  stop("Rebuilt manuscript claim validation failed:\n", paste(tail(validation_output, 80), collapse = "\n"))
}

compare_file <- function(expected_relative, rebuilt_relative) {
  expected <- project_path(expected_relative)
  rebuilt <- file.path(rebuilt_dir, rebuilt_relative)
  if (!file.exists(rebuilt)) stop("Missing rebuilt artifact: ", rebuilt_relative)
  expected_hash <- canonical_text_sha256(expected)
  rebuilt_hash <- canonical_text_sha256(rebuilt)
  if (!identical(expected_hash, rebuilt_hash)) {
    stop("Rebuilt artifact differs from tracked expected snapshot: ", rebuilt_relative,
         "\nexpected ", expected_hash, "\nrebuilt  ", rebuilt_hash)
  }
  invisible(TRUE)
}

for (entry in manifest$expected_outputs) {
  compare_file(entry$path, entry$rebuilt_relative)
}

generated_tex <- file.path(rebuilt_dir, "journal-style-manuscript.tex")
main_tex <- file.path(root, "main.tex")
if (!identical(canonical_text_sha256(generated_tex), canonical_text_sha256(main_tex))) {
  stop("Rebuilt manuscript TeX does not match root main.tex.")
}

if (write_main) {
  if (!file.copy(generated_tex, main_tex, overwrite = TRUE)) stop("Unable to update main.tex.")
  message("main.tex updated from reproduced aggregate manuscript TeX.")
} else if (check_mode) {
  message("reproduce-results check passed: aggregate inputs, rebuilt outputs, claim ledger, and main.tex agree.")
}

if (nzchar(out_dir)) {
  message("Rebuilt artifacts written under: ", rel_to_root(stage_parent))
}
