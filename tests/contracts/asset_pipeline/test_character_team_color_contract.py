from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from tools.asset_pipeline.core.png_rgba import RgbaImage, write_rgba_png


ROOT = Path(__file__).resolve().parents[3]
CLIPS = ("down", "left", "right", "up", "trapped_down", "victory_down", "defeat_down")


class CharacterTeamColorContractTests(unittest.TestCase):
    def test_character_package_generates_eight_team_variants_and_csv_plan(self) -> None:
        with TemporaryDirectory() as temp:
            project = Path(temp)
            package = project / "content_source/asset_intake/character/demo"
            (package / "source").mkdir(parents=True)
            (project / "content_source/csv/team_colors").mkdir(parents=True)
            (project / "tests/reports/latest").mkdir(parents=True)
            (project / "content_source/csv/team_colors/team_palettes.csv").write_text(
                (ROOT / "content_source/csv/team_colors/team_palettes.csv").read_text(encoding="utf-8"),
                encoding="utf-8",
            )
            source_pixels = bytes([120, 120, 120, 255]) * (400 * 100)
            mask_pixels = bytes([255, 0, 0, 255]) * (400 * 100)
            for clip in CLIPS:
                write_rgba_png(package / f"source/{clip}.png", RgbaImage(400, 100, source_pixels))
                write_rgba_png(package / f"source/mask_{clip}.png", RgbaImage(400, 100, mask_pixels))
            manifest = {
                "asset_type": "character",
                "asset_key": "demo",
                "display_name": "demo",
                "spec_id": "character_sprite_100_v1",
                "content_ids": {"animation_set_id": "char_anim_demo"},
                "source_files": {clip: f"source/{clip}.png" for clip in CLIPS},
                "team_color": {
                    "mode": "mask_palette",
                    "palette_id": "team_palette_default_8",
                    "mask_files": {clip: f"source/mask_{clip}.png" for clip in CLIPS},
                },
                "pipeline": {"generate_team_colors": True},
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
                    "character",
                    "--asset-key",
                    "demo",
                    "--dry-run",
                    "--generate-variants",
                ],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            for team_index in range(1, 9):
                self.assertTrue((project / f"assets/generated/animation/characters/demo/team_{team_index:02d}/down.png").exists())
            report = json.loads((project / "tests/reports/latest/phase38_asset_pipeline_latest.json").read_text(encoding="utf-8"))
            csv_summary = report["packages"][0]["csv_patch_summary"][0]
            self.assertEqual(csv_summary["inserted"], 9)


if __name__ == "__main__":
    unittest.main()

