extends Control
## Character creation (CHARACTER_CREATION state): name, FREE point-buy over
## all eight attributes (session-5 owner design — the player sets every
## value), origin presets as quick-fill templates, placeholder-rig colors,
## live preview with derived-stat readout. No permanent hard classes
## (charter §17) — build identity comes from the numbers the player picks.

## Origin presets: [key, STR, AGI, ATT, DEF, VIT, STA, ARC, CHA] — templates
## that FILL the editable allocation, never lock it. All spend TOTAL_POINTS.
const PRESETS: Array[Array] = [
	["balanced", 8, 8, 8, 8, 10, 8, 2, 4],
	["brawler", 11, 7, 9, 7, 10, 8, 2, 2],
	["swift", 7, 10, 9, 6, 9, 9, 3, 3],
]

## Point-buy rules: same budget the presets spend; floors keep a fighter
## viable, the ceiling keeps level-1 builds honest.
const TOTAL_POINTS: int = 56
const ATTR_MIN: int = 1
const ATTR_MAX: int = 15

## [property on AttributeBlock, localization key]
const ATTRS: Array[Array] = [
	["strength", "attr.strength"], ["agility", "attr.agility"],
	["attack", "attr.attack"], ["defence", "attr.defence"],
	["vitality", "attr.vitality"], ["stamina", "attr.stamina"],
	["arcana", "attr.arcana"], ["charisma", "attr.charisma"],
]

const BODY_TONES: Array[Color] = [
	Color(0.93, 0.76, 0.6), Color(0.85, 0.64, 0.47), Color(0.72, 0.52, 0.36),
	Color(0.55, 0.38, 0.26), Color(0.4, 0.28, 0.2),
]
const ACCENT_COLORS: Array[Color] = [
	Color(0.22, 0.36, 0.6), Color(0.55, 0.2, 0.2), Color(0.2, 0.45, 0.28),
	Color(0.5, 0.32, 0.6), Color(0.65, 0.45, 0.15), Color(0.25, 0.25, 0.3),
]

var _preset_index: int = 0
var _body_index: int = 1
var _accent_index: int = 0
var _values: Dictionary = {}
var _preview: PlaceholderRig = null
## attr name -> {value_label, minus, plus} for cheap refreshes.
var _rows: Dictionary = {}

@onready var _title: Label = %TitleLabel
@onready var _name_label: Label = %NameLabel
@onready var _name_edit: LineEdit = %NameEdit
@onready var _preset_box: HBoxContainer = %PresetBox
@onready var _preset_desc: Label = %PresetDesc
@onready var _body_label: Label = %BodyLabel
@onready var _body_box: HBoxContainer = %BodyBox
@onready var _accent_label: Label = %AccentLabel
@onready var _accent_box: HBoxContainer = %AccentBox
@onready var _points_label: Label = %PointsLabel
@onready var _attr_box: VBoxContainer = %AttrBox
@onready var _preview_anchor: Control = %PreviewAnchor
@onready var _stats_label: Label = %StatsLabel
@onready var _start: Button = %StartButton
@onready var _back: Button = %BackButton


func _ready() -> void:
	_title.text = tr("creation.title")
	_name_label.text = tr("creation.name_label")
	_name_edit.text = tr("character.default_name")
	_body_label.text = tr("creation.body_label")
	_accent_label.text = tr("creation.accent_label")
	_start.text = tr("creation.start")
	_back.text = tr("common.back")
	_start.pressed.connect(_on_start_pressed)
	_back.pressed.connect(SceneRouter.goto_main_menu)

	for index in PRESETS.size():
		var button := Button.new()
		button.text = tr("creation.preset.%s" % PRESETS[index][0])
		button.custom_minimum_size = Vector2(140, 42)
		button.toggle_mode = true
		button.pressed.connect(_on_preset_pressed.bind(index))
		_preset_box.add_child(button)
	_build_swatches(_body_box, BODY_TONES, _on_body_pressed)
	_build_swatches(_accent_box, ACCENT_COLORS, _on_accent_pressed)
	_build_attr_rows()
	_apply_preset(0)

	_preview = PlaceholderRig.new()
	_preview_anchor.add_child(_preview)
	# Rig carries face/muscle/equipment detail — show it big in the booth.
	_preview.scale = Vector2(2.2, 2.2)
	_refresh()
	_preview_anchor.resized.connect(_position_preview)
	_position_preview.call_deferred()


func _build_swatches(box: HBoxContainer, colors: Array[Color], handler: Callable) -> void:
	for index in colors.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(38, 38)
		var style := StyleBoxFlat.new()
		style.bg_color = colors[index]
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.pressed.connect(handler.bind(index))
		box.add_child(button)


## One compact -/+ row per attribute; every value is the player's to set.
func _build_attr_rows() -> void:
	for attr in ATTRS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_attr_box.add_child(row)

		var name_label := Label.new()
		name_label.text = tr(attr[1])
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(34, 30)
		minus.add_theme_font_size_override("font_size", 20)
		minus.pressed.connect(_on_attr_changed.bind(attr[0] as String, -1))
		row.add_child(minus)

		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(34, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 18)
		value_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
		row.add_child(value_label)

		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(34, 30)
		plus.add_theme_font_size_override("font_size", 20)
		plus.pressed.connect(_on_attr_changed.bind(attr[0] as String, 1))
		row.add_child(plus)

		_rows[attr[0]] = {"value": value_label, "minus": minus, "plus": plus}


func _apply_preset(index: int) -> void:
	_preset_index = index
	var preset: Array = PRESETS[index]
	for i in ATTRS.size():
		_values[ATTRS[i][0]] = int(preset[i + 1])


func _spent_points() -> int:
	var total: int = 0
	for attr in ATTRS:
		total += int(_values[attr[0]])
	return total


func _points_left() -> int:
	return TOTAL_POINTS - _spent_points()


func _on_attr_changed(attr_name: String, delta: int) -> void:
	var current: int = int(_values[attr_name])
	if delta > 0 and (_points_left() <= 0 or current >= ATTR_MAX):
		return
	if delta < 0 and current <= ATTR_MIN:
		return
	_values[attr_name] = current + delta
	AudioManager.play(&"click")
	_refresh()


func _on_preset_pressed(index: int) -> void:
	_apply_preset(index)
	_refresh()


func _on_body_pressed(index: int) -> void:
	_body_index = index
	_refresh()


func _on_accent_pressed(index: int) -> void:
	_accent_index = index
	_refresh()


func _refresh() -> void:
	for index in _preset_box.get_child_count():
		(_preset_box.get_child(index) as Button).button_pressed = index == _preset_index
	_preset_desc.text = tr("creation.preset.%s.desc" % PRESETS[_preset_index][0])

	var left: int = _points_left()
	_points_label.text = tr("creation.points_left").format({"points": left})
	_points_label.tooltip_text = tr("creation.points_hint")
	for attr in ATTRS:
		var row: Dictionary = _rows[attr[0]]
		var value: int = int(_values[attr[0]])
		(row["value"] as Label).text = str(value)
		(row["minus"] as Button).disabled = value <= ATTR_MIN
		(row["plus"] as Button).disabled = left <= 0 or value >= ATTR_MAX

	_refresh_stats_preview()
	if _preview != null:
		_preview.body_color = BODY_TONES[_body_index]
		_preview.accent_color = ACCENT_COLORS[_accent_index]
		_preview.queue_redraw()


## Live derived-stat readout — the same calculator the game itself uses
## (charter §6: nothing recomputes stats ad hoc).
func _refresh_stats_preview() -> void:
	var attrs: AttributeBlock = _selected_attributes()
	_stats_label.text = "%s %d  ·  %s %d  ·  %s %d\n%s %d  ·  %s %d  ·  %s %d" % [
		tr("combat.hud.hp"), ProgressionCalculator.max_hp(attrs, 1),
		tr("combat.hud.energy"), ProgressionCalculator.max_energy(attrs, 1),
		tr("stat.max_mana"), ProgressionCalculator.max_mana(attrs, 1),
		tr("stat.attack_rating"), ProgressionCalculator.attack_rating(attrs),
		tr("stat.defence_rating"), ProgressionCalculator.defence_rating(attrs),
		tr("stat.initiative"), ProgressionCalculator.initiative(attrs),
	]


func _position_preview() -> void:
	var anchor_size: Vector2 = _preview_anchor.size
	_preview.position = Vector2(anchor_size.x / 2.0, anchor_size.y * 0.92)


func _selected_attributes() -> AttributeBlock:
	var attrs := AttributeBlock.new()
	for attr in ATTRS:
		attrs.set(attr[0], int(_values[attr[0]]))
	return attrs


func _on_start_pressed() -> void:
	# Unspent creation points are never lost — they walk into the game as
	# attribute points (spend them on the character sheet).
	GameManager.start_new_game_custom(
			_name_edit.text, _selected_attributes(),
			BODY_TONES[_body_index], ACCENT_COLORS[_accent_index],
			_points_left())
