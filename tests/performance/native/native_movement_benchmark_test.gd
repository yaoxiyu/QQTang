extends QQTUnitTest

const NativeBenchmarkRunnerScript = preload("res://gameplay/native_bridge/native_benchmark_runner.gd")

func test_movement_benchmark_reports_real_native_parity_and_non_regression() -> void:
	var report := NativeBenchmarkRunnerScript.new().run_movement_benchmark(3)

	assert_true(report.has("baseline_avg_usec"), "movement benchmark report should expose baseline average")
	assert_true(report.has("native_avg_usec"), "movement benchmark report should expose native average")
	assert_true(report.has("baseline_p95_usec"), "movement benchmark report should expose baseline p95")
	assert_true(report.has("native_p95_usec"), "movement benchmark report should expose native p95")
	assert_true(report.has("baseline_max_usec"), "movement benchmark report should expose baseline max")
	assert_true(report.has("native_max_usec"), "movement benchmark report should expose native max")
	assert_true(report.get("sample_count", 0) > 0, "movement benchmark should collect real samples")
	assert_true(bool(report.get("native_runtime_available", false)), "movement benchmark should run with native runtime available")
	assert_true(bool(report.get("parity_ok", false)), "movement benchmark should preserve movement parity")
	assert_true(
		float(report.get("slowdown_ratio", 0.0)) <= float(report.get("max_allowed_slowdown_ratio", 0.0)),
		"movement benchmark should not regress beyond allowed slowdown ratio report=%s" % str(report)
	)
