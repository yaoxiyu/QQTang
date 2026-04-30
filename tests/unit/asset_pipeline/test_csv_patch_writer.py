from __future__ import annotations

import csv
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from tools.asset_pipeline.core.csv_patch_writer import CsvPatchWriter
from tools.asset_pipeline.core.dry_run_plan import CsvPatchPlan


class CsvPatchWriterTests(unittest.TestCase):
    def test_dry_run_does_not_create_file(self) -> None:
        with TemporaryDirectory() as temp:
            root = Path(temp)
            plan = CsvPatchPlan("content_source/csv/demo.csv", "id", [{"id": "a", "name": "A"}])
            summary = CsvPatchWriter(root).apply(plan, write=False)
            self.assertEqual(summary["inserted"], 1)
            self.assertFalse((root / "content_source/csv/demo.csv").exists())

    def test_write_preserves_header_and_updates_by_key(self) -> None:
        with TemporaryDirectory() as temp:
            root = Path(temp)
            csv_path = root / "content_source/csv/demo.csv"
            csv_path.parent.mkdir(parents=True)
            csv_path.write_text("id,name,manual\nold,Old,keep\n", encoding="utf-8")
            plan = CsvPatchPlan("content_source/csv/demo.csv", "id", [{"id": "old", "name": "New"}])
            CsvPatchWriter(root).apply(plan, write=True)
            with csv_path.open(newline="", encoding="utf-8") as handle:
                rows = list(csv.DictReader(handle))
            self.assertEqual(rows[0]["name"], "New")
            self.assertEqual(rows[0]["manual"], "keep")


if __name__ == "__main__":
    unittest.main()

