real_pdflatex <- function() {
  candidates <- unique(c(
    Sys.getenv("TA_WIKI_REAL_PDFLATEX", unset = ""),
    Sys.getenv("TA_WIKI_PDFLATEX", unset = ""),
    Sys.which("pdflatex")
  ))
  candidates <- candidates[nzchar(candidates)]
  for (candidate in candidates) {
    path <- if (file.exists(candidate)) {
      normalizePath(candidate, winslash = "/", mustWork = TRUE)
    } else {
      found <- Sys.which(candidate)
      if (nzchar(found)) normalizePath(found, winslash = "/", mustWork = TRUE) else NA_character_
    }
    if (is.na(path)) next
    probe <- command_status(path, "--version")
    if (identical(probe$status, 0L) && !grepl("fake", probe$output, ignore.case = TRUE)) return(path)
  }
  ""
}

all_releaseable_renderer_rows <- function(metadata) {
  items <- metadata$item_spec[
    metadata$item_spec$primary_analysis == "yes" &
      metadata$item_spec$release_eligibility == "review_required" &
      metadata$item_spec$item_type %in% c("single_choice", "ordinal", "likert", "checkbox"),
    , drop = FALSE
  ]
  rows <- lapply(seq_len(nrow(items)), function(index) {
    item <- items[index, , drop = FALSE]
    if (identical(item$item_type[[1]], "checkbox")) {
      options <- checkbox_codebook(metadata, item$analysis_name[[1]])
      response <- options$canonical_option
    } else {
      options <- scalar_codebook(metadata, item$analysis_name[[1]], item$item_type[[1]])
      response <- options$canonical_value
    }
    data.frame(
      domain = rep(item$domain[[1]], length(response)),
      item = rep(item$analysis_name[[1]], length(response)),
      response = response,
      n = rep(5L, length(response)),
      denominator = rep(5L, length(response)),
      percent = rep(100, length(response)),
      release_status = rep("released", length(response)),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

testthat::test_that("every releaseable controlled response label compiles with a real TeX engine", {
  engine <- real_pdflatex()
  if (!nzchar(engine)) {
    testthat::skip("A real pdflatex executable is unavailable for the release-rendering integration test.")
  }

  public_summary <- all_releaseable_renderer_rows(read_metadata(project_root))
  results <- render_release_results_tex(public_summary, metadata = read_metadata(project_root))
  rendered <- paste(results, collapse = "\n")
  testthat::expect_true(all(utf8ToInt(rendered) <= 127L))

  stage_dir <- tempfile("ta-wiki-real-tex-")
  dir.create(stage_dir, recursive = TRUE)
  on.exit(unlink(stage_dir, recursive = TRUE, force = TRUE), add = TRUE)
  testthat::expect_true(file.copy(file.path(project_root, "manuscript", "article.tex"), stage_dir))
  writeLines(results, file.path(stage_dir, "generated-results.tex"), useBytes = TRUE)

  compiled <- command_status(
    engine,
    c("-interaction=nonstopmode", "-halt-on-error", "-file-line-error", "article.tex"),
    wd = stage_dir
  )
  testthat::expect_equal(compiled$status, 0L, info = compiled$output)
  output <- file.path(stage_dir, "article.pdf")
  testthat::expect_true(file.exists(output))
  testthat::expect_equal(readBin(output, what = "raw", n = 5L), charToRaw("%PDF-"))
})
