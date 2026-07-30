# Deterministic, conservative transformations for structured survey fields.
# Raw values remain only in the immutable restricted source freeze. This module
# writes canonical categories only when an exact controlled match is available.

contribution_status_sensitivity <- function(values, states, evidence_states, rule) {
  if (length(values) != length(states) || length(values) != length(evidence_states)) {
    stop("Contribution-status sensitivity inputs have inconsistent lengths.")
  }
  required_rule_columns <- c(
    "rule_id", "analysis_name", "analysis_variant", "evidence_item", "evidence_state",
    "when_primary_state", "derived_value", "derived_state", "scope", "rationale"
  )
  if (!is.data.frame(rule) || nrow(rule) != 1L || !identical(names(rule), required_rule_columns) ||
      !startsWith(rule$analysis_variant[[1]], "sensitivity_") ||
      !identical(rule$scope[[1]], "internal_sensitivity")) {
    stop("Scalar sensitivity requires a controlled derivation rule.")
  }
  values <- as.character(values)
  states <- as.character(states)
  evidence_states <- as.character(evidence_states)
  inferred <- states == rule$when_primary_state[[1]] & evidence_states == rule$evidence_state[[1]]
  sensitivity_values <- values
  sensitivity_states <- states
  sensitivity_values[inferred] <- rule$derived_value[[1]]
  sensitivity_states[inferred] <- rule$derived_state[[1]]
  list(
    values = sensitivity_values,
    states = sensitivity_states,
    inferred = inferred,
    inferred_n = sum(inferred)
  )
}

empty_rule_audit <- function(metadata) {
  data.frame(
    rule_id = c(metadata$transformation_rules$rule_id, metadata$derivation_rules$rule_id),
    affected_n = integer(nrow(metadata$transformation_rules) + nrow(metadata$derivation_rules)),
    stringsAsFactors = FALSE
  )
}

apply_registered_rules <- function(value, analysis_name, metadata, scope, rule_audit) {
  if (is.na(value) || !nzchar(trimws(value))) {
    return(list(value = NA_character_, rule_audit = rule_audit))
  }
  output <- normalize_display_text(value)
  rules <- metadata$transformation_rules[
    metadata$transformation_rules$analysis_name == analysis_name &
      metadata$transformation_rules$scope == scope,
    , drop = FALSE
  ]
  if (!nrow(rules)) return(list(value = output, rule_audit = rule_audit))

  for (i in seq_len(nrow(rules))) {
    key <- normalize_key(output)
    match_key <- normalize_key(rules$match_key[[i]])
    matched <- FALSE
    if (identical(rules$operation[[i]], "replace_exact")) {
      if (identical(key, match_key)) {
        output <- rules$replacement[[i]]
        matched <- TRUE
      }
    } else if (identical(rules$operation[[i]], "replace_substring")) {
      position <- regexpr(match_key, key, fixed = TRUE)[[1]]
      if (!identical(position, -1L)) {
        end <- position + nchar(match_key, type = "chars") - 1L
        output <- paste0(
          substr(key, 1L, position - 1L),
          normalize_key(rules$replacement[[i]]),
          substr(key, end + 1L, nchar(key, type = "chars"))
        )
        matched <- TRUE
      }
    }
    if (matched) {
      target <- which(rule_audit$rule_id == rules$rule_id[[i]])
      rule_audit$affected_n[[target]] <- rule_audit$affected_n[[target]] + 1L
    }
  }
  list(value = output, rule_audit = rule_audit)
}

recode_scalar <- function(value, analysis_name, item_type, metadata, rule_audit) {
  applied <- apply_registered_rules(value, analysis_name, metadata, "scalar", rule_audit)
  if (is.na(applied$value) || !nzchar(applied$value)) {
    return(list(value = NA_character_, state = "missing", rule_audit = applied$rule_audit))
  }
  codebook <- scalar_codebook(metadata, analysis_name, item_type)
  key <- normalize_key(applied$value)
  matched <- codebook[codebook$key == key, , drop = FALSE]
  if (nrow(matched) != 1L) {
    return(list(value = NA_character_, state = "invalid", rule_audit = applied$rule_audit))
  }
  list(value = matched$canonical_value[[1]], state = "valid", rule_audit = applied$rule_audit)
}

parse_checkbox <- function(value, analysis_name, metadata, rule_audit) {
  applied <- apply_registered_rules(value, analysis_name, metadata, "checkbox", rule_audit)
  if (is.na(applied$value) || !nzchar(applied$value)) {
    return(list(options = character(), state = "missing", rule_audit = applied$rule_audit))
  }
  codebook <- checkbox_codebook(metadata, analysis_name)
  working <- normalize_key(applied$value)
  selected <- integer()
  # Longest-first replacement prevents a short option from matching inside a
  # longer registered option. Remaining non-separator text is an unmatched
  # Other/free-text fragment and makes the response invalid for the primary
  # checkbox summary; no fragment is written to the audit artifact.
  for (i in seq_len(nrow(codebook))) {
    option_key <- codebook$key[[i]]
    repeat {
      hit <- regexpr(option_key, working, fixed = TRUE)[[1]]
      if (identical(hit, -1L)) break
      selected <- c(selected, i)
      width <- nchar(option_key, type = "chars")
      substr(working, hit, hit + width - 1L) <- strrep(" ", width)
    }
  }
  selected <- sort(unique(selected))
  remainder <- gsub("[,;[:space:]]", "", working)
  if (!length(selected)) {
    return(list(options = character(), state = "invalid", rule_audit = applied$rule_audit))
  }
  if (nzchar(remainder)) {
    return(list(options = character(), state = "partial_invalid", rule_audit = applied$rule_audit))
  }
  list(
    options = codebook$canonical_option[selected],
    state = "valid",
    rule_audit = applied$rule_audit
  )
}

skip_applicability <- function(values, rule, variant = "primary") {
  n <- nrow(values)
  scalar <- function(name) as.character(values[[name]])
  nonmissing <- function(x) !is.na(x) & nzchar(x)
  if (identical(rule, "always")) return(rep(TRUE, n))
  if (identical(rule, "never")) return(rep(FALSE, n))
  if (identical(rule, "wiki_awareness_any")) return(nonmissing(scalar("wiki_awareness")))
  if (identical(rule, "wiki_visited_yes")) {
    value <- scalar("wiki_visited")
    return(!is.na(value) & startsWith(value, "Yes"))
  }
  if (identical(rule, "consult_frequency_not_never")) {
    value <- scalar("consult_frequency")
    return(nonmissing(value) & value != "Never")
  }
  if (identical(rule, "needs_not_fully_met")) {
    value <- scalar("needs_met")
    return(!is.na(value) & (startsWith(value, "Moderately") | startsWith(value, "Slightly") | startsWith(value, "Not")))
  }
  if (identical(rule, "contributed_no_or_missing")) {
    value <- scalar("contributed")
    return(!is.na(value) & value == "No")
  }
  if (identical(rule, "editathon_nonparticipant")) {
    value <- scalar("editathon_awareness")
    return(!is.na(value) & value == "Yes, but I did not participate")
  }
  if (identical(rule, "editathon_participant")) {
    value <- scalar("editathon_awareness")
    return(!is.na(value) & value == "Yes, and I participated")
  }
  if (identical(rule, "editathon_aware")) {
    value <- scalar("editathon_awareness")
    return(!is.na(value) & startsWith(value, "Yes"))
  }
  stop("Unsupported skip rule: ", rule)
}

state_counts <- function(states) {
  levels <- c("valid", "inferred", "missing", "invalid", "partial_invalid", "structural_skip")
  counts <- table(factor(states, levels = levels))
  stats::setNames(as.integer(counts), levels)
}
