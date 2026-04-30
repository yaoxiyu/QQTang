from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory


ROOT = Path(__file__).resolve().parents[3]


class PluginExtensionContractTests(unittest.TestCase):
    def test_emote_demo_plugin_is_discovered_without_main_branch(self) -> None:
        with TemporaryDirectory() as temp:
            project = Path(temp)
            package = project / "content_source/asset_intake/emote/demo"
            package.mkdir(parents=True)
            (project / "tests/reports/latest").mkdir(parents=True)
            manifest = {
                "asset_type": "emote",
                "asset_key": "demo",
                "spec_id": "emote_demo_v1",
                "content_ids": {"emote_id": "emote_demo"},
                "source_files": {},
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
                    "emote",
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
            self.assertEqual(report["packages"][0]["asset_type"], "emote")


if __name__ == "__main__":
    unittest.main()
