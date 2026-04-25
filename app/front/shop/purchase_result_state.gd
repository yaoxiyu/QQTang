class_name PurchaseResultState
extends RefCounted

const WalletStateScript = preload("res://app/front/economy/wallet_state.gd")
const PlayerInventoryStateScript = preload("res://app/front/inventory/player_inventory_state.gd")
const SELF_SCRIPT = preload("res://app/front/shop/purchase_result_state.gd")

var purchase_id: String = ""
var offer_id: String = ""
var catalog_revision: int = 0
var status: String = ""
var wallet: RefCounted = null
var inventory: RefCounted = null
var profile_version: int = 0
var owned_asset_revision: int = 0
var wallet_revision: int = 0
var idempotent_replay: bool = false


static func from_response(data: Dictionary):
	var state = SELF_SCRIPT.new()
	state.purchase_id = String(data.get("purchase_id", ""))
	state.offer_id = String(data.get("offer_id", ""))
	state.catalog_revision = int(data.get("catalog_revision", 0))
	state.status = String(data.get("status", ""))
	if data.get("wallet", null) is Dictionary:
		state.wallet = WalletStateScript.from_response(data.get("wallet", {}))
	if data.get("inventory", null) is Dictionary:
		state.inventory = PlayerInventoryStateScript.from_response(data.get("inventory", {}))
	state.profile_version = int(data.get("profile_version", 0))
	state.owned_asset_revision = int(data.get("owned_asset_revision", 0))
	state.wallet_revision = int(data.get("wallet_revision", 0))
	state.idempotent_replay = bool(data.get("idempotent_replay", false))
	return state
