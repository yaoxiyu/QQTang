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
from tools.asset_pipeline.plugins.character.team_color_variant import TeamColor, parse_hex_color, recolor_image


class Plugin(AssetTypePlugin):
    asset_type = "character"

    def preflight(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> StageResult:
        result = StageResult(stage="plugin_preflight")
        expected_width = (spec.frame_width or 0) * (spec.frames_per_direction or 0)
        expected_height = spec.frame_height or 0
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
            if info.width != expected_width or info.height != expected_height:
                result.fail(f"{clip} size {info.width}x{info.height}, expected {expected_width}x{expected_height}")
            if spec.alpha_required and not info.has_alpha:
                result.fail(f"{clip} must be PNG with alpha channel")
        animation_set_id = package.manifest.content_ids.get("animation_set_id")
        if not animation_set_id:
            result.fail("missing content_ids.animation_set_id")
        elif _csv_has_key(project_root / "content_source/csv/character_animation_sets/character_animation_sets.csv", "animation_set_id", animation_set_id):
            result.warn(f"animation_set_id already exists and will be updated: {animation_set_id}")
        self._validate_team_masks(package, spec, result)
        return result

    def build_csv_patch(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> list[CsvPatchPlan]:
        defaults = spec.defaults
        animation_set_id = package.manifest.content_ids["animation_set_id"]
        display_name = str(package.manifest.data.get("display_name", package.manifest.asset_key))
        def asset_path(clip: str) -> str:
            value = package.manifest.source_files[clip].replace("\\", "/")
            return f"res://{package.root.relative_to(project_root).as_posix()}/{value}"

        rows = [self._build_animation_row(package, spec, project_root, animation_set_id, display_name, package.manifest.source_files)]
        team_color = package.manifest.data.get("team_color", {})
        pipeline = package.manifest.data.get("pipeline", {})
        generate_team_colors = bool(pipeline.get("generate_team_colors", False)) if isinstance(pipeline, dict) else False
        if isinstance(team_color, dict) and generate_team_colors:
            for team in _load_team_palette(project_root, str(team_color.get("palette_id", "team_palette_default_8"))):
                team_id_text = f"team_{team.team_id:02d}"
                variant_id = f"{animation_set_id}_{team_id_text}"
                source_files = {clip: f"assets/generated/animation/characters/{package.manifest.asset_key}/{team_id_text}/{clip}.png" for clip in spec.required_clips}
                rows.append(self._build_animation_row(package, spec, project_root, variant_id, f"{display_name} {team_id_text}", source_files, project_relative=True))
        return [CsvPatchPlan("content_source/csv/character_animation_sets/character_animation_sets.csv", "animation_set_id", rows)]

    def generate_variants(self, package: AssetPackage, spec: AssetSpec, project_root: Path) -> StageResult:
        result = StageResult(stage="generate_variants")
        team_color = package.manifest.data.get("team_color", {})
        if not isinstance(team_color, dict) or team_color.get("mode") != "mask_palette":
            result.warn("team_color.mode is not mask_palette; no variants generated")
            return result
        palette_id = str(team_color.get("palette_id", "team_palette_default_8"))
        mask_files = team_color.get("mask_files", {})
        if not isinstance(mask_files, dict):
            result.fail("team_color.mask_files must be an object")
            return result
        for team in _load_team_palette(project_root, palette_id):
            team_id_text = f"team_{team.team_id:02d}"
            for clip in spec.required_clips:
                source_path = resolve_package_file(package.root, package.manifest.source_files[clip])
                mask_path = resolve_package_file(package.root, str(mask_files[clip]))
                output_path = project_root / "assets" / "generated" / "animation" / "characters" / package.manifest.asset_key / team_id_text / f"{clip}.png"
                recolor_image(source_path, mask_path, output_path, team)
                result.outputs.append(str(output_path.relative_to(project_root)))
        return result

    def _validate_team_masks(self, package: AssetPackage, spec: AssetSpec, result: StageResult) -> None:
        team_color = package.manifest.data.get("team_color", {})
        pipeline = package.manifest.data.get("pipeline", {})
        generate_team_colors = bool(pipeline.get("generate_team_colors", False)) if isinstance(pipeline, dict) else False
        if not isinstance(team_color, dict) or not generate_team_colors:
            return
        mask_files = team_color.get("mask_files", {})
        if not isinstance(mask_files, dict):
            result.fail("team_color.mask_files must be an object when generate_team_colors is true")
            return
        for clip in spec.required_clips:
            mask_relative = mask_files.get(clip)
            if not mask_relative:
                result.fail(f"missing team_color.mask_files.{clip}")
                continue
            try:
                source_path = resolve_package_file(package.root, package.manifest.source_files[clip])
                mask_path = resolve_package_file(package.root, str(mask_relative))
            except ValueError as exc:
                result.fail(str(exc))
                continue
            if not mask_path.exists():
                result.fail(f"missing team color mask for {clip}: {mask_relative}")
                continue
            source_info = read_png_info(source_path)
            mask_info = read_png_info(mask_path)
            if source_info.width != mask_info.width or source_info.height != mask_info.height:
                result.fail(f"mask {clip} size {mask_info.width}x{mask_info.height}, expected {source_info.width}x{source_info.height}")
            if not mask_info.has_alpha:
                result.fail(f"mask {clip} must be PNG with alpha channel")

    def _build_animation_row(
        self,
        package: AssetPackage,
        spec: AssetSpec,
        project_root: Path,
        animation_set_id: str,
        display_name: str,
        source_files: dict[str, str],
        project_relative: bool = False,
    ) -> dict[str, str]:
        defaults = spec.defaults
        def asset_path(clip: str) -> str:
            value = source_files[clip].replace("\\", "/")
            if project_relative:
                return f"res://{value}"
            return f"res://{package.root.relative_to(project_root).as_posix()}/{value}"
        content_hash = hashlib.sha256(animation_set_id.encode("utf-8")).hexdigest()[:16]
        return {
            "animation_set_id": animation_set_id,
            "display_name": display_name,
            "down_strip_path": asset_path("down"),
            "left_strip_path": asset_path("left"),
            "right_strip_path": asset_path("right"),
            "up_strip_path": asset_path("up"),
            "frame_width": str(spec.frame_width),
            "frame_height": str(spec.frame_height),
            "frames_per_direction": str(spec.frames_per_direction),
            "run_fps": str(defaults["run_fps"]),
            "idle_frame_index": str(defaults["idle_frame_index"]),
            "pivot_x": str(defaults["pivot_x"]),
            "pivot_y": str(defaults["pivot_y"]),
            "pivot_adjust_x": str(defaults["pivot_adjust_x"]),
            "pivot_adjust_y": str(defaults["pivot_adjust_y"]),
            "loop_run": str(defaults["loop_run"]),
            "loop_idle": str(defaults["loop_idle"]),
            "trapped_down_strip_path": asset_path("trapped_down"),
            "victory_down_strip_path": asset_path("victory_down"),
            "defeat_down_strip_path": asset_path("defeat_down"),
            "content_hash": "phase38_" + content_hash,
        }


def _csv_has_key(path: Path, key_field: str, key_value: str) -> bool:
    if not path.exists():
        return False
    with path.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            if row.get(key_field, "") == key_value:
                return True
    return False


def _load_team_palette(project_root: Path, palette_id: str) -> list[TeamColor]:
    palette_path = project_root / "content_source/csv/team_colors/team_palettes.csv"
    if not palette_path.exists():
        raise FileNotFoundError(f"missing team palette csv: {palette_path}")
    colors: list[TeamColor] = []
    with palette_path.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            if row.get("palette_id") != palette_id:
                continue
            colors.append(
                TeamColor(
                    team_id=int(row["team_id"]),
                    team_color_id=row["team_color_id"],
                    primary=parse_hex_color(row["primary_hex"]),
                    secondary=parse_hex_color(row["secondary_hex"]),
                    shadow=parse_hex_color(row["shadow_hex"]),
                    highlight=parse_hex_color(row["highlight_hex"]),
                )
            )
    colors.sort(key=lambda item: item.team_id)
    if [color.team_id for color in colors] != list(range(1, 9)):
        raise ValueError(f"palette {palette_id} must contain team_id 1..8")
    return colors
