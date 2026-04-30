from __future__ import annotations

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from tools.asset_pipeline.core.asset_manifest import load_manifest, validate_manifest_shape, validate_write_rights


class AssetManifestTests(unittest.TestCase):
    def test_manifest_requires_phase38_fields(self) -> None:
        with TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "manifest.json").write_text('{"asset_type":"character"}', encoding="utf-8")
            manifest = load_manifest(root)
            errors = validate_manifest_shape(manifest)
        self.assertIn("missing manifest field: asset_key", errors)
        self.assertIn("missing manifest field: rights", errors)

    def test_write_rights_require_commercial_use_and_approval(self) -> None:
        with TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "manifest.json").write_text(
                """
                {
                  "asset_type": "character",
                  "asset_key": "demo",
                  "spec_id": "character_sprite_100_v1",
                  "content_ids": {},
                  "source_files": {},
                  "rights": {"commercial_use": false, "review_status": "draft"}
                }
                """,
                encoding="utf-8",
            )
            manifest = load_manifest(root)
            errors = validate_write_rights(manifest)
        self.assertIn("rights.commercial_use must be true before WriteCsv", errors)
        self.assertIn("rights.review_status must be approved before WriteCsv", errors)


if __name__ == "__main__":
    unittest.main()

