extends TestCase
## Every GDScript in the project must PARSE. A screen whose script fails to
## compile still instantiates as a bare node, so the scene-smoke suite can go
## green while a menu is completely dead (found exactly that way in session 7
## when a new class_name had not been registered yet). This suite closes that
## hole for the whole codebase, not just the scenes that happen to be listed.

const SCRIPT_DIRS: PackedStringArray = [
	"res://autoload", "res://combat", "res://characters", "res://data/models",
	"res://services", "res://ui", "res://scenes", "res://tools", "res://tests",
]


func test_every_script_compiles() -> void:
	var checked: int = 0
	for dir_path in SCRIPT_DIRS:
		checked += _check_dir(dir_path)
	assert_true(checked >= 40, "suspiciously few scripts scanned (%d)" % checked)


func _check_dir(dir_path: String) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	var checked: int = 0
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var path: String = dir_path.path_join(file)
		var script: Resource = load(path)
		assert_true(script != null and script is GDScript, "%s failed to compile" % path)
		checked += 1
	for sub in dir.get_directories():
		checked += _check_dir(dir_path.path_join(sub))
	return checked
