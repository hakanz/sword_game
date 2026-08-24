extends SceneTree
## Headless unit-test runner.
## Run:  godot --headless --path . -s res://tests/test_runner.gd
## Exit code 0 = all green, 1 = failures, 2 = runner setup error.
## Discovers every res://tests/unit/test_*.gd (each extends tests/test_case.gd).

const TESTS_DIR: String = "res://tests/unit"


func _initialize() -> void:
	print("=== Arena Legends unit tests ===")
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		push_error("Test runner: cannot open %s" % TESTS_DIR)
		quit(2)
		return

	var files: PackedStringArray = dir.get_files()
	files.sort()
	var suites: int = 0
	var total_assertions: int = 0
	var all_failures: PackedStringArray = []

	for file in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load(TESTS_DIR + "/" + file)
		var case: TestCase = script.new()
		var result: Dictionary = case.run_all()
		suites += 1
		total_assertions += result["assertions"]
		var failures: PackedStringArray = result["failures"]
		for failure in failures:
			all_failures.append("%s :: %s" % [file, failure])
		print("  %s — %d assertions, %d failures" % [file, result["assertions"], failures.size()])

	print("--------------------------------")
	if all_failures.is_empty():
		print("PASSED: %d suites, %d assertions" % [suites, total_assertions])
		quit(0)
	else:
		for failure in all_failures:
			print("FAIL: %s" % failure)
		print("FAILED: %d failure(s) across %d suites" % [all_failures.size(), suites])
		quit(1)
