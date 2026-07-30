#!/usr/bin/env Rscript

# Build the working structured aggregate-analysis package for authorized
# coauthor review. Outputs go to ignored internal storage. This command no
# longer extracts or keyword-codes open-text responses; qualitative work must
# use the separate restricted manual qualitative workflow.

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
activate_project(root)

cli <- parse_cli()
if (length(setdiff(cli$flags, character()))) {
  stop("Unsupported flag(s): ", paste(cli$flags, collapse = ", "))
}
run_dir <- option_value(cli, "run-dir", required = TRUE)
source_xlsx <- option_value(cli, "source-xlsx", default = "")
out_dir <- option_value(cli, "out-dir", default = file.path(root, "reports", "internal", "full-analysis"))
pdflatex <- Sys.getenv("TA_WIKI_PDFLATEX", unset = Sys.which("pdflatex"))
if (!nzchar(pdflatex) && file.exists("C:/Users/anton/AppData/Local/Programs/MiKTeX/miktex/bin/x64/pdflatex.exe")) {
  pdflatex <- "C:/Users/anton/AppData/Local/Programs/MiKTeX/miktex/bin/x64/pdflatex.exe"
}

normalize_input_path <- function(path, must_work = TRUE) {
  normalizePath(path, winslash = "/", mustWork = must_work)
}
run_dir <- normalize_input_path(run_dir)
out_dir <- normalize_input_path(out_dir, must_work = FALSE)
if (nzchar(source_xlsx)) {
  stop("--source-xlsx is disabled for full-internal-analysis. Use scripts/run.R qualitative to prepare a restricted manual qualitative workspace; do not extract or auto-code open text in this aggregate builder.")
}

table_dir <- file.path(out_dir, "tables")
qual_dir <- file.path(out_dir, "qualitative-status")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(qual_dir, recursive = TRUE, showWarnings = FALSE)

read_csv <- function(...) {
  utils::read.csv(file.path(...), check.names = FALSE, stringsAsFactors = FALSE, na.strings = "")
}
write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}
first_existing <- function(paths) {
  hits <- paths[file.exists(paths)]
  if (!length(hits)) stop("Missing required input. Tried: ", paste(paths, collapse = "; "))
  hits[[1]]
}

metadata_dir <- file.path(root, "data", "metadata")
item_spec <- read_csv(metadata_dir, "item-spec.csv")
publication_labels <- read_csv(metadata_dir, "publication-labels.csv")
exploratory_pairs <- read_csv(metadata_dir, "exploratory-pairs.csv")

structured_summary_path <- first_existing(c(
  file.path(run_dir, "outputs", "internal", "structured-item-summary.csv"),
  file.path(run_dir, "outputs/internal/structured-item-summary.csv")
))
cohort_flow_path <- file.path(run_dir, "outputs", "internal", "cohort-flow.csv")
contribution_sensitivity_path <- file.path(run_dir, "outputs", "internal", "contribution-sensitivity.csv")
cross_tabs_path <- file.path(run_dir, "outputs", "internal", "exploratory-crosstabs.csv")
cross_tab_summary_path <- file.path(run_dir, "outputs", "internal", "exploratory-crosstab-summary.csv")
cohort_ledger_path <- file.path(run_dir, "derived", "cohort-ledger.csv")

structured_summary <- read.csv(structured_summary_path, check.names = FALSE, stringsAsFactors = FALSE, na.strings = "")
cohort_flow <- read.csv(cohort_flow_path, check.names = FALSE, stringsAsFactors = FALSE)
contribution_sensitivity <- read.csv(contribution_sensitivity_path, check.names = FALSE, stringsAsFactors = FALSE, na.strings = "")
cross_tabs <- read.csv(cross_tabs_path, check.names = FALSE, stringsAsFactors = FALSE, na.strings = "")
cross_tab_summary <- read.csv(cross_tab_summary_path, check.names = FALSE, stringsAsFactors = FALSE, na.strings = "")
cohort_ledger <- read.csv(cohort_ledger_path, check.names = FALSE, stringsAsFactors = FALSE)

label_map <- publication_labels[, c("analysis_name", "publication_label", "domain_label", "domain_order")]
internal_only_labels <- data.frame(
  analysis_name = "noncontribution_reasons",
  publication_label = "Reasons for not contributing to the TA Wiki",
  domain_label = "Contribution and participation",
  domain_order = 4L,
  stringsAsFactors = FALSE
)
internal_only_labels <- internal_only_labels[
  internal_only_labels$analysis_name %in% structured_summary$item &
    !internal_only_labels$analysis_name %in% label_map$analysis_name,
  ,
  drop = FALSE
]
if (nrow(internal_only_labels)) {
  label_map <- rbind(label_map, internal_only_labels)
}
summary_labeled <- merge(
  structured_summary,
  label_map,
  by.x = "item",
  by.y = "analysis_name",
  all.x = TRUE,
  sort = FALSE
)
summary_labeled$publication_label[is.na(summary_labeled$publication_label)] <- summary_labeled$item[is.na(summary_labeled$publication_label)]
summary_labeled$domain_label[is.na(summary_labeled$domain_label)] <- summary_labeled$domain[is.na(summary_labeled$domain_label)]
summary_labeled$domain_order[is.na(summary_labeled$domain_order)] <- 999L
summary_labeled <- summary_labeled[order(
  summary_labeled$domain_order,
  summary_labeled$item,
  summary_labeled$analysis_variant,
  summary_labeled$display_order
), ]

write_csv(summary_labeled, file.path(table_dir, "quantitative-structured-summary-labeled.csv"))
write_csv(cohort_flow, file.path(table_dir, "quantitative-cohort-flow.csv"))
write_csv(contribution_sensitivity, file.path(table_dir, "quantitative-contribution-sensitivity.csv"))
write_csv(cross_tabs, file.path(table_dir, "quantitative-exploratory-crosstabs.csv"))
write_csv(cross_tab_summary, file.path(table_dir, "quantitative-exploratory-crosstab-summary.csv"))

primary_rows <- summary_labeled[summary_labeled$analysis_variant == "primary", , drop = FALSE]
item_completeness <- unique(primary_rows[, c(
  "domain_order", "domain_label", "item", "publication_label", "eligible_n", "applicable_n",
  "observed_valid_n", "inferred_n", "missing_n", "invalid_n", "structural_skip_n", "denominator"
)])
item_completeness <- item_completeness[order(item_completeness$domain_order, item_completeness$item), ]
write_csv(item_completeness, file.path(table_dir, "quantitative-item-completeness.csv"))

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
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  x[] <- lapply(x, function(col) ifelse(is.na(col), "", as.character(col)))
  header <- paste("|", paste(names(x), collapse = " | "), "|")
  sep <- paste("|", paste(rep("---", ncol(x)), collapse = " | "), "|")
  rows <- apply(x, 1, function(row) paste("|", paste(gsub("\\|", "/", row), collapse = " | "), "|"))
  c(header, sep, rows)
}
html_table <- function(x) {
  x <- as.data.frame(x, stringsAsFactors = FALSE)
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
latex_longtable <- function(x, caption, widths) {
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  x[] <- lapply(x, function(col) latex_escape(ifelse(is.na(col), "", as.character(col))))
  align <- paste0("@{}",
                  paste(paste0("p{", widths, "}"), collapse = ""),
                  "@{}")
  out <- c(
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
  for (i in seq_len(nrow(x))) {
    out <- c(out, paste(as.character(x[i, ]), collapse = " & "), "\\\\")
  }
  c(out, "\\bottomrule", "\\end{longtable}")
}

format_percent <- function(x) {
  ifelse(is.na(x), "", sprintf("%.1f", as.numeric(x)))
}
quant_table <- summary_labeled[, c(
  "domain_label", "publication_label", "analysis_variant", "response", "n",
  "denominator", "percent", "missing_n", "invalid_n"
)]
names(quant_table) <- c("Domain", "Item", "Variant", "Response", "n", "N", "Percent", "Missing", "Invalid")
quant_table$Percent <- format_percent(quant_table$Percent)

completeness_table <- item_completeness[, c(
  "domain_label", "publication_label", "eligible_n", "observed_valid_n", "missing_n", "invalid_n", "denominator"
)]
names(completeness_table) <- c("Domain", "Item", "Eligible", "Valid", "Missing", "Invalid", "Denominator")

cross_tab_label <- function(item) {
  hit <- publication_labels$publication_label[match(item, publication_labels$analysis_name)]
  ifelse(is.na(hit), item, hit)
}
cross_tabs_labeled <- cross_tabs
if (nrow(cross_tabs_labeled)) {
  cross_tabs_labeled$row_item_label <- cross_tab_label(cross_tabs_labeled$row_item)
  cross_tabs_labeled$column_item_label <- cross_tab_label(cross_tabs_labeled$column_item)
}
write_csv(cross_tabs_labeled, file.path(table_dir, "quantitative-exploratory-crosstabs-labeled.csv"))

extract_qualitative <- function() {
  list(
    units = data.frame(),
    coded = data.frame(),
    themes = data.frame(),
    note = "Qualitative extraction and automatic coding are disabled. Open-ended responses are reserved for the restricted manual qualitative workflow."
  )
}

qual <- extract_qualitative()
if (nrow(qual$units)) {
  write_csv(qual$units, file.path(qual_dir, "qualitative-open-text-units.csv"))
  write_csv(qual$coded, file.path(qual_dir, "qualitative-coded-units.csv"))
  write_csv(qual$themes, file.path(qual_dir, "qualitative-themes.csv"))
}

theme_lines <- c(
  "# Qualitative status memo",
  "",
  qual$note,
  "",
  "No qualitative synthesis is generated by this structured aggregate builder. Any later qualitative findings require the separate restricted manual coding, independent review/adjudication, snapshot, and disclosure-review workflow.",
  ""
)
if (nrow(qual$themes)) {
  theme_lines <- c(theme_lines, md_table(qual$themes))
} else {
  theme_lines <- c(theme_lines, "No theme table was generated.")
}
writeLines(theme_lines, file.path(qual_dir, "qualitative-status.md"), useBytes = TRUE)

domain_counts <- aggregate(item ~ domain_label, data = unique(summary_labeled[, c("domain_label", "item")]), FUN = length)
names(domain_counts) <- c("Domain", "Items summarized")
domain_counts <- domain_counts[match(unique(summary_labeled$domain_label[order(summary_labeled$domain_order)]), domain_counts$Domain), ]

md <- c(
  "# TA Wiki full internal analysis report",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "This internal report is the working structured aggregate analysis product. It is intentionally stored under `reports/internal/` and is not a public-release artifact.",
  "",
  "## Audit diagnosis",
  "",
  "- The current release-approved article is thin because public-release suppression was applied before a full internal analysis article was written.",
  "- The structured quantitative analysis already exists internally; this report exposes it in a readable coauthor-review form.",
  "- Open-ended material remains outside this builder and requires the separate restricted manual qualitative workflow before any theme, quotation, or paraphrase can be used.",
  "",
  "## Cohort flow",
  "",
  md_table(cohort_flow),
  "",
  "## Domains summarized",
  "",
  md_table(domain_counts),
  "",
  "## Item completeness",
  "",
  md_table(completeness_table),
  "",
  "## Structured descriptive summaries",
  "",
  md_table(quant_table),
  "",
  "## Contribution sensitivity",
  "",
  md_table(contribution_sensitivity),
  "",
  "## Exploratory cross-tab completeness",
  "",
  md_table(cross_tab_summary),
  "",
  "## Exploratory cross-tab cells",
  "",
  if (nrow(cross_tabs_labeled)) md_table(cross_tabs_labeled[, c(
    "pair_id", "row_item_label", "row_response", "column_item_label",
    "column_response", "n", "pairwise_complete_n"
  )]) else "No exploratory cross-tab cells were generated.",
  "",
  "## Qualitative status",
  "",
  qual$note,
  "",
  "No qualitative themes, quotations, or paraphrases were generated.",
  "",
  "## Interpretation boundary",
  "",
  "Use these structured results descriptively. Do not report p-values, causal effects, or response rates. The article should describe the observed survey-record reports and the missingness/denominator structure. Qualitative findings require a separate restricted manual review before inclusion."
)
writeLines(md, file.path(out_dir, "full-analysis-report.md"), useBytes = TRUE)

html <- c(
  "<!doctype html><html><head><meta charset=\"utf-8\">",
  "<title>TA Wiki full internal analysis report</title>",
  "<style>body{font-family:system-ui,-apple-system,Segoe UI,sans-serif;line-height:1.45;margin:2rem;max-width:1200px}table{border-collapse:collapse;width:100%;margin:1rem 0;font-size:.9rem}th,td{border:1px solid #ddd;padding:.35rem;vertical-align:top}th{background:#f5f5f5}code{background:#f5f5f5;padding:.1rem .25rem}</style>",
  "</head><body>",
  "<h1>TA Wiki full internal analysis report</h1>",
  paste0("<p><strong>Generated:</strong> ", html_escape(format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")), "</p>"),
  "<p>This internal report is the working structured aggregate analysis product. It is ignored by Git and is not a public-release artifact.</p>",
  "<h2>Cohort flow</h2>", html_table(cohort_flow),
  "<h2>Domains summarized</h2>", html_table(domain_counts),
  "<h2>Item completeness</h2>", html_table(completeness_table),
  "<h2>Structured descriptive summaries</h2>", html_table(quant_table),
  "<h2>Contribution sensitivity</h2>", html_table(contribution_sensitivity),
  "<h2>Exploratory cross-tab completeness</h2>", html_table(cross_tab_summary),
  "<h2>Exploratory cross-tab cells</h2>",
  if (nrow(cross_tabs_labeled)) html_table(cross_tabs_labeled[, c(
    "pair_id", "row_item_label", "row_response", "column_item_label",
    "column_response", "n", "pairwise_complete_n"
  )]) else "<p>No exploratory cross-tab cells were generated.</p>",
  "<h2>Qualitative status</h2>",
  paste0("<p>", html_escape(qual$note), "</p>"),
  "<p>No qualitative themes, quotations, or paraphrases were generated.</p>",
  "<h2>Interpretation boundary</h2>",
  "<p>Use these structured results descriptively. Do not report p-values, causal effects, or response rates. Qualitative findings require a separate restricted manual review before inclusion.</p>",
  "</body></html>"
)
writeLines(html, file.path(out_dir, "full-analysis-report.html"), useBytes = TRUE)

theme_tex <- if (nrow(qual$themes)) {
  latex_longtable(qual$themes, "Reviewed qualitative themes.", c("0.10\\textwidth", "0.38\\textwidth", "0.13\\textwidth", "0.30\\textwidth"))
} else {
  "No qualitative themes, quotations, or paraphrases were generated."
}
tex <- c(
  "\\documentclass[10pt]{article}",
  "\\usepackage[margin=0.75in]{geometry}",
  "\\usepackage{booktabs}",
  "\\usepackage{longtable}",
  "\\usepackage[T1]{fontenc}",
  "\\usepackage[hidelinks]{hyperref}",
  "\\usepackage[expansion=false]{microtype}",
  "\\title{TA Wiki Full Internal Descriptive Analysis}",
  "\\author{Internal coauthor-review working draft}",
  paste0("\\date{", latex_escape(format(Sys.Date(), "%Y-%m-%d")), "}"),
  "\\begin{document}",
  "\\maketitle",
  "\\section*{Purpose and status}",
  "This ignored internal report is the working structured aggregate analysis product for coauthor review. It is not a public release artifact. It contains descriptive structured summaries only; qualitative findings require the separate restricted manual review workflow before inclusion.",
  "\\section*{Cohort flow}",
  latex_longtable(cohort_flow, "Cohort flow.", c("0.60\\textwidth", "0.20\\textwidth")),
  "\\section*{Item completeness}",
  latex_longtable(completeness_table, "Item completeness and denominators.", c("0.16\\textwidth", "0.34\\textwidth", "0.08\\textwidth", "0.08\\textwidth", "0.08\\textwidth", "0.08\\textwidth", "0.10\\textwidth")),
  "\\section*{Structured descriptive summaries}",
  latex_longtable(quant_table, "Structured descriptive summaries.", c("0.13\\textwidth", "0.25\\textwidth", "0.09\\textwidth", "0.27\\textwidth", "0.04\\textwidth", "0.04\\textwidth", "0.06\\textwidth", "0.04\\textwidth", "0.04\\textwidth")),
  "\\section*{Contribution sensitivity}",
  latex_longtable(contribution_sensitivity, "Contribution uncertainty diagnostics.", c("0.15\\textwidth", "0.18\\textwidth", "0.07\\textwidth", "0.08\\textwidth", "0.08\\textwidth", "0.10\\textwidth", "0.08\\textwidth", "0.08\\textwidth", "0.08\\textwidth")),
  "\\section*{Exploratory cross-tab completeness}",
  latex_longtable(cross_tab_summary, "Exploratory cross-tab completeness.", rep("0.065\\textwidth", ncol(cross_tab_summary))),
  "\\section*{Qualitative status}",
  latex_escape(qual$note),
  theme_tex,
  "\\section*{Interpretation boundary}",
  "Use these structured results descriptively. Do not report p-values, causal effects, or response rates. Qualitative findings require separate restricted manual review before quotation, paraphrase, or external release.",
  "\\end{document}"
)
tex_path <- file.path(out_dir, "full-analysis-article.tex")
writeLines(tex, tex_path, useBytes = TRUE)

build_record <- list(
  generated_at_utc = utc_now(),
  run_dir = run_dir,
  source_xlsx_supplied = nzchar(source_xlsx),
  outputs = list(
    markdown = file.path(out_dir, "full-analysis-report.md"),
    html = file.path(out_dir, "full-analysis-report.html"),
    tex = tex_path
  )
)

if (nzchar(pdflatex) && file.exists(pdflatex)) {
  old <- getwd()
  setwd(out_dir)
  on.exit(setwd(old), add = TRUE)
  args <- c("-interaction=nonstopmode", "-halt-on-error", "-file-line-error", "-no-shell-escape", basename(tex_path))
  status1 <- system2(pdflatex, args, stdout = TRUE, stderr = TRUE)
  status2 <- system2(pdflatex, args, stdout = TRUE, stderr = TRUE)
  build_record$pdf <- file.path(out_dir, "full-analysis-article.pdf")
  build_record$pdflatex_status <- c(attr(status1, "status") %||% 0L, attr(status2, "status") %||% 0L)
  build_record$pdflatex_output_tail <- tail(c(status1, status2), 40)
} else {
  build_record$pdf <- ""
  build_record$pdflatex_status <- "pdflatex_unavailable"
}

writeLines(jsonlite::toJSON(build_record, auto_unbox = TRUE, pretty = TRUE), file.path(out_dir, "full-analysis-build-record.json"), useBytes = TRUE)

cat("Full internal analysis package written to: ", out_dir, "\n", sep = "")
if (nzchar(build_record$pdf) && file.exists(build_record$pdf)) {
  cat("Full internal analysis PDF: ", build_record$pdf, "\n", sep = "")
}
