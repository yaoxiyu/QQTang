#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
BUF_GEN = ROOT / "buf.gen.yaml"

ALLOWED_OUT_TARGETS = {
    "services/room_service/internal/gen",
    "services/game_service/internal/gen",
    "network/client_net/generated",
}


def main() -> int:
    if not BUF_GEN.exists():
        print(f"[buf-gen-guard] missing file: {BUF_GEN}")
        return 2

    text = BUF_GEN.read_text(encoding="utf-8")
    out_targets = re.findall(r"^\s*out:\s*(\S+)\s*$", text, flags=re.MULTILINE)
    unique_targets = set(out_targets)
    unknown = sorted(unique_targets - ALLOWED_OUT_TARGETS)
    missing = sorted(ALLOWED_OUT_TARGETS - unique_targets)

    if unknown:
        print("[buf-gen-guard] FAIL unknown out targets:")
        for item in unknown:
            print(f"  - {item}")
        return 1

    if missing:
        print("[buf-gen-guard] FAIL missing required out targets:")
        for item in missing:
            print(f"  - {item}")
        return 1

    print("[buf-gen-guard] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
