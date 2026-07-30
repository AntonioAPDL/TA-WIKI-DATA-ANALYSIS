#!/usr/bin/env Rscript

# Independent validation for the structured-only journal manuscript outputs.
# This script does not generate manuscript prose or tables. It checks the
# already-generated snapshot against source hashes and profile-specific
# exclusions so obvious drift is caught outside the builder.

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
activate_project(root)
source(file.path(dirname(this_script), "lib", "run_manifest.R"))

cli <- parse_cli()
if (length(setdiff(cli$flags, character()))) {
  stop("Unsupported flag(s): ", paste(cli$flags, collapse = ", "))
}

manuscript_dir <- option_value(cli, "manuscript-dir", default = file.path(root, "reports", "internal", "journal-manuscript"))
analysis_dir <- option_value(cli, "analysis-dir", default = file.path(root, "reports", "internal", "full-analysis"))
manuscript_dir <- normalizePath(manuscript_dir, winslash = "/", mustWork = TRUE)
analysis_dir <- normalizePath(analysis_dir, winslash = "/", mustWork = TRUE)

read_csv <- function(path) {
  if (!file.exists(path)) stop("Missing required artifact: ", path)
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE, na.strings = "")
}
as_num <- function(x) suppressWarnings(as.numeric(x))
failures <- character()
check <- function(ok, message) {
  if (!isTRUE(ok)) failures <<- c(failures, message)
}
source_hash_cache <- new.env(parent = emptyenv())
cached_sha256 <- function(path) {
  key <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (!exists(key, envir = source_hash_cache, inherits = FALSE)) {
    assign(key, sha256_file(key), envir = source_hash_cache)
  }
  get(key, envir = source_hash_cache, inherits = FALSE)
}

ledger <- read_csv(file.path(manuscript_dir, "journal-claim-ledger.csv"))
main_table <- read_csv(file.path(manuscript_dir, "main-table-engagement-indicators.csv"))
context_table <- read_csv(file.path(manuscript_dir, "main-table-survey-record-context.csv"))
build_record_path <- file.path(manuscript_dir, "journal-style-manuscript-build-record.json")
if (!file.exists(build_record_path)) stop("Missing build record: ", build_record_path)
build_record <- jsonlite::fromJSON(build_record_path, simplifyVector = FALSE)
md_path <- file.path(manuscript_dir, "journal-style-manuscript.md")
tex_path <- file.path(manuscript_dir, "journal-style-manuscript.tex")
md <- paste(readLines(md_path, warn = FALSE), collapse = "\n")
tex <- paste(readLines(tex_path, warn = FALSE), collapse = "\n")

required_ledger_cols <- c(
  "claim_id", "manuscript_location", "claim_class", "parent_claim_id",
  "routing_required", "raw_review_required", "source_row_key",
  "bundle_relative_source", "manuscript_profile", "coauthor_status"
)
check(all(required_ledger_cols %in% names(ledger)), "Claim ledger is missing one or more second-pass audit columns.")

for (i in seq_len(nrow(ledger))) {
  source_artifact <- ledger$source_artifact[[i]]
  if (!nzchar(source_artifact)) next
  source_path <- file.path(analysis_dir, source_artifact)
  check(file.exists(source_path), paste0("Claim ", ledger$claim_id[[i]], " source artifact is missing: ", source_artifact))
  if (file.exists(source_path) && nzchar(ledger$source_sha256[[i]])) {
    check(identical(cached_sha256(source_path), ledger$source_sha256[[i]]),
          paste0("Claim ", ledger$claim_id[[i]], " source SHA-256 mismatch."))
  }
}

check(nrow(context_table) == 4L, "Table 1 should contain four survey-record context rows.")
check(nrow(main_table) >= 10L && nrow(main_table) <= 11L, "Table 2 should contain approximately 10-11 central rows.")
check(!any(grepl("Scheduling conflict|editathon_nonparticipant_reasons", paste(main_table, collapse = " "), ignore.case = TRUE)),
      "Routing-dependent editathon reason appears in the main table.")
check(!grepl("Scheduling conflict|editathon_nonparticipant_reasons", md, ignore.case = TRUE),
      "Routing-dependent editathon reason appears in the manuscript Markdown.")
check(!grepl("reason-based sensitivity classification", md, ignore.case = TRUE),
      "Old sensitivity terminology appears in the manuscript Markdown.")
check(!grepl("reason-informed missing-response classification scenario", md, ignore.case = TRUE),
      "Reason-informed routing-dependent scenario appears in the manuscript Markdown instead of only the supplement/diagnostics.")
check(!grepl("Wiki content did they report wanting|desired Wiki content", md, ignore.case = TRUE),
      "General desired-feature item is still described as Wiki-specific content.")
check(!grepl("Before external circulation|current analytic package|accompanying audit materials", md, ignore.case = TRUE),
      "Rendered manuscript still contains audit/package/TODO language.")
old_front_matter_terms <- c(
  paste0("CONFID", "ENTIAL"),
  paste("NOT", "FOR", "EXTERNAL"),
  paste("Draft", "version"),
  paste(paste0("Confid", "ential"), "coauthor", "draft")
)
old_front_matter_pattern <- paste(old_front_matter_terms, collapse = "|")
check(!grepl(old_front_matter_pattern, md, ignore.case = TRUE) &&
        !grepl(old_front_matter_pattern, tex, ignore.case = TRUE),
      "Rendered manuscript should not contain front-matter warning banners or draft-status labels.")
check(!grepl("\\brespondents?\\b", md, ignore.case = TRUE),
      "Rendered manuscript should use survey records rather than respondents until uniqueness is verified.")
check(!grepl("Appendix C records contribution", md, ignore.case = TRUE),
      "Incorrect Appendix C contribution reference remains.")
check(!grepl("Appendix B|Contribution-status sensitivity", md, ignore.case = TRUE),
      "Redundant contribution appendix remains in the manuscript Markdown.")
check(!grepl("\\\\subsection\\{Table 1|\\\\subsection\\{Table 2", tex),
      "Tables are still rendered as TeX subsections.")
check(!grepl("\\\\scriptsize", tex),
      "Manuscript TeX still uses scriptsize tables.")
check(grepl("\\\\usepackage\\{float\\}", tex) && grepl("\\\\begin\\{table\\}\\[H\\]", tex),
      "Manuscript TeX should use nonfloating table placement so Table 2 cannot interrupt Discussion.")
check(grepl("\\\\usepackage\\{lineno\\}", tex) && grepl("\\\\linenumbers", tex),
      "Coauthor-review PDF should include line numbers.")
check(grepl("## References", md, fixed = TRUE) && grepl("\\\\section\\*\\{References\\}", tex),
      "Rendered manuscript should include a References section in Markdown and TeX.")
for (citation_anchor in c("AAPOR", "Eysenbach", "Freeman", "Sadera", "UNESCO", "von Elm")) {
  check(grepl(citation_anchor, md, fixed = TRUE),
        paste0("Rendered manuscript is missing citation anchor: ", citation_anchor))
}
check(!grepl("\\bTODO\\b|\\bplaceholder\\b|\\bpending\\b", md, ignore.case = TRUE),
      "Rendered manuscript should not contain TODO, placeholder, or pending language.")

direct_yes <- ledger[ledger$source_item == "contributed" & ledger$source_response == "Yes", , drop = FALSE]
direct_no <- ledger[ledger$source_item == "contributed" & ledger$source_response == "No", , drop = FALSE]
bound <- ledger[ledger$claim_class == "missing_response_bound", , drop = FALSE]
check(nrow(direct_yes) >= 1L && nrow(direct_no) >= 1L && nrow(bound) >= 1L,
      "Contribution direct Yes/No claims and missing-response bound must all be present.")
check(any(ledger$routing_required == "yes" & ledger$raw_review_required == "yes"),
      "Routing-dependent secondary claims should be explicitly marked as requiring raw/routing review.")

if (length(failures)) {
  stop("Journal manuscript validation failed:\n- ", paste(failures, collapse = "\n- "))
}

message("journal manuscript validation passed")
