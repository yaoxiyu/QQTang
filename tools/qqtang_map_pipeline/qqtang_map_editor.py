#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
QQTang Map Editor - 基于 QQ堂 mapElem 资源的 2.5D 地图编辑器

依赖：
    pip install pillow

运行：
    python qqtang_map_editor.py --asset-root /path/to/QQTangExtracted-master/QQTang5.2_Beta1Build1
    python qqtang_map_editor.py --zip /path/to/QQTangExtracted-master.zip

设计原则：
    1. 地面层仅使用 40×40 资源，支持 40×40 范围内像素外扩。
    2. 表现层使用 2.5D Sprite 锚点渲染，bottom_right 对齐逻辑格。
    3. 表现层每次编辑后全量重排渲染，排序为 row 升序、col 降序。
    4. 地面层未铺满时不允许编辑表现层，避免透明缝隙直接露底。
    5. 一键导出 JSON 配置和 PNG 预览，方便运行时读取和复现。
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import shutil
import sys
import tempfile
import zipfile
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Dict, List, Optional, Tuple

try:
    import tkinter as tk
    from tkinter import ttk, filedialog, messagebox
except Exception as exc:  # pragma: no cover
    print("Tkinter is required to run the editor UI.", exc)
    raise

try:
    from PIL import Image, ImageTk, ImageDraw, ImageSequence
except Exception as exc:  # pragma: no cover
    print("Pillow is required. Install with: pip install pillow", exc)
    raise

CELL_SIZE = 40
DEFAULT_COLS = 15
DEFAULT_ROWS = 13
PREVIEW_MARGIN_TOP = 72
PREVIEW_MARGIN_LEFT = 20
ASSET_EXTS = {".png", ".gif", ".jpg", ".jpeg", ".bmp"}
REPO_ROOT = Path(__file__).resolve().parents[2]
OFFICIAL_MAPS_CSV = REPO_ROOT / "content_source/csv/maps/maps.csv"
OFFICIAL_VARIANTS_CSV = REPO_ROOT / "content_source/csv/maps/map_match_variants.csv"
OFFICIAL_FLOOR_CSV = REPO_ROOT / "content_source/csv/maps/map_floor_tiles.csv"
OFFICIAL_SURFACE_CSV = REPO_ROOT / "content_source/csv/maps/map_surface_instances.csv"
OFFICIAL_CHANNEL_CSV = REPO_ROOT / "content_source/csv/maps/map_channel_instances.csv"
OFFICIAL_VISUAL_META_CSV = REPO_ROOT / "content_source/csv/maps/map_elem_visual_meta.csv"
OFFICIAL_ELEM_OVERRIDES_CSV = REPO_ROOT / "content_source/csv/maps/map_elem_overrides.csv"
OFFICIAL_MATCH_FORMATS_CSV = REPO_ROOT / "content_source/csv/match_formats/match_formats.csv"
OFFICIAL_MODES_CSV = REPO_ROOT / "content_source/csv/modes/modes.csv"
OFFICIAL_RULESETS_CSV = REPO_ROOT / "content_source/csv/rulesets/rulesets.csv"
OFFICIAL_PREVIEW_DIR = REPO_ROOT / "content/maps/previews"
MATCH_FORMAT_1V1 = "1v1"
MATCH_FORMAT_DUO = str(2) + "v" + str(2)
MATCH_FORMAT_4V4 = "4v4"
LOGIC_TYPE_LABELS = {
    "floor": "地面",
    "decoration": "纯装饰",
    "breakable": "可破坏",
    "trigger": "可触发",
}
LOGIC_TYPE_ORDER = ["floor", "decoration", "breakable", "trigger"]
SURFACE_ANCHOR_LABELS = {
    "bottom_right": "右下角",
    "bottom_left": "左下角",
    "bottom_center": "底部中心",
    "center": "完全中心",
}
SURFACE_ANCHOR_ORDER = ["bottom_right", "bottom_left", "bottom_center", "center"]
MOVEMENT_PASS_DIRS_ORDER = ["none", "u", "d", "l", "r", "ud", "lr", "ul", "ur", "dl", "dr", "lur", "ldr", "uld", "urd", "udlr"]
MOVEMENT_PASS_DIRS_LABELS = {
    "none": "全碰撞",
    "u": "上向可通",
    "d": "下向可通",
    "l": "左向可通",
    "r": "右向可通",
    "ud": "上下可通",
    "lr": "左右可通",
    "ul": "上左可通",
    "ur": "上右可通",
    "dl": "下左可通",
    "dr": "下右可通",
    "lur": "左上右可通",
    "ldr": "左下右可通",
    "uld": "上左下可通",
    "urd": "上右下可通",
    "udlr": "四向全通",
}


@dataclass
class AssetMeta:
    key: str
    theme: str
    elem_id: str
    state: str
    rel_path: str
    abs_path: str
    width: int
    height: int
    frames: int
    ext: str
    logical_type: str
    geometry_type: str
    layer_hint: str
    footprint_w: int
    footprint_h: int
    collision_w: int
    collision_h: int
    movement_pass_dirs: str
    anchor_mode: str
    anchor_x: float
    anchor_y: float
    confidence: float
    review_reason: str


def classify_asset(width: int, height: int, state: str) -> Tuple[str, str, int, int, int, int, str, float, str]:
    """正式规则：40x40 是地面；其它默认表现层 1x1，特殊占格/碰撞只能走人工 override。"""
    if width == CELL_SIZE and height == CELL_SIZE:
        return (
            "floor_candidate_40x40",
            "floor",
            1,
            1,
            0,
            0,
            "cell_fill_40x40",
            0.98,
            "exact_40x40_floor_candidate",
        )
    if width <= 48 and height <= 68:
        geometry_type = "object_1x1_2p5d"
        confidence = 0.95
        review = "default_surface_1x1"
    elif width % CELL_SIZE == 0 and height % CELL_SIZE == 0:
        geometry_type = "multi_cell_grid_exact"
        confidence = 0.86
        review = "manual_override_required_for_multi_cell_visual_or_collision"
    elif width <= 48:
        geometry_type = "tall_object_1xN"
        confidence = 0.65
        review = "manual_override_required_if_visual_or_collision_exceeds_1x1"
    elif height <= 68:
        geometry_type = "wide_object_or_horizontal_deco"
        confidence = 0.70
        review = "manual_override_required_if_visual_or_collision_exceeds_1x1"
    else:
        geometry_type = "large_complex_object"
        confidence = 0.60
        review = "manual_override_required_for_large_irregular_asset"
    return (
        geometry_type,
        "surface",
        1,
        1,
        1,
        1,
        "bottom_right",
        confidence,
        review,
    )


def parse_elem_name(path: Path) -> Tuple[str, str]:
    stem = path.stem
    # 兼容 elem1_stand、elem1_die、elem1_trigger、极少数异常命名。
    m = re.match(r"(elem\d+)(?:_(.*))?$", stem)
    if not m:
        return stem, "unknown"
    elem_id = m.group(1)
    state = m.group(2) if m.group(2) else "unknown"
    return elem_id, state


def find_sibling_action_path(path: Path, action: str) -> Optional[Path]:
    base = path.stem.removesuffix("_stand").removesuffix("_die").removesuffix("_trigger")
    for ext in sorted(ASSET_EXTS):
        candidate = path.with_name(f"{base}_{action}{ext}")
        if candidate.exists():
            return candidate
    return None


def infer_logic_type(layer_hint: str, state: str, path: Path) -> str:
    if layer_hint == "floor":
        return "floor"
    if state == "stand":
        if find_sibling_action_path(path, "die") is not None:
            return "breakable"
        if find_sibling_action_path(path, "trigger") is not None:
            return "trigger"
    return "decoration"


def logic_type_label(logic_type: str) -> str:
    return LOGIC_TYPE_LABELS.get(logic_type, logic_type)


def find_data_root(path: Path) -> Optional[Path]:
    """接受 zip 解包根、仓库根或 QQTang5.2_Beta1Build1 根，定位 data/object/mapElem 所在版本根。"""
    path = path.resolve()
    candidates = [
        path,
        path / "QQTang5.2_Beta1Build1",
        path / "QQTangExtracted-master" / "QQTang5.2_Beta1Build1",
    ]
    for candidate in candidates:
        if (candidate / "data" / "object" / "mapElem").exists():
            return candidate
    for p in path.rglob("mapElem"):
        if p.is_dir() and p.parent.name == "object" and p.parent.parent.name == "data":
            return p.parent.parent.parent
    return None


def is_map_elem_root(path: Path) -> bool:
    if not path.exists() or not path.is_dir():
        return False
    for child in path.iterdir():
        if child.is_dir() and any(p.suffix.lower() in ASSET_EXTS for p in child.iterdir() if p.is_file()):
            return True
    return False


def extract_zip(zip_path: Path) -> Path:
    cache_dir = Path.home() / ".qqtang_map_editor_cache" / zip_path.stem
    marker = cache_dir / ".extract_done"
    if marker.exists():
        return cache_dir
    if cache_dir.exists():
        shutil.rmtree(cache_dir)
    cache_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "r") as zf:
        zf.extractall(cache_dir)
    marker.write_text("ok", encoding="utf-8")
    return cache_dir


def scan_assets(version_root: Path) -> List[AssetMeta]:
    map_elem_root = version_root / "data" / "object" / "mapElem"
    if not map_elem_root.exists():
        map_elem_root = version_root
    elem_overrides = load_elem_overrides()
    assets: List[AssetMeta] = []
    for path in sorted(map_elem_root.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in ASSET_EXTS:
            continue
        try:
            im = Image.open(path)
            width, height = im.size
            frames = getattr(im, "n_frames", 1)
        except Exception:
            continue
        rel = path.relative_to(map_elem_root).as_posix()
        parts = rel.split("/")
        if len(parts) < 2:
            continue
        theme = parts[0]
        elem_id, state = parse_elem_name(path)
        geometry_type, layer_hint, fp_w, fp_h, collision_w, collision_h, anchor, confidence, review = classify_asset(width, height, state)
        key = f"{theme}/{path.stem}"
        override = elem_overrides.get(key, {})
        if override:
            fp_w = int(override.get("footprint_w", fp_w))
            fp_h = int(override.get("footprint_h", fp_h))
            collision_w = int(override.get("collision_w", collision_w))
            collision_h = int(override.get("collision_h", collision_h))
            anchor = str(override.get("anchor_mode", anchor))
        movement_pass_dirs = str(override.get("movement_pass_dirs", "none")).strip().lower()
        if movement_pass_dirs not in MOVEMENT_PASS_DIRS_ORDER:
            movement_pass_dirs = "none"
        override_logic_type = str(override.get("logic_type", "")).strip()
        if width == CELL_SIZE and height == CELL_SIZE or override_logic_type == "floor":
            layer_hint = "floor"
            logical_type = "floor"
            fp_w = max(1, fp_w)
            fp_h = max(1, fp_h)
            collision_w = 0
            collision_h = 0
            anchor = "cell_fill_40x40"
        else:
            layer_hint = "surface"
            logical_type = override_logic_type if override_logic_type in LOGIC_TYPE_ORDER else infer_logic_type(layer_hint, state, path)
            if anchor not in SURFACE_ANCHOR_ORDER:
                anchor = "bottom_right"
        anchor_x = float(width)
        anchor_y = float(height)
        assets.append(
            AssetMeta(
                key=key,
                theme=theme,
                elem_id=elem_id,
                state=state,
                rel_path=rel,
                abs_path=str(path),
                width=width,
                height=height,
                frames=frames,
                ext=path.suffix.lower(),
                logical_type=logical_type,
                geometry_type=geometry_type,
                layer_hint=layer_hint,
                footprint_w=fp_w,
                footprint_h=fp_h,
                collision_w=collision_w,
                collision_h=collision_h,
                movement_pass_dirs=movement_pass_dirs,
                anchor_mode=anchor,
                anchor_x=anchor_x,
                anchor_y=anchor_y,
                confidence=confidence,
                review_reason=review,
            )
        )
    return assets


def load_elem_overrides() -> Dict[str, dict]:
    result: Dict[str, dict] = {}
    if not OFFICIAL_ELEM_OVERRIDES_CSV.exists():
        return result
    try:
        _fieldnames, rows = read_csv_rows(OFFICIAL_ELEM_OVERRIDES_CSV)
    except Exception:
        return result
    for row in rows:
        elem_key = str(row.get("elem_key", "")).strip()
        if not elem_key:
            continue
        item: dict = {}
        logic_type = str(row.get("logic_type", "")).strip()
        if logic_type in LOGIC_TYPE_ORDER:
            item["logic_type"] = logic_type
        anchor_mode = str(row.get("anchor_mode", "")).strip()
        if anchor_mode in SURFACE_ANCHOR_ORDER:
            item["anchor_mode"] = anchor_mode
        movement_pass_dirs = str(row.get("movement_pass_dirs", "")).strip().lower()
        if movement_pass_dirs in MOVEMENT_PASS_DIRS_ORDER:
            item["movement_pass_dirs"] = movement_pass_dirs
        for field in ("footprint_w", "footprint_h", "collision_w", "collision_h"):
            raw = str(row.get(field, "")).strip()
            if not raw:
                continue
            try:
                item[field] = max(0 if field.startswith("collision") else 1, int(raw))
            except ValueError:
                pass
        if item:
            result[elem_key] = item
    return result


def first_frame_rgba(path: str) -> Image.Image:
    im = Image.open(path)
    if getattr(im, "is_animated", False):
        im.seek(0)
    return im.convert("RGBA")


def expand_floor_tile_to_40(img: Image.Image, passes: int = 4) -> Image.Image:
    """地面像素外扩：只在 40×40 内把透明像素用邻近非透明像素补齐，避免 tile 采样缝。"""
    img = img.convert("RGBA")
    if img.size != (CELL_SIZE, CELL_SIZE):
        img = img.resize((CELL_SIZE, CELL_SIZE), Image.Resampling.NEAREST)
    pix = img.load()
    for _ in range(passes):
        updates = []
        for y in range(CELL_SIZE):
            for x in range(CELL_SIZE):
                if pix[x, y][3] != 0:
                    continue
                neighbors = []
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < CELL_SIZE and 0 <= ny < CELL_SIZE and pix[nx, ny][3] != 0:
                        neighbors.append(pix[nx, ny])
                if neighbors:
                    # 取第一个邻近不透明像素，避免平均色引入脏边。
                    r, g, b, _ = neighbors[0]
                    updates.append((x, y, (r, g, b, 255)))
        if not updates:
            break
        for x, y, color in updates:
            pix[x, y] = color
    return img


class AssetStore:
    def __init__(self, assets: List[AssetMeta]):
        self.assets = assets
        self.by_key: Dict[str, AssetMeta] = {a.key: a for a in assets}
        self._image_cache: Dict[str, Image.Image] = {}
        self._thumb_cache: Dict[Tuple[str, int], ImageTk.PhotoImage] = {}
        self._floor_cache: Dict[str, Image.Image] = {}

    @property
    def themes(self) -> List[str]:
        return sorted({a.theme for a in self.assets})

    @property
    def logical_types(self) -> List[str]:
        available = {a.logical_type for a in self.assets}
        ordered = [logic_type_label(item) for item in LOGIC_TYPE_ORDER if item in available]
        extras = sorted(logic_type_label(item) for item in available if item not in LOGIC_TYPE_ORDER)
        return ordered + extras

    def image(self, key: str) -> Image.Image:
        if key not in self._image_cache:
            self._image_cache[key] = first_frame_rgba(self.by_key[key].abs_path)
        return self._image_cache[key]

    def floor_image(self, key: str) -> Image.Image:
        if key not in self._floor_cache:
            self._floor_cache[key] = expand_floor_tile_to_40(self.image(key))
        return self._floor_cache[key]

    def thumb(self, key: str, size: int = 40) -> ImageTk.PhotoImage:
        cache_key = (key, size)
        if cache_key in self._thumb_cache:
            return self._thumb_cache[cache_key]
        im = self.image(key).copy()
        im.thumbnail((size, size), Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        canvas.alpha_composite(im, ((size - im.width) // 2, (size - im.height) // 2))
        tk_img = ImageTk.PhotoImage(canvas)
        self._thumb_cache[cache_key] = tk_img
        return tk_img

    def filtered(self, theme: str, logical_type: str, layer: str, search: str, include_animated: bool) -> List[AssetMeta]:
        search = search.strip().lower()
        result = []
        for a in self.assets:
            if theme != "全部" and a.theme != theme:
                continue
            if logical_type != "全部" and logic_type_label(a.logical_type) != logical_type:
                continue
            if not include_animated and a.state not in ("stand", "unknown"):
                continue
            if layer == "floor" and a.layer_hint != "floor":
                continue
            if layer == "surface":
                # 表现层默认不显示地面资产，除非用户手动在逻辑类型选择它。
                if logical_type == "全部" and a.logical_type == "floor":
                    continue
            if search and search not in a.key.lower() and search not in a.elem_id.lower():
                continue
            result.append(a)
        return result[:500]


@dataclass
class FloorInstance:
    asset_key: str
    x: int
    y: int
    w: int
    h: int


@dataclass
class SurfaceInstance:
    asset_key: str
    x: int
    y: int
    z_bias: int = 0
    footprint_w: int = 1
    footprint_h: int = 1


class MapModel:
    def __init__(self, cols: int = DEFAULT_COLS, rows: int = DEFAULT_ROWS):
        self.cols = cols
        self.rows = rows
        self.name = "new_map"
        self.mode = "box"
        self.rule = "ruleset_classic"
        self.floor: List[List[Optional[str]]] = [[None for _ in range(cols)] for _ in range(rows)]
        self.floor_instances: Dict[Tuple[int, int], FloorInstance] = {}
        self.surface: Dict[Tuple[int, int], SurfaceInstance] = {}
        self.channels: Dict[Tuple[int, int], Dict[str, object]] = {}
        self.spawns: List[Tuple[int, int]] = []

    def is_floor_complete(self) -> bool:
        return all(self.floor[y][x] for y in range(self.rows) for x in range(self.cols))

    def to_config(self, store: AssetStore) -> dict:
        surface_instances = []
        for inst in sorted(self.surface.values(), key=lambda i: (i.y, -i.x, i.z_bias)):
            meta = store.by_key[inst.asset_key]
            surface_instances.append(
                {
                    "asset_key": inst.asset_key,
                    "cell_x": inst.x,
                    "cell_y": inst.y,
                    "footprint_w": inst.footprint_w,
                    "footprint_h": inst.footprint_h,
                    "anchor_mode": meta.anchor_mode,
                    "z_bias": inst.z_bias,
                    "sort_key": [inst.y, -inst.x, inst.z_bias],
                }
            )
        return {
            "schema_version": 1,
            "map": {
                "name": self.name,
                "mode": self.mode,
                "rule": self.rule,
                "cols": self.cols,
                "rows": self.rows,
                "cell_size": CELL_SIZE,
            },
                "render_rules": {
                "floor": "fill_40x40_with_optional_pixel_expansion",
                "surface_anchor": "default_bottom_right_override_bottom_left_or_bottom_center_or_center",
                "surface_sort": "row_asc_col_desc_z_bias",
                "surface_sort_formula": "sort_key=(layer,row,-col,z_bias)",
            },
            "layers": {
                "floor": [
                    asdict(inst)
                    for inst in sorted(self.floor_instances.values(), key=lambda item: (item.y, item.x))
                ],
                "surface": surface_instances,
                "channels": [{
                    "x": x,
                    "y": y,
                    "movement_pass_dirs": str(channel.get("movement_pass_dirs", "none")),
                    "allow_place_bubble": bool(channel.get("allow_place_bubble", True)),
                } for (x, y), channel in sorted(self.channels.items(), key=lambda item: (item[0][1], item[0][0]))],
                "spawns": [{"x": x, "y": y, "player_index": i + 1} for i, (x, y) in enumerate(self.spawns)],
            },
        }


def to_map_id(name: str) -> str:
    base = re.sub(r"[^a-zA-Z0-9_]+", "_", name.strip().lower()).strip("_")
    if not base:
        base = "new_map"
    if not base.startswith("map_"):
        base = "map_" + base
    return base


def is_editor_map_row(row: dict) -> bool:
    preview_path = str(row.get("preview_image_path", ""))
    return preview_path.startswith("res://content/maps/previews/") and str(row.get("sort_order", "")) == "100"


def list_editor_map_rows() -> list[dict]:
    if not OFFICIAL_MAPS_CSV.exists():
        return []
    _fieldnames, rows = read_csv_rows(OFFICIAL_MAPS_CSV)
    return [row for row in rows if is_editor_map_row(row)]


def delete_official_map(map_id: str) -> None:
    map_id = map_id.strip()
    if not map_id:
        return
    _fieldnames, rows = read_csv_rows(OFFICIAL_MAPS_CSV)
    target_rows = [row for row in rows if row.get("map_id", "") == map_id]
    if not target_rows:
        raise ValueError(f"map not found: {map_id}")
    if not is_editor_map_row(target_rows[0]):
        raise ValueError(f"only editor generated maps can be deleted: {map_id}")
    preview_resource_path = str(target_rows[0].get("preview_image_path", ""))
    remove_csv_rows(OFFICIAL_MAPS_CSV, lambda row: row.get("map_id", "") == map_id)
    remove_csv_rows(OFFICIAL_VARIANTS_CSV, lambda row: row.get("map_id", "") == map_id)
    remove_csv_rows(OFFICIAL_FLOOR_CSV, lambda row: row.get("map_id", "") == map_id)
    remove_csv_rows(OFFICIAL_SURFACE_CSV, lambda row: row.get("map_id", "") == map_id)
    remove_csv_rows(OFFICIAL_CHANNEL_CSV, lambda row: row.get("map_id", "") == map_id)
    prefix = "res://content/maps/previews/"
    if preview_resource_path.startswith(prefix):
        preview_path = OFFICIAL_PREVIEW_DIR / preview_resource_path.removeprefix(prefix)
        if preview_path.exists():
            preview_path.unlink()
        import_path = preview_path.with_suffix(preview_path.suffix + ".import")
        if import_path.exists():
            import_path.unlink()


def parse_spawn_points(text: str) -> list[tuple[int, int]]:
    result: list[tuple[int, int]] = []
    for item in text.split(";"):
        parts = item.strip().split(":")
        if len(parts) != 2:
            continue
        try:
            result.append((int(parts[0]), int(parts[1])))
        except ValueError:
            continue
    return result


def load_official_map_model(map_id: str, store: "AssetStore") -> MapModel:
    _map_fields, map_rows = read_csv_rows(OFFICIAL_MAPS_CSV)
    map_row = next((row for row in map_rows if row.get("map_id", "") == map_id), None)
    if map_row is None:
        raise ValueError(f"map not found: {map_id}")
    if not is_editor_map_row(map_row):
        raise ValueError(f"only editor generated maps can be opened: {map_id}")
    cols = int(map_row.get("width", "15") or "15")
    rows = int(map_row.get("height", "13") or "13")
    model = MapModel(cols, rows)
    model.name = str(map_row.get("display_name", map_id)).strip() or map_id
    model.mode = str(map_row.get("bound_mode_id", map_row.get("theme_id", "box"))).strip() or "box"
    model.rule = str(map_row.get("bound_rule_set_id", "ruleset_classic")).strip() or "ruleset_classic"
    model.spawns = parse_spawn_points(str(map_row.get("spawn_points", "")))

    _floor_fields, floor_rows = read_csv_rows(OFFICIAL_FLOOR_CSV)
    for row in floor_rows:
        if row.get("map_id", "") != map_id:
            continue
        elem_key = str(row.get("elem_key", "")).strip()
        if elem_key not in store.by_key:
            continue
        x = int(row.get("x", "0") or "0")
        y = int(row.get("y", "0") or "0")
        w = max(1, int(row.get("w", "1") or "1"))
        h = max(1, int(row.get("h", "1") or "1"))
        for dy in range(h):
            for dx in range(w):
                tx = x + dx
                ty = y + dy
                if 0 <= tx < cols and 0 <= ty < rows:
                    model.floor[ty][tx] = elem_key
        model.floor_instances[(x, y)] = FloorInstance(elem_key, x, y, w, h)

    _surface_fields, surface_rows = read_csv_rows(OFFICIAL_SURFACE_CSV)
    for row in surface_rows:
        if row.get("map_id", "") != map_id:
            continue
        elem_key = str(row.get("elem_key", "")).strip()
        if elem_key not in store.by_key:
            continue
        x = int(row.get("x", "0") or "0")
        y = int(row.get("y", "0") or "0")
        z_bias = int(row.get("z_bias", "0") or "0")
        meta = store.by_key[elem_key]
        fp_w = max(1, meta.footprint_w)
        fp_h = max(1, meta.footprint_h)
        if 0 <= x < cols and 0 <= y < rows:
            model.surface[(x, y)] = SurfaceInstance(elem_key, x, y, z_bias, fp_w, fp_h)
    _channel_fields, channel_rows = read_csv_rows(OFFICIAL_CHANNEL_CSV)
    for row in channel_rows:
        if row.get("map_id", "") != map_id:
            continue
        x = int(row.get("x", "0") or "0")
        y = int(row.get("y", "0") or "0")
        dirs = str(row.get("movement_pass_dirs", "none")).strip().lower()
        allow_place_bubble = str(row.get("allow_place_bubble", "true")).strip().lower() not in ("false", "0", "no")
        if dirs not in MOVEMENT_PASS_DIRS_ORDER:
            dirs = "none"
        if 0 <= x < cols and 0 <= y < rows:
            model.channels[(x, y)] = {"movement_pass_dirs": dirs, "allow_place_bubble": allow_place_bubble}
    return model


def sync_official_map_csv(config: dict, preview_png_path: Path, previous_map_id: Optional[str] = None) -> str:
    map_info = config["map"]
    map_id = to_map_id(str(map_info["name"]))
    display_name = str(map_info["name"]).strip() or map_id
    cols = int(map_info["cols"])
    rows = int(map_info["rows"])
    spawns = config["layers"]["spawns"]
    if len(spawns) < 2:
        raise ValueError("formal map export requires at least 2 spawn points")
    if previous_map_id and previous_map_id != map_id:
        _fieldnames, existing_rows = read_csv_rows(OFFICIAL_MAPS_CSV)
        if any(row.get("map_id", "") == map_id for row in existing_rows):
            raise ValueError(f"target map id already exists: {map_id}")
        delete_official_map(previous_map_id)

    OFFICIAL_PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    official_preview_path = OFFICIAL_PREVIEW_DIR / f"{map_id}.preview.png"
    shutil.copyfile(preview_png_path, official_preview_path)
    preview_resource_path = "res://content/maps/previews/" + official_preview_path.name

    mode_id = str(map_info["mode"]).strip() or "box"
    map_row = {
        "map_id": map_id,
        "display_name": display_name,
        "preview_image_path": preview_resource_path,
        "width": str(cols),
        "height": str(rows),
        "layout_rows": "",
        "spawn_points": ";".join(f"{int(item['x'])}:{int(item['y'])}" for item in spawns),
        "theme_id": mode_id,
        "item_spawn_profile_id": "default_items",
        "bound_mode_id": mode_id,
        "bound_rule_set_id": str(map_info["rule"]).strip() or "ruleset_classic",
        "custom_room_enabled": "true",
        "sort_order": "100",
    }
    upsert_csv_row(OFFICIAL_MAPS_CSV, "map_id", map_row)

    remove_csv_rows(OFFICIAL_VARIANTS_CSV, lambda row: row.get("map_id", "") == map_id)
    format_player_counts = _load_match_format_player_counts()
    spawn_count = len(spawns)
    variant_rows: list[dict] = []
    for fmt_id, required_players in sorted(format_player_counts.items()):
        if spawn_count >= required_players:
            ranked = "true" if required_players >= 4 else "false"
            variant_rows.append({
                "map_id": map_id,
                "match_format_id": fmt_id,
                "casual_enabled": "true",
                "ranked_enabled": ranked,
            })
    if not variant_rows:
        raise ValueError("spawn count %d is too small for any known match format" % spawn_count)
    append_csv_rows(OFFICIAL_VARIANTS_CSV, variant_rows)

    remove_csv_rows(OFFICIAL_FLOOR_CSV, lambda row: row.get("map_id", "") == map_id)
    floor_rows = []
    for item in config["layers"]["floor"]:
        floor_rows.append(
            {
                "map_id": map_id,
                "x": str(int(item["x"])),
                "y": str(int(item["y"])),
                "w": str(int(item["w"])),
                "h": str(int(item["h"])),
                "elem_key": str(item["asset_key"]),
            }
        )
    append_csv_rows(OFFICIAL_FLOOR_CSV, floor_rows)

    remove_csv_rows(OFFICIAL_SURFACE_CSV, lambda row: row.get("map_id", "") == map_id)
    surface_rows = []
    for index, item in enumerate(config["layers"]["surface"], start=1):
        surface_rows.append(
            {
                "map_id": map_id,
                "instance_id": f"{map_id}_surface_{index:04d}",
                "elem_key": str(item["asset_key"]),
                "x": str(int(item["cell_x"])),
                "y": str(int(item["cell_y"])),
                "z_bias": str(int(item.get("z_bias", 0))),
                "render_role": "surface",
            }
        )
    append_csv_rows(OFFICIAL_SURFACE_CSV, surface_rows)

    remove_csv_rows(OFFICIAL_CHANNEL_CSV, lambda row: row.get("map_id", "") == map_id)
    channel_rows = []
    for item in config["layers"].get("channels", []):
        channel_rows.append(
            {
                "map_id": map_id,
                "x": str(int(item["x"])),
                "y": str(int(item["y"])),
                "movement_pass_dirs": str(item.get("movement_pass_dirs", "none")),
                "allow_place_bubble": "true" if bool(item.get("allow_place_bubble", True)) else "false",
            }
        )
    append_csv_rows(OFFICIAL_CHANNEL_CSV, channel_rows)
    return map_id


def read_csv_rows(path: Path) -> tuple[list[str], list[dict]]:
    if not path.exists():
        return [], []
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        return list(reader.fieldnames or []), list(reader)


def write_csv_rows(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def upsert_csv_row(path: Path, primary_key: str, new_row: dict) -> None:
    fieldnames, rows = read_csv_rows(path)
    rows = [row for row in rows if row.get(primary_key, "") != new_row[primary_key]]
    rows.append(new_row)
    write_csv_rows(path, fieldnames, rows)


def remove_csv_rows(path: Path, predicate) -> None:
    fieldnames, rows = read_csv_rows(path)
    write_csv_rows(path, fieldnames, [row for row in rows if not predicate(row)])


def append_csv_rows(path: Path, new_rows: list[dict]) -> None:
    if not new_rows:
        return
    fieldnames, rows = read_csv_rows(path)
    for row in new_rows:
        for key in row:
            if key not in fieldnames:
                fieldnames.append(key)
    rows.extend(new_rows)
    write_csv_rows(path, fieldnames, rows)


def _load_match_format_player_counts() -> Dict[str, int]:
    result: Dict[str, int] = {}
    if not OFFICIAL_MATCH_FORMATS_CSV.exists():
        return result
    _fieldnames, rows = read_csv_rows(OFFICIAL_MATCH_FORMATS_CSV)
    for row in rows:
        fmt_id = str(row.get("match_format_id", "")).strip()
        if not fmt_id:
            continue
        team_count = int(row.get("team_count", "0") or "0")
        party_size = int(row.get("required_party_size", "0") or "0")
        if team_count > 0 and party_size > 0:
            result[fmt_id] = team_count * party_size
    return result


def load_mode_options() -> list[tuple[str, str]]:
    if not OFFICIAL_MODES_CSV.exists():
        return []
    _fieldnames, rows = read_csv_rows(OFFICIAL_MODES_CSV)
    result = []
    for row in rows:
        mode_id = str(row.get("mode_id", "")).strip()
        if not mode_id:
            continue
        mode_name = str(row.get("mode_name", row.get("display_name", mode_id))).strip() or mode_id
        result.append((mode_id, mode_name))
    return result


def load_rule_options() -> list[tuple[str, str]]:
    if not OFFICIAL_RULESETS_CSV.exists():
        return []
    _fieldnames, rows = read_csv_rows(OFFICIAL_RULESETS_CSV)
    result = []
    for row in rows:
        rule_id = str(row.get("rule_set_id", "")).strip()
        if rule_id:
            result.append((rule_id, rule_id))
    return result or [("ruleset_classic", "ruleset_classic")]


def format_option(option: tuple[str, str]) -> str:
    return f"{option[0]} | {option[1]}"


def option_id(display_text: str) -> str:
    return display_text.split("|", 1)[0].strip()


class MapEditor(tk.Tk):
    def __init__(self, store: AssetStore):
        super().__init__()
        self.title("QQTang 2.5D Map Editor")
        self.geometry("1280x860")
        self.minsize(1100, 760)
        self.store = store
        self.model = MapModel()
        self.current_map_id: Optional[str] = None
        self.mode_options = load_mode_options()
        self.rule_options = load_rule_options()
        self.current_layer = tk.StringVar(value="floor")
        self.current_channel_dirs = tk.StringVar(value="none")
        self.current_channel_allow_bubble = tk.BooleanVar(value=True)
        self.selected_asset_key: Optional[str] = None
        self.view_scale = 1
        self.canvas_img: Optional[ImageTk.PhotoImage] = None
        self.status_var = tk.StringVar(value="Ready")
        self._paint_drag_active = False
        self._paint_drag_last_cell: Optional[Tuple[int, int]] = None
        self._preview_cell: Optional[Tuple[int, int]] = None
        self._preview_valid: bool = False
        self._drag_placing: bool = False
        self._build_ui()
        self.refresh_filters()
        self.refresh_asset_list()
        self.redraw()

    def _build_ui(self):
        root = ttk.Frame(self)
        root.pack(fill=tk.BOTH, expand=True)

        left = ttk.Frame(root, width=310)
        left.pack(side=tk.LEFT, fill=tk.Y, padx=6, pady=6)
        left.pack_propagate(False)

        ttk.Label(left, text="地图资产列表", font=("Arial", 13, "bold")).pack(anchor="w")

        f = ttk.Frame(left)
        f.pack(fill=tk.X, pady=(8, 0))
        ttk.Label(f, text="主题").grid(row=0, column=0, sticky="w")
        self.theme_cb = ttk.Combobox(f, state="readonly", width=18)
        self.theme_cb.grid(row=0, column=1, sticky="ew", padx=4)
        ttk.Label(f, text="逻辑类型").grid(row=1, column=0, sticky="w", pady=3)
        self.type_cb = ttk.Combobox(f, state="readonly", width=18)
        self.type_cb.grid(row=1, column=1, sticky="ew", padx=4, pady=3)
        ttk.Label(f, text="搜索").grid(row=2, column=0, sticky="w")
        self.search_var = tk.StringVar()
        ttk.Entry(f, textvariable=self.search_var).grid(row=2, column=1, sticky="ew", padx=4)
        self.anim_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(f, text="显示 die/trigger/gif 动画变体", variable=self.anim_var, command=self.refresh_asset_list).grid(row=3, column=0, columnspan=2, sticky="w")
        f.columnconfigure(1, weight=1)
        self.theme_cb.bind("<<ComboboxSelected>>", lambda e: self.refresh_asset_list())
        self.type_cb.bind("<<ComboboxSelected>>", lambda e: self.refresh_asset_list())
        self.search_var.trace_add("write", lambda *_: self.refresh_asset_list())

        ttk.Separator(left).pack(fill=tk.X, pady=8)

        self.asset_canvas = tk.Canvas(left, highlightthickness=0)
        self.asset_scroll = ttk.Scrollbar(left, orient="vertical", command=self.asset_canvas.yview)
        self.asset_canvas.configure(yscrollcommand=self.asset_scroll.set)
        self.asset_frame = ttk.Frame(self.asset_canvas)
        self.asset_window = self.asset_canvas.create_window((0, 0), window=self.asset_frame, anchor="nw")
        self.asset_canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        self.asset_scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self.asset_frame.bind("<Configure>", lambda e: self.asset_canvas.configure(scrollregion=self.asset_canvas.bbox("all")))
        self.asset_canvas.bind("<Configure>", lambda e: self.asset_canvas.itemconfigure(self.asset_window, width=e.width))
        self.asset_canvas.bind_all("<MouseWheel>", self._on_mousewheel)

        right = ttk.Frame(root)
        right.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=6, pady=6)

        meta_bar = ttk.LabelFrame(right, text="地图配置")
        meta_bar.pack(fill=tk.X)
        self.name_var = tk.StringVar(value=self.model.name)
        self.mode_var = tk.StringVar(value=format_option(self.mode_options[0]))
        for option in self.mode_options:
            if option[0] == self.model.mode:
                self.mode_var.set(format_option(option))
        self.rule_var = tk.StringVar(value=format_option(self.rule_options[0]))
        for option in self.rule_options:
            if option[0] == self.model.rule:
                self.rule_var.set(format_option(option))
        ttk.Label(meta_bar, text="地图名字").grid(row=0, column=0, sticky="w", padx=4, pady=4)
        ttk.Entry(meta_bar, textvariable=self.name_var, width=24).grid(row=0, column=1, sticky="w", padx=4)
        ttk.Label(meta_bar, text="地图模式").grid(row=0, column=2, sticky="w", padx=4)
        self.mode_cb = ttk.Combobox(meta_bar, textvariable=self.mode_var, state="readonly", width=24)
        self.mode_cb["values"] = [format_option(option) for option in self.mode_options]
        self.mode_cb.grid(row=0, column=3, sticky="w", padx=4)
        ttk.Label(meta_bar, text="地图规则").grid(row=0, column=4, sticky="w", padx=4)
        self.rule_cb = ttk.Combobox(meta_bar, textvariable=self.rule_var, state="readonly", width=24)
        self.rule_cb["values"] = [format_option(option) for option in self.rule_options]
        self.rule_cb.grid(row=0, column=5, sticky="w", padx=4)
        ttk.Button(meta_bar, text="打开地图", command=self.open_map_dialog).grid(row=0, column=6, padx=4)
        ttk.Button(meta_bar, text="保存地图", command=self.save_formal_map).grid(row=0, column=7, padx=4)
        ttk.Button(meta_bar, text="删除地图", command=self.delete_current_map).grid(row=0, column=8, padx=4)
        ttk.Button(meta_bar, text="一键导出配置", command=self.export_config).grid(row=1, column=6, padx=4, pady=4)
        ttk.Button(meta_bar, text="清空当前层", command=self.clear_current_layer).grid(row=1, column=7, padx=4, pady=4)

        layer_bar = ttk.LabelFrame(right, text="编辑层")
        layer_bar.pack(fill=tk.X, pady=(6, 6))
        for txt, val in (("地面层", "floor"), ("表现层", "surface"), ("通道层", "channel"), ("出生点", "spawn")):
            ttk.Radiobutton(layer_bar, text=txt, value=val, variable=self.current_layer, command=self.on_layer_changed).pack(side=tk.LEFT, padx=8, pady=4)
        ttk.Label(layer_bar, text="通道类型:").pack(side=tk.LEFT, padx=(8, 2))
        channel_cb = ttk.Combobox(layer_bar, textvariable=self.current_channel_dirs, state="readonly", values=MOVEMENT_PASS_DIRS_ORDER, width=6)
        channel_cb.pack(side=tk.LEFT, padx=(0, 8))
        ttk.Checkbutton(layer_bar, text="可放泡泡", variable=self.current_channel_allow_bubble).pack(side=tk.LEFT, padx=(0, 8))
        ttk.Label(layer_bar, text="提示：表现层每次点击后按 row 升序 + col 降序全量重排渲染。右键删除当前格内容。", foreground="#555").pack(side=tk.LEFT, padx=12)

        self.map_canvas = tk.Canvas(right, background="#222", highlightthickness=0)
        self.map_canvas.pack(fill=tk.BOTH, expand=True)
        self.map_canvas.bind("<Button-1>", self.on_map_left_click)
        self.map_canvas.bind("<B1-Motion>", self.on_map_left_drag)
        self.map_canvas.bind("<ButtonRelease-1>", self.on_map_left_release)
        self.map_canvas.bind("<Button-3>", self.on_map_right_click)
        self.map_canvas.bind("<Motion>", self.on_map_motion)
        self.asset_canvas.bind("<B1-Motion>", self.on_map_left_drag)
        self.asset_canvas.bind("<ButtonRelease-1>", self.on_map_left_release)
        self.bind("<ButtonRelease-1>", self.on_map_left_release, add=True)

        status = ttk.Label(self, textvariable=self.status_var, anchor="w")
        status.pack(fill=tk.X, side=tk.BOTTOM)

    def _on_mousewheel(self, event):
        # 仅当鼠标在左侧资产区附近时滚动资产列表。
        x = self.winfo_pointerx() - self.asset_canvas.winfo_rootx()
        y = self.winfo_pointery() - self.asset_canvas.winfo_rooty()
        if 0 <= x <= self.asset_canvas.winfo_width() and 0 <= y <= self.asset_canvas.winfo_height():
            self.asset_canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")

    def refresh_filters(self):
        self.theme_cb["values"] = ["全部"] + self.store.themes
        self.theme_cb.set("全部")
        self.type_cb["values"] = ["全部"] + self.store.logical_types
        self.type_cb.set("全部")

    def on_layer_changed(self):
        layer = self.current_layer.get()
        if layer == "surface" and not self.model.is_floor_complete():
            self.status_var.set("地面层未铺满：纯装饰可放在空地面，其他表现层元素需要占用范围内有地面。")
        elif layer == "channel":
            self.status_var.set("通道层为独立碰撞层，和表现层方块不绑定。")
        self.refresh_asset_list()
        self.redraw()

    def refresh_asset_list(self):
        for child in self.asset_frame.winfo_children():
            child.destroy()
        layer = self.current_layer.get()
        assets = self.store.filtered(
            self.theme_cb.get() or "全部",
            self.type_cb.get() or "全部",
            "floor" if layer == "floor" else "surface" if layer in ("surface", "channel", "spawn") else "surface",
            self.search_var.get(),
            self.anim_var.get(),
        )
        for i, asset in enumerate(assets):
            frame = ttk.Frame(self.asset_frame, relief=tk.GROOVE, padding=3)
            frame.pack(fill=tk.X, padx=2, pady=2)
            thumb = self.store.thumb(asset.key, 44)
            img_label = ttk.Label(frame, image=thumb)
            img_label.image = thumb
            img_label.pack(side=tk.LEFT)
            text = f"{asset.key}\n{asset.width}×{asset.height}  {asset.footprint_w}×{asset.footprint_h}  {logic_type_label(asset.logical_type)}"
            label = ttk.Label(frame, text=text, justify=tk.LEFT)
            label.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=4)
            for widget in (frame, img_label, label):
                widget.bind("<Button-1>", lambda e, k=asset.key: self.select_asset(k))
                widget.bind("<Button-3>", lambda e, k=asset.key: self._on_asset_right_click(e, k))
        self.status_var.set(f"资产列表：{len(assets)} 个；当前层：{layer}；当前选择：{self.selected_asset_key or '无'}")

    def select_asset(self, key: str):
        self.selected_asset_key = key
        meta = self.store.by_key[key]
        confidence_str = f" 置信={meta.confidence:.0%}" if meta.confidence < 0.9 else ""
        self.status_var.set(f"已选择：{key}  {meta.width}×{meta.height}  占格={meta.footprint_w}×{meta.footprint_h}  {logic_type_label(meta.logical_type)}{confidence_str}")

    def _on_asset_right_click(self, event, key: str):
        self.select_asset(key)
        menu = tk.Menu(self, tearoff=0)
        menu.add_command(label="编辑占格", command=lambda: self._edit_footprint_dialog(key))
        try:
            menu.tk_popup(event.x_root, event.y_root)
        finally:
            menu.grab_release()

    def _edit_footprint_dialog(self, key: str):
        meta = self.store.by_key[key]
        win = tk.Toplevel(self)
        win.title(f"编辑占格 — {key}")
        win.geometry("340x260")
        win.transient(self)
        win.grab_set()
        win.resizable(False, False)

        content = ttk.Frame(win, padding=(12, 10, 12, 8))
        content.pack(fill=tk.BOTH, expand=True)

        ttk.Label(content, text=f"资产: {key}").pack(anchor="w")
        ttk.Label(content, text=f"图像尺寸: {meta.width}×{meta.height}  当前占格: {meta.footprint_w}×{meta.footprint_h}  碰撞: {meta.collision_w}×{meta.collision_h}  通行: {MOVEMENT_PASS_DIRS_LABELS.get(meta.movement_pass_dirs, meta.movement_pass_dirs)}").pack(anchor="w", pady=(4, 0))

        f = ttk.Frame(content)
        f.pack(fill=tk.X, pady=12)
        ttk.Label(f, text="占格宽度:").grid(row=0, column=0, padx=4)
        w_var = tk.StringVar(value=str(meta.footprint_w))
        ttk.Spinbox(f, from_=1, to=20, textvariable=w_var, width=5).grid(row=0, column=1, padx=4)
        ttk.Label(f, text="占格高度:").grid(row=0, column=2, padx=4)
        h_var = tk.StringVar(value=str(meta.footprint_h))
        ttk.Spinbox(f, from_=1, to=20, textvariable=h_var, width=5).grid(row=0, column=3, padx=4)
        ttk.Label(f, text="碰撞宽度:").grid(row=1, column=0, padx=4, pady=4)
        cw_var = tk.StringVar(value=str(meta.collision_w))
        ttk.Spinbox(f, from_=0, to=20, textvariable=cw_var, width=5).grid(row=1, column=1, padx=4, pady=4)
        ttk.Label(f, text="碰撞高度:").grid(row=1, column=2, padx=4, pady=4)
        ch_var = tk.StringVar(value=str(meta.collision_h))
        ttk.Spinbox(f, from_=0, to=20, textvariable=ch_var, width=5).grid(row=1, column=3, padx=4, pady=4)
        logic_var = tk.StringVar(value=meta.logical_type)
        ttk.Label(f, text="逻辑类型:").grid(row=2, column=0, padx=4, pady=4)
        ttk.Combobox(f, textvariable=logic_var, state="readonly", values=LOGIC_TYPE_ORDER, width=12).grid(row=2, column=1, columnspan=3, sticky="w", padx=4, pady=4)
        pass_var = tk.StringVar(value=meta.movement_pass_dirs if meta.movement_pass_dirs in MOVEMENT_PASS_DIRS_ORDER else "none")
        ttk.Label(f, text="方向通行:").grid(row=3, column=0, padx=4, pady=4)
        ttk.Combobox(f, textvariable=pass_var, state="readonly", values=MOVEMENT_PASS_DIRS_ORDER, width=12).grid(row=3, column=1, columnspan=3, sticky="w", padx=4, pady=4)
        current_anchor = meta.anchor_mode if meta.anchor_mode in SURFACE_ANCHOR_ORDER else "bottom_right"
        anchor_values = [f"{item}:{SURFACE_ANCHOR_LABELS[item]}" for item in SURFACE_ANCHOR_ORDER]
        anchor_var = tk.StringVar(value=f"{current_anchor}:{SURFACE_ANCHOR_LABELS[current_anchor]}")
        ttk.Label(f, text="锚点:").grid(row=4, column=0, padx=4, pady=4)
        ttk.Combobox(f, textvariable=anchor_var, state="readonly", values=anchor_values, width=14).grid(row=4, column=1, columnspan=3, sticky="w", padx=4, pady=4)

        def _save():
            try:
                w = max(1, int(w_var.get()))
                h = max(1, int(h_var.get()))
                cw = max(0, int(cw_var.get()))
                ch = max(0, int(ch_var.get()))
            except ValueError:
                messagebox.showwarning("输入错误", "占格和碰撞宽高必须为整数。")
                return
            logic_type = logic_var.get() if logic_var.get() in LOGIC_TYPE_ORDER else "decoration"
            movement_pass_dirs = pass_var.get() if pass_var.get() in MOVEMENT_PASS_DIRS_ORDER else "none"
            anchor_type = anchor_var.get().split(":", 1)[0]
            anchor_type = anchor_type if anchor_type in SURFACE_ANCHOR_ORDER else "bottom_right"
            self._save_elem_override(key, w, h, cw, ch, logic_type, anchor_type, movement_pass_dirs)
            win.destroy()
            self.status_var.set(f"已更新 {key} 占格={w}×{h} 碰撞={cw}×{ch} 通行={MOVEMENT_PASS_DIRS_LABELS.get(movement_pass_dirs, movement_pass_dirs)} 逻辑={logic_type_label(logic_type)} 锚点={SURFACE_ANCHOR_LABELS.get(anchor_type, anchor_type)}")

        button_bar = ttk.Frame(content)
        button_bar.pack(fill=tk.X, side=tk.BOTTOM, pady=(8, 0))
        ttk.Button(button_bar, text="取消", command=win.destroy).pack(side=tk.RIGHT)
        save_button = ttk.Button(button_bar, text="保存", command=_save)
        save_button.pack(side=tk.RIGHT, padx=(0, 8))
        win.bind("<Return>", lambda _event: _save())
        win.bind("<Escape>", lambda _event: win.destroy())
        save_button.focus_set()

    def _save_elem_override(self, key: str, w: int, h: int, cw: int, ch: int, logic_type: str, anchor_mode: str, movement_pass_dirs: str):
        fieldnames, rows = read_csv_rows(OFFICIAL_ELEM_OVERRIDES_CSV)
        rows = [row for row in rows if str(row.get("elem_key", "")).strip() != key]
        rows.append({"elem_key": key, "footprint_w": str(w), "footprint_h": str(h), "collision_w": str(cw), "collision_h": str(ch), "logic_type": logic_type, "anchor_mode": anchor_mode, "movement_pass_dirs": movement_pass_dirs})
        default_fieldnames = ["elem_key", "footprint_w", "footprint_h", "collision_w", "collision_h", "logic_type", "anchor_mode", "movement_pass_dirs"]
        if not fieldnames:
            fieldnames = list(default_fieldnames)
        for field in default_fieldnames:
            if field not in fieldnames:
                fieldnames.append(field)
        write_csv_rows(OFFICIAL_ELEM_OVERRIDES_CSV, fieldnames, rows)
        self.store.by_key[key].footprint_w = w
        self.store.by_key[key].footprint_h = h
        self.store.by_key[key].collision_w = cw
        self.store.by_key[key].collision_h = ch
        self.store.by_key[key].logical_type = logic_type
        self.store.by_key[key].anchor_mode = anchor_mode
        self.store.by_key[key].movement_pass_dirs = movement_pass_dirs
        self.refresh_asset_list()
        self.redraw()

    def map_cell_from_event(self, event) -> Optional[Tuple[int, int]]:
        x = event.x - PREVIEW_MARGIN_LEFT
        y = event.y - PREVIEW_MARGIN_TOP
        col = x // CELL_SIZE
        row = y // CELL_SIZE
        if 0 <= col < self.model.cols and 0 <= row < self.model.rows:
            return int(col), int(row)
        return None

    def on_map_motion(self, event):
        cell = self.map_cell_from_event(event)
        layer = self.current_layer.get()
        if cell:
            meta_str = ""
            if self.selected_asset_key and self.selected_asset_key in self.store.by_key:
                meta = self.store.by_key[self.selected_asset_key]
                fp_w = max(1, meta.footprint_w)
                fp_h = max(1, meta.footprint_h)
                meta_str = f" 占格={fp_w}×{fp_h}"
            self.status_var.set(f"cell=({cell[0]},{cell[1]}) layer={layer} selected={self.selected_asset_key or '无'}{meta_str}")
            if self.selected_asset_key and layer in ("floor", "surface"):
                if self._drag_placing:
                    return
                prev_cell = self._preview_cell
                self._preview_cell = cell
                self._preview_valid = self._check_placement_valid(cell[0], cell[1], layer)
                if prev_cell != cell:
                    self._draw_footprint_overlay()
            else:
                self._clear_footprint_overlay()
                self._preview_cell = None
        else:
            self._clear_footprint_overlay()
            self._preview_cell = None

    def _asset_is_multi_cell(self) -> bool:
        if not self.selected_asset_key or self.selected_asset_key not in self.store.by_key:
            return False
        meta = self.store.by_key[self.selected_asset_key]
        return meta.footprint_w > 1 or meta.footprint_h > 1

    def on_map_left_click(self, event):
        cell = self.map_cell_from_event(event)
        layer = self.current_layer.get()
        if layer == "spawn":
            self._paint_drag_active = False
            self._paint_drag_last_cell = None
            self._drag_placing = False
            if cell:
                if cell in self.model.spawns:
                    self.model.spawns.remove(cell)
                else:
                    self.model.spawns.append(cell)
            self.redraw()
            return
        if self._asset_is_multi_cell() and layer in ("floor", "surface"):
            self._paint_drag_active = False
            self._paint_drag_last_cell = None
            self._drag_placing = True
            if cell:
                self._preview_cell = cell
                self._preview_valid = self._check_placement_valid(cell[0], cell[1], layer)
            else:
                self._preview_valid = False
            self._draw_footprint_overlay()
            return
        self._drag_placing = False
        if cell:
            x, y = cell
            self._paint_drag_active = self._paint_cell(x, y, show_warning=True)
            self._paint_drag_last_cell = cell if self._paint_drag_active else None

    def on_map_left_drag(self, event):
        if not self._drag_placing and not self._paint_drag_active:
            if self._asset_is_multi_cell() and self.current_layer.get() in ("floor", "surface"):
                self._drag_placing = True
        if self._drag_placing:
            cell = self.map_cell_from_event(event)
            layer = self.current_layer.get()
            if cell:
                self._preview_cell = cell
                self._preview_valid = self._check_placement_valid(cell[0], cell[1], layer)
            else:
                self._preview_valid = False
            self._draw_footprint_overlay()
            return
        if not self._paint_drag_active:
            return
        cell = self.map_cell_from_event(event)
        if not cell:
            return
        if cell == self._paint_drag_last_cell:
            return
        cells = self._cells_between(self._paint_drag_last_cell, cell) if self._paint_drag_last_cell else [cell]
        changed = False
        for cx, cy in cells:
            changed = self._paint_cell(cx, cy, show_warning=False, redraw=False) or changed
        self._paint_drag_last_cell = cell
        if changed:
            self.redraw()

    def on_map_left_release(self, _event):
        if self._drag_placing:
            self._drag_placing = False
            if self._preview_valid and self._preview_cell:
                x, y = self._preview_cell
                self._paint_cell(x, y, show_warning=False)
            self._clear_footprint_overlay()
            return
        self._paint_drag_active = False
        self._paint_drag_last_cell = None
        self._clear_footprint_overlay()

    def _paint_cell(self, x: int, y: int, show_warning: bool, redraw: bool = True) -> bool:
        layer = self.current_layer.get()
        if layer == "channel":
            dirs = self.current_channel_dirs.get() if self.current_channel_dirs.get() in MOVEMENT_PASS_DIRS_ORDER else "none"
            self.model.channels[(x, y)] = {"movement_pass_dirs": dirs, "allow_place_bubble": bool(self.current_channel_allow_bubble.get())}
            if redraw:
                self.redraw()
            return True
        if not self.selected_asset_key:
            if show_warning:
                messagebox.showwarning("未选择资产", "请先在左侧选择一个地图资产。")
            return False
        asset = self.store.by_key[self.selected_asset_key]
        footprint_w = max(1, asset.footprint_w)
        footprint_h = max(1, asset.footprint_h)
        if layer == "surface":
            in_bounds = self._anchor_rect_in_bounds(x, y, footprint_w, footprint_h, asset.anchor_mode)
        else:
            in_bounds = self._rect_in_bounds(x, y, footprint_w, footprint_h)
        if not in_bounds:
            if show_warning:
                messagebox.showwarning("占格越界", f"资产占格 {footprint_w}×{footprint_h}，当前位置会超出地图范围。")
            return False
        changed = False
        if layer == "floor":
            if asset.layer_hint != "floor":
                if show_warning:
                    messagebox.showwarning("地面层限制", "地面层只能使用地面资产。")
                return False
            self._remove_floor_instances_overlapping(x, y, footprint_w, footprint_h)
            self.model.floor_instances[(x, y)] = FloorInstance(asset.key, x, y, footprint_w, footprint_h)
            for tx, ty in self._rect_cells(x, y, footprint_w, footprint_h):
                self.model.floor[ty][tx] = asset.key
            changed = True
        elif layer == "surface":
            if self._surface_rect_overlaps(x, y, footprint_w, footprint_h, asset.anchor_mode):
                if show_warning:
                    messagebox.showwarning("占格冲突", "当前位置的表现层占格范围已有其他资产。")
                return False
            if asset.logical_type != "decoration" and not self._has_floor_coverage_anchor(x, y, footprint_w, footprint_h, asset.anchor_mode):
                if show_warning:
                    messagebox.showwarning("地面不足", "非纯装饰表现层元素要求占用范围内全部已有地面。")
                return False
            current = self._surface_instance_at_cell(x, y)
            if current is None or current.asset_key != asset.key:
                self.model.surface[(x, y)] = SurfaceInstance(asset.key, x, y, 0, footprint_w, footprint_h)
                changed = True
        if changed and redraw:
            self.redraw()
        return True

    def _rect_in_bounds(self, x: int, y: int, w: int, h: int) -> bool:
        return x >= 0 and y >= 0 and x + w <= self.model.cols and y + h <= self.model.rows

    def _rect_cells(self, x: int, y: int, w: int, h: int) -> List[Tuple[int, int]]:
        return [(tx, ty) for ty in range(y, y + h) for tx in range(x, x + w)]

    def _anchor_rect_in_bounds(self, x: int, y: int, w: int, h: int, anchor_mode: str) -> bool:
        if anchor_mode == "bottom_left":
            return x >= 0 and y >= 0 and x < self.model.cols and y < self.model.rows and x + w <= self.model.cols and y - h + 1 >= 0
        if anchor_mode == "bottom_center":
            left = x - ((w - 1) // 2)
            right = left + w - 1
            return x >= 0 and y >= 0 and x < self.model.cols and y < self.model.rows and left >= 0 and right < self.model.cols and y - h + 1 >= 0
        if anchor_mode == "center":
            left = x - ((w - 1) // 2)
            right = left + w - 1
            return x >= 0 and y >= 0 and x < self.model.cols and y < self.model.rows and left >= 0 and right < self.model.cols and y - h + 1 >= 0
        return x >= 0 and y >= 0 and x < self.model.cols and y < self.model.rows and x - w + 1 >= 0 and y - h + 1 >= 0

    def _anchor_rect_cells(self, x: int, y: int, w: int, h: int, anchor_mode: str) -> List[Tuple[int, int]]:
        if anchor_mode == "bottom_left":
            return [(x + dx, y - dy) for dy in range(h) for dx in range(w)]
        if anchor_mode == "bottom_center":
            left = x - ((w - 1) // 2)
            return [(left + dx, y - dy) for dy in range(h) for dx in range(w)]
        if anchor_mode == "center":
            left = x - ((w - 1) // 2)
            return [(left + dx, y - dy) for dy in range(h) for dx in range(w)]
        return [(x - dx, y - dy) for dy in range(h) for dx in range(w)]

    def _rects_overlap(self, ax: int, ay: int, aw: int, ah: int, bx: int, by: int, bw: int, bh: int) -> bool:
        return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by

    def _remove_floor_instances_overlapping(self, x: int, y: int, w: int, h: int):
        remove_keys: List[Tuple[int, int]] = []
        for key, inst in self.model.floor_instances.items():
            if self._rects_overlap(x, y, w, h, inst.x, inst.y, inst.w, inst.h):
                remove_keys.append(key)
        for key in remove_keys:
            inst = self.model.floor_instances.pop(key)
            for tx, ty in self._rect_cells(inst.x, inst.y, inst.w, inst.h):
                if 0 <= tx < self.model.cols and 0 <= ty < self.model.rows:
                    self.model.floor[ty][tx] = None

    def _floor_instance_at_cell(self, x: int, y: int) -> Optional[FloorInstance]:
        for inst in self.model.floor_instances.values():
            if inst.x <= x < inst.x + inst.w and inst.y <= y < inst.y + inst.h:
                return inst
        return None

    def _surface_instance_at_cell(self, x: int, y: int) -> Optional[SurfaceInstance]:
        for inst in self.model.surface.values():
            meta = self.store.by_key.get(inst.asset_key)
            anchor_mode = meta.anchor_mode if meta is not None else "bottom_right"
            if (x, y) in self._anchor_rect_cells(inst.x, inst.y, inst.footprint_w, inst.footprint_h, anchor_mode):
                return inst
        return None

    def _surface_rect_overlaps(self, x: int, y: int, w: int, h: int, anchor_mode: str) -> bool:
        target_cells = set(self._anchor_rect_cells(x, y, w, h, anchor_mode))
        for inst in self.model.surface.values():
            meta = self.store.by_key.get(inst.asset_key)
            inst_anchor_mode = meta.anchor_mode if meta is not None else "bottom_right"
            if target_cells.intersection(self._anchor_rect_cells(inst.x, inst.y, inst.footprint_w, inst.footprint_h, inst_anchor_mode)):
                return True
        return False

    def _has_floor_coverage(self, x: int, y: int, w: int, h: int) -> bool:
        return all(self.model.floor[ty][tx] for tx, ty in self._rect_cells(x, y, w, h))

    def _has_floor_coverage_anchor(self, x: int, y: int, w: int, h: int, anchor_mode: str) -> bool:
        return all(self.model.floor[ty][tx] for tx, ty in self._anchor_rect_cells(x, y, w, h, anchor_mode))

    def _check_placement_valid(self, x: int, y: int, layer: str) -> bool:
        if not self.selected_asset_key or self.selected_asset_key not in self.store.by_key:
            return False
        asset = self.store.by_key[self.selected_asset_key]
        fp_w = max(1, asset.footprint_w)
        fp_h = max(1, asset.footprint_h)
        if layer == "surface":
            in_bounds = self._anchor_rect_in_bounds(x, y, fp_w, fp_h, asset.anchor_mode)
        else:
            in_bounds = self._rect_in_bounds(x, y, fp_w, fp_h)
        if not in_bounds:
            return False
        if layer == "floor":
            if asset.layer_hint != "floor":
                return False
        elif layer == "surface":
            if self._surface_rect_overlaps(x, y, fp_w, fp_h, asset.anchor_mode):
                return False
            if asset.logical_type != "decoration" and not self._has_floor_coverage_anchor(x, y, fp_w, fp_h, asset.anchor_mode):
                return False
        return True

    def _draw_footprint_overlay(self):
        self._clear_footprint_overlay()
        if not self._preview_cell or not self.selected_asset_key:
            return
        if self.selected_asset_key not in self.store.by_key:
            return
        asset = self.store.by_key[self.selected_asset_key]
        fp_w = max(1, asset.footprint_w)
        fp_h = max(1, asset.footprint_h)
        x, y = self._preview_cell
        ox, oy = PREVIEW_MARGIN_LEFT, PREVIEW_MARGIN_TOP
        if self.current_layer.get() == "surface":
            if asset.anchor_mode == "bottom_left":
                x1 = ox + x * CELL_SIZE
            elif asset.anchor_mode == "bottom_center":
                x1 = ox + (x - ((fp_w - 1) // 2)) * CELL_SIZE
            elif asset.anchor_mode == "center":
                x1 = ox + (x - ((fp_w - 1) // 2)) * CELL_SIZE
            else:
                x1 = ox + (x - fp_w + 1) * CELL_SIZE
            y1 = oy + (y - fp_h + 1) * CELL_SIZE
        else:
            x1 = ox + x * CELL_SIZE
            y1 = oy + y * CELL_SIZE
        x2 = x1 + fp_w * CELL_SIZE
        y2 = y1 + fp_h * CELL_SIZE
        color = "#4CAF50" if self._preview_valid else "#F44336"
        self.map_canvas.create_rectangle(
            x1, y1, x2, y2,
            outline=color, width=3, stipple="gray50",
            tags="footprint_preview",
        )
        self.map_canvas.create_text(
            (x1 + x2) // 2, (y1 + y2) // 2,
            text=f"{fp_w}×{fp_h}",
            fill=color, font=("Arial", 11, "bold"),
            tags="footprint_preview",
        )

    def _clear_footprint_overlay(self):
        self.map_canvas.delete("footprint_preview")

    def _cells_between(self, start: Tuple[int, int], end: Tuple[int, int]) -> List[Tuple[int, int]]:
        x0, y0 = start
        x1, y1 = end
        dx = abs(x1 - x0)
        dy = -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        cells: List[Tuple[int, int]] = []
        while True:
            cells.append((x0, y0))
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy
        return cells

    def on_map_right_click(self, event):
        cell = self.map_cell_from_event(event)
        if not cell:
            return
        x, y = cell
        layer = self.current_layer.get()
        if layer == "floor":
            inst = self._floor_instance_at_cell(x, y)
            if inst is not None:
                self._remove_floor_instances_overlapping(inst.x, inst.y, inst.w, inst.h)
            else:
                self.model.floor[y][x] = None
        elif layer == "surface":
            inst = self._surface_instance_at_cell(x, y)
            if inst is not None:
                self.model.surface.pop((inst.x, inst.y), None)
        elif layer == "channel":
            self.model.channels.pop((x, y), None)
        elif layer == "spawn":
            if (x, y) in self.model.spawns:
                self.model.spawns.remove((x, y))
        self.redraw()

    def render_to_image(
        self,
        include_surface: bool = True,
        include_spawns: bool = True,
        include_channels: bool = True,
        draw_grid: bool = True,
    ) -> Image.Image:
        width = self.model.cols * CELL_SIZE + PREVIEW_MARGIN_LEFT * 2
        height = self.model.rows * CELL_SIZE + PREVIEW_MARGIN_TOP + 24
        img = Image.new("RGBA", (width, height), (35, 35, 35, 255))
        draw = ImageDraw.Draw(img)
        ox, oy = PREVIEW_MARGIN_LEFT, PREVIEW_MARGIN_TOP

        # 地面层：按实例渲染。多格资产用原图拉伸到 M*40×N*40，普通资产逐格平铺。
        covered: set = set()
        for inst in sorted(self.model.floor_instances.values(), key=lambda i: (i.y, i.x)):
            meta = self.store.by_key.get(inst.asset_key)
            is_multi = meta is not None and (meta.footprint_w > 1 or meta.footprint_h > 1)
            if is_multi:
                px, py = ox + inst.x * CELL_SIZE, oy + inst.y * CELL_SIZE
                asset_img = self.store.image(inst.asset_key)
                target_w = inst.w * CELL_SIZE
                target_h = inst.h * CELL_SIZE
                if asset_img.size != (target_w, target_h):
                    asset_img = asset_img.resize((target_w, target_h), Image.NEAREST)
                img.alpha_composite(asset_img, (px, py))
            else:
                for ty in range(inst.y, inst.y + inst.h):
                    for tx in range(inst.x, inst.x + inst.w):
                        px, py = ox + tx * CELL_SIZE, oy + ty * CELL_SIZE
                        img.alpha_composite(self.store.floor_image(inst.asset_key), (px, py))
            for ty in range(inst.y, inst.y + inst.h):
                for tx in range(inst.x, inst.x + inst.w):
                    covered.add((tx, ty))
        for row in range(self.model.rows):
            for col in range(self.model.cols):
                if (col, row) not in covered:
                    px, py = ox + col * CELL_SIZE, oy + row * CELL_SIZE
                    fill = (58, 58, 58, 255) if (row + col) % 2 == 0 else (50, 50, 50, 255)
                    draw.rectangle([px, py, px + CELL_SIZE, py + CELL_SIZE], fill=fill)

        if include_surface:
            instances = sorted(
                self.model.surface.values(),
                key=lambda inst: (
                    inst.y,
                    -inst.x,
                    inst.z_bias,
                ),
            )
            for inst in instances:
                meta = self.store.by_key[inst.asset_key]
                asset_img = self.store.image(inst.asset_key)
                if meta.anchor_mode == "bottom_left":
                    dx = ox + inst.x * CELL_SIZE
                    dy = oy + (inst.y + 1) * CELL_SIZE - meta.height
                elif meta.anchor_mode == "bottom_center":
                    left_cell = inst.x - ((inst.footprint_w - 1) // 2)
                    center_x = ox + (left_cell + inst.footprint_w / 2) * CELL_SIZE
                    dx = center_x - meta.width / 2
                    dy = oy + (inst.y + 1) * CELL_SIZE - meta.height
                elif meta.anchor_mode == "center":
                    left_cell = inst.x - ((inst.footprint_w - 1) // 2)
                    center_x = ox + (left_cell + inst.footprint_w / 2) * CELL_SIZE
                    center_y = oy + (inst.y + 1 - inst.footprint_h / 2) * CELL_SIZE
                    dx = center_x - meta.width / 2
                    dy = center_y - meta.height / 2
                else:
                    dx = ox + (inst.x + 1) * CELL_SIZE - meta.width
                    dy = oy + (inst.y + 1) * CELL_SIZE - meta.height
                img.alpha_composite(asset_img, (int(round(dx)), int(round(dy))))

        if include_channels:
            for (cx, cy), channel in sorted(self.model.channels.items(), key=lambda item: (item[0][1], item[0][0])):
                dirs = str(channel.get("movement_pass_dirs", "none"))
                allow_place = bool(channel.get("allow_place_bubble", True))
                px = ox + cx * CELL_SIZE
                py = oy + cy * CELL_SIZE
                draw.rectangle([px + 2, py + 2, px + CELL_SIZE - 2, py + CELL_SIZE - 2], outline=(80, 200, 255, 220), width=2)
                draw.text((px + 4, py + 4), dirs.upper(), fill=(80, 200, 255, 255))
                if not allow_place:
                    draw.text((px + 4, py + 20), "NO BOMB", fill=(255, 120, 120, 255))

        if include_spawns:
            for idx, (sx, sy) in enumerate(self.model.spawns, start=1):
                cx = ox + sx * CELL_SIZE + CELL_SIZE // 2
                cy = oy + sy * CELL_SIZE + CELL_SIZE // 2
                draw.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], outline=(255, 80, 80, 255), width=3)
                draw.text((cx - 4, cy - 7), str(idx), fill=(255, 255, 255, 255))

        if draw_grid:
            grid_color = (0, 0, 0, 95)
            for col in range(self.model.cols + 1):
                x = ox + col * CELL_SIZE
                draw.line([x, oy, x, oy + self.model.rows * CELL_SIZE], fill=grid_color)
            for row in range(self.model.rows + 1):
                y = oy + row * CELL_SIZE
                draw.line([ox, y, ox + self.model.cols * CELL_SIZE, y], fill=grid_color)

        title = f"{self.name_var.get()} | mode={self.mode_var.get()} | rule={self.rule_var.get()}"
        draw.text((ox, 18), title, fill=(240, 240, 240, 255))
        return img

    def redraw(self):
        layer = self.current_layer.get()
        include_surface = layer in ("surface", "channel", "spawn")
        include_spawns = layer == "spawn"
        self._clear_footprint_overlay()
        # 表现层编辑时显示地面+表现层；地面编辑时只显示地面。
        include_channels = layer == "channel"
        img = self.render_to_image(
            include_surface=include_surface,
            include_spawns=include_spawns,
            include_channels=include_channels,
            draw_grid=True,
        )
        self.canvas_img = ImageTk.PhotoImage(img)
        self.map_canvas.delete("all")
        self.map_canvas.create_image(0, 0, anchor="nw", image=self.canvas_img)
        self.map_canvas.config(scrollregion=(0, 0, img.width, img.height))

    def open_map_dialog(self):
        rows = list_editor_map_rows()
        if not rows:
            messagebox.showinfo("打开地图", "没有找到编辑器生成的地图。")
            return
        win = tk.Toplevel(self)
        win.title("打开编辑器地图")
        win.geometry("720x360")
        win.transient(self)
        win.grab_set()

        tree = ttk.Treeview(win, columns=("map_id", "name", "mode", "rule"), show="headings", selectmode="browse")
        for col, text, width in (
            ("map_id", "地图 ID", 180),
            ("name", "地图名字", 180),
            ("mode", "地图模式", 120),
            ("rule", "地图规则", 160),
        ):
            tree.heading(col, text=text)
            tree.column(col, width=width, anchor="w")
        tree.pack(fill=tk.BOTH, expand=True, padx=8, pady=8)
        for row in rows:
            map_id = row.get("map_id", "")
            tree.insert(
                "",
                tk.END,
                iid=map_id,
                values=(
                    map_id,
                    row.get("display_name", ""),
                    row.get("bound_mode_id", ""),
                    row.get("bound_rule_set_id", ""),
                ),
            )

        buttons = ttk.Frame(win)
        buttons.pack(fill=tk.X, padx=8, pady=(0, 8))

        def selected_map_id() -> str:
            selection = tree.selection()
            return selection[0] if selection else ""

        def open_selected():
            map_id = selected_map_id()
            if not map_id:
                return
            try:
                self.load_formal_map(map_id)
            except Exception as exc:
                messagebox.showerror("打开失败", str(exc))
                return
            win.destroy()

        def delete_selected():
            map_id = selected_map_id()
            if not map_id:
                return
            if not messagebox.askyesno("确认删除", f"确定删除地图 {map_id} ?"):
                return
            try:
                delete_official_map(map_id)
            except Exception as exc:
                messagebox.showerror("删除失败", str(exc))
                return
            tree.delete(map_id)
            if self.current_map_id == map_id:
                self.current_map_id = None
                self.status_var.set(f"已删除地图：{map_id}")

        ttk.Button(buttons, text="打开", command=open_selected).pack(side=tk.LEFT, padx=4)
        ttk.Button(buttons, text="删除", command=delete_selected).pack(side=tk.LEFT, padx=4)
        ttk.Button(buttons, text="关闭", command=win.destroy).pack(side=tk.RIGHT, padx=4)
        tree.bind("<Double-1>", lambda _event: open_selected())

    def load_formal_map(self, map_id: str):
        self.model = load_official_map_model(map_id, self.store)
        self.current_map_id = map_id
        self.name_var.set(self.model.name)
        self._set_option_var(self.mode_var, self.mode_options, self.model.mode)
        self._set_option_var(self.rule_var, self.rule_options, self.model.rule)
        self.current_layer.set("floor")
        self.selected_asset_key = None
        self.refresh_asset_list()
        self.redraw()
        self.status_var.set(f"已打开地图：{map_id}")

    def save_formal_map(self):
        try:
            map_id = self._sync_current_model_to_official(previous_map_id=self.current_map_id)
        except Exception as exc:
            messagebox.showerror("保存失败", str(exc))
            return
        self.current_map_id = map_id
        self.status_var.set(f"已保存地图：{map_id}")
        messagebox.showinfo("保存完成", f"正式地图已保存：{map_id}")

    def delete_current_map(self):
        if not self.current_map_id:
            messagebox.showinfo("删除地图", "当前没有打开的编辑器地图。")
            return
        map_id = self.current_map_id
        if not messagebox.askyesno("确认删除", f"确定删除当前地图 {map_id} ?"):
            return
        try:
            delete_official_map(map_id)
        except Exception as exc:
            messagebox.showerror("删除失败", str(exc))
            return
        self.current_map_id = None
        self.model = MapModel()
        self.name_var.set(self.model.name)
        self._set_option_var(self.mode_var, self.mode_options, self.model.mode)
        self._set_option_var(self.rule_var, self.rule_options, self.model.rule)
        self.selected_asset_key = None
        self.refresh_asset_list()
        self.redraw()
        self.status_var.set(f"已删除地图：{map_id}")

    def _sync_current_model_to_official(self, previous_map_id: Optional[str] = None) -> str:
        self.model.name = self.name_var.get().strip() or "new_map"
        self.model.mode = option_id(self.mode_var.get()) or "box"
        self.model.rule = option_id(self.rule_var.get()) or "ruleset_classic"
        config = self.model.to_config(self.store)
        with tempfile.TemporaryDirectory() as tmp_dir:
            png_path = Path(tmp_dir) / "preview.png"
            self.render_to_image(
                include_surface=True,
                include_spawns=False,
                include_channels=False,
                draw_grid=False,
            ).save(png_path)
            return sync_official_map_csv(config, png_path, previous_map_id=previous_map_id)

    def _set_option_var(self, var: tk.StringVar, options: list[tuple[str, str]], option_id_value: str):
        for option in options:
            if option[0] == option_id_value:
                var.set(format_option(option))
                return
        if options:
            var.set(format_option(options[0]))

    def clear_current_layer(self):
        layer = self.current_layer.get()
        if not messagebox.askyesno("确认", f"确定清空当前层：{layer} ?"):
            return
        if layer == "floor":
            self.model.floor = [[None for _ in range(self.model.cols)] for _ in range(self.model.rows)]
            self.model.surface.clear()
            self.model.channels.clear()
        elif layer == "surface":
            self.model.surface.clear()
        elif layer == "channel":
            self.model.channels.clear()
        elif layer == "spawn":
            self.model.spawns.clear()
        self.redraw()

    def export_config(self):
        self.model.name = self.name_var.get().strip() or "new_map"
        self.model.mode = option_id(self.mode_var.get()) or "box"
        self.model.rule = option_id(self.rule_var.get()) or "ruleset_classic"
        out_dir = filedialog.askdirectory(title="选择导出目录")
        if not out_dir:
            return
        out = Path(out_dir)
        out.mkdir(parents=True, exist_ok=True)
        config = self.model.to_config(self.store)
        base = re.sub(r"[^a-zA-Z0-9_\-\u4e00-\u9fa5]+", "_", self.model.name)
        json_path = out / f"{base}.qqtang_map.json"
        png_path = out / f"{base}.preview.png"
        json_path.write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding="utf-8")
        self.render_to_image(
            include_surface=True,
            include_spawns=False,
            include_channels=False,
            draw_grid=False,
        ).save(png_path)
        try:
            map_id = sync_official_map_csv(config, png_path, previous_map_id=self.current_map_id)
        except Exception as exc:
            messagebox.showerror("正式管线导出失败", str(exc))
            return
        self.current_map_id = map_id
        messagebox.showinfo("导出完成", f"已导出：\n{json_path}\n{png_path}\n正式地图 ID：{map_id}")


def write_asset_index(assets: List[AssetMeta], out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    csv_path = out_dir / "qqtang_map_elem_asset_index.csv"
    json_path = out_dir / "qqtang_map_elem_asset_index.json"
    fields = list(asdict(assets[0]).keys()) if assets else []
    with csv_path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        for a in assets:
            writer.writerow(asdict(a))
    json_path.write_text(json.dumps([asdict(a) for a in assets], ensure_ascii=False, indent=2), encoding="utf-8")
    return csv_path, json_path


def main(argv: Optional[List[str]] = None):
    parser = argparse.ArgumentParser(description="QQTang 2.5D Map Editor")
    parser.add_argument("--asset-root", type=str, default="", help="QQTang5.2_Beta1Build1 根目录，或包含该目录的仓库根")
    parser.add_argument("--zip", type=str, default="", help="QQTangExtracted-master.zip 路径；会自动解包到用户缓存目录")
    parser.add_argument("--dump-index", type=str, default="", help="只扫描并导出资产索引到指定目录，不启动 UI")
    args = parser.parse_args(argv)

    search_roots = []
    if args.zip:
        zip_path = Path(args.zip).expanduser().resolve()
        if not zip_path.exists():
            raise FileNotFoundError(zip_path)
        search_roots.append(extract_zip(zip_path))
    if args.asset_root:
        search_roots.append(Path(args.asset_root).expanduser().resolve())
    # 常用默认位置：脚本同目录、当前目录。
    script_dir = Path(__file__).resolve().parent
    search_roots.extend([REPO_ROOT / "external/assets/maps/elements", script_dir, Path.cwd()])

    version_root = None
    for root in search_roots:
        version_root = root if is_map_elem_root(root) else find_data_root(root)
        if version_root:
            break

    if not version_root:
        tk.Tk().withdraw()
        selected = filedialog.askopenfilename(
            title="请选择 QQTangExtracted-master.zip 或 QQTang5.2_Beta1Build1 目录下任意文件",
            filetypes=[("Zip or image/resource", "*.zip *.png *.gif *.*")],
        )
        if selected:
            p = Path(selected)
            if p.suffix.lower() == ".zip":
                version_root = find_data_root(extract_zip(p))
            else:
                version_root = find_data_root(p.parent)
    if not version_root:
        raise RuntimeError("无法定位 data/object/mapElem。请使用 --asset-root 或 --zip 指定资源。")

    assets = scan_assets(version_root)
    if not assets:
        raise RuntimeError(f"未扫描到 mapElem 图片资源：{version_root}")

    if args.dump_index:
        write_asset_index(assets, Path(args.dump_index))
        print(f"dumped {len(assets)} assets to {args.dump_index}")
        return

    app = MapEditor(AssetStore(assets))
    app.mainloop()


if __name__ == "__main__":
    main()
