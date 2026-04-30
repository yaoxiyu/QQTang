from __future__ import annotations

from pathlib import Path

from tools.asset_pipeline.core.asset_package import AssetPackage
from tools.asset_pipeline.core.asset_spec_registry import AssetSpec
from tools.asset_pipeline.core.asset_type_plugin import AssetTypePlugin
from tools.asset_pipeline.core.asset_validation_result import StageResult
from tools.asset_pipeline.core.dry_run_plan import CsvPatchPlan
from tools.asset_pipeline.core.path_policy import resolve_package_file
from tools.asset_pipeline.core.png_probe import read_png_info


class Plugin(AssetTypePlugin):
    asset_type = "map_theme"

    def preflight(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> StageResult:
        result = StageResult(stage="plugin_preflight")
        if not package.manifest.content_ids.get("theme_id"):
            result.fail("missing content_ids.theme_id")
        background = package.manifest.source_files.get("background")
        grid = package.manifest.data.get("grid", {})
        if background and isinstance(grid, dict):
            width_cells = int(grid.get("width_cells", 0))
            height_cells = int(grid.get("height_cells", 0))
            cell_px = int(grid.get("cell_px", spec.cell_px or 48))
            try:
                info = read_png_info(resolve_package_file(package.root, background))
                expected_width = width_cells * cell_px
                expected_height = height_cells * cell_px
                if expected_width > 0 and expected_height > 0 and (info.width != expected_width or info.height != expected_height):
                    result.fail(f"background size {info.width}x{info.height}, expected {expected_width}x{expected_height}")
            except Exception as exc:
                result.fail(str(exc))
        return result

    def build_csv_patch(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> list[CsvPatchPlan]:
        ids = package.manifest.content_ids
        colors = package.manifest.data.get("colors", {})
        if not isinstance(colors, dict):
            colors = {}
        row = {
            "theme_id": ids["theme_id"],
            "display_name": str(package.manifest.data.get("display_name", package.manifest.asset_key)),
            "bgm_key": str(package.manifest.data.get("bgm_key", "")),
            "environment_scene_path": str(package.manifest.data.get("environment_scene_path", "")),
            "ground_color": str(colors.get("ground", "#E0E0D1")),
            "solid_color": str(colors.get("solid", "#343845")),
            "breakable_color": str(colors.get("breakable", "#B37A4B")),
            "spawn_color": str(colors.get("spawn", "#3E6B42")),
            "grid_line_color": str(colors.get("grid_line", "#1A1E27")),
            "occluder_color": str(colors.get("occluder", "#4E7A52")),
            "solid_presentation_id": str(ids.get("solid_presentation_id", "")),
            "breakable_presentation_id": str(ids.get("breakable_presentation_id", "")),
        }
        return [CsvPatchPlan("content_source/csv/map_themes/map_themes.csv", "theme_id", [row])]

