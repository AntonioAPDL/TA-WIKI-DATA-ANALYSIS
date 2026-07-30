#!/usr/bin/env Rscript

# Build a local, nonnumeric manuscript preview from tracked inputs only. This
# command is deliberately separate from the disclosure-approved final build.

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
activate_project(root)
source(file.path(root, "scripts", "lib", "run_manifest.R"))
require_manifest_packages()

cli <- parse_cli()
if (length(cli$flags) || length(setdiff(names(cli$values), "output"))) {
  stop("Usage: Rscript scripts/run.R manuscript-preview [--output manuscript/<name>.pdf]")
}
manuscript_dir <- normalizePath(file.path(root, "manuscript"), winslash = "/", mustWork = TRUE)
default_destination <- file.path(manuscript_dir, "article-preview.pdf")
destination <- option_value(cli, "output", default = default_destination)
if (!grepl("^(?:[A-Za-z]:[/\\\\]|/)", destination)) destination <- file.path(root, destination)
destination <- normalizePath(destination, winslash = "/", mustWork = FALSE)
same_path <- function(left, right) {
  if (.Platform$OS.type == "windows") identical(tolower(left), tolower(right)) else identical(left, right)
}
if (!same_path(dirname(destination), manuscript_dir) || !grepl("\\.pdf$", destination, ignore.case = TRUE)) {
  stop("The controlled preview output must be a .pdf file directly under the repository manuscript directory.")
}

preview_input <- c(
  file.path(root, "manuscript", "article.tex"),
  file.path(root, "manuscript", "generated-results.tex")
)
if (!all(file.exists(preview_input))) {
  stop("The controlled preview requires manuscript/article.tex and manuscript/generated-results.tex.")
}
git <- Sys.which("git")
if (!nzchar(git)) git <- "C:/Program Files/Git/cmd/git.exe"
tracked_inputs <- run_command(
  git,
  c("-C", root, "ls-files", "--error-unmatch", "--", "manuscript/article.tex", "manuscript/generated-results.tex"),
  root
)
if (tracked_inputs$status != 0L) {
  stop("The controlled preview requires both manuscript inputs to be Git-tracked.")
}
input_clean <- run_command(
  git,
  c("-C", root, "diff", "--quiet", "HEAD", "--", "manuscript/article.tex", "manuscript/generated-results.tex"),
  root
)
if (input_clean$status == 1L) {
  stop("The controlled preview requires manuscript/article.tex and manuscript/generated-results.tex to match HEAD.")
}
if (input_clean$status != 0L) {
  stop("Unable to verify the Git snapshot for the controlled-preview inputs.")
}
git_snapshot <- git_metadata(root)
source_hashes <- vapply(preview_input, sha256_file, character(1))

configured_engine <- Sys.getenv("TA_WIKI_PDFLATEX", unset = "")
engine_candidates <- unique(c(configured_engine, Sys.which("pdflatex")))
engine_candidates <- engine_candidates[nzchar(engine_candidates)]
if (!length(engine_candidates)) {
  stop(
    "pdflatex is required for the controlled preview. Put it on PATH or set TA_WIKI_PDFLATEX to its executable path. " ,
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

stage_dir <- tempfile("ta-wiki-manuscript-preview-")
dir.create(stage_dir, recursive = TRUE, showWarnings = FALSE)
copied_inputs <- file.copy(preview_input, stage_dir, overwrite = FALSE)
if (!all(copied_inputs)) {
  stop("Unable to stage manuscript preview inputs.")
}
staged_input <- file.path(stage_dir, basename(preview_input))
staged_hashes <- vapply(staged_input, sha256_file, character(1))
if (!identical(unname(source_hashes), unname(staged_hashes))) {
  stop("The staged manuscript inputs do not match the verified pre-build snapshot.")
}
results_text <- paste(readLines(staged_input[[2]], warn = FALSE), collapse = "\n")
results_text_normalized <- tolower(gsub("[[:space:]]+", " ", results_text))
placeholder_marker <- "no disclosure-approved numerical result artifact is currently available for this manuscript"
if (!grepl(placeholder_marker, results_text_normalized, fixed = TRUE) || grepl("[0-9]", results_text)) {
  stop("The controlled preview requires the checked-in nonnumeric results placeholder; use the documented final-build route after an approved release.")
}
writeLines(c(
  "\\begin{center}",
  "\\fbox{\\parbox{0.88\\linewidth}{\\centering\\textbf{Controlled draft preview.} This PDF contains no disclosure-approved numerical results and is not submission-ready.}}",
  "\\end{center}"
), file.path(stage_dir, "preview-notice.tex"), useBytes = TRUE)
staged_article <- file.path(stage_dir, "article.tex")
article_lines <- readLines(staged_article, warn = FALSE)
maketitle_line <- which(trimws(article_lines) == "\\maketitle")
if (length(maketitle_line) != 1L) {
  stop("The controlled preview could not locate the manuscript title command in its staged copy.")
}
article_lines <- append(article_lines, "\\input{preview-notice.tex}", after = maketitle_line)
writeLines(article_lines, staged_article, useBytes = TRUE)

previous_directory <- getwd()
setwd(stage_dir)

compile_once <- function() {
  output <- tryCatch(
    system2(
      engine,
      c("-interaction=nonstopmode", "-halt-on-error", "-file-line-error", "-no-shell-escape", "article.tex"),
      stdout = TRUE,
      stderr = TRUE
    ),
    error = function(error) structure(conditionMessage(error), status = 1L)
  )
  status <- attr(output, "status") %||% 0L
  if (status != 0L) {
    detail <- paste(utils::tail(as.character(output), 30L), collapse = "\n")
    stop("pdflatex failed while compiling the controlled preview:\n", detail)
  }
}

compile_once()
compile_once()
preview_pdf <- file.path(stage_dir, "article.pdf")
if (!file.exists(preview_pdf) || !isTRUE(file.info(preview_pdf)$size > 0L)) {
  stop("pdflatex completed without producing a nonempty article.pdf.")
}
pdf_signature <- readBin(preview_pdf, what = "raw", n = 5L)
if (length(pdf_signature) != 5L || !identical(pdf_signature, charToRaw("%PDF-"))) {
  stop("pdflatex completed without producing a valid PDF signature.")
}

if (!file.copy(preview_pdf, destination, overwrite = TRUE)) {
  stop("Unable to copy the controlled preview to: ", destination)
}

engine_version <- if (length(engine_probe)) trimws(as.character(engine_probe[[1]])) else "pdflatex"
record_path <- sub("\\.pdf$", ".build.json", destination, ignore.case = TRUE)
record <- list(
  schema_version = "1.0",
  status = "controlled_draft_preview_not_submission_ready",
  generated_at_utc = utc_now(),
  source = list(
    article = list(relative_path = "manuscript/article.tex", sha256 = source_hashes[[1]]),
    results_placeholder = list(relative_path = "manuscript/generated-results.tex", sha256 = source_hashes[[2]]),
    preview_notice_sha256 = sha256_file(file.path(stage_dir, "preview-notice.tex")),
    staged_article_sha256 = sha256_file(staged_article)
  ),
  build = list(
    engine = basename(engine),
    engine_sha256 = sha256_file(engine),
    engine_version = engine_version,
    compile_arguments = c("-interaction=nonstopmode", "-halt-on-error", "-file-line-error", "-no-shell-escape", "article.tex"),
    passes = 2L,
    git = git_snapshot
  ),
  output = list(
    relative_path = file.path("manuscript", basename(destination)),
    sha256 = sha256_file(destination),
    bytes = unname(file.info(destination)$size)
  )
)
temporary_record <- tempfile("ta-wiki-manuscript-preview-record-", tmpdir = tempdir(), fileext = ".json")
jsonlite::write_json(record, temporary_record, auto_unbox = TRUE, pretty = TRUE, null = "null")
if (!file.copy(temporary_record, record_path, overwrite = TRUE)) {
  stop("Unable to write the local controlled-preview build record: ", record_path)
}
unlink(temporary_record, force = TRUE)
setwd(previous_directory)
unlink(stage_dir, recursive = TRUE, force = TRUE)
message("Controlled draft preview built: ", destination)
message("Local build record: ", record_path)
message("TeX engine: ", engine_version)
message("The preview contains no disclosure-approved numerical results and is not a submission-ready manuscript.")
