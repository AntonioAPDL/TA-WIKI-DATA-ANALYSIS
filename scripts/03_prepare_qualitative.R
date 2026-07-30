#!/usr/bin/env Rscript

# Prepare a restricted-only manual qualitative workspace template. This task
# never reads, classifies, quotes, or releases open-text responses; authorized
# reviewers add content under the documented protocol after a separate review
# decision and record each completed coding round as a restricted snapshot.

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
activate_project(root)
source(file.path(root, "scripts", "lib", "restricted_root.R"))
source(file.path(root, "scripts", "lib", "run_manifest.R"))

cli <- parse_cli()
if (length(cli$flags) || !identical(names(cli$values), "manifest")) {
  stop("Qualitative workspace preparation requires exactly --manifest <transformation-manifest-path>.")
}
transformation_manifest_path <- option_value(cli, "manifest", required = TRUE)
if (path_uses_configured_restricted_root(transformation_manifest_path)) {
  require_restricted_operation_authorization(root, "qualitative")
}
manifest_context <- validate_stage_manifest(transformation_manifest_path, "transformation")
if (!identical(manifest_context$manifest$mode, "real")) stop("Qualitative workspace preparation is unavailable for synthetic runs.")
require_restricted_operation_authorization(root, "qualitative")
root_restricted <- restricted_root(root)
if (!path_within(manifest_context$run_dir, file.path(root_restricted, "runs"))) stop("A real transformation manifest must reside under approved restricted storage.")
if (git_metadata(root)$dirty) stop("Qualitative workspace preparation requires a clean Git worktree.")
context <- transform_manifest_input(
  transformation_manifest_path,
  authorization_action = "qualitative",
  project_root = root
)

workspace <- file.path(context$run_dir, "qualitative")
if (dir.exists(workspace) && length(list.files(workspace, all.files = TRUE, no.. = TRUE))) {
  stop("Qualitative workspace template already exists for this run.")
}
dir.create(workspace, recursive = TRUE, showWarnings = FALSE)
write_template <- function(table, filename) {
  path <- file.path(workspace, filename)
  utils::write.csv(table, path, row.names = FALSE, na = "")
  path
}
codebook_path <- write_template(data.frame(
  code_id = character(), parent_code = character(), definition = character(), inclusion_criteria = character(),
  exclusion_criteria = character(), example_reference = character(), status = character(), stringsAsFactors = FALSE
), "qualitative-codebook.csv")
ledger_path <- write_template(data.frame(
  source_field = character(), unit_id = character(), code_id = character(), reviewer_role = character(),
  coding_round = integer(), adjudication_status = character(), notes_reference = character(), stringsAsFactors = FALSE
), "coding-ledger.csv")
theme_path <- write_template(data.frame(
  theme_id = character(), theme_label = character(), supporting_unit_count = integer(),
  reviewer_status = character(), release_disposition = character(), stringsAsFactors = FALSE
), "theme-audit.csv")
review_path <- write_template(data.frame(
  artifact_id = character(), content_type = character(), linkage_risk = character(),
  quote_or_paraphrase = character(), disposition = character(), reviewer_status = character(), stringsAsFactors = FALSE
), "qualitative-disclosure-review.csv")
instructions_path <- file.path(workspace, "README.md")
writeLines(c(
  "# Restricted qualitative workspace",
  "",
  "Do not copy open text, quotes, respondent identifiers, or reviewer identities into the repository.",
  "Populate this workspace only under docs/qualitative-protocol.md and the applicable governance record.",
  "The default releasable output is an aggregate, disclosure-reviewed theme; direct quotations remain blocked unless separately approved.",
  "After each manual coding or adjudication round, record a restricted byte-hash snapshot with scripts/run.R qualitative-snapshot."
), instructions_path, useBytes = TRUE)
manifest_path <- file.path(workspace, "qualitative-workspace-template.json")
write_json_atomic(list(
  schema_version = "1.1",
  status = "template_prepared_no_open_text_processed",
  generated_at_utc = utc_now(),
  transformation_manifest_sha256 = sha256_file(transformation_manifest_path),
  qualitative_protocol_sha256 = sha256_file(file.path(root, "docs", "qualitative-protocol.md")),
  generator = list(git_commit = git_metadata(root)$commit, script_sha256 = sha256_file(this_script)),
  artifacts = lapply(list(codebook_path, ledger_path, theme_path, review_path, instructions_path), function(path) list(filename = basename(path), sha256 = sha256_file(path)))
), manifest_path)
message("Restricted qualitative workspace prepared without processing open text: ", workspace)
