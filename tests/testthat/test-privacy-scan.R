testthat::test_that("adversarial privacy-scanner suite passes", {
  python <- python_command()
  result <- command_status(python$executable, c(python$prefix, file.path(project_root, "tests", "test_privacy_scan.py")))
  testthat::expect_equal(result$status, 0L, info = result$output)
})
