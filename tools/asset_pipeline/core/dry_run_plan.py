from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class CsvPatchPlan:
    path: str
    key_field: str
    rows: list[dict[str, str]]

    def summary(self) -> dict[str, object]:
        return {
            "path": self.path,
            "key_field": self.key_field,
            "row_count": len(self.rows),
            "keys": [row.get(self.key_field, "") for row in self.rows],
        }

