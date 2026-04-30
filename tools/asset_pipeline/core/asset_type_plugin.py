from __future__ import annotations

import json
from pathlib import Path

from .asset_package import AssetPackage
from .asset_spec_registry import AssetSpec
from .asset_validation_result import StageResult
from .dry_run_plan import CsvPatchPlan


class AssetTypePlugin:
    asset_type: str = ""

    def __init__(self, plugin_root: Path) -> None:
        self.plugin_root = plugin_root

    def load_schema(self) -> dict[str, object]:
        schema_path = self.plugin_root / "schema.json"
        if not schema_path.exists():
            raise FileNotFoundError(f"missing plugin schema: {schema_path}")
        return json.loads(schema_path.read_text(encoding="utf-8"))

    def preflight(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> StageResult:
        return StageResult(stage="plugin_preflight")

    def normalize(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> StageResult:
        return StageResult(stage="normalize_sources")

    def generate_variants(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> StageResult:
        return StageResult(stage="generate_variants")

    def build_csv_patch(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> list[CsvPatchPlan]:
        return []

    def build_preview(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> StageResult:
        return StageResult(stage="build_preview")

