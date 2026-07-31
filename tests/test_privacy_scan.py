#!/usr/bin/env python3
"""Adversarial tests for the Git-index privacy scanner."""
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
        raise AssertionError(f"expected {expect}, got {result.returncode}: {' '.join(args)}\n{result.stdout}\n{result.stderr}")
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


def test_allowed_placeholder() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        placeholder = repo / "data" / "raw" / ".gitkeep"
        placeholder.parent.mkdir(parents=True)
        placeholder.write_text("\n", encoding="utf-8")
        run(repo, GIT, "add", "data/raw/.gitkeep")
        scan(repo, 0)


def test_force_added_derived_file_is_rejected() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        leak = repo / "data" / "derived" / "analysis.csv"
        leak.parent.mkdir(parents=True)
        leak.write_text("respondent,value\n1,secret\n", encoding="utf-8")
        run(repo, GIT, "add", "-f", "data/derived/analysis.csv")
        output = scan(repo, 1)
        assert "restricted path is tracked" in output


def test_nested_placeholder_bypass_is_rejected() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        leak = repo / "data" / "raw" / "nested" / ".gitkeep"
        leak.parent.mkdir(parents=True)
        leak.write_text("not a placeholder\n", encoding="utf-8")
        run(repo, GIT, "add", "-f", "data/raw/nested/.gitkeep")
        scan(repo, 1)


def test_spreadsheet_or_serialized_fixture_is_rejected_by_default() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        artifact = repo / "tests" / "unapproved.xlsx"
        artifact.parent.mkdir(parents=True)
        artifact.write_bytes(b"not a permitted fixture")
        run(repo, GIT, "add", "tests/unapproved.xlsx")
        output = scan(repo, 1)
        assert "binary/data extension is not permitted" in output


def test_explicit_controlled_metadata_csv_is_allowed() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        metadata = repo / "data" / "metadata" / "item-spec.csv"
        metadata.parent.mkdir(parents=True)
        metadata.write_text("position,analysis_name\n1,safe_item\n", encoding="utf-8")
        run(repo, GIT, "add", "data/metadata/item-spec.csv")
        scan(repo, 0)


def test_new_controlled_metadata_csv_is_allowed() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        metadata = repo / "data" / "metadata" / "derivation-rules.csv"
        metadata.parent.mkdir(parents=True)
        metadata.write_text("rule_id,analysis_name\nsafe_rule,safe_item\n", encoding="utf-8")
        run(repo, GIT, "add", "data/metadata/derivation-rules.csv")
        scan(repo, 0)


def test_reproducibility_file_ledger_csv_is_allowed() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        ledger = repo / "docs" / "reproducibility-file-ledger.csv"
        ledger.parent.mkdir(parents=True)
        ledger.write_text("path,file_class\nREADME.md,repository_control\n", encoding="utf-8")
        run(repo, GIT, "add", "docs/reproducibility-file-ledger.csv")
        scan(repo, 0)


def test_unapproved_metadata_csv_is_rejected() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        metadata = repo / "data" / "metadata" / "unapproved.csv"
        metadata.parent.mkdir(parents=True)
        metadata.write_text("safe,value\nexample,1\n", encoding="utf-8")
        run(repo, GIT, "add", "data/metadata/unapproved.csv")
        output = scan(repo, 1)
        assert "binary/data extension is not permitted" in output


def test_approved_structured_aggregate_csv_is_allowed() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        aggregate = repo / "results" / "structured-aggregate" / "aggregate-data" / "quantitative-cohort-flow.csv"
        aggregate.parent.mkdir(parents=True)
        aggregate.write_text("stage,n\nanalytic_records,10\n", encoding="utf-8")
        run(repo, GIT, "add", "results/structured-aggregate/aggregate-data/quantitative-cohort-flow.csv")
        scan(repo, 0)


def test_unapproved_structured_aggregate_csv_is_rejected() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        aggregate = repo / "results" / "structured-aggregate" / "aggregate-data" / "unreviewed.csv"
        aggregate.parent.mkdir(parents=True)
        aggregate.write_text("respondent,value\n1,unsafe\n", encoding="utf-8")
        run(repo, GIT, "add", "results/structured-aggregate/aggregate-data/unreviewed.csv")
        output = scan(repo, 1)
        assert "binary/data extension is not permitted" in output


def test_structured_aggregate_csv_rejects_identifier_like_content() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        aggregate = repo / "results" / "structured-aggregate" / "aggregate-data" / "quantitative-cohort-flow.csv"
        aggregate.parent.mkdir(parents=True)
        aggregate.write_text("stage,note\nanalytic_records,person@example.org\n", encoding="utf-8")
        run(repo, GIT, "add", "results/structured-aggregate/aggregate-data/quantitative-cohort-flow.csv")
        output = scan(repo, 1)
        assert "possible restricted content in aggregate result artifact" in output


def test_index_content_not_worktree_content_is_scanned() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        artifact = repo / "manuscript" / "generated-results.tex"
        artifact.parent.mkdir(parents=True)
        artifact.write_text("Contact person@example.org\n", encoding="utf-8")
        run(repo, GIT, "add", "manuscript/generated-results.tex")
        artifact.write_text("safe replacement in worktree\n", encoding="utf-8")
        output = scan(repo, 1)
        assert "possible restricted content" in output


def test_tracked_results_placeholder_rejects_numeric_or_import_content() -> None:
    unsafe_cases = (
        "No disclosure-approved numerical result artifact is currently available for this manuscript. 7\n",
        "No disclosure-approved numerical result artifact is currently available for this manuscript.\\n\\input{private-results.tex}\n",
    )
    for content in unsafe_cases:
        with tempfile.TemporaryDirectory() as directory:
            repo = pathlib.Path(directory)
            init_repo(repo)
            placeholder = repo / "manuscript" / "generated-results.tex"
            placeholder.parent.mkdir(parents=True)
            placeholder.write_text(content, encoding="utf-8")
            run(repo, GIT, "add", "manuscript/generated-results.tex")
            output = scan(repo, 1)
            assert "tracked manuscript results placeholder" in output


def test_wrapped_results_placeholder_is_allowed() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        placeholder = repo / "manuscript" / "generated-results.tex"
        placeholder.parent.mkdir(parents=True)
        placeholder.write_text(
            "No disclosure-approved numerical result artifact is currently available\n"
            "for this manuscript.\n",
            encoding="utf-8",
        )
        run(repo, GIT, "add", "manuscript/generated-results.tex")
        scan(repo, 0)


def test_strict_history_scans_tree_objects() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        scan(repo, 0, "--strict-history")


def test_strict_history_accepts_only_the_known_legacy_placeholder() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        placeholder = repo / "manuscript" / "generated-results.tex"
        placeholder.parent.mkdir(parents=True)
        placeholder.write_text(
            "Results pending reproducible real-data validation and coauthor disclosure review.\n",
            encoding="utf-8",
        )
        run(repo, GIT, "add", "manuscript/generated-results.tex")
        run(repo, GIT, "commit", "-qm", "legacy-placeholder")
        placeholder.write_text(
            "No disclosure-approved numerical result artifact is currently available\n"
            "for this manuscript.\n",
            encoding="utf-8",
        )
        run(repo, GIT, "add", "manuscript/generated-results.tex")
        run(repo, GIT, "commit", "-qm", "current-placeholder")
        scan(repo, 0, "--strict-history")


if __name__ == "__main__":
    test_allowed_placeholder()
    test_force_added_derived_file_is_rejected()
    test_nested_placeholder_bypass_is_rejected()
    test_spreadsheet_or_serialized_fixture_is_rejected_by_default()
    test_explicit_controlled_metadata_csv_is_allowed()
    test_new_controlled_metadata_csv_is_allowed()
    test_reproducibility_file_ledger_csv_is_allowed()
    test_unapproved_metadata_csv_is_rejected()
    test_approved_structured_aggregate_csv_is_allowed()
    test_unapproved_structured_aggregate_csv_is_rejected()
    test_structured_aggregate_csv_rejects_identifier_like_content()
    test_index_content_not_worktree_content_is_scanned()
    test_tracked_results_placeholder_rejects_numeric_or_import_content()
    test_wrapped_results_placeholder_is_allowed()
    test_strict_history_scans_tree_objects()
    test_strict_history_accepts_only_the_known_legacy_placeholder()
    print("privacy scanner adversarial tests passed")
