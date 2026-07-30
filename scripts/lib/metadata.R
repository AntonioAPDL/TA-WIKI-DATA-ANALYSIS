# Controlled metadata and normalization helpers. These files are respondent-free
# contracts; every real transformation binds their hashes in the run manifest.

metadata_paths <- function(root) {
  list(
    variable_map = file.path(root, "data", "metadata", "variable_map.csv"),
    item_spec = file.path(root, "data", "metadata", "item-spec.csv"),
    live_header_manifest = file.path(root, "data", "metadata", "live-header-manifest.csv"),
    category_codebook = file.path(root, "data", "metadata", "category-codebook.csv"),
    checkbox_options = file.path(root, "data", "metadata", "checkbox-options.csv"),
    derivation_rules = file.path(root, "data", "metadata", "derivation-rules.csv"),
    exploratory_pairs = file.path(root, "data", "metadata", "exploratory-pairs.csv"),
    publication_labels = file.path(root, "data", "metadata", "publication-labels.csv"),
    transformation_rules = file.path(root, "data", "metadata", "transformation-rules.csv"),
    recoding_rules = file.path(root, "data", "metadata", "recoding-rules.md"),
    analysis_specification = file.path(root, "docs", "analysis-specification.md"),
    release_policy = file.path(root, "config", "release-policy.yml")
  )
}

normalize_display_text <- function(values) {
  values <- as.character(values)
  values[is.na(values)] <- NA_character_
  values <- gsub("[[:cntrl:]]+", " ", values)
  values <- gsub("[[:space:]]+", " ", values)
  trimws(values)
}

normalize_key <- function(values) {
  values <- normalize_display_text(values)
  values <- enc2utf8(values)
  values <- gsub("\u00a0", " ", values, fixed = TRUE)
  values <- gsub("\u2018", "'", values, fixed = TRUE)
  values <- gsub("\u2019", "'", values, fixed = TRUE)
  values <- gsub("\u2013", "-", values, fixed = TRUE)
  values <- gsub("\u2014", "-", values, fixed = TRUE)
  tolower(values)
}

validate_codebook_entries <- function(rows, value_column, label) {
  if (!is.data.frame(rows) || !all(c(value_column, "display_order") %in% names(rows)) || !nrow(rows)) {
    stop(label, " has an unsupported schema.")
  }
  keys <- normalize_key(rows[[value_column]])
  if (anyNA(keys) || any(!nzchar(keys))) {
    stop(label, " contains an empty response label.")
  }
  if (anyDuplicated(keys)) {
    stop(label, " contains duplicate normalized response labels.")
  }
  orders <- suppressWarnings(as.numeric(rows$display_order))
  if (anyNA(orders) || any(!is.finite(orders)) || any(orders != floor(orders)) || any(orders < 1)) {
    stop(label, " contains invalid display orders.")
  }
  if (anyDuplicated(as.integer(orders))) {
    stop(label, " contains duplicate display orders.")
  }
  invisible(TRUE)
}

read_csv_contract <- function(path, expected_columns) {
  if (!file.exists(path)) stop("Missing controlled metadata file: ", basename(path))
  table <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = character())
  if (!identical(names(table), expected_columns)) {
    stop("Metadata schema failure in ", basename(path), ".")
  }
  table
}

read_metadata <- function(root) {
  paths <- metadata_paths(root)
  variable_map <- read_csv_contract(paths$variable_map, c("position", "analysis_name", "role", "restricted"))
  item_spec <- read_csv_contract(
    paths$item_spec,
    c("position", "analysis_name", "item_type", "domain", "primary_analysis", "skip_rule", "privacy_class", "release_eligibility")
  )
  category_codebook <- read_csv_contract(paths$category_codebook, c("analysis_name", "canonical_value", "display_order"))
  checkbox_options <- read_csv_contract(paths$checkbox_options, c("analysis_name", "canonical_option", "display_order"))
  derivation_rules <- read_csv_contract(
    paths$derivation_rules,
    c(
      "rule_id", "analysis_name", "analysis_variant", "evidence_item", "evidence_state",
      "when_primary_state", "derived_value", "derived_state", "scope", "rationale"
    )
  )
  exploratory_pairs <- read_csv_contract(
    paths$exploratory_pairs,
    c("pair_id", "row_item", "column_item", "rationale", "analysis_variant", "internal_only")
  )
  publication_labels <- read_csv_contract(
    paths$publication_labels,
    c("analysis_name", "publication_label", "domain_label", "domain_order")
  )
  transformation_rules <- read_csv_contract(paths$transformation_rules, c("rule_id", "analysis_name", "operation", "match_key", "replacement", "scope", "rationale"))

  if (!identical(variable_map$position, seq_len(nrow(variable_map))) ||
      anyDuplicated(variable_map$analysis_name) ||
      !all(variable_map$restricted %in% c("yes", "no"))) {
    stop("Variable-map contract failure.")
  }
  if (!identical(item_spec$position, variable_map$position) ||
      !identical(item_spec$analysis_name, variable_map$analysis_name) ||
      anyDuplicated(item_spec$analysis_name) ||
      !all(item_spec$primary_analysis %in% c("yes", "no"))) {
    stop("Item-spec contract failure.")
  }
  allowed_types <- c("timestamp", "consent", "eligibility", "single_choice", "ordinal", "likert", "checkbox", "open_text")
  if (!all(item_spec$item_type %in% allowed_types)) stop("Item-spec contains an unsupported item type.")
  if (anyDuplicated(paste(category_codebook$analysis_name, normalize_key(category_codebook$canonical_value), sep = "\r"))) {
    stop("Category-codebook contains duplicate normalized values.")
  }
  if (anyDuplicated(paste(checkbox_options$analysis_name, normalize_key(checkbox_options$canonical_option), sep = "\r"))) {
    stop("Checkbox-option registry contains duplicate normalized options.")
  }
  if (anyDuplicated(transformation_rules$rule_id) ||
      !all(transformation_rules$operation %in% c("replace_exact", "replace_substring")) ||
      !all(transformation_rules$scope %in% c("scalar", "checkbox"))) {
    stop("Transformation-rule registry failure.")
  }

  scalar_primary_names <- item_spec$analysis_name[
    item_spec$primary_analysis == "yes" &
      item_spec$item_type %in% c("single_choice", "ordinal", "likert")
  ]
  checkbox_primary_names <- item_spec$analysis_name[
    item_spec$primary_analysis == "yes" & item_spec$item_type == "checkbox"
  ]
  valid_states <- c("valid", "missing", "invalid", "partial_invalid", "structural_skip")
  derivation_ok <- nrow(derivation_rules) > 0L &&
    !anyNA(derivation_rules) &&
    !anyDuplicated(derivation_rules$rule_id) &&
    all(grepl("^RULE-[A-Z]+-[0-9]{3,}$", derivation_rules$rule_id)) &&
    all(derivation_rules$analysis_name %in% scalar_primary_names) &&
    all(derivation_rules$evidence_item %in% checkbox_primary_names) &&
    all(startsWith(derivation_rules$analysis_variant, "sensitivity_")) &&
    all(derivation_rules$evidence_state %in% valid_states) &&
    all(derivation_rules$when_primary_state %in% valid_states) &&
    all(derivation_rules$derived_state %in% c("valid", "inferred")) &&
    all(derivation_rules$scope == "internal_sensitivity") &&
    all(nzchar(trimws(derivation_rules$derived_value))) &&
    all(nzchar(trimws(derivation_rules$rationale))) &&
    !anyDuplicated(paste(derivation_rules$analysis_name, derivation_rules$analysis_variant, sep = "\r"))
  if (!derivation_ok) stop("Derivation-rule registry failure.")

  structured_primary <- item_spec[
    item_spec$primary_analysis == "yes" & item_spec$item_type %in% c("single_choice", "ordinal", "likert", "checkbox"),
    , drop = FALSE
  ]
  scalar_primary <- structured_primary[structured_primary$item_type %in% c("single_choice", "ordinal", "likert"), , drop = FALSE]
  if (!nrow(exploratory_pairs) || anyNA(exploratory_pairs) ||
      any(!grepl("^EXP-[0-9]{3,}$", exploratory_pairs$pair_id)) || anyDuplicated(exploratory_pairs$pair_id) ||
      any(!exploratory_pairs$row_item %in% scalar_primary$analysis_name) ||
      any(!exploratory_pairs$column_item %in% scalar_primary$analysis_name) ||
      any(exploratory_pairs$row_item == exploratory_pairs$column_item) ||
      any(exploratory_pairs$analysis_variant != "primary") || any(exploratory_pairs$internal_only != "yes") ||
      any(!nzchar(trimws(exploratory_pairs$rationale)))) {
    stop("Exploratory-pair registry failure.")
  }
  canonical_pairs <- vapply(seq_len(nrow(exploratory_pairs)), function(index) {
    paste(sort(c(exploratory_pairs$row_item[[index]], exploratory_pairs$column_item[[index]])), collapse = "\r")
  }, character(1))
  if (anyDuplicated(canonical_pairs)) stop("Exploratory-pair registry contains duplicate or reversed pairs.")

  releaseable <- structured_primary[structured_primary$release_eligibility == "review_required", , drop = FALSE]
  labels_ok <- nrow(publication_labels) == nrow(releaseable) &&
    !anyNA(publication_labels) && !anyDuplicated(publication_labels$analysis_name) &&
    setequal(publication_labels$analysis_name, releaseable$analysis_name) &&
    all(nzchar(trimws(publication_labels$publication_label))) &&
    all(nzchar(trimws(publication_labels$domain_label)))
  orders <- suppressWarnings(as.numeric(publication_labels$domain_order))
  if (!labels_ok || anyNA(orders) || any(!is.finite(orders)) || any(orders != floor(orders)) || any(orders < 1L)) {
    stop("Publication-label registry failure.")
  }
  domain_order_map <- split(as.integer(orders), publication_labels$domain_label)
  if (any(vapply(domain_order_map, function(values) length(unique(values)) != 1L, logical(1))) ||
      anyDuplicated(vapply(domain_order_map, `[[`, integer(1), 1L))) {
    stop("Publication-label registry has inconsistent domain ordering.")
  }

  metadata <- list(
    paths = paths,
    variable_map = variable_map,
    item_spec = item_spec,
    category_codebook = category_codebook,
    checkbox_options = checkbox_options,
    derivation_rules = derivation_rules,
    exploratory_pairs = exploratory_pairs,
    publication_labels = publication_labels,
    transformation_rules = transformation_rules
  )

  scalar_items <- metadata$item_spec[metadata$item_spec$item_type %in% c("single_choice", "ordinal", "likert"), , drop = FALSE]
  for (index in seq_len(nrow(scalar_items))) {
    scalar_codebook(metadata, scalar_items$analysis_name[[index]], scalar_items$item_type[[index]])
  }
  for (index in seq_len(nrow(metadata$derivation_rules))) {
    rule <- metadata$derivation_rules[index, , drop = FALSE]
    item <- item_row(metadata, rule$analysis_name[[1]])
    codebook <- scalar_codebook(metadata, item$analysis_name[[1]], item$item_type[[1]])
    if (!rule$derived_value[[1]] %in% codebook$canonical_value) {
      stop("Derivation-rule registry derives a value outside the controlled codebook.")
    }
  }
  checkbox_items <- metadata$item_spec[metadata$item_spec$item_type == "checkbox", , drop = FALSE]
  for (index in seq_len(nrow(checkbox_items))) {
    checkbox_codebook(metadata, checkbox_items$analysis_name[[index]])
  }

  metadata
}

metadata_hashes <- function(metadata) {
  lapply(metadata$paths, tracked_file_sha256)
}

releaseable_item_names <- function(metadata) {
  releaseable_types <- c("single_choice", "ordinal", "likert", "checkbox")
  metadata$item_spec$analysis_name[
    metadata$item_spec$primary_analysis == "yes" &
      metadata$item_spec$item_type %in% releaseable_types &
      metadata$item_spec$release_eligibility == "review_required"
  ]
}

item_row <- function(metadata, analysis_name) {
  row <- metadata$item_spec[metadata$item_spec$analysis_name == analysis_name, , drop = FALSE]
  if (nrow(row) != 1L) stop("Unknown analysis item: ", analysis_name)
  row
}

scalar_codebook <- function(metadata, analysis_name, item_type) {
  rows <- metadata$category_codebook[metadata$category_codebook$analysis_name == analysis_name, , drop = FALSE]
  if (identical(item_type, "likert")) {
    rows <- rbind(
      rows,
      metadata$category_codebook[metadata$category_codebook$analysis_name == "__likert__", , drop = FALSE]
    )
  }
  if (!nrow(rows)) stop("Missing scalar category codebook for ", analysis_name)
  validate_codebook_entries(rows, "canonical_value", paste0("Scalar codebook for ", analysis_name))
  rows$key <- normalize_key(rows$canonical_value)
  rows[order(rows$display_order, rows$canonical_value), , drop = FALSE]
}

checkbox_codebook <- function(metadata, analysis_name) {
  rows <- metadata$checkbox_options[metadata$checkbox_options$analysis_name == analysis_name, , drop = FALSE]
  if (!nrow(rows)) stop("Missing checkbox-option registry for ", analysis_name)
  validate_codebook_entries(rows, "canonical_option", paste0("Checkbox-option registry for ", analysis_name))
  rows$key <- normalize_key(rows$canonical_option)
  rows <- rows[order(-nchar(rows$key), rows$display_order, rows$canonical_option), , drop = FALSE]
  rows
}

publication_label <- function(metadata, analysis_name) {
  row <- metadata$publication_labels[metadata$publication_labels$analysis_name == analysis_name, , drop = FALSE]
  if (nrow(row) != 1L) stop("Missing publication label for ", analysis_name)
  row
}
