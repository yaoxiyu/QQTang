from __future__ import annotations

import hashlib
import csv
from pathlib import Path

from tools.asset_pipeline.core.asset_package import AssetPackage
from tools.asset_pipeline.core.asset_spec_registry import AssetSpec
from tools.asset_pipeline.core.asset_type_plugin import AssetTypePlugin
from tools.asset_pipeline.core.asset_validation_result import StageResult
from tools.asset_pipeline.core.dry_run_plan import CsvPatchPlan
from tools.asset_pipeline.core.path_policy import resolve_package_file
from tools.asset_pipeline.core.png_probe import read_png_info


class Plugin(AssetTypePlugin):
    asset_type = "bubble"

    def preflight(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> StageResult:
        result = StageResult(stage="plugin_preflight")
        layout = package.manifest.data.get("layout", {})
        layout_type = layout.get("type", "grid") if isinstance(layout, dict) else "grid"
        if layout_type not in ("grid", "strip"):
            result.fail(f"unsupported bubble layout.type: {layout_type}")
        relative = package.manifest.source_files.get("idle_grid")
        if not relative:
            result.fail("missing source_files.idle_grid")
            return result
        try:
            path = resolve_package_file(package.root, relative)
        except ValueError as exc:
            result.fail(str(exc))
            return result
        if not path.exists():
            result.fail(f"missing source file for idle_grid: {relative}")
            return result
        try:
            info = read_png_info(path)
        except ValueError as exc:
            result.fail(str(exc))
            return result
        columns = int(layout.get("columns", spec.source_columns or 0)) if isinstance(layout, dict) else spec.source_columns or 0
        rows = int(layout.get("rows", spec.source_rows or 0)) if isinstance(layout, dict) else spec.source_rows or 0
        expected_width = (spec.frame_width or 0) * columns
        expected_height = (spec.frame_height or 0) * rows
        if info.width != expected_width or info.height != expected_height:
            result.fail(f"idle_grid size {info.width}x{info.height}, expected {expected_width}x{expected_height}")
        frame_count = int(layout.get("frame_count", spec.frame_count or 0)) if isinstance(layout, dict) else spec.frame_count or 0
        if frame_count > columns * rows:
            result.fail(f"frame_count {frame_count} exceeds grid capacity {columns * rows}")
        if spec.alpha_required and not info.has_alpha:
            result.fail("idle_grid must be PNG with alpha channel")
        if not package.manifest.content_ids.get("animation_set_id"):
            result.fail("missing content_ids.animation_set_id")
        elif _csv_has_key(
            project_root / "content_source/csv/bubble_animation_sets/bubble_animation_sets.csv",
            "animation_set_id",
            package.manifest.content_ids["animation_set_id"],
        ):
            result.warn("animation_set_id already exists and will be updated: %s" % package.manifest.content_ids["animation_set_id"])
        return result

    def build_csv_patch(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> list[CsvPatchPlan]:
        defaults = spec.defaults
        layout = package.manifest.data.get("layout", {})
        if not isinstance(layout, dict):
            layout = {}
        animation_set_id = package.manifest.content_ids["animation_set_id"]
        source = package.manifest.source_files["idle_grid"].replace("\\", "/")
        row = {
            "animation_set_id": animation_set_id,
            "display_name": str(package.manifest.data.get("display_name", package.manifest.asset_key)),
            "source_layout_type": str(layout.get("type", "grid")),
            "source_image_path": f"res://{package.root.relative_to(project_root).as_posix()}/{source}",
            "frame_width": str(spec.frame_width),
            "frame_height": str(spec.frame_height),
            "frame_count": str(layout.get("frame_count", spec.frame_count)),
            "source_columns": str(layout.get("columns", spec.source_columns)),
            "source_rows": str(layout.get("rows", spec.source_rows)),
            "idle_fps": str(defaults["idle_fps"]),
            "idle_frame_index": str(defaults["idle_frame_index"]),
            "loop_idle": str(defaults["loop_idle"]),
            "content_hash": "phase38_" + hashlib.sha256(animation_set_id.encode("utf-8")).hexdigest()[:16],
        }
        return [CsvPatchPlan("content_source/csv/bubble_animation_sets/bubble_animation_sets.csv", "animation_set_id", [row])]


def _csv_has_key(path: Path, key_field: str, key_value: str) -> bool:
    if not path.exists():
        return False
    with path.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            if row.get(key_field, "") == key_value:
                return True
    return False
