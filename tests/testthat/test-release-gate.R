testthat::test_that("release renderer remains fail-closed", {
  release <- command_status(rscript_bin, file.path(project_root, "scripts", "blocked_release_entrypoint.R"))
  testthat::expect_false(identical(release$status, 0L))
  testthat::expect_match(release$output, "blocked until the approved minimum_cell_count", fixed = TRUE)
})

testthat::test_that("authoritative release entry point rejects synthetic analysis without artifacts", {
  synthetic_root <- tempfile("ta-wiki-release-synthetic-")
  dir.create(synthetic_root, recursive = TRUE)
  run_id <- fresh_run_id("release")
  validate <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "run.R"), "validate", "--synthetic", "--run-id", run_id, "--synthetic-root", synthetic_root)
  )
  testthat::expect_equal(validate$status, 0L, info = validate$output)
  run_dir <- file.path(synthetic_root, paste("synthetic", run_id, sep = "-"))
  transformation_manifest <- file.path(run_dir, "manifests", "01-validation.json")
  transform <- command_status(rscript_bin, c(file.path(project_root, "scripts", "run.R"), "transform", "--manifest", transformation_manifest))
  testthat::expect_equal(transform$status, 0L, info = transform$output)
  analysis_manifest <- file.path(run_dir, "manifests", "02-transformation.json")
  analyze <- command_status(rscript_bin, c(file.path(project_root, "scripts", "run.R"), "analyze", "--manifest", analysis_manifest))
  testthat::expect_equal(analyze$status, 0L, info = analyze$output)
  release_manifest <- file.path(run_dir, "manifests", "03-analysis.json")
  release <- command_status(rscript_bin, c(file.path(project_root, "scripts", "run.R"), "release", "--manifest", release_manifest))
  testthat::expect_false(identical(release$status, 0L))
  testthat::expect_match(release$output, "unavailable for synthetic", fixed = TRUE)
  testthat::expect_false(dir.exists(file.path(run_dir, "outputs", "release-candidate")))
})

testthat::test_that("authoritative release entry point rejects stale real-analysis lineage before output creation", {
  testthat::skip_if(git_metadata(project_root)$dirty, "This command-level test requires a clean checkout.")
  restricted <- tempfile("ta-wiki-release-lineage-")
  dir.create(file.path(restricted, "governance"), recursive = TRUE)
  dir.create(file.path(restricted, "runs", "real-lineage-001", "manifests"), recursive = TRUE)
  write_restricted_preflight_record(restricted)
  previous <- Sys.getenv("TA_WIKI_RESTRICTED_ROOT", unset = NA_character_)
  previous_authorization <- Sys.getenv("TA_WIKI_GOVERNANCE_AUTHORIZATION_ID", unset = NA_character_)
  on.exit({
    if (is.na(previous)) Sys.unsetenv("TA_WIKI_RESTRICTED_ROOT") else Sys.setenv(TA_WIKI_RESTRICTED_ROOT = previous)
    if (is.na(previous_authorization)) Sys.unsetenv("TA_WIKI_GOVERNANCE_AUTHORIZATION_ID") else Sys.setenv(TA_WIKI_GOVERNANCE_AUTHORIZATION_ID = previous_authorization)
  }, add = TRUE)
  Sys.setenv(TA_WIKI_RESTRICTED_ROOT = restricted)
  Sys.setenv(TA_WIKI_GOVERNANCE_AUTHORIZATION_ID = write_restricted_test_authorization(restricted))

  run_dir <- file.path(restricted, "runs", "real-lineage-001")
  policy <- read_release_policy(file.path(project_root, "config", "release-policy.yml"))
  lineage <- write_minimal_real_lineage(run_dir, run_id = "lineage-001")

  analysis <- read_manifest(lineage$analysis)
  analysis$environment$git_commit <- paste(rep("0", 40L), collapse = "")
  jsonlite::write_json(analysis, lineage$analysis, auto_unbox = TRUE)
  stale_commit <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "run.R"), "release", "--manifest", lineage$analysis)
  )
  testthat::expect_false(identical(stale_commit$status, 0L))
  testthat::expect_match(stale_commit$output, "different Git commit", fixed = TRUE)

  lineage <- write_minimal_real_lineage(run_dir, run_id = "lineage-001")
  analysis <- read_manifest(lineage$analysis)
  analysis$schema$release_policy <- paste(rep("a", 64L), collapse = "")
  jsonlite::write_json(analysis, lineage$analysis, auto_unbox = TRUE)
  stale_policy <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "run.R"), "release", "--manifest", lineage$analysis)
  )
  testthat::expect_false(identical(stale_policy$status, 0L))
  testthat::expect_match(stale_policy$output, "Release policy changed", fixed = TRUE)

  lineage <- write_minimal_real_lineage(run_dir, run_id = "lineage-001")
  transformation <- read_manifest(lineage$transformation)
  transformation$environment$git_commit <- paste(rep("0", 40L), collapse = "")
  jsonlite::write_json(transformation, lineage$transformation, auto_unbox = TRUE)
  analysis <- read_manifest(lineage$analysis)
  analysis$transformation_manifest_sha256 <- sha256_file(lineage$transformation)
  jsonlite::write_json(analysis, lineage$analysis, auto_unbox = TRUE)
  stale_predecessor <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "run.R"), "release", "--manifest", lineage$analysis)
  )
  testthat::expect_false(identical(stale_predecessor$status, 0L))
  testthat::expect_match(stale_predecessor$output, "Transformation manifest was generated by a different Git commit", fixed = TRUE)
  testthat::expect_false(dir.exists(file.path(run_dir, "outputs", "release-candidate")))
})
