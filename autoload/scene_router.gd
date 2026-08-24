extends Node
## Central scene navigation (charter §6). All scene changes go through here
## so transitions/loading behavior can be added in one place later.

const SCENE_MAIN_MENU: String = "res://scenes/menu/main_menu.tscn"
const SCENE_ARENA: String = "res://scenes/arena/arena.tscn"
const SCENE_RESULTS: String = "res://scenes/results/results.tscn"


func goto_main_menu() -> void:
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	_change_scene(SCENE_MAIN_MENU)


func goto_arena() -> void:
	GameManager.change_state(GameManager.GameState.COMBAT)
	_change_scene(SCENE_ARENA)


func goto_results() -> void:
	GameManager.change_state(GameManager.GameState.POST_BATTLE)
	_change_scene(SCENE_RESULTS)


func _change_scene(path: String) -> void:
	# Deferred so a scene change is safe from within signal callbacks.
	get_tree().change_scene_to_file.call_deferred(path)
