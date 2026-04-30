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
    asset_type = "vfx_jelly_trap"

    def preflight(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> StageResult:
        result = StageResult(stage="plugin_preflight")
        if not package.manifest.content_ids.get("vfx_set_id"):
            result.fail("missing content_ids.vfx_set_id")
        defaults = spec.defaults
        expected_frames = {
            "enter": int(defaults["enter_frames"]),
            "loop": int(defaults["loop_frames"]),
            "release": int(defaults["release_frames"]),
        }
        for clip in spec.required_clips:
            relative = package.manifest.source_files.get(clip)
            if not relative:
                result.fail(f"missing source_files.{clip}")
                continue
            try:
                path = resolve_package_file(package.root, relative)
            except ValueError as exc:
                result.fail(str(exc))
                continue
            if not path.exists():
                result.fail(f"missing source file for {clip}: {relative}")
                continue
            try:
                info = read_png_info(path)
            except ValueError as exc:
                result.fail(str(exc))
                continue
            expected_width = (spec.frame_width or 0) * expected_frames[clip]
            expected_height = spec.frame_height or 0
            if info.width != expected_width or info.height != expected_height:
                result.fail(f"{clip} size {info.width}x{info.height}, expected {expected_width}x{expected_height}")
            if not info.has_alpha:
                result.fail(f"{clip} must be PNG with alpha channel")
        return result

    def build_csv_patch(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> list[CsvPatchPlan]:
        defaults = spec.defaults
        vfx_set_id = package.manifest.content_ids["vfx_set_id"]
        def asset_path(clip: str) -> str:
            value = package.manifest.source_files[clip].replace("\\", "/")
            return f"res://{package.root.relative_to(project_root).as_posix()}/{value}"
        row = {
            "vfx_set_id": vfx_set_id,
            "display_name": str(package.manifest.data.get("display_name", package.manifest.asset_key)),
            "enter_strip_path": asset_path("enter"),
            "loop_strip_path": asset_path("loop"),
            "release_strip_path": asset_path("release"),
            "frame_width": str(spec.frame_width),
            "frame_height": str(spec.frame_height),
            "enter_frames": str(defaults["enter_frames"]),
            "loop_frames": str(defaults["loop_frames"]),
            "release_frames": str(defaults["release_frames"]),
            "enter_fps": str(defaults["enter_fps"]),
            "loop_fps": str(defaults["loop_fps"]),
            "release_fps": str(defaults["release_fps"]),
            "pivot_x": str(defaults["pivot_x"]),
            "pivot_y": str(defaults["pivot_y"]),
            "layer": str(defaults["layer"]),
            "follow_actor": str(defaults["follow_actor"]),
            "content_hash": str(package.manifest.data.get("content_hash", vfx_set_id + "_phase38")),
        }
        return [CsvPatchPlan("content_source/csv/vfx_animation_sets/vfx_animation_sets.csv", "vfx_set_id", [row])]

