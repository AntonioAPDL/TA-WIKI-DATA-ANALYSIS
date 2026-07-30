#!/usr/bin/env Rscript

# Build the structured-only coauthor-review manuscript from the ignored
# full-analysis package. The renderer uses aggregate artifacts only and does
# not read row-level survey data, open-text responses, timestamps, or contact
# material.

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
activate_project(root)

cli <- parse_cli()
if (length(setdiff(cli$flags, character()))) {
  stop("Unsupported flag(s): ", paste(cli$flags, collapse = ", "))
}

analysis_dir <- option_value(cli, "analysis-dir", default = file.path(root, "reports", "internal", "full-analysis"))
out_dir <- option_value(cli, "out-dir", default = file.path(root, "reports", "internal", "journal-manuscript"))
copy_to <- option_value(cli, "copy-to", default = "")
pdflatex <- Sys.getenv("TA_WIKI_PDFLATEX", unset = Sys.which("pdflatex"))
if (!nzchar(pdflatex) && file.exists("C:/Users/anton/AppData/Local/Programs/MiKTeX/miktex/bin/x64/pdflatex.exe")) {
  pdflatex <- "C:/Users/anton/AppData/Local/Programs/MiKTeX/miktex/bin/x64/pdflatex.exe"
}

normalize_input_path <- function(path, must_work = TRUE) {
  normalizePath(path, winslash = "/", mustWork = must_work)
}
analysis_dir <- normalize_input_path(analysis_dir)
out_dir <- normalize_input_path(out_dir, must_work = FALSE)
if (nzchar(copy_to)) copy_to <- normalize_input_path(copy_to, must_work = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

read_required_csv <- function(...) {
  path <- file.path(...)
  if (!file.exists(path)) stop("Missing required analysis artifact: ", path)
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE, na.strings = "")
}
write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}
as_num <- function(x) suppressWarnings(as.numeric(x))
fmt_pct <- function(x) {
  value <- as_num(x)
  ifelse(is.na(value), "", sprintf("%.1f%%", value))
}
fmt_pct0 <- function(x) {
  value <- as_num(x)
  ifelse(is.na(value), "", sprintf("%.0f%%", value))
}
fmt_ratio0 <- function(n, denominator, percent = NULL) {
  if (is.null(percent)) percent <- 100 * as_num(n) / as_num(denominator)
  paste0(n, "/", denominator, " (", fmt_pct0(percent), ")")
}
fmt_count <- function(n, denominator) paste0(n, " of ", denominator)
sentence_join <- function(parts) {
  parts <- parts[nzchar(parts)]
  if (!length(parts)) return("")
  if (length(parts) == 1L) return(parts)
  if (length(parts) == 2L) return(paste(parts, collapse = " and "))
  paste0(paste(parts[-length(parts)], collapse = ", "), ", and ", parts[[length(parts)]])
}
html_escape <- function(x) {
  x <- ifelse(is.na(x), "", as.character(x))
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x
}
ascii <- function(x) {
  x <- ifelse(is.na(x), "", as.character(x))
  iconv(x, from = "", to = "ASCII//TRANSLIT", sub = "")
}
latex_escape <- function(x) {
  x <- ascii(x)
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  x <- gsub("([#$%&_{}])", "\\\\\\1", x, perl = TRUE)
  x <- gsub("\\^", "\\\\textasciicircum{}", x)
  x <- gsub("~", "\\\\textasciitilde{}", x)
  x
}
md_table <- function(x) {
  x <- as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE)
  x[] <- lapply(x, function(col) ifelse(is.na(col), "", as.character(col)))
  header <- paste("|", paste(names(x), collapse = " | "), "|")
  sep <- paste("|", paste(rep("---", ncol(x)), collapse = " | "), "|")
  rows <- apply(x, 1, function(row) paste("|", paste(gsub("\\|", "/", row), collapse = " | "), "|"))
  c(header, sep, rows)
}
html_table <- function(x) {
  x <- as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE)
  x[] <- lapply(x, function(col) html_escape(ifelse(is.na(col), "", as.character(col))))
  rows <- apply(x, 1, function(row) paste0("<tr><td>", paste(row, collapse = "</td><td>"), "</td></tr>"))
  c(
    "<table>",
    paste0("<thead><tr><th>", paste(html_escape(names(x)), collapse = "</th><th>"), "</th></tr></thead>"),
    "<tbody>",
    rows,
    "</tbody></table>"
  )
}
latex_longtable <- function(x, caption, widths = NULL, size = "\\small") {
  x <- as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE)
  x[] <- lapply(x, function(col) latex_escape(ifelse(is.na(col), "", as.character(col))))
  if (is.null(widths)) widths <- rep(sprintf("%.3f\\textwidth", 0.92 / ncol(x)), ncol(x))
  if (length(widths) != ncol(x)) stop("Longtable width count does not match column count.")
  colspec <- paste0(">{\\raggedright\\arraybackslash}p{", widths, "}")
  align <- paste0("@{}", paste(colspec, collapse = "@{\\hspace{0.012\\textwidth}}"), "@{}")
  out <- c(
    size,
    paste0("\\begin{longtable}{", align, "}"),
    paste0("\\caption{", latex_escape(caption), "}\\\\"),
    "\\toprule",
    paste(latex_escape(names(x)), collapse = " & "), "\\\\",
    "\\midrule",
    "\\endfirsthead",
    "\\toprule",
    paste(latex_escape(names(x)), collapse = " & "), "\\\\",
    "\\midrule",
    "\\endhead"
  )
  if (nrow(x)) {
    for (i in seq_len(nrow(x))) out <- c(out, paste(as.character(x[i, ]), collapse = " & "), "\\\\")
  }
  c(out, "\\bottomrule", "\\end{longtable}", "\\normalsize")
}

latex_table <- function(x, caption, widths = NULL, size = "\\footnotesize") {
  x <- as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE)
  x[] <- lapply(x, function(col) latex_escape(ifelse(is.na(col), "", as.character(col))))
  if (is.null(widths)) widths <- rep(sprintf("%.3f\\textwidth", 0.92 / ncol(x)), ncol(x))
  if (length(widths) != ncol(x)) stop("Table width count does not match column count.")
  colspec <- paste0(">{\\raggedright\\arraybackslash}p{", widths, "}")
  align <- paste0("@{}", paste(colspec, collapse = "@{\\hspace{0.012\\textwidth}}"), "@{}")
  out <- c(
    "\\begin{table}[H]",
    "\\centering",
    "\\renewcommand{\\arraystretch}{1.08}",
    size,
    paste0("\\caption{", latex_escape(caption), "}"),
    paste0("\\begin{tabular}{", align, "}"),
    "\\toprule",
    paste(latex_escape(names(x)), collapse = " & "), "\\\\",
    "\\midrule"
  )
  if (nrow(x)) {
    for (i in seq_len(nrow(x))) out <- c(out, paste(as.character(x[i, ]), collapse = " & "), "\\\\")
  }
  c(out, "\\bottomrule", "\\end{tabular}", "\\normalsize", "\\end{table}")
}

find_executable <- function(candidates) {
  for (candidate in candidates) {
    if (!nzchar(candidate)) next
    is_path <- grepl("/", candidate, fixed = TRUE) ||
      grepl("\\", candidate, fixed = TRUE) ||
      grepl("^[A-Za-z]:", candidate)
    if (is_path && file.exists(candidate)) return(candidate)
    hit <- Sys.which(candidate)
    if (nzchar(hit)) return(hit)
  }
  ""
}

sha256_file <- function(path) {
  if (!file.exists(path)) return("")
  certutil <- find_executable(c("certutil", "C:/Windows/System32/certutil.exe"))
  if (nzchar(certutil)) {
    out <- suppressWarnings(system2(certutil, c("-hashfile", normalizePath(path, winslash = "\\"), "SHA256"), stdout = TRUE, stderr = TRUE))
    hit <- grep("^[0-9A-Fa-f]{64}$", trimws(out), value = TRUE)
    if (length(hit)) return(tolower(hit[[1]]))
  }
  sha256sum <- find_executable(c("sha256sum", "C:/Program Files/Git/usr/bin/sha256sum.exe"))
  if (nzchar(sha256sum)) {
    out <- suppressWarnings(system2(sha256sum, normalizePath(path, winslash = "/", mustWork = TRUE), stdout = TRUE, stderr = TRUE))
    hit <- regmatches(out, regexpr("^[0-9A-Fa-f]{64}", out))
    hit <- hit[nzchar(hit)]
    if (length(hit)) return(tolower(hit[[1]]))
  }
  shasum <- find_executable(c("shasum", "C:/Program Files/Git/usr/bin/shasum.exe"))
  if (nzchar(shasum)) {
    out <- suppressWarnings(system2(shasum, c("-a", "256", normalizePath(path, winslash = "/", mustWork = TRUE)), stdout = TRUE, stderr = TRUE))
    hit <- regmatches(out, regexpr("^[0-9A-Fa-f]{64}", out))
    hit <- hit[nzchar(hit)]
    if (length(hit)) return(tolower(hit[[1]]))
  }
  openssl <- find_executable(c("openssl", "C:/Program Files/Git/usr/bin/openssl.exe"))
  if (nzchar(openssl)) {
    out <- suppressWarnings(system2(openssl, c("dgst", "-sha256", "-r", normalizePath(path, winslash = "/", mustWork = TRUE)), stdout = TRUE, stderr = TRUE))
    hit <- regmatches(out, regexpr("^[0-9A-Fa-f]{64}", out))
    hit <- hit[nzchar(hit)]
    if (length(hit)) return(tolower(hit[[1]]))
  }
  stop("No SHA-256 implementation available for: ", path)
}
rel_path <- function(path, base) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  base <- paste0(normalizePath(base, winslash = "/", mustWork = FALSE), "/")
  if (startsWith(path, base)) substring(path, nchar(base) + 1L) else path
}
git_executable <- function() find_executable(c("git", "C:/Program Files/Git/cmd/git.exe", "C:/Program Files/Git/bin/git.exe"))
git_value <- function(args) {
  git <- git_executable()
  if (!nzchar(git)) return("")
  out <- suppressWarnings(system2(git, c("-C", root, args), stdout = TRUE, stderr = FALSE))
  if (!length(out)) "" else trimws(out[[1]])
}
git_status_short <- function() {
  git <- git_executable()
  if (!nzchar(git)) return("")
  out <- suppressWarnings(system2(git, c("-C", root, "status", "--short"), stdout = TRUE, stderr = FALSE))
  paste(out, collapse = "\n")
}

tables_dir <- file.path(analysis_dir, "tables")
summary_labeled <- read_required_csv(tables_dir, "quantitative-structured-summary-labeled.csv")
item_completeness <- read_required_csv(tables_dir, "quantitative-item-completeness.csv")
cohort_flow <- read_required_csv(tables_dir, "quantitative-cohort-flow.csv")
contribution_sensitivity <- read_required_csv(tables_dir, "quantitative-contribution-sensitivity.csv")

primary <- summary_labeled[summary_labeled$analysis_variant == "primary", , drop = FALSE]
primary$n_num <- as_num(primary$n)
primary$denominator_num <- as_num(primary$denominator)
primary$percent_num <- as_num(primary$percent)
primary$display_order_num <- as_num(primary$display_order)
primary <- primary[order(primary$item, primary$display_order_num), ]

cohort_n <- cohort_flow$n[cohort_flow$stage == "analytic_cohort_records"]
if (!length(cohort_n)) cohort_n <- max(as_num(primary$eligible_n), na.rm = TRUE)
cohort_n <- as.integer(cohort_n[[1]])

find_response <- function(item, pattern, exact = FALSE, variant = "primary") {
  rows <- primary[primary$item == item & primary$analysis_variant == variant, , drop = FALSE]
  if (exact) {
    rows <- rows[rows$response == pattern, , drop = FALSE]
  } else {
    rows <- rows[grepl(pattern, rows$response, fixed = TRUE), , drop = FALSE]
  }
  if (nrow(rows) != 1L) stop("Expected one response row for item=", item, " pattern=", pattern, "; found ", nrow(rows))
  rows[1, , drop = FALSE]
}
item_completeness_row <- function(item) {
  row <- item_completeness[item_completeness$item == item, , drop = FALSE]
  if (nrow(row) != 1L) stop("Expected one completeness row for item=", item, "; found ", nrow(row))
  row[1, , drop = FALSE]
}
missing_boundary <- function(item) {
  row <- item_completeness_row(item)
  missing <- as.integer(as_num(row$missing_n))
  invalid <- as.integer(as_num(row$invalid_n))
  notes <- character()
  if (!is.na(missing) && missing > 0) notes <- c(notes, paste0(missing, " missing"))
  if (!is.na(invalid) && invalid > 0) notes <- c(notes, paste0(invalid, " invalid"))
  if (!length(notes)) return("All eligible records had valid responses for this item.")
  paste0("Interpret with the item-specific denominator; ", paste(notes, collapse = " and "), " response(s) were not included in the denominator.")
}
missing_invalid_text <- function(item) {
  row <- item_completeness_row(item)
  paste0(row$missing_n, " missing; ", row$invalid_n, " invalid")
}
metric_from_row <- function(row) {
  n <- as_num(row$n)
  denominator <- as_num(row$denominator)
  percent <- as_num(row$percent)
  list(
    row = row,
    n = n,
    denominator = denominator,
    percent = percent,
    table = fmt_ratio0(n, denominator, percent),
    prose = fmt_count(n, denominator),
    percent0 = fmt_pct0(percent)
  )
}
metric <- function(item, pattern, exact = FALSE) metric_from_row(find_response(item, pattern, exact = exact))
combined_metric <- function(item, patterns, label) {
  rows <- do.call(rbind, lapply(patterns, function(pattern) find_response(item, pattern)))
  denominator <- unique(rows$denominator)
  missing <- unique(rows$missing_n)
  invalid <- unique(rows$invalid_n)
  if (length(denominator) != 1L) stop("Combined metric has more than one denominator for item=", item)
  n <- sum(as_num(rows$n))
  percent <- 100 * n / as_num(denominator)
  list(
    label = label,
    item = item,
    source_response = paste(rows$response, collapse = " + "),
    n = n,
    denominator = as_num(denominator),
    percent = percent,
    missing_n = as_num(missing[[1]]),
    invalid_n = as_num(invalid[[1]]),
    table = fmt_ratio0(n, denominator, percent),
    prose = fmt_count(n, denominator),
    percent0 = fmt_pct0(percent)
  )
}
agree_metric <- function(item, label) combined_metric(item, c("Strongly agree", "Agree"), label)
sensitivity_metric <- function(variant, response) {
  row <- contribution_sensitivity[contribution_sensitivity$analysis_variant == variant & contribution_sensitivity$response == response, , drop = FALSE]
  if (nrow(row) != 1L) stop("Expected one contribution sensitivity row for variant=", variant, " response=", response)
  metric_from_row(row)
}

claim_row <- function(claim_id, claim_group, manuscript_section, claim_type, claim_text,
                      source_artifact, source_item, source_response, n, denominator,
                      percent, missing_n, invalid_n, analysis_variant = "primary",
                      release_status = "internal_review_only", verification_status = "aggregate_checked",
                      interpretation_boundary = "Describes the observed survey records; no population or causal claim.",
                      manuscript_location = manuscript_section, claim_class = claim_type,
                      parent_claim_id = "", routing_required = "no", raw_review_required = "no",
                      source_row_key = "", manuscript_profile = "structured_only_internal_coauthor_draft",
                      coauthor_status = "pending_review") {
  source_path <- file.path(analysis_dir, source_artifact)
  if (!nzchar(source_row_key)) {
    source_row_key <- paste(c(analysis_variant, source_item, source_response), collapse = "|")
  }
  data.frame(
    claim_id = claim_id,
    claim_group = claim_group,
    manuscript_section = manuscript_section,
    manuscript_location = manuscript_location,
    claim_type = claim_type,
    claim_class = claim_class,
    claim_text = claim_text,
    parent_claim_id = parent_claim_id,
    source_artifact = source_artifact,
    bundle_relative_source = sub("^tables/", "aggregate-data/", source_artifact),
    source_sha256 = sha256_file(source_path),
    source_item = source_item,
    source_response = source_response,
    source_row_key = source_row_key,
    analysis_variant = analysis_variant,
    n = as.character(n),
    denominator = as.character(denominator),
    percent = fmt_pct(percent),
    missing_n = as.character(missing_n),
    invalid_n = as.character(invalid_n),
    routing_required = routing_required,
    raw_review_required = raw_review_required,
    release_status = release_status,
    verification_status = verification_status,
    manuscript_profile = manuscript_profile,
    coauthor_status = coauthor_status,
    interpretation_boundary = interpretation_boundary,
    stringsAsFactors = FALSE
  )
}
quant_claim <- function(claim_id, group, section, item, pattern, claim_text, exact = FALSE,
                        claim_type = "descriptive", boundary = NULL) {
  m <- metric(item, pattern, exact = exact)
  row <- m$row
  if (is.null(boundary)) boundary <- missing_boundary(item)
  claim_row(
    claim_id, group, section, claim_type, claim_text(m),
    "tables/quantitative-structured-summary-labeled.csv", item, row$response,
    row$n, row$denominator, row$percent, row$missing_n, row$invalid_n,
    interpretation_boundary = boundary
  )
}
combined_claim <- function(claim_id, group, section, item, patterns, label, claim_text,
                           claim_type = "descriptive", boundary = NULL) {
  combo <- combined_metric(item, patterns, label)
  if (is.null(boundary)) boundary <- missing_boundary(item)
  claim_row(
    claim_id, group, section, claim_type, claim_text(combo),
    "tables/quantitative-structured-summary-labeled.csv", item, combo$source_response,
    combo$n, combo$denominator, combo$percent, combo$missing_n, combo$invalid_n,
    interpretation_boundary = boundary
  )
}
sensitivity_claim <- function(claim_id, response, claim_text) {
  variant <- "sensitivity_inferred_from_valid_reason"
  row <- contribution_sensitivity[contribution_sensitivity$analysis_variant == variant & contribution_sensitivity$response == response, , drop = FALSE]
  claim_row(
    claim_id, "Contribution", "Supplement", "sensitivity", claim_text,
    "tables/quantitative-contribution-sensitivity.csv", "contributed", response,
    row$n, row$denominator, row$percent, row$missing_n, row$invalid_n,
    analysis_variant = variant,
    manuscript_location = "Internal supplement",
    claim_class = "secondary_sensitivity",
    routing_required = "yes",
    raw_review_required = "yes",
    interpretation_boundary = "Secondary internal reason-informed diagnostic only; routing for the reason item remains unverified."
  )
}
interpretive_claim <- function(claim_id, group, location, claim_text, evidence_ids,
                               claim_class = "comparative_interpretation",
                               interpretation_boundary = "Interpretive synthesis of structured descriptive claims; not a causal or population-level claim.") {
  claim_row(
    claim_id, group, location, "interpretive", claim_text,
    "tables/quantitative-structured-summary-labeled.csv", "", evidence_ids,
    "", "", "", "", "",
    manuscript_location = location,
    claim_class = claim_class,
    source_row_key = evidence_ids,
    verification_status = "evidence_ids_checked",
    interpretation_boundary = interpretation_boundary
  )
}

metric_peer <- metric("current_resources", "Advice from other grad students in Stats")
metric_faculty <- metric("current_resources", "Advice from the course instructor or faculty")
metric_online <- metric("current_resources", "Online resources")
metric_ta_wiki_current <- metric("current_resources", "The TA Wiki", exact = TRUE)
metric_course <- metric("desired_features", "Course-specific tips from previous TAs")
metric_rubrics <- metric("desired_features", "Grading rubrics and examples")
metric_activities <- metric("desired_features", "Lesson plans or activity ideas")
metric_templates <- metric("desired_features", "Templates")
metric_awareness <- combined_metric("wiki_awareness", c("Yes", "heard of it"), "aware_or_heard")
metric_visited <- combined_metric("wiki_visited", c("Yes, multiple times", "Yes, once or twice"), "visited_any")
metric_never_consult <- metric("consult_frequency", "Never")
metric_rarely_consult <- metric("consult_frequency", "Rarely")
metric_sometimes_consult <- metric("consult_frequency", "Sometimes")
metric_needs_very_complete <- combined_metric("needs_met", c("Very well", "Completely"), "needs_very_or_complete")
metric_needs_moderate <- metric("needs_met", "Moderately")
metric_needs_not_used <- metric("needs_met", "haven't used")
metric_contributed_yes <- metric("contributed", "Yes", exact = TRUE)
metric_contributed_no <- metric("contributed", "No", exact = TRUE)
metric_sens_yes <- sensitivity_metric("sensitivity_inferred_from_valid_reason", "Yes")
metric_sens_no <- sensitivity_metric("sensitivity_inferred_from_valid_reason", "No")
metric_understand <- agree_metric("understand_contribution", "understand_agree")
metric_straightforward <- agree_metric("contribution_straightforward", "straightforward_agree")
metric_simpler <- agree_metric("simpler_interface", "simpler_agree")
metric_training <- agree_metric("training_walkthrough", "training_agree")
metric_github_use_none <- metric("github_use_effect", "It makes no difference to me")
metric_github_use_more <- metric("github_use_effect", "more likely to use it")
metric_github_use_less <- metric("github_use_effect", "less likely to use it")
metric_github_contrib_none <- metric("github_contribution_effect", "It makes no difference")
metric_github_contrib_more <- metric("github_contribution_effect", "more likely to contribute")
metric_github_contrib_less <- metric("github_contribution_effect", "less likely to contribute")
metric_github_version <- metric("github_advantages", "Version control")
metric_github_transparency <- metric("github_advantages", "Transparency")
metric_github_learning <- metric("github_disadvantages", "Steep learning curve")
metric_github_setup <- metric("github_disadvantages", "Requires technical setup")
metric_github_formal <- metric("github_disadvantages", "overly formal")
metric_editathon_nonpart <- metric("editathon_awareness", "Yes, but I did not participate")
metric_editathon_part <- metric("editathon_awareness", "Yes, and I participated")
metric_value <- agree_metric("wiki_value", "wiki_value_agree")
metric_recommend <- agree_metric("recommend_wiki", "recommend_agree")
metric_maintain <- agree_metric("maintain_wiki", "maintain_agree")
metric_ownership_agree <- agree_metric("wiki_ownership", "ownership_agree")
metric_ownership_neutral <- metric("wiki_ownership", "Neutral", exact = TRUE)
metric_ownership_disagree <- combined_metric("wiki_ownership", c("Strongly disagree", "Disagree"), "ownership_disagree")
metric_ta_experience <- metric("ta_quarters", "5 or more quarters")
metric_git_comfort <- combined_metric("git_comfort", c("Moderately comfortable", "Very comfortable", "Expert"), "git_moderate_or_higher")
metric_teaching_interest <- combined_metric("teaching_interest", c("Moderately interested", "Very interested", "Extremely interested"), "teaching_interest_moderate_or_higher")
metric_program_year <- combined_metric("program_year", c("2nd year", "3rd year", "4th year"), "program_second_or_later")

contribution_missing_n <- as.integer(as_num(item_completeness_row("contributed")$missing_n))
contribution_bound_low <- as.integer(metric_contributed_yes$n)
contribution_bound_high <- contribution_bound_low + contribution_missing_n
contribution_bound_text <- paste0(contribution_bound_low, "-", contribution_bound_high, " of ", cohort_n)
contribution_direct_text <- paste0("Yes ", as.integer(metric_contributed_yes$n), "; no ", as.integer(metric_contributed_no$n), "; missing ", contribution_missing_n)
contribution_reason_informed_text <- paste0("Yes ", as.integer(metric_sens_yes$n), "; no ", as.integer(metric_sens_no$n), "; missing 1")
plain_ratio <- function(m) paste0(as.integer(m$n), "/", as.integer(m$denominator))

ledger <- do.call(rbind, list(
  claim_row("C001", "Survey-record context", "Methods/Table 1", "descriptive", paste0("Analytic cohort records: ", cohort_n, "."),
            "tables/quantitative-cohort-flow.csv", "analytic_cohort_records", "analytic_cohort_records", cohort_n, "", "", "", "",
            source_row_key = "analytic_cohort_records", manuscript_location = "Methods; Table 1"),
  quant_claim("C002", "Survey-record context", "Results/Table 1", "ta_quarters", "5 or more quarters", function(m) paste0("Survey records reporting five or more quarters as a departmental TA: ", m$table, ".")),
  combined_claim("C003", "Survey-record context", "Results/Table 1", "git_comfort", c("Moderately comfortable", "Very comfortable", "Expert"), "git_moderate_or_higher", function(m) paste0("Survey records reporting at least moderate Git/GitHub comfort: ", m$table, ".")),
  combined_claim("C004", "Survey-record context", "Results/Table 1", "teaching_interest", c("Moderately interested", "Very interested", "Extremely interested"), "teaching_interest_moderate_or_higher", function(m) paste0("Survey records reporting at least moderate interest in developing teaching skills: ", m$table, ".")),
  quant_claim("C005", "Resource context", "Supplement", "current_resources", "Advice from other grad students in Stats", function(m) paste0("Graduate-student peer advice was selected by ", m$table, ".")),
  quant_claim("C006", "Resource context", "Supplement", "current_resources", "Advice from the course instructor or faculty", function(m) paste0("Instructor or faculty advice was selected by ", m$table, ".")),
  quant_claim("C007", "Resource context", "Supplement", "current_resources", "Online resources", function(m) paste0("Online resources were selected by ", m$table, ".")),
  quant_claim("C008", "Resource context", "Results/Table 2", "current_resources", "The TA Wiki", function(m) paste0("The TA Wiki was selected as a current teaching-support resource by ", m$table, "."), exact = TRUE),
  quant_claim("C009", "Desired resource features", "Results/Supplement", "desired_features", "Course-specific tips from previous TAs", function(m) paste0("Course-specific tips were selected by ", m$table, "."), boundary = missing_boundary("desired_features")),
  quant_claim("C010", "Desired resource features", "Results/Supplement", "desired_features", "Grading rubrics and examples", function(m) paste0("Grading rubrics/examples were selected by ", m$table, "."), boundary = missing_boundary("desired_features")),
  quant_claim("C011", "Desired resource features", "Results/Supplement", "desired_features", "Lesson plans or activity ideas", function(m) paste0("Lesson/activity ideas were selected by ", m$table, "."), boundary = missing_boundary("desired_features")),
  quant_claim("C012", "Desired resource features", "Results/Supplement", "desired_features", "Templates", function(m) paste0("Templates were selected by ", m$table, "."), boundary = missing_boundary("desired_features")),
  combined_claim("C013", "Awareness and use", "Results/Table 2", "wiki_awareness", c("Yes", "heard of it"), "aware_or_heard", function(m) paste0("Survey records with at least some awareness of the TA Wiki: ", m$table, ".")),
  combined_claim("C014", "Awareness and use", "Results/Table 2", "wiki_visited", c("Yes, multiple times", "Yes, once or twice"), "visited_any", function(m) paste0("Survey records reporting at least one prior Wiki visit: ", m$table, ".")),
  quant_claim("C015", "Awareness and use", "Results/Table 2", "consult_frequency", "Never", function(m) paste0("Valid consultation-frequency responses selecting never: ", m$table, "."), boundary = missing_boundary("consult_frequency")),
  quant_claim("C016", "Awareness and use", "Results/Table 2", "consult_frequency", "Rarely", function(m) paste0("Valid consultation-frequency responses selecting rarely: ", m$table, "."), boundary = missing_boundary("consult_frequency")),
  quant_claim("C017", "Awareness and use", "Results/Table 2", "consult_frequency", "Sometimes", function(m) paste0("Valid consultation-frequency responses selecting sometimes: ", m$table, "."), boundary = missing_boundary("consult_frequency")),
  combined_claim("C018", "Needs met", "Supplement", "needs_met", c("Very well", "Completely"), "needs_very_or_complete", function(m) paste0("Valid needs-met responses selecting very well or completely: ", m$table, "."), boundary = missing_boundary("needs_met")),
  quant_claim("C019", "Needs met", "Supplement", "needs_met", "Moderately", function(m) paste0("Valid needs-met responses selecting moderately: ", m$table, "."), boundary = missing_boundary("needs_met")),
  quant_claim("C020", "Needs met", "Supplement", "needs_met", "haven't used", function(m) paste0("Valid needs-met responses reporting insufficient use to say: ", m$table, "."), boundary = missing_boundary("needs_met")),
  combined_claim("C021", "Value and maintenance", "Results/Table 2", "wiki_value", c("Strongly agree", "Agree"), "wiki_value_agree", function(m) paste0("Survey records agreeing or strongly agreeing that the Wiki is or could be valuable: ", m$table, ".")),
  combined_claim("C022", "Value and maintenance", "Results/Table 2", "recommend_wiki", c("Strongly agree", "Agree"), "recommend_agree", function(m) paste0("Survey records agreeing or strongly agreeing that they would recommend the Wiki: ", m$table, ".")),
  combined_claim("C023", "Value and maintenance", "Results/Table 2", "maintain_wiki", c("Strongly agree", "Agree"), "maintain_agree", function(m) paste0("Survey records agreeing or strongly agreeing that the Wiki should be maintained: ", m$table, ".")),
  quant_claim("C024", "Contribution", "Results/Table 2", "contributed", "Yes", function(m) paste0("Valid direct contribution responses that were yes: ", m$table, "."), exact = TRUE, boundary = missing_boundary("contributed")),
  quant_claim("C025", "Contribution", "Results/Table 2", "contributed", "No", function(m) paste0("Valid direct contribution responses that were no: ", m$table, "."), exact = TRUE, boundary = missing_boundary("contributed")),
  interpretive_claim("C026", "Contribution", "Results/Table 2", paste0("With three missing direct responses unresolved, the number reporting prior contribution could range from ", contribution_bound_text, "."), "C024+C025", claim_class = "missing_response_bound", interpretation_boundary = "Deterministic full-cohort bound from extreme assignments of missing direct responses; not a confidence interval."),
  sensitivity_claim("C027", "Yes", paste0("Under the internal reason-informed diagnostic, the yes count was ", metric_sens_yes$table, ".")),
  sensitivity_claim("C028", "No", paste0("Under the internal reason-informed diagnostic, the no count was ", metric_sens_no$table, ".")),
  combined_claim("C029", "Contribution process", "Results/Table 2", "understand_contribution", c("Strongly agree", "Agree"), "understand_agree", function(m) paste0("Survey records agreeing or strongly agreeing that they understood how to contribute: ", m$table, ".")),
  combined_claim("C030", "Contribution process", "Results/Table 2", "contribution_straightforward", c("Strongly agree", "Agree"), "straightforward_agree", function(m) paste0("Survey records agreeing or strongly agreeing that the contribution process is straightforward: ", m$table, ".")),
  combined_claim("C031", "Contribution process", "Results/Table 2", "simpler_interface", c("Strongly agree", "Agree"), "simpler_agree", function(m) paste0("Survey records agreeing or strongly agreeing that a simpler interface would increase willingness to contribute: ", m$table, ".")),
  combined_claim("C032", "Contribution process", "Results/Table 2", "training_walkthrough", c("Strongly agree", "Agree"), "training_agree", function(m) paste0("Survey records agreeing or strongly agreeing that training or a walkthrough would increase willingness to contribute: ", m$table, ".")),
  quant_claim("C033", "GitHub perceptions", "Results/Supplement", "github_use_effect", "It makes no difference to me", function(m) paste0("For willingness to use the Wiki, no difference was reported by ", m$table, ".")),
  quant_claim("C034", "GitHub perceptions", "Results/Supplement", "github_use_effect", "more likely to use it", function(m) paste0("For willingness to use the Wiki, greater willingness was reported by ", m$table, ".")),
  quant_claim("C035", "GitHub perceptions", "Results/Supplement", "github_use_effect", "less likely to use it", function(m) paste0("For willingness to use the Wiki, lower willingness was reported by ", m$table, ".")),
  quant_claim("C036", "GitHub perceptions", "Results/Supplement", "github_contribution_effect", "It makes no difference", function(m) paste0("For willingness to contribute, no difference was reported by ", m$table, ".")),
  quant_claim("C037", "GitHub perceptions", "Results/Supplement", "github_contribution_effect", "more likely to contribute", function(m) paste0("For willingness to contribute, greater willingness was reported by ", m$table, ".")),
  quant_claim("C038", "GitHub perceptions", "Results/Supplement", "github_contribution_effect", "less likely to contribute", function(m) paste0("For willingness to contribute, lower willingness was reported by ", m$table, ".")),
  quant_claim("C039", "GitHub perceptions", "Supplement", "github_advantages", "Version control", function(m) paste0("Version control was selected as a GitHub advantage by ", m$table, "."), boundary = missing_boundary("github_advantages")),
  quant_claim("C040", "GitHub perceptions", "Supplement", "github_advantages", "Transparency", function(m) paste0("Transparency was selected as a GitHub advantage by ", m$table, "."), boundary = missing_boundary("github_advantages")),
  quant_claim("C041", "GitHub perceptions", "Supplement", "github_disadvantages", "Steep learning curve", function(m) paste0("A steep learning curve was selected as a GitHub disadvantage by ", m$table, "."), boundary = missing_boundary("github_disadvantages")),
  quant_claim("C042", "GitHub perceptions", "Supplement", "github_disadvantages", "Requires technical setup", function(m) paste0("Technical setup was selected as a GitHub disadvantage by ", m$table, "."), boundary = missing_boundary("github_disadvantages")),
  quant_claim("C043", "GitHub perceptions", "Supplement", "github_disadvantages", "overly formal", function(m) paste0("An overly formal contribution process was selected as a GitHub disadvantage by ", m$table, "."), boundary = missing_boundary("github_disadvantages")),
  quant_claim("C044", "Editathon", "Results", "editathon_awareness", "Yes, but I did not participate", function(m) paste0("Survey records reporting editathon awareness without participation: ", m$table, ".")),
  quant_claim("C045", "Editathon", "Results", "editathon_awareness", "Yes, and I participated", function(m) paste0("Survey records reporting editathon participation: ", m$table, ".")),
  combined_claim("C046", "Maintenance", "Supplement", "wiki_ownership", c("Strongly agree", "Agree"), "ownership_agree", function(m) paste0("Survey records agreeing or strongly agreeing with a sense of Wiki ownership: ", m$table, ".")),
  quant_claim("C047", "Maintenance", "Supplement", "wiki_ownership", "Neutral", function(m) paste0("Survey records neutral on Wiki ownership: ", m$table, "."), exact = TRUE),
  combined_claim("C048", "Maintenance", "Supplement", "wiki_ownership", c("Strongly disagree", "Disagree"), "ownership_disagree", function(m) paste0("Survey records disagreeing or strongly disagreeing with a sense of Wiki ownership: ", m$table, ".")),
  interpretive_claim("C049", "Central interpretation", "Discussion", "Potential value was endorsed more uniformly than current selection or consultation of the Wiki.", "C008+C015+C016+C017+C021"),
  interpretive_claim("C050", "Implementation implication", "Discussion", "Lower-friction contribution routes are candidate pilots rather than established effective interventions.", "C029+C030+C031+C032", claim_class = "recommendation", interpretation_boundary = "Implementation recommendation generated from descriptive structured responses; effect must be tested prospectively."),
  interpretive_claim("C051", "Implementation implication", "Discussion", "Desired features of a departmental teaching resource are candidate Wiki features to test, not direct evidence of requested Wiki changes.", "C009+C010+C011+C012", claim_class = "recommendation", interpretation_boundary = "Desired-feature item concerned a general departmental teaching resource.")
))
write_csv(ledger, file.path(out_dir, "journal-claim-ledger.csv"))

main_table_context <- data.frame(
  Characteristic = c(
    "Analytic records",
    "TA experience",
    "Git/GitHub comfort",
    "Teaching development interest"
  ),
  Result = c(
    as.character(cohort_n),
    paste0(plain_ratio(metric_ta_experience), " reported at least five quarters"),
    paste0(plain_ratio(metric_git_comfort), " reported at least moderate comfort"),
    paste0(plain_ratio(metric_teaching_interest), " reported at least moderate interest")
  ),
  `Interpretive note` = c(
    "Eligible and consenting according to the aggregate cohort flow.",
    "Survey-record context only.",
    "The survey-record group contained relatively few reports of low Git/GitHub comfort; the department-wide distribution is unknown.",
    "Survey-record context only."
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

main_table_indicators <- data.frame(
  Domain = c(
    "Current use",
    "Awareness",
    "Visitation",
    "Consultation",
    "Potential value",
    "Recommendation",
    "Maintenance",
    "Contribution",
    "Contribution range",
    "Process",
    "Process"
  ),
  Indicator = c(
    "TA Wiki selected as current resource",
    "At least heard of the Wiki",
    "Visited at least once",
    "Never / rarely / sometimes",
    "Agree or strongly agree",
    "Agree or strongly agree",
    "Agree or strongly agree",
    "Direct Yes / No / missing",
    "Possible Yes count",
    "Understand / straightforward",
    "Simpler interface / training would help"
  ),
  Result = c(
    plain_ratio(metric_ta_wiki_current),
    plain_ratio(metric_awareness),
    plain_ratio(metric_visited),
    paste0(plain_ratio(metric_never_consult), "; ", plain_ratio(metric_rarely_consult), "; ", plain_ratio(metric_sometimes_consult)),
    plain_ratio(metric_value),
    plain_ratio(metric_recommend),
    plain_ratio(metric_maintain),
    contribution_direct_text,
    gsub("-", " to ", contribution_bound_text, fixed = TRUE),
    paste0(plain_ratio(metric_understand), "; ", plain_ratio(metric_straightforward)),
    paste0(plain_ratio(metric_simpler), "; ", plain_ratio(metric_training))
  ),
  Note = c(
    "Multiple-selection current-resource item; does not measure consultation frequency.",
    "Includes one record indicating limited awareness.",
    "A prior visit is not reported consultation.",
    "Three missing responses.",
    "Item says is or could be valuable.",
    "Two neutral; two unsure.",
    "Preference, not sustainability evidence.",
    "Direct item is primary.",
    "Extreme-case deterministic missing-response range; not a confidence interval.",
    "Separate direct items.",
    "Hypothetical willingness items, not observed behavior."
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

supplemental_indicators <- data.frame(
  Domain = c(
    "Current resources", "Current resources", "Current resources",
    "Desired features", "Desired features", "Desired features", "Desired features",
    "Needs met", "Needs met", "Needs met",
    "GitHub use effect", "GitHub use effect", "GitHub use effect",
    "GitHub contribution effect", "GitHub contribution effect", "GitHub contribution effect",
    "GitHub advantages", "GitHub advantages",
    "GitHub disadvantages", "GitHub disadvantages", "GitHub disadvantages",
    "Editathon", "Editathon",
    "Ownership", "Ownership", "Ownership",
    "Reason-informed scenario"
  ),
  Indicator = c(
    "Peer advice", "Instructor/faculty advice", "Online resources",
    "Course-specific tips", "Rubrics/examples", "Lesson or activity ideas", "Templates",
    "Very well or complete", "Moderate", "Insufficient use to say",
    "No difference", "More likely", "Less likely",
    "No difference", "More likely", "Less likely",
    "Version control", "Transparency",
    "Steep learning curve", "Technical setup", "Overly formal process",
    "Aware/no participation", "Participated",
    "Agree/strongly agree", "Neutral", "Disagree/strongly disagree",
    "Yes / No / missing"
  ),
  Result = c(
    metric_peer$table, metric_faculty$table, metric_online$table,
    metric_course$table, metric_rubrics$table, metric_activities$table, metric_templates$table,
    metric_needs_very_complete$table, metric_needs_moderate$table, metric_needs_not_used$table,
    metric_github_use_none$table, metric_github_use_more$table, metric_github_use_less$table,
    metric_github_contrib_none$table, metric_github_contrib_more$table, metric_github_contrib_less$table,
    metric_github_version$table, metric_github_transparency$table,
    metric_github_learning$table, metric_github_setup$table, metric_github_formal$table,
    metric_editathon_nonpart$table, metric_editathon_part$table,
    metric_ownership_agree$table, metric_ownership_neutral$table, metric_ownership_disagree$table,
    contribution_reason_informed_text
  ),
  Note = c(
    rep("Multiple-selection current-resource item.", 3),
    rep("Desired features of a general departmental teaching resource; two invalid responses.", 4),
    rep("Item-specific denominator; three missing responses.", 3),
    rep("Perception item; no platform effect estimate.", 6),
    rep("Multiple-selection item; one invalid response.", 5),
    rep("Direct editathon-awareness item.", 2),
    rep("Sense-of-ownership item; not a governance assignment.", 3),
    "Secondary scenario only; reclassifies missing direct responses as No when a valid noncontribution-reason response exists; routing remains unverified."
  ),
  `Evidence profile` = c(
    rep("structured_supplement", 3),
    rep("structured_supplement", 4),
    rep("structured_supplement", 3),
    rep("structured_supplement", 6),
    rep("structured_supplement", 5),
    rep("structured_supplement", 2),
    rep("structured_supplement", 3),
    "restricted_diagnostic"
  ),
  `Routing status` = c(
    rep("direct_or_unconditional_item", 3),
    rep("direct_or_unconditional_item", 4),
    rep("routing_unverified_for_related_reason_item", 3),
    rep("direct_or_unconditional_item", 6),
    rep("direct_or_unconditional_item", 5),
    rep("direct_or_unconditional_item", 2),
    rep("direct_or_unconditional_item", 3),
    "routing_unverified"
  ),
  `Release status` = c(
    rep("coauthor_review_exact_count", 3),
    rep("coauthor_review_exact_count", 4),
    rep("coauthor_review_exact_count", 3),
    rep("coauthor_review_exact_count", 6),
    rep("coauthor_review_exact_count", 5),
    rep("coauthor_review_exact_count", 2),
    rep("coauthor_review_exact_count", 3),
    "internal_only_not_manuscript_evidence"
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

write_csv(main_table_context, file.path(out_dir, "main-table-survey-record-context.csv"))
write_csv(main_table_indicators, file.path(out_dir, "main-table-engagement-indicators.csv"))
write_csv(supplemental_indicators, file.path(out_dir, "supplemental-structured-indicators.csv"))
unlink(
  file.path(out_dir, c(
    "main-table-analysis-boundary.csv",
    "main-table-core-findings.csv",
    "main-table-qualitative-themes.csv",
    "main-table-respondent-context.csv"
  )),
  force = TRUE
)

appendix_completeness <- item_completeness[, c("domain_label", "publication_label", "eligible_n", "observed_valid_n", "missing_n", "invalid_n", "structural_skip_n", "denominator")]
names(appendix_completeness) <- c("Domain", "Item", "Eligible", "Valid", "Missing", "Invalid", "Structural skips", "Denominator")
appendix_full <- primary[, c("domain_label", "item", "publication_label", "response", "n", "denominator", "percent", "missing_n", "invalid_n")]
names(appendix_full) <- c("Domain", "Item ID", "Item", "Response", "n", "N", "Percent", "Missing", "Invalid")
appendix_full$Percent <- fmt_pct0(appendix_full$Percent)
conditional_or_diagnostic_items <- c(
  "needs_reason",
  "noncontribution_reasons",
  "editathon_nonparticipant_reasons",
  "editathon_experience",
  "editathon_improvement"
)
appendix_full$`Evidence profile` <- ifelse(
  appendix_full$`Item ID` %in% conditional_or_diagnostic_items,
  "restricted_diagnostic",
  "structured_supplement"
)
appendix_full$`Routing status` <- ifelse(
  appendix_full$`Item ID` %in% conditional_or_diagnostic_items,
  "routing_unverified",
  "direct_or_unconditional_item"
)
appendix_full$`Release status` <- ifelse(
  appendix_full$`Item ID` %in% conditional_or_diagnostic_items,
  "internal_only_not_manuscript_evidence",
  "coauthor_review_exact_count"
)
appendix_contribution <- data.frame(
  Classification = c("Direct item", "Extreme-case deterministic missing-response range", "Internal reason-informed diagnostic"),
  Result = c(
    contribution_direct_text,
    paste0("Possible Yes count: ", contribution_bound_text),
    contribution_reason_informed_text
  ),
  Assumption = c(
    "No classification of missing direct responses.",
    "All three missing direct responses are assigned to No for the lower bound and Yes for the upper bound.",
    "A missing direct response is reclassified as No when a valid noncontribution-reason response is present."
  ),
  Status = c(
    "Primary contribution summary.",
    "Principal sensitivity because it does not require conditional-item routing.",
    "Secondary internal scenario; routing for the reason item remains unverified."
  ),
  stringsAsFactors = FALSE
)

manuscript_title <- "Awareness, Use, and Contribution in a Departmental TA Wiki: A Descriptive Survey"
author_lines <- c(
  "Antonio Aguirre -- University of California, Santa Cruz",
  "Andrew Le -- University of California, Santa Cruz",
  "Marcela Alfaro-Córdoba -- University of California, Santa Cruz"
)
author_line <- paste(author_lines, collapse = "; ")
version_date <- paste0("Manuscript version: ", format(as.Date(Sys.time(), tz = "UTC"), "%Y-%m-%d"))

abstract <- paste0(
  "This brief departmental evaluation examined awareness, use, contribution, and perceived value of a teaching-assistant (TA) Wiki using ", cohort_n, " survey records classified as eligible and consenting under the project's cohort rules. ",
  "Structured items were summarized with counts and item-specific valid-response denominators; missing and invalid responses were reported separately. ",
  "No response rate or department-wide prevalence estimate was calculated because a verified invitation denominator and final eligible sampling frame were unavailable. ",
  "Four of 12 records selected the Wiki as a current teaching-support resource, all 12 indicated at least some awareness, and 9 reported a prior visit. ",
  "Among 9 valid consultation-frequency responses, 4 selected never, 2 rarely, and 3 sometimes. ",
  "The direct contribution item yielded 5 Yes, 4 No, and 3 missing responses. Assigning all three missing responses to No or all three to Yes gives a possible contributor count of 5 to 8 among the 12 records. ",
  "Eight of 12 agreed that a simpler interface would increase willingness to contribute. All 12 agreed that the Wiki is or could be valuable, 8 agreed that they would recommend it, and 11 supported continued maintenance. ",
  "Potential value was therefore endorsed more consistently than current-resource selection, reported consultation, or complete direct contribution status. These results describe the observed records only and support prospective local testing rather than claims of effectiveness."
)

intro <- c(
  "Graduate-student teaching knowledge often circulates through local, informal, and course-specific channels. Advice from peers, instructors, prior teaching assistants, orientation materials, and online sources can all help teaching assistants prepare for classroom, grading, office-hour, and communication responsibilities. Recent reviews of graduate-teaching-assistant professional development emphasize departmental support, peer networks, pedagogical training, and sustainable structures rather than one-time information delivery alone (Sadera et al., 2024; Freeman et al., 2026).",
  "A departmental TA Wiki is one possible local response to that problem. It can collect course-specific advice, reusable teaching materials, recurring procedures, and links to departmental or university resources. Its usefulness depends on more than awareness: potential users must be able to find relevant content, judge it useful, and understand how contribution and maintenance work. The sustainability and accessibility concerns are consistent with broader guidance for shared educational resources, while the present project remains a local departmental implementation rather than an evaluation of open educational resources in general (UNESCO, 2019).",
  "The platform used to host the Wiki is part of the implementation question. GitHub can support transparent version history and distributed editing, but it can also make consultation or first-time contribution feel technical. The relevant descriptive question is how the survey records described awareness, use, contribution, and GitHub-related perceptions in the current departmental context.",
  "This brief descriptive evaluation addresses three questions: (1) what awareness, visitation, consultation, and perceived value were reported; (2) what prior contribution and contribution-process perceptions were reported, including perceptions of GitHub hosting; and (3) which features were selected for a useful departmental teaching resource. The analysis reports item-level counts and denominators to inform local planning. It does not estimate department-wide prevalence, causal effects, or intervention effectiveness."
)

methods_sections <- list(
  list(
    heading = "Survey context and analytic cohort",
    paragraphs = c(paste0("Data came from a voluntary departmental TA Wiki feedback survey. The analytic cohort contained ", cohort_n, " survey records classified as eligible and consenting under documented project rules. Because a verified invitation denominator and final eligible sampling frame were unavailable, no response rate was calculated."))
  ),
  list(
    heading = "Descriptive summaries",
    paragraphs = c("Counts were the primary summaries. For each item, the denominator was the number of responses classified as valid for that item. Missing and invalid responses were excluded from item-specific valid-response denominators and reported separately. For multiple-selection items, each option count was divided by the number of valid item responses; option percentages are nonexclusive and may sum to more than 100%. Percentages describe the observed records only and were not interpreted as department-wide prevalence estimates.")
  ),
  list(
    heading = "Missingness, invalid responses, and routing boundary",
    paragraphs = c("Blank responses were classified as missing because verified display-logic metadata were unavailable; no structural skips were inferred. Responses that could not be matched to controlled categories were classified as invalid. Conditional reason items were not used as primary substantive evidence without record-level confirmation of their parent-item routing.")
  ),
  list(
    heading = "Contribution uncertainty",
    paragraphs = c(paste0("The direct prior-contribution item was primary: 5 responses were Yes, 4 were No, and 3 were missing. Without classifying those missing responses, the number reporting prior contribution in the 12-record cohort could range from ", contribution_bound_low, " to ", contribution_bound_high, ". This extreme-case deterministic missing-response range is not a confidence interval and does not quantify sampling uncertainty."))
  ),
  list(
    heading = "Qualitative boundary",
    paragraphs = c("Open-ended responses were excluded from the present structured analysis and reserved for a separate restricted qualitative review. No qualitative themes, quotations, or paraphrases were used as manuscript evidence.")
  ),
  list(
    heading = "Analysis transparency",
    paragraphs = c(
      "The descriptive analysis rules were formalized after data collection and were not preregistered. Manuscript values were generated from version-controlled aggregate analysis tables; record-level data and open-text responses are not reported in this manuscript.",
      "Reporting choices were aligned with general guidance for complete observational-study reporting, internet-survey reporting, and survey-method disclosure where applicable: denominators are item-specific, missing and invalid responses are separated, unavailable response-rate inputs are explicitly named, and unsupported generalization is avoided (von Elm et al., 2007; Eysenbach, 2004; AAPOR, 2026)."
    )
  )
)

results_sections <- list(
  list(
    heading = "Survey-record and teaching-support context",
    paragraphs = c(
      paste0("The survey records primarily reflected experienced TAs: ", metric_ta_experience$prose, " reported at least five departmental TA quarters, ", metric_git_comfort$prose, " reported at least moderate Git/GitHub comfort, and ", metric_teaching_interest$prose, " reported at least moderate interest in developing teaching skills."),
      paste0("The TA Wiki was selected as a current teaching-support resource by ", metric_ta_wiki_current$prose, " records. Detailed current-resource and desired-feature selections are reported in the structured aggregate supplement. The denominator for these summaries is the analytic survey-record count, not a verified department-wide eligible population.")
    )
  ),
  list(
    heading = "Awareness, use, and perceived value",
    paragraphs = c(
      paste0("All 12 records indicated at least some awareness of the Wiki and ", metric_visited$prose, " reported a prior visit, but consultation frequency was mixed among the 9 valid responses: ", metric_never_consult$prose, " selected never, ", metric_rarely_consult$prose, " selected rarely, and ", metric_sometimes_consult$prose, " selected sometimes. These are separate item summaries, not an individual-level engagement funnel."),
      paste0(metric_value$prose, " agreed or strongly agreed that the Wiki is or could be valuable, ", metric_recommend$prose, " agreed or strongly agreed that they would recommend it, and ", metric_maintain$prose, " agreed or strongly agreed that it should be maintained.")
    )
  ),
  list(
    heading = "Contribution process and GitHub perceptions",
    paragraphs = c(
      paste0("Five records reported prior contribution, four reported no prior contribution, and three were missing. Assigning all three missing responses to No or all three to Yes yields a possible contributor count of ", gsub("-", " to ", contribution_bound_text, fixed = TRUE), ". This is a deterministic missing-response range, not a confidence interval."),
      paste0("Agreement that records indicated understanding how to contribute was more common than agreement that the process was straightforward: ", metric_understand$prose, " agreed or strongly agreed that they understood how to contribute, while ", metric_straightforward$prose, " agreed or strongly agreed that the process was straightforward. ", metric_simpler$prose, " agreed or strongly agreed that a simpler interface would increase willingness to contribute, and ", metric_training$prose, " agreed or strongly agreed that training or a walkthrough would do so."),
      paste0("Reported effects of GitHub hosting were mixed rather than uniformly positive or negative. For willingness to use the Wiki, ", metric_github_use_none$prose, " reported no difference, ", metric_github_use_more$prose, " reported being more likely to use it, and ", metric_github_use_less$prose, " reported being less likely. For willingness to contribute, the corresponding counts were ", metric_github_contrib_none$prose, ", ", metric_github_contrib_more$prose, ", and ", metric_github_contrib_less$prose, ".")
    )
  ),
  list(
    heading = "Editathon awareness and participation",
    paragraphs = c(paste0("All 12 records indicated having heard of the editathon, and ", metric_editathon_part$prose, " reported participating."))
  )
)

discussion_sections <- list(
  list(
    heading = "Potential value, current-resource selection, and reported consultation are distinct",
    paragraphs = c("Potential value was endorsed more uniformly than current-resource selection or reported consultation of the Wiki. All 12 records agreed that the Wiki is or could be valuable, but only 4 selected it as a current teaching-support resource, and consultation-frequency responses were mixed. These items measure distinct constructs and should not be arranged as an individual-level engagement funnel. Awareness, perceived value, current-resource selection, reported consultation, and recommendation should be evaluated separately when planning subsequent changes. This interpretation is a local planning inference from structured item summaries, not evidence that the Wiki currently reaches or benefits the department as a whole.")
  ),
  list(
    heading = "Contribution evidence supports cautious local testing",
    paragraphs = c("The contribution findings do not establish that GitHub or any particular workflow caused lower participation. They do identify plausible implementation targets: agreement with understanding how to contribute was more common than agreement that the process was straightforward, and responses to the GitHub-effect items were divided. The records primarily reflected experienced TAs and included relatively few reports of low Git/GitHub comfort; perceptions among newer or less technically comfortable graduate students may therefore differ, although the department-wide distribution is unknown. A lower-friction contribution route could be piloted, with subsequent evaluation based on observed edits or contributions rather than hypothetical willingness alone.")
  ),
  list(
    heading = "Content, maintenance, and evaluation",
    paragraphs = c("The desired-features item concerned a useful departmental teaching resource rather than the Wiki specifically. Course-linked tips, rubrics, activities, and templates should therefore be treated as candidate features to pilot in the Wiki, not as direct evidence that the records requested those exact Wiki changes. Similarly, support for continued maintenance does not establish a sustainable governance model. The department could pilot an explicit maintenance role and review schedule and evaluate whether those arrangements improve content currency, use, or contribution.")
  )
)

limitations <- c(
  paste0("This evaluation includes ", cohort_n, " voluntary survey records from one departmental setting. A verified invitation denominator and final eligible sampling frame were unavailable, so neither a response rate nor the extent of nonresponse bias can be assessed. The findings describe the observed records and should not be interpreted as department-wide prevalence estimates."),
  "The survey was cross-sectional and relied on self-reports, including hypothetical willingness rather than observed Wiki-use or contribution logs. Missing and invalid responses reduced several item-specific denominators, and verified display logic was unavailable, preventing confirmation of routing for conditional items. Three direct contribution responses were missing, producing a possible full-cohort contributor count of 5 to 8. The records primarily reflected experienced TAs and included relatively few reports of low Git/GitHub comfort. Open-ended responses were outside the current structured analysis, and sparse exploratory cross-tabs were retained only as internal diagnostics."
)

conclusion <- "In these 12 survey records, the TA Wiki's potential value was endorsed more consistently than current-resource selection, reported consultation, or complete direct contribution status. The results can guide local planning, but they do not estimate department-wide engagement or establish that any content, platform, outreach, or maintenance change would be effective. A reasonable next step would be to pilot a small set of changes, measure subsequent use and contribution, and repeat the survey with verified routing and a documented invitation denominator."

references <- data.frame(
  text = c(
    "American Association for Public Opinion Research. (2026). Code of Professional Ethics and Practices. Revised June 2026.",
    "Eysenbach, G. (2004). Improving the quality of Web surveys: The Checklist for Reporting Results of Internet E-Surveys (CHERRIES). Journal of Medical Internet Research, 6(3), e34. doi:10.2196/jmir.6.3.e34.",
    "Freeman, A. S., Bleiler-Baxter, S. K., & Gardner, G. E. (2026). STEM graduate teaching assistants' psychological needs for teaching: A scoping review of literature. International Journal of STEM Education, 13, Article 11. doi:10.1186/s40594-026-00593-3.",
    "Sadera, E., Suonio, E. E. K., Chen, J. C. C., Herbert, R., Hsu, D., Bogdan, B., & Kool, B. (2024). Strategies and approaches for delivering sustainable training and professional development of graduate teaching assistants, teaching assistants, and tutors: A scoping review. Journal of Applied Research in Higher Education, 16(5), 2199-2215. doi:10.1108/JARHE-08-2023-0323.",
    "UNESCO. (2019). Recommendation on Open Educational Resources (OER). Adopted by the General Conference at its 40th session, Paris, 25 November 2019.",
    "von Elm, E., Altman, D. G., Egger, M., Pocock, S. J., Gotzsche, P. C., & Vandenbroucke, J. P. (2007). The Strengthening the Reporting of Observational Studies in Epidemiology (STROBE) Statement: Guidelines for reporting observational studies. PLOS Medicine, 4(10), e296. doi:10.1371/journal.pmed.0040296."
  ),
  url = c(
    "https://aapor.org/standards-and-ethics/",
    "https://doi.org/10.2196/jmir.6.3.e34",
    "https://doi.org/10.1186/s40594-026-00593-3",
    "https://doi.org/10.1108/JARHE-08-2023-0323",
    "https://www.unesco.org/en/legal-affairs/recommendation-open-educational-resources-oer",
    "https://doi.org/10.1371/journal.pmed.0040296"
  ),
  stringsAsFactors = FALSE
)

section_md <- function(sections, level = "###") {
  unlist(lapply(sections, function(section) c(paste(level, section$heading), "", section$paragraphs, "")), use.names = FALSE)
}
p <- function(x) paste0("<p>", html_escape(x), "</p>")
section_html <- function(sections, level = "h3") {
  unlist(lapply(sections, function(section) c(paste0("<", level, ">", html_escape(section$heading), "</", level, ">"), unlist(lapply(section$paragraphs, p), use.names = FALSE))), use.names = FALSE)
}
paragraphs_tex <- function(x) as.vector(rbind(latex_escape(x), ""))
section_tex <- function(sections, command = "subsection") {
  unlist(lapply(sections, function(section) c(paste0("\\", command, "{", latex_escape(section$heading), "}"), paragraphs_tex(section$paragraphs))), use.names = FALSE)
}
references_md <- function(refs) {
  paste0(seq_len(nrow(refs)), ". ", refs$text, " ", refs$url)
}
references_html <- function(refs) {
  c("<ol>", paste0("<li>", html_escape(refs$text), " <a href=\"", html_escape(refs$url), "\">", html_escape(refs$url), "</a></li>"), "</ol>")
}
references_tex <- function(refs) {
  text <- sub(" doi:[A-Za-z0-9./-]+\\.$", ".", refs$text)
  c(
    "\\begin{sloppypar}",
    "\\small",
    "\\begin{enumerate}",
    paste0("\\item ", latex_escape(text)),
    "\\end{enumerate}",
    "\\normalsize",
    "\\end{sloppypar}"
  )
}
appendix_domain_md <- function(data) {
  out <- character()
  for (domain in unique(data$Domain)) {
    subset <- data[data$Domain == domain, , drop = FALSE]
    subset$Domain <- NULL
    out <- c(out, paste0("### ", domain), "", md_table(subset), "")
  }
  out
}
appendix_domain_html <- function(data) {
  out <- character()
  for (domain in unique(data$Domain)) {
    subset <- data[data$Domain == domain, , drop = FALSE]
    subset$Domain <- NULL
    out <- c(out, paste0("<h3>", html_escape(domain), "</h3>"), html_table(subset))
  }
  out
}
appendix_domain_tex <- function(data) {
  out <- character()
  for (domain in unique(data$Domain)) {
    subset <- data[data$Domain == domain, , drop = FALSE]
    subset$Domain <- NULL
    out <- c(
      out,
      paste0("\\subsection*{", latex_escape(domain), "}"),
      latex_longtable(subset, paste0("Full structured response distributions: ", domain, "."), c("0.26\\textwidth", "0.38\\textwidth", "0.05\\textwidth", "0.05\\textwidth", "0.07\\textwidth", "0.06\\textwidth", "0.06\\textwidth"), "\\footnotesize")
    )
  }
  out
}

supplement_md <- c(
  "# TA Wiki structured aggregate supplement",
  "",
  "This supplement is generated from the same aggregate analysis package as the manuscript. It is an internal coauthor-review supplement, not a public-release artifact.",
  "",
  "## Supplemental selected indicators",
  "",
  md_table(supplemental_indicators),
  "",
  "## Item completeness",
  "",
  md_table(appendix_completeness),
  "",
  "## Full structured response distributions by domain",
  "",
  appendix_domain_md(appendix_full)
)
supplement_md_path <- file.path(out_dir, "journal-style-manuscript-supplement.md")
writeLines(supplement_md, supplement_md_path, useBytes = TRUE)

supplement_html <- c(
  "<!doctype html><html><head><meta charset=\"utf-8\">",
  "<title>TA Wiki structured aggregate supplement</title>",
  "<style>body{font-family:system-ui,-apple-system,Segoe UI,sans-serif;line-height:1.5;margin:2rem;max-width:1100px}table{border-collapse:collapse;width:100%;margin:1rem 0;font-size:.9rem}th,td{border:1px solid #ddd;padding:.35rem;vertical-align:top}th{background:#f5f5f5}</style>",
  "</head><body>",
  "<h1>TA Wiki structured aggregate supplement</h1>",
  p("This supplement is generated from the same aggregate analysis package as the manuscript. It is an internal coauthor-review supplement, not a public-release artifact."),
  "<h2>Supplemental selected indicators</h2>",
  html_table(supplemental_indicators),
  "<h2>Item completeness</h2>",
  html_table(appendix_completeness),
  "<h2>Full structured response distributions by domain</h2>",
  appendix_domain_html(appendix_full),
  "</body></html>"
)
supplement_html_path <- file.path(out_dir, "journal-style-manuscript-supplement.html")
writeLines(supplement_html, supplement_html_path, useBytes = TRUE)

md <- c(
  paste0("# ", manuscript_title),
  "",
  author_line,
  "",
  version_date,
  "",
  "## Abstract",
  "",
  abstract,
  "",
  "## Introduction",
  "",
  intro,
  "",
  "## Methods",
  "",
  section_md(methods_sections),
  "## Results",
  "",
  section_md(results_sections),
  "### Table 1. Survey-record and analytic context",
  "",
  md_table(main_table_context),
  "",
  "### Table 2. Selected indicators of awareness, use, value, and contribution",
  "",
  "Counts are primary. Percentages, where shown, use the item-specific valid-response denominator. Multiple-selection categories are nonexclusive. Missing and invalid responses are not included in item-specific denominators. No structural skips were inferred because verified display logic was unavailable.",
  "",
  md_table(main_table_indicators),
  "",
  "## Discussion and local implications",
  "",
  section_md(discussion_sections),
  "## Limitations",
  "",
  limitations,
  "",
  "## Conclusion",
  "",
  conclusion,
  "",
  "## References",
  "",
  references_md(references),
  "",
  "## Supplementary materials",
  "",
  "Full item-completeness summaries and structured response distributions are provided in the internal aggregate supplement. Routing-dependent conditional items and sparse exploratory cross-tabs are retained as restricted diagnostics and are not interpreted as manuscript findings."
)
md_path <- file.path(out_dir, "journal-style-manuscript.md")
writeLines(md, md_path, useBytes = TRUE)

html <- c(
  "<!doctype html><html><head><meta charset=\"utf-8\">",
  paste0("<title>", html_escape(manuscript_title), "</title>"),
  "<style>body{font-family:system-ui,-apple-system,Segoe UI,sans-serif;line-height:1.5;margin:2rem;max-width:1100px}h1,h2,h3{line-height:1.2}table{border-collapse:collapse;width:100%;margin:1rem 0;font-size:.9rem}th,td{border:1px solid #ddd;padding:.35rem;vertical-align:top}th{background:#f5f5f5}</style>",
  "</head><body>",
  paste0("<h1>", html_escape(manuscript_title), "</h1>"),
  paste0("<p>", html_escape(author_line), "</p>"),
  paste0("<p>", html_escape(version_date), "</p>"),
  "<h2>Abstract</h2>",
  p(abstract),
  "<h2>Introduction</h2>",
  unlist(lapply(intro, p), use.names = FALSE),
  "<h2>Methods</h2>",
  section_html(methods_sections),
  "<h2>Results</h2>",
  section_html(results_sections),
  "<h3>Table 1. Survey-record and analytic context</h3>",
  html_table(main_table_context),
  "<h3>Table 2. Selected indicators of awareness, use, value, and contribution</h3>",
  p("Counts are primary. Percentages, where shown, use the item-specific valid-response denominator. Multiple-selection categories are nonexclusive. Missing and invalid responses are not included in item-specific denominators. No structural skips were inferred because verified display logic was unavailable."),
  html_table(main_table_indicators),
  "<h2>Discussion and local implications</h2>",
  section_html(discussion_sections),
  "<h2>Limitations</h2>",
  unlist(lapply(limitations, p), use.names = FALSE),
  "<h2>Conclusion</h2>",
  p(conclusion),
  "<h2>References</h2>",
  references_html(references),
  "<h2>Supplementary materials</h2>",
  p("Full item-completeness summaries and structured response distributions are provided in the internal aggregate supplement. Routing-dependent conditional items and sparse exploratory cross-tabs are retained as restricted diagnostics and are not interpreted as manuscript findings."),
  "</body></html>"
)
html_path <- file.path(out_dir, "journal-style-manuscript.html")
writeLines(html, html_path, useBytes = TRUE)

tex <- c(
  "\\documentclass[11pt]{article}",
  "\\usepackage[margin=1in]{geometry}",
  "\\usepackage{booktabs}",
  "\\usepackage{longtable}",
  "\\usepackage{array}",
  "\\usepackage{float}",
  "\\usepackage{lineno}",
  "\\usepackage{cmap}",
  "\\usepackage[T1]{fontenc}",
  "\\usepackage{lmodern}",
  "\\usepackage{url}",
  "\\usepackage[hidelinks]{hyperref}",
  "\\usepackage[expansion=false]{microtype}",
  "\\input{glyphtounicode}",
  "\\pdfgentounicode=1",
  "\\setlength{\\parskip}{0.55em}",
  "\\setlength{\\parindent}{0pt}",
  "\\Urlmuskip=0mu plus 1mu",
  paste0("\\title{", latex_escape(manuscript_title), "}"),
  "\\author{Antonio Aguirre\\\\University of California, Santa Cruz \\and Andrew Le\\\\University of California, Santa Cruz \\and Marcela Alfaro-C\\'ordoba\\\\University of California, Santa Cruz}",
  paste0("\\date{", latex_escape(version_date), "}"),
  paste0("\\hypersetup{pdftitle={", latex_escape(manuscript_title), "},pdfauthor={Antonio Aguirre, Andrew Le, and Marcela Alfaro-Cordoba},pdfsubject={Departmental TA Wiki descriptive survey},pdfkeywords={TA Wiki, teaching assistants, descriptive survey, coauthor review}}"),
  "\\begin{document}",
  "\\maketitle",
  "\\linenumbers",
  "\\begin{abstract}",
  latex_escape(abstract),
  "\\end{abstract}",
  "\\section{Introduction}",
  paragraphs_tex(intro),
  "\\section{Methods}",
  section_tex(methods_sections),
  "\\section{Results}",
  section_tex(results_sections),
  latex_table(main_table_context, "Survey-record and analytic context.", c("0.20\\textwidth", "0.26\\textwidth", "0.47\\textwidth"), "\\footnotesize"),
  "Counts are primary. Percentages, where shown, use the item-specific valid-response denominator. Multiple-selection categories are nonexclusive. Missing and invalid responses are not included in item-specific denominators. No structural skips were inferred because verified display logic was unavailable.",
  latex_table(main_table_indicators, "Selected indicators of awareness, use, value, and contribution.", c("0.17\\textwidth", "0.30\\textwidth", "0.15\\textwidth", "0.28\\textwidth"), "\\footnotesize"),
  "\\section{Discussion and local implications}",
  section_tex(discussion_sections),
  "\\section{Limitations}",
  paragraphs_tex(limitations),
  "\\section{Conclusion}",
  latex_escape(conclusion),
  "\\section*{References}",
  references_tex(references),
  "\\section*{Supplementary materials}",
  "Full item-completeness summaries and structured response distributions are provided in the internal aggregate supplement. Routing-dependent conditional items and sparse exploratory cross-tabs are retained as restricted diagnostics and are not interpreted as manuscript findings.",
  "\\end{document}"
)
tex_path <- file.path(out_dir, "journal-style-manuscript.tex")
writeLines(tex, tex_path, useBytes = TRUE)

input_files <- c(
  structured_summary = file.path(tables_dir, "quantitative-structured-summary-labeled.csv"),
  item_completeness = file.path(tables_dir, "quantitative-item-completeness.csv"),
  cohort_flow = file.path(tables_dir, "quantitative-cohort-flow.csv"),
  contribution_sensitivity = file.path(tables_dir, "quantitative-contribution-sensitivity.csv"),
  builder_script = this_script
)
output_files <- list(
  markdown = md_path,
  html = html_path,
  tex = tex_path,
  supplement_markdown = supplement_md_path,
  supplement_html = supplement_html_path,
  claim_ledger = file.path(out_dir, "journal-claim-ledger.csv"),
    main_table_survey_record_context = file.path(out_dir, "main-table-survey-record-context.csv"),
  main_table_engagement_indicators = file.path(out_dir, "main-table-engagement-indicators.csv"),
  supplemental_structured_indicators = file.path(out_dir, "supplemental-structured-indicators.csv")
)
bundle_relative_input <- function(path) {
  repo_rel <- rel_path(path, root)
  repo_rel <- sub("^reports/internal/full-analysis/tables/quantitative-structured-summary-labeled.csv$", "aggregate-data/quantitative-structured-summary-labeled.csv", repo_rel)
  repo_rel <- sub("^reports/internal/full-analysis/tables/quantitative-item-completeness.csv$", "aggregate-data/quantitative-item-completeness.csv", repo_rel)
  repo_rel <- sub("^reports/internal/full-analysis/tables/quantitative-cohort-flow.csv$", "aggregate-data/quantitative-cohort-flow.csv", repo_rel)
  repo_rel <- sub("^reports/internal/full-analysis/tables/quantitative-contribution-sensitivity.csv$", "aggregate-data/quantitative-contribution-sensitivity.csv", repo_rel)
  repo_rel
}
input_descriptor <- function(path) {
  list(
    repository_relative = rel_path(path, root),
    analysis_relative = rel_path(path, analysis_dir),
    bundle_relative = bundle_relative_input(path),
    sha256 = sha256_file(path)
  )
}
tex_version <- ""
if (nzchar(pdflatex) && file.exists(pdflatex)) {
  tex_version <- paste(suppressWarnings(system2(pdflatex, "--version", stdout = TRUE, stderr = TRUE))[1], collapse = "")
}
git_status <- git_status_short()

build_record <- list(
  generated_at_utc = utc_now(),
  manuscript_profile = "structured_only_internal_coauthor_draft",
  repository = list(
    commit = git_value(c("rev-parse", "HEAD")),
    branch = git_value(c("branch", "--show-current")),
    worktree_clean = !nzchar(git_status),
    status_short = git_status
  ),
  runtime = list(
    r_version = R.version.string,
    platform = R.version$platform,
    tex_engine = rel_path(pdflatex, root),
    tex_version = tex_version,
    renv_lock_sha256 = sha256_file(file.path(root, "renv.lock")),
    style_profile_sha256 = sha256_file(file.path(root, "STYLE_PROFILE.md")),
    project_context_sha256 = sha256_file(file.path(root, "scripts", "lib", "project_context.R"))
  ),
  analysis_dir = rel_path(analysis_dir, root),
  out_dir = rel_path(out_dir, root),
  inputs = lapply(input_files, input_descriptor),
  outputs = lapply(output_files, rel_path, base = root),
  excluded_from_manuscript = list(
    qualitative_results = "Deferred pending restricted human review and disclosure decision.",
    conditional_noncontribution_reasons = "Not used as substantive findings because respondent-level routing is unverified.",
    exploratory_cross_tabs = "Retained as internal diagnostics only; not included in the manuscript PDF."
  )
)

if (nzchar(pdflatex) && file.exists(pdflatex)) {
  old <- getwd()
  setwd(out_dir)
  on.exit(setwd(old), add = TRUE)
  args <- c("-interaction=nonstopmode", "-halt-on-error", "-file-line-error", "-no-shell-escape", basename(tex_path))
  status1 <- system2(pdflatex, args, stdout = TRUE, stderr = TRUE)
  status2 <- system2(pdflatex, args, stdout = TRUE, stderr = TRUE)
  pdf_path <- file.path(out_dir, "journal-style-manuscript.pdf")
  output_files$pdf <- pdf_path
  build_record$outputs$pdf <- rel_path(pdf_path, root)
  build_record$pdflatex_status <- c(attr(status1, "status") %||% 0L, attr(status2, "status") %||% 0L)
  build_record$pdflatex_output_tail <- tail(c(status1, status2), 40)
  if (any(as.integer(build_record$pdflatex_status) != 0L)) {
    writeLines(jsonlite::toJSON(build_record, auto_unbox = TRUE, pretty = TRUE), file.path(out_dir, "journal-style-manuscript-build-record.json"), useBytes = TRUE)
    stop("pdflatex failed; see build record tail for details.")
  }
  warning_pattern <- "Overfull \\\\hbox|Overfull \\\\vbox|Underfull|Infinite glue shrinkage|undefined references?|Reference .*undefined|Label\\(s\\) may have changed|Missing character|Rerun to get cross-references right"
  pdflatex_warnings <- unique(grep(warning_pattern, c(status1, status2), value = TRUE, ignore.case = TRUE))
  final_pass_rerun <- grep("Rerun to get cross-references right|undefined references?|Reference .*undefined|Label\\(s\\) may have changed", status2, value = TRUE, ignore.case = TRUE)
  fatal_quality <- unique(c(
    grep("Overfull \\\\hbox|Overfull \\\\vbox|Infinite glue shrinkage|Missing character", c(status1, status2), value = TRUE, ignore.case = TRUE),
    final_pass_rerun
  ))
  build_record$pdflatex_warnings <- pdflatex_warnings
  build_record$pdflatex_quality_issues <- fatal_quality
  if (length(fatal_quality)) {
    writeLines(jsonlite::toJSON(build_record, auto_unbox = TRUE, pretty = TRUE), file.path(out_dir, "journal-style-manuscript-build-record.json"), useBytes = TRUE)
    stop("PDF quality gate failed: see pdflatex_quality_issues in build record.")
  }
} else {
  output_files$pdf <- ""
  build_record$outputs$pdf <- ""
  build_record$pdflatex_status <- "pdflatex_unavailable"
}

build_record$output_hashes <- lapply(output_files, function(path) if (nzchar(path) && file.exists(path)) sha256_file(path) else "")

if (nzchar(copy_to)) {
  dir.create(copy_to, recursive = TRUE, showWarnings = FALSE)
  copied <- list(
    profile = "coauthor_review_copy",
    request_reference = "local copy requested by command",
    destination = "user_specified_local_directory_not_recorded",
    artifacts = list()
  )
  if (nzchar(output_files$pdf) && file.exists(output_files$pdf)) {
    dest <- file.path(copy_to, "TA-Wiki-Manuscript.pdf")
    file.copy(output_files$pdf, dest, overwrite = TRUE)
    copied$artifacts$pdf <- basename(dest)
  }
  dest_html <- file.path(copy_to, "TA-Wiki-Manuscript.html")
  file.copy(html_path, dest_html, overwrite = TRUE)
  copied$artifacts$html <- basename(dest_html)
  dest_supplement_html <- file.path(copy_to, "TA-Wiki-Structured-Supplement.html")
  file.copy(supplement_html_path, dest_supplement_html, overwrite = TRUE)
  copied$artifacts$supplement_html <- basename(dest_supplement_html)
  build_record$copied_to <- copied
}

record_path <- file.path(out_dir, "journal-style-manuscript-build-record.json")
writeLines(jsonlite::toJSON(build_record, auto_unbox = TRUE, pretty = TRUE), record_path, useBytes = TRUE)

cat("Journal-style manuscript written to: ", out_dir, "\n", sep = "")
if (nzchar(output_files$pdf) && file.exists(output_files$pdf)) {
  cat("Journal-style manuscript PDF: ", output_files$pdf, "\n", sep = "")
}
if (nzchar(copy_to)) {
  cat("Copied review artifacts to: ", copy_to, "\n", sep = "")
}
