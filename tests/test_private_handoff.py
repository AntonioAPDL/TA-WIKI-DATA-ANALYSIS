#!/usr/bin/env python3
"""Adversarial checks for the non-mutating private-handoff verifier."""
from __future__ import annotations

import pathlib
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[1]
VERIFIER = ROOT / "scripts" / "verify_private_handoff.py"
WORKFLOW = ROOT / ".github" / "workflows" / "ci.yml"
PR_TEMPLATE = ROOT / ".github" / "PULL_REQUEST_TEMPLATE.md"
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
    run(path, GIT, "config", "user.email", "handoff-test@example.invalid")
    run(path, GIT, "config", "user.name", "Handoff Test")
    (path / "README.md").write_text("safe\n", encoding="utf-8")
    run(path, GIT, "add", "README.md")
    run(path, GIT, "commit", "-qm", "initial")


def verify(path: pathlib.Path, expect: int = 0, *options: str) -> str:
    return run(path, sys.executable, str(VERIFIER), str(path), *options, expect=expect)


def test_clean_repository_passes() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        output = verify(repo)
        assert "passed" in output


def test_dirty_worktree_is_rejected_without_listing_paths() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        (repo / "private-notes.txt").write_text("do not disclose\n", encoding="utf-8")
        output = verify(repo, 1)
        assert "worktree is not clean" in output
        assert "private-notes.txt" not in output


def test_strict_history_delegates_to_privacy_scanner() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        output = verify(repo, 0, "--strict-history")
        assert "passed" in output


def test_local_or_credentialed_origin_is_rejected_without_echoing_secret() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        run(repo, GIT, "remote", "add", "origin", "file:///tmp/private-repository.git")
        output = verify(repo, 1, "--require-origin")
        assert "credential-free HTTPS or Git-over-SSH" in output

    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        secret = "must-not-appear"
        run(repo, GIT, "remote", "add", "origin", f"https://{secret}@github.com/example/repository.git")
        output = verify(repo, 1, "--require-origin")
        assert "credential-free HTTPS or Git-over-SSH" in output
        assert secret not in output


def test_query_or_fragment_origin_credentials_are_rejected_without_echoing_secret() -> None:
    secret = "must-not-appear-in-output"
    urls = (
        f"https://github.com/example/repository.git?access_token={secret}",
        f"https://github.com/example/repository.git#access_token={secret}",
        f"git@github.com:example/repository.git?access_token={secret}",
    )
    for url in urls:
        with tempfile.TemporaryDirectory() as directory:
            repo = pathlib.Path(directory)
            init_repo(repo)
            run(repo, GIT, "remote", "add", "origin", url)
            output = verify(repo, 1, "--require-origin")
            assert "credential-free HTTPS or Git-over-SSH" in output
            assert secret not in output


def test_standard_origin_and_repository_hooks_pass_when_required() -> None:
    with tempfile.TemporaryDirectory() as directory:
        repo = pathlib.Path(directory)
        init_repo(repo)
        hooks = repo / ".githooks"
        hooks.mkdir()
        (hooks / "pre-commit").write_text("#!/bin/sh\n", encoding="utf-8")
        (hooks / "pre-push").write_text("#!/bin/sh\n", encoding="utf-8")
        run(repo, GIT, "add", ".githooks")
        run(repo, GIT, "commit", "-qm", "add hooks")
        run(repo, GIT, "config", "core.hooksPath", ".githooks")
        run(repo, GIT, "remote", "add", "origin", "https://github.com/example/repository.git")
        output = verify(repo, 0, "--require-hooks", "--require-origin", "--require-origin-only")
        assert "passed" in output
        run(repo, GIT, "remote", "add", "upstream", "https://github.com/example/upstream.git")
        output = verify(repo, 1, "--require-origin-only")
        assert "may not have remotes other than origin" in output


def test_ci_and_pull_request_template_preserve_handoff_boundary() -> None:
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for requirement in (
        "permissions:\n  contents: read",
        "fetch-depth: 0",
        "persist-credentials: false",
        "timeout-minutes: 20",
        "cancel-in-progress: true",
        "python tests/test_private_handoff.py",
        "python scripts/verify_private_handoff.py . --strict-history",
    ):
        assert requirement in workflow
    action_references = [
        line.strip()
        for line in workflow.splitlines()
        if line.strip().startswith("- uses:")
    ]
    assert action_references
    assert all(re.search(r"@[0-9a-f]{40}$", reference) for reference in action_references)

    template = PR_TEMPLATE.read_text(encoding="utf-8")
    for boundary in ("respondent-level rows", "raffle/contact material", "credentials"):
        assert boundary in template


if __name__ == "__main__":
    test_clean_repository_passes()
    test_dirty_worktree_is_rejected_without_listing_paths()
    test_strict_history_delegates_to_privacy_scanner()
    test_local_or_credentialed_origin_is_rejected_without_echoing_secret()
    test_query_or_fragment_origin_credentials_are_rejected_without_echoing_secret()
    test_standard_origin_and_repository_hooks_pass_when_required()
    test_ci_and_pull_request_template_preserve_handoff_boundary()
    print("private handoff verifier tests passed")
