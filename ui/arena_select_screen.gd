extends Control
## Arena region selection (ARENA_SELECT state, charter §21): pick where to
## fight normal duels, see level gates + champion status, and enter each
## region's tournament. Unlock rules live on GameManager, never here.

@onready var _title: Label = %TitleLabel
@onready var _list: VBoxContainer = %ArenaList
@onready var _back: Button = %BackButton


func _ready() -> void:
	if GameManager.profile == null:
		SceneRouter.goto_main_menu()
		return
	_title.text = tr("arenas.title")
	_back.text = tr("common.back")
	_back.pressed.connect(SceneRouter.goto_town)
	_refresh()


func _refresh() -> void:
	var profile: PlayerProfile = GameManager.profile
	for child in _list.get_children():
		child.queue_free()
	for arena in ItemDB.all_arenas():
		_add_row(profile, arena)


func _add_row(profile: PlayerProfile, arena: ArenaData) -> void:
	var panel := PanelContainer.new()
	_list.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var unlocked: bool = GameManager.is_arena_unlocked(arena)
	var selected: bool = profile.selected_arena_id == arena.id
	var completed: bool = profile.completed_tournament_arena_ids.has(arena.id)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = tr(arena.name_key)
	name_label.add_theme_font_size_override("font_size", 22)
	if not unlocked:
		name_label.add_theme_color_override("font_color", Color(0.55, 0.5, 0.6))
	info.add_child(name_label)

	var range_label := Label.new()
	range_label.text = tr("arenas.level_range").format({
		"min": arena.min_level, "max": arena.max_level,
	})
	range_label.add_theme_font_size_override("font_size", 14)
	range_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.8))
	info.add_child(range_label)

	var status_label := Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	if not unlocked:
		status_label.text = tr("arenas.locked_hint")
		status_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.4))
	elif completed:
		status_label.text = tr("arenas.champion_beaten").format({
			"champion": tr(arena.champion.name_text),
		})
		status_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.55))
	else:
		status_label.text = tr("arenas.champion_waits").format({
			"champion": tr(arena.champion.name_text),
		})
		status_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5))
	info.add_child(status_label)

	if selected:
		var tag := Label.new()
		tag.text = tr("arenas.selected")
		tag.add_theme_font_size_override("font_size", 16)
		tag.add_theme_color_override("font_color", Color(0.6, 0.85, 0.55))
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
	elif unlocked:
		var select := Button.new()
		select.text = tr("arenas.select")
		select.custom_minimum_size = Vector2(130, 50)
		select.pressed.connect(_on_select.bind(arena))
		row.add_child(select)

	if GameManager.is_tournament_unlocked(arena):
		var tournament := Button.new()
		tournament.text = tr("arenas.tournament")
		tournament.custom_minimum_size = Vector2(150, 50)
		tournament.pressed.connect(func() -> void: GameManager.start_tournament(arena))
		row.add_child(tournament)


func _on_select(arena: ArenaData) -> void:
	GameManager.profile.selected_arena_id = arena.id
	SaveManager.save_profile(GameManager.profile)
	_refresh()
