#!/usr/bin/env Rscript

# Verify a human-created restricted attestation that binds the exact candidate
# bytes. Verification records approval evidence; it never publishes a file.

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
if (length(cli$flags) || !identical(sort(names(cli$values)), c("approval-id", "candidate-manifest"))) {
  stop("Release-attestation verification requires --candidate-manifest <path> --approval-id <restricted-attestation-id>.")
}
candidate_manifest_path <- option_value(cli, "candidate-manifest", required = TRUE)
approval_id <- option_value(cli, "approval-id", required = TRUE)
git <- git_metadata(root)
if (git$dirty || !is_git_commit(git$commit)) {
  stop("Release-attestation verification requires a clean Git worktree with a resolved HEAD commit.")
}
policy <- read_release_policy(file.path(root, "config", "release-policy.yml"))
candidate <- validate_release_candidate_manifest(
  root,
  candidate_manifest_path,
  policy = policy,
  metadata = read_metadata(root),
  current_git_commit = git$commit,
  authorization_action = "verify-release"
)
attestation <- read_release_attestation(
  root, approval_id, candidate,
  authorization_action = "verify-release",
  authorization = candidate$authorization
)
restricted <- restricted_root(root)
verification_dir <- file.path(restricted, "governance", "release-verifications")
dir.create(verification_dir, recursive = TRUE, showWarnings = FALSE)
verification_path <- file.path(verification_dir, paste0(attestation$id, ".json"))
if (file.exists(verification_path)) stop("A release-attestation verification already exists for this approval ID.")
write_json_atomic(list(
  schema_version = if (identical(candidate$manifest$schema_version, "1.2")) "1.2" else "1.1",
  status = "approved_candidate_verified_pending_external_delivery",
  generated_at_utc = utc_now(),
  candidate_manifest_sha256 = candidate$sha256,
  analysis_manifest_sha256 = candidate$manifest$analysis_manifest_sha256,
  release_policy_sha256 = candidate$manifest$release_policy_sha256,
  candidate_output_sha256 = as.list(candidate$output_hashes),
  attestation = attestation,
  verifier = list(git_commit = git$commit, script_sha256 = tracked_file_sha256(this_script)),
  authorization = authorization_provenance_descriptor(candidate$authorization)
), verification_path)
message("Restricted attestation verified. External delivery remains a separate, manual action under the approved release process.")
