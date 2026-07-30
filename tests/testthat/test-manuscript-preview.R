testthat::test_that("controlled manuscript preview stages only the tracked TeX inputs", {
  fake_dir <- tempfile("ta-wiki-fake-pdflatex-")
  dir.create(fake_dir, recursive = TRUE)
  on.exit(unlink(fake_dir, recursive = TRUE, force = TRUE), add = TRUE)
  if (.Platform$OS.type == "windows") {
    fake_engine <- file.path(fake_dir, "fake-pdflatex.cmd")
    writeLines(c(
      "@echo off",
      "if \"%1\"==\"--version\" (",
      "  echo FakeTeX 1.0",
      "  exit /b 0",
      ")",
      "> article.pdf echo %%PDF-1.4",
      "exit /b 0"
    ), fake_engine, useBytes = TRUE)
  } else {
    fake_engine <- file.path(fake_dir, "fake-pdflatex")
    writeLines(c(
      "#!/bin/sh",
      "if [ \"$1\" = \"--version\" ]; then echo 'FakeTeX 1.0'; exit 0; fi",
      "printf '%s\\n' '%PDF-1.4' > article.pdf"
    ), fake_engine, useBytes = TRUE)
    Sys.chmod(fake_engine, mode = "0755")
  }

  preview_name <- paste0("preview-test-", as.integer(Sys.time()), ".pdf")
  preview_path <- file.path(project_root, "manuscript", preview_name)
  record_path <- sub("\\.pdf$", ".build.json", preview_path)
  on.exit(unlink(preview_path, force = TRUE), add = TRUE)
  on.exit(unlink(record_path, force = TRUE), add = TRUE)
  original_engine <- Sys.getenv("TA_WIKI_PDFLATEX", unset = NA_character_)
  on.exit({
    if (is.na(original_engine)) Sys.unsetenv("TA_WIKI_PDFLATEX") else Sys.setenv(TA_WIKI_PDFLATEX = original_engine)
  }, add = TRUE)
  Sys.setenv(TA_WIKI_PDFLATEX = fake_engine)

  result <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "run.R"), "manuscript-preview", "--output", file.path("manuscript", preview_name))
  )
  testthat::expect_equal(result$status, 0L, info = result$output)
  testthat::expect_true(file.exists(preview_path))
  testthat::expect_gt(file.info(preview_path)$size, 0L)
  testthat::expect_true(file.exists(record_path))
  testthat::expect_equal(readBin(preview_path, what = "raw", n = 5L), charToRaw("%PDF-"))
  testthat::expect_match(result$output, "contains no disclosure-approved numerical results", fixed = TRUE)
})

testthat::test_that("controlled manuscript preview rejects an unsafe output destination", {
  result <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "run.R"), "manuscript-preview", "--output", "outside-preview.pdf")
  )
  testthat::expect_false(identical(result$status, 0L))
  testthat::expect_match(result$output, "must be a .pdf file directly under the repository manuscript directory", fixed = TRUE)
})

testthat::test_that("tracked manuscript source cannot import a local preview notice", {
  article <- readLines(file.path(project_root, "manuscript", "article.tex"), warn = FALSE)
  builder <- readLines(file.path(project_root, "scripts", "build_manuscript_preview.R"), warn = FALSE)
  testthat::expect_false(any(grepl("preview-notice", article, fixed = TRUE)))
  testthat::expect_true(any(grepl("preview-notice", builder, fixed = TRUE)))
  testthat::expect_true(any(grepl("input_clean", builder, fixed = TRUE)))
  testthat::expect_true(any(grepl("--quiet", builder, fixed = TRUE)))
})
