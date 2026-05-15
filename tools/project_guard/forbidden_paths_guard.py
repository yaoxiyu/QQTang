#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SEED = "tools/project_guard/default_forbidden_paths_seed.txt"


def normalize_path(value: str) -> str:
    return value.strip().replace("\\", "/").lstrip("./")


def load_forbidden_paths(seed_path: Path) -> list[str]:
    paths: list[str] = []
    for raw_line in seed_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        paths.append(normalize_path(line))
    return paths


def run_git(args: list[str]) -> str:
    proc = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)
    if proc.returncode != 0:
        message = proc.stderr.strip() or proc.stdout.strip() or "unknown git error"
        raise RuntimeError(message)
    return proc.stdout


def changed_paths_from_base(base_ref: str) -> list[str]:
    output = run_git(["diff", "--name-only", f"{base_ref}...HEAD"])
    return [normalize_path(line) for line in output.splitlines() if line.strip()]


def changed_paths_from_status() -> list[str]:
    output = run_git(["status", "--porcelain"])
    paths: list[str] = []
    for line in output.splitlines():
        if not line.strip():
            continue
        path = line[3:].strip()
        if " -> " in path:
            path = path.split(" -> ", 1)[1].strip()
        if path:
            paths.append(normalize_path(path))
    return paths


def is_forbidden_path(path: str, forbidden_path: str) -> bool:
    normalized_path = normalize_path(path)
    normalized_forbidden = normalize_path(forbidden_path)
    if normalized_forbidden.endswith("/"):
        return normalized_path.startswith(normalized_forbidden)
    return normalized_path == normalized_forbidden


def find_violations(changed_paths: list[str], forbidden_paths: list[str]) -> list[str]:
    violations: list[str] = []
    for path in changed_paths:
        for forbidden_path in forbidden_paths:
            if is_forbidden_path(path, forbidden_path):
                violations.append(f"{path} matches {forbidden_path}")
                break
    return violations


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Forbidden path guard.")
    parser.add_argument("--base", help="Base ref for git diff, for example origin/main.")
    parser.add_argument("--seed", default=DEFAULT_SEED, help="Forbidden path seed file.")
    parser.add_argument("--paths", nargs="*", help="Explicit changed paths to validate.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    seed_path = Path(args.seed) if args.seed else None
    if seed_path is None:
        print("[path_guard] no seed file specified; nothing is forbidden. Pass --seed to enforce.")
        return 0
    if not seed_path.is_absolute():
        seed_path = ROOT / seed_path
    if not seed_path.exists():
        print(f"[path_guard] seed file not found: {seed_path}", file=sys.stderr)
        return 2

    forbidden_paths = load_forbidden_paths(seed_path)
    if args.paths is not None and len(args.paths) > 0:
        changed_paths = [normalize_path(path) for path in args.paths]
        source = "explicit paths"
    elif args.base:
        try:
            changed_paths = changed_paths_from_base(args.base)
        except RuntimeError as exc:
            print(f"[path_guard] failed to diff against {args.base}: {exc}", file=sys.stderr)
            return 2
        source = f"git diff {args.base}...HEAD"
    else:
        try:
            changed_paths = changed_paths_from_status()
        except RuntimeError as exc:
            print(f"[path_guard] failed to read git status: {exc}", file=sys.stderr)
            return 2
        source = "git status"

    violations = find_violations(changed_paths, forbidden_paths)
    print(f"[path_guard] source={source} changed={len(changed_paths)} forbidden={len(forbidden_paths)}")
    if not violations:
        print("[path_guard] PASS")
        return 0

    print("[path_guard] FAIL forbidden path changes detected:")
    for violation in violations:
        print(f"  - {violation}")
    print("[path_guard] These paths require an explicit approved exception.")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

