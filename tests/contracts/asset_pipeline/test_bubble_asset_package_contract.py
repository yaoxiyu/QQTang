from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from tools.asset_pipeline.core.png_rgba import RgbaImage, write_rgba_png


ROOT = Path(__file__).resolve().parents[3]


class BubbleAssetPackageContractTests(unittest.TestCase):
    def test_bubble_package_dry_run_builds_csv_patch(self) -> None:
        with TemporaryDirectory() as temp:
            project = Path(temp)
            package = project / "content_source/asset_intake/bubble/demo"
            (package / "source").mkdir(parents=True)
            (project / "tests/reports/latest").mkdir(parents=True)
            write_rgba_png(package / "source/bubble_idle_grid.png", RgbaImage(256, 256, bytes([80, 160, 255, 180]) * (256 * 256)))
            manifest = {
                "asset_type": "bubble",
                "asset_key": "demo",
                "display_name": "demo bubble",
                "spec_id": "bubble_animation_64_v1",
                "content_ids": {"animation_set_id": "bubble_anim_demo"},
                "source_files": {"idle_grid": "source/bubble_idle_grid.png"},
                "layout": {"type": "grid", "columns": 4, "rows": 4, "frame_count": 16},
                "rights": {"commercial_use": True, "review_status": "approved"},
            }
            (package / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            completed = subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "tools/asset_pipeline/run_asset_pipeline.py"),
                    "--project-root",
                    str(project),
                    "--asset-type",
                    "bubble",
                    "--asset-key",
                    "demo",
                    "--dry-run",
                ],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            report = json.loads((project / "tests/reports/latest/phase38_asset_pipeline_latest.json").read_text(encoding="utf-8"))
            csv_summary = report["packages"][0]["csv_patch_summary"][0]
            self.assertEqual(csv_summary["keys"], ["bubble_anim_demo"])
            self.assertFalse((project / "content_source/csv/bubble_animation_sets/bubble_animation_sets.csv").exists())


if __name__ == "__main__":
    unittest.main()
