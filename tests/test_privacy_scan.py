#!/usr/bin/env python3
"""Regression tests for the tracked-file privacy scanner."""
from __future__ import annotations

import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCANNER = ROOT / "scripts" / "privacy_scan.py"
GIT = shutil.which("git") or r"C:\Program Files\Git\cmd\git.exe"


def run(cwd: pathlib.Path, *args: str, expect: int = 0) -> str:
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True)
    if result.returncode != expect:
        raise AssertionError(
            f"expected {expect}, got {result.returncode}: {' '.join(args)}\n"
            f"{result.stdout}\n{result.stderr}"
        )
    return result.stdout + result.stderr


def init_repo(path: pathlib.Path) -> None:
    run(path, GIT, "init", "-q")
    run(path, GIT, "config", "user.email", "scanner-test@example.invalid")
    run(path, GIT, "config", "user.name", "Scanner Test")
    (path / "README.md").write_text("safe\n", encoding="utf-8")
    run(path, GIT, "add", "README.md")
    run(path, GIT, "commit", "-qm", "initial")


def scan(path: pathlib.Path, expect: int, *options: str) -> str:
    return run(path, sys.executable, str(SCANNER), str(path), *options, expect=expect)


def test_raw_data_path_is_rejected() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        leak = repo / "data" / "raw" / "survey.csv"
        leak.parent.mkdir(parents=True)
        leak.write_text("respondent,value\n1,secret\n", encoding="utf-8")
        run(repo, GIT, "add", "-f", "data/raw/survey.csv")
        output = scan(repo, 1)
        assert "restricted path is tracked" in output


def test_unapproved_csv_is_rejected() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        artifact = repo / "results" / "structured-aggregate" / "aggregate-data" / "unreviewed.csv"
        artifact.parent.mkdir(parents=True)
        artifact.write_text("respondent,value\n1,unsafe\n", encoding="utf-8")
        run(repo, GIT, "add", "results/structured-aggregate/aggregate-data/unreviewed.csv")
        output = scan(repo, 1)
        assert "binary/data extension is not permitted" in output


def test_approved_aggregate_csv_is_allowed() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        artifact = repo / "results" / "structured-aggregate" / "aggregate-data" / "quantitative-cohort-flow.csv"
        artifact.parent.mkdir(parents=True)
        artifact.write_text("stage,n\nanalytic_records,10\n", encoding="utf-8")
        run(repo, GIT, "add", "results/structured-aggregate/aggregate-data/quantitative-cohort-flow.csv")
        scan(repo, 0)


def test_approved_qualitative_theme_summary_is_allowed() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        artifact = repo / "results" / "structured-aggregate" / "aggregate-data" / "qualitative-theme-summary.csv"
        artifact.parent.mkdir(parents=True)
        artifact.write_text("theme_id,theme,record_count,summary\nQ01,Platform friction,3,Disclosure-safe aggregate paraphrase.\n", encoding="utf-8")
        run(repo, GIT, "add", "results/structured-aggregate/aggregate-data/qualitative-theme-summary.csv")
        scan(repo, 0)


def test_aggregate_identifier_like_content_is_rejected() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        artifact = repo / "results" / "structured-aggregate" / "aggregate-data" / "quantitative-cohort-flow.csv"
        artifact.parent.mkdir(parents=True)
        artifact.write_text("stage,note\nanalytic_records,person@example.org\n", encoding="utf-8")
        run(repo, GIT, "add", "results/structured-aggregate/aggregate-data/quantitative-cohort-flow.csv")
        output = scan(repo, 1)
        assert "possible restricted content in aggregate result artifact" in output


def test_strict_history_scans_clean_history() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        scan(repo, 0, "--strict-history")


if __name__ == "__main__":
    test_raw_data_path_is_rejected()
    test_unapproved_csv_is_rejected()
    test_approved_aggregate_csv_is_allowed()
    test_approved_qualitative_theme_summary_is_allowed()
    test_aggregate_identifier_like_content_is_rejected()
    test_strict_history_scans_clean_history()
    print("privacy scanner regression tests passed")
