from __future__ import annotations

from pathlib import Path

from tools.asset_pipeline.core.asset_package import AssetPackage
from tools.asset_pipeline.core.asset_spec_registry import AssetSpec
from tools.asset_pipeline.core.asset_type_plugin import AssetTypePlugin
from tools.asset_pipeline.core.asset_validation_result import StageResult
from tools.asset_pipeline.core.dry_run_plan import CsvPatchPlan


VALID_CATEGORIES = {
    "floor": (15, 15, False, False, False),
    "solid_wall": (0, 0, False, True, True),
    "breakable_block": (0, 0, True, True, True),
    "horizontal_pass": (10, 10, False, False, False),
    "vertical_pass": (5, 5, False, False, False),
    "all_pass_overlay": (15, 15, False, False, False),
    "occluder": (15, 15, False, False, False),
    "spawn": (15, 15, False, False, False),
    "mechanism": (15, 15, False, False, False),
}


class Plugin(AssetTypePlugin):
    asset_type = "map_tile"

    def preflight(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> StageResult:
        result = StageResult(stage="plugin_preflight")
        if not package.manifest.content_ids.get("presentation_id"):
            result.fail("missing content_ids.presentation_id")
        tile_category = str(package.manifest.data.get("tile_category", ""))
        if tile_category not in VALID_CATEGORIES:
            result.fail(f"unsupported tile_category: {tile_category}")
            return result
        movement_pass_mask = int(package.manifest.data.get("movement_pass_mask", VALID_CATEGORIES[tile_category][0]))
        if movement_pass_mask < 0 or movement_pass_mask > 15:
            result.fail(f"movement_pass_mask out of range: {movement_pass_mask}")
        blast_pass_mask = int(package.manifest.data.get("blast_pass_mask", VALID_CATEGORIES[tile_category][1]))
        if blast_pass_mask < 0 or blast_pass_mask > 15:
            result.fail(f"blast_pass_mask out of range: {blast_pass_mask}")
        return result

    def build_csv_patch(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> list[CsvPatchPlan]:
        ids = package.manifest.content_ids
        row = {
            "presentation_id": ids["presentation_id"],
            "display_name": str(package.manifest.data.get("display_name", package.manifest.asset_key)),
            "render_role": str(package.manifest.data.get("render_role", "static_block")),
            "tile_scene_path": str(package.manifest.data.get("tile_scene_path", "")),
            "idle_anim": str(package.manifest.data.get("idle_anim", "")),
            "height_px": str(package.manifest.data.get("height_px", 0)),
            "fade_when_actor_inside": str(package.manifest.data.get("fade_when_actor_inside", "false")).lower(),
            "fade_alpha": str(package.manifest.data.get("fade_alpha", 1.0)),
            "content_hash": str(package.manifest.data.get("content_hash", ids["presentation_id"] + "_phase38")),
        }
        return [CsvPatchPlan("content_source/csv/tile_presentations/tile_presentations.csv", "presentation_id", [row])]

