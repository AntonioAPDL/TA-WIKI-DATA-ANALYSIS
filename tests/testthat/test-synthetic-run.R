testthat::test_that("synthetic validation, transformation, and analysis use manifest-bound lineage", {
  synthetic_root <- tempfile("ta-wiki-synthetic-")
  dir.create(synthetic_root, recursive = TRUE)
  run_id <- fresh_run_id("synthetic")
  validate <- command_status(
    rscript_bin,
    c(
      file.path(project_root, "scripts", "01_validate_input.R"),
      "--synthetic", "--run-id", run_id, "--synthetic-root", synthetic_root
    )
  )
  testthat::expect_equal(validate$status, 0L, info = validate$output)
  run_dir <- file.path(synthetic_root, paste("synthetic", run_id, sep = "-"))
  validation_manifest <- file.path(run_dir, "manifests", "01-validation.json")
  testthat::expect_true(file.exists(validation_manifest))
  manifest <- jsonlite::read_json(validation_manifest, simplifyVector = FALSE)
  testthat::expect_identical(manifest$mode, "synthetic")
  testthat::expect_identical(manifest$schema_version, "1.2")
  ledger_path <- file.path(run_dir, "derived", "cohort-ledger.csv")
  testthat::expect_true(file.exists(ledger_path))
  ledger <- read.csv(ledger_path, check.names = FALSE)
  testthat::expect_identical(
    names(ledger),
    c("record_id", "source_row", "consent_valid", "eligible_valid", "in_cohort")
  )
  testthat::expect_false(file.exists(file.path(run_dir, "derived", "validated-source.csv")))
  testthat::expect_false(file.exists(file.path(run_dir, "derived", "analysis-input.csv")))
  serialized_manifest <- jsonlite::toJSON(manifest, auto_unbox = TRUE)
  testthat::expect_false(grepl("source_path|drive_file_id|drive_revision_id", serialized_manifest))

  transform <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "02_transform.R"), "--manifest", validation_manifest)
  )
  testthat::expect_equal(transform$status, 0L, info = transform$output)
  transformation_manifest <- file.path(run_dir, "manifests", "02-transformation.json")
  testthat::expect_true(file.exists(transformation_manifest))

  analyze <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "02_analyze.R"), "--manifest", transformation_manifest)
  )
  testthat::expect_equal(analyze$status, 0L, info = analyze$output)
  output <- read.csv(file.path(run_dir, "outputs", "internal", "structured-item-summary.csv"), check.names = FALSE)
  testthat::expect_true(all(c("eligible_n", "applicable_n", "observed_valid_n", "invalid_n", "denominator", "percent") %in% names(output)))
  testthat::expect_true(file.exists(file.path(run_dir, "manifests", "03-analysis.json")))
  pair_summary <- read.csv(file.path(run_dir, "outputs", "internal", "exploratory-crosstab-summary.csv"), check.names = FALSE)
  testthat::expect_identical(
    names(pair_summary),
    c(
      "pair_id", "row_item", "column_item", "analysis_variant", "internal_only",
      "eligible_n", "row_applicable_n", "column_applicable_n", "pairwise_applicable_n",
      "row_valid_n", "column_valid_n", "pairwise_complete_n", "pairwise_excluded_n", "rationale"
    )
  )
  pair_cells <- read.csv(file.path(run_dir, "outputs", "internal", "exploratory-crosstabs.csv"), check.names = FALSE)
  testthat::expect_identical(
    names(pair_cells),
    c(
      "pair_id", "row_item", "row_analysis_variant", "row_response", "row_display_order",
      "column_item", "column_analysis_variant", "column_response", "column_display_order", "n", "pairwise_complete_n"
    )
  )
  if (nrow(pair_cells)) {
    testthat::expect_true(all(pair_cells$row_display_order >= 1L))
    testthat::expect_true(all(pair_cells$column_display_order >= 1L))
  }
})

testthat::test_that("transformation rejects a tampered validated source", {
  synthetic_root <- tempfile("ta-wiki-synthetic-")
  dir.create(synthetic_root, recursive = TRUE)
  run_id <- fresh_run_id("tamper")
  validate <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "01_validate_input.R"), "--synthetic", "--run-id", run_id, "--synthetic-root", synthetic_root)
  )
  testthat::expect_equal(validate$status, 0L, info = validate$output)
  run_dir <- file.path(synthetic_root, paste("synthetic", run_id, sep = "-"))
  validation_manifest <- file.path(run_dir, "manifests", "01-validation.json")
  input <- file.path(run_dir, "derived", "cohort-ledger.csv")
  writeLines(c(readLines(input, warn = FALSE), "tampered"), input)
  transform <- command_status(rscript_bin, c(file.path(project_root, "scripts", "02_transform.R"), "--manifest", validation_manifest))
  testthat::expect_false(identical(transform$status, 0L))
  testthat::expect_match(transform$output, "Output hash does not match", fixed = TRUE)
})

testthat::test_that("transformation rejects a validation manifest with a source locator field", {
  synthetic_root <- tempfile("ta-wiki-synthetic-")
  dir.create(synthetic_root, recursive = TRUE)
  run_id <- fresh_run_id("manifest-locator")
  validate <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "01_validate_input.R"), "--synthetic", "--run-id", run_id, "--synthetic-root", synthetic_root)
  )
  testthat::expect_equal(validate$status, 0L, info = validate$output)
  run_dir <- file.path(synthetic_root, paste("synthetic", run_id, sep = "-"))
  validation_manifest <- file.path(run_dir, "manifests", "01-validation.json")
  manifest <- jsonlite::read_json(validation_manifest, simplifyVector = FALSE)
  manifest$source$source_path <- "forbidden-locator"
  jsonlite::write_json(manifest, validation_manifest, auto_unbox = TRUE, pretty = TRUE, null = "null")
  transform <- command_status(rscript_bin, c(file.path(project_root, "scripts", "02_transform.R"), "--manifest", validation_manifest))
  testthat::expect_false(identical(transform$status, 0L))
  testthat::expect_match(transform$output, "unsupported locator field", fixed = TRUE)
})

testthat::test_that("safe XLSX fixture can be written and read in the locked environment", {
  fixture <- read.csv(file.path(project_root, "tests", "synthetic-survey-fixture.csv"), check.names = FALSE, stringsAsFactors = FALSE)
  path <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(fixture, path)
  restored <- readxl::read_excel(path, .name_repair = "minimal")
  testthat::expect_equal(nrow(restored), nrow(fixture))
  testthat::expect_equal(ncol(restored), ncol(fixture))
  testthat::expect_identical(names(restored), names(fixture))
})

testthat::test_that("restricted roots inside the repository or Downloads are rejected", {
  previous <- Sys.getenv("TA_WIKI_RESTRICTED_ROOT", unset = NA_character_)
  on.exit({
    if (is.na(previous)) Sys.unsetenv("TA_WIKI_RESTRICTED_ROOT") else Sys.setenv(TA_WIKI_RESTRICTED_ROOT = previous)
  }, add = TRUE)
  Sys.setenv(TA_WIKI_RESTRICTED_ROOT = project_root)
  testthat::expect_error(restricted_root(project_root), "outside the repository")
})

testthat::test_that("external roots require a passing preflight record", {
  candidate <- tempfile("ta-wiki-restricted-")
  dir.create(candidate, recursive = TRUE)
  previous <- Sys.getenv("TA_WIKI_RESTRICTED_ROOT", unset = NA_character_)
  on.exit({
    if (is.na(previous)) Sys.unsetenv("TA_WIKI_RESTRICTED_ROOT") else Sys.setenv(TA_WIKI_RESTRICTED_ROOT = previous)
  }, add = TRUE)
  Sys.setenv(TA_WIKI_RESTRICTED_ROOT = candidate)
  testthat::expect_error(restricted_root(project_root), "preflight record is missing")
})
