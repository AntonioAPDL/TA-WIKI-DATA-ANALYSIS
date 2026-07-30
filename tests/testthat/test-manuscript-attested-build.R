make_attested_build_fixture <- function(repo, restricted_root) {
  fixture <- new.env(parent = globalenv())
  source(file.path(repo, "scripts", "lib", "project_context.R"), local = fixture)
  source(file.path(repo, "scripts", "lib", "restricted_root.R"), local = fixture)
  source(file.path(repo, "scripts", "lib", "run_manifest.R"), local = fixture)
  source(file.path(repo, "scripts", "lib", "metadata.R"), local = fixture)
  source(file.path(repo, "scripts", "lib", "disclosure.R"), local = fixture)

  dir.create(file.path(restricted_root, "governance", "release-attestations"), recursive = TRUE)
  dir.create(file.path(restricted_root, "governance", "release-verifications"), recursive = TRUE)
  jsonlite::write_json(list(
    schema_version = "1.1",
    checked_at_utc = "2026-01-01T00:00:00Z",
    root_path_recorded = FALSE,
    dedicated_directory = TRUE,
    access_control_passed = TRUE,
    outside_repository = TRUE,
    outside_downloads = TRUE,
    git_worktree_checked = TRUE,
    is_git_worktree = FALSE
  ), file.path(restricted_root, "governance", "restricted-root-preflight.json"), auto_unbox = TRUE)
  authorization_id <- Sys.getenv("TA_WIKI_GOVERNANCE_AUTHORIZATION_ID", unset = "")
  if (!nzchar(authorization_id)) stop("The isolated fixture requires a synthetic test authorization ID.")
  write_restricted_test_authorization(
    restricted_root,
    authorized_project_root = repo,
    authorization_id = authorization_id
  )

  run_dir <- file.path(restricted_root, "runs", "real-attested-build")
  manifests <- file.path(run_dir, "manifests")
  candidate_dir <- file.path(run_dir, "outputs", "release-candidate")
  dir.create(manifests, recursive = TRUE)
  dir.create(candidate_dir, recursive = TRUE)
  policy <- fixture$read_release_policy(file.path(repo, "config", "release-policy.yml"))
  metadata <- fixture$read_metadata(repo)
  environment <- list(
    git_commit = fixture$git_metadata(repo)$commit,
    git_dirty = FALSE,
    lockfile_sha256 = fixture$tracked_file_sha256(file.path(repo, "renv.lock"))
  )
  schema <- fixture$metadata_hashes(metadata)
  schema[["release_policy"]] <- policy$sha256
  source_record <- list(id = "survey_final", sha256 = paste(rep("c", 64L), collapse = ""))
  source_freeze <- list(
    id = "freeze-attested-build",
    provenance_sha256 = paste(rep("d", 64L), collapse = ""),
    source_sha256 = source_record$sha256
  )
  validation_path <- file.path(manifests, "01-validation.json")
  jsonlite::write_json(list(
    schema_version = "1.1",
    stage = "validation",
    mode = "real",
    run_id = "attested-build",
    source = source_record,
    source_freeze = source_freeze,
    environment = environment,
    schema = schema
  ), validation_path, auto_unbox = TRUE)
  transformation_path <- file.path(manifests, "02-transformation.json")
  jsonlite::write_json(list(
    schema_version = "1.1",
    stage = "transformation",
    mode = "real",
    run_id = "attested-build",
    source = source_record,
    source_freeze = source_freeze,
    validation_manifest_sha256 = fixture$sha256_file(validation_path),
    environment = environment,
    schema = schema
  ), transformation_path, auto_unbox = TRUE)
  item <- "wiki_visited"
  item_info <- fixture$item_row(metadata, item)
  options <- fixture$scalar_codebook(metadata, item, item_info$item_type[[1]])
  summary <- data.frame(
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
  summary_path <- file.path(run_dir, "outputs", "internal", "structured-item-summary.csv")
  dir.create(dirname(summary_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(summary, summary_path, row.names = FALSE)
  analysis_path <- file.path(manifests, "03-analysis.json")
  jsonlite::write_json(list(
    schema_version = "1.1",
    stage = "analysis",
    mode = "real",
    run_id = "attested-build",
    source = source_record,
    source_freeze = source_freeze,
    transformation_manifest_sha256 = fixture$sha256_file(transformation_path),
    environment = environment,
    schema = schema,
    outputs = fixture$manifest_output_descriptors(run_dir, list(structured_summary = summary_path))
  ), analysis_path, auto_unbox = TRUE)

  public_path <- file.path(candidate_dir, "structured-summary-public.csv")
  suppression_path <- file.path(candidate_dir, "suppression-log.csv")
  results_path <- file.path(candidate_dir, "generated-results.tex")
  release <- fixture$conservative_suppress(summary, policy$minimum_cell_count, metadata = metadata)
  utils::write.csv(release$public, public_path, row.names = FALSE, na = "")
  utils::write.csv(release$suppression_log, suppression_path, row.names = FALSE, na = "")
  writeLines(fixture$render_release_results_tex_v1_1(release$public), results_path, useBytes = TRUE)
  candidate_manifest_path <- file.path(candidate_dir, "release-candidate-manifest.json")
  candidate_manifest <- list(
    schema_version = "1.1",
    status = "candidate_generated_pending_manual_review",
    analysis_manifest_sha256 = fixture$sha256_file(analysis_path),
    analysis_manifest_relative_path = "manifests/03-analysis.json",
    release_policy_sha256 = policy$sha256,
    generator = list(
      git_commit = environment$git_commit,
      script_sha256 = fixture$tracked_file_sha256(file.path(repo, "scripts", "04_prepare_release.R"))
    ),
    release_universe = list(
      analysis_variants = "primary",
      excluded = c("sensitivity variants", "exploratory cross-tabs", "qualitative material", "respondent-level material")
    ),
    outputs = list(
      structured_summary_public = list(filename = basename(public_path), sha256 = fixture$sha256_file(public_path)),
      suppression_log = list(filename = basename(suppression_path), sha256 = fixture$sha256_file(suppression_path)),
      manuscript_results = list(filename = basename(results_path), sha256 = fixture$sha256_file(results_path))
    ),
    suppression_groups = nrow(release$suppression_log)
  )
  jsonlite::write_json(candidate_manifest, candidate_manifest_path, auto_unbox = TRUE, pretty = TRUE)
  candidate <- fixture$validate_release_candidate_manifest(repo, candidate_manifest_path, policy = policy, metadata = metadata)

  approval_id <- "approval-attested-build"
  attestation_path <- file.path(restricted_root, "governance", "release-attestations", paste0(approval_id, ".json"))
  jsonlite::write_json(list(
    schema_version = "1.1",
    status = "approved",
    manual_disclosure_review = TRUE,
    pi_approval_confirmed = TRUE,
    pi_approval_reference = "test-governance-record",
    candidate_manifest_sha256 = candidate$sha256,
    analysis_manifest_sha256 = candidate$manifest$analysis_manifest_sha256,
    release_policy_sha256 = candidate$manifest$release_policy_sha256,
    candidate_output_sha256 = as.list(candidate$output_hashes)
  ), attestation_path, auto_unbox = TRUE, pretty = TRUE)
  attestation <- fixture$read_release_attestation(repo, approval_id, candidate)
  verification_path <- file.path(restricted_root, "governance", "release-verifications", paste0(approval_id, ".json"))
  jsonlite::write_json(list(
    schema_version = "1.1",
    status = "approved_candidate_verified_pending_external_delivery",
    candidate_manifest_sha256 = candidate$sha256,
    analysis_manifest_sha256 = candidate$manifest$analysis_manifest_sha256,
    release_policy_sha256 = candidate$manifest$release_policy_sha256,
    candidate_output_sha256 = as.list(candidate$output_hashes),
    attestation = attestation,
    verifier = list(
      git_commit = environment$git_commit,
      script_sha256 = fixture$tracked_file_sha256(file.path(repo, "scripts", "05_verify_release_attestation.R"))
    )
  ), verification_path, auto_unbox = TRUE, pretty = TRUE)
  list(
    approval_id = approval_id,
    candidate_manifest_path = candidate_manifest_path,
    candidate_sha256 = candidate$sha256,
    results_sha256 = candidate$output_hashes[["manuscript_results"]]
  )
}

testthat::test_that("attested manuscript build is byte-bound and remains in restricted storage", {
  git <- Sys.which("git")
  if (!nzchar(git)) git <- "C:/Program Files/Git/cmd/git.exe"
  if (!file.exists(git)) testthat::skip("Git is required for the isolated attested-build integration test.")

  fixture_repo <- tempfile("ta-wiki-attested-build-repository-")
  restricted <- tempfile("ta-wiki-attested-build-restricted-")
  on.exit(unlink(fixture_repo, recursive = TRUE, force = TRUE), add = TRUE)
  on.exit(unlink(restricted, recursive = TRUE, force = TRUE), add = TRUE)
  cloned <- command_status(git, c("clone", "--no-local", project_root, fixture_repo), wd = tempdir())
  testthat::expect_equal(cloned$status, 0L, info = cloned$output)

  overlay_paths <- c(
    "config/release-policy.yml",
    "manuscript/article.tex",
    "manuscript/generated-results.tex",
    "scripts/build_attested_manuscript.R",
    "scripts/lib/disclosure.R",
    "scripts/lib/restricted_root.R",
    "scripts/run.R"
  )
  for (relative_path in overlay_paths) {
    source_path <- file.path(project_root, relative_path)
    destination_path <- file.path(fixture_repo, relative_path)
    dir.create(dirname(destination_path), recursive = TRUE, showWarnings = FALSE)
    testthat::expect_true(file.copy(source_path, destination_path, overwrite = TRUE))
  }
  fixture_policy_path <- file.path(fixture_repo, "config", "release-policy.yml")
  fixture_policy_lines <- readLines(fixture_policy_path, warn = FALSE)
  fixture_policy_lines <- sub("minimum_cell_count: 5", "minimum_cell_count: 2", fixture_policy_lines, fixed = TRUE)
  writeLines(fixture_policy_lines, fixture_policy_path, useBytes = TRUE)
  staged <- command_status(git, c("-C", fixture_repo, "add", "--", overlay_paths), wd = fixture_repo)
  testthat::expect_equal(staged$status, 0L, info = staged$output)
  committed <- command_status(git, c(
    "-C", fixture_repo,
    "-c", "user.name=TestFixture",
    "-c", "user.email=test-fixture@example.invalid",
    "commit", "-m", "attested-fixture"
  ), wd = fixture_repo)
  testthat::expect_equal(committed$status, 0L, info = committed$output)

  previous_root <- Sys.getenv("TA_WIKI_RESTRICTED_ROOT", unset = NA_character_)
  previous_authorization <- Sys.getenv("TA_WIKI_GOVERNANCE_AUTHORIZATION_ID", unset = NA_character_)
  previous_engine <- Sys.getenv("TA_WIKI_PDFLATEX", unset = NA_character_)
  on.exit({
    if (is.na(previous_root)) Sys.unsetenv("TA_WIKI_RESTRICTED_ROOT") else Sys.setenv(TA_WIKI_RESTRICTED_ROOT = previous_root)
    if (is.na(previous_authorization)) Sys.unsetenv("TA_WIKI_GOVERNANCE_AUTHORIZATION_ID") else Sys.setenv(TA_WIKI_GOVERNANCE_AUTHORIZATION_ID = previous_authorization)
    if (is.na(previous_engine)) Sys.unsetenv("TA_WIKI_PDFLATEX") else Sys.setenv(TA_WIKI_PDFLATEX = previous_engine)
  }, add = TRUE)
  Sys.setenv(TA_WIKI_RESTRICTED_ROOT = restricted)
  Sys.setenv(TA_WIKI_GOVERNANCE_AUTHORIZATION_ID = "test-attested-authorization")
  fixture <- make_attested_build_fixture(fixture_repo, restricted)

  fake_engine_dir <- tempfile("ta-wiki-fake-pdflatex-")
  dir.create(fake_engine_dir, recursive = TRUE)
  on.exit(unlink(fake_engine_dir, recursive = TRUE, force = TRUE), add = TRUE)
  if (.Platform$OS.type == "windows") {
    fake_engine <- file.path(fake_engine_dir, "fake-pdflatex.cmd")
    writeLines(c(
      "@echo off",
      "if \"%1\"==\"--version\" (",
      "  echo FakeTeX 1.0",
      "  exit /b 0",
      ")",
      "> article.pdf echo %%PDF-1.4",
      "exit /b 0"
    ), fake_engine, useBytes = TRUE)
  } else {
    fake_engine <- file.path(fake_engine_dir, "fake-pdflatex")
    writeLines(c(
      "#!/bin/sh",
      "if [ \"$1\" = \"--version\" ]; then echo 'FakeTeX 1.0'; exit 0; fi",
      "printf '%s\\n' '%PDF-1.4' > article.pdf"
    ), fake_engine, useBytes = TRUE)
    Sys.chmod(fake_engine, mode = "0755")
  }
  Sys.setenv(TA_WIKI_PDFLATEX = fake_engine)

  result <- command_status(
    rscript_bin,
    c(
      file.path(fixture_repo, "scripts", "run.R"),
      "manuscript-attested-build",
      "--candidate-manifest", fixture$candidate_manifest_path,
      "--approval-id", fixture$approval_id
    ),
    wd = fixture_repo
  )
  testthat::expect_equal(result$status, 0L, info = result$output)
  testthat::expect_match(result$output, "remain in restricted storage", fixed = TRUE)

  build_name <- paste0("attested-", fixture$approval_id, "-", substr(fixture$candidate_sha256, 1L, 12L))
  build_dir <- file.path(restricted, "reports", "manuscript-builds", build_name)
  pdf_path <- file.path(build_dir, "article-attested-results.pdf")
  record_path <- file.path(build_dir, "article-attested-results.build.json")
  testthat::expect_true(file.exists(pdf_path))
  testthat::expect_equal(readBin(pdf_path, what = "raw", n = 5L), charToRaw("%PDF-"))
  testthat::expect_true(file.exists(record_path))
  record <- jsonlite::read_json(record_path, simplifyVector = FALSE)
  testthat::expect_identical(record$status, "attested_results_manuscript_build_not_submission_ready")
  testthat::expect_identical(record$lineage$candidate_manifest_sha256, fixture$candidate_sha256)
  testthat::expect_identical(record$source$attested_results_sha256, fixture$results_sha256)
  testthat::expect_false(file.exists(file.path(fixture_repo, "manuscript", "article-attested-results.pdf")))
  tracked_placeholder <- paste(readLines(file.path(fixture_repo, "manuscript", "generated-results.tex"), warn = FALSE), collapse = "\n")
  testthat::expect_match(
    tolower(gsub("[[:space:]]+", " ", tracked_placeholder)),
    "no disclosure-approved numerical result artifact is currently available for this manuscript",
    fixed = TRUE
  )
})
