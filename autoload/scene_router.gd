extends Node
## Central scene navigation (charter §6). All scene changes go through here
## so transitions/loading behavior can be added in one place later.

const SCENE_MAIN_MENU: String = "res://scenes/menu/main_menu.tscn"
const SCENE_ARENA: String = "res://scenes/arena/arena.tscn"
const SCENE_RESULTS: String = "res://scenes/results/results.tscn"
const SCENE_CHARACTER_SHEET: String = "res://scenes/character/character_sheet.tscn"
const SCENE_SHOP: String = "res://scenes/shops/shop.tscn"
const SCENE_INVENTORY: String = "res://scenes/inventory/inventory.tscn"
const SCENE_SKILLS: String = "res://scenes/skills/skills.tscn"
const SCENE_CHARACTER_CREATION: String = "res://scenes/creation/character_creation.tscn"
const SCENE_ARENA_SELECT: String = "res://scenes/arena_select/arena_select.tscn"
const SCENE_TOURNAMENT: String = "res://scenes/tournament/tournament.tscn"
const SCENE_SETTINGS: String = "res://scenes/settings/settings.tscn"
const SCENE_TOWN: String = "res://scenes/town/town.tscn"


func goto_main_menu() -> void:
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	_change_scene(SCENE_MAIN_MENU)


func goto_arena() -> void:
	GameManager.change_state(GameManager.GameState.COMBAT)
	_change_scene(SCENE_ARENA)


func goto_results() -> void:
	GameManager.change_state(GameManager.GameState.POST_BATTLE)
	_change_scene(SCENE_RESULTS)


func goto_character_sheet() -> void:
	GameManager.change_state(GameManager.GameState.CHARACTER_SHEET)
	_change_scene(SCENE_CHARACTER_SHEET)


func goto_town() -> void:
	GameManager.change_state(GameManager.GameState.TOWN)
	_change_scene(SCENE_TOWN)


func goto_weaponsmith() -> void:
	GameManager.shop_kind = GameManager.ShopKind.WEAPONS
	GameManager.change_state(GameManager.GameState.SHOP)
	_change_scene(SCENE_SHOP)


func goto_armourer() -> void:
	GameManager.shop_kind = GameManager.ShopKind.ARMOUR
	GameManager.change_state(GameManager.GameState.SHOP)
	_change_scene(SCENE_SHOP)


func goto_inventory() -> void:
	GameManager.change_state(GameManager.GameState.INVENTORY)
	_change_scene(SCENE_INVENTORY)


func goto_skills() -> void:
	GameManager.change_state(GameManager.GameState.SKILLS)
	_change_scene(SCENE_SKILLS)


func goto_character_creation() -> void:
	GameManager.change_state(GameManager.GameState.CHARACTER_CREATION)
	_change_scene(SCENE_CHARACTER_CREATION)


func goto_arena_select() -> void:
	GameManager.change_state(GameManager.GameState.ARENA_SELECT)
	_change_scene(SCENE_ARENA_SELECT)


func goto_tournament() -> void:
	GameManager.change_state(GameManager.GameState.TOURNAMENT)
	_change_scene(SCENE_TOURNAMENT)


func goto_settings() -> void:
	GameManager.change_state(GameManager.GameState.SETTINGS)
	_change_scene(SCENE_SETTINGS)


func _change_scene(path: String) -> void:
	# Defensive: leaving any screen must never strand a paused tree.
	get_tree().paused = false
	# Deferred so a scene change is safe from within signal callbacks.
	get_tree().change_scene_to_file.call_deferred(path)
