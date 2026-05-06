#!/usr/bin/env python3
import argparse
import csv
import json
import struct
from pathlib import Path

CELL_SIZE = 40
IMAGE_EXTS = {".png", ".gif", ".jpg", ".jpeg", ".bmp"}


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
        return build_meta(width, height, 1, 1, "bottom_right", 0, 1.0, "floor", "")
    return build_meta(width, height, 1, 1, "bottom_right", 1, 1.0, "surface", "")


def build_meta(
    width: int,
    height: int,
    footprint_w: int,
    footprint_h: int,
    anchor_mode: str,
    draw_layer: int,
    confidence: float,
    visual_layer: str,
    review_reason: str,
) -> dict:
    anchor_x = float(width)
    return {
        "width": width,
        "height": height,
        "footprint_w": footprint_w,
        "footprint_h": footprint_h,
        "anchor_mode": anchor_mode,
        "anchor_x": anchor_x,
        "anchor_y": float(height),
        "draw_layer": draw_layer,
        "sort_mode": "row_asc_col_desc",
        "z_bias": 0,
        "visual_layer": visual_layer,
        "confidence": confidence,
        "review_reason": review_reason,
    }


def parse_elem_id(path: Path) -> str:
    stem = path.stem
    if "_" in stem:
        stem = stem.split("_", 1)[0]
    return stem.replace("elem", "")


def scan_assets(asset_root: Path) -> list[dict]:
    rows = []
    for path in sorted(asset_root.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in IMAGE_EXTS:
            continue
        if path.suffix.lower() == ".gif" and not path.stem.endswith("_stand"):
            continue
        theme = path.parent.name
        elem_key = f"{theme}/{path.stem}"
        width, height = read_image_size(path)
        meta = infer_meta(width, height)
        die_path = find_sibling_action_path(path, "die")
        trigger_path = find_sibling_action_path(path, "trigger")
        interaction_kind = "floor"
        if meta["visual_layer"] == "surface":
            if die_path:
                interaction_kind = "breakable"
            elif trigger_path:
                interaction_kind = "trigger_solid"
            else:
                interaction_kind = "solid"
        rows.append({
            "elem_key": elem_key,
            "theme": theme,
            "elem_id": parse_elem_id(path),
            "resource_path": "res://" + path.as_posix(),
            "die_resource_path": "res://" + die_path.as_posix() if die_path else "",
            "trigger_resource_path": "res://" + trigger_path.as_posix() if trigger_path else "",
            "interaction_kind": interaction_kind,
            **meta,
        })
    return rows


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
        "theme",
        "elem_id",
        "resource_path",
        "die_resource_path",
        "trigger_resource_path",
        "interaction_kind",
        "width",
        "height",
        "footprint_w",
        "footprint_h",
        "anchor_mode",
        "anchor_x",
        "anchor_y",
        "draw_layer",
        "sort_mode",
        "z_bias",
        "visual_layer",
        "confidence",
        "review_reason",
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
    parser.add_argument("--json-out", default="tools/qqtang_map_pipeline/generated/map_elem_visual_meta.json")
    args = parser.parse_args()

    rows = scan_assets(Path(args.asset_root))
    write_csv(Path(args.csv_out), rows)
    write_json(Path(args.json_out), rows)
    print(f"generated visual meta rows={len(rows)} csv={args.csv_out} json={args.json_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
