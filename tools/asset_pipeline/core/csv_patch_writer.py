from __future__ import annotations

import csv
from pathlib import Path

from .dry_run_plan import CsvPatchPlan


class CsvPatchWriter:
    def __init__(self, project_root: Path) -> None:
        self.project_root = project_root

    def apply(self, plan: CsvPatchPlan, write: bool) -> dict[str, object]:
        csv_path = self.project_root / plan.path
        header: list[str]
        existing_rows: list[dict[str, str]] = []
        if csv_path.exists():
            with csv_path.open(newline="", encoding="utf-8-sig") as handle:
                reader = csv.DictReader(handle)
                header = list(reader.fieldnames or [])
                existing_rows = [dict(row) for row in reader]
        else:
            header = []

        for row in plan.rows:
            for column in row:
                if column not in header:
                    header.append(column)

        seen_keys: set[str] = set()
        for row in existing_rows:
            key = row.get(plan.key_field, "")
            if key in seen_keys:
                raise ValueError(f"duplicate existing key {key} in {plan.path}")
            seen_keys.add(key)

        patch_by_key = {row[plan.key_field]: row for row in plan.rows}
        if len(patch_by_key) != len(plan.rows):
            raise ValueError(f"duplicate patch key in {plan.path}")

        updated = 0
        for row in existing_rows:
            key = row.get(plan.key_field, "")
            if key in patch_by_key:
                row.update(patch_by_key.pop(key))
                updated += 1

        inserted = len(patch_by_key)
        existing_rows.extend(patch_by_key.values())

        if write:
            csv_path.parent.mkdir(parents=True, exist_ok=True)
            with csv_path.open("w", newline="", encoding="utf-8") as handle:
                writer = csv.DictWriter(handle, fieldnames=header, lineterminator="\n")
                writer.writeheader()
                for row in existing_rows:
                    writer.writerow({column: row.get(column, "") for column in header})

        return {
            "path": plan.path,
            "key_field": plan.key_field,
            "keys": [row.get(plan.key_field, "") for row in plan.rows],
            "inserted": inserted,
            "updated": updated,
            "write": write,
        }
