#!/usr/bin/env Rscript

# Assemble the coauthor-review package from generated aggregate manuscript
# artifacts. This command does not read raw survey rows, timestamps, open-text
# responses, raffle/contact material, or restricted source workbooks.

this_script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][[1]])
this_script <- normalizePath(this_script, winslash = "/", mustWork = TRUE)
source(file.path(dirname(this_script), "lib", "project_context.R"))
root <- project_root_from_script(this_script)
activate_project(root)
source(file.path(dirname(this_script), "lib", "run_manifest.R"))

cli <- parse_cli()
if (length(setdiff(cli$flags, character()))) {
  stop("Unsupported flag(s): ", paste(cli$flags, collapse = ", "))
}

manuscript_dir <- option_value(cli, "manuscript-dir", default = file.path(root, "reports", "internal", "journal-manuscript"))
out_dir <- option_value(cli, "out-dir", default = file.path(root, "reports", "internal", "coauthor-package"))
copy_to <- option_value(cli, "copy-to", default = "")
package_id <- option_value(cli, "package-id", default = format(as.Date(Sys.time(), tz = "UTC"), "%Y%m%d"))

manuscript_dir <- normalizePath(manuscript_dir, winslash = "/", mustWork = TRUE)
out_dir <- normalizePath(out_dir, winslash = "/", mustWork = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

package_root <- file.path(out_dir, paste0("TA-Wiki-Coauthor-Review-Package-", package_id))
if (dir.exists(package_root)) {
  normalized_root <- normalizePath(package_root, winslash = "/", mustWork = FALSE)
  normalized_out <- normalizePath(out_dir, winslash = "/", mustWork = TRUE)
  if (!startsWith(normalized_root, paste0(normalized_out, "/"))) {
    stop("Refusing to remove a package directory outside the configured output directory.")
  }
  unlink(package_root, recursive = TRUE, force = TRUE)
}
dir.create(package_root, recursive = TRUE, showWarnings = FALSE)

copy_artifact <- function(from, to_relative) {
  source <- file.path(manuscript_dir, from)
  if (!file.exists(source)) stop("Missing required generated artifact: ", source)
  dest <- file.path(package_root, to_relative)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(source, dest, overwrite = TRUE)) {
    stop("Failed to copy generated artifact: ", source)
  }
  data.frame(
    package_path = gsub("\\\\", "/", to_relative),
    source_artifact = from,
    sha256 = sha256_file(dest),
    bytes = file.info(dest)$size,
    stringsAsFactors = FALSE
  )
}

manifest <- do.call(rbind, list(
  copy_artifact("journal-style-manuscript.pdf", "manuscript/TA-Wiki-Manuscript.pdf"),
  copy_artifact("journal-style-manuscript.html", "manuscript/TA-Wiki-Manuscript.html"),
  copy_artifact("journal-style-manuscript.md", "manuscript/TA-Wiki-Manuscript.md"),
  copy_artifact("journal-style-manuscript-supplement.html", "supplement/TA-Wiki-Structured-Supplement.html"),
  copy_artifact("journal-style-manuscript-supplement.md", "supplement/TA-Wiki-Structured-Supplement.md"),
  copy_artifact("journal-claim-ledger.csv", "evidence/TA-Wiki-Claim-Ledger.csv"),
  copy_artifact("main-table-survey-record-context.csv", "evidence/TA-Wiki-Table-1-Survey-Record-Context.csv"),
  copy_artifact("main-table-engagement-indicators.csv", "evidence/TA-Wiki-Table-2-Engagement-Indicators.csv"),
  copy_artifact("supplemental-structured-indicators.csv", "evidence/TA-Wiki-Supplemental-Structured-Indicators.csv"),
  copy_artifact("journal-style-manuscript-build-record.json", "evidence/TA-Wiki-Manuscript-Build-Record.json")
))

doc_map <- c(
  "docs/current-status.md",
  "docs/coauthor-package-guide.md",
  "docs/reproducibility-guide.md",
  "docs/analysis-overview.md",
  "docs/literature-evidence-matrix.md"
)
for (doc in doc_map) {
  source <- file.path(root, doc)
  if (!file.exists(source)) stop("Missing required documentation file: ", source)
  dest <- file.path(package_root, doc)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(source, dest, overwrite = TRUE)) {
    stop("Failed to copy documentation file: ", source)
  }
}

readme <- c(
  "# TA Wiki coauthor review package",
  "",
  paste0("Package ID: ", package_id),
  "",
  "This package contains the current coauthor-review manuscript, structured aggregate supplement, claim ledger, selected evidence tables, and documentation needed to review the descriptive survey/evaluation.",
  "",
  "Start with `manuscript/TA-Wiki-Manuscript.pdf`. Use `supplement/TA-Wiki-Structured-Supplement.html` for full structured aggregate distributions and `evidence/TA-Wiki-Claim-Ledger.csv` to trace manuscript claims to generated aggregate artifacts.",
  "",
  "The package does not include raw survey rows, timestamps, open-text responses, raffle/contact material, or restricted source files.",
  "",
  "The manuscript is descriptive. It reports observed survey-record counts and item-specific denominators and does not estimate response rates, department-wide prevalence, causal effects, or intervention effectiveness.",
  "",
  "Included documentation:",
  "",
  "- `docs/current-status.md`",
  "- `docs/coauthor-package-guide.md`",
  "- `docs/reproducibility-guide.md`",
  "- `docs/analysis-overview.md`",
  "- `docs/literature-evidence-matrix.md`",
  "",
  "For reproducibility, see `MANIFEST.csv` and `evidence/TA-Wiki-Manuscript-Build-Record.json`."
)
writeLines(readme, file.path(package_root, "README.md"), useBytes = TRUE)
manifest <- rbind(
  manifest,
  data.frame(
    package_path = "README.md",
    source_artifact = "generated_package_readme",
    sha256 = sha256_file(file.path(package_root, "README.md")),
    bytes = file.info(file.path(package_root, "README.md"))$size,
    stringsAsFactors = FALSE
  )
)
utils::write.csv(manifest, file.path(package_root, "MANIFEST.csv"), row.names = FALSE, na = "")

zip_path <- file.path(out_dir, paste0("TA-Wiki-Coauthor-Review-Package-", package_id, ".zip"))
old_wd <- getwd()
on.exit(setwd(old_wd), add = TRUE)
setwd(out_dir)
if (file.exists(zip_path)) unlink(zip_path, force = TRUE)
zip_result <- tryCatch(
  utils::zip(zipfile = basename(zip_path), files = basename(package_root), flags = "-r9Xq"),
  error = function(e) e
)
zip_created <- file.exists(zip_path) && file.info(zip_path)$size > 0
zip_detail <- if (inherits(zip_result, "condition")) {
  conditionMessage(zip_result)
} else {
  paste0("zip status ", paste(zip_result, collapse = " "))
}

record <- list(
  package_id = package_id,
  generated_at_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  manuscript_dir = "user_local_generated_manuscript_dir",
  package_dir = basename(package_root),
  zip_file = if (zip_created) basename(zip_path) else "",
  zip_sha256 = if (zip_created) sha256_file(zip_path) else "",
  zip_status = if (zip_created) "created" else paste0("not_created: ", zip_detail),
  artifacts = manifest
)
writeLines(jsonlite::toJSON(record, auto_unbox = TRUE, pretty = TRUE), file.path(package_root, "package-build-record.json"), useBytes = TRUE)

if (nzchar(copy_to)) {
  copy_to <- normalizePath(copy_to, winslash = "/", mustWork = FALSE)
  dir.create(copy_to, recursive = TRUE, showWarnings = FALSE)
  if (zip_created) {
    invisible(file.copy(zip_path, file.path(copy_to, basename(zip_path)), overwrite = TRUE))
  }
  invisible(file.copy(file.path(package_root, "manuscript", "TA-Wiki-Manuscript.pdf"),
                      file.path(copy_to, "TA-Wiki-Manuscript.pdf"), overwrite = TRUE))
  invisible(file.copy(file.path(package_root, "manuscript", "TA-Wiki-Manuscript.html"),
                      file.path(copy_to, "TA-Wiki-Manuscript.html"), overwrite = TRUE))
  invisible(file.copy(file.path(package_root, "supplement", "TA-Wiki-Structured-Supplement.html"),
                      file.path(copy_to, "TA-Wiki-Structured-Supplement.html"), overwrite = TRUE))
}

cat("Coauthor review package directory: ", package_root, "\n", sep = "")
if (zip_created) {
  cat("Coauthor review package ZIP: ", zip_path, "\n", sep = "")
} else {
  warning("ZIP file was not created; package directory is complete. Details: ", zip_detail)
}
