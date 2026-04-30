from __future__ import annotations

import unittest

from tools.asset_pipeline.core.asset_spec_registry import get_spec


class AssetSpecRegistryTests(unittest.TestCase):
    def test_registered_phase38_specs_are_queryable(self) -> None:
        self.assertEqual(get_spec("character_sprite_100_v1").asset_type, "character")
        self.assertEqual(get_spec("bubble_animation_64_v1").asset_type, "bubble")
        self.assertEqual(get_spec("map_tile_48_v1").asset_type, "map_tile")
        self.assertEqual(get_spec("vfx_jelly_trap_128_v1").asset_type, "vfx_jelly_trap")

    def test_unknown_spec_fails_clearly(self) -> None:
        with self.assertRaisesRegex(KeyError, "unknown asset spec"):
            get_spec("missing_spec")


if __name__ == "__main__":
    unittest.main()

