# Disclosure-control helpers. Automated suppression is deliberately
# conservative and never substitutes for the required human review attestation.

release_policy_expected_keys <- function() {
  list(
    public_release = c(
      "permitted_only_after_pi_approval",
      "minimum_cell_count",
      "suppress_free_text",
      "suppress_timestamps",
      "suppress_respondent_level_rows",
      "require_manual_disclosure_review"
    ),
    internal_outputs = c("git_ignored", "may_contain_small_cells")
  )
}

parse_release_policy_section <- function(lines, section, expected_keys) {
  header <- paste0(section, ":")
  start <- match(header, lines)
  if (is.na(start)) stop("Release policy is missing the ", section, " section.")
  next_headers <- which(grepl("^[A-Za-z][A-Za-z0-9_]*:$", lines))
  end <- next_headers[next_headers > start]
  end <- if (length(end)) end[[1]] - 1L else length(lines)
  body <- lines[seq.int(start + 1L, end)]
  pattern <- "^  ([A-Za-z][A-Za-z0-9_]*):[[:space:]]*(.*)$"
  parsed <- regexec(pattern, body)
  matches <- regmatches(body, parsed)
  if (!length(body) || any(lengths(matches) != 3L)) {
    stop("Release policy has an invalid entry in the ", section, " section.")
  }
  keys <- vapply(matches, `[[`, character(1), 2L)
  values <- vapply(matches, `[[`, character(1), 3L)
  if (anyDuplicated(keys) || !setequal(keys, expected_keys)) {
    stop("Release policy has unexpected, missing, or duplicate keys in the ", section, " section.")
  }
  stats::setNames(values, keys)
}

read_release_policy <- function(path) {
  if (!file.exists(path)) stop("Missing release policy.")
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- trimws(lines, which = "right")
  lines <- lines[nzchar(trimws(lines)) & !grepl("^[[:space:]]*#", lines)]
  expected <- release_policy_expected_keys()
  headers <- sub(":$", "", lines[grepl("^[A-Za-z][A-Za-z0-9_]*:$", lines)])
  if (!identical(headers, names(expected))) {
    stop("Release policy must contain only the expected top-level sections in the documented order.")
  }
  public <- parse_release_policy_section(lines, "public_release", expected$public_release)
  internal <- parse_release_policy_section(lines, "internal_outputs", expected$internal_outputs)
  as_logical <- function(value, key) {
    if (!identical(value, "true") && !identical(value, "false")) {
      stop("Release policy value ", key, " must be true or false.")
    }
    identical(value, "true")
  }
  threshold_value <- public[["minimum_cell_count"]]
  if (identical(threshold_value, "null")) {
    threshold <- NA_integer_
  } else {
    if (!grepl("^[0-9]+$", threshold_value)) {
      stop("Release policy minimum_cell_count must be null or a base-10 integer.")
    }
    threshold <- suppressWarnings(as.integer(threshold_value))
    if (is.na(threshold)) stop("Release policy minimum_cell_count is outside the supported integer range.")
    if (threshold < 2L) stop("Release policy minimum_cell_count must be at least 2.")
  }
  list(
    path = path,
    sha256 = tracked_file_sha256(path),
    minimum_cell_count = threshold,
    permitted_only_after_pi_approval = as_logical(public[["permitted_only_after_pi_approval"]], "permitted_only_after_pi_approval"),
    suppress_free_text = as_logical(public[["suppress_free_text"]], "suppress_free_text"),
    suppress_timestamps = as_logical(public[["suppress_timestamps"]], "suppress_timestamps"),
    suppress_respondent_level_rows = as_logical(public[["suppress_respondent_level_rows"]], "suppress_respondent_level_rows"),
    require_manual_disclosure_review = as_logical(public[["require_manual_disclosure_review"]], "require_manual_disclosure_review"),
    internal_outputs_git_ignored = as_logical(internal[["git_ignored"]], "git_ignored"),
    internal_outputs_may_contain_small_cells = as_logical(internal[["may_contain_small_cells"]], "may_contain_small_cells")
  )
}

assert_release_policy_controls <- function(policy, action = "Release rendering") {
  if (!is.list(policy) || is.na(policy$minimum_cell_count)) {
    stop(action, " is blocked until the approved minimum_cell_count is set.")
  }
  mandatory <- c(
    "permitted_only_after_pi_approval",
    "require_manual_disclosure_review",
    "suppress_free_text",
    "suppress_timestamps",
    "suppress_respondent_level_rows",
    "internal_outputs_git_ignored",
    "internal_outputs_may_contain_small_cells"
  )
  if (!all(vapply(mandatory, function(name) isTRUE(policy[[name]]), logical(1)))) {
    stop(action, " is blocked because the release policy does not satisfy mandatory disclosure controls.")
  }
  invisible(TRUE)
}

is_sha256 <- function(value) is.character(value) && length(value) == 1L && grepl("^[0-9a-f]{64}$", value)

is_git_commit <- function(value) {
  is.character(value) && length(value) == 1L && !is.na(value) &&
    grepl("^[0-9a-f]{40}([0-9a-f]{24})?$", value)
}

validate_current_stage_provenance <- function(stage, manifest, expected_schema,
                                              policy, current_commit,
                                              current_lockfile_sha256,
                                              expected_analysis_controls = NULL) {
  environment <- manifest$environment
  if (!is.list(environment) || !is_git_commit(environment$git_commit) || !isFALSE(environment$git_dirty)) {
    stop(stage, " manifest does not record a clean, valid Git provenance.")
  }
  if (!identical(environment$git_commit, current_commit)) {
    stop(stage, " manifest was generated by a different Git commit; rerun validation, transformation, and analysis before release.")
  }
  if (!is_sha256(environment$lockfile_sha256) || !identical(environment$lockfile_sha256, current_lockfile_sha256)) {
    stop(stage, " manifest lockfile does not match the current renv.lock; rerun validation, transformation, and analysis before release.")
  }

  recorded_schema <- unlist(manifest$schema, use.names = TRUE)
  recorded_policy_hash <- recorded_schema[["release_policy"]]
  if (!is_sha256(recorded_policy_hash) || !identical(recorded_policy_hash, policy$sha256)) {
    stop("Release policy changed after ", tolower(stage), "; rerun validation, transformation, and analysis before release.")
  }
  if (!identical(as.character(recorded_schema[names(expected_schema)]), as.character(expected_schema))) {
    stop("Controlled metadata changed after ", tolower(stage), "; rerun validation, transformation, and analysis before release.")
  }
  if (!is.null(expected_analysis_controls)) {
    if (!identical(manifest$schema_version, "1.2") || !identical(manifest$analysis_controls, expected_analysis_controls)) {
      stop(stage, " manifest analytical-control fingerprint does not match the current controlled inputs; rerun validation, transformation, and analysis before release.")
    }
  }
  invisible(TRUE)
}

read_bound_predecessor <- function(run_dir, filename, stage, expected_sha256,
                                   downstream_context) {
  if (!is_sha256(expected_sha256)) {
    stop("The ", downstream_context$manifest$stage, " manifest has an invalid ", stage, " predecessor hash.")
  }
  path <- file.path(run_dir, "manifests", filename)
  if (!file.exists(path) || !identical(sha256_file(path), expected_sha256)) {
    stop("The ", downstream_context$manifest$stage, " manifest does not bind the ", stage, " manifest in its own run directory.")
  }
  context <- validate_stage_manifest(path, stage)
  if (!identical(context$run_dir, downstream_context$run_dir) ||
      !identical(context$manifest$mode, downstream_context$manifest$mode) ||
      !identical(context$manifest$run_id, downstream_context$manifest$run_id)) {
    stop("The ", downstream_context$manifest$stage, " manifest predecessor lineage is inconsistent.")
  }
  if (is.null(context$manifest$source) || is.null(downstream_context$manifest$source) ||
      is.null(context$manifest$source_freeze) || is.null(downstream_context$manifest$source_freeze) ||
      !identical(context$manifest$source, downstream_context$manifest$source) ||
      !identical(context$manifest$source_freeze, downstream_context$manifest$source_freeze)) {
    stop("The ", downstream_context$manifest$stage, " manifest predecessor source provenance is inconsistent.")
  }
  context
}

validate_current_release_lineage <- function(project_root, analysis_manifest_path,
                                             policy = NULL, metadata = NULL,
                                             current_git_commit = NULL,
                                             require_clean_worktree = TRUE,
                                             authorization_action = NULL) {
  # A candidate is meaningful only when its entire validation-to-analysis chain
  # was produced by the exact current controlled source. This check deliberately
  # happens before candidate creation and during attestation verification, so a
  # later code, lockfile, metadata, or policy change cannot make an older or
  # mixed-version real-data lineage eligible for release.
  if (path_uses_configured_restricted_root(analysis_manifest_path)) {
    require_restricted_operation_authorization(
      project_root,
      authorization_action %||% "release"
    )
  }
  if (is.null(policy)) {
    policy <- read_release_policy(file.path(project_root, "config", "release-policy.yml"))
  }
  if (is.null(metadata)) metadata <- read_metadata(project_root)
  git <- git_metadata(project_root)
  if (isTRUE(require_clean_worktree) && isTRUE(git$dirty)) {
    stop("Release lineage verification requires a clean Git worktree.")
  }
  current_commit <- current_git_commit %||% git$commit
  if (!is_git_commit(current_commit)) {
    stop("Current Git commit is unavailable; cannot prepare or verify a release.")
  }
  if (!identical(current_commit, git$commit)) {
    stop("Supplied current Git commit does not match the checked-out HEAD.")
  }
  current_lockfile_sha256 <- tracked_file_sha256(file.path(project_root, "renv.lock"))
  expected_schema <- unlist(metadata_hashes(metadata), use.names = TRUE)
  expected_schema[["release_policy"]] <- policy$sha256

  analysis_context <- validate_stage_manifest(analysis_manifest_path, "analysis")
  expected_analysis_path <- normalizePath(
    file.path(analysis_context$run_dir, "manifests", "03-analysis.json"),
    winslash = "/", mustWork = FALSE
  )
  actual_analysis_path <- normalizePath(analysis_manifest_path, winslash = "/", mustWork = TRUE)
  if (!identical(analysis_context$manifest$mode, "real") ||
      !identical(actual_analysis_path, expected_analysis_path)) {
    stop("Release lineage requires the canonical real-run manifests/03-analysis.json artifact.")
  }
  expected_analysis_controls <- if (identical(analysis_context$manifest$schema_version, "1.2")) {
    analysis_control_fingerprint(project_root)
  } else {
    NULL
  }
  validate_current_stage_provenance(
    "Analysis", analysis_context$manifest, expected_schema, policy,
    current_commit, current_lockfile_sha256, expected_analysis_controls
  )
  transformation_context <- read_bound_predecessor(
    analysis_context$run_dir,
    "02-transformation.json",
    "transformation",
    analysis_context$manifest$transformation_manifest_sha256,
    analysis_context
  )
  validate_current_stage_provenance(
    "Transformation", transformation_context$manifest, expected_schema, policy,
    current_commit, current_lockfile_sha256, expected_analysis_controls
  )
  validation_context <- read_bound_predecessor(
    analysis_context$run_dir,
    "01-validation.json",
    "validation",
    transformation_context$manifest$validation_manifest_sha256,
    transformation_context
  )
  validate_current_stage_provenance(
    "Validation", validation_context$manifest, expected_schema, policy,
    current_commit, current_lockfile_sha256, expected_analysis_controls
  )

  invisible(list(
    git_commit = current_commit,
    lockfile_sha256 = current_lockfile_sha256,
    release_policy_sha256 = policy$sha256,
    analysis_controls = expected_analysis_controls,
    analysis = analysis_context,
    transformation = transformation_context,
    validation = validation_context
  ))
}

validate_analysis_baseline_descriptor <- function(baseline) {
  if (!is.list(baseline) || !is_git_commit(baseline$git_commit) || !is_sha256(baseline$lockfile_sha256) ||
      !is.list(baseline$analysis_controls) || !identical(baseline$analysis_controls$schema_version, "1.0") ||
      !is.list(baseline$analysis_controls$files) || !all(vapply(baseline$analysis_controls$files, is_sha256, logical(1)))) {
    stop("Release candidate has an invalid analytical-baseline descriptor.")
  }
  invisible(baseline)
}

validate_analysis_baseline_stage_provenance <- function(stage, manifest, expected_schema,
                                                        policy, baseline) {
  environment <- manifest$environment
  if (!identical(manifest$schema_version, "1.2") || !is.list(environment) ||
      !is_git_commit(environment$git_commit) || !isFALSE(environment$git_dirty)) {
    stop(stage, " manifest does not record a clean analytical-baseline provenance.")
  }
  if (!identical(environment$git_commit, baseline$git_commit) ||
      !is_sha256(environment$lockfile_sha256) || !identical(environment$lockfile_sha256, baseline$lockfile_sha256)) {
    stop(stage, " manifest does not match the candidate analytical baseline.")
  }
  if (!identical(manifest$analysis_controls, baseline$analysis_controls)) {
    stop(stage, " manifest does not match the candidate analytical-control fingerprint.")
  }
  recorded_schema <- unlist(manifest$schema, use.names = TRUE)
  recorded_policy_hash <- recorded_schema[["release_policy"]]
  if (!is_sha256(recorded_policy_hash) || !identical(recorded_policy_hash, policy$sha256)) {
    stop("Release policy changed after ", tolower(stage), "; the candidate is not eligible for this editorial build.")
  }
  if (!identical(as.character(recorded_schema[names(expected_schema)]), as.character(expected_schema))) {
    stop("Controlled metadata changed after ", tolower(stage), "; the candidate is not eligible for this editorial build.")
  }
  invisible(TRUE)
}

validate_candidate_analysis_baseline_lineage <- function(project_root, analysis_manifest_path,
                                                         baseline, policy = NULL, metadata = NULL,
                                                         require_clean_worktree = TRUE) {
  validate_analysis_baseline_descriptor(baseline)
  if (is.null(policy)) policy <- read_release_policy(file.path(project_root, "config", "release-policy.yml"))
  if (is.null(metadata)) metadata <- read_metadata(project_root)
  git <- git_metadata(project_root)
  if (isTRUE(require_clean_worktree) && isTRUE(git$dirty)) {
    stop("Analytical-baseline verification requires a clean Git worktree.")
  }
  validate_analysis_control_fingerprint(baseline$analysis_controls, project_root, "Release candidate")
  expected_schema <- unlist(metadata_hashes(metadata), use.names = TRUE)
  expected_schema[["release_policy"]] <- policy$sha256
  analysis_context <- validate_stage_manifest(analysis_manifest_path, "analysis")
  expected_analysis_path <- normalizePath(
    file.path(analysis_context$run_dir, "manifests", "03-analysis.json"),
    winslash = "/", mustWork = FALSE
  )
  actual_analysis_path <- normalizePath(analysis_manifest_path, winslash = "/", mustWork = TRUE)
  if (!identical(analysis_context$manifest$mode, "real") || !identical(actual_analysis_path, expected_analysis_path)) {
    stop("Release lineage requires the canonical real-run manifests/03-analysis.json artifact.")
  }
  validate_analysis_baseline_stage_provenance("Analysis", analysis_context$manifest, expected_schema, policy, baseline)
  transformation_context <- read_bound_predecessor(
    analysis_context$run_dir, "02-transformation.json", "transformation",
    analysis_context$manifest$transformation_manifest_sha256, analysis_context
  )
  validate_analysis_baseline_stage_provenance("Transformation", transformation_context$manifest, expected_schema, policy, baseline)
  validation_context <- read_bound_predecessor(
    analysis_context$run_dir, "01-validation.json", "validation",
    transformation_context$manifest$validation_manifest_sha256, transformation_context
  )
  validate_analysis_baseline_stage_provenance("Validation", validation_context$manifest, expected_schema, policy, baseline)
  invisible(list(
    git_commit = baseline$git_commit,
    lockfile_sha256 = baseline$lockfile_sha256,
    release_policy_sha256 = policy$sha256,
    analysis_controls = baseline$analysis_controls,
    analysis = analysis_context,
    transformation = transformation_context,
    validation = validation_context
  ))
}

validate_release_scalar <- function(value, label) {
  if (!is.character(value) || length(value) != 1L || is.na(value) || !nzchar(trimws(value))) {
    stop("Release summary has an invalid ", label, " value.")
  }
  invisible(value)
}

validate_release_count <- function(value, label, allow_zero = TRUE) {
  if (!is.numeric(value) || length(value) != 1L || is.na(value) || !is.finite(value) ||
      value != floor(value) || value < if (allow_zero) 0 else 1) {
    stop("Release summary has an invalid ", label, " value.")
  }
  as.integer(value)
}

validate_release_summary_against_metadata <- function(primary, metadata, require_complete_universe = FALSE) {
  allowed <- metadata$item_spec[
    metadata$item_spec$analysis_name %in% releaseable_item_names(metadata),
    c("analysis_name", "item_type", "domain"),
    drop = FALSE
  ]
  if (!nrow(allowed) || anyDuplicated(allowed$analysis_name)) {
    stop("Controlled metadata does not define a valid release universe.")
  }
  observed_items <- unique(primary$item)
  if (!all(observed_items %in% allowed$analysis_name)) {
    stop("Release summary contains an item outside the controlled release universe.")
  }
  if (isTRUE(require_complete_universe) && !setequal(observed_items, allowed$analysis_name)) {
    stop("Release summary does not cover the complete controlled release universe.")
  }
  for (item in observed_items) {
    expected_item <- allowed[allowed$analysis_name == item, , drop = FALSE]
    rows <- primary[primary$item == item, , drop = FALSE]
    if (!all(rows$domain == expected_item$domain[[1]]) ||
        !all(rows$item_type == expected_item$item_type[[1]])) {
      stop("Release summary item metadata does not match the controlled specification.")
    }
    options <- if (identical(expected_item$item_type[[1]], "checkbox")) {
      codebook <- checkbox_codebook(metadata, item)
      data.frame(
        response = as.character(codebook$canonical_option),
        display_order = as.integer(codebook$display_order),
        stringsAsFactors = FALSE
      )
    } else {
      codebook <- scalar_codebook(metadata, item, expected_item$item_type[[1]])
      data.frame(
        response = as.character(codebook$canonical_value),
        display_order = as.integer(codebook$display_order),
        stringsAsFactors = FALSE
      )
    }
    expected <- options[order(options$display_order, options$response), , drop = FALSE]
    rownames(expected) <- NULL
    observed <- data.frame(
      response = as.character(rows$response),
      display_order = as.integer(rows$display_order),
      stringsAsFactors = FALSE
    )
    observed <- observed[order(observed$display_order, observed$response), , drop = FALSE]
    rownames(observed) <- NULL
    if (!identical(observed, expected)) {
      stop("Release summary response categories do not match the controlled specification.")
    }
  }
  invisible(TRUE)
}

validate_release_summary <- function(summary_table, metadata = NULL, require_complete_universe = FALSE) {
  required <- c(
    "domain", "item", "item_type", "analysis_variant", "response", "display_order", "n",
    "denominator", "percent"
  )
  if (!is.data.frame(summary_table) || !all(required %in% names(summary_table))) {
    stop("Internal summary has an unsupported disclosure schema.")
  }
  primary <- summary_table[summary_table$analysis_variant == "primary", required, drop = FALSE]
  if (!is.null(metadata)) {
    primary <- primary[primary$item %in% releaseable_item_names(metadata), , drop = FALSE]
  }
  if (!nrow(primary)) stop("Internal summary does not contain a primary release universe.")
  if (anyNA(primary$analysis_variant) || any(summary_table$analysis_variant == "", na.rm = TRUE)) {
    stop("Internal summary has an invalid analysis variant.")
  }
  if (any(primary$analysis_variant != "primary")) stop("Release universe must contain only primary variants.")
  for (column in c("domain", "item", "item_type", "response")) {
    lapply(primary[[column]], validate_release_scalar, label = column)
  }
  display_order <- vapply(primary$display_order, validate_release_count, integer(1), label = "display_order")
  counts <- vapply(primary$n, validate_release_count, integer(1), label = "n")
  denominators <- vapply(primary$denominator, validate_release_count, integer(1), label = "denominator")
  if (any(counts > denominators)) stop("Release summary contains a count larger than its denominator.")
  expected_percent <- ifelse(denominators > 0L, round(100 * counts / denominators, 1), NA_real_)
  observed_percent <- suppressWarnings(as.numeric(primary$percent))
  percent_ok <- (is.na(expected_percent) & is.na(observed_percent)) |
    (!is.na(expected_percent) & is.finite(observed_percent) & abs(expected_percent - observed_percent) < 1e-8)
  if (!all(percent_ok)) stop("Release summary has an inconsistent percent value.")
  keys <- interaction(primary$domain, primary$item, primary$item_type, primary$analysis_variant, drop = TRUE, lex.order = TRUE)
  response_keys <- paste(keys, primary$response, sep = "\r")
  if (anyDuplicated(response_keys)) stop("Release summary contains duplicate response rows.")
  for (group in split(seq_len(nrow(primary)), keys)) {
    group_denominators <- unique(denominators[group])
    if (length(group_denominators) != 1L) stop("A release table has inconsistent denominators.")
    if (anyDuplicated(display_order[group])) stop("A release table has duplicate display orders.")
  }
  primary$display_order <- display_order
  primary$n <- counts
  primary$denominator <- denominators
  primary$percent <- observed_percent
  if (!is.null(metadata)) {
    validate_release_summary_against_metadata(
      primary,
      metadata,
      require_complete_universe = require_complete_universe
    )
  }
  primary
}

conservative_suppress <- function(summary_table, threshold, metadata = NULL, require_complete_universe = FALSE) {
  threshold <- validate_release_count(threshold, "minimum_cell_count", allow_zero = FALSE)
  if (threshold < 2L) stop("minimum_cell_count must be at least 2.")
  primary <- validate_release_summary(
    summary_table,
    metadata = metadata,
    require_complete_universe = require_complete_universe
  )
  groups <- split(
    primary,
    interaction(primary$domain, primary$item, primary$item_type, primary$analysis_variant, drop = TRUE, lex.order = TRUE)
  )
  public <- list()
  log <- list()
  for (group in groups) {
    denominator <- unique(group$denominator)
    small_positive <- any(group$n > 0L & group$n < threshold)
    small_denominator <- denominator[[1]] < threshold
    if (small_positive || small_denominator) {
      public[[length(public) + 1L]] <- data.frame(
        domain = group$domain[[1]], item = group$item[[1]], item_type = group$item_type[[1]],
        analysis_variant = "primary", response = NA_character_, display_order = NA_integer_,
        n = NA_integer_, denominator = NA_integer_, percent = NA_real_, release_status = "fully_suppressed",
        stringsAsFactors = FALSE
      )
      log[[length(log) + 1L]] <- data.frame(
        domain = group$domain[[1]], item = group$item[[1]], item_type = group$item_type[[1]],
        analysis_variant = "primary",
        reason = if (small_denominator) "denominator_below_threshold" else "positive_cell_below_threshold",
        stringsAsFactors = FALSE
      )
    } else {
      public[[length(public) + 1L]] <- data.frame(
        domain = group$domain, item = group$item, item_type = group$item_type,
        analysis_variant = group$analysis_variant, response = group$response,
        display_order = group$display_order, n = group$n, denominator = group$denominator,
        percent = group$percent, release_status = "released",
        stringsAsFactors = FALSE
      )
    }
  }
  list(
    public = do.call(rbind, public),
    suppression_log = if (length(log)) {
      do.call(rbind, log)
    } else {
      data.frame(
        domain = character(), item = character(), item_type = character(), analysis_variant = character(),
        reason = character(), stringsAsFactors = FALSE
      )
    }
  )
}

tex_escape <- function(value) {
  output <- enc2utf8(as.character(value))
  typography <- c(
    "\u00a0" = " ",
    "\u2018" = "'",
    "\u2019" = "'",
    "\u201c" = "\"",
    "\u201d" = "\"",
    "\u2013" = "-",
    "\u2014" = "-"
  )
  for (token in names(typography)) output <- gsub(token, typography[[token]], output, fixed = TRUE)
  output <- gsub("[[:cntrl:]]+", " ", output)
  output <- trimws(gsub("[[:space:]]+", " ", output))
  unsupported <- !is.na(output) & grepl("[^ -~]", output)
  if (any(unsupported)) {
    stop("The TeX renderer cannot safely encode non-ASCII controlled display text.")
  }
  replacements <- c(
    "\\" = "\\textbackslash{}",
    "&" = "\\&",
    "%" = "\\%",
    "$" = "\\$",
    "#" = "\\#",
    "_" = "\\_",
    "{" = "\\{",
    "}" = "\\}",
    "~" = "\\textasciitilde{}",
    "^" = "\\textasciicircum{}"
  )
  unname(vapply(output, function(entry) {
    if (is.na(entry)) return(NA_character_)
    characters <- strsplit(entry, "", fixed = TRUE)[[1]]
    escaped <- unname(replacements[characters])
    escaped[is.na(escaped)] <- characters[is.na(escaped)]
    paste0(escaped, collapse = "")
  }, character(1)))
}

# The v1.1 renderer is retained verbatim for validating a legacy candidate in
# its original frozen execution checkout. New candidates use the labelled
# v1.2 renderer below. Do not alter this function: its bytes define the
# historical candidate contract.
render_release_results_tex_v1_1 <- function(public_summary) {
  required <- c("domain", "item", "response", "n", "denominator", "percent", "release_status")
  if (!is.data.frame(public_summary) || !all(required %in% names(public_summary))) {
    stop("Release candidate has an unsupported public-summary schema for manuscript rendering.")
  }
  released <- public_summary[public_summary$release_status == "released", , drop = FALSE]
  suppressed_present <- any(public_summary$release_status == "fully_suppressed")
  lines <- c("% Generated only from a restricted disclosure-controlled release candidate.")
  if (!nrow(released)) {
    return(c(
      lines,
      "\\textit{No structured result table was releasable under the approved disclosure policy.}"
    ))
  }
  lines <- c(
    lines,
    "\\subsection*{Disclosure-approved structured summaries}",
    "\\begin{longtable}{p{0.22\\linewidth}p{0.35\\linewidth}rrr}",
    "\\toprule",
    "Item & Response & $n$ & $N$ & Percent \\\\",
    "\\midrule",
    "\\endhead"
  )
  item_labels <- gsub("_", " ", released$item, fixed = TRUE)
  for (i in seq_len(nrow(released))) {
    lines <- c(lines, paste0(
      tex_escape(item_labels[[i]]), " & ", tex_escape(released$response[[i]]), " & ",
      as.integer(released$n[[i]]), " & ", as.integer(released$denominator[[i]]), " & ",
      formatC(released$percent[[i]], format = "f", digits = 1), "\\% \\\\"
    ))
  }
  lines <- c(lines, "\\bottomrule", "\\end{longtable}")
  if (suppressed_present) {
    lines <- c(lines, "\\textit{Additional pre-specified structured tables were withheld under the disclosure policy.}")
  }
  lines
}

render_release_results_tex <- function(public_summary, metadata) {
  required <- c("domain", "item", "response", "n", "denominator", "percent", "release_status")
  if (!is.data.frame(public_summary) || !all(required %in% names(public_summary))) {
    stop("Release candidate has an unsupported public-summary schema for manuscript rendering.")
  }
  if (!is.list(metadata) || is.null(metadata$publication_labels)) {
    stop("Release rendering requires controlled publication labels.")
  }
  released <- public_summary[public_summary$release_status == "released", , drop = FALSE]
  suppressed_present <- any(public_summary$release_status == "fully_suppressed")
  lines <- c("% Generated only from a restricted disclosure-controlled release candidate.")
  if (!nrow(released)) {
    return(c(
      lines,
      "\\textit{No structured result table was releasable under the approved disclosure policy.}"
    ))
  }
  labels <- do.call(rbind, lapply(unique(released$item), function(item) publication_label(metadata, item)))
  released$publication_label <- labels$publication_label[match(released$item, labels$analysis_name)]
  released$domain_label <- labels$domain_label[match(released$item, labels$analysis_name)]
  released$domain_order <- as.integer(labels$domain_order[match(released$item, labels$analysis_name)])
  # Candidate construction supplies controlled display order.  Keep the
  # renderer usable for deliberately minimal, already-validated test fixtures
  # by falling back to their existing row order when that optional column is
  # absent; candidate validation separately requires the controlled schema.
  response_order <- if ("display_order" %in% names(released)) {
    released$display_order
  } else {
    seq_len(nrow(released))
  }
  released <- released[order(released$domain_order, released$domain_label, released$item, response_order), , drop = FALSE]
  lines <- c(
    lines,
    "\\subsection*{Disclosure-approved structured summaries}",
    "\\begin{longtable}{p{0.30\\linewidth}p{0.30\\linewidth}rrr}",
    "\\caption{Disclosure-approved structured survey summaries.}\\label{tab:structured-survey-summaries}\\\\",
    "\\toprule",
    "Item & Response & $n$ & $N$ & Percent \\\\",
    "\\midrule",
    "\\endfirsthead",
    "\\toprule",
    "Item & Response & $n$ & $N$ & Percent \\\\",
    "\\midrule",
    "\\endhead"
  )
  for (domain in unique(released$domain_label)) {
    domain_rows <- released[released$domain_label == domain, , drop = FALSE]
    lines <- c(lines, paste0("\\multicolumn{5}{l}{\\textit{", tex_escape(domain), "}} \\\\"))
    for (item in unique(domain_rows$item)) {
      item_rows <- domain_rows[domain_rows$item == item, , drop = FALSE]
      for (i in seq_len(nrow(item_rows))) {
        item_label <- if (i == 1L) item_rows$publication_label[[i]] else ""
        lines <- c(lines, paste0(
          tex_escape(item_label), " & ", tex_escape(item_rows$response[[i]]), " & ",
          as.integer(item_rows$n[[i]]), " & ", as.integer(item_rows$denominator[[i]]), " & ",
          formatC(item_rows$percent[[i]], format = "f", digits = 1), "\\% \\\\"
        ))
      }
    }
  }
  lines <- c(
    lines,
    "\\bottomrule",
    "\\end{longtable}",
    "\\noindent\\textit{Note.} Percentages use the item-specific released denominator ($N$) shown in the table."
  )
  if (suppressed_present) {
    lines <- c(lines, "\\textit{Additional pre-specified structured tables were withheld under the disclosure policy.}")
  }
  lines
}

candidate_output_descriptor <- function(candidate_dir, filename) {
  if (!is.character(filename) || length(filename) != 1L || basename(filename) != filename) {
    stop("Release candidate output filename is unsafe.")
  }
  path <- file.path(candidate_dir, filename)
  if (!file.exists(path)) stop("Release candidate output is missing: ", filename)
  list(filename = filename, sha256 = sha256_file(path))
}

candidate_output_filenames <- function() {
  c(
    structured_summary_public = "structured-summary-public.csv",
    suppression_log = "suppression-log.csv",
    manuscript_results = "generated-results.tex"
  )
}

validate_candidate_output_filenames <- function(outputs) {
  filenames <- candidate_output_filenames()
  declared_filenames <- if (is.list(outputs)) vapply(outputs, function(descriptor) {
    if (!is.list(descriptor) || !is_nonempty_string(descriptor$filename)) return(NA_character_)
    descriptor$filename
  }, character(1)) else character()
  # Validate output keys/order separately from their values. `vapply()` retains
  # the manifest keys as names, so compare the filename values without names
  # after the explicit key/order check above.
  if (!identical(names(outputs), names(filenames)) ||
      !identical(unname(declared_filenames), unname(filenames))) {
    stop("Release candidate manifest does not declare the canonical output filenames.")
  }
  filenames
}

read_candidate_csv <- function(path, expected_columns, label) {
  table <- tryCatch(
    utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE, na.strings = ""),
    error = function(error) NULL
  )
  if (is.null(table) || !identical(names(table), expected_columns)) {
    stop("Release candidate has an unsupported ", label, " schema.")
  }
  table
}

normalize_optional_integer_column <- function(values, label, minimum = 0L) {
  numeric_values <- suppressWarnings(as.numeric(values))
  bad <- !is.na(values) & (is.na(numeric_values) | !is.finite(numeric_values) |
    numeric_values != floor(numeric_values) | numeric_values < minimum)
  if (any(bad)) stop("Release candidate has an invalid ", label, " value.")
  as.integer(numeric_values)
}

normalize_optional_numeric_column <- function(values, label) {
  numeric_values <- suppressWarnings(as.numeric(values))
  bad <- !is.na(values) & (is.na(numeric_values) | !is.finite(numeric_values))
  if (any(bad)) stop("Release candidate has an invalid ", label, " value.")
  as.numeric(numeric_values)
}

normalize_candidate_public_summary <- function(table) {
  required <- c(
    "domain", "item", "item_type", "analysis_variant", "response", "display_order",
    "n", "denominator", "percent", "release_status"
  )
  if (!identical(names(table), required)) {
    stop("Release candidate has an unsupported public-summary schema.")
  }
  out <- data.frame(
    domain = as.character(table$domain),
    item = as.character(table$item),
    item_type = as.character(table$item_type),
    analysis_variant = as.character(table$analysis_variant),
    response = as.character(table$response),
    display_order = normalize_optional_integer_column(table$display_order, "public display_order", minimum = 1L),
    n = normalize_optional_integer_column(table$n, "public n", minimum = 0L),
    denominator = normalize_optional_integer_column(table$denominator, "public denominator", minimum = 0L),
    percent = normalize_optional_numeric_column(table$percent, "public percent"),
    release_status = as.character(table$release_status),
    stringsAsFactors = FALSE
  )
  if (any(!out$release_status %in% c("released", "fully_suppressed"))) {
    stop("Release candidate has an invalid public release status.")
  }
  out
}

normalize_candidate_suppression_log <- function(table) {
  required <- c("domain", "item", "item_type", "analysis_variant", "reason")
  if (!identical(names(table), required)) {
    stop("Release candidate has an unsupported suppression-log schema.")
  }
  out <- data.frame(
    domain = as.character(table$domain),
    item = as.character(table$item),
    item_type = as.character(table$item_type),
    analysis_variant = as.character(table$analysis_variant),
    reason = as.character(table$reason),
    stringsAsFactors = FALSE
  )
  if (nrow(out) && (anyNA(out) || any(!nzchar(out$domain)) || any(!nzchar(out$item)) ||
    any(!nzchar(out$item_type)) || any(!nzchar(out$analysis_variant)) || any(!nzchar(out$reason)))) {
    stop("Release candidate has an invalid suppression-log value.")
  }
  out
}

validate_candidate_artifacts <- function(candidate_dir, manifest, release, metadata) {
  filenames <- validate_candidate_output_filenames(manifest$outputs)
  expected_files <- c(unname(filenames), "release-candidate-manifest.json")
  entries <- list.files(candidate_dir, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  entry_names <- basename(entries)
  if (!identical(sort(entry_names), sort(expected_files)) || any(file.info(entries)$isdir)) {
    stop("Release candidate directory contains unexpected artifacts.")
  }

  public_path <- file.path(candidate_dir, filenames[["structured_summary_public"]])
  suppression_path <- file.path(candidate_dir, filenames[["suppression_log"]])
  manuscript_path <- file.path(candidate_dir, filenames[["manuscript_results"]])
  actual_public <- normalize_candidate_public_summary(read_candidate_csv(
    public_path,
    c("domain", "item", "item_type", "analysis_variant", "response", "display_order", "n", "denominator", "percent", "release_status"),
    "public summary"
  ))
  expected_public <- normalize_candidate_public_summary(release$public)
  actual_log <- normalize_candidate_suppression_log(read_candidate_csv(
    suppression_path,
    c("domain", "item", "item_type", "analysis_variant", "reason"),
    "suppression log"
  ))
  expected_log <- normalize_candidate_suppression_log(release$suppression_log)
  if (!isTRUE(all.equal(actual_public, expected_public, check.attributes = FALSE)) ||
      !isTRUE(all.equal(actual_log, expected_log, check.attributes = FALSE))) {
    stop("Release candidate artifacts are not derived from the bound analysis and disclosure policy.")
  }
  expected_tex <- if (identical(manifest$schema_version, "1.1")) {
    render_release_results_tex_v1_1(expected_public)
  } else {
    render_release_results_tex(expected_public, metadata = metadata)
  }
  actual_tex <- tryCatch(readLines(manuscript_path, warn = FALSE, encoding = "UTF-8"), error = function(error) NULL)
  if (is.null(actual_tex) || !identical(actual_tex, expected_tex)) {
    stop("Release candidate manuscript results are not derived from the public summary.")
  }
  if (!is.numeric(manifest$suppression_groups) || length(manifest$suppression_groups) != 1L ||
      is.na(manifest$suppression_groups) || manifest$suppression_groups != nrow(expected_log)) {
    stop("Release candidate manifest has an invalid suppression-group count.")
  }
  invisible(TRUE)
}

validate_release_candidate_manifest <- function(project_root, candidate_manifest_path,
                                                policy = NULL, metadata = NULL,
                                                current_git_commit = NULL,
                                                require_clean_worktree = TRUE,
                                                authorization_action = "release") {
  if (!file.exists(candidate_manifest_path)) stop("Missing release candidate manifest.")
  if (is.null(policy)) policy <- read_release_policy(file.path(project_root, "config", "release-policy.yml"))
  if (is.null(metadata)) metadata <- read_metadata(project_root)
  assert_release_policy_controls(policy, action = "Release-candidate verification")
  root <- restricted_root(project_root)
  candidate_dir <- normalizePath(dirname(candidate_manifest_path), winslash = "/", mustWork = TRUE)
  if (!path_within(candidate_dir, file.path(root, "runs"))) {
    stop("Release candidate manifest must reside under approved restricted storage.")
  }
  if (!identical(basename(candidate_dir), "release-candidate")) {
    stop("Release candidate manifest must reside in a release-candidate directory.")
  }
  output_dir <- dirname(candidate_dir)
  run_dir <- dirname(output_dir)
  if (!identical(basename(output_dir), "outputs")) {
    stop("Release candidate directory has an unsupported location.")
  }
  manifest <- tryCatch(jsonlite::read_json(candidate_manifest_path, simplifyVector = FALSE), error = function(error) NULL)
  candidate_schema <- if (is.list(manifest)) manifest$schema_version else NULL
  requested_analysis_baseline <- if (identical(candidate_schema, "1.2") && is.list(manifest$analysis_baseline)) {
    manifest$analysis_baseline$git_commit
  } else {
    NULL
  }
  authorization <- require_restricted_operation_authorization(
    project_root,
    authorization_action,
    analysis_baseline_git_commit = requested_analysis_baseline
  )
  declared_exclusions <- if (is.list(manifest) && is.list(manifest$release_universe) && !is.null(manifest$release_universe$excluded)) {
    as.character(unlist(manifest$release_universe$excluded, use.names = FALSE))
  } else {
    character()
  }
  schema_ok <- identical(candidate_schema, "1.1") || identical(candidate_schema, "1.2")
  expected_exclusions <- if (identical(candidate_schema, "1.1")) {
    c("sensitivity variants", "exploratory cross-tabs", "qualitative material", "respondent-level material")
  } else {
    c(
      "conditional reason item without verified routing",
      "sensitivity variants",
      "exploratory cross-tabs",
      "qualitative material",
      "respondent-level material"
    )
  }
  baseline_ok <- if (identical(candidate_schema, "1.2")) {
    tryCatch({
      validate_analysis_baseline_descriptor(manifest$analysis_baseline)
      TRUE
    }, error = function(error) FALSE)
  } else {
    is.null(manifest$analysis_baseline)
  }
  if (is.null(manifest) || !schema_ok || !baseline_ok ||
      !identical(manifest$status, "candidate_generated_pending_manual_review") ||
      !is_sha256(manifest$analysis_manifest_sha256) || !is_sha256(manifest$release_policy_sha256) ||
      !identical(manifest$analysis_manifest_relative_path, "manifests/03-analysis.json") ||
      is.null(manifest$generator) || !is_git_commit(manifest$generator$git_commit) ||
      !is_sha256(manifest$generator$script_sha256) ||
       is.null(manifest$release_universe) || !identical(manifest$release_universe$analysis_variants, "primary") ||
       !identical(declared_exclusions, expected_exclusions) ||
       is.null(manifest$outputs) || !identical(names(manifest$outputs), names(candidate_output_filenames()))) {
    stop("Release candidate manifest has an unsupported schema.")
  }
  canonical_output_filenames <- validate_candidate_output_filenames(manifest$outputs)
  analysis_manifest_path <- file.path(run_dir, manifest$analysis_manifest_relative_path)
  if (!file.exists(analysis_manifest_path) || !identical(sha256_file(analysis_manifest_path), manifest$analysis_manifest_sha256)) {
    stop("Release candidate does not bind the analysis manifest in its own run directory.")
  }
  analysis_context <- validate_stage_manifest(analysis_manifest_path, "analysis")
  if (!identical(analysis_context$manifest$mode, "real") ||
      !identical(normalizePath(analysis_context$run_dir, winslash = "/", mustWork = TRUE), normalizePath(run_dir, winslash = "/", mustWork = TRUE))) {
    stop("Release candidate analysis lineage is invalid.")
  }
  lineage <- if (identical(candidate_schema, "1.1")) {
    validate_current_release_lineage(
      project_root,
      analysis_manifest_path,
      policy = policy,
      metadata = metadata,
      current_git_commit = current_git_commit,
      require_clean_worktree = require_clean_worktree,
      authorization_action = authorization_action
    )
  } else {
    validate_candidate_analysis_baseline_lineage(
      project_root,
      analysis_manifest_path,
      baseline = manifest$analysis_baseline,
      policy = policy,
      metadata = metadata,
      require_clean_worktree = require_clean_worktree
    )
  }
  analysis_context <- lineage$analysis
  analysis_policy_hash <- unlist(analysis_context$manifest$schema, use.names = TRUE)[["release_policy"]]
  if (!is_sha256(analysis_policy_hash) || !identical(manifest$release_policy_sha256, analysis_policy_hash)) {
    stop("Release candidate does not bind the analysis manifest release policy.")
  }
  if (!identical(manifest$generator$git_commit, lineage$git_commit) ||
      !identical(manifest$generator$git_commit, analysis_context$manifest$environment$git_commit)) {
    stop("Release candidate generator commit does not match its analysis manifest.")
  }
  if (!identical(manifest$generator$script_sha256, tracked_file_sha256(file.path(project_root, "scripts", "04_prepare_release.R")))) {
    stop("Release candidate generator script does not match the current release builder.")
  }
  output_names <- c("structured_summary_public", "suppression_log", "manuscript_results")
  output_hashes <- stats::setNames(vapply(output_names, function(name) {
    descriptor <- manifest$outputs[[name]]
    if (is.null(descriptor$filename) || !is_sha256(descriptor$sha256)) {
      stop("Release candidate manifest has an invalid output descriptor.")
    }
    actual <- candidate_output_descriptor(candidate_dir, canonical_output_filenames[[name]])
    if (!identical(actual$sha256, descriptor$sha256)) stop("Release candidate output does not match its manifest.")
    actual$sha256
  }, character(1)), output_names)
  summary_descriptor <- analysis_context$manifest$outputs$structured_summary
  if (is.null(summary_descriptor)) stop("Release candidate analysis manifest is missing the structured summary artifact.")
  summary_path <- resolve_manifest_output(analysis_context$run_dir, summary_descriptor, "structured_summary")
  summary_table <- read.csv(summary_path, check.names = FALSE, stringsAsFactors = FALSE, na.strings = "")
  release <- conservative_suppress(summary_table, policy$minimum_cell_count, metadata = metadata)
  validate_candidate_artifacts(candidate_dir, manifest, release, metadata = metadata)
  list(
    path = normalizePath(candidate_manifest_path, winslash = "/", mustWork = TRUE),
    sha256 = sha256_file(candidate_manifest_path),
    directory = candidate_dir,
    analysis_manifest_path = normalizePath(analysis_manifest_path, winslash = "/", mustWork = TRUE),
    manifest = manifest,
    output_hashes = output_hashes,
    authorization = authorization
  )
}

read_release_attestation <- function(project_root, approval_id, candidate,
                                     authorization_action = "verify-release",
                                     authorization = NULL) {
  baseline <- if (is.list(candidate$manifest) && identical(candidate$manifest$schema_version, "1.2")) {
    candidate$manifest$analysis_baseline$git_commit
  } else {
    NULL
  }
  verified_authorization <- require_restricted_operation_authorization(
    project_root, authorization_action, analysis_baseline_git_commit = baseline
  )
  if (!is.null(authorization) && !identical(authorization, verified_authorization)) {
    stop("The supplied restricted authorization does not match the current verified authorization.")
  }
  authorization <- verified_authorization
  approval_id <- validate_run_id(approval_id)
  root <- restricted_root(project_root)
  path <- file.path(root, "governance", "release-attestations", paste0(approval_id, ".json"))
  if (!file.exists(path)) stop("Missing restricted release attestation.")
  attestation <- tryCatch(jsonlite::read_json(path, simplifyVector = FALSE), error = function(error) NULL)
  required_output_hashes <- candidate$output_hashes[c("structured_summary_public", "suppression_log", "manuscript_results")]
  output_ok <- !is.null(attestation$candidate_output_sha256) && all(vapply(names(required_output_hashes), function(name) {
    identical(attestation$candidate_output_sha256[[name]], required_output_hashes[[name]])
  }, logical(1)))
  if (is.null(attestation) || !identical(attestation$schema_version, "1.1") ||
      !identical(attestation$status, "approved") || !isTRUE(attestation$manual_disclosure_review) ||
      !isTRUE(attestation$pi_approval_confirmed) ||
      !is.character(attestation$pi_approval_reference) || length(attestation$pi_approval_reference) != 1L ||
      !nzchar(trimws(attestation$pi_approval_reference)) ||
      !identical(attestation$candidate_manifest_sha256, candidate$sha256) ||
      !identical(attestation$analysis_manifest_sha256, candidate$manifest$analysis_manifest_sha256) ||
      !identical(attestation$release_policy_sha256, candidate$manifest$release_policy_sha256) || !output_ok) {
    stop("Restricted release attestation is absent, incomplete, or does not bind the exact candidate artifacts.")
  }
  # Authorization is revalidated at every operation boundary.  Do not include
  # its action-specific in-memory object in this stable attestation descriptor:
  # verify-release and manuscript-attested-build may use the same signed
  # authorization record while representing different permitted operations.
  list(id = approval_id, sha256 = sha256_file(path))
}

read_release_verification <- function(project_root, approval_id, candidate, attestation = NULL,
                                      authorization_action = "manuscript-attested-build",
                                      authorization = NULL) {
  # An attestation is not enough on its own for a restricted manuscript build:
  # the attestation must first have passed the independent verifier.  This
  # reader rechecks that the stored verification record is bound to the same
  # candidate bytes and to the immutable verifier implementation recorded for
  # that verification action.
  baseline <- if (is.list(candidate$manifest) && identical(candidate$manifest$schema_version, "1.2")) {
    candidate$manifest$analysis_baseline$git_commit
  } else {
    NULL
  }
  verified_authorization <- require_restricted_operation_authorization(
    project_root, authorization_action, analysis_baseline_git_commit = baseline
  )
  if (!is.null(authorization) && !identical(authorization, verified_authorization)) {
    stop("The supplied restricted authorization does not match the current verified authorization.")
  }
  authorization <- verified_authorization
  approval_id <- validate_run_id(approval_id)
  verified_attestation <- read_release_attestation(
    project_root, approval_id, candidate,
    authorization_action = authorization_action,
    authorization = authorization
  )
  if (!is.null(attestation) && !identical(attestation, verified_attestation)) {
    stop("The supplied release attestation does not match the current verified attestation.")
  }
  attestation <- verified_attestation
  if (!is.list(attestation) || !identical(attestation$id, approval_id) || !is_sha256(attestation$sha256)) {
    stop("Restricted release attestation input is invalid for verification lookup.")
  }
  root <- restricted_root(project_root)
  path <- file.path(root, "governance", "release-verifications", paste0(approval_id, ".json"))
  if (!file.exists(path)) stop("Missing restricted release-attestation verification record.")
  verification <- tryCatch(jsonlite::read_json(path, simplifyVector = FALSE), error = function(error) NULL)
  required_output_hashes <- candidate$output_hashes[c("structured_summary_public", "suppression_log", "manuscript_results")]
  output_ok <- !is.null(verification$candidate_output_sha256) && all(vapply(names(required_output_hashes), function(name) {
    identical(verification$candidate_output_sha256[[name]], required_output_hashes[[name]])
  }, logical(1)))
  historical_verifier_sha256 <- if (!is.null(verification$verifier) && is_git_commit(verification$verifier$git_commit)) {
    tryCatch(
      tracked_file_sha256_at_commit(
        project_root,
        "scripts/05_verify_release_attestation.R",
        verification$verifier$git_commit
      ),
      error = function(error) NA_character_
    )
  } else {
    NA_character_
  }
  verifier_ok <- !is.null(verification$verifier) &&
    is_git_commit(verification$verifier$git_commit) &&
    is_sha256(verification$verifier$script_sha256) &&
    !is.na(historical_verifier_sha256) &&
    identical(verification$verifier$script_sha256, historical_verifier_sha256)
  if (identical(candidate$manifest$schema_version, "1.1")) {
    verifier_ok <- verifier_ok && identical(verification$verifier$git_commit, candidate$manifest$generator$git_commit)
  }
  attestation_ok <- !is.null(verification$attestation) &&
    identical(verification$attestation$id, attestation$id) &&
    identical(verification$attestation$sha256, attestation$sha256)
  expected_verification_schema <- if (identical(candidate$manifest$schema_version, "1.2")) "1.2" else "1.1"
  authorization_ok <- if (identical(candidate$manifest$schema_version, "1.2")) {
    identical(verification$authorization, authorization_provenance_descriptor(authorization))
  } else {
    TRUE
  }
  if (is.null(verification) || !identical(verification$schema_version, expected_verification_schema) ||
      !identical(verification$status, "approved_candidate_verified_pending_external_delivery") ||
      !identical(verification$candidate_manifest_sha256, candidate$sha256) ||
      !identical(verification$analysis_manifest_sha256, candidate$manifest$analysis_manifest_sha256) ||
      !identical(verification$release_policy_sha256, candidate$manifest$release_policy_sha256) ||
      !output_ok || !attestation_ok || !verifier_ok || !authorization_ok) {
    stop("Restricted release-attestation verification is absent, incomplete, or does not bind the exact candidate artifacts.")
  }
  list(id = approval_id, sha256 = sha256_file(path))
}
