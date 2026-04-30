from __future__ import annotations

from pathlib import Path

from tools.asset_pipeline.core.asset_package import AssetPackage
from tools.asset_pipeline.core.asset_spec_registry import AssetSpec
from tools.asset_pipeline.core.asset_type_plugin import AssetTypePlugin
from tools.asset_pipeline.core.asset_validation_result import StageResult


class Plugin(AssetTypePlugin):
    asset_type = "emote"

    def preflight(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> StageResult:
        result = StageResult(stage="plugin_preflight")
        result.warn("emote plugin is a Phase38 extension demo and does not write CSV yet")
        return result

