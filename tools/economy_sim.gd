extends SceneTree
## Economy pacing report entry point (charter §22 / §35 sibling). DEV-ONLY —
## tools/ is excluded from exports. The work lives in economy_sim_impl.gd,
## loaded at RUNTIME: a `-s` main script compiles before the autoload globals
## register, so it could not reference ItemDB directly (docs/build.md).
##
## Run:
##   godot --headless --path . -s res://tools/economy_sim.gd
##   godot --headless --path . -s res://tools/economy_sim.gd -- --charisma=20


func _initialize() -> void:
	var impl: RefCounted = load("res://tools/economy_sim_impl.gd").new()
	impl.run()
	quit(0)
