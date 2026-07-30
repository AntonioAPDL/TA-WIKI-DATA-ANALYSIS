testthat::test_that("a synthetic workbook exercises the complete real-mode candidate path", {
  testthat::skip_if(git_metadata(project_root)$dirty, "This end-to-end fixture requires a clean committed baseline.")

  restricted <- tempfile("ta-wiki-real-mode-fixture-")
  dir.create(restricted, recursive = TRUE)
  on.exit(unlink(restricted, recursive = TRUE, force = TRUE), add = TRUE)
  write_restricted_preflight_record(restricted)

  authorization_id <- fresh_run_id("fixture-auth")
  write_restricted_test_authorization(restricted, authorization_id = authorization_id)
  write_restricted_test_source_context(restricted, authorization_id = authorization_id)

  source_fixture <- read.csv(
    file.path(project_root, "tests", "synthetic-survey-fixture.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  metadata <- read_metadata(project_root)
  testthat::expect_identical(names(source_fixture), metadata$variable_map$analysis_name)
  source_fixture <- source_fixture[rep(seq_len(nrow(source_fixture)), length.out = 12L), , drop = FALSE]
  names(source_fixture) <- approved_live_headers(project_root)
  raw_dir <- file.path(restricted, "raw")
  dir.create(raw_dir, recursive = TRUE)
  workbook <- file.path(raw_dir, "TA Wiki Feedback Survey (Responses).xlsx")
  writexl::write_xlsx(source_fixture, workbook)
  restored_headers <- names(readxl::read_excel(workbook, .name_repair = "minimal"))
  testthat::expect_identical(restored_headers, approved_live_headers(project_root))

  previous_root <- Sys.getenv("TA_WIKI_RESTRICTED_ROOT", unset = NA_character_)
  previous_authorization <- Sys.getenv("TA_WIKI_GOVERNANCE_AUTHORIZATION_ID", unset = NA_character_)
  on.exit({
    if (is.na(previous_root)) Sys.unsetenv("TA_WIKI_RESTRICTED_ROOT") else Sys.setenv(TA_WIKI_RESTRICTED_ROOT = previous_root)
    if (is.na(previous_authorization)) Sys.unsetenv("TA_WIKI_GOVERNANCE_AUTHORIZATION_ID") else Sys.setenv(TA_WIKI_GOVERNANCE_AUTHORIZATION_ID = previous_authorization)
  }, add = TRUE)
  Sys.setenv(
    TA_WIKI_RESTRICTED_ROOT = restricted,
    TA_WIKI_GOVERNANCE_AUTHORIZATION_ID = authorization_id
  )

  freeze_id <- "fixture-freeze-001"
  run_id <- "fixture-real-001"
  run <- function(arguments) {
    command_status(rscript_bin, c(file.path(project_root, "scripts", "run.R"), arguments), wd = project_root)
  }

  intake <- run(c("intake", "--freeze-id", freeze_id))
  testthat::expect_equal(intake$status, 0L, info = intake$output)
  source_provenance <- file.path(restricted, "governance", "source-freezes", freeze_id, "source-provenance.json")
  testthat::expect_true(file.exists(source_provenance))

  validate <- run(c("validate", "--run-id", run_id, "--source-freeze-id", freeze_id))
  testthat::expect_equal(validate$status, 0L, info = validate$output)
  run_dir <- file.path(restricted, "runs", paste("real", run_id, sep = "-"))
  validation_manifest <- file.path(run_dir, "manifests", "01-validation.json")
  testthat::expect_true(file.exists(validation_manifest))
  validation_record <- read_manifest(validation_manifest)
  testthat::expect_identical(validation_record$schema_version, "1.2")
  testthat::expect_true(file.exists(file.path(run_dir, "derived", "cohort-ledger.csv")))
  testthat::expect_false(file.exists(file.path(run_dir, "derived", "validated-source.csv")))
  testthat::expect_false(file.exists(file.path(run_dir, "derived", "analysis-input.csv")))
  testthat::expect_false(grepl(
    "source_path|drive_file_id|drive_revision_id",
    jsonlite::toJSON(validation_record, auto_unbox = TRUE)
  ))

  transform <- run(c("transform", "--manifest", validation_manifest))
  testthat::expect_equal(transform$status, 0L, info = transform$output)
  transformation_manifest <- file.path(run_dir, "manifests", "02-transformation.json")
  testthat::expect_true(file.exists(transformation_manifest))

  analyze <- run(c("analyze", "--manifest", transformation_manifest))
  testthat::expect_equal(analyze$status, 0L, info = analyze$output)
  analysis_manifest <- file.path(run_dir, "manifests", "03-analysis.json")
  testthat::expect_true(file.exists(analysis_manifest))

  release <- run(c("release", "--manifest", analysis_manifest))
  testthat::expect_equal(release$status, 0L, info = release$output)
  candidate_dir <- file.path(run_dir, "outputs", "release-candidate")
  candidate_manifest <- file.path(candidate_dir, "release-candidate-manifest.json")
  testthat::expect_true(file.exists(candidate_manifest))
  testthat::expect_silent(validate_release_candidate_manifest(project_root, candidate_manifest))
  candidate_record <- read_manifest(candidate_manifest)
  testthat::expect_identical(candidate_record$schema_version, "1.2")
  testthat::expect_identical(candidate_record$analysis_baseline$git_commit, git_metadata(project_root)$commit)
  testthat::expect_identical(
    candidate_record$analysis_baseline$lockfile_sha256,
    tracked_file_sha256(file.path(project_root, "renv.lock"))
  )
  testthat::expect_identical(
    candidate_record$analysis_baseline$analysis_controls,
    analysis_control_fingerprint(project_root)
  )

  tampered_candidate <- candidate_record
  tampered_candidate$analysis_baseline$analysis_controls$files[[1L]] <- paste(rep("0", 64L), collapse = "")
  jsonlite::write_json(tampered_candidate, candidate_manifest, auto_unbox = TRUE, pretty = TRUE)
  testthat::expect_error(
    validate_release_candidate_manifest(project_root, candidate_manifest, require_clean_worktree = FALSE),
    "analytical-control fingerprint"
  )
  jsonlite::write_json(candidate_record, candidate_manifest, auto_unbox = TRUE, pretty = TRUE)

  candidate_for_verification <- validate_release_candidate_manifest(
    project_root, candidate_manifest, authorization_action = "verify-release"
  )
  candidate_for_build <- validate_release_candidate_manifest(
    project_root, candidate_manifest, authorization_action = "manuscript-attested-build"
  )
  testthat::expect_false(identical(
    candidate_for_verification$authorization$action,
    candidate_for_build$authorization$action
  ))
  testthat::expect_identical(
    authorization_provenance_descriptor(candidate_for_verification$authorization),
    authorization_provenance_descriptor(candidate_for_build$authorization)
  )

  approval_id <- "fixture-approval-001"
  attestation_dir <- file.path(restricted, "governance", "release-attestations")
  verification_dir <- file.path(restricted, "governance", "release-verifications")
  dir.create(attestation_dir, recursive = TRUE)
  dir.create(verification_dir, recursive = TRUE)
  attestation_path <- file.path(attestation_dir, paste0(approval_id, ".json"))
  jsonlite::write_json(list(
    schema_version = "1.1",
    status = "approved",
    manual_disclosure_review = TRUE,
    pi_approval_confirmed = TRUE,
    pi_approval_reference = "synthetic-test-only",
    candidate_manifest_sha256 = candidate_for_verification$sha256,
    analysis_manifest_sha256 = candidate_for_verification$manifest$analysis_manifest_sha256,
    release_policy_sha256 = candidate_for_verification$manifest$release_policy_sha256,
    candidate_output_sha256 = as.list(candidate_for_verification$output_hashes)
  ), attestation_path, auto_unbox = TRUE, pretty = TRUE)
  attestation <- read_release_attestation(
    project_root, approval_id, candidate_for_verification,
    authorization_action = "verify-release",
    authorization = candidate_for_verification$authorization
  )

  verification_path <- file.path(verification_dir, paste0(approval_id, ".json"))
  verification_record <- list(
    schema_version = "1.2",
    status = "approved_candidate_verified_pending_external_delivery",
    candidate_manifest_sha256 = candidate_for_verification$sha256,
    analysis_manifest_sha256 = candidate_for_verification$manifest$analysis_manifest_sha256,
    release_policy_sha256 = candidate_for_verification$manifest$release_policy_sha256,
    candidate_output_sha256 = as.list(candidate_for_verification$output_hashes),
    attestation = attestation,
    verifier = list(
      git_commit = git_metadata(project_root)$commit,
      script_sha256 = tracked_file_sha256(file.path(project_root, "scripts", "05_verify_release_attestation.R"))
    ),
    authorization = authorization_provenance_descriptor(candidate_for_verification$authorization)
  )
  jsonlite::write_json(verification_record, verification_path, auto_unbox = TRUE, pretty = TRUE)
  testthat::expect_silent(read_release_verification(
    project_root, approval_id, candidate_for_build, attestation,
    authorization_action = "manuscript-attested-build",
    authorization = candidate_for_build$authorization
  ))
  verification_record$authorization$record_sha256 <- paste(rep("e", 64L), collapse = "")
  jsonlite::write_json(verification_record, verification_path, auto_unbox = TRUE, pretty = TRUE)
  testthat::expect_error(
    read_release_verification(
      project_root, approval_id, candidate_for_build, attestation,
      authorization_action = "manuscript-attested-build",
      authorization = candidate_for_build$authorization
    ),
    "does not bind the exact candidate artifacts"
  )
  testthat::expect_identical(
    sort(list.files(candidate_dir)),
    sort(c(
      "generated-results.tex",
      "release-candidate-manifest.json",
      "structured-summary-public.csv",
      "suppression-log.csv"
    ))
  )
})
