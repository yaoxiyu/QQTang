extends Control

const ROOM_ASSETS := preload("res://content/ui_assets/room_assets.tres")
const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const RoomCharacterPreviewScene = preload("res://scenes/front/components/room_character_preview.tscn")
const RoomViewModelBuilderScript = preload("res://app/front/room/room_view_model_builder.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const RoomTooltipAssets = preload("res://content/ui_assets/room_tooltip_assets.tres")

const TAG := "front.room.scene"
const SLOT_COUNT := 8
const MIN_OPEN := 2
const RANDOM_CHAR_ID := "12301"

var _app_runtime: Node = null
var _room_controller: Node = null
var _front_flow: Node = null
var _room_use_case = null
var _vm_builder = RoomViewModelBuilderScript.new()
var _last_snapshot = null
var _last_vm: Dictionary = {}
var _closed_slots: Dictionary = {}
var _open_slot_count: int = SLOT_COUNT
var _category: String = "normal"
var _page: int = 0
var _selected_char_id: String = ""
var _selected_team_id: int = 1
var _icon_cache: Dictionary = {}
var _char_entries: Array = []
var _char_cache_sig: String = ""
var _tooltip: Control = null
var _tooltip_cid: String = ""

@onready var bg_panel: PanelContainer = $BgPanel
@onready var bg_texture: TextureRect = $BgPanel/BgTexture
@onready var slot_row_top: HBoxContainer = $CharacterSlotsPanel/SlotRowTop
@onready var slot_row_bottom: HBoxContainer = $CharacterSlotsPanel/SlotRowBottom
@onready var choose_mode_btn: TextureButton = $RuleSelect/ChooseModeBtn
@onready var room_prop_btn: TextureButton = $RuleSelect/RoomPropBtn
@onready var choose_map_btn: TextureButton = $RuleSelect/ChooseMapBtn
@onready var map_preview: TextureRect = $MapPreview
@onready var normal_tab_btn: TextureButton = $RoleSelectPanel/CharacterTab/NormalTabBtn
@onready var vip_tab_btn: TextureButton = $RoleSelectPanel/CharacterTab/VipTabBtn
@onready var prev_char_btn: TextureButton = $RoleSelectPanel/PrevCharBtn
@onready var character_grid: GridContainer = $RoleSelectPanel/CharacterGrid
@onready var next_char_btn: TextureButton = $RoleSelectPanel/NextCharBtn
@onready var team_select_row: HBoxContainer = $RoleSelectPanel/TeamSelectRow
@onready var room_action_btn: TextureButton = $BottomBar/RoomActionBtn
@onready var leave_btn: TextureButton = $BottomBar/LeaveBtn


func _ready() -> void:
	_apply_bg()
	_setup_team_btns()
	_connect_signals()
	_bind_runtime()
	_refresh_char_grid()
	_connect_role_nav()
	LogFrontScript.debug("[room_fml] _ready", "", 0, TAG)


func _exit_tree() -> void:
	if _room_controller != null:
		if _room_controller.room_snapshot_changed.is_connected(_on_snapshot):
			_room_controller.room_snapshot_changed.disconnect(_on_snapshot)
		if _room_controller.start_match_requested.is_connected(_on_start_match):
			_room_controller.start_match_requested.disconnect(_on_start_match)
	if _room_use_case != null and _room_use_case.room_client_gateway != null and _room_use_case.room_client_gateway.room_snapshot_received.is_connected(_on_gateway):
		_room_use_case.room_client_gateway.room_snapshot_received.disconnect(_on_gateway)


func _apply_bg() -> void:
	var s := get_node_or_null("RoomScroll")
	if s: s.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var st: StyleBoxTexture = StyleBoxTexture.new()
	st.texture = bg_texture.texture
	bg_panel.add_theme_stylebox_override("panel", st)


# ═══ Runtime ═══

func _bind_runtime() -> void:
	_app_runtime = AppRuntimeRootScript.get_existing(get_tree())
	if _app_runtime == null: get_tree().change_scene_to_file("res://scenes/front/boot_scene.tscn"); return
	if _app_runtime.has_method("is_runtime_ready") and _app_runtime.is_runtime_ready(): _on_runtime_ready(); return
	if _app_runtime.has_signal("runtime_ready") and not _app_runtime.runtime_ready.is_connected(_on_runtime_ready):
		_app_runtime.runtime_ready.connect(_on_runtime_ready, CONNECT_ONE_SHOT)


func _on_runtime_ready() -> void:
	_room_controller = _app_runtime.room_session_controller
	_front_flow = _app_runtime.front_flow
	_room_use_case = _app_runtime.room_use_case
	_connect_runtime()
	if _app_runtime != null and _app_runtime.player_profile_state != null:
		var profile_char := PlayerProfileState.resolve_default_character_id(String(_app_runtime.player_profile_state.default_character_id))
		if CharacterCatalogScript.has_character(profile_char):
			_selected_char_id = profile_char
		elif CharacterCatalogScript.has_character(RANDOM_CHAR_ID):
			_selected_char_id = RANDOM_CHAR_ID
		else:
			_selected_char_id = CharacterCatalogScript.get_default_character_id()
		_save_char_to_profile(_selected_char_id)
	if _room_controller != null and _room_controller.has_method("build_room_snapshot"):
		var snap = _room_controller.build_room_snapshot()
		if snap != null:
			for member in snap.members:
				if member != null and member.is_local_player and int(member.team_id) > 0:
					_selected_team_id = int(member.team_id)
					break
		_refresh(snap)
	_refresh_char_grid()
	if _room_use_case != null:
		_room_use_case.update_local_profile("", _selected_char_id, "", _selected_team_id)


func _connect_runtime() -> void:
	if _room_controller == null: return
	if not _room_controller.room_snapshot_changed.is_connected(_on_snapshot):
		_room_controller.room_snapshot_changed.connect(_on_snapshot)
	if not _room_controller.start_match_requested.is_connected(_on_start_match):
		_room_controller.start_match_requested.connect(_on_start_match)
	if _room_use_case != null and _room_use_case.room_client_gateway != null and not _room_use_case.room_client_gateway.room_snapshot_received.is_connected(_on_gateway):
		_room_use_case.room_client_gateway.room_snapshot_received.connect(_on_gateway)


func _on_snapshot(snapshot) -> void: _last_snapshot = snapshot; _refresh(snapshot)
func _on_gateway(_s) -> void: if _room_controller != null and _room_controller.has_method("build_room_snapshot"): call_deferred("_refresh", _room_controller.build_room_snapshot())


func _refresh(snapshot) -> void:
	_last_snapshot = snapshot
	if _vm_builder != null and _app_runtime != null:
		_last_vm = _vm_builder.build_view_model(snapshot, _room_controller.room_runtime_context if _room_controller != null else null, _app_runtime.player_profile_state, _app_runtime.current_room_entry_context)
	_sync_selected_team_from_snapshot(snapshot, _last_vm)
	_refresh_slots(snapshot, _last_vm)
	_refresh_actions(snapshot, _last_vm)
	_refresh_props(snapshot, _last_vm)


func _sync_selected_team_from_snapshot(snapshot, vm: Dictionary) -> void:
	var team_id := int(vm.get("local_team_id", 0))
	if snapshot != null:
		for member in snapshot.members:
			if member != null and member.is_local_player and int(member.team_id) > 0:
				team_id = int(member.team_id)
				break
	if team_id <= 0:
		return
	_selected_team_id = clampi(team_id, 1, 8)
	_move_checkmark(_selected_team_id)


func _on_start_match(snapshot) -> void:
	if _app_runtime == null or _front_flow == null: return
	if String(snapshot.topology) == "dedicated_server": return
	var cfg = _app_runtime.build_and_store_start_config(snapshot)
	if cfg == null or cfg.match_id.is_empty(): return
	if _front_flow.has_method("request_start_match"): _front_flow.request_start_match()


# ═══ Team buttons (static tscn nodes, only move CheckMark) ═══

func _setup_team_btns() -> void:
	for i in range(8):
		var btn: TextureButton = _team_btn(i)
		if btn and not btn.pressed.is_connected(_on_team_btn):
			btn.pressed.connect(_on_team_btn.bind(i + 1))


func _team_btn(index: int) -> TextureButton:
	if index < team_select_row.get_child_count():
		return team_select_row.get_child(index) as TextureButton
	return null


func _find_checkmark() -> TextureRect:
	for i in range(8):
		var btn: TextureButton = _team_btn(i)
		if btn:
			var c: TextureRect = btn.get_node_or_null("CheckMark") as TextureRect
			if c: return c
	return null


func _move_checkmark(tid: int) -> void:
	var check: TextureRect = _find_checkmark()
	if check == null: return
	for i in range(8):
		var btn: TextureButton = _team_btn(i)
		if btn and i + 1 == tid and check.get_parent() != btn:
			check.get_parent().remove_child(check)
			btn.add_child(check)
			return


func _on_team_btn(tid: int) -> void:
	_move_checkmark(tid)
	_selected_team_id = tid
	if _room_use_case != null:
		_room_use_case.update_local_profile("", _selected_char_id, "", tid)
	LogFrontScript.debug("[room_fml] team: %d char=%s" % [tid, _selected_char_id], "", 0, TAG)


# ═══ Character grid — UPDATE existing tscn TextureButtons, NEVER replace ═══

func _refresh_char_grid() -> void:
	var entries: Array = _get_entries()
	var mp: int = _get_max_page(entries.size())
	_page = clampi(_page, 0, mp)
	for child in character_grid.get_children():
		if child is TextureButton:
			var tb: TextureButton = child as TextureButton
			if tb.mouse_entered.is_connected(_on_char_hover):
				tb.mouse_entered.disconnect(_on_char_hover)
			if tb.mouse_exited.is_connected(_on_char_hover):
				tb.mouse_exited.disconnect(_on_char_hover)
	var start: int = _page * 8
	for i in range(8):
		var btn: TextureButton = character_grid.get_child(i) as TextureButton if i < character_grid.get_child_count() else null
		if btn == null: continue
		var ei: int = start + i
		if ei >= entries.size():
			btn.texture_normal = null; btn.visible = false; continue
		btn.visible = true
		var e: Dictionary = entries[ei]
		var cid: String = String(e.get("id", ""))
		btn.set_meta("character_id", cid)
		var icon: String = String(e.get("selection_icon_path", ""))
		var icon_sel: String = String(e.get("selection_icon_selected_path", ""))
		btn.set_meta("icon_path", icon)
		btn.set_meta("icon_selected_path", icon_sel)
		var normal_tex := _load_icon(icon)
		var hover_tex := _load_icon(icon_sel)
		var is_selected := _selected_char_id == cid
		btn.texture_normal = hover_tex if is_selected else normal_tex
		btn.texture_hover = hover_tex
		btn.texture_pressed = hover_tex
		btn.tooltip_text = String(e.get("display_name", cid))
		btn.mouse_entered.connect(_on_char_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_char_hover.bind(btn, false))
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn.callable)
		btn.pressed.connect(_on_char_picked.bind(cid))
	prev_char_btn.disabled = _page <= 0
	next_char_btn.disabled = _page >= mp


func _on_char_picked(cid: String) -> void:
	if cid.is_empty(): return
	_selected_char_id = cid
	_save_char_to_profile(cid)
	for child in character_grid.get_children():
		if child is TextureButton:
			var b: TextureButton = child as TextureButton
			var bcid: String = String(b.get_meta("character_id", ""))
			var is_sel := bcid == cid
			var normal_path: String = String(b.get_meta("icon_selected_path", "")) if is_sel else String(b.get_meta("icon_path", ""))
			var hover_path: String = String(b.get_meta("icon_selected_path", ""))
			if not normal_path.is_empty():
				b.texture_normal = _load_icon(normal_path)
				b.texture_hover = _load_icon(hover_path)
				b.texture_pressed = _load_icon(hover_path)
	if _room_use_case != null:
		_room_use_case.update_local_profile("", cid, "", _selected_team_id)
	LogFrontScript.debug("[room_fml] char: %s team=%d" % [cid, _selected_team_id], "", 0, TAG)


func _on_char_hover(btn: TextureButton, hovered: bool) -> void:
	var cid: String = String(btn.get_meta("character_id", ""))
	if hovered and not cid.is_empty() and cid != RANDOM_CHAR_ID:
		_show_tooltip(cid)
	else:
		_hide_tooltip()


# ── Tooltip ──

func _ensure_tooltip() -> void:
	if _tooltip != null: return
	_tooltip = Control.new()
	_tooltip.name = "CharacterTooltip"
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 100
	_tooltip.custom_minimum_size = Vector2(256, 271)
	add_child(_tooltip)


func _show_tooltip(cid: String) -> void:
	if cid == _tooltip_cid and _tooltip != null and _tooltip.visible: return
	_ensure_tooltip()
	if _tooltip == null: return
	for child in _tooltip.get_children(): child.queue_free()
	var meta: Dictionary = CharacterCatalogScript.get_character_metadata(cid)
	if meta.is_empty(): return
	_tooltip_cid = cid

	var ill: String = String(meta.get("illustration_path", ""))
	if not ill.is_empty():
		var tex: Texture2D = _load_icon(ill)
		if tex != null:
			var r: TextureRect = TextureRect.new(); r.texture = tex; r.size = tex.get_size()
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE; r.set_position(RoomTooltipAssets.illustration_offset)
			_tooltip.add_child(r)

	var panel_tex: Texture2D = _load_icon(RoomTooltipAssets.panel_background_path)
	if panel_tex != null:
		var r: TextureRect = TextureRect.new(); r.texture = panel_tex; r.size = panel_tex.get_size()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE; r.set_position(RoomTooltipAssets.panel_offset)
		_tooltip.add_child(r)

	var nm: String = String(meta.get("name_image_path", ""))
	if not nm.is_empty():
		var ntex: Texture2D = _load_icon(nm)
		if ntex != null:
			var r: TextureRect = TextureRect.new(); r.texture = ntex; r.size = ntex.get_size()
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE; r.set_position(RoomTooltipAssets.panel_offset + RoomTooltipAssets.name_offset)
			_tooltip.add_child(r)

	var gp: Vector2 = character_grid.global_position
	_tooltip.set_position(gp + RoomTooltipAssets.tooltip_anchor_offset)
	var ib: int = int(meta.get("initial_bubble_count", 1)); var mb: int = int(meta.get("max_bubble_count", 5))
	var ip: int = int(meta.get("initial_bubble_power", 1)); var mp: int = int(meta.get("max_bubble_power", 5))
	var is_: int = int(meta.get("initial_move_speed", 1)); var ms: int = int(meta.get("max_move_speed", 9))
	_add_stat_icons(RoomTooltipAssets.bomb_icon_path, ib, mb, 0)
	_add_stat_icons(RoomTooltipAssets.power_icon_path, ip, mp, 1)
	_add_stat_icons(RoomTooltipAssets.speed_icon_path, is_, ms, 2)
	_tooltip.visible = true


func _hide_tooltip() -> void:
	_tooltip_cid = ""
	if _tooltip != null: _tooltip.visible = false


func _add_stat_icons(icon_path: String, initial: int, max_val: int, row_index: int) -> void:
	if _tooltip == null: return
	var tex: Texture2D = _load_icon(icon_path)
	if tex == null: return
	var max_icons: int = mini(max_val, 9)
	var filled: int = clampi(initial, 0, max_icons)
	var dim: int = max_icons - filled
	var origin: Vector2 = RoomTooltipAssets.panel_offset + RoomTooltipAssets.stat_offset + Vector2(0, float(row_index) * RoomTooltipAssets.stat_row_gap)
	for fi in range(filled):
		var icon: TextureRect = TextureRect.new(); icon.texture = tex; icon.size = tex.get_size()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE; icon.set_position(origin + Vector2(float(fi) * RoomTooltipAssets.stat_icon_step, 0))
		_tooltip.add_child(icon)
	for di in range(dim):
		var icon: TextureRect = TextureRect.new(); icon.texture = tex; icon.size = tex.get_size()
		icon.modulate = Color(1, 1, 1, RoomTooltipAssets.stat_dim_alpha); icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_position(origin + Vector2(float(filled + di) * RoomTooltipAssets.stat_icon_step, 0))
		_tooltip.add_child(icon)


# ── Character data ──

func _get_entries() -> Array:
	var sig: String = _category
	if sig == _char_cache_sig: return _char_entries.duplicate(true)
	var entries: Array = []
	for entry in CharacterCatalogScript.get_character_selector_entries():
		var cid: String = String(entry.get("id", "")).strip_edges()
		if cid.is_empty(): continue
		var tp: int = int(entry.get("type", 0))
		if _category == "normal":
			if cid == RANDOM_CHAR_ID: continue
			if tp != CharacterCatalogScript.TYPE_DEFAULT_SELECTABLE: continue
		elif tp != CharacterCatalogScript.TYPE_VIP_SELECTABLE: continue
		entries.append({"id": cid, "display_name": String(entry.get("display_name", cid)),
			"selection_order": int(entry.get("selection_order", 999999)),
			"selection_icon_path": String(entry.get("selection_icon_path", "")),
			"selection_icon_selected_path": String(entry.get("selection_icon_selected_path", ""))})
	if _category == "normal":
		var re: Dictionary = CharacterCatalogScript.get_character_entry(RANDOM_CHAR_ID)
		if not re.is_empty():
			entries.push_front({"id": RANDOM_CHAR_ID, "display_name": String(re.get("display_name", "随机角色")),
				"selection_order": -1, "selection_icon_path": String(re.get("selection_icon_path", "")),
				"selection_icon_selected_path": String(re.get("selection_icon_selected_path", ""))})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa: int = int(a.get("selection_order", 999999)); var ob: int = int(b.get("selection_order", 999999))
		if oa == ob: return String(a.get("display_name", "")).naturalnocasecmp_to(String(b.get("display_name", ""))) < 0
		return oa < ob)
	_char_cache_sig = sig; _char_entries = entries.duplicate(true)
	return entries


func _get_max_page(n: int) -> int: return 0 if n <= 0 else int(ceil(float(n) / 8.0)) - 1


# ── Tabs / page ──

func _connect_signals() -> void:
	normal_tab_btn.pressed.connect(_on_normal)
	vip_tab_btn.pressed.connect(_on_vip)
	prev_char_btn.pressed.connect(_on_prev)
	next_char_btn.pressed.connect(_on_next)
	leave_btn.pressed.connect(_on_leave)
	room_action_btn.pressed.connect(_on_action)
	choose_mode_btn.pressed.connect(_on_mode)
	room_prop_btn.pressed.connect(_on_prop)
	choose_map_btn.pressed.connect(_on_map)


func _on_normal() -> void: _category = "normal"; _page = 0; _char_cache_sig = ""; normal_tab_btn.button_pressed = true; vip_tab_btn.button_pressed = false; _refresh_char_grid()
func _on_vip() -> void: _category = "vip"; _page = 0; _char_cache_sig = ""; vip_tab_btn.button_pressed = true; normal_tab_btn.button_pressed = false; _refresh_char_grid()
func _on_prev() -> void: if _page > 0: _page -= 1; _refresh_char_grid()
func _on_next() -> void: var entries: Array = _get_entries(); if _page < _get_max_page(entries.size()): _page += 1; _refresh_char_grid()


# ═══ Slots (dynamic rebuild inside SlotGrid only — parent layout untouched) ═══

func _refresh_slots(snapshot, vm: Dictionary) -> void:
	if snapshot == null: return
	var open_count: int = _resolve_open(snapshot, vm)
	var maxp: int = int(vm.get("max_player_count", snapshot.max_players))
	if maxp <= 0: maxp = SLOT_COUNT
	for i in range(SLOT_COUNT):
		var row: HBoxContainer = slot_row_top if i < 4 else slot_row_bottom
		var idx: int = i if i < 4 else i - 4
		if idx >= row.get_child_count(): continue
		var btn: TextureButton = row.get_child(idx) as TextureButton
		if btn == null: continue
		# Clean up runtime overlays from previous refresh
		for child in btn.get_children():
			if child.name == "SlotClosedOverlay" or child.has_method("configure_preview"):
				child.queue_free()
		var m = _find_member(snapshot, i)
		var is_open: bool = i < open_count
		if bool(vm.get("is_custom_room", false)): is_open = _is_slot_open(i, maxp)
		# Toggle static TeamColor visibility
		var tc: TextureRect = btn.get_node_or_null("TeamColor") as TextureRect
		if m != null:
			btn.tooltip_text = m.player_name
			_add_preview(btn, m.character_id, 126.0, m.team_id)
			if tc:
				tc.texture = load(ROOM_ASSETS.get("team_color_strip_%d_path" % clampi(m.team_id, 1, 8)) as String)
				tc.visible = true
				var nl: Label = tc.get_node_or_null("PlayerName") as Label
				if nl: nl.text = m.player_name
			btn.disabled = false
		else:
			if tc: tc.visible = false
			if is_open:
				btn.tooltip_text = "空位"
				btn.disabled = not _can_toggle(vm)
			else:
				btn.tooltip_text = "已关闭"
				btn.disabled = not _can_toggle(vm)
				var ov: TextureRect = TextureRect.new()
				ov.name = "SlotClosedOverlay"; ov.texture = load(ROOM_ASSETS.slot_closed_overlay_path)
				ov.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ov.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
				ov.set_anchors_preset(Control.PRESET_FULL_RECT); ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(ov)





func _add_team_overlay(btn: Button, tid: int, name_str: String, top: bool) -> void:
	var path: String = ROOM_ASSETS.get("team_color_strip_%d_path" % clampi(tid, 1, 8)) as String
	var strip: TextureRect = TextureRect.new()
	strip.name = "TeamColorStrip"; strip.texture = load(path)
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; strip.stretch_mode = TextureRect.STRETCH_KEEP
	strip.custom_minimum_size = Vector2(117, 20); strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.anchor_left = 0.5; strip.anchor_right = 0.5
	if top: strip.anchor_top = 0.0; strip.anchor_bottom = 0.0; strip.offset_left = -58; strip.offset_top = 2; strip.offset_right = 59; strip.offset_bottom = 22
	else: strip.anchor_top = 1.0; strip.anchor_bottom = 1.0; strip.offset_left = -58; strip.offset_top = -22; strip.offset_right = 59; strip.offset_bottom = -2
	btn.add_child(strip)
	var lbl: Label = Label.new()
	lbl.name = "PlayerName"; lbl.text = name_str
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10); lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT); strip.add_child(lbl)


func _add_preview(parent: Control, cid: String, size: float, team: int) -> void:
	if parent == null or cid.strip_edges().is_empty(): return
	var pv = RoomCharacterPreviewScene.instantiate()
	if pv == null: return
	if pv is Control:
		var pc: Control = pv as Control
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE; pc.custom_minimum_size = Vector2(size, size)
		pc.set_anchors_preset(Control.PRESET_FULL_RECT)
		pc.offset_left = 3.0; pc.offset_top = 3.0; pc.offset_right = -3.0; pc.offset_bottom = -3.0
		pc.set("stretch", true)
	parent.add_child(pv)
	if pv.has_method("configure_preview"): pv.call_deferred("configure_preview", cid, team)


func _find_member(snapshot, i: int):
	if snapshot == null: return null
	for m in snapshot.sorted_members():
		if m != null and int(m.slot_index) == i: return m
	return null


func _resolve_open(snapshot, vm: Dictionary) -> int:
	if bool(vm.get("is_match_room", false)): return clampi(int(snapshot.required_party_size), 1, SLOT_COUNT)
	if bool(vm.get("is_custom_room", false)): _sync_closed(snapshot, vm); return clampi(_open_slot_count, MIN_OPEN, SLOT_COUNT)
	return clampi(maxi(snapshot.members.size(), 1), 1, SLOT_COUNT)


func _is_slot_open(i: int, maxp: int) -> bool: return i < maxp and not _closed_slots.has(i)


func _sync_closed(snapshot, vm: Dictionary) -> void:
	_closed_slots.clear()
	if snapshot == null: return
	var mp: int = int(vm.get("max_player_count", snapshot.max_players))
	if mp <= 0: mp = SLOT_COUNT
	for i in range(SLOT_COUNT):
		var open: bool = snapshot.open_slot_indices.has(i)
		if snapshot.open_slot_indices.is_empty() and i < mp: open = true
		if i >= mp or not open: _closed_slots[i] = true
	_open_slot_count = mp if snapshot.open_slot_indices.is_empty() else snapshot.open_slot_indices.size()


func _can_toggle(vm: Dictionary) -> bool:
	return bool(vm.get("is_custom_room", false)) and bool(vm.get("can_edit_selection", false)) and _last_snapshot != null and _is_host()


func _on_slot_toggle(idx: int) -> void:
	if _last_snapshot == null or not _can_toggle(_last_vm): return
	if _find_member(_last_snapshot, idx) != null: return
	var open: Array = _last_snapshot.open_slot_indices.duplicate()
	if open.is_empty():
		var mp: int = int(_last_vm.get("max_player_count", _last_snapshot.max_players))
		if mp <= 0: mp = SLOT_COUNT
		for i in range(mp): open.append(i)
	if open.has(idx):
		if open.size() <= max(_last_snapshot.members.size(), MIN_OPEN): return
		open.erase(idx)
	else: open.append(idx)
	open.sort()
	if _room_use_case == null or _room_use_case.room_client_gateway == null: return
	_room_use_case.room_client_gateway.request_update_selection(String(_last_snapshot.selected_map_id), String(_last_snapshot.rule_set_id), String(_last_snapshot.mode_id), open)


# ═══ Actions ═══

func _refresh_actions(snapshot, vm: Dictionary) -> void:
	if snapshot == null or room_action_btn == null: return
	var host: bool = _is_host()
	var match: bool = bool(vm.get("is_match_room", false))
	if host and not match:
		_apply_action_tex("start"); room_action_btn.visible = true; room_action_btn.disabled = not bool(vm.get("can_start", false))
	elif not host:
		var rd: bool = bool(vm.get("local_member_ready", false))
		_apply_action_tex("unready" if rd else "ready"); room_action_btn.visible = true; room_action_btn.disabled = not bool(vm.get("can_ready", false))
	else: room_action_btn.visible = false


func _refresh_props(snapshot, vm: Dictionary) -> void:
	var custom: bool = bool(vm.get("is_custom_room", false)); var edit: bool = _is_host() and custom
	for b in [choose_mode_btn, room_prop_btn, choose_map_btn]:
		if b != null: b.visible = custom; b.disabled = not edit


func _is_host() -> bool:
	if _last_snapshot == null: return false
	for m in _last_snapshot.members:
		if m != null and m.is_local_player and m.is_owner: return true
	return _app_runtime != null and int(_app_runtime.local_peer_id) == int(_last_snapshot.owner_peer_id)


func _apply_action_tex(k: String) -> void:
	if room_action_btn == null: return
	var n: String; var h: String; var p: String; var d: String
	match k:
		"start": n = ROOM_ASSETS.btn_start_normal_path; h = ROOM_ASSETS.btn_start_hover_path; p = ROOM_ASSETS.btn_start_pressed_path; d = ROOM_ASSETS.btn_start_disabled_path
		"ready": n = ROOM_ASSETS.btn_ready_normal_path; h = ROOM_ASSETS.btn_ready_hover_path; p = ROOM_ASSETS.btn_ready_pressed_path; d = ROOM_ASSETS.btn_ready_disabled_path
		"unready": n = ROOM_ASSETS.btn_unready_normal_path; h = ROOM_ASSETS.btn_unready_hover_path; p = ROOM_ASSETS.btn_unready_pressed_path; d = ROOM_ASSETS.btn_unready_disabled_path
	room_action_btn.texture_normal = load(n); room_action_btn.texture_hover = load(h)
	room_action_btn.texture_pressed = load(p); room_action_btn.texture_disabled = load(d)


func _on_action() -> void:
	if _room_use_case == null: return
	if _is_host(): _room_use_case.start_match()
	else: _room_use_case.toggle_ready()


func _on_leave() -> void: if _room_use_case != null: _room_use_case.leave_room()
func _on_mode() -> void:
	_set_feedback("模式选择待接入弹窗UI")
func _on_prop() -> void:
	_set_feedback("房间属性编辑待接入弹窗UI")
func _on_map() -> void:
	if _room_use_case == null:
		_set_feedback("房间服务未连接"); return
	var popup := AcceptDialog.new()
	popup.title = "选择地图"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 460)
	popup.add_child(scroll)
	var vbox := VBoxContainer.new()
	scroll.add_child(vbox)
	for mode_entry in MapSelectionCatalogScript.get_custom_room_mode_entries():
		var mode_id := String(mode_entry.get("mode_id", ""))
		if mode_id.is_empty(): continue
		var mode_label := Label.new()
		mode_label.text = String(mode_entry.get("display_name", mode_id))
		mode_label.add_theme_font_size_override("font_size", 18)
		vbox.add_child(mode_label)
		for map_entry in MapSelectionCatalogScript.get_custom_room_maps_by_mode(mode_id):
			var map_id := String(map_entry.get("map_id", ""))
			if map_id.is_empty(): continue
			var max_p := int(map_entry.get("max_player_count", 8))
			var btn := Button.new()
			btn.text = "%s    %d人" % [String(map_entry.get("display_name", map_id)), max_p]
			btn.pressed.connect(func(): _on_map_selected(map_id); popup.hide())
			vbox.add_child(btn)
	add_child(popup); popup.popup_centered(Vector2i(360, 520))

func _on_map_selected(map_id: String) -> void:
	if _room_use_case == null: return
	var binding := MapSelectionCatalogScript.get_map_binding(map_id)
	var rule_set_id := String(binding.get("bound_rule_set_id", ""))
	var mode_id := String(binding.get("bound_mode_id", ""))
	if _room_use_case.room_client_gateway != null:
		_room_use_case.room_client_gateway.request_update_selection(map_id, rule_set_id, mode_id)
	_set_feedback("地图已选择: " + map_id)

func _set_feedback(msg: String) -> void:
	var label := get_node_or_null("FeedbackLabel")
	if label == null:
		label = Label.new(); label.name = "FeedbackLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		add_child(label)
		label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		label.position = Vector2(-200, -36)
	(label as Label).text = msg
	label.visible = true
	var timer := get_node_or_null("FeedbackTimer")
	if timer != null: timer.queue_free()
	timer = Timer.new(); timer.name = "FeedbackTimer"
	timer.wait_time = 3.0; timer.one_shot = true
	timer.timeout.connect(func(): if label != null: label.visible = false)
	add_child(timer); timer.start()


# ═══ Role nav anim ═══

func _connect_role_nav() -> void:
	_setup_nav(prev_char_btn, true); _setup_nav(next_char_btn, false)


func _setup_nav(btn: TextureButton, left: bool) -> void:
	var pfx: String = "left_role" if left else "right_role"
	btn.set_meta("r_frames", [ROOM_ASSETS.get("btn_%s_anim_0_path" % pfx) as String, ROOM_ASSETS.get("btn_%s_anim_1_path" % pfx) as String, ROOM_ASSETS.get("btn_%s_anim_2_path" % pfx) as String])
	btn.set_meta("r_anim", false)
	var t: Timer = Timer.new(); t.name = "RTimer"; t.wait_time = 3.0; t.one_shot = false; t.autostart = true
	btn.add_child(t); t.timeout.connect(_on_nav_tick.bind(btn))


func _on_nav_tick(btn: TextureButton) -> void:
	if btn.get_meta("r_anim", false): return
	btn.set_meta("r_anim", true); _nav_frame(btn, btn.get_meta("r_frames", []), 0)


func _nav_frame(btn: TextureButton, frames: Array, idx: int) -> void:
	if idx >= frames.size():
		btn.set_meta("r_anim", false)
		btn.texture_normal = load(ROOM_ASSETS.btn_left_role_normal_path if btn == prev_char_btn else ROOM_ASSETS.btn_right_role_normal_path)
		btn.texture_hover = load(ROOM_ASSETS.btn_left_role_hover_path if btn == prev_char_btn else ROOM_ASSETS.btn_right_role_hover_path)
		btn.texture_pressed = load(ROOM_ASSETS.btn_left_role_pressed_path if btn == prev_char_btn else ROOM_ASSETS.btn_right_role_pressed_path)
		return
	btn.texture_normal = load(frames[idx]); btn.texture_hover = load(frames[idx]); btn.texture_pressed = load(frames[idx])
	var ft: Timer = Timer.new(); ft.name = "FTimer"; ft.wait_time = 0.166; ft.one_shot = true
	btn.add_child(ft); ft.timeout.connect(Callable(self, "_nav_frame").bind(btn, frames, idx + 1)); ft.start()


# ═══ Helpers ═══

func _tex_style(p: String) -> StyleBoxTexture:
	var s: StyleBoxTexture = StyleBoxTexture.new(); s.texture = load(p); return s


func _save_char_to_profile(cid: String) -> void:
	if _app_runtime == null or _app_runtime.player_profile_state == null:
		return
	_app_runtime.player_profile_state.default_character_id = PlayerProfileState.resolve_default_character_id(cid)
	if _app_runtime.profile_repository != null and _app_runtime.profile_repository.has_method("save_profile"):
		_app_runtime.profile_repository.save_profile(_app_runtime.player_profile_state)

func _load_icon(path: String) -> Texture2D:
	var n: String = path.strip_edges()
	if n.is_empty(): return null
	if _icon_cache.has(n): return _icon_cache[n]
	if not FileAccess.file_exists(n): _icon_cache[n] = null; return null
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(n))
	if img == null or img.is_empty(): _icon_cache[n] = null; return null
	var t: ImageTexture = ImageTexture.create_from_image(img); _icon_cache[n] = t; return t
