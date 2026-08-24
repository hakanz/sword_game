extends Node
## Central random number service (charter §34).
## ALL gameplay randomness must go through this service so combat is
## reproducible with a fixed seed. Never call randi()/randf() directly
## elsewhere in gameplay code.
##
## Seeding:
##  - `--combat-seed=12345` passed as a user command-line arg (after `--`).
##  - `set_seed()` from the debug menu or tests.

var current_seed: int = 0
var seeded_manually: bool = false

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	args.append_array(OS.get_cmdline_args())
	for arg in args:
		if arg.begins_with("--combat-seed="):
			var value: String = arg.get_slice("=", 1)
			if value.is_valid_int():
				set_seed(int(value))
			break
	if not seeded_manually:
		_rng.randomize()
		current_seed = int(_rng.seed)


func set_seed(new_seed: int) -> void:
	current_seed = new_seed
	_rng.seed = new_seed
	seeded_manually = true


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


## `probability` is in [0.0, 1.0]. Returns true with that probability.
func chance(probability: float) -> bool:
	return _rng.randf() < probability


## Returns a random element of a non-empty array.
func pick(options: Array) -> Variant:
	assert(not options.is_empty(), "RngService.pick() called with empty array")
	return options[_rng.randi_range(0, options.size() - 1)]
