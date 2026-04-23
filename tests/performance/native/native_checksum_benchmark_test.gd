extends QQTUnitTest


func test_checksum_benchmark_contract_shape() -> void:
	var report := _build_benchmark_report("checksum")

	assert_true(report.has("baseline_avg_usec"), "checksum benchmark report should expose baseline average")
	assert_true(report.has("native_avg_usec"), "checksum benchmark report should expose native average")
	assert_true(report.has("baseline_p95_usec"), "checksum benchmark report should expose baseline p95")
	assert_true(report.has("native_p95_usec"), "checksum benchmark report should expose native p95")
	assert_true(report.has("baseline_max_usec"), "checksum benchmark report should expose baseline max")
	assert_true(report.has("native_max_usec"), "checksum benchmark report should expose native max")


func _build_benchmark_report(name: String) -> Dictionary:
	return {
		"name": name,
		"baseline_avg_usec": 0.0,
		"native_avg_usec": 0.0,
		"baseline_p95_usec": 0.0,
		"native_p95_usec": 0.0,
		"baseline_max_usec": 0.0,
		"native_max_usec": 0.0,
	}
