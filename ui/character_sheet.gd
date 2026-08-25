extends Control
## Character sheet (CHARACTER_SHEET state): allocate attribute points with a
## pending-then-confirm model, previewing derived stats live. All derived
## numbers come from ProgressionCalculator — this screen computes nothing
## itself (charter §13.1).

const ATTRIBUTES: PackedStringArray = [
	"strength", "agility", "attack", "defence",
	"vitality", "stamina", "arcana", "charisma",
]

var _profile: PlayerProfile = null
var _pending: Dictionary = {}

var _value_labels: Dictionary = {}
var _plus_buttons: Dictionary = {}
var _minus_buttons: Dictionary = {}

@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel
@onready var _xp_label: Label = %XPLabel
@onready var _xp_bar: ProgressBar = %XPBar
@onready var _points_label: Label = %PointsLabel
@onready var _skill_points_label: Label = %SkillPointsLabel
@onready var _attr_grid: GridContainer = %AttrGrid
@onready var _stats_title: Label = %StatsTitle
@onready var _stats_box: VBoxContainer = %StatsBox
@onready var _confirm: Button = %ConfirmButton
@onready var _back: Button = %BackButton


func _ready() -> void:
	_profile = GameManager.profile
	if _profile == null:
		SceneRouter.goto_main_menu()
		return
	_back.text = tr("common.back")
	_confirm.text = tr("common.confirm")
	_stats_title.text = tr("sheet.stats_title")
	_back.pressed.connect(_on_back_pressed)
	_confirm.pressed.connect(_on_confirm_pressed)
	_build_attribute_rows()
	_refresh()


func _build_attribute_rows() -> void:
	for attr in ATTRIBUTES:
		var name_label := Label.new()
		name_label.text = tr("attr.%s" % attr)
		name_label.add_theme_font_size_override("font_size", 19)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_attr_grid.add_child(name_label)

		var value_label := Label.new()
		value_label.add_theme_font_size_override("font_size", 19)
		value_label.custom_minimum_size = Vector2(64, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_attr_grid.add_child(value_label)
		_value_labels[attr] = value_label

		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(48, 44)
		minus.pressed.connect(_on_adjust.bind(attr, -1))
		_attr_grid.add_child(minus)
		_minus_buttons[attr] = minus

		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(48, 44)
		plus.pressed.connect(_on_adjust.bind(attr, 1))
		_attr_grid.add_child(plus)
		_plus_buttons[attr] = plus


func _on_adjust(attr: String, delta: int) -> void:
	var next: int = int(_pending.get(attr, 0)) + delta
	if next < 0 or _points_remaining() - delta < 0:
		return
	_pending[attr] = next
	_refresh()


func _points_remaining() -> int:
	var spent: int = 0
	for value in _pending.values():
		spent += value
	return _profile.attribute_points - spent


func _preview_attributes() -> AttributeBlock:
	var preview: AttributeBlock = _profile.attributes.duplicate_block()
	for attr in _pending.keys():
		preview.set(attr, int(preview.get(attr)) + int(_pending[attr]))
	return preview


func _refresh() -> void:
	_name_label.text = _profile.character_name
	_level_label.text = tr("sheet.level").format({"level": _profile.level})

	var config: ProgressionConfig = GameManager.PROGRESSION_CONFIG
	var needed: int = ProgressionCalculator.xp_required(config, _profile.level)
	_xp_label.text = "%s %d/%d" % [tr("sheet.xp"), _profile.xp, needed]
	_xp_bar.max_value = needed
	_xp_bar.value = _profile.xp

	var remaining: int = _points_remaining()
	_points_label.text = tr("sheet.attribute_points").format({"points": remaining})
	_skill_points_label.text = tr("sheet.skill_points").format({"points": _profile.skill_points})

	var preview: AttributeBlock = _preview_attributes()
	for attr in ATTRIBUTES:
		var base: int = int(_profile.attributes.get(attr))
		var pending: int = int(_pending.get(attr, 0))
		var label: Label = _value_labels[attr]
		label.text = str(base + pending) if pending == 0 else "%d (+%d)" % [base + pending, pending]
		(_minus_buttons[attr] as Button).disabled = pending <= 0
		(_plus_buttons[attr] as Button).disabled = remaining <= 0

	_refresh_stats(preview)
	_confirm.disabled = _pending.values().all(func(v: int) -> bool: return v == 0)


func _refresh_stats(attrs: AttributeBlock) -> void:
	for child in _stats_box.get_children():
		child.queue_free()
	var weapon: WeaponData = ItemDB.weapon(_profile.weapon_id)
	var rows: Array[Array] = [
		["stat.max_hp", ProgressionCalculator.max_hp(attrs, _profile.level)],
		["stat.max_energy", ProgressionCalculator.max_energy(attrs, _profile.level)],
		["stat.max_mana", ProgressionCalculator.max_mana(attrs, _profile.level)],
		["stat.attack_rating", ProgressionCalculator.attack_rating(attrs)],
		["stat.defence_rating", ProgressionCalculator.defence_rating(attrs)],
		["stat.evasion", ProgressionCalculator.evasion(attrs)],
		["stat.initiative", ProgressionCalculator.initiative(attrs)],
		["stat.damage_bonus", ProgressionCalculator.attribute_damage_bonus(attrs, weapon.weapon_class)],
		["stat.crit_chance", "%d%%" % roundi(HitCalculator.crit_chance_for(attrs, weapon) * 100)],
	]
	for row in rows:
		var label := Label.new()
		label.text = "%s: %s" % [tr(row[0]), str(row[1])]
		label.add_theme_font_size_override("font_size", 17)
		_stats_box.add_child(label)


func _on_confirm_pressed() -> void:
	for attr in _pending.keys():
		var delta: int = int(_pending[attr])
		if delta > 0:
			_profile.attributes.set(attr, int(_profile.attributes.get(attr)) + delta)
			_profile.attribute_points -= delta
	_pending.clear()
	SaveManager.save_profile(_profile)
	_refresh()


func _on_back_pressed() -> void:
	SceneRouter.goto_town()
