testthat::test_that("the runner provides command help", {
  result <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "run.R"), "help")
  )
  testthat::expect_equal(result$status, 0L, info = result$output)
  testthat::expect_match(result$output, "Usage: Rscript scripts/run.R <command>", fixed = TRUE)
  testthat::expect_match(result$output, "manuscript-preview", fixed = TRUE)
  testthat::expect_match(result$output, "manuscript-attested-build", fixed = TRUE)
  testthat::expect_match(result$output, "reproduce-results", fixed = TRUE)
  testthat::expect_match(result$output, "readiness", fixed = TRUE)
})

testthat::test_that("readiness reports technical state without asserting manual approval", {
  previous <- Sys.getenv("TA_WIKI_RESTRICTED_ROOT", unset = NA_character_)
  on.exit({
    if (is.na(previous)) Sys.unsetenv("TA_WIKI_RESTRICTED_ROOT") else Sys.setenv(TA_WIKI_RESTRICTED_ROOT = previous)
  }, add = TRUE)
  Sys.unsetenv("TA_WIKI_RESTRICTED_ROOT")
  result <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "run.R"), "readiness")
  )
  testthat::expect_equal(result$status, 0L, info = result$output)
  testthat::expect_match(result$output, '"status": "technical_readiness_only"', fixed = TRUE)
  testthat::expect_match(result$output, '"governance_authorization": "signed_record_and_human_authority_required"', fixed = TRUE)
  testthat::expect_match(result$output, '"record_and_signed_artifact_machine_checks_passed": false', fixed = TRUE)
  testthat::expect_match(result$output, '"restricted_intake": false', fixed = TRUE)
  testthat::expect_match(result$output, '"minimum_cell_count_configured": true', fixed = TRUE)
})

testthat::test_that("readiness keeps release readiness scoped to release authorization", {
  restricted <- tempfile("ta-wiki-readiness-restricted-")
  dir.create(restricted, recursive = TRUE)
  on.exit(unlink(restricted, recursive = TRUE, force = TRUE), add = TRUE)
  write_restricted_preflight_record(restricted)
  authorization_id <- write_restricted_test_authorization(
    restricted,
    operations = "intake"
  )
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
  result <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "run.R"), "readiness")
  )
  testthat::expect_equal(result$status, 0L, info = result$output)
  start <- regexpr("\\{", result$output)[[1]]
  testthat::expect_true(start > 0L, info = result$output)
  report <- jsonlite::fromJSON(substr(result$output, start, nchar(result$output)))
  testthat::expect_true(report$intake_authorization$record_and_signed_artifact_machine_checks_passed)
  testthat::expect_false(report$release_authorization$record_and_signed_artifact_machine_checks_passed)
  testthat::expect_false(report$technical_prerequisites$release_candidate)
})
