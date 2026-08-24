extends SceneTree
## Battle simulation entry point (charter §35). DEV-ONLY — tools/ is
## excluded from exports. All logic lives in battle_sim_impl.gd (loaded at
## runtime so autoload singletons are available to it).
##
## Run:
##   godot --headless --path . -s res://tools/battle_sim.gd -- --battles=200 --base-seed=1000


func _initialize() -> void:
	var impl: RefCounted = load("res://tools/battle_sim_impl.gd").new()
	impl.run()
	quit(0)
