from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory


ROOT = Path(__file__).resolve().parents[3]


class MapAssetPackageContractTests(unittest.TestCase):
    def test_map_tile_horizontal_pass_dry_run_builds_tile_presentation_patch(self) -> None:
        with TemporaryDirectory() as temp:
            project = Path(temp)
            package = project / "content_source/asset_intake/map_tile/h_pass"
            package.mkdir(parents=True)
            (project / "tests/reports/latest").mkdir(parents=True)
            manifest = {
                "asset_type": "map_tile",
                "asset_key": "h_pass",
                "spec_id": "map_tile_48_v1",
                "content_ids": {"presentation_id": "tile_pres_h_pass"},
                "source_files": {},
                "tile_category": "horizontal_pass",
                "movement_pass_mask": 10,
                "blast_pass_mask": 10,
                "display_name": "horizontal pass",
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
                    "map_tile",
                    "--asset-key",
                    "h_pass",
                    "--dry-run",
                ],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            report = json.loads((project / "tests/reports/latest/phase38_asset_pipeline_latest.json").read_text(encoding="utf-8"))
            self.assertEqual(report["packages"][0]["csv_patch_summary"][0]["keys"], ["tile_pres_h_pass"])


if __name__ == "__main__":
    unittest.main()

