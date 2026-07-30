#!/usr/bin/env Rscript

# Build a restricted manuscript-integration PDF from an attested, exact
# disclosure candidate. This command never copies candidate material into the
# repository, a local preview, or an external destination.

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
activate_project(root)
source(file.path(root, "scripts", "lib", "restricted_root.R"))
source(file.path(root, "scripts", "lib", "run_manifest.R"))
source(file.path(root, "scripts", "lib", "metadata.R"))
source(file.path(root, "scripts", "lib", "analysis_controls.R"))
source(file.path(root, "scripts", "lib", "disclosure.R"))
require_manifest_packages()

cli <- parse_cli()
required_options <- c("approval-id", "candidate-manifest")
if (length(cli$flags) || !identical(sort(names(cli$values)), required_options)) {
  stop(
    "Usage: Rscript scripts/run.R manuscript-attested-build ",
    "--candidate-manifest <restricted-release-candidate-manifest.json> ",
    "--approval-id <restricted-attestation-id>"
  )
}

candidate_manifest_path <- option_value(cli, "candidate-manifest", required = TRUE)
approval_id <- option_value(cli, "approval-id", required = TRUE)
git <- git_metadata(root)
if (git$dirty || !is_git_commit(git$commit)) {
  stop("Attested manuscript builds require a clean Git worktree with a resolved HEAD commit.")
}

restricted <- restricted_root(root)
policy <- read_release_policy(file.path(root, "config", "release-policy.yml"))
candidate <- validate_release_candidate_manifest(
  root,
  candidate_manifest_path,
  policy = policy,
  metadata = read_metadata(root),
  current_git_commit = git$commit,
  authorization_action = "manuscript-attested-build"
)
attestation <- read_release_attestation(
  root, approval_id, candidate,
  authorization_action = "manuscript-attested-build",
  authorization = candidate$authorization
)
verification <- read_release_verification(
  root, approval_id, candidate, attestation,
  authorization_action = "manuscript-attested-build",
  authorization = candidate$authorization
)

git_path <- Sys.which("git")
if (!nzchar(git_path)) git_path <- "C:/Program Files/Git/cmd/git.exe"
assert_tracked_head <- function(path, relative_path, label) {
  tracked <- run_command(
    git_path,
    c("-C", root, "ls-files", "--error-unmatch", "--", relative_path),
    root
  )
  if (tracked$status != 0L) stop(label, " must be Git-tracked.")
  clean <- run_command(git_path, c("-C", root, "diff", "--quiet", "HEAD", "--", relative_path), root)
  if (clean$status == 1L) stop(label, " must match HEAD before an attested manuscript build.")
  if (clean$status != 0L) stop("Unable to verify the Git snapshot for ", label, ".")
  invisible(normalizePath(path, winslash = "/", mustWork = TRUE))
}

article_path <- assert_tracked_head(
  file.path(root, "manuscript", "article.tex"),
  "manuscript/article.tex",
  "The manuscript article source"
)
placeholder_path <- assert_tracked_head(
  file.path(root, "manuscript", "generated-results.tex"),
  "manuscript/generated-results.tex",
  "The tracked results placeholder"
)
placeholder_text <- paste(readLines(placeholder_path, warn = FALSE), collapse = "\n")
placeholder_marker <- "no disclosure-approved numerical result artifact is currently available for this manuscript"
placeholder_normalized <- tolower(gsub("[[:space:]]+", " ", placeholder_text))
if (!grepl(placeholder_marker, placeholder_normalized, fixed = TRUE) ||
    grepl("[0-9]", placeholder_text)) {
  stop("The tracked manuscript results input must remain the nonnumeric placeholder; do not place approved results in Git.")
}

article_lines <- readLines(article_path, warn = FALSE)
import_lines <- trimws(article_lines[grepl("\\\\(?:input|include)\\s*\\{", article_lines, perl = TRUE)])
if (!identical(import_lines, "\\input{generated-results.tex}")) {
  stop("The attested manuscript builder supports only the controlled generated-results.tex import in article.tex.")
}
maketitle_line <- which(trimws(article_lines) == "\\maketitle")
if (length(maketitle_line) != 1L) {
  stop("The attested manuscript builder could not locate the manuscript title command.")
}

results_descriptor <- candidate$manifest$outputs$manuscript_results
results_path <- candidate_output_descriptor(candidate$directory, results_descriptor$filename)
if (!identical(results_path$sha256, candidate$output_hashes[["manuscript_results"]])) {
  stop("The attested manuscript-results fragment does not match the verified candidate manifest.")
}
results_file <- file.path(candidate$directory, results_descriptor$filename)
results_lines <- readLines(results_file, warn = FALSE)
if (!length(results_lines) ||
    !identical(results_lines[[1]], "% Generated only from a restricted disclosure-controlled release candidate.")) {
  stop("The attested manuscript-results fragment has an unsupported generated-content marker.")
}
unsafe_fragment <- c(
  "\\\\(?:input|include|openout|write|immediate|newwrite|read|usepackage|documentclass)\\b",
  "\\\\end\\s*\\{document\\}"
)
if (any(vapply(unsafe_fragment, function(pattern) any(grepl(pattern, results_lines, perl = TRUE)), logical(1)))) {
  stop("The attested manuscript-results fragment contains an unsupported TeX command.")
}

configured_engine <- Sys.getenv("TA_WIKI_PDFLATEX", unset = "")
engine_candidates <- unique(c(configured_engine, Sys.which("pdflatex")))
engine_candidates <- engine_candidates[nzchar(engine_candidates)]
if (!length(engine_candidates)) {
  stop(
    "pdflatex is required for the restricted attested manuscript build. Put it on PATH or set TA_WIKI_PDFLATEX to its executable path. ",
    "This command does not install a TeX distribution or make an external delivery."
  )
}
resolve_engine <- function(candidate_path) {
  if (file.exists(candidate_path)) return(normalizePath(candidate_path, winslash = "/", mustWork = TRUE))
  found <- Sys.which(candidate_path)
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
  stop("Unable to execute pdflatex at the configured path.")
}

build_parent <- file.path(restricted, "reports", "manuscript-builds")
dir.create(build_parent, recursive = TRUE, showWarnings = FALSE)
build_parent <- normalizePath(build_parent, winslash = "/", mustWork = TRUE)
if (!path_within(build_parent, restricted)) stop("Restricted manuscript-build output path is unsafe.")
build_name <- paste0("attested-", attestation$id, "-", substr(candidate$sha256, 1L, 12L))
destination <- file.path(build_parent, build_name)
if (dir.exists(destination) || file.exists(destination)) {
  stop("An immutable restricted manuscript-build record already exists for this attestation and candidate.")
}

stage_dir <- tempfile(paste0(".staging-", build_name, "-"), tmpdir = build_parent)
final_dir <- tempfile(paste0(".ready-", build_name, "-"), tmpdir = build_parent)
dir.create(stage_dir, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(stage_dir, recursive = TRUE, force = TRUE), add = TRUE)
on.exit(unlink(final_dir, recursive = TRUE, force = TRUE), add = TRUE)

staged_article <- file.path(stage_dir, "article.tex")
staged_results <- file.path(stage_dir, "generated-results.tex")
if (!isTRUE(file.copy(article_path, staged_article, overwrite = FALSE)) ||
    !isTRUE(file.copy(results_file, staged_results, overwrite = FALSE))) {
  stop("Unable to stage the restricted manuscript inputs.")
}
if (!identical(sha256_file(article_path), sha256_file(staged_article)) ||
    !identical(sha256_file(results_file), sha256_file(staged_results))) {
  stop("The restricted manuscript inputs changed while being staged.")
}
notice_path <- file.path(stage_dir, "attested-build-notice.tex")
writeLines(c(
  "\\begin{center}",
  "\\fbox{\\parbox{0.88\\linewidth}{\\centering\\textbf{Restricted attested-results integration build.} This PDF remains in approved restricted storage and is not submission-ready until manuscript facts, declarations, venue requirements, and an authorized delivery decision are complete.}}",
  "\\end{center}"
), notice_path, useBytes = TRUE)
staged_article_lines <- readLines(staged_article, warn = FALSE)
staged_article_lines <- append(staged_article_lines, "\\input{attested-build-notice.tex}", after = maketitle_line)
writeLines(staged_article_lines, staged_article, useBytes = TRUE)

previous_directory <- getwd()
on.exit(setwd(previous_directory), add = TRUE)
setwd(stage_dir)
compile_arguments <- c("-interaction=nonstopmode", "-halt-on-error", "-file-line-error", "-no-shell-escape", "article.tex")
compile_once <- function() {
  output <- tryCatch(
    system2(engine, compile_arguments, stdout = TRUE, stderr = TRUE),
    error = function(error) structure(conditionMessage(error), status = 1L)
  )
  status <- attr(output, "status") %||% 0L
  if (status != 0L) {
    detail <- paste(utils::tail(as.character(output), 30L), collapse = "\n")
    stop("pdflatex failed while compiling the restricted attested manuscript build:\n", detail)
  }
}
compile_once()
compile_once()
staged_pdf <- file.path(stage_dir, "article.pdf")
if (!file.exists(staged_pdf) || !isTRUE(file.info(staged_pdf)$size > 0L)) {
  stop("pdflatex completed without producing a nonempty restricted manuscript PDF.")
}
pdf_signature <- readBin(staged_pdf, what = "raw", n = 5L)
if (length(pdf_signature) != 5L || !identical(pdf_signature, charToRaw("%PDF-"))) {
  stop("pdflatex completed without producing a valid PDF signature.")
}

dir.create(final_dir, recursive = TRUE, showWarnings = FALSE)
final_pdf <- file.path(final_dir, "article-attested-results.pdf")
if (!file.copy(staged_pdf, final_pdf, overwrite = FALSE)) {
  stop("Unable to stage the restricted manuscript PDF for finalization.")
}
engine_version <- if (length(engine_probe)) trimws(as.character(engine_probe[[1]])) else "pdflatex"
record <- list(
  schema_version = if (identical(candidate$manifest$schema_version, "1.2")) "1.1" else "1.0",
  status = "attested_results_manuscript_build_not_submission_ready",
  generated_at_utc = utc_now(),
  lineage = list(
    candidate_manifest_sha256 = candidate$sha256,
    analysis_manifest_sha256 = candidate$manifest$analysis_manifest_sha256,
    release_policy_sha256 = candidate$manifest$release_policy_sha256,
    candidate_output_sha256 = as.list(candidate$output_hashes),
    attestation = attestation,
    verification = verification
  ),
  source = list(
    editorial_git_commit = git$commit,
    article_git_blob_sha256 = tracked_file_sha256(article_path),
    article_checkout_sha256 = sha256_file(article_path),
    tracked_results_placeholder_git_blob_sha256 = tracked_file_sha256(placeholder_path),
    attested_results_sha256 = sha256_file(results_file),
    build_notice_sha256 = sha256_file(notice_path),
    staged_article_sha256 = sha256_file(staged_article),
    builder_script_git_blob_sha256 = tracked_file_sha256(this_script)
  ),
  build = list(
    engine = basename(engine),
    engine_sha256 = sha256_file(engine),
    engine_version = engine_version,
    compile_arguments = compile_arguments,
    passes = 2L,
    git = git
  ),
  output = list(
    relative_path = file.path("reports", "manuscript-builds", build_name, basename(final_pdf)),
    sha256 = sha256_file(final_pdf),
    bytes = unname(file.info(final_pdf)$size)
  )
)
write_json_atomic(record, file.path(final_dir, "article-attested-results.build.json"))
if (!file.rename(final_dir, destination)) {
  stop("Unable to finalize the immutable restricted manuscript-build record.")
}

message("Restricted attested-results manuscript build completed: ", file.path("reports", "manuscript-builds", build_name))
message("The PDF and build record remain in restricted storage and are not submission-ready or externally delivered.")
