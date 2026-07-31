testthat::test_that("tracked aggregate bundle reproduces the manuscript snapshot", {
  result <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "run.R"), "reproduce-results", "--check")
  )
  testthat::expect_equal(result$status, 0L, info = result$output)
  testthat::expect_match(
    result$output,
    "reproduce-results check passed",
    fixed = TRUE
  )
})
