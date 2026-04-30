from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class AssetSpec:
    spec_id: str
    asset_type: str
    frame_width: int | None = None
    frame_height: int | None = None
    frame_count: int | None = None
    frames_per_direction: int | None = None
    source_columns: int | None = None
    source_rows: int | None = None
    cell_px: int | None = None
    required_clips: tuple[str, ...] = ()
    accepted_formats: tuple[str, ...] = ("png",)
    alpha_required: bool = True
    output_targets: tuple[str, ...] = ()
    defaults: dict[str, object] = field(default_factory=dict)


_SPECS: dict[str, AssetSpec] = {
    "character_sprite_100_v1": AssetSpec(
        spec_id="character_sprite_100_v1",
        asset_type="character",
        frame_width=100,
        frame_height=100,
        frames_per_direction=4,
        required_clips=("down", "left", "right", "up", "trapped_down", "victory_down", "defeat_down"),
        output_targets=("content_source/csv/character_animation_sets/character_animation_sets.csv",),
        defaults={
            "run_fps": 8,
            "idle_frame_index": 0,
            "pivot_x": 50,
            "pivot_y": 100,
            "pivot_adjust_x": 0,
            "pivot_adjust_y": -15,
            "loop_run": "true",
            "loop_idle": "false",
        },
    ),
    "bubble_animation_64_v1": AssetSpec(
        spec_id="bubble_animation_64_v1",
        asset_type="bubble",
        frame_width=64,
        frame_height=64,
        frame_count=16,
        source_columns=4,
        source_rows=4,
        required_clips=("idle_grid",),
        output_targets=("content_source/csv/bubble_animation_sets/bubble_animation_sets.csv",),
        defaults={"idle_fps": 10, "idle_frame_index": 0, "loop_idle": "true"},
    ),
    "map_tile_48_v1": AssetSpec(
        spec_id="map_tile_48_v1",
        asset_type="map_tile",
        cell_px=48,
        output_targets=("content_source/csv/tile_presentations/tile_presentations.csv",),
        defaults={"movement_pass_mask": 15, "blast_pass_mask": 15},
    ),
    "map_theme_48_v1": AssetSpec(
        spec_id="map_theme_48_v1",
        asset_type="map_theme",
        cell_px=48,
        output_targets=("content_source/csv/map_themes/map_themes.csv",),
    ),
    "vfx_jelly_trap_128_v1": AssetSpec(
        spec_id="vfx_jelly_trap_128_v1",
        asset_type="vfx_jelly_trap",
        frame_width=128,
        frame_height=128,
        required_clips=("enter", "loop", "release"),
        output_targets=("content_source/csv/vfx_animation_sets/vfx_animation_sets.csv",),
        defaults={
            "enter_frames": 6,
            "loop_frames": 8,
            "release_frames": 6,
            "enter_fps": 12,
            "loop_fps": 10,
            "release_fps": 12,
            "pivot_x": 64,
            "pivot_y": 108,
            "layer": "status_overlay",
            "follow_actor": "true",
        },
    ),
    "team_color_palette_v1": AssetSpec(
        spec_id="team_color_palette_v1",
        asset_type="team_color_palette",
        output_targets=("content_source/csv/team_colors/team_palettes.csv",),
    ),
    "emote_demo_v1": AssetSpec(
        spec_id="emote_demo_v1",
        asset_type="emote",
        output_targets=(),
    ),
}


def get_spec(spec_id: str) -> AssetSpec:
    try:
        return _SPECS[spec_id]
    except KeyError as exc:
        raise KeyError(f"unknown asset spec: {spec_id}") from exc


def all_specs() -> dict[str, AssetSpec]:
    return dict(_SPECS)
