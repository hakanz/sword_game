extends Control
## Dustwell, the fighters' quarter (TOWN state, charter §22): the hub between
## fights. Location cards route to the arena, both merchants, the trainer and
## the player's own screens. Named NPCs get dialogue/quests in a later phase.

## [name_key, icon, route]
var _locations: Array[Array] = [
	["town.fight", preload("res://assets/icons/action_attack.svg"),
			func() -> void: GameManager.start_next_duel()],
	["town.regions", preload("res://assets/icons/action_approach.svg"),
			SceneRouter.goto_arena_select],
	["town.weaponsmith", preload("res://assets/icons/class_sword.svg"),
			SceneRouter.goto_weaponsmith],
	["town.armourer", preload("res://assets/icons/slot_chest.svg"),
			SceneRouter.goto_armourer],
	["town.trainer", preload("res://assets/icons/skill_focused_loose.svg"),
			SceneRouter.goto_skills],
	["town.character", preload("res://assets/icons/slot_helmet.svg"),
			SceneRouter.goto_character_sheet],
	["town.inventory", preload("res://assets/icons/slot_belt.svg"),
			SceneRouter.goto_inventory],
]

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _name_label: Label = %NameLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _gold_icon: TextureRect = %GoldIcon
@onready var _grid: GridContainer = %LocationGrid
@onready var _back: Button = %BackButton


func _ready() -> void:
	if GameManager.profile == null:
		SceneRouter.goto_main_menu()
		return
	var profile: PlayerProfile = GameManager.profile
	_title.text = tr("town.title")
	_subtitle.text = tr("town.subtitle")
	_name_label.text = "%s  ·  %s" % [profile.character_name,
			tr("sheet.level").format({"level": profile.level})]
	# Always-visible XP progress under the name (session-5 owner design).
	var xp_needed: int = ProgressionCalculator.xp_required(
			GameManager.PROGRESSION_CONFIG, profile.level)
	var xp_bar := ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 8)
	xp_bar.show_percentage = false
	xp_bar.max_value = xp_needed
	xp_bar.value = profile.xp
	xp_bar.tooltip_text = "%s %d / %d" % [tr("sheet.xp"), profile.xp, xp_needed]
	xp_bar.add_theme_stylebox_override("fill", UITheme.bar_fill(Color(0.93, 0.76, 0.35)))
	var status_box: VBoxContainer = _name_label.get_parent()
	status_box.add_child(xp_bar)
	status_box.move_child(xp_bar, _name_label.get_index() + 1)
	_gold_icon.texture = preload("res://assets/icons/coin.svg")
	_gold_label.text = str(profile.gold)
	_back.text = tr("town.leave")
	_back.pressed.connect(SceneRouter.goto_main_menu)

	for location in _locations:
		var button := Button.new()
		button.text = tr(location[0])
		button.icon = location[1]
		button.custom_minimum_size = Vector2(260, 74)
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_constant_override("icon_max_width", 34)
		button.expand_icon = true
		button.pressed.connect(location[2])
		# The arena's call (session-5): when the tournament is due, the duel
		# card becomes the tournament summons — golden and pulsing.
		if location[0] == "town.fight" and GameManager.tournament_required():
			button.text = tr("town.tournament_call")
			button.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3))
			var pulse: Tween = create_tween()
			pulse.set_loops()
			pulse.tween_property(button, "modulate", Color(1.15, 1.08, 0.9), 0.55)
			pulse.tween_property(button, "modulate", Color.WHITE, 0.55)
		_grid.add_child(button)
