extends Control
## Main menu (MAIN_MENU state). Character creation gets its own scene in the
## progression phase — until then "Enter the Arena" starts a duel with the
## default gladiator so the core loop is playable end to end.

const PLAYER_PRESET: CharacterData = preload("res://data/characters/player_default.tres")
const ENEMY_PRESET: CharacterData = preload("res://data/characters/enemy_vosk.tres")

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _play: Button = %PlayButton
@onready var _language: Button = %LanguageButton
@onready var _quit: Button = %QuitButton
@onready var _version: Label = %VersionLabel


func _ready() -> void:
	_play.pressed.connect(_on_play_pressed)
	_language.pressed.connect(_on_language_pressed)
	_quit.pressed.connect(_on_quit_pressed)
	# Web builds have no meaningful quit (charter §3: browser matrix).
	_quit.visible = not OS.has_feature("web")
	_version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	_refresh_texts()


func _refresh_texts() -> void:
	_title.text = tr("app.title")
	_subtitle.text = tr("menu.subtitle")
	_play.text = tr("menu.play")
	_language.text = tr("menu.language")
	_quit.text = tr("menu.quit")


func _on_play_pressed() -> void:
	# duplicate(true): runtime never mutates the preset resources.
	GameManager.player_character = PLAYER_PRESET.duplicate(true)
	GameManager.next_opponent = ENEMY_PRESET.duplicate(true)
	GameManager.last_combat_result = null
	SceneRouter.goto_arena()


func _on_language_pressed() -> void:
	LocalizationManager.cycle_locale()
	_refresh_texts()


func _on_quit_pressed() -> void:
	get_tree().quit()
