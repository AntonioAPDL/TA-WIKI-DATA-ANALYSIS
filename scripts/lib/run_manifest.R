# Manifest and fingerprint helpers. Manifests contain reproducibility metadata
# only; they must never include respondent-level values or restricted root paths.

require_manifest_packages <- function() {
  required <- c("digest", "jsonlite")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stop("Missing manifest packages: ", paste(missing, collapse = ", "))
}

sha256_file <- function(path) {
  if (!file.exists(path)) stop("Cannot fingerprint missing file: ", path)
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}

tracked_file_sha256 <- function(path) {
  # Controlled project inputs are identified by their canonical Git blob, not
  # checkout bytes. This keeps their manifest fingerprints stable when a
  # platform changes LF/CRLF during checkout. Files outside a Git worktree (for
  # example, temporary test policies) retain ordinary byte-level hashing.
  if (!file.exists(path)) stop("Cannot fingerprint missing file: ", path)
  target <- normalizePath(path, winslash = "/", mustWork = TRUE)
  git <- Sys.which("git")
  if (!nzchar(git)) git <- "C:/Program Files/Git/cmd/git.exe"
  repository <- run_command(git, c("-C", dirname(target), "rev-parse", "--show-toplevel"), dirname(target))
  if (repository$status != 0L || !nzchar(trimws(repository$output))) return(sha256_file(target))
  root <- normalizePath(trimws(repository$output), winslash = "/", mustWork = TRUE)
  root_prefix <- paste0(tolower(root), "/")
  if (!startsWith(tolower(target), root_prefix)) return(sha256_file(target))
  relative <- substring(target, nchar(root) + 2L)
  tracked <- run_command(git, c("-C", root, "ls-files", "--error-unmatch", "--", relative), root)
  if (tracked$status != 0L) return(sha256_file(target))

  blob <- tempfile("ta-wiki-git-blob-", fileext = ".bin")
  on.exit(unlink(blob, force = TRUE), add = TRUE)
  shown <- tryCatch(
    # On Unix, `stderr = TRUE` implicitly captures stdout and prevents the
    # canonical blob from being written to `blob`. Keep stdout binary-directed
    # to the file and inspect the ordinary exit status instead.
    system2(git, c("-C", root, "show", paste0("HEAD:", relative)), stdout = blob, stderr = FALSE),
    error = function(error) structure(conditionMessage(error), status = 1L)
  )
  exit_status <- attr(shown, "status")
  if (is.null(exit_status) && is.numeric(shown) && length(shown) == 1L) {
    exit_status <- shown
  }
  if (!is.null(exit_status) && (!identical(as.integer(exit_status), 0L))) {
    stop("Unable to read the canonical Git blob for tracked file: ", relative)
  }
  if (!file.exists(blob)) stop("Git did not produce a canonical blob for tracked file: ", relative)
  sha256_file(blob)
}

tracked_file_sha256_at_commit <- function(root, relative_path, commit) {
  if (!is.character(relative_path) || length(relative_path) != 1L || is.na(relative_path) ||
      !grepl("^[A-Za-z0-9][A-Za-z0-9._/-]*$", relative_path) ||
      grepl("(^|/)\\.\\.(/|$)", relative_path) ||
      !is.character(commit) || length(commit) != 1L || is.na(commit) ||
      !grepl("^[0-9a-f]{40}([0-9a-f]{24})?$", commit)) {
    stop("Historical Git blob lookup requires a safe path and commit.")
  }
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  git <- Sys.which("git")
  if (!nzchar(git)) git <- "C:/Program Files/Git/cmd/git.exe"
  blob <- tempfile("ta-wiki-historical-git-blob-", fileext = ".bin")
  on.exit(unlink(blob, force = TRUE), add = TRUE)
  shown <- tryCatch(
    system2(git, c("-C", root, "show", paste0(commit, ":", relative_path)), stdout = blob, stderr = FALSE),
    error = function(error) structure(conditionMessage(error), status = 1L)
  )
  exit_status <- attr(shown, "status")
  if (is.null(exit_status) && is.numeric(shown) && length(shown) == 1L) {
    exit_status <- shown
  }
  if ((!is.null(exit_status) && !identical(as.integer(exit_status), 0L)) || !file.exists(blob)) {
    stop("Unable to read the historical Git blob for ", relative_path, ".")
  }
  sha256_file(blob)
}

sha256_text <- function(text) digest::digest(paste(text, collapse = "\n"), algo = "sha256", serialize = FALSE)

write_json_atomic <- function(object, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temporary <- paste0(path, ".tmp-", Sys.getpid())
  on.exit(unlink(temporary), add = TRUE)
  jsonlite::write_json(object, temporary, auto_unbox = TRUE, pretty = TRUE, null = "null")
  if (!file.rename(temporary, path)) stop("Unable to atomically write manifest: ", path)
  invisible(path)
}

read_manifest <- function(path) {
  if (!file.exists(path)) stop("Missing run manifest: ", path)
  jsonlite::read_json(path, simplifyVector = FALSE)
}

relative_run_path <- function(run_dir, path) {
  run <- normalizePath(run_dir, winslash = "/", mustWork = TRUE)
  target <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (!startsWith(tolower(target), paste0(tolower(run), "/"))) stop("Artifact is outside its run directory.")
  substring(target, nchar(run) + 2L)
}

manifest_environment <- function(root) {
  git <- git_metadata(root)
  list(
    r_version = R.version.string,
    platform = R.version$platform,
    timezone = Sys.timezone(),
    locale = Sys.getlocale(),
    lockfile_sha256 = tracked_file_sha256(file.path(root, "renv.lock")),
    git_commit = git$commit,
    git_dirty = git$dirty
  )
}

manifest_output_descriptors <- function(run_dir, output_paths) {
  if (!is.list(output_paths) || !length(output_paths) || is.null(names(output_paths)) || any(!nzchar(names(output_paths)))) {
    stop("Manifest output paths must be a named non-empty list.")
  }
  lapply(output_paths, function(path) {
    list(relative_path = relative_run_path(run_dir, path), sha256 = sha256_file(path))
  })
}

resolve_manifest_output <- function(run_dir, descriptor, label) {
  relative <- descriptor$relative_path
  if (!is.character(relative) || length(relative) != 1L || startsWith(relative, "/") ||
      grepl("(^|/)\\.\\.(/|$)", relative)) {
    stop("Manifest output path is unsafe for ", label, ".")
  }
  path <- file.path(run_dir, relative)
  if (!file.exists(path)) stop("Manifest-declared output is missing for ", label, ".")
  if (!identical(sha256_file(path), descriptor$sha256)) {
    stop("Output hash does not match its manifest for ", label, ".")
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

manifest_sha256_value <- function(value) {
  is.character(value) && length(value) == 1L && !is.na(value) && grepl("^[0-9a-f]{64}$", value)
}

manifest_nonempty_string <- function(value) {
  is.character(value) && length(value) == 1L && !is.na(value) && nzchar(trimws(value))
}

manifest_null_or_na <- function(value) {
  is.null(value) || (is.character(value) && length(value) == 1L && is.na(value))
}

validate_manifest_source_descriptors <- function(manifest) {
  source_ok <- is.list(manifest$source) &&
    identical(names(manifest$source), c("id", "sha256")) &&
    manifest_nonempty_string(manifest$source$id) &&
    manifest_sha256_value(manifest$source$sha256)
  source_freeze <- manifest$source_freeze
  freeze_ok <- is.list(source_freeze) &&
    identical(names(source_freeze), c("id", "provenance_sha256", "source_sha256")) &&
    manifest_nonempty_string(source_freeze$id) &&
    manifest_sha256_value(source_freeze$source_sha256) &&
    identical(source_freeze$source_sha256, manifest$source$sha256)
  if (identical(manifest$mode, "real")) {
    freeze_ok <- freeze_ok && manifest_sha256_value(source_freeze$provenance_sha256)
  } else if (identical(manifest$mode, "synthetic")) {
    freeze_ok <- freeze_ok && identical(manifest$source$id, "synthetic_fixture") &&
      identical(source_freeze$id, "synthetic") && manifest_null_or_na(source_freeze$provenance_sha256)
  }
  if (!source_ok || !freeze_ok) {
    stop("Manifest source provenance is missing, malformed, or contains an unsupported locator field.")
  }
  invisible(TRUE)
}

validate_stage_manifest <- function(manifest_path, stage) {
  require_manifest_packages()
  manifest <- read_manifest(manifest_path)
  if (!manifest$schema_version %in% c("1.1", "1.2") || !identical(manifest$stage, stage)) {
    stop("Manifest is not a supported ", stage, " manifest.")
  }
  if (!manifest$mode %in% c("synthetic", "real")) stop("Manifest mode is invalid.")
  if (identical(manifest$schema_version, "1.2") &&
      (!is.list(manifest$analysis_controls) || !identical(manifest$analysis_controls$schema_version, "1.0") ||
       !is.list(manifest$analysis_controls$files))) {
    stop("Manifest is missing its analytical-control fingerprint.")
  }
  if (identical(manifest$schema_version, "1.2")) {
    validate_manifest_source_descriptors(manifest)
  }
  run_dir <- normalizePath(file.path(dirname(manifest_path), ".."), winslash = "/", mustWork = TRUE)
  list(manifest = manifest, run_dir = run_dir)
}

write_validation_manifest <- function(root, run_dir, mode, run_id, source,
                                      schema_paths, output_paths, validation,
                                      source_freeze, analysis_controls) {
  require_manifest_packages()
  if (!is.list(source) || !is_nonempty_string(source$id) || !is_sha256_value(source$sha256)) {
    stop("Validation manifest requires a safe source descriptor.")
  }
  expected_freeze_fields <- c("id", "provenance_sha256", "source_sha256")
  if (!is.list(source_freeze) || !identical(names(source_freeze), expected_freeze_fields) ||
      !is_nonempty_string(source_freeze$id) || !is_sha256_value(source_freeze$source_sha256) ||
      !identical(source_freeze$source_sha256, source$sha256) ||
      (identical(mode, "real") && !is_sha256_value(source_freeze$provenance_sha256))) {
    stop("Validation manifest requires a locator-free source-freeze descriptor.")
  }
  if (!is.list(analysis_controls) || !identical(analysis_controls$schema_version, "1.0") ||
      !is.list(analysis_controls$files)) {
    stop("Validation manifest requires an analytical-control fingerprint.")
  }
  manifest <- list(
    schema_version = "1.2",
    stage = "validation",
    mode = mode,
    run_id = run_id,
    generated_at_utc = utc_now(),
    source = source,
    source_freeze = source_freeze,
    schema = lapply(schema_paths, tracked_file_sha256),
    analysis_controls = analysis_controls,
    environment = manifest_environment(root),
    outputs = manifest_output_descriptors(run_dir, output_paths),
    validation = validation
  )
  path <- file.path(run_dir, "manifests", "01-validation.json")
  write_json_atomic(manifest, path)
  path
}

validation_manifest_input <- function(manifest_path, authorization_action = NULL,
                                      project_root = NULL) {
  if (path_uses_configured_restricted_root(manifest_path)) {
    if (!is_nonempty_string(authorization_action) || !is_nonempty_string(project_root)) {
      stop("Resolving a restricted validation manifest requires an explicit authorized operation.")
    }
    require_restricted_operation_authorization(project_root, authorization_action)
  }
  context <- validate_stage_manifest(manifest_path, "validation")
  if (identical(context$manifest$schema_version, "1.1")) {
    stop("Legacy validation manifests cannot be transformed by the v1.2 minimization workflow; create a new controlled lineage.")
  }
  required <- c("cohort_ledger")
  if (!all(required %in% names(context$manifest$outputs))) {
    stop("Validation manifest is missing required lineage outputs.")
  }
  context$inputs <- lapply(required, function(name) {
    resolve_manifest_output(context$run_dir, context$manifest$outputs[[name]], name)
  })
  names(context$inputs) <- required
  context
}

write_transform_manifest <- function(root, run_dir, validation_manifest_path,
                                     output_paths, transformation) {
  require_manifest_packages()
  validation <- read_manifest(validation_manifest_path)
  manifest <- list(
    schema_version = "1.2",
    stage = "transformation",
    mode = validation$mode,
    run_id = validation$run_id,
    generated_at_utc = utc_now(),
    validation_manifest_sha256 = sha256_file(validation_manifest_path),
    source = validation$source,
    source_freeze = validation$source_freeze,
    schema = validation$schema,
    analysis_controls = validation$analysis_controls,
    environment = manifest_environment(root),
    outputs = manifest_output_descriptors(run_dir, output_paths),
    transformation = transformation
  )
  path <- file.path(run_dir, "manifests", "02-transformation.json")
  write_json_atomic(manifest, path)
  path
}

transform_manifest_input <- function(manifest_path, authorization_action = NULL,
                                     project_root = NULL) {
  if (path_uses_configured_restricted_root(manifest_path)) {
    if (!is_nonempty_string(authorization_action) || !is_nonempty_string(project_root)) {
      stop("Resolving a restricted transformation manifest requires an explicit authorized operation.")
    }
    require_restricted_operation_authorization(project_root, authorization_action)
  }
  context <- validate_stage_manifest(manifest_path, "transformation")
  required <- c("structured_items", "checkbox_selections", "transformation_audit")
  if (!all(required %in% names(context$manifest$outputs))) {
    stop("Transformation manifest is missing required lineage outputs.")
  }
  context$inputs <- lapply(required, function(name) {
    resolve_manifest_output(context$run_dir, context$manifest$outputs[[name]], name)
  })
  names(context$inputs) <- required
  context
}

write_analysis_manifest <- function(root, run_dir, transformation_manifest_path,
                                    output_paths, analysis) {
  require_manifest_packages()
  transformation <- read_manifest(transformation_manifest_path)
  manifest <- list(
    schema_version = "1.2",
    stage = "analysis",
    mode = transformation$mode,
    run_id = transformation$run_id,
    generated_at_utc = utc_now(),
    transformation_manifest_sha256 = sha256_file(transformation_manifest_path),
    source = transformation$source,
    source_freeze = transformation$source_freeze,
    schema = transformation$schema,
    analysis_controls = transformation$analysis_controls,
    environment = manifest_environment(root),
    outputs = manifest_output_descriptors(run_dir, output_paths),
    analysis = analysis
  )
  path <- file.path(run_dir, "manifests", "03-analysis.json")
  write_json_atomic(manifest, path)
  path
}
