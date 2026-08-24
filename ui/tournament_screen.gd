extends Control
## Tournament bracket view (TOURNAMENT state, charter §21): four rounds
## ending with the arena champion. Progress state lives on GameManager;
## leaving forfeits the run (confirmed).

const ROUND_KEYS: PackedStringArray = [
	"tournament.round.qualification",
	"tournament.round.quarter",
	"tournament.round.semi",
	"tournament.round.final",
]

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _rounds_box: VBoxContainer = %RoundsBox
@onready var _fight: Button = %FightButton
@onready var _abandon: Button = %AbandonButton
@onready var _abandon_dialog: ConfirmationDialog = %AbandonDialog


func _ready() -> void:
	if GameManager.profile == null or not GameManager.in_tournament():
		SceneRouter.goto_main_menu()
		return
	var arena: ArenaData = ItemDB.arena(GameManager.tournament_arena_id)
	_title.text = tr("tournament.title").format({"arena": tr(arena.name_key)})
	_subtitle.text = tr("tournament.subtitle").format({
		"champion": tr(arena.champion.name_text),
	})
	_fight.text = tr("tournament.fight")
	_abandon.text = tr("tournament.abandon")
	_abandon_dialog.title = tr("tournament.abandon")
	_abandon_dialog.dialog_text = tr("tournament.abandon_confirm")
	_abandon_dialog.ok_button_text = tr("common.confirm")
	_abandon_dialog.cancel_button_text = tr("common.cancel")
	_fight.pressed.connect(GameManager.start_tournament_round)
	_abandon.pressed.connect(_abandon_dialog.popup_centered)
	_abandon_dialog.confirmed.connect(_on_abandon_confirmed)
	_build_rounds()


func _build_rounds() -> void:
	var current: int = GameManager.tournament_round
	for index in ROUND_KEYS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_rounds_box.add_child(row)

		var marker := Label.new()
		marker.custom_minimum_size = Vector2(34, 0)
		marker.add_theme_font_size_override("font_size", 20)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.text = tr(ROUND_KEYS[index])
		if index < current:
			marker.text = "+"
			marker.add_theme_color_override("font_color", Color(0.6, 0.85, 0.55))
			name_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.55))
		elif index == current:
			marker.text = ">"
			marker.add_theme_color_override("font_color", Color(0.93, 0.76, 0.35))
			name_label.add_theme_color_override("font_color", Color(0.93, 0.76, 0.35))
		else:
			marker.text = "-"
			marker.add_theme_color_override("font_color", Color(0.5, 0.47, 0.55))
			name_label.add_theme_color_override("font_color", Color(0.5, 0.47, 0.55))
		row.add_child(marker)
		row.add_child(name_label)


func _on_abandon_confirmed() -> void:
	GameManager.abandon_tournament()
	SceneRouter.goto_main_menu()
