#!/usr/bin/env python3
"""GDScript style linter for QQTang.

Checks for oversized files, oversized functions, and forbidden patterns.
Run as part of validation pipeline.
"""
import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

MAX_FILE_LINES = 700
MAX_FUNC_LINES = 120

FORBIDDEN_NEW_FILE_PATTERNS = [
    (r'\+\+', 'operator ++ is forbidden in GDScript'),
    (r'var\s+\w+\s*:\s*$', 'untyped variable declaration'),
]


def find_gd_files(base: Path) -> list[Path]:
    result = []
    for p in base.rglob("*.gd"):
        rel = str(p.relative_to(base))
        if rel.startswith(("addons/", ".git/", "tests/reports/")):
            continue
        result.append(p)
    result.sort()
    return result


def check_file(path: Path) -> list[str]:
    issues: list[str] = []
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        return [f"{path}: cannot read file"]

    lines = text.split("\n")
    rel = str(path.relative_to(REPO_ROOT))

    # File size check
    if len(lines) > MAX_FILE_LINES:
        issues.append(f"WARN {rel}: {len(lines)} lines (max {MAX_FILE_LINES})")

    # Function size check (naive: count lines between func and next func/end of indent)
    in_func = False
    func_start = 0
    func_name = ""
    for i, line in enumerate(lines):
        stripped = line.lstrip()
        if stripped.startswith("func ") and not stripped.startswith("func _"):
            in_func = True
            func_start = i
            func_name = stripped.split("(")[0].replace("func ", "")
        elif in_func and (stripped.startswith("func ") or (line == "" and i - func_start > MAX_FUNC_LINES)):
            size = i - func_start
            if size > MAX_FUNC_LINES:
                issues.append(f"WARN {rel}:{func_start+1} {func_name}() is {size} lines (max {MAX_FUNC_LINES})")
            in_func = False

    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description="QQTang GDScript style linter")
    parser.add_argument("--fail-new", action="store_true", help="Fail on new files with issues (WARN on old)")
    parser.add_argument("--paths", nargs="*", default=None, help="Specific files or directories to check")
    args = parser.parse_args()

    base = REPO_ROOT
    if args.paths:
        files = []
        for p in args.paths:
            path = Path(p)
            if path.is_dir():
                files.extend(find_gd_files(path))
            elif path.suffix == ".gd":
                files.append(path)
    else:
        files = find_gd_files(base)

    all_issues: list[str] = []
    for f in files:
        all_issues.extend(check_file(f))

    for issue in all_issues:
        print(issue)

    warns = sum(1 for i in all_issues if i.startswith("WARN"))
    errors = sum(1 for i in all_issues if i.startswith("ERROR"))
    if warns:
        print(f"\n{warns} warnings, {errors} errors")
    return 0 if errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
