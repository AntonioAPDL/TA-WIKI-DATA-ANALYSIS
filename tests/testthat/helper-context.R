project_root <- normalizePath(file.path(dirname(testthat::test_path()), "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(project_root, "scripts", "lib", "project_context.R"))
activate_project(project_root)
source(file.path(project_root, "scripts", "lib", "restricted_root.R"))
source(file.path(project_root, "scripts", "lib", "run_manifest.R"))
source(file.path(project_root, "scripts", "lib", "metadata.R"))
source(file.path(project_root, "scripts", "lib", "analysis_controls.R"))
source(file.path(project_root, "scripts", "lib", "disclosure.R"))
source(file.path(project_root, "scripts", "lib", "transformations.R"))

rscript_bin <- file.path(R.home("bin"), "Rscript")

command_status <- function(command, arguments, wd = tempdir()) {
  previous <- getwd()
  on.exit(setwd(previous), add = TRUE)
  setwd(wd)
  output <- suppressWarnings(system2(command, arguments, stdout = TRUE, stderr = TRUE))
  list(status = attr(output, "status") %||% 0L, output = paste(output, collapse = "\n"))
}

fresh_run_id <- function(prefix = "test") {
  paste(prefix, Sys.getpid(), as.integer(as.numeric(Sys.time())), sample.int(999999L, 1L), sep = "-")
}

write_restricted_preflight_record <- function(restricted_root) {
  governance <- file.path(restricted_root, "governance")
  dir.create(governance, recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(list(
    schema_version = "1.1",
    checked_at_utc = "2026-01-01T00:00:00Z",
    root_path_recorded = FALSE,
    dedicated_directory = TRUE,
    outside_repository = TRUE,
    outside_downloads = TRUE,
    git_worktree_checked = TRUE,
    is_git_worktree = FALSE,
    access_control_passed = TRUE
  ), file.path(governance, "restricted-root-preflight.json"), auto_unbox = TRUE)
}

# Test-only fixtures live under a temporary external restricted root.  They
# exercise record validation without representing a real authorization or
# institutional signature.
write_restricted_test_authorization <- function(restricted_root,
                                                authorized_project_root = project_root,
                                                authorization_id = "test-authorization",
                                                operations = names(restricted_operation_catalog())) {
  authorization_id <- validate_run_id(authorization_id)
  preflight_path <- file.path(restricted_root, "governance", "restricted-root-preflight.json")
  if (!file.exists(preflight_path)) stop("A test authorization requires a restricted-root preflight record.")
  authorization_dir <- file.path(restricted_root, "governance", "operating-authorizations")
  dir.create(authorization_dir, recursive = TRUE, showWarnings = FALSE)
  signed_filename <- paste0(authorization_id, ".signed.pdf")
  signed_path <- file.path(authorization_dir, signed_filename)
  writeLines(c("%PDF-1.4", "% synthetic test fixture; not an institutional approval"), signed_path, useBytes = TRUE)
  git <- git_metadata(authorized_project_root)
  jsonlite::write_json(list(
    schema_version = "1.0",
    record_type = "restricted_data_operating_authorization",
    authorization_id = authorization_id,
    status = "authorized",
    issued_at_utc = "2026-01-01T00:00:00Z",
    expires_at_utc = "2099-01-01T00:00:00Z",
    authorization_basis_reference = "synthetic-test-record-not-a-real-authorization",
    authorization_scope = list(
      authorized_operations = unname(operations),
      restricted_data_categories = unname(unique(restricted_operation_catalog())),
      authorized_git_commit = git$commit,
      restricted_root_preflight_sha256 = sha256_file(preflight_path),
      operating_controls = list(
        storage = TRUE,
        encryption = TRUE,
        backup = TRUE,
        retention = TRUE,
        incident_response = TRUE,
        access_roles = TRUE,
        analysis_scope = TRUE,
        sharing_scope = TRUE
      )
    ),
    human_signature = list(
      signer_name = "Synthetic test fixture",
      signer_role = "Test-only role",
      signed_at_utc = "2026-01-01T00:00:00Z",
      method = "institutional_e_signature",
      signed_artifact = list(
        filename = signed_filename,
        sha256 = sha256_file(signed_path)
      )
    )
  ), file.path(authorization_dir, paste0(authorization_id, ".json")), auto_unbox = TRUE, pretty = TRUE)
  authorization_id
}

write_restricted_test_source_context <- function(restricted_root,
                                                 authorized_project_root = project_root,
                                                 authorization_id = "test-authorization") {
  authorization_id <- validate_run_id(authorization_id)
  jsonlite::write_json(list(
    schema_version = "1.0",
    record_type = "restricted_source_access_context",
    status = "authorized_for_intake",
    recorded_at_utc = "2026-01-01T00:00:00Z",
    authorization_id = authorization_id,
    authorized_git_commit = git_metadata(authorized_project_root)$commit,
    source_access_record_reference = "synthetic-test-source-access-record",
    source = list(
      id = "survey_final",
      filename = "TA Wiki Feedback Survey (Responses).xlsx",
      drive_file_id = "synthetic-drive-file-id",
      drive_revision_id = "synthetic-drive-revision-id"
    )
  ), file.path(restricted_root, "governance", "source-access-context.json"), auto_unbox = TRUE, pretty = TRUE)
}

write_approved_test_policy <- function() {
  path <- tempfile(fileext = ".yml")
  lines <- readLines(file.path(project_root, "config", "release-policy.yml"), warn = FALSE)
  lines <- sub("minimum_cell_count: 5", "minimum_cell_count: 2", lines, fixed = TRUE)
  writeLines(lines, path, useBytes = TRUE)
  read_release_policy(path)
}

controlled_release_summary_fixture <- function(metadata = read_metadata(project_root)) {
  item <- "wiki_visited"
  item_info <- item_row(metadata, item)
  options <- scalar_codebook(metadata, item, item_info$item_type[[1]])
  data.frame(
    domain = rep(item_info$domain[[1]], nrow(options)),
    item = rep(item, nrow(options)),
    item_type = rep(item_info$item_type[[1]], nrow(options)),
    analysis_variant = rep("primary", nrow(options)),
    response = options$canonical_value,
    display_order = options$display_order,
    n = c(2L, 3L, 3L),
    denominator = rep(8L, nrow(options)),
    percent = c(25, 37.5, 37.5),
    stringsAsFactors = FALSE
  )
}

write_minimal_real_lineage <- function(run_dir, run_id = "test-001",
                                       schema = metadata_hashes(read_metadata(project_root)),
                                       analysis_outputs = NULL) {
  manifests <- file.path(run_dir, "manifests")
  dir.create(manifests, recursive = TRUE, showWarnings = FALSE)
  environment <- list(
    git_commit = git_metadata(project_root)$commit,
    git_dirty = FALSE,
    lockfile_sha256 = tracked_file_sha256(file.path(project_root, "renv.lock"))
  )
  source <- list(id = "survey_final", sha256 = paste(rep("c", 64L), collapse = ""))
  source_freeze <- list(
    id = "freeze-001",
    provenance_sha256 = paste(rep("d", 64L), collapse = ""),
    source_sha256 = source$sha256
  )
  validation_path <- file.path(manifests, "01-validation.json")
  jsonlite::write_json(list(
    schema_version = "1.1",
    stage = "validation",
    mode = "real",
    run_id = run_id,
    source = source,
    source_freeze = source_freeze,
    environment = environment,
    schema = schema
  ), validation_path, auto_unbox = TRUE)
  transformation_path <- file.path(manifests, "02-transformation.json")
  jsonlite::write_json(list(
    schema_version = "1.1",
    stage = "transformation",
    mode = "real",
    run_id = run_id,
    source = source,
    source_freeze = source_freeze,
    validation_manifest_sha256 = sha256_file(validation_path),
    environment = environment,
    schema = schema
  ), transformation_path, auto_unbox = TRUE)
  analysis_path <- file.path(manifests, "03-analysis.json")
  analysis_manifest <- list(
    schema_version = "1.1",
    stage = "analysis",
    mode = "real",
    run_id = run_id,
    source = source,
    source_freeze = source_freeze,
    transformation_manifest_sha256 = sha256_file(transformation_path),
    environment = environment,
    schema = schema
  )
  if (!is.null(analysis_outputs)) {
    analysis_manifest$outputs <- manifest_output_descriptors(run_dir, analysis_outputs)
  }
  jsonlite::write_json(analysis_manifest, analysis_path, auto_unbox = TRUE)
  list(validation = validation_path, transformation = transformation_path, analysis = analysis_path)
}
