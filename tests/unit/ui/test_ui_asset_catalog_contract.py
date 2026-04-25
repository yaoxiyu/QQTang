from __future__ import annotations

import csv
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CSV_PATH = ROOT / "content_source" / "csv" / "ui" / "ui_asset_catalog.csv"
JSON_PATH = ROOT / "content" / "ui_assets" / "catalog" / "ui_asset_catalog.json"


class UiAssetCatalogContractTests(unittest.TestCase):
    def test_json_catalog_has_unique_enabled_asset_ids(self) -> None:
        data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
        assets = [item for item in data["assets"] if item.get("enabled")]
        asset_ids = [item["asset_id"] for item in assets]
        self.assertEqual(len(asset_ids), len(set(asset_ids)))
        self.assertIn("ui.placeholder.missing", asset_ids)

    def test_csv_seed_matches_json_asset_ids(self) -> None:
        with CSV_PATH.open(newline="", encoding="utf-8") as handle:
            rows = [row for row in csv.DictReader(handle) if row["enabled"].lower() == "true"]
        csv_ids = {row["asset_id"] for row in rows}
        json_data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
        json_ids = {item["asset_id"] for item in json_data["assets"] if item.get("enabled")}
        self.assertEqual(csv_ids, json_ids)

    def test_battle_hud_catalog_covers_required_asset_ids(self) -> None:
        asset_ids_script = (ROOT / "presentation" / "battle" / "hud" / "battle_hud_asset_ids.gd").read_text(encoding="utf-8")
        json_data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
        json_ids = {item["asset_id"] for item in json_data["assets"] if item.get("enabled")}
        required_ids = {
            "ui.battle.hud.timer.frame",
            "ui.battle.hud.countdown.frame",
            "ui.battle.hud.player_row",
            "ui.battle.hud.score_panel",
            "ui.battle.hud.team_score.red",
            "ui.battle.hud.team_score.blue",
            "ui.battle.hud.local_status.frame",
            "ui.battle.hud.hp_bar.frame",
            "ui.battle.hud.hp_bar.fill",
            "ui.battle.item_slot.empty",
            "ui.battle.item_slot.active",
            "ui.battle.item_slot.cooldown",
            "ui.battle.hud.toast.frame",
            "ui.battle.hud.network.good",
            "ui.battle.hud.network.warning",
            "ui.battle.hud.network.bad",
        }
        self.assertTrue(required_ids.issubset(json_ids))
        for asset_id in required_ids:
            self.assertIn(asset_id, asset_ids_script)

    def test_login_catalog_covers_required_asset_ids(self) -> None:
        json_data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
        json_ids = {item["asset_id"] for item in json_data["assets"] if item.get("enabled")}
        required_ids = {
            "ui.login.bg.main",
            "ui.login.logo.main",
            "ui.login.panel.auth",
            "ui.login.input.account.normal",
            "ui.login.input.account.focused",
            "ui.login.input.password.normal",
            "ui.login.input.password.focused",
            "ui.login.button.login.normal",
            "ui.login.button.login.hover",
            "ui.login.button.login.pressed",
            "ui.login.button.login.disabled",
            "ui.login.button.register.normal",
            "ui.login.button.guest.normal",
            "ui.login.label.error",
            "ui.login.label.server_status",
        }
        self.assertTrue(required_ids.issubset(json_ids))


if __name__ == "__main__":
    unittest.main()
