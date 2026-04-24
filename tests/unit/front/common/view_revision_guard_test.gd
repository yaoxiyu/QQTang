extends "res://tests/gut/base/qqt_unit_test.gd"

const ViewRevisionGuardScript = preload("res://app/front/common/view_revision_guard.gd")


func test_same_key_and_revision_is_skipped_after_first_seen() -> void:
	var guard := ViewRevisionGuardScript.new()

	assert_false(guard.should_skip("room_alpha", 10), "first revision should not be skipped")
	assert_true(guard.should_skip("room_alpha", 10), "same key and revision should be skipped")


func test_new_revision_is_not_skipped() -> void:
	var guard := ViewRevisionGuardScript.new()

	assert_false(guard.should_skip("room_alpha", 10), "first revision should not be skipped")
	assert_false(guard.should_skip("room_alpha", 11), "new revision should not be skipped")


func test_reset_clears_cached_revision() -> void:
	var guard := ViewRevisionGuardScript.new()

	assert_false(guard.should_skip("room_alpha", 10), "first revision should not be skipped")
	assert_true(guard.should_skip("room_alpha", 10), "same revision should be skipped")
	guard.reset()
	assert_false(guard.should_skip("room_alpha", 10), "reset should make same revision visible again")
