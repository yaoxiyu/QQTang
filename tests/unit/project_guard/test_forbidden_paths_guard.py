from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT_PATH = ROOT / "tools" / "project_guard" / "forbidden_paths_guard.py"


def load_guard_module():
    spec = importlib.util.spec_from_file_location("forbidden_paths_guard", SCRIPT_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("failed to load forbidden path guard module")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ForbiddenPathTests(unittest.TestCase):
    def setUp(self) -> None:
        self.guard = load_guard_module()

    def test_directory_forbidden_path_matches_child(self) -> None:
        violations = self.guard.find_violations(
            ["services/game_service/internal/queue/assignment.go"],
            ["services/game_service/internal/queue/"],
        )
        self.assertEqual(violations, ["services/game_service/internal/queue/assignment.go matches services/game_service/internal/queue/"])

    def test_file_forbidden_path_matches_exact_file_only(self) -> None:
        violations = self.guard.find_violations(
            [
                "scenes/battle/battle_flow_coordinator.gd",
                "scenes/battle/battle_flow_coordinator_notes.md",
            ],
            ["scenes/battle/battle_flow_coordinator.gd"],
        )
        self.assertEqual(violations, ["scenes/battle/battle_flow_coordinator.gd matches scenes/battle/battle_flow_coordinator.gd"])

    def test_allowed_path_has_no_violation(self) -> None:
        violations = self.guard.find_violations(
            ["services/account_service/internal/shop/catalog_provider.go"],
            ["services/game_service/internal/queue/"],
        )
        self.assertEqual(violations, [])


if __name__ == "__main__":
    unittest.main()


