#!/usr/bin/env Rscript

# Generate a restricted disclosure-controlled candidate. This step is not a
# release: it cannot move, publish, or attest to the output it creates.

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

cli <- parse_cli()
if (length(cli$flags) || !identical(names(cli$values), "manifest")) {
  stop("Release-candidate preparation requires exactly --manifest <analysis-manifest-path>.")
}
analysis_manifest_path <- option_value(cli, "manifest", required = TRUE)
if (path_uses_configured_restricted_root(analysis_manifest_path)) {
  require_restricted_operation_authorization(root, "release")
}
context <- validate_stage_manifest(analysis_manifest_path, "analysis")
if (!identical(context$manifest$mode, "real")) stop("Release-candidate preparation is unavailable for synthetic runs.")
require_restricted_operation_authorization(root, "release")
root_restricted <- restricted_root(root)
if (!path_within(context$run_dir, file.path(root_restricted, "runs"))) {
  stop("A real analysis manifest must reside under approved restricted storage.")
}
git <- git_metadata(root)
if (git$dirty || !is_git_commit(git$commit)) {
  stop("Release-candidate preparation requires a clean Git worktree with a resolved HEAD commit.")
}
policy <- read_release_policy(file.path(root, "config", "release-policy.yml"))
metadata <- read_metadata(root)
lineage <- validate_current_release_lineage(
  root,
  analysis_manifest_path,
  policy = policy,
  metadata = metadata,
  current_git_commit = git$commit
)
assert_release_policy_controls(policy, action = "Release rendering")
summary_descriptor <- context$manifest$outputs$structured_summary
if (is.null(summary_descriptor)) stop("Analysis manifest is missing the structured summary artifact.")
summary_path <- resolve_manifest_output(context$run_dir, summary_descriptor, "structured_summary")
summary_table <- read.csv(summary_path, check.names = FALSE, stringsAsFactors = FALSE, na.strings = "")
release <- conservative_suppress(
  summary_table,
  policy$minimum_cell_count,
  metadata = metadata,
  require_complete_universe = TRUE
)

write_csv_atomic <- function(table, path) {
  temporary <- paste0(path, ".tmp-", Sys.getpid())
  on.exit(unlink(temporary), add = TRUE)
  utils::write.csv(table, temporary, row.names = FALSE, na = "")
  if (!file.rename(temporary, path)) stop("Unable to atomically write release artifact.")
}

release_dir <- file.path(context$run_dir, "outputs", "release-candidate")
if (dir.exists(release_dir)) stop("Release-candidate directory already exists; candidates are immutable.")
release_parent <- dirname(release_dir)
dir.create(release_parent, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(release_parent)) stop("Unable to create the restricted release-output directory.")
staging_dir <- file.path(release_parent, paste0(".release-candidate.staging-", Sys.getpid()))
if (dir.exists(staging_dir)) stop("A prior incomplete release-candidate staging directory requires restricted review.")
dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(staging_dir)) stop("Unable to create the release-candidate staging directory.")
candidate_published <- FALSE
on.exit({
  if (!candidate_published && dir.exists(staging_dir)) unlink(staging_dir, recursive = TRUE, force = TRUE)
}, add = TRUE)

public_path <- file.path(staging_dir, "structured-summary-public.csv")
suppression_path <- file.path(staging_dir, "suppression-log.csv")
manuscript_path <- file.path(staging_dir, "generated-results.tex")
manifest_path <- file.path(staging_dir, "release-candidate-manifest.json")
write_csv_atomic(release$public, public_path)
write_csv_atomic(release$suppression_log, suppression_path)
writeLines(render_release_results_tex(release$public, metadata = metadata), manuscript_path, useBytes = TRUE)
manifest <- list(
  schema_version = "1.2",
  status = "candidate_generated_pending_manual_review",
  generated_at_utc = utc_now(),
  analysis_manifest_sha256 = sha256_file(analysis_manifest_path),
  analysis_manifest_relative_path = "manifests/03-analysis.json",
  release_policy_sha256 = policy$sha256,
  analysis_baseline = list(
    git_commit = lineage$git_commit,
    lockfile_sha256 = lineage$lockfile_sha256,
    analysis_controls = lineage$analysis_controls
  ),
  generator = list(git_commit = git$commit, script_sha256 = tracked_file_sha256(this_script)),
  release_universe = list(
    analysis_variants = "primary",
    excluded = c(
      "conditional reason item without verified routing",
      "sensitivity variants",
      "exploratory cross-tabs",
      "qualitative material",
      "respondent-level material"
    )
  ),
  outputs = list(
    structured_summary_public = candidate_output_descriptor(staging_dir, basename(public_path)),
    suppression_log = candidate_output_descriptor(staging_dir, basename(suppression_path)),
    manuscript_results = candidate_output_descriptor(staging_dir, basename(manuscript_path))
  ),
  suppression_groups = nrow(release$suppression_log)
)
write_json_atomic(manifest, manifest_path)
if (!file.rename(staging_dir, release_dir)) stop("Unable to atomically publish the restricted release candidate.")
candidate_published <- TRUE
message("Restricted release candidate prepared. It remains in restricted storage pending manual disclosure review and a manifest-bound attestation.")
