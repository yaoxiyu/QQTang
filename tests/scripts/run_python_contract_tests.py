#!/usr/bin/env python3
"""Explicit Python test runner for QQTang.

Scans tests/**/test_*.py and runs each file in an independent subprocess.
Does NOT rely on unittest default discovery, ensuring CI catches tests
that would be missed by `python -m unittest discover`.
"""
import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
TEST_DIR = REPO_ROOT / "tests"
REPORT_DIR = REPO_ROOT / "tests" / "reports" / "latest"
DEFAULT_TIMEOUT_SECONDS = 120

EXCLUDE_DIRS = {"__pycache__", "reports"}


def find_test_files() -> list[Path]:
    result: list[Path] = []
    for root, dirs, files in os.walk(TEST_DIR):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for filename in files:
            if filename.startswith("test_") and filename.endswith(".py"):
                result.append(Path(root) / filename)
    result.sort()
    return result


def run_single(test_path: Path, timeout: int) -> dict:
    start = time.monotonic()
    proc = subprocess.run(
        [sys.executable, "-m", "unittest", str(test_path), "-v"],
        capture_output=True,
        text=True,
        timeout=timeout,
        cwd=str(REPO_ROOT),
    )
    elapsed = time.monotonic() - start
    return {
        "file": str(test_path.relative_to(REPO_ROOT)),
        "exit_code": proc.returncode,
        "elapsed_seconds": round(elapsed, 3),
        "stdout": proc.stdout,
        "stderr": proc.stderr,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="QQTang Python contract test runner")
    parser.add_argument(
        "--timeout",
        type=int,
        default=DEFAULT_TIMEOUT_SECONDS,
        help=f"Per-file timeout in seconds (default: {DEFAULT_TIMEOUT_SECONDS})",
    )
    parser.add_argument(
        "--json-report",
        action="store_true",
        default=True,
        help="Write JSON report to tests/reports/latest/",
    )
    args = parser.parse_args()

    test_files = find_test_files()
    if not test_files:
        print("No Python test files found.")
        return 0

    results: list[dict] = []
    failed = 0
    timed_out = 0

    for test_path in test_files:
        rel = str(test_path.relative_to(REPO_ROOT))
        print(f"--- {rel} ", end="", flush=True)
        try:
            r = run_single(test_path, args.timeout)
        except subprocess.TimeoutExpired:
            elapsed = args.timeout
            r = {
                "file": rel,
                "exit_code": -1,
                "elapsed_seconds": elapsed,
                "stdout": "",
                "stderr": f"TIMEOUT after {elapsed}s",
            }
            timed_out += 1

        status = "PASS" if r["exit_code"] == 0 else ("TIMEOUT" if r["exit_code"] == -1 else "FAIL")
        print(f"{status} ({r['elapsed_seconds']:.1f}s)")
        if r["exit_code"] != 0:
            failed += 1
            if r["stderr"]:
                for line in r["stderr"].strip().splitlines():
                    print(f"  [stderr] {line}")

        results.append(r)

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    report_path = REPORT_DIR / "python_contract_tests_latest.json"
    report = {
        "total": len(results),
        "passed": len(results) - failed,
        "failed": failed - timed_out,
        "timed_out": timed_out,
        "results": results,
    }
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print(f"\n{report['passed']}/{report['total']} passed", end="")
    if report["failed"]:
        print(f", {report['failed']} failed", end="")
    if report["timed_out"]:
        print(f", {report['timed_out']} timed out", end="")
    print(f"\nReport: {report_path}")
    return 1 if failed > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
