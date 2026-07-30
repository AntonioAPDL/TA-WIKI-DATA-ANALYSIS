#!/usr/bin/env python3
"""Verify non-sensitive readiness of a clean clone for private handoff.

This verifier is deliberately read-only: it makes no network requests, does
not change Git configuration, and never reads local ignored workspaces.  It
can establish only repository-side conditions.  Hosting-service visibility,
access control, branch protection, governance approvals, and disclosure
decisions remain human-controlled checks outside this command.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import shutil
import subprocess
import sys
from urllib.parse import urlsplit


GIT = shutil.which("git") or r"C:\Program Files\Git\cmd\git.exe"
SCP_GIT_URL = re.compile(r"^git@[A-Za-z0-9.-]+:[^\s]+$")


def git_result(root: pathlib.Path, *args: str) -> subprocess.CompletedProcess[str]:
    """Run Git without echoing potentially sensitive local configuration."""
    return subprocess.run(
        [GIT, "-C", str(root), *args],
        text=True,
        capture_output=True,
        check=False,
    )


def git_output(root: pathlib.Path, *args: str) -> str:
    result = git_result(root, *args)
    if result.returncode != 0:
        raise RuntimeError("Git command failed")
    return result.stdout.strip()


def repository_root(path: pathlib.Path) -> pathlib.Path:
    return pathlib.Path(git_output(path, "rev-parse", "--show-toplevel")).resolve()


def clean_worktree_error(root: pathlib.Path) -> str | None:
    status = git_output(root, "status", "--porcelain=v1", "--untracked-files=all")
    if status:
        return "worktree is not clean"
    return None


def unreachable_object_error(root: pathlib.Path) -> str | None:
    result = git_result(root, "fsck", "--no-reflogs", "--unreachable")
    if result.returncode != 0 or result.stdout.strip() or result.stderr.strip():
        return "unreachable Git objects remain or Git fsck could not complete"
    return None


def hooks_error(root: pathlib.Path) -> str | None:
    expected = (root / ".githooks").resolve()
    pre_commit = expected / "pre-commit"
    pre_push = expected / "pre-push"
    if not expected.is_dir() or not pre_commit.is_file() or not pre_push.is_file():
        return "repository privacy hooks are incomplete"

    configured = git_result(root, "config", "--get", "core.hooksPath")
    if configured.returncode != 0 or not configured.stdout.strip():
        return "core.hooksPath is not configured for the repository privacy hooks"

    hook_path = pathlib.Path(configured.stdout.strip())
    if not hook_path.is_absolute():
        hook_path = root / hook_path
    if hook_path.resolve() != expected:
        return "core.hooksPath does not point to the repository privacy hooks"
    return None


def credential_free_network_remote(url: str) -> bool:
    """Accept only standard credential-free HTTPS or Git-over-SSH remotes."""
    # A remote URL has no legitimate need for a query or fragment in this
    # workflow.  Treat either delimiter as unsafe even when its value is empty:
    # Git configuration must not become a carrier for token-like credentials.
    if "?" in url or "#" in url:
        return False
    if SCP_GIT_URL.fullmatch(url):
        return True

    parsed = urlsplit(url)
    if parsed.scheme == "https":
        return bool(parsed.hostname) and parsed.username is None and parsed.password is None
    if parsed.scheme == "ssh":
        return (
            bool(parsed.hostname)
            and parsed.password is None
            and parsed.username in {None, "git"}
        )
    return False


def origin_error(root: pathlib.Path, origin_only: bool) -> str | None:
    remote_names = [name for name in git_output(root, "remote").splitlines() if name]
    if "origin" not in remote_names:
        return "origin is not configured"
    if origin_only and set(remote_names) != {"origin"}:
        return "a private-handoff clone may not have remotes other than origin"

    urls = git_result(root, "remote", "get-url", "--all", "origin")
    origin_urls = [url for url in urls.stdout.splitlines() if url]
    if urls.returncode != 0 or not origin_urls:
        return "origin has no configured URL"
    if any(not credential_free_network_remote(url) for url in origin_urls):
        return "origin is not a credential-free HTTPS or Git-over-SSH remote"
    return None


def strict_privacy_error(root: pathlib.Path) -> str | None:
    scanner = pathlib.Path(__file__).with_name("privacy_scan.py")
    result = subprocess.run(
        [sys.executable, str(scanner), str(root), "--strict-history"],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return "strict tracked-file privacy scan failed; run the scanner directly for local diagnostics"
    return None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify clean-clone conditions before a private repository handoff."
    )
    parser.add_argument("root", nargs="?", default=".", help="repository root to inspect")
    parser.add_argument(
        "--strict-history",
        action="store_true",
        help="also run the strict tracked-file privacy scan",
    )
    parser.add_argument(
        "--require-hooks",
        action="store_true",
        help="require core.hooksPath to resolve to .githooks",
    )
    parser.add_argument(
        "--require-origin",
        action="store_true",
        help="require a credential-free HTTPS or Git-over-SSH origin remote",
    )
    parser.add_argument(
        "--require-origin-only",
        action="store_true",
        help="require origin to be the only configured remote (implies --require-origin)",
    )
    args = parser.parse_args()

    try:
        root = repository_root(pathlib.Path(args.root).resolve())
    except (OSError, RuntimeError):
        print("private handoff readiness check failed:", file=sys.stderr)
        print("- target is not an accessible Git repository", file=sys.stderr)
        return 1

    errors: list[str] = []
    for check in (clean_worktree_error, unreachable_object_error):
        error = check(root)
        if error:
            errors.append(error)
    if args.strict_history:
        error = strict_privacy_error(root)
        if error:
            errors.append(error)
    if args.require_hooks:
        error = hooks_error(root)
        if error:
            errors.append(error)
    if args.require_origin or args.require_origin_only:
        error = origin_error(root, origin_only=args.require_origin_only)
        if error:
            errors.append(error)

    if errors:
        print("private handoff readiness check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("private handoff readiness check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
