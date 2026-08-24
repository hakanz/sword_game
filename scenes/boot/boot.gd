extends Control
## BOOT state: autoloads have self-initialized (settings, locale, audio) by
## the time this scene runs; it only routes onward. In smoke-test mode
## (`--smoke-test` user arg) it wires a full AI-vs-AI duel and lets the
## results screen quit with an exit code — used by CI and headless checks.

const PLAYER_PRESET: CharacterData = preload("res://data/characters/player_default.tres")
const ENEMY_PRESET: CharacterData = preload("res://data/characters/enemy_vosk.tres")

@onready var _loading: Label = %LoadingLabel


func _ready() -> void:
	_loading.text = tr("boot.loading")
	# One frame so the loading frame paints before any scene-change hitch.
	await get_tree().process_frame
	if GameManager.smoke_test:
		GameManager.player_character = PLAYER_PRESET.duplicate(true)
		GameManager.next_opponent = ENEMY_PRESET.duplicate(true)
		SceneRouter.goto_arena()
	else:
		SceneRouter.goto_main_menu()
