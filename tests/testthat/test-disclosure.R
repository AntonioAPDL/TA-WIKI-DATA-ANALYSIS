testthat::test_that("release policy enforces the selected conservative threshold", {
  policy <- read_release_policy(file.path(project_root, "config", "release-policy.yml"))
  testthat::expect_identical(policy$minimum_cell_count, 5L)
  testthat::expect_true(policy$require_manual_disclosure_review)
  testthat::expect_true(policy$suppress_free_text)
  testthat::expect_true(policy$suppress_timestamps)
  testthat::expect_true(policy$suppress_respondent_level_rows)
})

testthat::test_that("release policy rejects a fractional threshold", {
  policy_path <- tempfile(fileext = ".yml")
  lines <- readLines(file.path(project_root, "config", "release-policy.yml"), warn = FALSE)
  lines <- sub("minimum_cell_count: 5", "minimum_cell_count: 2.9", lines, fixed = TRUE)
  writeLines(lines, policy_path, useBytes = TRUE)
  testthat::expect_error(read_release_policy(policy_path), "base-10 integer")
})

testthat::test_that("controlled tracked-file hashes use canonical Git blobs across EOL checkout", {
  git <- Sys.which("git")
  if (!nzchar(git)) git <- "C:/Program Files/Git/cmd/git.exe"
  if (!file.exists(git)) testthat::skip("Git is required for the canonical-blob regression test.")
  repository <- tempfile("ta-wiki-canonical-blob-")
  dir.create(repository, recursive = TRUE)
  on.exit(unlink(repository, recursive = TRUE, force = TRUE), add = TRUE)
  tracked_path <- file.path(repository, "controlled.txt")
  writeBin(charToRaw("one\ntwo\n"), tracked_path)
  initialized <- command_status(git, c("-C", repository, "init"))
  testthat::expect_equal(initialized$status, 0L, info = initialized$output)
  added <- command_status(git, c("-C", repository, "add", "controlled.txt"))
  testthat::expect_equal(added$status, 0L, info = added$output)
  committed <- command_status(git, c(
    "-C", repository,
    "-c", "user.name=TestFixture",
    "-c", "user.email=test-fixture@example.invalid",
    "commit", "-m", "fixture"
  ))
  testthat::expect_equal(committed$status, 0L, info = committed$output)

  canonical <- tracked_file_sha256(tracked_path)
  writeBin(charToRaw("one\r\ntwo\r\n"), tracked_path)
  testthat::expect_false(identical(sha256_file(tracked_path), canonical))
  testthat::expect_identical(tracked_file_sha256(tracked_path), canonical)
})

testthat::test_that("historical tracked-file hashes use the recorded Git revision", {
  git <- Sys.which("git")
  if (!nzchar(git)) git <- "C:/Program Files/Git/cmd/git.exe"
  if (!file.exists(git)) testthat::skip("Git is required for the historical-blob regression test.")
  repository <- tempfile("ta-wiki-historical-blob-")
  dir.create(file.path(repository, "scripts"), recursive = TRUE)
  on.exit(unlink(repository, recursive = TRUE, force = TRUE), add = TRUE)
  verifier_path <- file.path(repository, "scripts", "05_verify_release_attestation.R")
  writeBin(charToRaw("old verifier bytes\n"), verifier_path)
  old_hash <- sha256_file(verifier_path)
  initialized <- command_status(git, c("-C", repository, "init"))
  testthat::expect_equal(initialized$status, 0L, info = initialized$output)
  added <- command_status(git, c("-C", repository, "add", "scripts/05_verify_release_attestation.R"))
  testthat::expect_equal(added$status, 0L, info = added$output)
  committed <- command_status(git, c(
    "-C", repository,
    "-c", "user.name=TestFixture",
    "-c", "user.email=test-fixture@example.invalid",
    "commit", "-m", "old-verifier"
  ))
  testthat::expect_equal(committed$status, 0L, info = committed$output)
  old_commit <- trimws(command_status(git, c("-C", repository, "rev-parse", "HEAD"))$output)

  writeBin(charToRaw("new verifier bytes\n"), verifier_path)
  added <- command_status(git, c("-C", repository, "add", "scripts/05_verify_release_attestation.R"))
  testthat::expect_equal(added$status, 0L, info = added$output)
  committed <- command_status(git, c(
    "-C", repository,
    "-c", "user.name=TestFixture",
    "-c", "user.email=test-fixture@example.invalid",
    "commit", "-m", "new-verifier"
  ))
  testthat::expect_equal(committed$status, 0L, info = committed$output)

  testthat::expect_identical(
    tracked_file_sha256_at_commit(repository, "scripts/05_verify_release_attestation.R", old_commit),
    old_hash
  )
  testthat::expect_false(identical(
    tracked_file_sha256_at_commit(repository, "scripts/05_verify_release_attestation.R", old_commit),
    tracked_file_sha256(verifier_path)
  ))
  testthat::expect_error(
    tracked_file_sha256_at_commit(repository, "scripts/05_verify_release_attestation.R", paste(rep("0", 40L), collapse = "")),
    "Unable to read the historical Git blob"
  )
})

testthat::test_that("suppression fully suppresses an affected table to prevent differencing", {
  summary <- data.frame(
    domain = rep("usage", 2), item = rep("wiki_visited", 2), item_type = rep("single_choice", 2),
    analysis_variant = rep("primary", 2), response = c("No", "Yes"), display_order = 1:2,
    n = c(1L, 11L), denominator = c(12L, 12L), percent = c(8.3, 91.7), stringsAsFactors = FALSE
  )
  release <- conservative_suppress(summary, threshold = 5L)
  testthat::expect_equal(nrow(release$public), 1L)
  testthat::expect_identical(release$public$release_status, "fully_suppressed")
  testthat::expect_true(all(is.na(release$public$n)))
  testthat::expect_equal(nrow(release$suppression_log), 1L)
})

testthat::test_that("release universe excludes sensitivity variants before suppression", {
  summary <- data.frame(
    domain = rep("contribution", 4), item = rep("contributed", 4), item_type = rep("single_choice", 4),
    analysis_variant = c("primary", "primary", "sensitivity_missing_status", "sensitivity_missing_status"),
    response = c("No", "Yes", "No", "Yes"), display_order = c(1L, 2L, 1L, 2L),
    n = c(5L, 5L, 1L, 9L), denominator = rep(10L, 4), percent = c(50, 50, 10, 90), stringsAsFactors = FALSE
  )
  release <- conservative_suppress(summary, threshold = 5L)
  testthat::expect_true(all(release$public$analysis_variant == "primary"))
  testthat::expect_equal(nrow(release$public), 2L)
  testthat::expect_equal(nrow(release$suppression_log), 0L)
})

testthat::test_that("release validation accepts an item-specific Likert option after the shared scale", {
  metadata <- read_metadata(project_root)
  item <- "recommend_wiki"
  item_info <- item_row(metadata, item)
  options <- scalar_codebook(metadata, item, item_info$item_type[[1]])
  counts <- rep(5L, nrow(options))
  denominator <- sum(counts)
  summary <- data.frame(
    domain = rep(item_info$domain[[1]], nrow(options)),
    item = rep(item, nrow(options)),
    item_type = rep(item_info$item_type[[1]], nrow(options)),
    analysis_variant = rep("primary", nrow(options)),
    response = options$canonical_value,
    display_order = options$display_order,
    n = counts,
    denominator = rep(denominator, nrow(options)),
    percent = round(100 * counts / denominator, 1),
    stringsAsFactors = FALSE
  )

  release <- conservative_suppress(summary, threshold = 5L, metadata = metadata)
  testthat::expect_true(all(release$public$release_status == "released"))
  testthat::expect_identical(release$public$response, options$canonical_value)
  testthat::expect_equal(nrow(release$suppression_log), 0L)
})

testthat::test_that("candidate preparation requires every controlled release item", {
  metadata <- read_metadata(project_root)
  item <- "wiki_visited"
  item_info <- item_row(metadata, item)
  options <- scalar_codebook(metadata, item, item_info$item_type[[1]])
  summary <- data.frame(
    domain = rep(item_info$domain[[1]], nrow(options)),
    item = rep(item, nrow(options)),
    item_type = rep(item_info$item_type[[1]], nrow(options)),
    analysis_variant = rep("primary", nrow(options)),
    response = options$canonical_value,
    display_order = options$display_order,
    n = rep(5L, nrow(options)),
    denominator = rep(as.integer(5L * nrow(options)), nrow(options)),
    percent = rep(round(100 / nrow(options), 1), nrow(options)),
    stringsAsFactors = FALSE
  )
  testthat::expect_silent(conservative_suppress(summary, threshold = 5L, metadata = metadata))
  testthat::expect_error(
    conservative_suppress(
      summary,
      threshold = 5L,
      metadata = metadata,
      require_complete_universe = TRUE
    ),
    "complete controlled release universe"
  )
})

testthat::test_that("release summary validation rejects malformed counts and percentages", {
  malformed <- data.frame(
    domain = "usage", item = "wiki_visited", item_type = "single_choice", analysis_variant = "primary",
    response = "Yes", display_order = 1L, n = 1.5, denominator = 2L, percent = 50, stringsAsFactors = FALSE
  )
  testthat::expect_error(conservative_suppress(malformed, threshold = 2L), "invalid n")
  malformed$n <- 1L
  malformed$percent <- 25
  testthat::expect_error(conservative_suppress(malformed, threshold = 2L), "inconsistent percent")
})

testthat::test_that("manuscript renderer includes released rows and withholds suppressed values", {
  metadata <- read_metadata(project_root)
  public <- data.frame(
    domain = c("usage", "usage"), item = c("wiki_visited", "consult_when"),
    response = c("Yes", NA_character_), n = c(10L, NA_integer_), denominator = c(12L, NA_integer_),
    percent = c(83.3, NA_real_), release_status = c("released", "fully_suppressed"), stringsAsFactors = FALSE
  )
  tex <- render_release_results_tex(public, metadata = metadata)
  rendered <- paste(tex, collapse = "\n")
  testthat::expect_match(rendered, "Prior visit to the TA Wiki", fixed = TRUE)
  testthat::expect_match(rendered, "10", fixed = TRUE)
  testthat::expect_false(grepl("When the TA Wiki is consulted", rendered, fixed = TRUE))
  testthat::expect_match(rendered, "withheld", fixed = TRUE)
})

testthat::test_that("TeX rendering normalizes approved typography and rejects unsupported text", {
  label <- paste0("Smaller, focused tasks or a list of ", "\u201c", "wanted", "\u201d", " contributions")
  rendered <- tex_escape(label)
  testthat::expect_identical(
    rendered,
    "Smaller, focused tasks or a list of \"wanted\" contributions"
  )
  testthat::expect_true(all(utf8ToInt(rendered) <= 127L))
  testthat::expect_error(
    tex_escape(paste0("Unsupported ", "\u00e9")),
    "cannot safely encode non-ASCII"
  )
})

testthat::test_that("release lineage requires a current complete manifest chain", {
  policy <- read_release_policy(file.path(project_root, "config", "release-policy.yml"))
  metadata <- read_metadata(project_root)
  run_dir <- tempfile("ta-wiki-lineage-")
  lineage <- write_minimal_real_lineage(run_dir)

  testthat::expect_silent(
    validate_current_release_lineage(project_root, lineage$analysis, policy = policy, metadata = metadata, require_clean_worktree = FALSE)
  )

  stale_commit <- read_manifest(lineage$analysis)
  stale_commit$environment$git_commit <- paste(rep("0", 40L), collapse = "")
  jsonlite::write_json(stale_commit, lineage$analysis, auto_unbox = TRUE)
  testthat::expect_error(
    validate_current_release_lineage(project_root, lineage$analysis, policy = policy, metadata = metadata, require_clean_worktree = FALSE),
    "Analysis manifest was generated by a different Git commit"
  )

  lineage <- write_minimal_real_lineage(run_dir)
  stale_predecessor <- read_manifest(lineage$transformation)
  stale_predecessor$environment$git_commit <- paste(rep("0", 40L), collapse = "")
  jsonlite::write_json(stale_predecessor, lineage$transformation, auto_unbox = TRUE)
  analysis <- read_manifest(lineage$analysis)
  analysis$transformation_manifest_sha256 <- sha256_file(lineage$transformation)
  jsonlite::write_json(analysis, lineage$analysis, auto_unbox = TRUE)
  testthat::expect_error(
    validate_current_release_lineage(project_root, lineage$analysis, policy = policy, metadata = metadata, require_clean_worktree = FALSE),
    "Transformation manifest was generated by a different Git commit"
  )

  lineage <- write_minimal_real_lineage(run_dir)
  stale_policy <- read_manifest(lineage$validation)
  stale_policy$schema$release_policy <- paste(rep("a", 64L), collapse = "")
  jsonlite::write_json(stale_policy, lineage$validation, auto_unbox = TRUE)
  transformation <- read_manifest(lineage$transformation)
  transformation$validation_manifest_sha256 <- sha256_file(lineage$validation)
  jsonlite::write_json(transformation, lineage$transformation, auto_unbox = TRUE)
  analysis <- read_manifest(lineage$analysis)
  analysis$transformation_manifest_sha256 <- sha256_file(lineage$transformation)
  jsonlite::write_json(analysis, lineage$analysis, auto_unbox = TRUE)
  testthat::expect_error(
    validate_current_release_lineage(project_root, lineage$analysis, policy = policy, metadata = metadata, require_clean_worktree = FALSE),
    "Release policy changed after validation"
  )

  lineage <- write_minimal_real_lineage(run_dir)
  stale_lockfile <- read_manifest(lineage$validation)
  stale_lockfile$environment$lockfile_sha256 <- paste(rep("a", 64L), collapse = "")
  jsonlite::write_json(stale_lockfile, lineage$validation, auto_unbox = TRUE)
  transformation <- read_manifest(lineage$transformation)
  transformation$validation_manifest_sha256 <- sha256_file(lineage$validation)
  jsonlite::write_json(transformation, lineage$transformation, auto_unbox = TRUE)
  analysis <- read_manifest(lineage$analysis)
  analysis$transformation_manifest_sha256 <- sha256_file(lineage$transformation)
  jsonlite::write_json(analysis, lineage$analysis, auto_unbox = TRUE)
  testthat::expect_error(
    validate_current_release_lineage(project_root, lineage$analysis, policy = policy, metadata = metadata, require_clean_worktree = FALSE),
    "Validation manifest lockfile does not match"
  )

  lineage <- write_minimal_real_lineage(run_dir)
  stale_metadata <- read_manifest(lineage$validation)
  stale_metadata$schema$item_spec <- paste(rep("a", 64L), collapse = "")
  jsonlite::write_json(stale_metadata, lineage$validation, auto_unbox = TRUE)
  transformation <- read_manifest(lineage$transformation)
  transformation$validation_manifest_sha256 <- sha256_file(lineage$validation)
  jsonlite::write_json(transformation, lineage$transformation, auto_unbox = TRUE)
  analysis <- read_manifest(lineage$analysis)
  analysis$transformation_manifest_sha256 <- sha256_file(lineage$transformation)
  jsonlite::write_json(analysis, lineage$analysis, auto_unbox = TRUE)
  testthat::expect_error(
    validate_current_release_lineage(project_root, lineage$analysis, policy = policy, metadata = metadata, require_clean_worktree = FALSE),
    "Controlled metadata changed after validation"
  )

  lineage <- write_minimal_real_lineage(run_dir)
  analysis <- read_manifest(lineage$analysis)
  analysis$transformation_manifest_sha256 <- paste(rep("a", 64L), collapse = "")
  jsonlite::write_json(analysis, lineage$analysis, auto_unbox = TRUE)
  testthat::expect_error(
    validate_current_release_lineage(project_root, lineage$analysis, policy = policy, metadata = metadata, require_clean_worktree = FALSE),
    "does not bind the transformation manifest"
  )

  lineage <- write_minimal_real_lineage(run_dir)
  transformation <- read_manifest(lineage$transformation)
  transformation$run_id <- "different-run-001"
  jsonlite::write_json(transformation, lineage$transformation, auto_unbox = TRUE)
  analysis <- read_manifest(lineage$analysis)
  analysis$transformation_manifest_sha256 <- sha256_file(lineage$transformation)
  jsonlite::write_json(analysis, lineage$analysis, auto_unbox = TRUE)
  testthat::expect_error(
    validate_current_release_lineage(project_root, lineage$analysis, policy = policy, metadata = metadata, require_clean_worktree = FALSE),
    "predecessor lineage is inconsistent"
  )

  lineage <- write_minimal_real_lineage(run_dir)
  dirty_validation <- read_manifest(lineage$validation)
  dirty_validation$environment$git_dirty <- TRUE
  jsonlite::write_json(dirty_validation, lineage$validation, auto_unbox = TRUE)
  transformation <- read_manifest(lineage$transformation)
  transformation$validation_manifest_sha256 <- sha256_file(lineage$validation)
  jsonlite::write_json(transformation, lineage$transformation, auto_unbox = TRUE)
  analysis <- read_manifest(lineage$analysis)
  analysis$transformation_manifest_sha256 <- sha256_file(lineage$transformation)
  jsonlite::write_json(analysis, lineage$analysis, auto_unbox = TRUE)
  testthat::expect_error(
    validate_current_release_lineage(project_root, lineage$analysis, policy = policy, metadata = metadata, require_clean_worktree = FALSE),
    "Validation manifest does not record a clean, valid Git provenance"
  )

  lineage <- write_minimal_real_lineage(run_dir)
  mismatched_source <- read_manifest(lineage$transformation)
  mismatched_source$source$id <- "different_source"
  jsonlite::write_json(mismatched_source, lineage$transformation, auto_unbox = TRUE)
  analysis <- read_manifest(lineage$analysis)
  analysis$transformation_manifest_sha256 <- sha256_file(lineage$transformation)
  jsonlite::write_json(analysis, lineage$analysis, auto_unbox = TRUE)
  testthat::expect_error(
    validate_current_release_lineage(project_root, lineage$analysis, policy = policy, metadata = metadata, require_clean_worktree = FALSE),
    "predecessor source provenance is inconsistent"
  )

  lineage <- write_minimal_real_lineage(run_dir)
  malformed <- read_manifest(lineage$analysis)
  malformed$environment <- list(git_commit = "short", git_dirty = FALSE)
  jsonlite::write_json(malformed, lineage$analysis, auto_unbox = TRUE)
  testthat::expect_error(
    validate_current_release_lineage(project_root, lineage$analysis, policy = policy, metadata = metadata, require_clean_worktree = FALSE),
    "Analysis manifest does not record a clean, valid Git provenance"
  )
})

testthat::test_that("candidate attestation binds exact candidate bytes", {
  restricted <- tempfile("ta-wiki-release-")
  dir.create(file.path(restricted, "governance", "release-attestations"), recursive = TRUE)
  dir.create(file.path(restricted, "governance", "release-verifications"), recursive = TRUE)
  dir.create(file.path(restricted, "runs", "real-test-001", "outputs", "release-candidate"), recursive = TRUE)
  write_restricted_preflight_record(restricted)
  previous <- Sys.getenv("TA_WIKI_RESTRICTED_ROOT", unset = NA_character_)
  previous_authorization <- Sys.getenv("TA_WIKI_GOVERNANCE_AUTHORIZATION_ID", unset = NA_character_)
  on.exit({
    if (is.na(previous)) Sys.unsetenv("TA_WIKI_RESTRICTED_ROOT") else Sys.setenv(TA_WIKI_RESTRICTED_ROOT = previous)
    if (is.na(previous_authorization)) Sys.unsetenv("TA_WIKI_GOVERNANCE_AUTHORIZATION_ID") else Sys.setenv(TA_WIKI_GOVERNANCE_AUTHORIZATION_ID = previous_authorization)
  }, add = TRUE)
  Sys.setenv(TA_WIKI_RESTRICTED_ROOT = restricted)
  Sys.setenv(TA_WIKI_GOVERNANCE_AUTHORIZATION_ID = write_restricted_test_authorization(restricted))
  candidate_dir <- file.path(restricted, "runs", "real-test-001", "outputs", "release-candidate")
  public_path <- file.path(candidate_dir, "structured-summary-public.csv")
  suppression_path <- file.path(candidate_dir, "suppression-log.csv")
  manuscript_path <- file.path(candidate_dir, "generated-results.tex")
  run_dir <- file.path(restricted, "runs", "real-test-001")
  metadata <- read_metadata(project_root)
  policy <- write_approved_test_policy()
  schema <- metadata_hashes(metadata)
  schema[["release_policy"]] <- policy$sha256
  summary <- controlled_release_summary_fixture(metadata)
  summary_path <- file.path(run_dir, "outputs", "internal", "structured-item-summary.csv")
  dir.create(dirname(summary_path), recursive = TRUE, showWarnings = FALSE)
  write.csv(summary, summary_path, row.names = FALSE)
  lineage <- write_minimal_real_lineage(
    run_dir,
    run_id = "test-001",
    schema = schema,
    analysis_outputs = list(structured_summary = summary_path)
  )
  analysis_manifest_path <- lineage$analysis
  release <- conservative_suppress(summary, policy$minimum_cell_count, metadata = metadata)
  write.csv(release$public, public_path, row.names = FALSE, na = "")
  write.csv(release$suppression_log, suppression_path, row.names = FALSE, na = "")
  writeLines(render_release_results_tex_v1_1(release$public), manuscript_path, useBytes = TRUE)
  candidate_manifest_path <- file.path(candidate_dir, "release-candidate-manifest.json")
  candidate_manifest <- list(
    schema_version = "1.1",
    status = "candidate_generated_pending_manual_review",
    analysis_manifest_sha256 = sha256_file(analysis_manifest_path),
    analysis_manifest_relative_path = "manifests/03-analysis.json",
    release_policy_sha256 = policy$sha256,
    generator = list(
      git_commit = git_metadata(project_root)$commit,
      script_sha256 = tracked_file_sha256(file.path(project_root, "scripts", "04_prepare_release.R"))
    ),
    release_universe = list(
      analysis_variants = "primary",
      excluded = c("sensitivity variants", "exploratory cross-tabs", "qualitative material", "respondent-level material")
    ),
    outputs = list(
      structured_summary_public = list(filename = basename(public_path), sha256 = sha256_file(public_path)),
      suppression_log = list(filename = basename(suppression_path), sha256 = sha256_file(suppression_path)),
      manuscript_results = list(filename = basename(manuscript_path), sha256 = sha256_file(manuscript_path))
    ),
    suppression_groups = nrow(release$suppression_log)
  )
  jsonlite::write_json(candidate_manifest, candidate_manifest_path, auto_unbox = TRUE, pretty = TRUE)
  candidate <- validate_release_candidate_manifest(
    project_root,
    candidate_manifest_path,
    policy = policy,
    metadata = metadata,
    require_clean_worktree = FALSE
  )

  candidate_manifest$outputs$structured_summary_public$filename <- "renamed-public-summary.csv"
  jsonlite::write_json(candidate_manifest, candidate_manifest_path, auto_unbox = TRUE, pretty = TRUE)
  testthat::expect_error(
    validate_release_candidate_manifest(project_root, candidate_manifest_path, policy = policy, metadata = metadata, require_clean_worktree = FALSE),
    "canonical output filenames"
  )
  candidate_manifest$outputs$structured_summary_public$filename <- basename(public_path)
  jsonlite::write_json(candidate_manifest, candidate_manifest_path, auto_unbox = TRUE, pretty = TRUE)
  candidate <- validate_release_candidate_manifest(project_root, candidate_manifest_path, policy = policy, metadata = metadata, require_clean_worktree = FALSE)

  candidate_manifest$release_policy_sha256 <- paste(rep("a", 64L), collapse = "")
  jsonlite::write_json(candidate_manifest, candidate_manifest_path, auto_unbox = TRUE, pretty = TRUE)
  testthat::expect_error(
    validate_release_candidate_manifest(project_root, candidate_manifest_path, policy = policy, metadata = metadata, require_clean_worktree = FALSE),
    "does not bind the analysis manifest release policy"
  )
  candidate_manifest$release_policy_sha256 <- policy$sha256
  candidate_manifest$generator$git_commit <- paste(rep("0", 40L), collapse = "")
  jsonlite::write_json(candidate_manifest, candidate_manifest_path, auto_unbox = TRUE, pretty = TRUE)
  testthat::expect_error(
    validate_release_candidate_manifest(project_root, candidate_manifest_path, policy = policy, metadata = metadata, require_clean_worktree = FALSE),
    "generator commit does not match"
  )
  candidate_manifest$generator$git_commit <- git_metadata(project_root)$commit
  jsonlite::write_json(candidate_manifest, candidate_manifest_path, auto_unbox = TRUE, pretty = TRUE)
  candidate <- validate_release_candidate_manifest(project_root, candidate_manifest_path, policy = policy, metadata = metadata, require_clean_worktree = FALSE)

  candidate_manifest$generator$script_sha256 <- paste(rep("b", 64L), collapse = "")
  jsonlite::write_json(candidate_manifest, candidate_manifest_path, auto_unbox = TRUE, pretty = TRUE)
  testthat::expect_error(
    validate_release_candidate_manifest(project_root, candidate_manifest_path, policy = policy, metadata = metadata, require_clean_worktree = FALSE),
    "generator script does not match"
  )
  candidate_manifest$generator$script_sha256 <- tracked_file_sha256(file.path(project_root, "scripts", "04_prepare_release.R"))
  jsonlite::write_json(candidate_manifest, candidate_manifest_path, auto_unbox = TRUE, pretty = TRUE)
  candidate <- validate_release_candidate_manifest(project_root, candidate_manifest_path, policy = policy, metadata = metadata, require_clean_worktree = FALSE)

  semantic_tamper <- read.csv(public_path, check.names = FALSE, stringsAsFactors = FALSE, na.strings = "")
  semantic_tamper$n[[1]] <- semantic_tamper$n[[1]] + 1L
  semantic_tamper$percent[[1]] <- round(100 * semantic_tamper$n[[1]] / semantic_tamper$denominator[[1]], 1)
  write.csv(semantic_tamper, public_path, row.names = FALSE, na = "")
  candidate_manifest$outputs$structured_summary_public$sha256 <- sha256_file(public_path)
  jsonlite::write_json(candidate_manifest, candidate_manifest_path, auto_unbox = TRUE, pretty = TRUE)
  testthat::expect_error(
    validate_release_candidate_manifest(project_root, candidate_manifest_path, policy = policy, metadata = metadata, require_clean_worktree = FALSE),
    "not derived from the bound analysis and disclosure policy"
  )
  write.csv(release$public, public_path, row.names = FALSE, na = "")
  candidate_manifest$outputs$structured_summary_public$sha256 <- sha256_file(public_path)
  jsonlite::write_json(candidate_manifest, candidate_manifest_path, auto_unbox = TRUE, pretty = TRUE)
  candidate <- validate_release_candidate_manifest(project_root, candidate_manifest_path, policy = policy, metadata = metadata, require_clean_worktree = FALSE)

  attestation_path <- file.path(restricted, "governance", "release-attestations", "approval-001.json")
  jsonlite::write_json(list(
    schema_version = "1.1",
    status = "approved",
    manual_disclosure_review = TRUE,
    pi_approval_confirmed = TRUE,
    pi_approval_reference = "governance-001",
    candidate_manifest_sha256 = candidate$sha256,
    analysis_manifest_sha256 = candidate$manifest$analysis_manifest_sha256,
    release_policy_sha256 = candidate$manifest$release_policy_sha256,
    candidate_output_sha256 = as.list(candidate$output_hashes)
  ), attestation_path, auto_unbox = TRUE, pretty = TRUE)
  stored_attestation <- jsonlite::read_json(attestation_path, simplifyVector = FALSE)
  testthat::expect_identical(stored_attestation$candidate_manifest_sha256, candidate$sha256)
  testthat::expect_identical(stored_attestation$analysis_manifest_sha256, candidate$manifest$analysis_manifest_sha256)
  testthat::expect_identical(stored_attestation$release_policy_sha256, candidate$manifest$release_policy_sha256)
  testthat::expect_identical(stored_attestation$candidate_output_sha256$structured_summary_public, candidate$output_hashes[["structured_summary_public"]])
  testthat::expect_identical(stored_attestation$candidate_output_sha256$suppression_log, candidate$output_hashes[["suppression_log"]])
  testthat::expect_identical(stored_attestation$candidate_output_sha256$manuscript_results, candidate$output_hashes[["manuscript_results"]])
  verified <- read_release_attestation(project_root, "approval-001", candidate)
  testthat::expect_identical(verified$id, "approval-001")
  verification_path <- file.path(restricted, "governance", "release-verifications", "approval-001.json")
  jsonlite::write_json(list(
    schema_version = "1.1",
    status = "approved_candidate_verified_pending_external_delivery",
    candidate_manifest_sha256 = candidate$sha256,
    analysis_manifest_sha256 = candidate$manifest$analysis_manifest_sha256,
    release_policy_sha256 = candidate$manifest$release_policy_sha256,
    candidate_output_sha256 = as.list(candidate$output_hashes),
    attestation = verified,
    verifier = list(
      git_commit = git_metadata(project_root)$commit,
      script_sha256 = tracked_file_sha256(file.path(project_root, "scripts", "05_verify_release_attestation.R"))
    )
  ), verification_path, auto_unbox = TRUE, pretty = TRUE)
  verified_record <- read_release_verification(project_root, "approval-001", candidate, verified)
  testthat::expect_identical(verified_record$id, "approval-001")
  invalid_verification <- jsonlite::read_json(verification_path, simplifyVector = FALSE)
  invalid_verification$attestation$sha256 <- paste(rep("e", 64L), collapse = "")
  jsonlite::write_json(invalid_verification, verification_path, auto_unbox = TRUE, pretty = TRUE)
  testthat::expect_error(
    read_release_verification(project_root, "approval-001", candidate, verified),
    "does not bind the exact candidate artifacts"
  )
  writeLines("tampered", public_path, useBytes = TRUE)
  testthat::expect_error(
    validate_release_candidate_manifest(project_root, candidate_manifest_path, policy = policy, metadata = metadata, require_clean_worktree = FALSE),
    "does not match"
  )
})
