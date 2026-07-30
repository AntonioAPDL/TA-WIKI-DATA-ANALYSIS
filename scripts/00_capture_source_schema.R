#!/usr/bin/env Rscript

# Freeze non-response source provenance and schema evidence before validation.
# This task reads the authoritative workbook only from the approved restricted
# root. It never writes source data, free text, timestamps, or restricted
# response values into the repository or console output.

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
activate_project(root)
source(file.path(root, "scripts", "lib", "restricted_root.R"))
source(file.path(root, "scripts", "lib", "run_manifest.R"))

cli <- parse_cli()
allowed_values <- c("freeze-id")
if (length(cli$flags) || length(setdiff(names(cli$values), allowed_values))) {
  stop("Usage: Rscript scripts/run.R intake --freeze-id <id>")
}

freeze_id <- validate_run_id(option_value(cli, "freeze-id", required = TRUE))
authorization <- read_restricted_operation_authorization(root, "intake")
source_context <- read_restricted_source_context(root, authorization)
if (git_metadata(root)$dirty) stop("Source intake requires a clean Git worktree.")
if (!requireNamespace("readxl", quietly = TRUE)) stop("Package readxl is required for source intake.")

freeze_parent <- freeze_parent_directory(root, create = TRUE)
freeze_dir <- freeze_directory(root, freeze_id)
if (dir.exists(freeze_dir)) stop("Source-freeze directory already exists; source freezes are immutable.")
staging_dir <- file.path(freeze_parent, paste0(".", freeze_id, ".staging-", Sys.getpid()))
if (dir.exists(staging_dir)) stop("A prior incomplete source-freeze staging directory requires restricted review.")
dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(staging_dir)) stop("Unable to create the source-freeze staging directory.")
freeze_published <- FALSE
on.exit({
  if (!freeze_published && dir.exists(staging_dir)) unlink(staging_dir, recursive = TRUE, force = TRUE)
}, add = TRUE)

# Copy the approved staging export before inspecting it. All schema evidence
# and downstream validation then bind the exact frozen bytes, not a mutable raw
# staging file that could later be replaced or removed.
staged_source <- restricted_source_workbook(root)
frozen_source <- copy_source_to_freeze_staging(root, staged_source, staging_dir)
source_path <- frozen_source$path

sheets <- readxl::excel_sheets(source_path)
if (length(sheets) != 1L) stop("Schema failure: workbook must contain exactly one response sheet.")
dat <- as.data.frame(
  readxl::read_excel(source_path, sheet = sheets[[1]], .name_repair = "minimal"),
  stringsAsFactors = FALSE
)
headers <- names(dat)
if (!length(headers) || anyNA(headers) || any(trimws(headers) == "") || anyDuplicated(headers)) {
  stop("Schema failure: source headers must be unique and non-empty.")
}

map_path <- file.path(root, "data", "metadata", "variable_map.csv")
map <- read.csv(map_path, stringsAsFactors = FALSE)
required_map_columns <- c("position", "analysis_name", "role", "restricted")
if (!identical(names(map), required_map_columns) || !identical(map$position, seq_len(nrow(map)))) {
  stop("Variable-map schema failure.")
}
if (ncol(dat) != nrow(map)) {
  stop("Schema failure: expected ", nrow(map), " populated columns; found ", ncol(dat), ".")
}
item_spec_path <- file.path(root, "data", "metadata", "item-spec.csv")
item_spec <- read.csv(item_spec_path, stringsAsFactors = FALSE)
required_item_spec_columns <- c(
  "position", "analysis_name", "item_type", "domain", "primary_analysis",
  "skip_rule", "privacy_class", "release_eligibility"
)
if (!identical(names(item_spec), required_item_spec_columns) ||
    !identical(item_spec$position, map$position) ||
    !identical(item_spec$analysis_name, map$analysis_name)) {
  stop("Item-spec schema failure.")
}
assert_live_header_contract(root, headers)

safe_values <- function(values) {
  normalized <- trimws(as.character(values))
  normalized[is.na(normalized) | normalized == ""] <- "<missing>"
  as.list(sort(table(normalized), decreasing = TRUE))
}

names(dat) <- map$analysis_name
safe_names <- map$analysis_name[map$restricted == "no"]
restricted_names <- map$analysis_name[map$restricted == "yes"]
structured_restricted <- item_spec$analysis_name[
  item_spec$item_type %in% c("single_choice", "ordinal", "likert", "checkbox") &
    map$restricted == "yes"
]
profile <- list(
  schema_version = "1.0",
  freeze_id = freeze_id,
  source_id = "survey_final",
  source_sha256 = frozen_source$sha256,
  response_rows = nrow(dat),
  populated_columns = ncol(dat),
  sheet_name = sheets[[1]],
  headers_sha256 = sha256_text(headers),
  categorical_values = stats::setNames(lapply(safe_names, function(name) safe_values(dat[[name]])), safe_names),
  structured_restricted_values = stats::setNames(
    lapply(structured_restricted, function(name) safe_values(dat[[name]])),
    structured_restricted
  ),
  restricted_completeness = stats::setNames(lapply(restricted_names, function(name) {
    values <- trimws(as.character(dat[[name]]))
    list(
      nonmissing = sum(!is.na(values) & values != ""),
      missing = sum(is.na(values) | values == "")
    )
  }), restricted_names)
)

header_path <- file.path(staging_dir, "candidate-live-header-manifest.csv")
header_temp <- paste0(header_path, ".tmp-", Sys.getpid())
utils::write.csv(data.frame(source_header = headers, stringsAsFactors = FALSE), header_temp, row.names = FALSE, na = "")
if (!file.rename(header_temp, header_path)) stop("Unable to atomically write candidate header manifest.")
profile_path <- file.path(staging_dir, "schema-profile.json")
write_json_atomic(profile, profile_path)

provenance <- list(
  schema_version = "1.2",
  status = "frozen",
  freeze_id = freeze_id,
  generated_at_utc = utc_now(),
  governance_authorization = list(
    id = authorization$id,
    record_sha256 = authorization$record_sha256,
    signed_artifact_sha256 = authorization$signed_artifact_sha256
  ),
  source_access_context_sha256 = source_context$sha256,
  source_access_record_reference = source_context$source_access_record_reference,
  source = list(
    id = source_context$source$id,
    filename = source_context$source$filename,
    frozen_filename = frozen_source$filename,
    sha256 = frozen_source$sha256,
    bytes = frozen_source$bytes,
    drive_file_id = source_context$source$drive_file_id,
    drive_revision_id = source_context$source$drive_revision_id,
    sheet_count = length(sheets),
    sheet_name = sheets[[1]],
    response_rows = nrow(dat),
    populated_columns = ncol(dat),
    headers_sha256 = sha256_text(headers)
  ),
  artifacts = list(
    frozen_workbook = list(filename = basename(frozen_source$path), sha256 = frozen_source$sha256),
    candidate_header_manifest = list(filename = basename(header_path), sha256 = sha256_file(header_path)),
    schema_profile = list(filename = basename(profile_path), sha256 = sha256_file(profile_path))
  ),
  environment = manifest_environment(root)
)
provenance_path <- file.path(staging_dir, "source-provenance.json")
write_json_atomic(provenance, provenance_path)
if (!file.rename(staging_dir, freeze_dir)) stop("Unable to atomically publish the immutable source freeze.")
freeze_published <- TRUE
provenance_path <- file.path(freeze_dir, "source-provenance.json")

message("Source intake passed. An immutable source-freeze record was created in restricted storage.")
