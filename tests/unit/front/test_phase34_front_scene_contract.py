from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


class Phase34FrontSceneContractTests(unittest.TestCase):
    def test_shop_and_inventory_scenes_are_registered(self) -> None:
        scene_flow = (ROOT / "app" / "flow" / "scene_flow_controller.gd").read_text(encoding="utf-8")
        self.assertIn('SHOP_SCENE_PATH: String = "res://scenes/front/shop_scene.tscn"', scene_flow)
        self.assertIn('INVENTORY_SCENE_PATH: String = "res://scenes/front/inventory_scene.tscn"', scene_flow)
        self.assertIn("func change_to_shop_scene()", scene_flow)
        self.assertIn("func change_to_inventory_scene()", scene_flow)

    def test_front_flow_has_shop_and_inventory_states(self) -> None:
        front_flow = (ROOT / "app" / "flow" / "front_flow_controller.gd").read_text(encoding="utf-8")
        self.assertIn("SHOP,", front_flow)
        self.assertIn("INVENTORY,", front_flow)
        self.assertIn("func enter_shop()", front_flow)
        self.assertIn("func enter_inventory()", front_flow)

    def test_lobby_and_room_bind_phase34_front_state(self) -> None:
        lobby_state = (ROOT / "app" / "front" / "lobby" / "lobby_view_state.gd").read_text(encoding="utf-8")
        lobby_controller = (ROOT / "scenes" / "front" / "lobby_scene_controller.gd").read_text(encoding="utf-8")
        room_binder = (ROOT / "scenes" / "front" / "room_scene_view_binder.gd").read_text(encoding="utf-8")
        self.assertIn("wallet_summary_text", lobby_state)
        self.assertIn("inventory_status_text", lobby_state)
        self.assertIn("shop_status_text", lobby_state)
        self.assertIn("_ensure_phase34_summary_rows", lobby_controller)
        self.assertIn('profile.get("title_id")', room_binder)
        self.assertIn('profile.get("avatar_id")', room_binder)

    def test_lobby_scene_is_phase34_formalized(self) -> None:
        lobby_controller = (ROOT / "scenes" / "front" / "lobby_scene_controller.gd").read_text(encoding="utf-8")
        self.assertIn("_apply_formal_lobby_layout", lobby_controller)
        self.assertIn("_build_reference_lobby_layout", lobby_controller)
        self.assertIn("ReferenceLobbyLayout", lobby_controller)
        self.assertIn("_create_reference_room_card", lobby_controller)
        self.assertIn("_reparent_account_card_children", lobby_controller)
        self.assertIn("_apply_phase34_lobby_asset_ids", lobby_controller)
        self.assertIn('set_meta("ui_asset_id"', lobby_controller)
        self.assertIn("ui.lobby.bg.main", lobby_controller)
        self.assertIn("ui.lobby.button.shop.normal", lobby_controller)

    def test_loading_uses_task_progress_aggregator(self) -> None:
        loading_use_case = (ROOT / "app" / "front" / "loading" / "loading_use_case.gd").read_text(encoding="utf-8")
        aggregator = (ROOT / "app" / "front" / "loading" / "loading_progress_aggregator.gd").read_text(encoding="utf-8")
        self.assertIn("AsyncLoadingPlanScript", loading_use_case)
        self.assertIn("_progress_aggregator.aggregate", loading_use_case)
        self.assertIn("weighted_progress", aggregator)
        self.assertNotIn("progress +=", loading_use_case)

    def test_battle_hud_binds_resource_ids_without_core_paths(self) -> None:
        hud_controller = (ROOT / "presentation" / "battle" / "hud" / "battle_hud_controller.gd").read_text(encoding="utf-8")
        hud_binder = (ROOT / "presentation" / "battle" / "hud" / "battle_hud_resource_binder.gd").read_text(encoding="utf-8")
        self.assertIn("BattleHudResourceBinderScript", hud_controller)
        self.assertIn("_bind_hud_resource_ids", hud_controller)
        self.assertIn("_apply_formal_hud_layout", hud_controller)
        self.assertIn("_ensure_reference_item_bar", hud_controller)
        self.assertIn("ReferenceItemBar", hud_controller)
        self.assertIn("hud_asset_bindings", hud_controller)
        self.assertIn('set_meta("ui_asset_id"', hud_binder)
        self.assertNotIn("res://assets/ui/battle", hud_controller)

    def test_room_loading_shop_inventory_are_phase34_formalized(self) -> None:
        room_controller = (ROOT / "scenes" / "front" / "room_scene_controller.gd").read_text(encoding="utf-8")
        loading_controller = (ROOT / "scenes" / "front" / "loading_scene_controller.gd").read_text(encoding="utf-8")
        shop_controller = (ROOT / "scenes" / "front" / "shop_scene_controller.gd").read_text(encoding="utf-8")
        inventory_controller = (ROOT / "scenes" / "front" / "inventory_scene_controller.gd").read_text(encoding="utf-8")
        self.assertIn("_apply_formal_room_layout", room_controller)
        self.assertIn("_build_reference_room_layout", room_controller)
        self.assertIn("ReferenceRoomLayout", room_controller)
        self.assertIn("_move_node_to", room_controller)
        self.assertIn("ui.room.bg.main", room_controller)
        self.assertIn("ui.room.button.ready.normal", room_controller)
        self.assertIn("_ensure_loading_background", loading_controller)
        self.assertIn("_build_reference_loading_layout", loading_controller)
        self.assertIn("_update_reference_progress", loading_controller)
        self.assertIn("ReferenceLoadingLayout", loading_controller)
        self.assertIn("ui.loading.bg.main", loading_controller)
        self.assertIn("ui.loading.panel.task", loading_controller)
        self.assertIn("ui.shop.bg.main", shop_controller)
        self.assertIn("ui.shop.panel.detail", shop_controller)
        self.assertIn("max_columns = 3", shop_controller)
        self.assertIn("ui.shop.tab.characters.normal", shop_controller)
        self.assertIn("ui.inventory.bg.main", inventory_controller)
        self.assertIn("ui.inventory.panel.grid", inventory_controller)
        self.assertIn("max_columns = 4", inventory_controller)
        self.assertIn("ui.inventory.tab.characters.normal", inventory_controller)

    def test_scene_files_reference_controllers(self) -> None:
        shop_scene = (ROOT / "scenes" / "front" / "shop_scene.tscn").read_text(encoding="utf-8")
        inventory_scene = (ROOT / "scenes" / "front" / "inventory_scene.tscn").read_text(encoding="utf-8")
        self.assertIn("res://scenes/front/shop_scene_controller.gd", shop_scene)
        self.assertIn("res://scenes/front/inventory_scene_controller.gd", inventory_scene)

    def test_login_scene_is_phase34_formalized(self) -> None:
        login_controller = (ROOT / "scenes" / "front" / "login_scene_controller.gd").read_text(encoding="utf-8")
        self.assertIn("_apply_formal_login_layout", login_controller)
        self.assertIn('set_meta("ui_asset_id"', login_controller)
        self.assertIn("ui.login.bg.main", login_controller)
        self.assertIn("ui.login.panel.auth", login_controller)
        self.assertIn("ui.login.button.login.normal", login_controller)
        self.assertNotIn("Register opens the browser registration page", login_controller)


if __name__ == "__main__":
    unittest.main()
