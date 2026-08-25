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

## The between-fights encounter panel, built in code and shown over the hub
## when one is waiting (charter §23).
var _event_panel: PanelContainer = null


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

	# Something happened on the way home (charter §23).
	var event: EventData = GameManager.take_pending_event()
	if event != null:
		_show_event(event, profile)


# --- Between-fights encounters (charter §23) --------------------------------

## Presents one encounter as a modal card: the scene, then the choices the
## purse can actually afford, then what came of it.
func _show_event(event: EventData, profile: PlayerProfile) -> void:
	_event_panel = PanelContainer.new()
	_event_panel.set_anchors_preset(Control.PRESET_CENTER)
	_event_panel.custom_minimum_size = Vector2(620, 0)
	add_child(_event_panel)
	_event_panel.position = (size - _event_panel.custom_minimum_size) * 0.5
	_event_panel.position.y = size.y * 0.18

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	_event_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var heading := Label.new()
	heading.text = tr("town.event_title")
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", Color(0.72, 0.68, 0.78))
	box.add_child(heading)

	var title := Label.new()
	title.text = tr(event.title_key)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	box.add_child(title)

	var body := Label.new()
	body.text = tr(event.body_key)
	body.add_theme_font_size_override("font_size", 17)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(580, 0)
	box.add_child(body)

	for choice: EventChoiceData in event.available_choices(profile.gold):
		var button := Button.new()
		button.text = tr(choice.label_key)
		button.custom_minimum_size = Vector2(0, 52)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_on_event_choice.bind(choice, profile, box))
		box.add_child(button)


## Applies the chosen outcome, then replaces the options with what happened.
func _on_event_choice(
		choice: EventChoiceData, profile: PlayerProfile, box: VBoxContainer) -> void:
	var outcome: EventService.Outcome = EventService.apply(profile, choice)
	SaveManager.save_profile(profile)  # autosave after a state change (charter §31)
	for child in box.get_children():
		if child is Button:
			child.queue_free()

	var result := Label.new()
	result.text = tr(outcome.text_key)
	result.add_theme_font_size_override("font_size", 17)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size = Vector2(580, 0)
	result.add_theme_color_override("font_color",
			Color(0.92, 0.55, 0.5) if outcome.wagered and not outcome.wager_won
			else Color(0.62, 0.87, 0.58))
	box.add_child(result)

	var ledger: String = _outcome_ledger(outcome)
	if ledger != "":
		var summary := Label.new()
		summary.text = ledger
		summary.add_theme_font_size_override("font_size", 16)
		summary.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
		box.add_child(summary)

	var close := Button.new()
	close.text = tr("event.continue")
	close.custom_minimum_size = Vector2(0, 52)
	close.pressed.connect(func() -> void:
		_event_panel.queue_free()
		_gold_label.text = str(profile.gold))
	box.add_child(close)
	_gold_label.text = str(profile.gold)


## "+35 gold · +6 fame" — the numbers behind the sentence.
func _outcome_ledger(outcome: EventService.Outcome) -> String:
	var parts: PackedStringArray = []
	if outcome.gold_delta != 0:
		parts.append("%+d %s" % [outcome.gold_delta, tr("common.gold_short")])
	if outcome.fame_delta != 0:
		parts.append("%+d %s" % [outcome.fame_delta, tr("common.fame_short")])
	if outcome.xp_gain != 0:
		parts.append("+%d %s" % [outcome.xp_gain, tr("sheet.xp")])
	if outcome.attribute_points != 0:
		parts.append("+%d %s" % [outcome.attribute_points, tr("common.attribute_point_short")])
	if outcome.item_id != &"":
		parts.append(tr("event.item_received"))
	return "  ·  ".join(parts)
