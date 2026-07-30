#!/usr/bin/env Rscript

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
activate_project(root)
source(file.path(root, "scripts", "lib", "restricted_root.R"))
source(file.path(root, "scripts", "lib", "run_manifest.R"))
source(file.path(root, "scripts", "lib", "metadata.R"))
source(file.path(root, "scripts", "lib", "transformations.R"))
source(file.path(root, "scripts", "lib", "analysis_controls.R"))
source(file.path(root, "scripts", "lib", "survey_source.R"))

cli <- parse_cli()
if (length(cli$flags) || !identical(names(cli$values), "manifest")) {
  stop("Transformation requires exactly --manifest <validation-manifest-path>.")
}
validation_manifest_path <- option_value(cli, "manifest", required = TRUE)
if (path_uses_configured_restricted_root(validation_manifest_path)) {
  require_restricted_operation_authorization(root, "transform")
}
manifest_context <- validate_stage_manifest(validation_manifest_path, "validation")
if (identical(manifest_context$manifest$mode, "real")) {
  require_restricted_operation_authorization(root, "transform")
  root_restricted <- restricted_root(root)
  if (!path_within(manifest_context$run_dir, file.path(root_restricted, "runs"))) {
    stop("A real validation manifest must reside under the approved restricted-data root.")
  }
  if (git_metadata(root)$dirty) stop("Real transformation requires a clean Git worktree.")
}
context <- validation_manifest_input(
  validation_manifest_path,
  authorization_action = "transform",
  project_root = root
)

metadata <- read_metadata(root)
expected_schema <- unlist(metadata_hashes(metadata), use.names = TRUE)
manifest_schema <- unlist(context$manifest$schema, use.names = TRUE)
if (!identical(as.character(manifest_schema[names(expected_schema)]), as.character(expected_schema))) {
  stop("Controlled metadata changed after validation; rerun validation before transformation.")
}
if (identical(context$manifest$schema_version, "1.2")) {
  validate_analysis_control_fingerprint(context$manifest$analysis_controls, root, "Validation manifest")
}

ledger <- read.csv(context$inputs$cohort_ledger, check.names = FALSE, stringsAsFactors = FALSE, na.strings = "")
ledger_columns <- c("record_id", "source_row", "consent_valid", "eligible_valid", "in_cohort")
if (!identical(names(ledger), ledger_columns) || !nrow(ledger) || anyDuplicated(ledger$record_id)) {
  stop("Cohort ledger has an unsupported schema.")
}
source_rows <- suppressWarnings(as.integer(ledger$source_row))
if (anyNA(source_rows) || !identical(source_rows, seq_len(nrow(ledger))) ||
    !identical(ledger$record_id, sprintf("record-%03d", seq_len(nrow(ledger))))) {
  stop("Cohort ledger row identity is invalid.")
}
in_cohort <- as.logical(ledger$in_cohort)
in_cohort[is.na(in_cohort)] <- FALSE
if (!any(in_cohort)) stop("No analytic-cohort records are available for transformation.")
source_context <- read_authoritative_survey_source(
  root = root,
  metadata = metadata,
  mode = context$manifest$mode,
  freeze_id = context$manifest$source_freeze$id,
  expected_source = context$manifest$source,
  expected_source_freeze = context$manifest$source_freeze
)
source_dat <- source_context$data
if (nrow(source_dat) != nrow(ledger)) stop("Frozen source row count does not match the cohort ledger.")
structured_fields <- metadata$item_spec$analysis_name[
  metadata$item_spec$primary_analysis == "yes" &
    metadata$item_spec$item_type %in% c("single_choice", "ordinal", "likert", "checkbox")
]
if (!all(structured_fields %in% names(source_dat)) || any(grepl("timestamp|open_text", structured_fields, ignore.case = TRUE))) {
  stop("Structured-analysis field contract is invalid.")
}
dat <- cbind(
  data.frame(record_id = ledger$record_id[in_cohort], stringsAsFactors = FALSE),
  source_dat[in_cohort, structured_fields, drop = FALSE]
)
if (any(c("timestamp", "consent", "eligible", "wished_content", "future_contribution", "change_one", "other_comments") %in% names(dat))) {
  stop("Data-minimization failure: an excluded field reached transformation.")
}

write_csv_atomic <- function(table, path) {
  temporary <- paste0(path, ".tmp-", Sys.getpid())
  on.exit(unlink(temporary), add = TRUE)
  utils::write.csv(table, temporary, row.names = FALSE, na = "")
  if (!file.rename(temporary, path)) stop("Unable to atomically write CSV artifact.")
}
is_nonempty <- function(value) !is.na(value) && nzchar(trimws(as.character(value)))

spec <- metadata$item_spec
analysis_spec <- spec[
  spec$primary_analysis == "yes" & spec$item_type %in% c("single_choice", "ordinal", "likert", "checkbox"),
  , drop = FALSE
]
scalar_spec <- analysis_spec[analysis_spec$item_type %in% c("single_choice", "ordinal", "likert"), , drop = FALSE]
checkbox_spec <- analysis_spec[analysis_spec$item_type == "checkbox", , drop = FALSE]

scalar_values <- data.frame(record_id = dat$record_id, stringsAsFactors = FALSE)
scalar_rows <- list()
checkbox_item_rows <- list()
checkbox_selection_rows <- list()
scalar_states <- list()
scalar_applicability <- list()
scalar_item_metadata <- list()
checkbox_states <- list()
unexpected_rows <- list()
rule_audit <- empty_rule_audit(metadata)
contribution_inferred_sensitivity <- 0L

append_unexpected <- function(item, count) {
  if (count > 0L) unexpected_rows[[length(unexpected_rows) + 1L]] <<- data.frame(item = item, unexpected_nonmissing_n = count, stringsAsFactors = FALSE)
}

for (i in seq_len(nrow(scalar_spec))) {
  item <- scalar_spec$analysis_name[[i]]
  item_type <- scalar_spec$item_type[[i]]
  domain <- scalar_spec$domain[[i]]
  rule <- scalar_spec$skip_rule[[i]]
  applicable <- skip_applicability(scalar_values, rule, variant = "primary")
  applicable[is.na(applicable)] <- FALSE
  values <- rep(NA_character_, nrow(dat))
  states <- rep("structural_skip", nrow(dat))
  unexpected <- 0L
  for (j in seq_len(nrow(dat))) {
    raw <- as.character(dat[[item]][[j]])
    if (!applicable[[j]]) {
      if (is_nonempty(raw)) unexpected <- unexpected + 1L
      next
    }
    recoded <- recode_scalar(raw, item, item_type, metadata, rule_audit)
    values[[j]] <- recoded$value
    states[[j]] <- recoded$state
    rule_audit <- recoded$rule_audit
  }

  scalar_values[[item]] <- values
  scalar_states[[item]] <- states
  scalar_applicability[[item]] <- applicable
  scalar_item_metadata[[item]] <- list(domain = domain, item_type = item_type)
  append_unexpected(item, unexpected)
  scalar_rows[[length(scalar_rows) + 1L]] <- data.frame(
    record_id = dat$record_id,
    item = item,
    domain = domain,
    item_type = item_type,
    analysis_variant = "primary",
    applicable = applicable,
    state = states,
    value = values,
    stringsAsFactors = FALSE
  )
}

for (i in seq_len(nrow(checkbox_spec))) {
  item <- checkbox_spec$analysis_name[[i]]
  domain <- checkbox_spec$domain[[i]]
  rule <- checkbox_spec$skip_rule[[i]]
  applicable <- skip_applicability(scalar_values, rule, variant = "primary")
  applicable[is.na(applicable)] <- FALSE
  states <- rep("structural_skip", nrow(dat))
  unexpected <- 0L
  for (j in seq_len(nrow(dat))) {
    raw <- as.character(dat[[item]][[j]])
    if (!applicable[[j]]) {
      if (is_nonempty(raw)) unexpected <- unexpected + 1L
      next
    }
    parsed <- parse_checkbox(raw, item, metadata, rule_audit)
    states[[j]] <- parsed$state
    rule_audit <- parsed$rule_audit
    if (identical(parsed$state, "valid") && length(parsed$options)) {
      options <- checkbox_codebook(metadata, item)
      display <- options[match(parsed$options, options$canonical_option), c("canonical_option", "display_order"), drop = FALSE]
      checkbox_selection_rows[[length(checkbox_selection_rows) + 1L]] <- data.frame(
        record_id = rep(dat$record_id[[j]], nrow(display)),
        item = rep(item, nrow(display)),
        domain = rep(domain, nrow(display)),
        option = display$canonical_option,
        display_order = display$display_order,
        stringsAsFactors = FALSE
      )
    }
  }
  checkbox_states[[item]] <- states
  append_unexpected(item, unexpected)
  checkbox_item_rows[[length(checkbox_item_rows) + 1L]] <- data.frame(
    record_id = dat$record_id,
    item = item,
    domain = domain,
    item_type = "checkbox",
    analysis_variant = "primary",
    applicable = applicable,
    state = states,
    value = NA_character_,
    stringsAsFactors = FALSE
  )
}

for (index in seq_len(nrow(metadata$derivation_rules))) {
  derivation_rule <- metadata$derivation_rules[index, , drop = FALSE]
  item <- derivation_rule$analysis_name[[1]]
  evidence_item <- derivation_rule$evidence_item[[1]]
  if (is.null(scalar_values[[item]]) || is.null(scalar_states[[item]]) ||
      is.null(scalar_applicability[[item]]) || is.null(scalar_item_metadata[[item]]) ||
      is.null(checkbox_states[[evidence_item]])) {
    stop("Controlled derivation rule cannot resolve its source items.")
  }
  sensitivity <- contribution_status_sensitivity(
    scalar_values[[item]],
    scalar_states[[item]],
    checkbox_states[[evidence_item]],
    derivation_rule
  )
  scalar_rows[[length(scalar_rows) + 1L]] <- data.frame(
    record_id = dat$record_id,
    item = item,
    domain = scalar_item_metadata[[item]]$domain,
    item_type = scalar_item_metadata[[item]]$item_type,
    analysis_variant = derivation_rule$analysis_variant[[1]],
    applicable = scalar_applicability[[item]],
    state = sensitivity$states,
    value = sensitivity$values,
    stringsAsFactors = FALSE
  )
  audit_row <- which(rule_audit$rule_id == derivation_rule$rule_id[[1]])
  if (length(audit_row) != 1L) stop("Controlled derivation rule is absent from the transformation audit.")
  rule_audit$affected_n[[audit_row]] <- sensitivity$inferred_n
  if (identical(item, "contributed")) {
    contribution_inferred_sensitivity <- sensitivity$inferred_n
  }
}
structured <- do.call(rbind, c(scalar_rows, checkbox_item_rows))
checkbox_selections <- if (length(checkbox_selection_rows)) do.call(rbind, checkbox_selection_rows) else data.frame(
  record_id = character(), item = character(), domain = character(), option = character(), display_order = integer(), stringsAsFactors = FALSE
)
unexpected <- if (length(unexpected_rows)) do.call(rbind, unexpected_rows) else data.frame(item = character(), unexpected_nonmissing_n = integer(), stringsAsFactors = FALSE)
state_summary <- do.call(rbind, lapply(split(structured, interaction(structured$item, structured$analysis_variant, drop = TRUE)), function(rows) {
  counts <- state_counts(rows$state)
  data.frame(
    item = rows$item[[1]],
    analysis_variant = rows$analysis_variant[[1]],
    valid_n = counts[["valid"]],
    inferred_n = counts[["inferred"]],
    missing_n = counts[["missing"]],
    invalid_n = counts[["invalid"]] + counts[["partial_invalid"]],
    partial_invalid_n = counts[["partial_invalid"]],
    structural_skip_n = counts[["structural_skip"]],
    stringsAsFactors = FALSE
  )
}))

structured_path <- file.path(context$run_dir, "derived", "structured-items.csv")
checkbox_path <- file.path(context$run_dir, "derived", "checkbox-selections.csv")
audit_path <- file.path(context$run_dir, "reports", "transformation-audit.json")
quality_path <- file.path(context$run_dir, "reports", "data-quality.json")
write_csv_atomic(structured, structured_path)
write_csv_atomic(checkbox_selections, checkbox_path)
audit <- list(
  schema_version = "1.0",
  status = "passed",
  analytic_cohort_records = nrow(dat),
  rule_application = lapply(seq_len(nrow(rule_audit)), function(i) list(rule_id = rule_audit$rule_id[[i]], affected_n = rule_audit$affected_n[[i]])),
  unexpected_nonmissing = lapply(seq_len(nrow(unexpected)), function(i) list(item = unexpected$item[[i]], n = unexpected$unexpected_nonmissing_n[[i]]))
)
write_json_atomic(audit, audit_path)
quality <- list(
  schema_version = "1.0",
  status = "passed",
  analytic_cohort_records = nrow(dat),
  item_state_counts = lapply(seq_len(nrow(state_summary)), function(i) as.list(state_summary[i, , drop = FALSE])),
  unexpected_nonmissing = audit$unexpected_nonmissing
)
write_json_atomic(quality, quality_path)

transform_manifest_path <- write_transform_manifest(
  root = root,
  run_dir = context$run_dir,
  validation_manifest_path = validation_manifest_path,
  output_paths = list(
    structured_items = structured_path,
    checkbox_selections = checkbox_path,
    transformation_audit = audit_path,
    data_quality = quality_path
  ),
  transformation = list(
    status = "passed",
    analytic_cohort_records = nrow(dat),
    metadata_sha256 = metadata_hashes(metadata),
    contribution_status_inferred_primary_n = 0L,
    contribution_status_inferred_sensitivity_n = contribution_inferred_sensitivity,
    contribution_primary_basis = "direct_response"
  )
)
message("Transformation passed. Manifest: ", transform_manifest_path)
