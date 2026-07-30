# Restricted-data root and isolated-run helpers. Real data never belong in the
# repository or Downloads workspace.

normalize_compare_path <- function(path, must_work = TRUE) {
  tolower(normalizePath(path, winslash = "/", mustWork = must_work))
}

path_within <- function(path, parent, must_work = TRUE) {
  child <- normalize_compare_path(path, must_work = must_work)
  base <- normalize_compare_path(parent, must_work = must_work)
  identical(child, base) || startsWith(child, paste0(base, "/"))
}

is_absolute_path <- function(path) grepl("^(?:[A-Za-z]:[\\\\/]|/)", path)

is_filesystem_root <- function(path) {
  normalized <- normalizePath(path, winslash = "/", mustWork = TRUE)
  identical(normalized, "/") ||
    grepl("^[A-Za-z]:/$", normalized) ||
    grepl("^//[^/]+/[^/]+/?$", normalized)
}

is_git_repository_path <- function(path) {
  git <- Sys.which("git")
  if (!nzchar(git)) git <- "C:/Program Files/Git/cmd/git.exe"
  if (!file.exists(git)) {
    stop("Git is required to verify that restricted storage is outside a Git repository.")
  }
  probe <- suppressWarnings(run_command(
    git,
    c("-C", path, "rev-parse", "--is-inside-work-tree", "--is-bare-repository"),
    path
  ))
  if (probe$status != 0L) return(FALSE)
  values <- tolower(trimws(strsplit(probe$output, "\\n", fixed = TRUE)[[1]]))
  any(values == "true")
}

is_nonempty_string <- function(value) {
  is.character(value) && length(value) == 1L && !is.na(value) && nzchar(trimws(value))
}

is_sha256_value <- function(value) {
  is_nonempty_string(value) && grepl("^[0-9a-f]{64}$", value)
}

read_source_header_manifest <- function(path, label = "header manifest") {
  if (!file.exists(path)) stop("Missing ", label, ".")
  headers <- tryCatch(
    # `encoding` preserves UTF-8 header bytes without converting through the
    # process locale, which may not itself be UTF-8 on Windows.
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, encoding = "UTF-8"),
    error = function(error) NULL
  )
  if (is.null(headers) || !identical(names(headers), "source_header")) {
    stop("The ", label, " has an unsupported schema.")
  }
  values <- headers$source_header
  if (!length(values) || anyNA(values) || any(trimws(values) == "") || anyDuplicated(values)) {
    stop("The ", label, " must contain one unique, non-empty source header per row.")
  }
  as.character(values)
}

approved_live_headers <- function(project_root) {
  read_source_header_manifest(
    file.path(project_root, "data", "metadata", "live-header-manifest.csv"),
    label = "approved live-header manifest"
  )
}

assert_live_header_contract <- function(project_root, headers, label = "live source headers") {
  headers <- as.character(headers)
  if (!length(headers) || anyNA(headers) || any(trimws(headers) == "") || anyDuplicated(headers)) {
    stop("Schema failure: ", label, " must be unique and non-empty.")
  }
  if (!identical(headers, approved_live_headers(project_root))) {
    stop("Schema failure: ", label, " do not exactly match the approved manifest.")
  }
  invisible(TRUE)
}

restricted_root <- function(project_root) {
  candidate <- Sys.getenv("TA_WIKI_RESTRICTED_ROOT", unset = "")
  if (!nzchar(candidate)) {
    stop("Real runs require TA_WIKI_RESTRICTED_ROOT to point to approved restricted storage.")
  }
  if (!is_absolute_path(candidate)) stop("TA_WIKI_RESTRICTED_ROOT must be an absolute path.")
  if (!dir.exists(candidate)) stop("TA_WIKI_RESTRICTED_ROOT does not exist.")
  normalized <- normalizePath(candidate, winslash = "/", mustWork = TRUE)
  if (is_filesystem_root(normalized)) {
    stop("TA_WIKI_RESTRICTED_ROOT must be a dedicated directory, not a filesystem root.")
  }
  downloads <- file.path(Sys.getenv("USERPROFILE", unset = path.expand("~")), "Downloads")
  if (path_within(normalized, project_root) || (dir.exists(downloads) && path_within(normalized, downloads))) {
    stop("TA_WIKI_RESTRICTED_ROOT must be outside the repository and Downloads workspace.")
  }
  if (is_git_repository_path(normalized)) {
    stop("TA_WIKI_RESTRICTED_ROOT must not be inside a Git working tree or repository.")
  }
  preflight <- file.path(normalized, "governance", "restricted-root-preflight.json")
  if (!file.exists(preflight)) {
    stop("Restricted-root preflight record is missing. Run scripts/preflight_restricted_root.ps1 before a real run.")
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required to verify restricted-root preflight.")
  evidence <- tryCatch({
    payload <- paste(readLines(preflight, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    payload <- sub("^\ufeff", "", payload)
    jsonlite::fromJSON(payload, simplifyVector = TRUE)
  }, error = function(error) NULL)
  if (is.null(evidence) || !identical(evidence$schema_version, "1.1") ||
      !is_nonempty_string(evidence$checked_at_utc) || !identical(evidence$root_path_recorded, FALSE) ||
      !isTRUE(evidence$dedicated_directory) || !isTRUE(evidence$git_worktree_checked) ||
      !isTRUE(evidence$access_control_passed) || !isTRUE(evidence$outside_repository) ||
      !isTRUE(evidence$outside_downloads) || !identical(evidence$is_git_worktree, FALSE)) {
    stop("Restricted-root preflight record does not satisfy required path/access checks.")
  }
  normalized
}

# A passing restricted-root preflight is a machine check only.  The functions
# below enforce the separate, off-repository operating authorization required
# before a command may read or write restricted material.  They intentionally
# do not make `restricted_root()` itself an authorization gate so that
# `scripts/run.R readiness` can remain a read-only technical-status command.
restricted_operation_catalog <- function() {
  c(
    intake = "survey_source",
    validate = "survey_source",
    transform = "row_level_derivatives",
    analyze = "row_level_derivatives",
    qualitative = "qualitative_material",
    `qualitative-snapshot` = "qualitative_material",
    release = "internal_aggregate",
    `verify-release` = "release_candidate",
    `manuscript-attested-build` = "release_candidate"
  )
}

is_utc_timestamp <- function(value) {
  is_nonempty_string(value) &&
    grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", value)
}

parse_utc_timestamp <- function(value) {
  if (!is_utc_timestamp(value)) return(as.POSIXct(NA))
  as.POSIXct(value, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

is_git_commit_value <- function(value) {
  is_nonempty_string(value) && grepl("^[0-9a-f]{40}$", value)
}

authorization_values <- function(value) {
  if (is.null(value)) return(character())
  as.character(unlist(value, use.names = FALSE))
}

read_restricted_operation_authorization <- function(project_root, action,
                                                    analysis_baseline_git_commit = NULL) {
  catalog <- restricted_operation_catalog()
  if (!is_nonempty_string(action) || !(action %in% names(catalog))) {
    stop("Unsupported restricted operation for governance authorization.")
  }

  root <- restricted_root(project_root)
  authorization_id <- Sys.getenv("TA_WIKI_GOVERNANCE_AUTHORIZATION_ID", unset = "")
  if (!is_nonempty_string(authorization_id)) {
    stop(
      "Restricted operation governance authorization is missing. ",
      "Set TA_WIKI_GOVERNANCE_AUTHORIZATION_ID only in the authorized restricted environment."
    )
  }
  authorization_id <- validate_run_id(authorization_id)
  authorization_dir <- file.path(root, "governance", "operating-authorizations")
  path <- file.path(authorization_dir, paste0(authorization_id, ".json"))
  if (!file.exists(path)) {
    stop("Restricted operation governance authorization record is missing or unavailable.")
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite is required to verify restricted operation governance authorization.")
  }
  record <- tryCatch(jsonlite::read_json(path, simplifyVector = FALSE), error = function(error) NULL)
  if (is.null(record) || !is.list(record)) {
    stop("Restricted operation governance authorization record has invalid JSON.")
  }

  scope <- if (is.list(record$authorization_scope)) record$authorization_scope else list()
  signature <- if (is.list(record$human_signature)) record$human_signature else list()
  artifact <- if (is.list(signature$signed_artifact)) signature$signed_artifact else list()
  operations <- authorization_values(scope$authorized_operations)
  categories <- authorization_values(scope$restricted_data_categories)
  control_names <- c(
    "storage", "encryption", "backup", "retention", "incident_response",
    "access_roles", "analysis_scope", "sharing_scope"
  )
  controls_ok <- is.list(scope$operating_controls) &&
    all(vapply(control_names, function(name) isTRUE(scope$operating_controls[[name]]), logical(1)))
  required_category <- unname(catalog[[action]])

  issued_at <- parse_utc_timestamp(record$issued_at_utc)
  expires_at <- parse_utc_timestamp(record$expires_at_utc)
  signed_at <- parse_utc_timestamp(signature$signed_at_utc)
  dates_ok <- !is.na(issued_at) && !is.na(signed_at) && !is.na(expires_at) &&
    issued_at <= signed_at && signed_at <= expires_at && expires_at > Sys.time()

  preflight_path <- file.path(root, "governance", "restricted-root-preflight.json")
  git <- git_metadata(project_root)
  artifact_filename <- if (is.list(artifact)) artifact$filename else NULL
  artifact_name_ok <- is_nonempty_string(artifact_filename) &&
    identical(basename(artifact_filename), artifact_filename) &&
    !grepl("[\\\\/]", artifact_filename)
  artifact_path <- if (artifact_name_ok) file.path(authorization_dir, artifact_filename) else NA_character_
  artifact_path_ok <- artifact_name_ok && file.exists(artifact_path)
  if (artifact_path_ok) {
    artifact_path <- normalizePath(artifact_path, winslash = "/", mustWork = TRUE)
    artifact_path_ok <- path_within(artifact_path, authorization_dir) && !isTRUE(file.info(artifact_path)$isdir)
  }
  artifact_ok <- artifact_path_ok && is_sha256_value(artifact$sha256) &&
    identical(artifact$sha256, sha256_file(artifact_path)) &&
    isTRUE(file.info(artifact_path)$size > 0)

  signature_methods <- c("institutional_e_signature", "wet_signature_scan")
  signature_ok <- is.list(signature) &&
    is_nonempty_string(signature$signer_name) && is_nonempty_string(signature$signer_role) &&
    is_nonempty_string(signature$method) && signature$method %in% signature_methods && artifact_ok
  legacy_schema <- identical(record$schema_version, "1.0")
  authorized_analysis_commit <- scope$authorized_git_commit
  requested_baseline_ok <- is.null(analysis_baseline_git_commit) ||
    (is_git_commit_value(analysis_baseline_git_commit) && identical(analysis_baseline_git_commit, authorized_analysis_commit))
  current_baseline_ok <- is_git_commit_value(authorized_analysis_commit) &&
    identical(authorized_analysis_commit, git$commit)
  baseline_binding_ok <- current_baseline_ok
  record_schema_ok <- legacy_schema && is_git_commit_value(authorized_analysis_commit)
  record_ok <- record_schema_ok &&
    identical(record$record_type, "restricted_data_operating_authorization") &&
    identical(record$authorization_id, authorization_id) && identical(record$status, "authorized") &&
    is_nonempty_string(record$authorization_basis_reference) && dates_ok &&
    is.list(scope) && controls_ok && action %in% operations && required_category %in% categories &&
    requested_baseline_ok && baseline_binding_ok &&
    is_sha256_value(scope$restricted_root_preflight_sha256) &&
    identical(scope$restricted_root_preflight_sha256, sha256_file(preflight_path)) && signature_ok
  if (!record_ok) {
    stop(
      "Restricted operation governance authorization is absent, expired, malformed, ",
      "out of scope, or does not bind this restricted root and Git baseline."
    )
  }

  list(
    id = authorization_id,
    action = action,
    path = normalizePath(path, winslash = "/", mustWork = TRUE),
    record_sha256 = sha256_file(path),
    signed_artifact_sha256 = artifact$sha256,
    analysis_baseline_git_commit = authorized_analysis_commit,
    editorial_candidate_build_allowed = FALSE
  )
}

require_restricted_operation_authorization <- function(project_root, action,
                                                       analysis_baseline_git_commit = NULL) {
  invisible(read_restricted_operation_authorization(
    project_root,
    action,
    analysis_baseline_git_commit = analysis_baseline_git_commit
  ))
}

authorization_provenance_descriptor <- function(authorization) {
  required <- c(
    "id", "record_sha256", "signed_artifact_sha256",
    "analysis_baseline_git_commit", "editorial_candidate_build_allowed"
  )
  if (!is.list(authorization) || !all(required %in% names(authorization)) ||
      !is_nonempty_string(authorization$id) ||
      !is_sha256_value(authorization$record_sha256) ||
      !is_sha256_value(authorization$signed_artifact_sha256) ||
      !is_git_commit_value(authorization$analysis_baseline_git_commit) ||
      !is.logical(authorization$editorial_candidate_build_allowed) ||
      length(authorization$editorial_candidate_build_allowed) != 1L ||
      is.na(authorization$editorial_candidate_build_allowed)) {
    stop("Restricted authorization cannot be converted to a stable provenance descriptor.")
  }
  list(
    id = authorization$id,
    record_sha256 = authorization$record_sha256,
    signed_artifact_sha256 = authorization$signed_artifact_sha256,
    analysis_baseline_git_commit = authorization$analysis_baseline_git_commit
  )
}

path_uses_configured_restricted_root <- function(path) {
  candidate <- Sys.getenv("TA_WIKI_RESTRICTED_ROOT", unset = "")
  if (!is_nonempty_string(candidate) || !dir.exists(candidate)) return(FALSE)
  path_within(path, candidate, must_work = FALSE)
}

# Intake receives its restricted source locator from this external record rather
# than from command-line arguments, which can otherwise be retained in shell or
# process history.  The record is authorized by, and stored beside, the signed
# operating authorization; it is never copied into Git.
read_restricted_source_context <- function(project_root, authorization = NULL) {
  if (is.null(authorization)) {
    authorization <- read_restricted_operation_authorization(project_root, "intake")
  }
  if (!is.list(authorization) || !is_nonempty_string(authorization$id)) {
    stop("Restricted source context requires a verified intake authorization.")
  }
  root <- restricted_root(project_root)
  path <- file.path(root, "governance", "source-access-context.json")
  if (!file.exists(path)) {
    stop("Restricted source-access context is missing. Record it in approved restricted storage before intake.")
  }
  record <- tryCatch(jsonlite::read_json(path, simplifyVector = FALSE), error = function(error) NULL)
  if (is.null(record) || !is.list(record)) {
    stop("Restricted source-access context has invalid JSON.")
  }
  source <- if (is.list(record$source)) record$source else list()
  git <- git_metadata(project_root)
  source_ok <- identical(record$schema_version, "1.0") &&
    identical(record$record_type, "restricted_source_access_context") &&
    identical(record$status, "authorized_for_intake") &&
    is_utc_timestamp(record$recorded_at_utc) &&
    identical(record$authorization_id, authorization$id) &&
    is_git_commit_value(record$authorized_git_commit) &&
    identical(record$authorized_git_commit, authorization$analysis_baseline_git_commit) &&
    identical(record$authorized_git_commit, git$commit) &&
    is_nonempty_string(record$source_access_record_reference) &&
    identical(source$id, "survey_final") &&
    identical(source$filename, basename(real_source_path(project_root))) &&
    is_nonempty_string(source$drive_file_id) && is_nonempty_string(source$drive_revision_id)
  if (!source_ok) {
    stop("Restricted source-access context is incomplete or does not bind this intake authorization and Git baseline.")
  }
  list(
    source = list(
      id = source$id,
      filename = source$filename,
      drive_file_id = source$drive_file_id,
      drive_revision_id = source$drive_revision_id
    ),
    source_access_record_reference = record$source_access_record_reference,
    sha256 = sha256_file(path)
  )
}

initialize_run_dir <- function(path, overwrite = FALSE) {
  if (dir.exists(path) && length(list.files(path, all.files = TRUE, no.. = TRUE)) && !overwrite) {
    stop("Run directory already exists and is not empty: ", path)
  }
  for (subdir in c("manifests", "derived", "reports", "outputs/internal", "logs")) {
    dir.create(file.path(path, subdir), recursive = TRUE, showWarnings = FALSE)
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

new_run_dir <- function(project_root, mode, run_id, synthetic_root = NULL) {
  run_id <- validate_run_id(run_id)
  if (identical(mode, "real")) {
    base <- file.path(restricted_root(project_root), "runs")
  } else if (identical(mode, "synthetic")) {
    base <- synthetic_root %||% file.path(tempdir(), "ta-wiki-assessment-runs")
    dir.create(base, recursive = TRUE, showWarnings = FALSE)
  } else {
    stop("Unsupported run mode: ", mode)
  }
  initialize_run_dir(file.path(base, paste(mode, run_id, sep = "-")))
}

real_source_path <- function(project_root) {
  file.path(restricted_root(project_root), "raw", "TA Wiki Feedback Survey (Responses).xlsx")
}

freeze_parent_directory <- function(project_root, create = FALSE) {
  root <- restricted_root(project_root)
  freeze_parent <- file.path(root, "governance", "source-freezes")
  if (!dir.exists(freeze_parent)) {
    if (!isTRUE(create)) {
      stop("The restricted source-freeze directory is missing.")
    }
    dir.create(freeze_parent, recursive = TRUE, showWarnings = FALSE)
  }
  if (!dir.exists(freeze_parent)) {
    stop("Unable to create the restricted source-freeze parent directory.")
  }
  freeze_parent <- normalizePath(freeze_parent, winslash = "/", mustWork = TRUE)
  if (!path_within(freeze_parent, root) ||
      identical(normalize_compare_path(freeze_parent), normalize_compare_path(root))) {
    stop("The restricted source-freeze directory must resolve inside approved restricted storage.")
  }
  freeze_parent
}

restricted_source_workbook <- function(project_root) {
  root <- restricted_root(project_root)
  raw_dir <- file.path(root, "raw")
  if (!dir.exists(raw_dir)) {
    stop("Approved restricted storage is missing the raw source-staging directory.")
  }
  raw_dir <- normalizePath(raw_dir, winslash = "/", mustWork = TRUE)
  if (!path_within(raw_dir, root) ||
      identical(normalize_compare_path(raw_dir), normalize_compare_path(root))) {
    stop("The raw source-staging directory must resolve inside approved restricted storage.")
  }
  expected <- real_source_path(project_root)
  if (!file.exists(expected)) {
    stop("Missing authoritative workbook in approved restricted storage.")
  }
  source_path <- normalizePath(expected, winslash = "/", mustWork = TRUE)
  source_info <- file.info(source_path)
  if (isTRUE(source_info$isdir) || is.na(source_info$size) || source_info$size <= 0) {
    stop("The authoritative workbook must be a nonempty regular file.")
  }
  if (!identical(tolower(tools::file_ext(source_path)), "xlsx") ||
      !path_within(source_path, raw_dir)) {
    stop("The authoritative workbook must resolve to the expected XLSX file inside restricted source staging.")
  }
  list(
    path = source_path,
    filename = basename(source_path),
    sha256 = sha256_file(source_path),
    bytes = unname(source_info$size)
  )
}

freeze_directory <- function(project_root, freeze_id) {
  freeze_id <- validate_run_id(freeze_id)
  freeze_parent <- freeze_parent_directory(project_root)
  freeze_dir <- file.path(freeze_parent, freeze_id)
  if (dir.exists(freeze_dir)) {
    freeze_dir <- normalizePath(freeze_dir, winslash = "/", mustWork = TRUE)
    if (!path_within(freeze_dir, freeze_parent) ||
        identical(normalize_compare_path(freeze_dir), normalize_compare_path(freeze_parent))) {
      stop("The source-freeze directory must resolve inside approved restricted storage.")
    }
  }
  freeze_dir
}

frozen_source_workbook_path <- function(project_root, freeze_id) {
  file.path(freeze_directory(project_root, freeze_id), "source-workbook.xlsx")
}

copy_source_to_freeze_staging <- function(project_root, source, staging_dir) {
  if (!is.list(source) || !is_nonempty_string(source$path) || !is_nonempty_string(source$filename) ||
      !is_sha256_value(source$sha256) || !is.numeric(source$bytes) ||
      length(source$bytes) != 1L || is.na(source$bytes) || source$bytes <= 0) {
    stop("A verified restricted source workbook is required before a freeze can be created.")
  }
  verified_source <- restricted_source_workbook(project_root)
  source_path <- normalizePath(source$path, winslash = "/", mustWork = TRUE)
  source_matches <- identical(source_path, verified_source$path) &&
    identical(source$filename, verified_source$filename) &&
    identical(source$sha256, verified_source$sha256) &&
    identical(as.numeric(source$bytes), as.numeric(verified_source$bytes))
  if (!source_matches) {
    stop("The source workbook changed before source-freeze copying; do not use this freeze.")
  }
  source <- verified_source
  freeze_parent <- freeze_parent_directory(project_root)
  if (!dir.exists(staging_dir)) stop("The source-freeze staging directory is missing.")
  staging_dir <- normalizePath(staging_dir, winslash = "/", mustWork = TRUE)
  if (!path_within(staging_dir, freeze_parent) ||
      identical(normalize_compare_path(staging_dir), normalize_compare_path(freeze_parent))) {
    stop("The source-freeze staging directory must resolve inside approved restricted storage.")
  }
  frozen_path <- file.path(staging_dir, "source-workbook.xlsx")
  if (file.exists(frozen_path)) stop("The frozen-source staging path already exists.")
  if (!isTRUE(file.copy(source$path, frozen_path, overwrite = FALSE, copy.date = TRUE))) {
    stop("Unable to copy the staged workbook into the immutable source-freeze directory.")
  }
  frozen_path <- normalizePath(frozen_path, winslash = "/", mustWork = TRUE)
  source_after <- restricted_source_workbook(project_root)
  frozen_info <- file.info(frozen_path)
  frozen_ok <- !isTRUE(frozen_info$isdir) && !is.na(frozen_info$size) &&
    identical(as.numeric(frozen_info$size), as.numeric(source$bytes)) &&
    identical(source_after$sha256, source$sha256) &&
    identical(as.numeric(source_after$bytes), as.numeric(source$bytes)) &&
    identical(sha256_file(frozen_path), source$sha256)
  if (!frozen_ok) {
    stop("The staged workbook changed during source-freeze copying; do not use this freeze.")
  }
  list(
    path = frozen_path,
    filename = basename(frozen_path),
    sha256 = source$sha256,
    bytes = source$bytes,
    source_filename = source$filename
  )
}

source_freeze_evidence <- function(project_root, freeze_id) {
  freeze_id <- validate_run_id(freeze_id)
  root <- restricted_root(project_root)
  freeze_dir <- freeze_directory(project_root, freeze_id)
  evidence_path <- file.path(freeze_dir, "source-provenance.json")
  if (!file.exists(evidence_path)) stop("Missing immutable source-freeze provenance record.")
  evidence <- tryCatch(jsonlite::read_json(evidence_path, simplifyVector = FALSE), error = function(error) NULL)
  source <- evidence$source
  artifacts <- evidence$artifacts
  authorization <- evidence$governance_authorization
  source_ok <- !is.null(source) && identical(evidence$schema_version, "1.2") &&
    identical(evidence$status, "frozen") && identical(evidence$freeze_id, freeze_id) &&
    identical(source$id, "survey_final") && identical(source$filename, basename(real_source_path(project_root))) &&
    identical(source$frozen_filename, basename(frozen_source_workbook_path(project_root, freeze_id))) &&
    is_sha256_value(source$sha256) &&
    is.numeric(source$bytes) && length(source$bytes) == 1L && !is.na(source$bytes) &&
    source$bytes > 0 &&
    is_nonempty_string(source$drive_file_id) && is_nonempty_string(source$drive_revision_id) &&
    is_sha256_value(evidence$source_access_context_sha256) &&
    is_nonempty_string(evidence$source_access_record_reference) &&
    is.list(authorization) && is_nonempty_string(authorization$id) &&
    is_sha256_value(authorization$record_sha256) && is_sha256_value(authorization$signed_artifact_sha256)
  if (!source_ok || is.null(artifacts)) {
    stop("Source-freeze provenance does not match the authoritative workbook.")
  }

  require_artifact <- function(name, filename) {
    descriptor <- artifacts[[name]]
    path <- file.path(freeze_dir, filename)
    if (is.null(descriptor) || !identical(descriptor$filename, filename) ||
        !is_sha256_value(descriptor$sha256) || !file.exists(path) ||
        !identical(descriptor$sha256, sha256_file(path))) {
      stop("Source-freeze provenance has an invalid ", name, " artifact.")
    }
    path
  }
  frozen_path <- require_artifact("frozen_workbook", "source-workbook.xlsx")
  frozen_info <- file.info(frozen_path)
  if (isTRUE(frozen_info$isdir) || is.na(frozen_info$size) ||
      !identical(as.numeric(source$bytes), as.numeric(frozen_info$size)) ||
      !identical(source$sha256, sha256_file(frozen_path))) {
    stop("Source-freeze provenance does not match the frozen workbook bytes.")
  }
  header_path <- require_artifact("candidate_header_manifest", "candidate-live-header-manifest.csv")
  require_artifact("schema_profile", "schema-profile.json")
  candidate_headers <- read_source_header_manifest(header_path, label = "source-freeze candidate header manifest")
  if (!identical(candidate_headers, approved_live_headers(project_root))) {
    stop("Source-freeze candidate header manifest does not match the approved manifest.")
  }

  list(
    id = freeze_id,
    provenance_sha256 = sha256_file(evidence_path),
    source_sha256 = source$sha256,
    source_path = frozen_path,
    drive_file_id = source$drive_file_id,
    drive_revision_id = source$drive_revision_id
  )
}
