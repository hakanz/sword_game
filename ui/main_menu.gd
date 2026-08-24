extends Control
## Main menu (MAIN_MENU state). Continue/Character appear once a save exists.
## A dedicated character-creation scene arrives in a later phase — until then
## "New Gladiator" starts with the default fighter.

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _continue: Button = %ContinueButton
@onready var _new_game: Button = %NewGameButton
@onready var _character: Button = %CharacterButton
@onready var _language: Button = %LanguageButton
@onready var _quit: Button = %QuitButton
@onready var _version: Label = %VersionLabel
@onready var _confirm_new: ConfirmationDialog = %ConfirmNewDialog


func _ready() -> void:
	_continue.pressed.connect(_on_continue_pressed)
	_new_game.pressed.connect(_on_new_game_pressed)
	_character.pressed.connect(_on_character_pressed)
	_language.pressed.connect(_on_language_pressed)
	_quit.pressed.connect(_on_quit_pressed)
	_confirm_new.confirmed.connect(_start_new_game)
	# Web builds have no meaningful quit (charter §3: browser matrix).
	_quit.visible = not OS.has_feature("web")
	_version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	_refresh()


func _refresh() -> void:
	var has_save: bool = SaveManager.has_profile()
	_continue.visible = has_save
	_character.visible = has_save
	_title.text = tr("app.title")
	_subtitle.text = tr("menu.subtitle")
	_continue.text = tr("menu.continue")
	_new_game.text = tr("menu.new_game")
	_character.text = tr("menu.character")
	_language.text = tr("menu.language")
	_quit.text = tr("menu.quit")
	_confirm_new.title = tr("menu.confirm_new_title")
	_confirm_new.dialog_text = tr("menu.confirm_new_text")
	_confirm_new.ok_button_text = tr("common.confirm")
	_confirm_new.cancel_button_text = tr("common.cancel")


func _on_continue_pressed() -> void:
	if not GameManager.continue_game():
		# Save unreadable — reflect reality in the UI instead of pretending.
		_refresh()


func _on_new_game_pressed() -> void:
	if SaveManager.has_profile():
		_confirm_new.popup_centered()
	else:
		_start_new_game()


func _start_new_game() -> void:
	GameManager.start_new_game()


func _on_character_pressed() -> void:
	if GameManager.profile == null:
		GameManager.profile = SaveManager.load_profile()
	if GameManager.profile != null:
		SceneRouter.goto_character_sheet()
	else:
		_refresh()


func _on_language_pressed() -> void:
	LocalizationManager.cycle_locale()
	_refresh()


func _on_quit_pressed() -> void:
	get_tree().quit()
