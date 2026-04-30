from __future__ import annotations

import struct
import zlib
from dataclasses import dataclass
from pathlib import Path

from .png_probe import PNG_SIGNATURE


@dataclass(frozen=True)
class RgbaImage:
    width: int
    height: int
    pixels: bytes


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def _unfilter(raw: bytes, width: int, height: int, bytes_per_pixel: int) -> bytes:
    stride = width * bytes_per_pixel
    rows: list[bytes] = []
    offset = 0
    previous = bytearray(stride)
    for _y in range(height):
        filter_type = raw[offset]
        offset += 1
        current = bytearray(raw[offset : offset + stride])
        offset += stride
        for x in range(stride):
            left = current[x - bytes_per_pixel] if x >= bytes_per_pixel else 0
            up = previous[x]
            up_left = previous[x - bytes_per_pixel] if x >= bytes_per_pixel else 0
            if filter_type == 1:
                current[x] = (current[x] + left) & 0xFF
            elif filter_type == 2:
                current[x] = (current[x] + up) & 0xFF
            elif filter_type == 3:
                current[x] = (current[x] + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                current[x] = (current[x] + _paeth(left, up, up_left)) & 0xFF
            elif filter_type != 0:
                raise ValueError(f"unsupported png filter: {filter_type}")
        rows.append(bytes(current))
        previous = current
    return b"".join(rows)


def read_rgba_png(path: Path) -> RgbaImage:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"not a png file: {path}")
    offset = len(PNG_SIGNATURE)
    width = 0
    height = 0
    bit_depth = 0
    color_type = 0
    idat = bytearray()
    while offset < len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        offset += 4
        kind = data[offset : offset + 4]
        offset += 4
        chunk = data[offset : offset + length]
        offset += length + 4
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _compression, _filter, _interlace = struct.unpack(">IIBBBBB", chunk)
        elif kind == b"IDAT":
            idat.extend(chunk)
        elif kind == b"IEND":
            break
    if bit_depth != 8 or color_type != 6:
        raise ValueError(f"only 8-bit RGBA PNG is supported: {path}")
    raw = zlib.decompress(bytes(idat))
    return RgbaImage(width, height, _unfilter(raw, width, height, 4))


def write_rgba_png(path: Path, image: RgbaImage) -> None:
    def chunk(kind: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)

    stride = image.width * 4
    raw_rows = []
    for y in range(image.height):
        start = y * stride
        raw_rows.append(b"\x00" + image.pixels[start : start + stride])
    payload = (
        PNG_SIGNATURE
        + chunk(b"IHDR", struct.pack(">IIBBBBB", image.width, image.height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(b"".join(raw_rows)))
        + chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)

