#!/usr/bin/env Rscript

# Record a byte-hash-only snapshot after an authorized manual qualitative
# coding/adjudication round. The command never prints or moves workspace text.

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
activate_project(root)
source(file.path(root, "scripts", "lib", "restricted_root.R"))
source(file.path(root, "scripts", "lib", "run_manifest.R"))

cli <- parse_cli()
if (length(cli$flags) || !identical(sort(names(cli$values)), c("governance-reference", "snapshot-id", "workspace"))) {
  stop("Qualitative snapshot requires --workspace <restricted-workspace> --snapshot-id <id> --governance-reference <restricted-record-id>.")
}
workspace_arg <- option_value(cli, "workspace", required = TRUE)
snapshot_id <- validate_run_id(option_value(cli, "snapshot-id", required = TRUE))
governance_reference <- validate_run_id(option_value(cli, "governance-reference", required = TRUE))
require_restricted_operation_authorization(root, "qualitative-snapshot")
if (git_metadata(root)$dirty) stop("Qualitative snapshot requires a clean Git worktree.")
restricted <- restricted_root(root)
if (!dir.exists(workspace_arg)) stop("Qualitative workspace does not exist.")
workspace <- normalizePath(workspace_arg, winslash = "/", mustWork = TRUE)
if (!path_within(workspace, file.path(restricted, "runs"))) {
  stop("Qualitative workspace must reside under approved restricted storage.")
}
template_path <- file.path(workspace, "qualitative-workspace-template.json")
if (!file.exists(template_path)) stop("Qualitative workspace template manifest is missing.")
template <- tryCatch(jsonlite::read_json(template_path, simplifyVector = FALSE), error = function(error) NULL)
if (is.null(template) || !identical(template$schema_version, "1.1") ||
    !identical(template$status, "template_prepared_no_open_text_processed") ||
    !is.character(template$transformation_manifest_sha256) || length(template$transformation_manifest_sha256) != 1L) {
  stop("Qualitative workspace template manifest has an unsupported schema.")
}
artifact_names <- c(
  "qualitative-codebook.csv",
  "coding-ledger.csv",
  "theme-audit.csv",
  "qualitative-disclosure-review.csv",
  "README.md"
)
artifact_paths <- file.path(workspace, artifact_names)
if (!all(file.exists(artifact_paths))) stop("Qualitative workspace is missing one or more required artifacts.")
snapshot_dir <- file.path(workspace, "snapshots")
dir.create(snapshot_dir, recursive = TRUE, showWarnings = FALSE)
snapshot_path <- file.path(snapshot_dir, paste0(snapshot_id, ".json"))
if (file.exists(snapshot_path)) stop("Qualitative snapshot ID already exists for this workspace.")
artifacts <- stats::setNames(lapply(artifact_paths, function(path) list(filename = basename(path), sha256 = sha256_file(path))), artifact_names)
write_json_atomic(list(
  schema_version = "1.1",
  status = "restricted_manual_coding_snapshot_recorded",
  generated_at_utc = utc_now(),
  snapshot_id = snapshot_id,
  governance_reference = governance_reference,
  workspace_template_sha256 = sha256_file(template_path),
  transformation_manifest_sha256 = template$transformation_manifest_sha256,
  qualitative_protocol_sha256 = template$qualitative_protocol_sha256,
  artifacts = artifacts,
  recorder = list(git_commit = git_metadata(root)$commit, script_sha256 = sha256_file(this_script))
), snapshot_path)
message("Restricted qualitative snapshot recorded without printing workspace content.")
