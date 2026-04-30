from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from tools.asset_pipeline.core.png_rgba import RgbaImage, read_rgba_png, write_rgba_png


@dataclass(frozen=True)
class TeamColor:
    team_id: int
    team_color_id: str
    primary: tuple[int, int, int]
    secondary: tuple[int, int, int]
    shadow: tuple[int, int, int]
    highlight: tuple[int, int, int]


def parse_hex_color(value: str) -> tuple[int, int, int]:
    text = value.strip().lstrip("#")
    if len(text) != 6:
        raise ValueError(f"invalid hex color: {value}")
    return int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16)


def recolor_image(source_path: Path, mask_path: Path, output_path: Path, team_color: TeamColor) -> None:
    source = read_rgba_png(source_path)
    mask = read_rgba_png(mask_path)
    if source.width != mask.width or source.height != mask.height:
        raise ValueError(f"mask size {mask.width}x{mask.height} does not match source {source.width}x{source.height}")

    output = bytearray(source.pixels)
    for offset in range(0, len(output), 4):
        mask_r = mask.pixels[offset]
        mask_g = mask.pixels[offset + 1]
        mask_b = mask.pixels[offset + 2]
        mask_a = mask.pixels[offset + 3] / 255.0
        if mask_a <= 0.0:
            continue
        if mask_g >= mask_r and mask_g >= mask_b and mask_g > 0:
            target = team_color.secondary
        elif mask_b >= mask_r and mask_b >= mask_g and mask_b > 0:
            target = team_color.shadow
        else:
            target = team_color.primary
        luminance = (output[offset] * 0.2126 + output[offset + 1] * 0.7152 + output[offset + 2] * 0.0722) / 255.0
        shade = 0.65 + luminance * 0.7
        for channel in range(3):
            recolored = max(0, min(255, int(target[channel] * shade)))
            output[offset + channel] = int(output[offset + channel] * (1.0 - mask_a) + recolored * mask_a)
    write_rgba_png(output_path, RgbaImage(source.width, source.height, bytes(output)))

