#!/usr/bin/env Rscript

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
activate_project(root)
source(file.path(root, "scripts", "lib", "restricted_root.R"))
source(file.path(root, "scripts", "lib", "run_manifest.R"))
source(file.path(root, "scripts", "lib", "metadata.R"))
source(file.path(root, "scripts", "lib", "analysis_controls.R"))

cli <- parse_cli()
if (length(cli$flags) || !identical(names(cli$values), "manifest")) {
  stop("Analysis requires exactly --manifest <transformation-manifest-path>.")
}
transformation_manifest_path <- option_value(cli, "manifest", required = TRUE)
if (path_uses_configured_restricted_root(transformation_manifest_path)) {
  require_restricted_operation_authorization(root, "analyze")
}
manifest_context <- validate_stage_manifest(transformation_manifest_path, "transformation")
if (identical(manifest_context$manifest$mode, "real")) {
  require_restricted_operation_authorization(root, "analyze")
  root_restricted <- restricted_root(root)
  if (!path_within(manifest_context$run_dir, file.path(root_restricted, "runs"))) {
    stop("A real transformation manifest must reside under the approved restricted-data root.")
  }
  if (git_metadata(root)$dirty) stop("Real analysis requires a clean Git worktree.")
}
context <- transform_manifest_input(
  transformation_manifest_path,
  authorization_action = "analyze",
  project_root = root
)

metadata <- read_metadata(root)
expected_schema <- unlist(metadata_hashes(metadata), use.names = TRUE)
manifest_schema <- unlist(context$manifest$schema, use.names = TRUE)
if (!identical(as.character(manifest_schema[names(expected_schema)]), as.character(expected_schema))) {
  stop("Controlled metadata changed after transformation; rerun validation and transformation before analysis.")
}
if (identical(context$manifest$schema_version, "1.2")) {
  validate_analysis_control_fingerprint(context$manifest$analysis_controls, root, "Transformation manifest")
}

structured <- read.csv(context$inputs$structured_items, check.names = FALSE, stringsAsFactors = FALSE, na.strings = "")
checkbox_selections <- read.csv(context$inputs$checkbox_selections, check.names = FALSE, stringsAsFactors = FALSE, na.strings = "")
required_structured <- c("record_id", "item", "domain", "item_type", "analysis_variant", "applicable", "state", "value")
required_checkbox <- c("record_id", "item", "domain", "option", "display_order")
if (!all(required_structured %in% names(structured)) || !all(required_checkbox %in% names(checkbox_selections))) {
  stop("Transformation artifacts have an unsupported schema.")
}
validation_path <- file.path(context$run_dir, "manifests", "01-validation.json")
if (!file.exists(validation_path) || !identical(sha256_file(validation_path), context$manifest$validation_manifest_sha256)) {
  stop("Transformation manifest does not bind the validation manifest in this run directory.")
}
validation_manifest <- read_manifest(validation_path)
eligible_n <- validation_manifest$validation$analytic_cohort_records

write_csv_atomic <- function(table, path) {
  temporary <- paste0(path, ".tmp-", Sys.getpid())
  on.exit(unlink(temporary), add = TRUE)
  utils::write.csv(table, temporary, row.names = FALSE, na = "")
  if (!file.rename(temporary, path)) stop("Unable to atomically write CSV artifact.")
}

summary_columns <- c(
  "domain", "item", "item_type", "analysis_variant", "response", "display_order", "n",
  "eligible_n", "applicable_n", "observed_valid_n", "inferred_n", "missing_n", "invalid_n",
  "structural_skip_n", "denominator", "percent"
)

summarise_scalar <- function(item, variant) {
  item_info <- item_row(metadata, item)
  rows <- structured[structured$item == item & structured$analysis_variant == variant, , drop = FALSE]
  if (nrow(rows) != eligible_n) stop("Structured scalar row count does not equal the analytic cohort for ", item, ".")
  categories <- scalar_codebook(metadata, item, item_info$item_type[[1]])
  applicable_n <- sum(as.logical(rows$applicable), na.rm = TRUE)
  observed_valid_n <- sum(rows$state == "valid", na.rm = TRUE)
  inferred_n <- sum(rows$state == "inferred", na.rm = TRUE)
  missing_n <- sum(rows$state == "missing", na.rm = TRUE)
  invalid_n <- sum(rows$state %in% c("invalid", "partial_invalid"), na.rm = TRUE)
  structural_skip_n <- sum(rows$state == "structural_skip", na.rm = TRUE)
  denominator <- observed_valid_n + inferred_n
  out <- lapply(seq_len(nrow(categories)), function(i) {
    n <- sum(rows$value == categories$canonical_value[[i]] & rows$state %in% c("valid", "inferred"), na.rm = TRUE)
    data.frame(
      domain = item_info$domain[[1]], item = item, item_type = item_info$item_type[[1]],
      analysis_variant = variant, response = categories$canonical_value[[i]], display_order = categories$display_order[[i]],
      n = n, eligible_n = eligible_n, applicable_n = applicable_n, observed_valid_n = observed_valid_n,
      inferred_n = inferred_n, missing_n = missing_n, invalid_n = invalid_n, structural_skip_n = structural_skip_n,
      denominator = denominator, percent = if (denominator) round(100 * n / denominator, 1) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}

summarise_checkbox <- function(item) {
  item_info <- item_row(metadata, item)
  rows <- structured[structured$item == item & structured$analysis_variant == "primary", , drop = FALSE]
  if (nrow(rows) != eligible_n) stop("Structured checkbox row count does not equal the analytic cohort for ", item, ".")
  categories <- checkbox_codebook(metadata, item)
  applicable_n <- sum(as.logical(rows$applicable), na.rm = TRUE)
  observed_valid_n <- sum(rows$state == "valid", na.rm = TRUE)
  missing_n <- sum(rows$state == "missing", na.rm = TRUE)
  invalid_n <- sum(rows$state %in% c("invalid", "partial_invalid"), na.rm = TRUE)
  structural_skip_n <- sum(rows$state == "structural_skip", na.rm = TRUE)
  out <- lapply(seq_len(nrow(categories)), function(i) {
    n <- sum(checkbox_selections$item == item & checkbox_selections$option == categories$canonical_option[[i]], na.rm = TRUE)
    data.frame(
      domain = item_info$domain[[1]], item = item, item_type = "checkbox", analysis_variant = "primary",
      response = categories$canonical_option[[i]], display_order = categories$display_order[[i]], n = n,
      eligible_n = eligible_n, applicable_n = applicable_n, observed_valid_n = observed_valid_n, inferred_n = 0L,
      missing_n = missing_n, invalid_n = invalid_n, structural_skip_n = structural_skip_n,
      denominator = observed_valid_n, percent = if (observed_valid_n) round(100 * n / observed_valid_n, 1) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}

primary_items <- metadata$item_spec[
  metadata$item_spec$primary_analysis == "yes" & metadata$item_spec$item_type %in% c("single_choice", "ordinal", "likert", "checkbox"),
  , drop = FALSE
]
sensitivity_variants <- metadata$derivation_rules$analysis_variant[
  metadata$derivation_rules$analysis_name == "contributed"
]
if (length(sensitivity_variants) != 1L) {
  stop("Controlled metadata must define exactly one contribution-status sensitivity variant.")
}
summary_tables <- list()
for (i in seq_len(nrow(primary_items))) {
  item <- primary_items$analysis_name[[i]]
  if (identical(primary_items$item_type[[i]], "checkbox")) {
    summary_tables[[length(summary_tables) + 1L]] <- summarise_checkbox(item)
  } else if (identical(item, "contributed")) {
    summary_tables[[length(summary_tables) + 1L]] <- summarise_scalar(item, "primary")
    summary_tables[[length(summary_tables) + 1L]] <- summarise_scalar(item, sensitivity_variants[[1]])
  } else {
    summary_tables[[length(summary_tables) + 1L]] <- summarise_scalar(item, "primary")
  }
}
structured_summary <- do.call(rbind, summary_tables)
structured_summary <- structured_summary[order(structured_summary$domain, structured_summary$item, structured_summary$analysis_variant, structured_summary$display_order), summary_columns]

cohort_flow <- data.frame(
  stage = c("exported_records", "valid_consent_records", "eligible_records", "analytic_cohort_records"),
  n = as.integer(c(
    validation_manifest$validation$exported_records,
    validation_manifest$validation$valid_consent_records,
    validation_manifest$validation$eligible_records,
    validation_manifest$validation$analytic_cohort_records
  )),
  stringsAsFactors = FALSE
)

valid_states <- c("valid", "inferred")
pair_rows <- metadata$exploratory_pairs
cross_tabs <- list()
cross_tab_diagnostics <- list()
for (index in seq_len(nrow(pair_rows))) {
  pair <- pair_rows[index, , drop = FALSE]
  item_rows <- function(item) {
    rows <- structured[
      structured$item == item & structured$analysis_variant == pair$analysis_variant[[1]],
      c("record_id", "applicable", "state", "value"), drop = FALSE
    ]
    if (nrow(rows) != eligible_n || anyDuplicated(rows$record_id)) {
      stop("Exploratory pair input is not one row per analytic record for ", item, ".")
    }
    rows
  }
  left <- item_rows(pair$row_item[[1]])
  right <- item_rows(pair$column_item[[1]])
  names(left)[names(left) == "applicable"] <- "row_applicable"
  names(left)[names(left) == "state"] <- "row_state"
  names(left)[names(left) == "value"] <- "row_response"
  names(right)[names(right) == "applicable"] <- "column_applicable"
  names(right)[names(right) == "state"] <- "column_state"
  names(right)[names(right) == "value"] <- "column_response"
  joined <- merge(left, right, by = "record_id", sort = FALSE)
  if (nrow(joined) != eligible_n || anyDuplicated(joined$record_id)) {
    stop("Exploratory pair join is not one row per analytic record for ", pair$pair_id[[1]], ".")
  }
  pairwise_complete <- joined$row_state %in% valid_states & joined$column_state %in% valid_states
  diagnostics <- data.frame(
    pair_id = pair$pair_id[[1]],
    row_item = pair$row_item[[1]],
    column_item = pair$column_item[[1]],
    analysis_variant = pair$analysis_variant[[1]],
    internal_only = pair$internal_only[[1]],
    eligible_n = eligible_n,
    row_applicable_n = sum(as.logical(joined$row_applicable), na.rm = TRUE),
    column_applicable_n = sum(as.logical(joined$column_applicable), na.rm = TRUE),
    pairwise_applicable_n = sum(as.logical(joined$row_applicable) & as.logical(joined$column_applicable), na.rm = TRUE),
    row_valid_n = sum(joined$row_state %in% valid_states),
    column_valid_n = sum(joined$column_state %in% valid_states),
    pairwise_complete_n = sum(pairwise_complete),
    pairwise_excluded_n = sum(!pairwise_complete),
    rationale = pair$rationale[[1]],
    stringsAsFactors = FALSE
  )
  cross_tab_diagnostics[[length(cross_tab_diagnostics) + 1L]] <- diagnostics
  if (any(pairwise_complete)) {
    complete_rows <- joined[pairwise_complete, c("row_response", "column_response"), drop = FALSE]
    row_info <- item_row(metadata, pair$row_item[[1]])
    column_info <- item_row(metadata, pair$column_item[[1]])
    row_categories <- scalar_codebook(metadata, pair$row_item[[1]], row_info$item_type[[1]])
    column_categories <- scalar_codebook(metadata, pair$column_item[[1]], column_info$item_type[[1]])
    complete_rows$row_response <- factor(complete_rows$row_response, levels = row_categories$canonical_value)
    complete_rows$column_response <- factor(complete_rows$column_response, levels = column_categories$canonical_value)
    tab <- as.data.frame(table(complete_rows$row_response, complete_rows$column_response), stringsAsFactors = FALSE)
    names(tab) <- c("row_response", "column_response", "n")
    tab <- tab[tab$n > 0L, , drop = FALSE]
    if (nrow(tab)) {
      tab$row_response <- as.character(tab$row_response)
      tab$column_response <- as.character(tab$column_response)
      tab$row_display_order <- row_categories$display_order[match(tab$row_response, row_categories$canonical_value)]
      tab$column_display_order <- column_categories$display_order[match(tab$column_response, column_categories$canonical_value)]
      tab <- tab[order(tab$row_display_order, tab$column_display_order), , drop = FALSE]
      tab$pair_id <- pair$pair_id[[1]]
      tab$row_item <- pair$row_item[[1]]
      tab$row_analysis_variant <- pair$analysis_variant[[1]]
      tab$column_item <- pair$column_item[[1]]
      tab$column_analysis_variant <- pair$analysis_variant[[1]]
      tab$pairwise_complete_n <- diagnostics$pairwise_complete_n[[1]]
      cross_tabs[[length(cross_tabs) + 1L]] <- tab[, c(
        "pair_id", "row_item", "row_analysis_variant", "row_response", "row_display_order",
        "column_item", "column_analysis_variant", "column_response", "column_display_order", "n", "pairwise_complete_n"
      )]
    }
  }
}
exploratory_cross_tabs <- if (length(cross_tabs)) do.call(rbind, cross_tabs) else data.frame(
  pair_id = character(), row_item = character(), row_analysis_variant = character(), row_response = character(),
  row_display_order = integer(), column_item = character(), column_analysis_variant = character(),
  column_response = character(), column_display_order = integer(), n = integer(), pairwise_complete_n = integer(),
  stringsAsFactors = FALSE
)
exploratory_cross_tab_summary <- do.call(rbind, cross_tab_diagnostics)

contribution_sensitivity <- structured_summary[
  structured_summary$item == "contributed",
  c("analysis_variant", "response", "n", "denominator", "percent", "observed_valid_n", "inferred_n", "missing_n", "invalid_n")
]

summary_path <- file.path(context$run_dir, "outputs", "internal", "structured-item-summary.csv")
cohort_path <- file.path(context$run_dir, "outputs", "internal", "cohort-flow.csv")
sensitivity_path <- file.path(context$run_dir, "outputs", "internal", "contribution-sensitivity.csv")
cross_tabs_path <- file.path(context$run_dir, "outputs", "internal", "exploratory-crosstabs.csv")
cross_tab_summary_path <- file.path(context$run_dir, "outputs", "internal", "exploratory-crosstab-summary.csv")
memo_path <- file.path(context$run_dir, "reports", "internal-results-memo.md")
write_csv_atomic(structured_summary, summary_path)
write_csv_atomic(cohort_flow, cohort_path)
write_csv_atomic(contribution_sensitivity, sensitivity_path)
write_csv_atomic(exploratory_cross_tabs, cross_tabs_path)
write_csv_atomic(exploratory_cross_tab_summary, cross_tab_summary_path)
memo <- c(
  "# Internal results memo",
  "",
  "This restricted memo is generated from the manifest-bound structured analysis.",
  "It is not a public release artifact and must not be shared without disclosure review.",
  "",
  paste0("Analytic cohort: ", eligible_n, " records."),
  paste0("Structured primary items summarized: ", length(unique(structured_summary$item))),
  paste0("Exploratory cross-tab cells generated: ", nrow(exploratory_cross_tabs)),
  "",
  "Interpretation must remain descriptive and context-specific; no causal, response-rate, or population-generalizable claims are supported by these outputs."
)
writeLines(memo, memo_path, useBytes = TRUE)

analysis_manifest_path <- write_analysis_manifest(
  root = root,
  run_dir = context$run_dir,
  transformation_manifest_path = transformation_manifest_path,
  output_paths = list(
    structured_summary = summary_path,
    cohort_flow = cohort_path,
    contribution_sensitivity = sensitivity_path,
    exploratory_cross_tabs = cross_tabs_path,
    exploratory_cross_tab_summary = cross_tab_summary_path,
    internal_results_memo = memo_path
  ),
  analysis = list(
    status = "passed",
    analytic_cohort_records = eligible_n,
    primary_items = unique(primary_items$analysis_name),
    exploratory_cross_tab_pairs = lapply(seq_len(nrow(pair_rows)), function(index) {
      list(
        pair_id = pair_rows$pair_id[[index]],
        row_item = pair_rows$row_item[[index]],
        column_item = pair_rows$column_item[[index]],
        analysis_variant = pair_rows$analysis_variant[[index]],
        internal_only = pair_rows$internal_only[[index]]
      )
    })
  )
)
message("Internal analysis passed. Manifest: ", analysis_manifest_path)
