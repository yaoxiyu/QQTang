from __future__ import annotations

import unittest

from tools.asset_pipeline.core.path_policy import ensure_project_relative


class AssetPathPolicyTests(unittest.TestCase):
    def test_rejects_escape_and_absolute_paths(self) -> None:
        for path in ("../outside.png", "C:/absolute/path.png", "/tmp/outside.png", "res://../../outside.png"):
            with self.subTest(path=path):
                with self.assertRaises(ValueError):
                    ensure_project_relative(path)

    def test_accepts_project_relative_paths(self) -> None:
        self.assertEqual(ensure_project_relative("source/down.png").as_posix(), "source/down.png")
        self.assertEqual(ensure_project_relative("res://assets/a.png").as_posix(), "assets/a.png")


if __name__ == "__main__":
    unittest.main()

