testthat::test_that("controlled metadata is complete and internally consistent", {
  metadata <- read_metadata(project_root)
  testthat::expect_equal(nrow(metadata$item_spec), 43L)
  testthat::expect_true(all(metadata$item_spec$analysis_name == metadata$variable_map$analysis_name))
  testthat::expect_true(all(nzchar(unlist(metadata_hashes(metadata), use.names = FALSE))))
  testthat::expect_equal(nrow(metadata$exploratory_pairs), 4L)
  testthat::expect_true(all(metadata$exploratory_pairs$internal_only == "yes"))
  testthat::expect_equal(nrow(metadata$publication_labels), sum(
    metadata$item_spec$primary_analysis == "yes" &
      metadata$item_spec$release_eligibility == "review_required" &
      metadata$item_spec$item_type %in% c("single_choice", "ordinal", "likert", "checkbox")
  ))
})

testthat::test_that("contribution status remains direct in the primary analysis and is inferred only in sensitivity", {
  metadata <- read_metadata(project_root)
  rule <- metadata$derivation_rules[
    metadata$derivation_rules$analysis_name == "contributed",
    , drop = FALSE
  ]
  direct_values <- c(NA_character_, "Yes", "No", NA_character_)
  direct_states <- c("missing", "valid", "valid", "missing")
  reason_states <- c("valid", "partial_invalid", "missing", "invalid")
  sensitivity <- contribution_status_sensitivity(direct_values, direct_states, reason_states, rule)
  testthat::expect_identical(direct_values[[1]], NA_character_)
  testthat::expect_identical(direct_states[[1]], "missing")
  testthat::expect_identical(sensitivity$values, c("No", "Yes", "No", NA_character_))
  testthat::expect_identical(sensitivity$states, c("inferred", "valid", "valid", "missing"))
  testthat::expect_identical(sensitivity$inferred_n, 1L)
})

testthat::test_that("conditional noncontribution reasons require an observed direct No in the primary summary", {
  values <- data.frame(
    contributed = c(NA_character_, "No", "Yes", ""),
    stringsAsFactors = FALSE
  )
  applicable <- skip_applicability(values, "contributed_no_or_missing", variant = "primary")
  testthat::expect_identical(applicable, c(FALSE, TRUE, FALSE, FALSE))
})

testthat::test_that("resolved response codebooks have unique, positive display orders", {
  metadata <- read_metadata(project_root)
  recommend <- scalar_codebook(metadata, "recommend_wiki", "likert")
  testthat::expect_identical(as.integer(recommend$display_order), 1:6)
  testthat::expect_identical(recommend$canonical_value[[6]], "Not sure")

  scalar_items <- metadata$item_spec[metadata$item_spec$item_type %in% c("single_choice", "ordinal", "likert"), , drop = FALSE]
  for (index in seq_len(nrow(scalar_items))) {
    codebook <- scalar_codebook(metadata, scalar_items$analysis_name[[index]], scalar_items$item_type[[index]])
    testthat::expect_identical(anyDuplicated(codebook$display_order), 0L, info = scalar_items$analysis_name[[index]])
    testthat::expect_true(all(codebook$display_order >= 1L), info = scalar_items$analysis_name[[index]])
  }

  checkbox_items <- metadata$item_spec[metadata$item_spec$item_type == "checkbox", , drop = FALSE]
  for (index in seq_len(nrow(checkbox_items))) {
    codebook <- checkbox_codebook(metadata, checkbox_items$analysis_name[[index]])
    testthat::expect_identical(anyDuplicated(codebook$display_order), 0L, info = checkbox_items$analysis_name[[index]])
    testthat::expect_true(all(codebook$display_order >= 1L), info = checkbox_items$analysis_name[[index]])
  }
})

testthat::test_that("metadata loading rejects a duplicate expanded Likert display order", {
  temporary_root <- tempfile("ta-wiki-bad-codebook-")
  on.exit(unlink(temporary_root, recursive = TRUE, force = TRUE), add = TRUE)
  temporary_metadata <- file.path(temporary_root, "data", "metadata")
  dir.create(temporary_metadata, recursive = TRUE)
  source_metadata <- file.path(project_root, "data", "metadata")
  copied <- file.copy(list.files(source_metadata, full.names = TRUE), temporary_metadata)
  testthat::expect_true(all(copied))

  codebook_path <- file.path(temporary_metadata, "category-codebook.csv")
  codebook <- utils::read.csv(codebook_path, stringsAsFactors = FALSE, check.names = FALSE)
  codebook$display_order[codebook$analysis_name == "recommend_wiki" & codebook$canonical_value == "Not sure"] <- 1L
  utils::write.csv(codebook, codebook_path, row.names = FALSE)

  testthat::expect_error(read_metadata(temporary_root), "duplicate display orders")
})

testthat::test_that("scalar normalizations and anomaly rules are explicit", {
  metadata <- read_metadata(project_root)
  audit <- empty_rule_audit(metadata)
  likert <- recode_scalar("Strongly Agree", "wiki_value", "likert", metadata, audit)
  testthat::expect_identical(likert$state, "valid")
  testthat::expect_identical(likert$value, "Strongly agree")

  contaminated <- recode_scalar("Department orientation or seminaron 1", "awareness_source", "single_choice", metadata, audit)
  testthat::expect_identical(contaminated$state, "valid")
  testthat::expect_identical(contaminated$value, "Department orientation or seminar")
  testthat::expect_equal(contaminated$rule_audit$affected_n[contaminated$rule_audit$rule_id == "RULE-AWARENESS-001"], 1L)

  incompatible <- recode_scalar("Neutral - I might check it out, Likely - I would use it when needs arise", "ideal_resource_use", "single_choice", metadata, audit)
  testthat::expect_identical(incompatible$state, "invalid")
})

testthat::test_that("checkbox parsing is exact, conservative, and handles registered contamination", {
  metadata <- read_metadata(project_root)
  audit <- empty_rule_audit(metadata)
  parsed <- parse_checkbox("Online resources (blogs, YouTube, subreddits, etc.), AI", "current_resources", metadata, audit)
  testthat::expect_identical(parsed$state, "valid")
  testthat::expect_setequal(parsed$options, c("Online resources (blogs, YouTube, subreddits, etc.)", "AI"))

  unmatched <- parse_checkbox("Course-specific tips from previous TAs, bespoke unregistered suggestion", "desired_features", metadata, audit)
  testthat::expect_identical(unmatched$state, "partial_invalid")
  testthat::expect_length(unmatched$options, 0L)

  corrected <- parse_checkbox("Requires technical setup (cloning repos, using a text editor, etc.)ion 5", "github_disadvantages", metadata, audit)
  testthat::expect_identical(corrected$state, "valid")
  testthat::expect_equal(corrected$options, "Requires technical setup (cloning repos, using a text editor, etc.)")
  testthat::expect_equal(corrected$rule_audit$affected_n[corrected$rule_audit$rule_id == "RULE-DISADVANTAGE-001"], 1L)
})
