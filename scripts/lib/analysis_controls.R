# Immutable analytical-control fingerprinting. The explicit tracked-file list
# separates analysis and release rendering inputs from ordinary editorial files.

analysis_control_manifest_path <- function(root) {
  file.path(root, "config", "analysis-control-files.csv")
}

analysis_control_relative_path_valid <- function(path) {
  is.character(path) && length(path) == 1L && !is.na(path) && nzchar(path) &&
    !grepl("^[A-Za-z]:|^/|\\\\", path) &&
    !grepl("(^|/)\\.\\.(/|$)", path) && !grepl("\\\\", path)
}

tracked_relative_file <- function(root, relative_path, label = "analytical control") {
  if (!analysis_control_relative_path_valid(relative_path)) {
    stop(label, " has an unsafe relative path.")
  }
  path <- file.path(root, relative_path)
  if (!file.exists(path) || isTRUE(file.info(path)$isdir)) {
    stop(label, " is missing or is not a regular file: ", relative_path)
  }
  git <- Sys.which("git")
  if (!nzchar(git)) git <- "C:/Program Files/Git/cmd/git.exe"
  tracked <- run_command(git, c("-C", root, "ls-files", "--error-unmatch", "--", relative_path), root)
  if (tracked$status != 0L) stop(label, " is not Git-tracked: ", relative_path)
  path
}

read_analysis_control_manifest <- function(root) {
  path <- analysis_control_manifest_path(root)
  table <- tryCatch(
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = character()),
    error = function(error) NULL
  )
  if (is.null(table) || !identical(names(table), c("relative_path", "control_domain")) || !nrow(table)) {
    stop("The analytical-control manifest has an unsupported schema.")
  }
  if (anyNA(table$relative_path) || any(!vapply(table$relative_path, analysis_control_relative_path_valid, logical(1))) ||
      anyDuplicated(table$relative_path) || anyNA(table$control_domain) || any(!nzchar(table$control_domain))) {
    stop("The analytical-control manifest contains an invalid entry.")
  }
  if (!"config/analysis-control-files.csv" %in% table$relative_path) {
    stop("The analytical-control manifest must fingerprint itself.")
  }
  paths <- vapply(
    table$relative_path,
    function(relative_path) tracked_relative_file(root, relative_path),
    character(1)
  )
  table$absolute_path <- unname(paths)
  table
}

analysis_control_fingerprint <- function(root) {
  controls <- read_analysis_control_manifest(root)
  hashes <- vapply(controls$absolute_path, tracked_file_sha256, character(1))
  names(hashes) <- controls$relative_path
  list(
    schema_version = "1.0",
    files = as.list(hashes)
  )
}

validate_analysis_control_fingerprint <- function(recorded, root, label = "Analysis baseline") {
  expected <- analysis_control_fingerprint(root)
  is_hash <- function(value) is.character(value) && length(value) == 1L && !is.na(value) && grepl("^[0-9a-f]{64}$", value)
  valid_record <- is.list(recorded) && identical(recorded$schema_version, "1.0") && is.list(recorded$files) &&
    identical(names(recorded$files), names(expected$files)) &&
    all(vapply(recorded$files, is_hash, logical(1)))
  if (!valid_record || !identical(unname(unlist(recorded$files, use.names = FALSE)), unname(unlist(expected$files, use.names = FALSE)))) {
    stop(label, " analytical-control fingerprint does not match the current controlled inputs.")
  }
  invisible(expected)
}
