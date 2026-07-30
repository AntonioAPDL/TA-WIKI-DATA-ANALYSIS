testthat::test_that("the tracked manuscript results placeholder stays nonnumeric and self-contained", {
  path <- file.path(project_root, "manuscript", "generated-results.tex")
  text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  normalized <- tolower(gsub("[[:space:]]+", " ", text))
  testthat::expect_match(
    normalized,
    "no disclosure-approved numerical result artifact is currently available for this manuscript",
    fixed = TRUE
  )
  testthat::expect_false(grepl("[0-9]", text))
  testthat::expect_false(grepl("\\\\(?:input|include|openout|write|read)\\b", text, perl = TRUE))
})
