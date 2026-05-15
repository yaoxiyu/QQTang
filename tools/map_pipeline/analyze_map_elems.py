#!/usr/bin/env python3
import argparse
import csv
import json
import struct
from pathlib import Path

CELL_SIZE = 40
IMAGE_EXTS = {".png", ".gif", ".jpg", ".jpeg", ".bmp"}
DEFAULT_ELEM_OVERRIDES_CSV = Path("content_source/csv/maps/map_elem_overrides.csv")
SURFACE_ANCHOR_MODES = {"bottom_right", "bottom_left", "bottom_center"}
MOVEMENT_PASS_DIRS = {
    "none", "u", "d", "l", "r", "ud", "lr", "ul", "ur", "dl", "dr",
    "lur", "ldr", "uld", "urd", "udlr",
}
THEME_IDS = {
    "common": 1,
    "bomb": 2,
    "box": 3,
    "bun": 4,
    "desert": 5,
    "exploration": 6,
    "field": 7,
    "machine": 8,
    "match": 9,
    "mine": 10,
    "pig": 11,
    "practice": 12,
    "pve": 13,
    "sculpture": 14,
    "snow": 15,
    "tank": 16,
    "town": 17,
    "treasure": 18,
    "water": 19,
}
MODE_NAMES = {
    "bomb": "炸弹主题",
    "box": "宝箱主题",
    "bun": "包子主题",
    "common": "通用主题",
    "desert": "沙漠主题",
    "exploration": "探险主题",
    "field": "田园主题",
    "machine": "机械主题",
    "match": "比赛主题",
    "mine": "矿洞主题",
    "pig": "猪猪主题",
    "practice": "练习主题",
    "pve": "PVE主题",
    "sculpture": "雕塑主题",
    "snow": "冰雪主题",
    "tank": "坦克主题",
    "town": "小镇主题",
    "treasure": "宝藏主题",
    "water": "水域主题",
}


def read_image_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as f:
        header = f.read(32)
        if header.startswith(b"\x89PNG\r\n\x1a\n"):
            return struct.unpack(">II", header[16:24])
        if header[:6] in (b"GIF87a", b"GIF89a"):
            return struct.unpack("<HH", header[6:10])
        if header.startswith(b"BM"):
            f.seek(18)
            return struct.unpack("<ii", f.read(8))
        if header.startswith(b"\xff\xd8"):
            return read_jpeg_size(path)
    raise ValueError(f"unsupported image format: {path}")


def read_jpeg_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as f:
        f.read(2)
        while True:
            marker_prefix = f.read(1)
            if marker_prefix != b"\xff":
                raise ValueError(f"invalid jpeg marker: {path}")
            marker = f.read(1)
            while marker == b"\xff":
                marker = f.read(1)
            if marker in (b"\xc0", b"\xc1", b"\xc2", b"\xc3"):
                f.read(3)
                height, width = struct.unpack(">HH", f.read(4))
                return width, height
            length = struct.unpack(">H", f.read(2))[0]
            f.seek(length - 2, 1)


def infer_meta(width: int, height: int) -> dict:
    if width == CELL_SIZE and height == CELL_SIZE:
        return build_meta(
            width,
            height,
            1,
            1,
            0,
            0,
            "cell_fill_40x40",
            0,
            1.0,
            "floor",
            "floor_candidate_40x40",
            "",
        )
    if width <= 48 and height <= 68:
        geometry_type = "object_1x1_2p5d"
        confidence = 0.95
        review_reason = "default_surface_1x1"
    elif width <= 48 and height > 68:
        geometry_type = "tall_object_1xN"
        confidence = 0.65
        review_reason = "manual_override_required_if_visual_or_collision_exceeds_1x1"
    elif width % CELL_SIZE == 0 and height % CELL_SIZE == 0:
        geometry_type = "multi_cell_grid_exact"
        confidence = 0.86
        review_reason = "manual_override_required_for_multi_cell_visual_or_collision"
    elif width > 48 and height <= 68:
        geometry_type = "wide_object_or_horizontal_deco"
        confidence = 0.70
        review_reason = "manual_override_required_if_visual_or_collision_exceeds_1x1"
    else:
        geometry_type = "large_complex_object"
        confidence = 0.60
        review_reason = "manual_override_required_for_large_irregular_asset"
    return build_meta(
        width,
        height,
        1,
        1,
        1,
        1,
        "bottom_right",
        1,
        confidence,
        "surface",
        geometry_type,
        review_reason,
    )


def build_meta(
    width: int,
    height: int,
    footprint_w: int,
    footprint_h: int,
    collision_w: int,
    collision_h: int,
    anchor_mode: str,
    draw_layer: int,
    confidence: float,
    visual_layer: str,
    geometry_type: str,
    review_reason: str,
) -> dict:
    anchor_x = float(width)
    return {
        "width": width,
        "height": height,
        "footprint_w": footprint_w,
        "footprint_h": footprint_h,
        "collision_w": collision_w,
        "collision_h": collision_h,
        "anchor_mode": anchor_mode,
        "anchor_x": anchor_x,
        "anchor_y": float(height),
        "draw_layer": draw_layer,
        "sort_mode": "row_asc_col_desc",
        "z_bias": 0,
        "visual_layer": visual_layer,
        "geometry_type": geometry_type,
        "confidence": confidence,
        "review_reason": review_reason,
    }


def parse_elem_number(path: Path) -> int:
    stem = path.stem
    if "_" in stem:
        stem = stem.split("_", 1)[0]
    text = stem.replace("elem", "")
    return int(text) if text.isdigit() else 0


def parse_state(path: Path) -> str:
    stem = path.stem
    if "_" not in stem:
        return "unknown"
    state = stem.rsplit("_", 1)[1]
    return state if state in {"stand", "die", "trigger"} else "unknown"


def scan_assets(asset_root: Path) -> list[dict]:
    elem_overrides = read_elem_overrides(DEFAULT_ELEM_OVERRIDES_CSV)
    rows = []
    for path in sorted(asset_root.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in IMAGE_EXTS:
            continue
        theme = path.parent.name
        elem_key = f"{theme}/{path.stem}"
        width, height = read_image_size(path)
        meta = infer_meta(width, height)
        override = elem_overrides.get(elem_key, {})
        if override:
            meta.update(override)
        die_path = find_sibling_action_path(path, "die")
        trigger_path = find_sibling_action_path(path, "trigger")
        state = parse_state(path)
        override_logic_type = str(override.get("logic_type", "")).strip()
        if width == CELL_SIZE and height == CELL_SIZE or override_logic_type == "floor":
            meta["visual_layer"] = "floor"
            meta["logic_type"] = "floor"
            meta["footprint_w"] = max(1, int(meta.get("footprint_w", 1)))
            meta["footprint_h"] = max(1, int(meta.get("footprint_h", 1)))
            meta["collision_w"] = 0
            meta["collision_h"] = 0
            meta["anchor_mode"] = "cell_fill_40x40"
        else:
            meta["visual_layer"] = "surface"
        interaction_kind = "none"
        logic_type = str(meta.get("logic_type", ""))
        if meta["visual_layer"] == "surface":
            if state != "stand":
                interaction_kind = "none"
                logic_type = "decoration"
            elif override_logic_type in {"decoration", "breakable", "trigger"}:
                logic_type = override_logic_type
                if logic_type == "breakable":
                    interaction_kind = "breakable"
                elif logic_type == "trigger":
                    interaction_kind = "trigger_solid"
                else:
                    interaction_kind = "solid"
            elif die_path:
                logic_type = "breakable"
                interaction_kind = "breakable"
            elif trigger_path:
                logic_type = "trigger"
                interaction_kind = "trigger_solid"
            elif logic_type == "breakable":
                interaction_kind = "breakable"
            elif logic_type == "trigger":
                interaction_kind = "trigger_solid"
            else:
                interaction_kind = "solid"
                logic_type = "decoration"
        else:
            logic_type = "floor"
        rows.append({
            "elem_key": elem_key,
            "mode_id": theme,
            "mode_name": MODE_NAMES.get(theme, theme),
            "elem_id": f"elem{parse_elem_number(path)}" if parse_elem_number(path) > 0 else path.stem,
            "state": state,
            "resource_path": "res://" + path.as_posix(),
            "die_resource_path": "res://" + die_path.as_posix() if die_path else "",
            "trigger_resource_path": "res://" + trigger_path.as_posix() if trigger_path else "",
            "interaction_kind": interaction_kind,
            "logic_type": logic_type,
            **meta,
        })
    return rows


def read_elem_overrides(path: Path) -> dict[str, dict]:
    if not path.exists():
        return {}
    result: dict[str, dict] = {}
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            elem_key = str(row.get("elem_key", "")).strip()
            if not elem_key:
                continue
            override = {}
            logic_type = str(row.get("logic_type", "")).strip()
            if logic_type in {"floor", "decoration", "breakable", "trigger"}:
                override["logic_type"] = logic_type
            anchor_mode = str(row.get("anchor_mode", "")).strip()
            if anchor_mode in SURFACE_ANCHOR_MODES:
                override["anchor_mode"] = anchor_mode
            try:
                if str(row.get("footprint_w", "")).strip():
                    override["footprint_w"] = max(1, int(str(row.get("footprint_w", "")).strip()))
                if str(row.get("footprint_h", "")).strip():
                    override["footprint_h"] = max(1, int(str(row.get("footprint_h", "")).strip()))
                if str(row.get("collision_w", "")).strip():
                    override["collision_w"] = max(0, int(str(row.get("collision_w", "")).strip()))
                if str(row.get("collision_h", "")).strip():
                    override["collision_h"] = max(0, int(str(row.get("collision_h", "")).strip()))
            except ValueError:
                continue
            movement_pass_dirs = str(row.get("movement_pass_dirs", "")).strip().lower()
            if movement_pass_dirs in MOVEMENT_PASS_DIRS:
                override["movement_pass_dirs"] = movement_pass_dirs
            if override:
                result[elem_key] = override
    return result


def ensure_elem_override_csv(path: Path) -> None:
    if path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["elem_key", "footprint_w", "footprint_h", "collision_w", "collision_h", "logic_type", "anchor_mode", "movement_pass_dirs"],
        )
        writer.writeheader()


def build_map_element_rows(visual_rows: list[dict]) -> list[dict]:
    grouped: dict[tuple[str, int], dict[str, str]] = {}
    for row in visual_rows:
        theme = row["mode_id"]
        elem_number = parse_elem_number(Path(row["resource_path"]))
        if elem_number <= 0:
            continue
        key = (theme, elem_number)
        item = grouped.setdefault(
            key,
            {
                "element_id": str(THEME_IDS.get(theme, 99) * 100000 + elem_number),
                "display_name": f"{theme}_elem{elem_number}",
                "mode_id": theme,
                "mode_name": MODE_NAMES.get(theme, theme),
                "elem_number": str(elem_number),
                "logic_type": "1",
                "interact_type": "0",
                "source_dir": theme,
                "stand_file": "",
                "die_file": "",
                "trigger_file": "",
            },
        )
        file_name = Path(row["resource_path"]).name
        state = row["state"]
        if state == "stand":
            item["stand_file"] = file_name
            visual_layer = row["visual_layer"]
            logic_type = row["logic_type"]
            if logic_type == "breakable":
                item["logic_type"] = "3"
            elif logic_type == "trigger":
                item["logic_type"] = "4"
            elif logic_type == "decoration":
                item["logic_type"] = "1"
            elif visual_layer == "surface":
                item["logic_type"] = "1"
            else:
                item["logic_type"] = "1"
        elif state == "die":
            item["die_file"] = file_name
        elif state == "trigger":
            item["trigger_file"] = file_name
    return sorted(grouped.values(), key=lambda item: int(item["element_id"]))


def find_sibling_action_path(stand_path: Path, action: str) -> Path | None:
    base = stand_path.stem.removesuffix("_stand")
    for ext in sorted(IMAGE_EXTS):
        candidate = stand_path.with_name(f"{base}_{action}{ext}")
        if candidate.exists():
            return candidate
    return None


def write_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "elem_key",
        "mode_id",
        "mode_name",
        "elem_id",
        "state",
        "resource_path",
        "die_resource_path",
        "trigger_resource_path",
        "interaction_kind",
        "logic_type",
        "width",
        "height",
        "footprint_w",
        "footprint_h",
        "collision_w",
        "collision_h",
        "anchor_mode",
        "anchor_x",
        "anchor_y",
        "draw_layer",
        "sort_mode",
        "z_bias",
        "visual_layer",
        "geometry_type",
        "confidence",
        "review_reason",
        "movement_pass_dirs",
    ]
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_map_elements_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "element_id",
        "display_name",
        "mode_id",
        "mode_name",
        "elem_number",
        "logic_type",
        "interact_type",
        "source_dir",
        "stand_file",
        "die_file",
        "trigger_file",
    ]
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_json(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-root", default="external/assets/maps/elements")
    parser.add_argument("--csv-out", default="content_source/csv/maps/map_elem_visual_meta.csv")
    parser.add_argument("--json-out", default="tools/map_pipeline/generated/map_elem_visual_meta.json")
    parser.add_argument("--map-elements-out", default="content_source/csv/map_elements/map_elements.csv")
    args = parser.parse_args()

    ensure_elem_override_csv(DEFAULT_ELEM_OVERRIDES_CSV)
    rows = scan_assets(Path(args.asset_root))
    write_csv(Path(args.csv_out), rows)
    write_json(Path(args.json_out), rows)
    map_element_rows = build_map_element_rows(rows)
    write_map_elements_csv(Path(args.map_elements_out), map_element_rows)
    print(
        "generated visual meta rows=%d map_element rows=%d csv=%s json=%s"
        % (len(rows), len(map_element_rows), args.csv_out, args.json_out)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
