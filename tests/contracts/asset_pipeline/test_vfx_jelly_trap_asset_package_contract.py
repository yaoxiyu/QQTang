from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from tools.asset_pipeline.core.png_rgba import RgbaImage, write_rgba_png


ROOT = Path(__file__).resolve().parents[3]


class VfxJellyTrapAssetPackageContractTests(unittest.TestCase):
    def test_vfx_jelly_trap_package_dry_run_builds_csv_patch(self) -> None:
        with TemporaryDirectory() as temp:
            project = Path(temp)
            package = project / "content_source/asset_intake/vfx_jelly_trap/qqt_misc111"
            (package / "source").mkdir(parents=True)
            (project / "tests/reports/latest").mkdir(parents=True)
            write_rgba_png(package / "source/enter.png", RgbaImage(128 * 6, 128, bytes([80, 200, 255, 160]) * (128 * 6 * 128)))
            write_rgba_png(package / "source/loop.png", RgbaImage(128 * 8, 128, bytes([80, 200, 255, 160]) * (128 * 8 * 128)))
            write_rgba_png(package / "source/release.png", RgbaImage(128 * 6, 128, bytes([80, 200, 255, 160]) * (128 * 6 * 128)))
            manifest = {
                "asset_type": "vfx_jelly_trap",
                "asset_key": "qqt_misc111",
                "display_name": "QQT misc111 jelly trap",
                "spec_id": "vfx_jelly_trap_128_v1",
                "content_ids": {"vfx_set_id": "vfx_jelly_trap_qqt_misc111"},
                "source_files": {"enter": "source/enter.png", "loop": "source/loop.png", "release": "source/release.png"},
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
                    "vfx_jelly_trap",
                    "--asset-key",
                    "qqt_misc111",
                    "--dry-run",
                ],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            report = json.loads((project / "tests/reports/latest/phase38_asset_pipeline_latest.json").read_text(encoding="utf-8"))
            self.assertEqual(report["packages"][0]["csv_patch_summary"][0]["keys"], ["vfx_jelly_trap_qqt_misc111"])


if __name__ == "__main__":
    unittest.main()
