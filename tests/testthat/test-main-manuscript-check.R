testthat::test_that("main manuscript check is exposed through the runner", {
  result <- system2(
    file.path(R.home("bin"), "Rscript"),
    c(file.path(project_root, "scripts", "run.R"), "manuscript-check"),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(result, "status") %||% 0L
  testthat::expect_identical(status, 0L)
  testthat::expect_match(
    paste(result, collapse = "\n"),
    "main.tex",
    fixed = TRUE
  )
})
