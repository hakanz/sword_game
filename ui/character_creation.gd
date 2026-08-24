extends Control
## Character creation (CHARACTER_CREATION state): name, origin preset,
## placeholder-rig colors, live preview. Presets are starting TEMPLATES
## (equal total points) — build identity comes from play, not a class pick
## (charter §17: no permanent hard classes).

## Origin presets: [key, STR, AGI, ATT, DEF, VIT, STA, ARC, CHA] — all 56 pts.
const PRESETS: Array[Array] = [
	["balanced", 8, 8, 8, 8, 10, 8, 2, 4],
	["brawler", 11, 6, 8, 7, 11, 8, 2, 3],
	["swift", 7, 10, 9, 6, 9, 9, 3, 3],
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
var _preview: PlaceholderRig = null

@onready var _title: Label = %TitleLabel
@onready var _name_label: Label = %NameLabel
@onready var _name_edit: LineEdit = %NameEdit
@onready var _preset_box: HBoxContainer = %PresetBox
@onready var _preset_desc: Label = %PresetDesc
@onready var _body_label: Label = %BodyLabel
@onready var _body_box: HBoxContainer = %BodyBox
@onready var _accent_label: Label = %AccentLabel
@onready var _accent_box: HBoxContainer = %AccentBox
@onready var _preview_anchor: Control = %PreviewAnchor
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
		button.custom_minimum_size = Vector2(150, 52)
		button.toggle_mode = true
		button.pressed.connect(_on_preset_pressed.bind(index))
		_preset_box.add_child(button)
	_build_swatches(_body_box, BODY_TONES, _on_body_pressed)
	_build_swatches(_accent_box, ACCENT_COLORS, _on_accent_pressed)

	_preview = PlaceholderRig.new()
	_preview_anchor.add_child(_preview)
	_preview.scale = Vector2(0.9, 0.9)
	_refresh()
	_preview_anchor.resized.connect(_position_preview)
	_position_preview.call_deferred()


func _build_swatches(box: HBoxContainer, colors: Array[Color], handler: Callable) -> void:
	for index in colors.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(44, 44)
		var style := StyleBoxFlat.new()
		style.bg_color = colors[index]
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.pressed.connect(handler.bind(index))
		box.add_child(button)


func _on_preset_pressed(index: int) -> void:
	_preset_index = index
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
	_preview.body_color = BODY_TONES[_body_index]
	_preview.accent_color = ACCENT_COLORS[_accent_index]
	_preview.queue_redraw()


func _position_preview() -> void:
	var anchor_size: Vector2 = _preview_anchor.size
	_preview.position = Vector2(anchor_size.x / 2.0, anchor_size.y - 8.0)


func _selected_attributes() -> AttributeBlock:
	var preset: Array = PRESETS[_preset_index]
	var attrs := AttributeBlock.new()
	attrs.strength = preset[1]
	attrs.agility = preset[2]
	attrs.attack = preset[3]
	attrs.defence = preset[4]
	attrs.vitality = preset[5]
	attrs.stamina = preset[6]
	attrs.arcana = preset[7]
	attrs.charisma = preset[8]
	return attrs


func _on_start_pressed() -> void:
	GameManager.start_new_game_custom(
			_name_edit.text, _selected_attributes(),
			BODY_TONES[_body_index], ACCENT_COLORS[_accent_index])
