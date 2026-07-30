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
source(file.path(root, "scripts", "lib", "survey_source.R"))

cli <- parse_cli()
allowed_flags <- c("synthetic")
allowed_values <- c("run-id", "synthetic-root", "source-freeze-id")
if (length(setdiff(cli$flags, allowed_flags)) || length(setdiff(names(cli$values), allowed_values))) {
  stop("Usage: Rscript scripts/run.R validate [--synthetic --synthetic-root <path>] --run-id <id> [--source-freeze-id <id>]")
}
synthetic <- has_flag(cli, "synthetic")
mode <- if (synthetic) "synthetic" else "real"
run_id <- validate_run_id(option_value(cli, "run-id", required = TRUE))
synthetic_root <- option_value(cli, "synthetic-root")
freeze_id <- option_value(cli, "source-freeze-id")
if (!synthetic && !is.null(synthetic_root)) stop("--synthetic-root is valid only with --synthetic.")
if (synthetic && !is.null(freeze_id)) stop("--source-freeze-id is valid only for a real source.")
if (!synthetic && is.null(freeze_id)) stop("Real validation requires --source-freeze-id from immutable intake evidence.")
if (!synthetic) {
  require_restricted_operation_authorization(root, "validate")
  if (git_metadata(root)$dirty) stop("Real validation requires a clean Git worktree.")
}

metadata <- read_metadata(root)
map <- metadata$variable_map
schema_paths <- metadata$paths
run_dir <- new_run_dir(root, mode, run_id, synthetic_root = synthetic_root)

source_context <- read_authoritative_survey_source(
  root = root,
  metadata = metadata,
  mode = mode,
  freeze_id = if (synthetic) NULL else freeze_id
)
dat <- source_context$data
source <- source_context$source
source_freeze <- source_context$source_freeze

if (ncol(dat) != nrow(map)) stop("Schema failure: expected ", nrow(map), " populated columns; found ", ncol(dat), ".")
if (!synthetic && nrow(dat) != 12L) stop("Input invariant failure: expected 12 response rows; found ", nrow(dat), ".")
if (!all(c("consent", "eligible") %in% names(dat))) stop("Schema failure: consent and eligibility fields are required.")

consent_valid <- trimws(as.character(dat$consent)) == "I consent to participate in this study"
eligible_valid <- tolower(trimws(as.character(dat$eligible))) == "yes"
consent_valid[is.na(consent_valid)] <- FALSE
eligible_valid[is.na(eligible_valid)] <- FALSE
in_cohort <- consent_valid & eligible_valid
if (!any(consent_valid)) stop("Cohort failure: no records contain the approved consent value.")
if (!any(eligible_valid)) stop("Cohort failure: no records contain the approved eligibility value.")
if (!any(in_cohort)) stop("Cohort failure: no record passes both the approved consent and eligibility rules.")

write_csv_atomic <- function(table, path) {
  temporary <- paste0(path, ".tmp-", Sys.getpid())
  on.exit(unlink(temporary), add = TRUE)
  utils::write.csv(table, temporary, row.names = FALSE, na = "")
  if (!file.rename(temporary, path)) stop("Unable to atomically write CSV artifact.")
}

cohort_ledger <- data.frame(
  data.frame(
    record_id = sprintf("record-%03d", seq_len(nrow(dat))),
    source_row = seq_len(nrow(dat)),
    consent_valid = consent_valid,
    eligible_valid = eligible_valid,
    in_cohort = in_cohort,
    stringsAsFactors = FALSE
  )
)
ledger_path <- file.path(run_dir, "derived", "cohort-ledger.csv")
write_csv_atomic(cohort_ledger, ledger_path)

structured_fields <- metadata$item_spec$analysis_name[
  metadata$item_spec$primary_analysis == "yes" &
    metadata$item_spec$item_type %in% c("single_choice", "ordinal", "likert", "checkbox")
]
if (!all(structured_fields %in% names(dat)) || any(structured_fields %in% c("timestamp", "consent", "eligible"))) {
  stop("Structured-analysis field contract is invalid.")
}

validation <- list(
  status = "passed",
  exported_records = nrow(dat),
  valid_consent_records = sum(consent_valid),
  eligible_records = sum(eligible_valid),
  analytic_cohort_records = sum(in_cohort),
  excluded_consent_records = sum(!consent_valid),
  excluded_eligibility_records = sum(consent_valid & !eligible_valid),
  populated_columns = ncol(dat),
  structured_analysis_fields = length(structured_fields),
  derivative_policy = "cohort_ledger_only"
)
summary_path <- file.path(run_dir, "reports", "validation-summary.json")
write_json_atomic(validation, summary_path)
manifest_path <- write_validation_manifest(
  root = root,
  run_dir = run_dir,
  mode = mode,
  run_id = run_id,
  source = source,
  schema_paths = schema_paths,
  output_paths = list(
    cohort_ledger = ledger_path,
    validation_summary = summary_path
  ),
  validation = validation,
  source_freeze = source_freeze,
  analysis_controls = analysis_control_fingerprint(root)
)
message("Validation passed. Manifest: ", manifest_path)
