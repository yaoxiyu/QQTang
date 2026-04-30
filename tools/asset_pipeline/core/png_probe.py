from __future__ import annotations

import struct
from dataclasses import dataclass
from pathlib import Path


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


@dataclass(frozen=True)
class PngInfo:
    width: int
    height: int
    color_type: int

    @property
    def has_alpha(self) -> bool:
        return self.color_type in (4, 6)


def read_png_info(path: Path) -> PngInfo:
    with path.open("rb") as handle:
        signature = handle.read(8)
        if signature != PNG_SIGNATURE:
            raise ValueError(f"not a png file: {path}")
        length_bytes = handle.read(4)
        chunk_type = handle.read(4)
        if len(length_bytes) != 4 or chunk_type != b"IHDR":
            raise ValueError(f"missing png IHDR: {path}")
        length = struct.unpack(">I", length_bytes)[0]
        data = handle.read(length)
        if length < 13 or len(data) < 13:
            raise ValueError(f"invalid png IHDR: {path}")
        width, height, _bit_depth, color_type = struct.unpack(">IIBB", data[:10])
        return PngInfo(width=width, height=height, color_type=color_type)

