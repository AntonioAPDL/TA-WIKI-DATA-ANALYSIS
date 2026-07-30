markdown_link_targets <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  matches <- regmatches(lines, gregexpr("\\]\\(([^)]+)\\)", lines, perl = TRUE))
  targets <- unlist(lapply(matches, function(items) {
    if (!length(items)) return(character())
    sub("^\\]\\(", "", sub("\\)$", "", items))
  }), use.names = FALSE)
  targets <- sub("#.*$", "", targets)
  targets <- trimws(targets)
  targets[nzchar(targets) &
    !grepl("^(https?://|mailto:|file:)", targets, ignore.case = TRUE)]
}

testthat::test_that("tracked Markdown links resolve to tracked files or directories", {
  documentation_files <- c(
    file.path(project_root, "README.md"),
    file.path(project_root, "CONTRIBUTING.md"),
    list.files(file.path(project_root, "docs"), pattern = "\\.md$", full.names = TRUE),
    list.files(file.path(project_root, "scripts"), pattern = "\\.md$", full.names = TRUE),
    list.files(file.path(project_root, "data", "metadata"), pattern = "\\.md$", full.names = TRUE),
    list.files(file.path(project_root, "manuscript"), pattern = "\\.md$", full.names = TRUE)
  )
  for (path in documentation_files) {
    targets <- markdown_link_targets(path)
    for (target in targets) {
      resolved <- file.path(dirname(path), target)
      testthat::expect_true(
        file.exists(resolved) || dir.exists(resolved),
        info = paste("Broken link in", normalizePath(path, winslash = "/"), ":", target)
      )
    }
  }
})
