extends "res://tests/gut/base/qqt_contract_test.gd"

const VfxAnimationSetCatalogScript = preload("res://content/vfx_animation_sets/catalog/vfx_animation_set_catalog.gd")
const VfxAnimationSetLoaderScript = preload("res://content/vfx_animation_sets/runtime/vfx_animation_set_loader.gd")


func test_main() -> void:
	var vfx_set := VfxAnimationSetLoaderScript.load_vfx_set("vfx_jelly_trap_qqt_misc111")
	_assert_true(vfx_set != null, "loads QQT misc111 jelly trap vfx")
	if vfx_set == null:
		return
	_assert_true(vfx_set.sprite_frames.has_animation("enter"), "jelly trap has enter")
	_assert_true(vfx_set.sprite_frames.has_animation("loop"), "jelly trap has loop")
	_assert_true(vfx_set.sprite_frames.has_animation("release"), "jelly trap has release")
	_assert_true(vfx_set.sprite_frames.get_animation_loop("loop"), "jelly trap loop clip loops")
	_assert_true(not VfxAnimationSetCatalogScript.has_id("vfx_jelly_trap_default"), "legacy default jelly trap vfx is removed")


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
