from __future__ import annotations

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from tools.asset_pipeline.core.png_rgba import RgbaImage, read_rgba_png, write_rgba_png
from tools.asset_pipeline.plugins.character.team_color_variant import TeamColor, recolor_image


class TeamColorVariantGeneratorTests(unittest.TestCase):
    def test_recolor_is_deterministic_and_preserves_alpha(self) -> None:
        with TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "source.png"
            mask = root / "mask.png"
            out_a = root / "a.png"
            out_b = root / "b.png"
            write_rgba_png(source, RgbaImage(1, 1, bytes([100, 100, 100, 77])))
            write_rgba_png(mask, RgbaImage(1, 1, bytes([255, 0, 0, 255])))
            color = TeamColor(1, "team_01", (80, 120, 200), (100, 140, 220), (20, 30, 60), (220, 230, 255))
            recolor_image(source, mask, out_a, color)
            recolor_image(source, mask, out_b, color)
            self.assertEqual(out_a.read_bytes(), out_b.read_bytes())
            self.assertEqual(read_rgba_png(out_a).pixels[3], 77)


if __name__ == "__main__":
    unittest.main()

