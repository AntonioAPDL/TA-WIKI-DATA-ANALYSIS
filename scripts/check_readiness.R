#!/usr/bin/env Rscript

# Report technical readiness without accessing respondent data or treating a
# local check as governance approval. This command is intentionally read-only.

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
activate_project(root)
source(file.path(root, "scripts", "lib", "restricted_root.R"))
source(file.path(root, "scripts", "lib", "run_manifest.R"))
source(file.path(root, "scripts", "lib", "disclosure.R"))

cli <- parse_cli()
if (length(cli$flags) || length(cli$values)) {
  stop("Usage: Rscript scripts/run.R readiness")
}

policy <- tryCatch(read_release_policy(file.path(root, "config", "release-policy.yml")), error = function(error) NULL)
root_configured <- nzchar(Sys.getenv("TA_WIKI_RESTRICTED_ROOT", unset = ""))
root_check <- tryCatch({
  restricted_root(root)
  TRUE
}, error = function(error) FALSE)
authorization_id_configured <- nzchar(Sys.getenv("TA_WIKI_GOVERNANCE_AUTHORIZATION_ID", unset = ""))
intake_authorization_record_checks_passed <- tryCatch({
  read_restricted_operation_authorization(root, "intake")
  TRUE
}, error = function(error) FALSE)
release_authorization_record_checks_passed <- tryCatch({
  read_restricted_operation_authorization(root, "release")
  TRUE
}, error = function(error) FALSE)
git <- git_metadata(root)
controls_enabled <- !is.null(policy) && !is.na(policy$minimum_cell_count) &&
  all(vapply(c(
    "permitted_only_after_pi_approval",
    "require_manual_disclosure_review",
    "suppress_free_text",
    "suppress_timestamps",
    "suppress_respondent_level_rows",
    "internal_outputs_git_ignored",
    "internal_outputs_may_contain_small_cells"
  ), function(name) isTRUE(policy[[name]]), logical(1)))

report <- list(
  schema_version = "1.0",
  status = "technical_readiness_only",
  checked_at_utc = utc_now(),
  code = list(
    clean_worktree = !isTRUE(git$dirty),
    resolved_git_commit = is_git_commit(git$commit)
  ),
  restricted_root = list(
    configured = root_configured,
    machine_checks_passed = root_check
  ),
  intake_authorization = list(
    id_configured = authorization_id_configured,
    record_and_signed_artifact_machine_checks_passed = intake_authorization_record_checks_passed,
    human_signature_authenticity = "manual_confirmation_required",
    status = if (intake_authorization_record_checks_passed) {
      "record_machine_checks_passed_human_authority_not_machine_verifiable"
    } else {
      "not_ready"
    }
  ),
  release_authorization = list(
    record_and_signed_artifact_machine_checks_passed = release_authorization_record_checks_passed,
    human_signature_authenticity = "manual_confirmation_required",
    status = if (release_authorization_record_checks_passed) {
      "record_machine_checks_passed_human_authority_not_machine_verifiable"
    } else {
      "not_ready"
    }
  ),
  disclosure_policy = list(
    parsed = !is.null(policy),
    minimum_cell_count_configured = !is.null(policy) && !is.na(policy$minimum_cell_count),
    mandatory_controls_enabled = controls_enabled
  ),
  manual_gates = list(
    governance_authorization = "signed_record_and_human_authority_required",
    source_freeze = "not_checked",
    scientific_review = "not_checked",
    disclosure_attestation = "not_checked",
    approved_delivery_destination = "not_checked"
  ),
  technical_prerequisites = list(
    restricted_intake = !isTRUE(git$dirty) && root_check && intake_authorization_record_checks_passed,
    release_candidate = !isTRUE(git$dirty) && root_check && release_authorization_record_checks_passed && controls_enabled
  )
)

cat(jsonlite::toJSON(report, auto_unbox = TRUE, pretty = TRUE), "\n")
