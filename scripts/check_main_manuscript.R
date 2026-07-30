#!/usr/bin/env Rscript

# Check the Overleaf-facing manuscript source. This command is intentionally
# source-safe: it reads only tracked TeX source and writes any optional PDF build
# products to a temporary directory.

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
cli <- parse_cli(commandArgs(trailingOnly = TRUE))

tex_path <- file.path(root, "main.tex")
if (!file.exists(tex_path)) stop("Missing root main.tex; the Overleaf-facing manuscript source is required.")

lines <- readLines(tex_path, warn = FALSE, encoding = "UTF-8")
text <- paste(lines, collapse = "\n")

required_patterns <- c(
  "\\\\documentclass",
  "\\\\begin\\{document\\}",
  "\\\\end\\{document\\}",
  "\\\\title\\{",
  "\\\\begin\\{abstract\\}"
)
missing <- required_patterns[!vapply(required_patterns, grepl, logical(1), x = text, perl = TRUE)]
if (length(missing)) {
  stop("main.tex is missing required manuscript structure: ", paste(missing, collapse = ", "))
}

forbidden_patterns <- c(
  "draft warning",
  "confidential warning"
)
forbidden_hits <- forbidden_patterns[
  vapply(forbidden_patterns, function(pattern) {
    grepl(tolower(pattern), tolower(text), fixed = TRUE)
  }, logical(1))
]
if (length(forbidden_hits)) {
  stop("main.tex contains stale internal-review wording: ", paste(forbidden_hits, collapse = ", "))
}

legacy_inputs <- c(
  "\\\\input\\{manuscript/article\\.tex\\}",
  "\\\\input\\{manuscript/generated-results\\.tex\\}"
)
legacy_hits <- legacy_inputs[vapply(legacy_inputs, grepl, logical(1), x = text, perl = TRUE)]
if (length(legacy_hits)) {
  stop("main.tex imports legacy controlled-build manuscript files: ", paste(legacy_hits, collapse = ", "))
}

require_pdf <- has_flag(cli, "require-pdf")
pdf_engine <- Sys.getenv("TA_WIKI_PDFLATEX", unset = "")
if (!nzchar(pdf_engine)) pdf_engine <- Sys.which("pdflatex")

if (!nzchar(pdf_engine)) {
  if (require_pdf) {
    stop("pdflatex is required by --require-pdf. Put it on PATH or set TA_WIKI_PDFLATEX.")
  }
  message("main.tex source check passed. pdflatex was not found, so PDF compilation was skipped.")
  quit(status = 0L)
}

build_dir <- tempfile("ta-wiki-main-tex-")
dir.create(build_dir, recursive = TRUE)
on.exit(unlink(build_dir, recursive = TRUE, force = TRUE), add = TRUE)
if (!file.copy(tex_path, file.path(build_dir, "main.tex"), overwrite = TRUE)) {
  stop("Unable to stage main.tex for temporary compilation.")
}

previous <- getwd()
on.exit(setwd(previous), add = TRUE)
setwd(build_dir)

compile <- function() {
  output <- tryCatch(
    system2(pdf_engine, c("-interaction=nonstopmode", "-halt-on-error", "main.tex"), stdout = TRUE, stderr = TRUE),
    error = function(error) structure(conditionMessage(error), status = 1L)
  )
  status <- attr(output, "status") %||% 0L
  list(status = status, output = paste(output, collapse = "\n"))
}

first <- compile()
second <- if (first$status == 0L) compile() else first
if (first$status != 0L || second$status != 0L || !file.exists(file.path(build_dir, "main.pdf"))) {
  detail <- second$output
  detail_lines <- strsplit(detail, "\n", fixed = TRUE)[[1]]
  detail_tail <- tail(detail_lines, 60)
  stop("pdflatex failed while compiling main.tex:\n", paste(detail_tail, collapse = "\n"))
}

message("main.tex check passed: source structure verified and PDF compilation succeeded in a temporary directory.")
