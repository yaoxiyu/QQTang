#!/usr/bin/env python3
from __future__ import annotations

import argparse
import fnmatch
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SELF_PATH = Path(__file__).resolve().relative_to(ROOT).as_posix()

FORBIDDEN_PATHS = [
    "gameplay/front/flow/",
    "gameplay/network/session/",
    "network/runtime/legacy/",
    "network/session/legacy/",
    "network/runtime/dedicated_server_bootstrap.gd",
    "network/session/runtime/server_room_runtime.gd",
    "network/session/runtime/server_room_runtime_compat_impl.gd",
    "network/session/runtime/legacy_room_runtime_bridge.gd",
    "app/http/",
]

FORBIDDEN_REFERENCES = [
    "res://gameplay/front/flow/",
    "res://gameplay/network/session/",
    "res://network/runtime/legacy/",
    "res://network/session/legacy/",
    "res://network/runtime/dedicated_server_bootstrap.gd",
    "res://network/session/runtime/server_room_runtime.gd",
    "res://network/session/runtime/server_room_runtime_compat_impl.gd",
    "res://network/session/runtime/legacy_room_runtime_bridge.gd",
    "res://app/http/http_response_reader.gd",
]

REFERENCE_SCAN_ROOTS = (
    "app/",
    "gameplay/",
    "network/",
    "presentation/",
    "services/",
    "tests/",
    "scripts/",
    "tools/",
    "docs/",
)

REFERENCE_SCAN_SUFFIXES = {
    ".gd",
    ".tscn",
    ".tres",
    ".res",
    ".go",
    ".cs",
    ".py",
    ".ps1",
    ".json",
    ".md",
    ".txt",
    ".yml",
    ".yaml",
}

REFERENCE_ALLOWLIST_PREFIXES = [
    "docs/archive/",
    "tests/contracts/path/",
]

REFERENCE_ALLOWLIST_FILES = {
    SELF_PATH,
    "tests/contracts/path/no_removed_room_runtime_test_reference_contract_test.gd",
    "tests/contracts/path/no_legacy_compat_assets_contract_test.gd",
    "tests/contracts/path/no_legacy_runtime_bridge_contract_test.gd",
}

TEMP_LOG_PATTERNS = [
    "*.log",
    "*.tmp",
    "*.temp",
]


class CheckResult:
    def __init__(self, name: str) -> None:
        self.name: str = name
        self.violations: list[str] = []

    @property
    def ok(self) -> bool:
        return not self.violations


def run_cmd(args: list[str]) -> str:
    proc = subprocess.run(args, cwd=ROOT, capture_output=True, text=True)
    if proc.returncode != 0:
        msg = proc.stderr.strip() or proc.stdout.strip() or "unknown error"
        raise RuntimeError(f"command failed: {' '.join(args)} -> {msg}")
    return proc.stdout


def list_tracked_files() -> list[str]:
    out = run_cmd(["git", "ls-files"])
    return [line.strip().replace("\\", "/") for line in out.splitlines() if line.strip()]


def list_git_status_paths() -> list[str]:
    out = run_cmd(["git", "status", "--porcelain"])
    paths: list[str] = []
    for line in out.splitlines():
        if not line:
            continue
        entry = line[3:].strip()
        if " -> " in entry:
            entry = entry.split(" -> ", 1)[1].strip()
        if entry:
            paths.append(entry.replace("\\", "/"))
    return paths


def safe_read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (FileNotFoundError, UnicodeDecodeError):
        return ""


def is_path_allowlisted(path: str) -> bool:
    normalized = path.replace("\\", "/")
    if normalized in REFERENCE_ALLOWLIST_FILES:
        return True
    return any(normalized.startswith(prefix) for prefix in REFERENCE_ALLOWLIST_PREFIXES)


def check_forbidden_paths_absent() -> CheckResult:
    result = CheckResult("A. forbidden paths do not exist")
    for rel in FORBIDDEN_PATHS:
        rel_path = rel.rstrip("/")
        if (ROOT / rel_path).exists():
            result.violations.append(f"forbidden path exists: {rel}")
    return result


def check_forbidden_references_absent(tracked_files: list[str]) -> CheckResult:
    result = CheckResult("B/C. forbidden references absent (with allowlist)")
    for rel in tracked_files:
        if not rel.startswith(REFERENCE_SCAN_ROOTS):
            continue
        if is_path_allowlisted(rel):
            continue
        if Path(rel).suffix.lower() not in REFERENCE_SCAN_SUFFIXES:
            continue
        text = safe_read_text(ROOT / rel)
        if not text:
            continue
        for pattern in FORBIDDEN_REFERENCES:
            if pattern in text:
                result.violations.append(f"{rel} -> {pattern}")
    return result


def check_dirty_artifacts(tracked_files: list[str], status_paths: list[str]) -> CheckResult:
    result = CheckResult("D. dirty artifacts not tracked or staged")
    all_paths = [(p, "tracked") for p in tracked_files] + [(p, "working_tree") for p in status_paths]

    for rel, source in all_paths:
        normalized = rel.replace("\\", "/")
        base = Path(normalized).name

        if normalized == ".godot" or normalized.startswith(".godot/"):
            result.violations.append(f"{source}: .godot artifact present -> {normalized}")

        if normalized == "TestResults" or normalized.startswith("TestResults/"):
            result.violations.append(f"{source}: TestResults artifact present -> {normalized}")

        if fnmatch.fnmatch(normalized, "tests/reports/raw/*.xml"):
            result.violations.append(f"{source}: raw report xml present -> {normalized}")

        if base == ".env":
            result.violations.append(f"{source}: private .env present -> {normalized}")

        if any(fnmatch.fnmatch(base, pattern) for pattern in TEMP_LOG_PATTERNS):
            result.violations.append(f"{source}: temp/log artifact present -> {normalized}")

    return result


def list_filesystem_files() -> list[str]:
    """Fallback file listing when .git is not available (archive mode)."""
    result: list[str] = []
    for p in ROOT.rglob("*"):
        if p.is_file():
            rel = p.relative_to(ROOT).as_posix()
            if rel.startswith((".git/", "__pycache__/", "addons/", "node_modules/")):
                continue
            result.append(rel)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="QQTang release sanity check")
    parser.add_argument(
        "--archive-mode",
        action="store_true",
        help="Run in archive mode (no .git dependency, skip dirty tree check)",
    )
    args = parser.parse_args()

    archive_mode = args.archive_mode
    if archive_mode or not (ROOT / ".git").exists():
        archive_mode = True
        print("[release_sanity] WARN: running in archive mode — git checks skipped")
        tracked_files = list_filesystem_files()
        status_paths = []
    else:
        try:
            tracked_files = list_tracked_files()
            status_paths = list_git_status_paths()
        except Exception as exc:  # noqa: BLE001
            print(f"[FATAL] failed to list repo files: {exc}")
            return 2

    checks = [
        check_forbidden_paths_absent(),
        check_forbidden_references_absent(tracked_files),
    ]
    if not archive_mode:
        checks.append(check_dirty_artifacts(tracked_files, status_paths))

    failed = 0
    print("[release_sanity] Current release sanity check")
    for check in checks:
        if check.ok:
            print(f"[PASS] {check.name}")
            continue
        failed += 1
        print(f"[FAIL] {check.name}")
        for violation in check.violations:
            print(f"  - {violation}")

    print(f"[summary] total={len(checks)} pass={len(checks) - failed} fail={failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

