# Read the immutable source only inside the authorized restricted workflow.
# Neither source locators nor response values are placed in a run manifest.

source_freeze_manifest_descriptor <- function(source_freeze) {
  if (!is.list(source_freeze) || !is_nonempty_string(source_freeze$id) ||
      !is_sha256_value(source_freeze$provenance_sha256) || !is_sha256_value(source_freeze$source_sha256)) {
    stop("Source-freeze evidence cannot be converted to a safe manifest descriptor.")
  }
  list(
    id = source_freeze$id,
    provenance_sha256 = source_freeze$provenance_sha256,
    source_sha256 = source_freeze$source_sha256
  )
}

assert_source_descriptor <- function(expected_source, source_id, source_sha256) {
  if (!is.list(expected_source) || !identical(expected_source$id, source_id) ||
      !is_sha256_value(expected_source$sha256) || !identical(expected_source$sha256, source_sha256)) {
    stop("The source bytes do not match the bound validation manifest.")
  }
  invisible(TRUE)
}

read_authoritative_survey_source <- function(root, metadata, mode, freeze_id = NULL,
                                              expected_source = NULL, expected_source_freeze = NULL) {
  map <- metadata$variable_map
  if (identical(mode, "synthetic")) {
    source_path <- file.path(root, "tests", "synthetic-survey-fixture.csv")
    dat <- utils::read.csv(source_path, check.names = FALSE, stringsAsFactors = FALSE)
    if (!identical(names(dat), map$analysis_name)) stop("Synthetic fixture schema failure.")
    source_id <- "synthetic_fixture"
    source_sha256 <- sha256_file(source_path)
    source_freeze <- list(id = "synthetic", provenance_sha256 = NA_character_, source_sha256 = source_sha256)
  } else if (identical(mode, "real")) {
    if (!is_nonempty_string(freeze_id)) stop("Real source loading requires a source-freeze ID.")
    source_freeze <- source_freeze_evidence(root, freeze_id)
    source_path <- source_freeze$source_path
    if (!requireNamespace("readxl", quietly = TRUE)) stop("Package readxl is required for a real-data workbook.")
    sheets <- readxl::excel_sheets(source_path)
    if (length(sheets) != 1L) stop("Schema failure: workbook must contain exactly one response sheet.")
    dat <- as.data.frame(
      readxl::read_excel(source_path, sheet = sheets[[1]], .name_repair = "minimal"),
      stringsAsFactors = FALSE
    )
    if (length(approved_live_headers(root)) != nrow(map)) {
      stop("Schema failure: approved header manifest and variable map have different lengths.")
    }
    assert_live_header_contract(root, names(dat))
    names(dat) <- map$analysis_name
    source_id <- "survey_final"
    source_sha256 <- source_freeze$source_sha256
  } else {
    stop("Unsupported source mode.")
  }
  if (ncol(dat) != nrow(map)) stop("Schema failure: expected ", nrow(map), " populated columns; found ", ncol(dat), ".")
  if (!is.null(expected_source)) assert_source_descriptor(expected_source, source_id, source_sha256)
  if (!is.null(expected_source_freeze) && identical(mode, "real")) {
    expected_freeze <- source_freeze_manifest_descriptor(source_freeze)
    if (!identical(expected_source_freeze, expected_freeze)) {
      stop("The immutable source-freeze evidence does not match the bound validation manifest.")
    }
  }
  list(
    data = dat,
    source = list(id = source_id, sha256 = source_sha256),
    source_freeze = if (identical(mode, "real")) source_freeze_manifest_descriptor(source_freeze) else source_freeze
  )
}
