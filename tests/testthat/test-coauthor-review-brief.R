testthat::test_that("coauthor review brief stages one tracked self-contained TeX source", {
  git <- Sys.which("git")
  if (!nzchar(git)) git <- "C:/Program Files/Git/cmd/git.exe"
  tracked <- run_command(
    git,
    c("-C", project_root, "ls-files", "--error-unmatch", "--", "manuscript/coauthor-review-brief.tex"),
    project_root
  )
  clean <- run_command(
    git,
    c("-C", project_root, "diff", "--quiet", "HEAD", "--", "manuscript/coauthor-review-brief.tex"),
    project_root
  )
  if (tracked$status != 0L || clean$status != 0L) {
    testthat::skip("The controlled brief-build test requires its source to be tracked and match HEAD.")
  }

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
      "> coauthor-review-brief.pdf echo %%PDF-1.4",
      "exit /b 0"
    ), fake_engine, useBytes = TRUE)
  } else {
    fake_engine <- file.path(fake_dir, "fake-pdflatex")
    writeLines(c(
      "#!/bin/sh",
      "if [ \"$1\" = \"--version\" ]; then echo 'FakeTeX 1.0'; exit 0; fi",
      "printf '%s\\n' '%PDF-1.4' > coauthor-review-brief.pdf"
    ), fake_engine, useBytes = TRUE)
    Sys.chmod(fake_engine, mode = "0755")
  }

  brief_name <- paste0("coauthor-brief-test-", as.integer(Sys.time()), ".pdf")
  brief_path <- file.path(project_root, "manuscript", brief_name)
  record_path <- sub("\\.pdf$", ".build.json", brief_path)
  on.exit(unlink(brief_path, force = TRUE), add = TRUE)
  on.exit(unlink(record_path, force = TRUE), add = TRUE)
  original_engine <- Sys.getenv("TA_WIKI_PDFLATEX", unset = NA_character_)
  on.exit({
    if (is.na(original_engine)) Sys.unsetenv("TA_WIKI_PDFLATEX") else Sys.setenv(TA_WIKI_PDFLATEX = original_engine)
  }, add = TRUE)
  Sys.setenv(TA_WIKI_PDFLATEX = fake_engine)

  result <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "run.R"), "coauthor-brief", "--output", file.path("manuscript", brief_name))
  )
  testthat::expect_equal(result$status, 0L, info = result$output)
  testthat::expect_true(file.exists(brief_path))
  testthat::expect_gt(file.info(brief_path)$size, 0L)
  testthat::expect_true(file.exists(record_path))
  testthat::expect_equal(readBin(brief_path, what = "raw", n = 5L), charToRaw("%PDF-"))
  testthat::expect_match(result$output, "contains no restricted results", fixed = TRUE)
})

testthat::test_that("coauthor review brief rejects an unsafe output destination", {
  result <- command_status(
    rscript_bin,
    c(file.path(project_root, "scripts", "run.R"), "coauthor-brief", "--output", "outside-brief.pdf")
  )
  testthat::expect_false(identical(result$status, 0L))
  testthat::expect_match(result$output, "must be a .pdf file directly under the repository manuscript directory", fixed = TRUE)
})

testthat::test_that("coauthor review brief is self-contained and clearly non-submission-ready", {
  brief <- readLines(file.path(project_root, "manuscript", "coauthor-review-brief.tex"), warn = FALSE)
  builder <- readLines(file.path(project_root, "scripts", "build_coauthor_review_brief.R"), warn = FALSE)
  testthat::expect_false(any(grepl("\\\\(?:input|include)", brief, perl = TRUE)))
  testthat::expect_true(any(grepl("self-contained", builder, fixed = TRUE)))
  testthat::expect_true(any(grepl("not a submission-ready manuscript", brief, fixed = TRUE)))
})
