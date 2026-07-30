#!/usr/bin/env Rscript

# Build a local, results-free coauthor review brief from one tracked TeX source.
# This artifact summarizes project readiness; it is not a submission manuscript
# and never reads restricted storage.

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
activate_project(root)
source(file.path(root, "scripts", "lib", "run_manifest.R"))
require_manifest_packages()

cli <- parse_cli()
if (length(cli$flags) || length(setdiff(names(cli$values), "output"))) {
  stop("Usage: Rscript scripts/run.R coauthor-brief [--output manuscript/<name>.pdf]")
}
manuscript_dir <- normalizePath(file.path(root, "manuscript"), winslash = "/", mustWork = TRUE)
default_destination <- file.path(manuscript_dir, "coauthor-review-brief.pdf")
destination <- option_value(cli, "output", default = default_destination)
if (!grepl("^(?:[A-Za-z]:[/\\\\]|/)", destination)) destination <- file.path(root, destination)
destination <- normalizePath(destination, winslash = "/", mustWork = FALSE)
same_path <- function(left, right) {
  if (.Platform$OS.type == "windows") identical(tolower(left), tolower(right)) else identical(left, right)
}
if (!same_path(dirname(destination), manuscript_dir) || !grepl("\\.pdf$", destination, ignore.case = TRUE)) {
  stop("The coauthor review brief output must be a .pdf file directly under the repository manuscript directory.")
}

brief_input <- file.path(root, "manuscript", "coauthor-review-brief.tex")
if (!file.exists(brief_input)) stop("The coauthor review brief source is missing.")
git <- Sys.which("git")
if (!nzchar(git)) git <- "C:/Program Files/Git/cmd/git.exe"
tracked_input <- run_command(
  git,
  c("-C", root, "ls-files", "--error-unmatch", "--", "manuscript/coauthor-review-brief.tex"),
  root
)
if (tracked_input$status != 0L) stop("The coauthor review brief source must be Git-tracked.")
input_clean <- run_command(
  git,
  c("-C", root, "diff", "--quiet", "HEAD", "--", "manuscript/coauthor-review-brief.tex"),
  root
)
if (input_clean$status == 1L) {
  stop("The coauthor review brief source must match HEAD before a controlled build.")
}
if (input_clean$status != 0L) stop("Unable to verify the Git snapshot for the coauthor review brief.")
brief_lines <- readLines(brief_input, warn = FALSE)
if (any(grepl("\\\\(?:input|include)", brief_lines, perl = TRUE))) {
  stop("The coauthor review brief must be self-contained and cannot import unverified TeX content.")
}
git_snapshot <- git_metadata(root)
source_hash <- sha256_file(brief_input)

configured_engine <- Sys.getenv("TA_WIKI_PDFLATEX", unset = "")
engine_candidates <- unique(c(configured_engine, Sys.which("pdflatex")))
engine_candidates <- engine_candidates[nzchar(engine_candidates)]
if (!length(engine_candidates)) {
  stop(
    "pdflatex is required for the coauthor review brief. Put it on PATH or set TA_WIKI_PDFLATEX to its executable path. ",
    "This command does not install a TeX distribution or substitute an unverified PDF."
  )
}
resolve_engine <- function(candidate) {
  if (file.exists(candidate)) return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
  found <- Sys.which(candidate)
  if (nzchar(found)) return(normalizePath(found, winslash = "/", mustWork = TRUE))
  NA_character_
}
resolved_engines <- vapply(engine_candidates, resolve_engine, character(1))
resolved_engines <- resolved_engines[!is.na(resolved_engines)]
if (!length(resolved_engines)) {
  stop("No configured pdflatex executable could be found. Set TA_WIKI_PDFLATEX to a valid executable path.")
}
engine <- resolved_engines[[1]]
engine_probe <- tryCatch(
  system2(engine, "--version", stdout = TRUE, stderr = TRUE),
  error = function(error) structure(conditionMessage(error), status = 1L)
)
if (!is.null(attr(engine_probe, "status")) && attr(engine_probe, "status") != 0L) {
  stop("Unable to execute pdflatex at: ", engine)
}

stage_dir <- tempfile("ta-wiki-coauthor-review-brief-")
dir.create(stage_dir, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(stage_dir, recursive = TRUE, force = TRUE), add = TRUE)
if (!file.copy(brief_input, stage_dir, overwrite = FALSE)) {
  stop("Unable to stage the coauthor review brief source.")
}
staged_input <- file.path(stage_dir, basename(brief_input))
if (!identical(source_hash, sha256_file(staged_input))) {
  stop("The staged coauthor review brief does not match the verified pre-build snapshot.")
}

previous_directory <- getwd()
on.exit(setwd(previous_directory), add = TRUE)
setwd(stage_dir)
compile_once <- function() {
  output <- tryCatch(
    system2(
      engine,
      c("-interaction=nonstopmode", "-halt-on-error", "-file-line-error", "-no-shell-escape", basename(brief_input)),
      stdout = TRUE,
      stderr = TRUE
    ),
    error = function(error) structure(conditionMessage(error), status = 1L)
  )
  status <- attr(output, "status") %||% 0L
  if (status != 0L) {
    detail <- paste(utils::tail(as.character(output), 30L), collapse = "\n")
    stop("pdflatex failed while compiling the coauthor review brief:\n", detail)
  }
}
compile_once()
compile_once()
brief_pdf <- file.path(stage_dir, sub("\\.tex$", ".pdf", basename(brief_input), ignore.case = TRUE))
if (!file.exists(brief_pdf) || !isTRUE(file.info(brief_pdf)$size > 0L)) {
  stop("pdflatex completed without producing a nonempty coauthor review brief PDF.")
}
pdf_signature <- readBin(brief_pdf, what = "raw", n = 5L)
if (length(pdf_signature) != 5L || !identical(pdf_signature, charToRaw("%PDF-"))) {
  stop("pdflatex completed without producing a valid PDF signature.")
}
if (!file.copy(brief_pdf, destination, overwrite = TRUE)) {
  stop("Unable to copy the coauthor review brief to: ", destination)
}

engine_version <- if (length(engine_probe)) trimws(as.character(engine_probe[[1]])) else "pdflatex"
record_path <- sub("\\.pdf$", ".build.json", destination, ignore.case = TRUE)
record <- list(
  schema_version = "1.0",
  status = "coauthor_review_brief_not_submission_ready",
  generated_at_utc = utc_now(),
  source = list(
    brief = list(relative_path = "manuscript/coauthor-review-brief.tex", sha256 = source_hash)
  ),
  build = list(
    engine = basename(engine),
    engine_sha256 = sha256_file(engine),
    engine_version = engine_version,
    compile_arguments = c("-interaction=nonstopmode", "-halt-on-error", "-file-line-error", "-no-shell-escape", basename(brief_input)),
    passes = 2L,
    git = git_snapshot
  ),
  output = list(
    relative_path = file.path("manuscript", basename(destination)),
    sha256 = sha256_file(destination),
    bytes = unname(file.info(destination)$size)
  )
)
temporary_record <- tempfile("ta-wiki-coauthor-review-brief-record-", tmpdir = tempdir(), fileext = ".json")
jsonlite::write_json(record, temporary_record, auto_unbox = TRUE, pretty = TRUE, null = "null")
if (!file.copy(temporary_record, record_path, overwrite = TRUE)) {
  stop("Unable to write the coauthor review brief build record: ", record_path)
}
unlink(temporary_record, force = TRUE)
message("Coauthor review brief built: ", destination)
message("Local build record: ", record_path)
message("TeX engine: ", engine_version)
message("The brief contains no restricted results and is not a submission-ready manuscript.")
