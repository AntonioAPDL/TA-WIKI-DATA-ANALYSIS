# Minimal hashing helpers shared by the aggregate-reproduction scripts.

require_manifest_packages <- function() {
  required <- c("digest", "jsonlite")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stop("Missing required packages: ", paste(missing, collapse = ", "))
}

sha256_file <- function(path) {
  if (!file.exists(path)) stop("Cannot fingerprint missing file: ", path)
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}
