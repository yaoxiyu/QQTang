class_name WalletState
extends RefCounted

const WalletBalanceStateScript = preload("res://app/front/economy/wallet_balance_state.gd")
const SELF_SCRIPT = preload("res://app/front/economy/wallet_state.gd")

var profile_id: String = ""
var wallet_revision: int = 0
var balances: Array = []
var last_sync_msec: int = 0


static func from_response(data: Dictionary):
	var state = SELF_SCRIPT.new()
	state.profile_id = String(data.get("profile_id", ""))
	state.wallet_revision = int(data.get("wallet_revision", 0))
	state.last_sync_msec = Time.get_ticks_msec()
	var raw_balances: Variant = data.get("balances", [])
	if raw_balances is Array:
		for item in raw_balances:
			if item is Dictionary:
				state.balances.append(WalletBalanceStateScript.from_dict(item))
	return state


func balance_of(currency_id: String) -> int:
	for balance in balances:
		if balance.currency_id == currency_id:
			return balance.balance
	return 0


func to_dict() -> Dictionary:
	var serialized: Array[Dictionary] = []
	for balance in balances:
		serialized.append(balance.to_dict())
	return {
		"profile_id": profile_id,
		"wallet_revision": wallet_revision,
		"balances": serialized,
		"last_sync_msec": last_sync_msec,
	}
