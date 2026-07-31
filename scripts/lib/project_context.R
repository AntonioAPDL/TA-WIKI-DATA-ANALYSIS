# Shared project-context helpers. Source this file from executable scripts in
# scripts/ after deriving the caller's --file path.

script_file <- function() {
  args <- commandArgs(FALSE)
  file_arg <- args[grepl("^--file=", args)]
  if (!length(file_arg)) stop("Unable to determine the executing script path.")
  normalizePath(sub("^--file=", "", file_arg[[1]]), winslash = "/", mustWork = TRUE)
}

project_root_from_script <- function(path = script_file()) {
  root <- normalizePath(file.path(dirname(path), ".."), winslash = "/", mustWork = TRUE)
  required <- c("renv.lock", "scripts", "results", "main.tex")
  if (!all(file.exists(file.path(root, required)))) {
    stop("The executing script is not located in a TA Wiki assessment project.")
  }
  root
}

activate_project <- function(root) {
  activate <- file.path(root, "renv", "activate.R")
  if (!file.exists(activate)) stop("Missing renv activation script.")
  previous <- getwd()
  on.exit(setwd(previous), add = TRUE)
  setwd(root)
  source(activate, local = TRUE)
  invisible(root)
}

parse_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
  flags <- character()
  values <- list()
  i <- 1L
  while (i <= length(args)) {
    arg <- args[[i]]
    if (!startsWith(arg, "--")) stop("Unexpected argument: ", arg)
    key <- sub("^--", "", arg)
    if (i == length(args) || startsWith(args[[i + 1L]], "--")) {
      flags <- c(flags, key)
      i <- i + 1L
    } else {
      if (!is.null(values[[key]])) stop("Argument supplied more than once: --", key)
      values[[key]] <- args[[i + 1L]]
      i <- i + 2L
    }
  }
  list(flags = unique(flags), values = values)
}

has_flag <- function(cli, name) name %in% cli$flags

option_value <- function(cli, name, default = NULL, required = FALSE) {
  value <- cli$values[[name]]
  if (is.null(value)) value <- default
  if (required && (is.null(value) || !nzchar(value))) stop("Missing required argument: --", name)
  value
}

validate_run_id <- function(run_id) {
  if (!grepl("^[A-Za-z0-9][A-Za-z0-9._-]{2,63}$", run_id)) {
    stop("Run ID must contain 3–64 letters, digits, dots, underscores, or hyphens.")
  }
  run_id
}

utc_now <- function() format(Sys.time(), tz = "UTC", usetz = FALSE, format = "%Y-%m-%dT%H:%M:%SZ")

run_command <- function(command, args, root) {
  output <- tryCatch(
    system2(command, args, stdout = TRUE, stderr = TRUE),
    error = function(error) structure(conditionMessage(error), status = 1L)
  )
  list(status = attr(output, "status") %||% 0L, output = paste(output, collapse = "\n"))
}

`%||%` <- function(x, y) if (is.null(x)) y else x

git_metadata <- function(root) {
  git <- Sys.which("git")
  if (!nzchar(git)) git <- "C:/Program Files/Git/cmd/git.exe"
  commit <- run_command(git, c("-C", root, "rev-parse", "HEAD"), root)
  status <- run_command(git, c("-C", root, "status", "--porcelain"), root)
  list(
    commit = if (commit$status == 0L) trimws(commit$output) else NA_character_,
    dirty = status$status != 0L || nzchar(trimws(status$output))
  )
}

python_command <- function() {
  configured <- Sys.getenv("TA_WIKI_PYTHON", unset = "")
  candidates <- c(configured, Sys.which("python3"), Sys.which("python"))
  if (.Platform$OS.type == "windows") {
    program_root <- file.path(Sys.getenv("LOCALAPPDATA", unset = ""), "Programs", "Python")
    if (dir.exists(program_root)) {
      candidates <- c(candidates, list.files(program_root, pattern = "^python\\.exe$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE))
    }
  }
  candidates <- unique(candidates[nzchar(candidates)])
  for (candidate in candidates) {
    probe <- tryCatch(suppressWarnings(system2(candidate, "--version", stdout = TRUE, stderr = TRUE)), error = function(error) structure("", status = 1L))
    if (is.null(attr(probe, "status")) || identical(attr(probe, "status"), 0L)) {
      return(list(executable = candidate, prefix = character()))
    }
  }
  launcher <- Sys.which("py")
  if (nzchar(launcher)) {
    probe <- tryCatch(suppressWarnings(system2(launcher, c("-3", "--version"), stdout = TRUE, stderr = TRUE)), error = function(error) structure("", status = 1L))
    if (is.null(attr(probe, "status")) || identical(attr(probe, "status"), 0L)) {
      return(list(executable = launcher, prefix = "-3"))
    }
  }
  stop("Python 3 is required. Set TA_WIKI_PYTHON to an executable path if it is not on PATH.")
}

project_file <- function(root, ...) normalizePath(file.path(root, ...), winslash = "/", mustWork = FALSE)
