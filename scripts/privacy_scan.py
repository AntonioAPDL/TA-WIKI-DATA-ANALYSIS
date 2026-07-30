#!/usr/bin/env python3
"""Enforce a safe tracked-file boundary using Git index/tree blobs, not files on disk."""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass

EXACT_PLACEHOLDERS = {
    "data/raw/.gitkeep",
    "data/restricted/.gitkeep",
    "data/derived/.gitkeep",
    "outputs/internal/.gitkeep",
    "reports/internal/.gitkeep",
    "reports/reproducibility/.gitkeep",
}
FORBIDDEN_PREFIXES = (
    "data/raw/",
    "data/restricted/",
    "data/derived/",
    "outputs/internal/",
    "reports/internal/",
    "reports/reproducibility/",
)
SAFE_PREFIXES = (
    ".github/",
    ".githooks/",
    "docs/",
    "config/",
    "data/metadata/",
    "manuscript/",
    "renv/",
    "scripts/",
    "tests/",
)
# Pre-reorganization paths are accepted only when scanning reachable history.
HISTORICAL_SAFE_PREFIXES = (
    "admin/",
)
SAFE_EXACT = {
    ".Rprofile",
    ".gitattributes",
    ".gitignore",
    "AGENTS.md",
    "CHANGELOG.md",
    "CONTRIBUTING.md",
    "DESCRIPTION",
    "LICENSE",
    "main.tex",
    "Makefile",
    "README.md",
    "renv.lock",
    "STYLE_PROFILE.md",
}
SAFE_DATA_PATHS = {
    "config/analysis-control-files.csv",
    "docs/evidence-index.csv",
    "docs/reproducibility-file-ledger.csv",
    "docs/results-inventory.csv",
    "docs/source-register.csv",
    "data/metadata/category-codebook.csv",
    "data/metadata/checkbox-options.csv",
    "data/metadata/derivation-rules.csv",
    "data/metadata/exploratory-pairs.csv",
    "data/metadata/item-spec.csv",
    "data/metadata/live-header-manifest.csv",
    "data/metadata/publication-labels.csv",
    "data/metadata/transformation-rules.csv",
    "data/metadata/variable_map.csv",
    "tests/synthetic-survey-fixture.csv",
}
HISTORICAL_SAFE_DATA_PATHS = {
    "admin/evidence-index.csv",
    "admin/results-inventory.csv",
    "admin/source-register.csv",
    "tests/fixtures_synthetic.csv",
}
FORBIDDEN_EXTENSIONS = {
    ".7z", ".bmp", ".csv", ".docx", ".feather", ".gif", ".gz", ".jpeg",
    ".jpg", ".parquet", ".pdf", ".png", ".rda", ".rdata", ".rds", ".sav",
    ".sqlite", ".tar", ".tiff", ".xls", ".xlsx", ".zip",
}
RELEASE_PREFIXES = ("outputs/release/", "manuscript/tables/", "manuscript/figures/")
RELEASE_EXACT = {"manuscript/generated-results.tex"}
SENSITIVE_TERMS = re.compile(r"(@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|\bTimestamp\b|\bE-?mail\b)", re.I)
RESULTS_PLACEHOLDER_MARKER = "no disclosure-approved numerical result artifact is currently available for this manuscript"
HISTORICAL_RESULTS_PLACEHOLDER_MARKERS = {
    "results pending reproducible real-data validation and coauthor disclosure review",
}
UNSAFE_PLACEHOLDER_COMMAND = re.compile(r"\\(?:input|include|openout|write|read)\b", re.I)
LFS_POINTER = b"version " + b"https://git-lfs.github.com/spec/v1"


@dataclass(frozen=True)
class Entry:
    mode: str
    blob: str
    path: str


def git_path() -> str:
    return shutil.which("git") or r"C:\Program Files\Git\cmd\git.exe"


def git(root: pathlib.Path, *args: str, text: bool = False) -> str | bytes:
    command = [git_path(), "-C", str(root), *args]
    return subprocess.check_output(command, text=text)


def parse_index_records(raw: bytes) -> list[Entry]:
    entries: list[Entry] = []
    for record in raw.split(b"\0"):
        if not record:
            continue
        metadata, path = record.split(b"\t", 1)
        pieces = metadata.decode("ascii").split()
        entries.append(Entry(mode=pieces[0], blob=pieces[1], path=path.decode("utf-8")))
    return entries


def parse_tree_records(raw: bytes) -> list[Entry]:
    entries: list[Entry] = []
    for record in raw.split(b"\0"):
        if not record:
            continue
        metadata, path = record.split(b"\t", 1)
        pieces = metadata.decode("ascii").split()
        if len(pieces) != 3 or pieces[1] != "blob":
            raise ValueError(f"Unexpected Git tree record: {metadata!r}")
        entries.append(Entry(mode=pieces[0], blob=pieces[2], path=path.decode("utf-8")))
    return entries


def index_entries(root: pathlib.Path) -> list[Entry]:
    return parse_index_records(git(root, "ls-files", "-s", "-z"))


def tree_entries(root: pathlib.Path, commit: str) -> list[Entry]:
    return parse_tree_records(git(root, "ls-tree", "-r", "-z", commit))


def blob(root: pathlib.Path, object_name: str) -> bytes:
    return git(root, "cat-file", "-p", object_name)


def path_allowed(path: str, include_historical_paths: bool = False) -> bool:
    if path in EXACT_PLACEHOLDERS or path in SAFE_EXACT:
        return True
    return path.startswith(SAFE_PREFIXES) or (
        include_historical_paths and path.startswith(HISTORICAL_SAFE_PREFIXES)
    )


def data_path_allowed(path: str, include_historical_paths: bool = False) -> bool:
    return path in SAFE_DATA_PATHS or (
        include_historical_paths and path in HISTORICAL_SAFE_DATA_PATHS
    )


def release_path(path: str) -> bool:
    return path in RELEASE_EXACT or path.startswith(RELEASE_PREFIXES)


def safe_results_placeholder(text: str, include_historical_paths: bool) -> bool:
    normalized = re.sub(r"\s+", " ", text.lower()).strip()
    recognized_marker = RESULTS_PLACEHOLDER_MARKER in normalized or (
        include_historical_paths
        and any(marker in normalized for marker in HISTORICAL_RESULTS_PLACEHOLDER_MARKERS)
    )
    return (
        recognized_marker
        and not re.search(r"[0-9]", text)
        and not UNSAFE_PLACEHOLDER_COMMAND.search(text)
    )


def scan_entries(root: pathlib.Path, entries: list[Entry], label: str) -> list[str]:
    errors: list[str] = []
    include_historical_paths = label == "reachable-history"
    for entry in entries:
        path = entry.path.replace("\\", "/")
        if entry.mode in {"120000", "160000"}:
            errors.append(f"{label}: symlink or submodule is not permitted: {path}")
            continue
        if path.startswith(FORBIDDEN_PREFIXES) and path not in EXACT_PLACEHOLDERS:
            errors.append(f"{label}: restricted path is tracked: {path}")
            continue
        if not path_allowed(path, include_historical_paths=include_historical_paths):
            errors.append(f"{label}: path is not on the safe tracked-file allowlist: {path}")
            continue
        suffix = pathlib.PurePosixPath(path).suffix.lower()
        if suffix in FORBIDDEN_EXTENSIONS and not data_path_allowed(path, include_historical_paths=include_historical_paths):
            errors.append(f"{label}: binary/data extension is not permitted: {path}")
            continue
        content = blob(root, entry.blob)
        if LFS_POINTER in content:
            errors.append(f"{label}: Git LFS pointer is not permitted: {path}")
            continue
        if b"\0" in content:
            errors.append(f"{label}: unknown binary content is not permitted: {path}")
            continue
        if release_path(path):
            text = content.decode("utf-8", errors="replace")
            if SENSITIVE_TERMS.search(text):
                errors.append(f"{label}: possible restricted content in release artifact: {path}")
        if path == "manuscript/generated-results.tex":
            text = content.decode("utf-8", errors="replace")
            if not safe_results_placeholder(text, include_historical_paths):
                errors.append(f"{label}: tracked manuscript results placeholder is not a safe nonnumeric placeholder")
    return errors


def strict_history_entries(root: pathlib.Path) -> list[Entry]:
    commits = git(root, "rev-list", "--all", text=True).splitlines()
    seen: dict[tuple[str, str, str], Entry] = {}
    for commit in commits:
        for entry in tree_entries(root, commit):
            seen[(entry.mode, entry.blob, entry.path)] = entry
    return list(seen.values())


def unreachable_objects(root: pathlib.Path) -> list[str]:
    result = subprocess.run(
        [git_path(), "-C", str(root), "fsck", "--no-reflogs", "--unreachable"],
        text=True,
        capture_output=True,
        check=False,
    )
    return [line for line in result.stdout.splitlines() if line.strip()]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", default=".")
    parser.add_argument("--strict-history", action="store_true", help="scan reachable history and reject unreachable objects")
    parser.add_argument("--json-report", help="write a non-sensitive scan report to this path")
    args = parser.parse_args()
    root = pathlib.Path(args.root).resolve()
    errors = scan_entries(root, index_entries(root), "index")
    if args.strict_history:
        errors.extend(scan_entries(root, strict_history_entries(root), "reachable-history"))
        if unreachable_objects(root):
            errors.append("strict-history: unreachable Git objects remain; publish only from a clean reviewed clone")
    report = {"root": str(root), "strict_history": args.strict_history, "status": "passed" if not errors else "failed", "errors": errors}
    if args.json_report:
        pathlib.Path(args.json_report).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("privacy scan passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
