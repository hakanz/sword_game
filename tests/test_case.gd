class_name TestCase
extends RefCounted
## Minimal unit-test base class. Test scripts extend this and define
## `test_*()` methods using the assert helpers. No third-party framework:
## charter §37 requires export-compat vetting for any dependency, and this
## tiny runner removes the need entirely.

var assertions: int = 0
var failures: PackedStringArray = []

var _current_method: String = ""


## Runs every `test_*` method, returns {"assertions": int, "failures": PackedStringArray}.
func run_all() -> Dictionary:
	var methods: Array[String] = []
	for entry: Dictionary in get_method_list():
		var method_name: String = entry["name"]
		if method_name.begins_with("test_"):
			methods.append(method_name)
	methods.sort()
	for method in methods:
		_current_method = method
		call(method)
	return {"assertions": assertions, "failures": failures}


func fail(message: String) -> void:
	failures.append("%s: %s" % [_current_method, message])


func assert_true(condition: bool, message: String = "") -> void:
	assertions += 1
	if not condition:
		fail("expected true — %s" % message)


func assert_false(condition: bool, message: String = "") -> void:
	assertions += 1
	if condition:
		fail("expected false — %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	assertions += 1
	if actual != expected:
		fail("expected %s, got %s — %s" % [expected, actual, message])


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.0001, message: String = "") -> void:
	assertions += 1
	if absf(actual - expected) > tolerance:
		fail("expected %s ± %s, got %s — %s" % [expected, tolerance, actual, message])
