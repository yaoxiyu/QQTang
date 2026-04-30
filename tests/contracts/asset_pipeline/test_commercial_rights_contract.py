from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory


ROOT = Path(__file__).resolve().parents[3]


def write_png_rgba(path: Path, width: int, height: int) -> None:
    import struct
    import zlib

    raw = b"".join(b"\x00" + (b"\xff\x00\x00\xff" * width) for _ in range(height))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )


class CommercialRightsContractTests(unittest.TestCase):
    def test_write_csv_rejects_unapproved_asset(self) -> None:
        with TemporaryDirectory() as temp:
            project = Path(temp)
            package = project / "content_source/asset_intake/character/demo"
            (package / "source").mkdir(parents=True)
            for clip in ("down", "left", "right", "up", "trapped_down", "victory_down", "defeat_down"):
                write_png_rgba(package / f"source/{clip}.png", 400, 100)
            (project / "tests/reports/latest").mkdir(parents=True)
            manifest = {
                "asset_type": "character",
                "asset_key": "demo",
                "display_name": "demo",
                "spec_id": "character_sprite_100_v1",
                "content_ids": {"animation_set_id": "char_anim_demo"},
                "source_files": {clip: f"source/{clip}.png" for clip in ("down", "left", "right", "up", "trapped_down", "victory_down", "defeat_down")},
                "rights": {"commercial_use": False, "review_status": "draft"},
            }
            (package / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            completed = subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "tools/asset_pipeline/run_asset_pipeline.py"),
                    "--project-root",
                    str(project),
                    "--asset-type",
                    "character",
                    "--asset-key",
                    "demo",
                    "--write-csv",
                ],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertNotEqual(completed.returncode, 0)
            report = json.loads((project / "tests/reports/latest/phase38_asset_pipeline_latest.json").read_text(encoding="utf-8"))
            errors = report["packages"][0]["stage_results"][-1]["errors"]
            self.assertIn("rights.commercial_use must be true before WriteCsv", errors)


if __name__ == "__main__":
    unittest.main()
