testthat::test_that("restricted-root evidence is versioned and fail-closed", {
  restricted <- tempfile("ta-wiki-restricted-root-")
  dir.create(restricted, recursive = TRUE)
  on.exit(unlink(restricted, recursive = TRUE, force = TRUE), add = TRUE)
  write_restricted_preflight_record(restricted)
  previous <- Sys.getenv("TA_WIKI_RESTRICTED_ROOT", unset = NA_character_)
  on.exit({
    if (is.na(previous)) Sys.unsetenv("TA_WIKI_RESTRICTED_ROOT") else Sys.setenv(TA_WIKI_RESTRICTED_ROOT = previous)
  }, add = TRUE)
  Sys.setenv(TA_WIKI_RESTRICTED_ROOT = restricted)

  testthat::expect_identical(
    restricted_root(project_root),
    normalizePath(restricted, winslash = "/", mustWork = TRUE)
  )

  preflight_path <- file.path(restricted, "governance", "restricted-root-preflight.json")
  legacy <- jsonlite::read_json(preflight_path, simplifyVector = FALSE)
  legacy$schema_version <- "1.0"
  jsonlite::write_json(legacy, preflight_path, auto_unbox = TRUE)
  testthat::expect_error(restricted_root(project_root), "does not satisfy required path/access checks")
})

testthat::test_that("restricted operations require a signed off-repository authorization beyond preflight", {
  restricted <- tempfile("ta-wiki-restricted-authorization-")
  dir.create(restricted, recursive = TRUE)
  on.exit(unlink(restricted, recursive = TRUE, force = TRUE), add = TRUE)
  write_restricted_preflight_record(restricted)
  previous_root <- Sys.getenv("TA_WIKI_RESTRICTED_ROOT", unset = NA_character_)
  previous_authorization <- Sys.getenv("TA_WIKI_GOVERNANCE_AUTHORIZATION_ID", unset = NA_character_)
  on.exit({
    if (is.na(previous_root)) Sys.unsetenv("TA_WIKI_RESTRICTED_ROOT") else Sys.setenv(TA_WIKI_RESTRICTED_ROOT = previous_root)
    if (is.na(previous_authorization)) Sys.unsetenv("TA_WIKI_GOVERNANCE_AUTHORIZATION_ID") else Sys.setenv(TA_WIKI_GOVERNANCE_AUTHORIZATION_ID = previous_authorization)
  }, add = TRUE)
  Sys.setenv(TA_WIKI_RESTRICTED_ROOT = restricted)
  Sys.unsetenv("TA_WIKI_GOVERNANCE_AUTHORIZATION_ID")

  testthat::expect_error(
    require_restricted_operation_authorization(project_root, "intake"),
    "governance authorization is missing"
  )
  blocked_intake <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "run.R"), "intake", "--freeze-id", "test-intake")
  )
  testthat::expect_false(identical(blocked_intake$status, 0L))
  testthat::expect_match(blocked_intake$output, "governance authorization is missing", fixed = TRUE)

  authorization_id <- write_restricted_test_authorization(restricted)
  Sys.setenv(TA_WIKI_GOVERNANCE_AUTHORIZATION_ID = authorization_id)
  approved <- read_restricted_operation_authorization(project_root, "intake")
  testthat::expect_identical(approved$id, authorization_id)
  testthat::expect_identical(approved$action, "intake")
  testthat::expect_silent(require_restricted_operation_authorization(project_root, "validate"))

  testthat::expect_error(
    read_restricted_source_context(project_root, approved),
    "source-access context is missing"
  )
  write_restricted_test_source_context(restricted, authorization_id = authorization_id)
  source_context <- read_restricted_source_context(project_root, approved)
  testthat::expect_identical(source_context$source$id, "survey_final")
  testthat::expect_true(is_sha256_value(source_context$sha256))

  locator_argument <- command_status(
    rscript_bin,
    c(
      file.path(project_root, "scripts", "run.R"), "intake",
      "--freeze-id", "test-intake", "--drive-file-id", "not-accepted"
    )
  )
  testthat::expect_false(identical(locator_argument$status, 0L))
  testthat::expect_match(locator_argument$output, "Usage: Rscript scripts/run.R intake --freeze-id <id>", fixed = TRUE)
})

testthat::test_that("live-header contract rejects an ordered schema change without printing headers", {
  headers <- approved_live_headers(project_root)
  testthat::expect_silent(assert_live_header_contract(project_root, headers))
  changed <- headers
  changed[[1]] <- "different-header"
  testthat::expect_error(
    assert_live_header_contract(project_root, changed),
    "do not exactly match the approved manifest"
  )
})

testthat::test_that("generated timestamps use an unambiguous UTC ISO-8601 form", {
  testthat::expect_match(utc_now(), "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")
})

testthat::test_that("a source freeze preserves copied bytes after raw staging is unavailable", {
  restricted <- tempfile("ta-wiki-frozen-source-")
  dir.create(restricted, recursive = TRUE)
  on.exit(unlink(restricted, recursive = TRUE, force = TRUE), add = TRUE)
  write_restricted_preflight_record(restricted)
  previous_root <- Sys.getenv("TA_WIKI_RESTRICTED_ROOT", unset = NA_character_)
  on.exit({
    if (is.na(previous_root)) Sys.unsetenv("TA_WIKI_RESTRICTED_ROOT") else Sys.setenv(TA_WIKI_RESTRICTED_ROOT = previous_root)
  }, add = TRUE)
  Sys.setenv(TA_WIKI_RESTRICTED_ROOT = restricted)

  raw_dir <- file.path(restricted, "raw")
  dir.create(raw_dir, recursive = TRUE)
  raw_workbook <- file.path(raw_dir, "TA Wiki Feedback Survey (Responses).xlsx")
  writexl::write_xlsx(data.frame(safe_fixture = "synthetic", stringsAsFactors = FALSE), raw_workbook)
  staged_source <- restricted_source_workbook(project_root)

  freeze_id <- "test-frozen-source"
  freeze_parent <- file.path(restricted, "governance", "source-freezes")
  dir.create(freeze_parent, recursive = TRUE)
  outside_staging <- tempfile("ta-wiki-outside-freeze-")
  dir.create(outside_staging, recursive = TRUE)
  on.exit(unlink(outside_staging, recursive = TRUE, force = TRUE), add = TRUE)
  testthat::expect_error(
    copy_source_to_freeze_staging(project_root, staged_source, outside_staging),
    "staging directory must resolve inside approved restricted storage"
  )
  staging_dir <- file.path(freeze_parent, ".test-frozen-source.staging")
  dir.create(staging_dir, recursive = TRUE)
  altered_source <- staged_source
  altered_source$sha256 <- paste(rep("0", 64L), collapse = "")
  testthat::expect_error(
    copy_source_to_freeze_staging(project_root, altered_source, staging_dir),
    "source workbook changed before source-freeze copying"
  )
  frozen_source <- copy_source_to_freeze_staging(project_root, staged_source, staging_dir)
  testthat::expect_true(file.exists(frozen_source$path))
  testthat::expect_identical(frozen_source$sha256, staged_source$sha256)

  header_path <- file.path(staging_dir, "candidate-live-header-manifest.csv")
  utils::write.csv(
    data.frame(source_header = approved_live_headers(project_root), stringsAsFactors = FALSE),
    header_path,
    row.names = FALSE,
    na = ""
  )
  profile_path <- file.path(staging_dir, "schema-profile.json")
  jsonlite::write_json(list(schema_version = "test"), profile_path, auto_unbox = TRUE)
  provenance <- list(
    schema_version = "1.2",
    status = "frozen",
    freeze_id = freeze_id,
    generated_at_utc = utc_now(),
    governance_authorization = list(
      id = "test-authorization",
      record_sha256 = paste(rep("a", 64L), collapse = ""),
      signed_artifact_sha256 = paste(rep("b", 64L), collapse = "")
    ),
    source_access_context_sha256 = paste(rep("c", 64L), collapse = ""),
    source_access_record_reference = "synthetic-source-access-record",
    source = list(
      id = "survey_final",
      filename = basename(real_source_path(project_root)),
      frozen_filename = basename(frozen_source$path),
      sha256 = frozen_source$sha256,
      bytes = frozen_source$bytes,
      drive_file_id = "synthetic-drive-file-id",
      drive_revision_id = "synthetic-drive-revision-id"
    ),
    artifacts = list(
      frozen_workbook = list(filename = basename(frozen_source$path), sha256 = frozen_source$sha256),
      candidate_header_manifest = list(filename = basename(header_path), sha256 = sha256_file(header_path)),
      schema_profile = list(filename = basename(profile_path), sha256 = sha256_file(profile_path))
    )
  )
  jsonlite::write_json(provenance, file.path(staging_dir, "source-provenance.json"), auto_unbox = TRUE, pretty = TRUE)
  freeze_dir <- file.path(freeze_parent, freeze_id)
  testthat::expect_true(file.rename(staging_dir, freeze_dir))

  unlink(raw_workbook, force = TRUE)
  evidence <- source_freeze_evidence(project_root, freeze_id)
  testthat::expect_identical(evidence$source_path, normalizePath(frozen_source_workbook_path(project_root, freeze_id), winslash = "/", mustWork = TRUE))
  testthat::expect_identical(evidence$source_sha256, frozen_source$sha256)

  writeBin(charToRaw("tampered"), evidence$source_path)
  testthat::expect_error(
    source_freeze_evidence(project_root, freeze_id),
    "invalid frozen_workbook artifact|does not match the frozen workbook bytes"
  )
})
