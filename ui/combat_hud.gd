class_name CombatHUD
extends CanvasLayer
## Combat HUD (charter §28): both fighters' HP/Energy/Armour with icons,
## an icon action bar with the player's skills inlined (no submenu — session-2
## directive), a hint line, and a fading announcement banner for champion
## lines. Fully mouse/touch driven; all visible text via translation keys.
## Reads combat state; NEVER computes combat math (charter §6).

signal action_selected(action: Enums.ActionType, skill: SkillData)

const ACTION_ICONS: Dictionary = {
	Enums.ActionType.ATTACK: preload("res://assets/icons/action_attack.svg"),
	Enums.ActionType.DEFEND: preload("res://assets/icons/action_defend.svg"),
	Enums.ActionType.APPROACH: preload("res://assets/icons/action_approach.svg"),
	Enums.ActionType.RETREAT: preload("res://assets/icons/action_retreat.svg"),
	Enums.ActionType.REST: preload("res://assets/icons/action_rest.svg"),
}

const COST_COLOR := Color(0.88, 0.66, 0.25)
const COOLDOWN_COLOR := Color(0.9, 0.4, 0.35)

var player: Combatant = null
var enemy: Combatant = null
var ctx: CombatContext = null

## SkillData -> Button, built once per combat in setup().
var _skill_buttons: Dictionary = {}

@onready var _player_name: Label = %PlayerName
@onready var _player_hp_label: Label = %PlayerHPLabel
@onready var _player_hp_bar: ProgressBar = %PlayerHPBar
@onready var _player_energy_label: Label = %PlayerEnergyLabel
@onready var _player_energy_bar: ProgressBar = %PlayerEnergyBar
@onready var _player_armour_label: Label = %PlayerArmourLabel
@onready var _player_armour_bar: ProgressBar = %PlayerArmourBar
@onready var _enemy_name: Label = %EnemyName
@onready var _enemy_hp_label: Label = %EnemyHPLabel
@onready var _enemy_hp_bar: ProgressBar = %EnemyHPBar
@onready var _enemy_energy_label: Label = %EnemyEnergyLabel
@onready var _enemy_energy_bar: ProgressBar = %EnemyEnergyBar
@onready var _enemy_armour_label: Label = %EnemyArmourLabel
@onready var _enemy_armour_bar: ProgressBar = %EnemyArmourBar
@onready var _round_label: Label = %RoundLabel
@onready var _turn_label: Label = %TurnLabel
@onready var _distance_label: Label = %DistanceLabel
@onready var _hint_label: Label = %HintLabel
@onready var _announce_label: Label = %AnnounceLabel
@onready var _player_status_row: HBoxContainer = %PlayerStatusRow
@onready var _enemy_status_row: HBoxContainer = %EnemyStatusRow
@onready var _action_bar: HBoxContainer = %ActionBar
@onready var _skill_separator: VSeparator = %SkillSeparator
@onready var _buttons: Dictionary = {
	Enums.ActionType.ATTACK: %AttackButton,
	Enums.ActionType.DEFEND: %DefendButton,
	Enums.ActionType.APPROACH: %ApproachButton,
	Enums.ActionType.RETREAT: %RetreatButton,
	Enums.ActionType.REST: %RestButton,
}


func _ready() -> void:
	(%AttackButton as Button).text = tr("combat.action.attack")
	(%DefendButton as Button).text = tr("combat.action.defend")
	(%ApproachButton as Button).text = tr("combat.action.approach")
	(%RetreatButton as Button).text = tr("combat.action.retreat")
	(%RestButton as Button).text = tr("combat.action.rest")
	for type: Enums.ActionType in _buttons.keys():
		var button: Button = _buttons[type]
		button.icon = ACTION_ICONS[type]
		button.add_theme_constant_override("icon_max_width", 30)
		button.pressed.connect(_on_action_button.bind(type))

	# Semantic bar colors (same meaning on both panels): HP green,
	# Energy amber, Armour steel-blue.
	var hp_fill := UITheme.bar_fill(Color(0.44, 0.75, 0.35))
	var energy_fill := UITheme.bar_fill(Color(0.88, 0.66, 0.25))
	var armour_fill := UITheme.bar_fill(Color(0.5, 0.6, 0.78))
	_player_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	_enemy_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	_player_energy_bar.add_theme_stylebox_override("fill", energy_fill)
	_enemy_energy_bar.add_theme_stylebox_override("fill", energy_fill)
	_player_armour_bar.add_theme_stylebox_override("fill", armour_fill)
	_enemy_armour_bar.add_theme_stylebox_override("fill", armour_fill)

	end_player_turn()
	_hint_label.text = ""

	EventBus.combat_started.connect(_on_combat_started)
	EventBus.round_started.connect(_on_round_started)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.action_resolved.connect(_on_action_resolved)
	EventBus.combatant_died.connect(_on_combatant_died)
	EventBus.status_applied.connect(_on_status_changed)
	EventBus.status_ticked.connect(_on_status_ticked)
	EventBus.status_expired.connect(_on_status_gone)


func setup(new_player: Combatant, new_enemy: Combatant, combat_ctx: CombatContext) -> void:
	player = new_player
	enemy = new_enemy
	ctx = combat_ctx

	_player_name.text = player.display_name()
	_enemy_name.text = enemy.display_name()

	player.hp_changed.connect(func(_c: int, _m: int) -> void: _refresh_stat_rows())
	player.energy_changed.connect(func(_c: int, _m: int) -> void: _refresh_stat_rows())
	player.armour_changed.connect(func(_c: int, _m: int) -> void: _refresh_stat_rows())
	enemy.hp_changed.connect(func(_c: int, _m: int) -> void: _refresh_stat_rows())
	enemy.energy_changed.connect(func(_c: int, _m: int) -> void: _refresh_stat_rows())
	enemy.armour_changed.connect(func(_c: int, _m: int) -> void: _refresh_stat_rows())

	_build_skill_buttons()
	_refresh_stat_rows()
	_refresh_status_rows()
	_refresh_distance()


## The player's skills live directly on the action bar as icon buttons
## (session-2 directive: no popup submenu). Built once per combat.
func _build_skill_buttons() -> void:
	for skill in _skill_buttons.keys():
		(_skill_buttons[skill] as Button).queue_free()
	_skill_buttons.clear()
	_skill_separator.visible = not player.get_skills().is_empty()
	for skill in player.get_skills():
		var button := Button.new()
		button.icon = skill.icon
		button.text = str(skill.energy_cost)
		button.custom_minimum_size = Vector2(72, 84)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 36)
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", COST_COLOR)
		button.tooltip_text = "%s — %s" % [tr(skill.name_key), tr(skill.description_key)]
		button.pressed.connect(_on_skill_button.bind(skill))
		_action_bar.add_child(button)
		_skill_buttons[skill] = button


func begin_player_turn(actor: Combatant) -> void:
	for type: Enums.ActionType in _buttons.keys():
		(_buttons[type] as Button).disabled = not CombatAction.is_valid(type, actor, ctx)
	for skill: SkillData in _skill_buttons.keys():
		var button: Button = _skill_buttons[skill]
		var cooldown: int = actor.cooldown_remaining(skill.id)
		button.disabled = not CombatAction.is_skill_valid(skill, actor, ctx)
		# Amber number = energy cost; red number = rounds of cooldown left.
		button.text = str(cooldown) if cooldown > 0 else str(skill.energy_cost)
		button.add_theme_color_override("font_color",
				COOLDOWN_COLOR if cooldown > 0 else COST_COLOR)
	var attack_reason: String = CombatAction.invalid_reason_key(Enums.ActionType.ATTACK, actor, ctx)
	_hint_label.text = tr(attack_reason) if attack_reason != "" else ""


func end_player_turn() -> void:
	for type: Enums.ActionType in _buttons.keys():
		(_buttons[type] as Button).disabled = true
	for skill: SkillData in _skill_buttons.keys():
		(_skill_buttons[skill] as Button).disabled = true
	_hint_label.text = ""


func _on_action_button(type: Enums.ActionType) -> void:
	end_player_turn()
	action_selected.emit(type, null)


func _on_skill_button(skill: SkillData) -> void:
	end_player_turn()
	action_selected.emit(Enums.ActionType.SKILL, skill)


## Fading center-screen banner (champion intros/defeats and other big beats).
func show_announcement(text: String) -> void:
	_announce_label.text = text
	_announce_label.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(_announce_label, "modulate:a", 0.0, 0.8)


# --- EventBus listeners -----------------------------------------------------

func _on_combat_started(_p: Combatant, e: Combatant) -> void:
	if e.data.intro_key != "":
		show_announcement(tr(e.data.intro_key))


func _on_round_started(round_number: int) -> void:
	_round_label.text = tr("combat.hud.round").format({"round": round_number})


func _on_turn_started(combatant: Combatant) -> void:
	if combatant.is_player_controlled:
		_turn_label.text = tr("combat.hud.your_turn")
	else:
		_turn_label.text = tr("combat.hud.enemy_turn").format({"name": combatant.display_name()})


func _on_action_resolved(result: ActionResult) -> void:
	if result.action == Enums.ActionType.APPROACH or result.action == Enums.ActionType.RETREAT:
		_refresh_distance()
	_refresh_stat_rows()


func _on_combatant_died(combatant: Combatant) -> void:
	if combatant.data.defeat_key != "":
		show_announcement(tr(combatant.data.defeat_key))


func _on_status_changed(_target: Combatant, _instance: StatusEffectInstance) -> void:
	_refresh_status_rows()


func _on_status_ticked(_target: Combatant, _results: Array) -> void:
	_refresh_stat_rows()
	_refresh_status_rows()


func _on_status_gone(_target: Combatant, _effect: StatusEffectData) -> void:
	_refresh_status_rows()


# --- Internal refresh -------------------------------------------------------

func _refresh_stat_rows() -> void:
	_set_row(_player_hp_label, _player_hp_bar, "combat.hud.hp", player.current_hp, player.max_hp)
	_set_row(_player_energy_label, _player_energy_bar, "combat.hud.energy",
			player.current_energy, player.max_energy)
	_set_row(_player_armour_label, _player_armour_bar, "combat.hud.armour",
			player.armour_current, player.armour_max)
	_set_row(_enemy_hp_label, _enemy_hp_bar, "combat.hud.hp", enemy.current_hp, enemy.max_hp)
	_set_row(_enemy_energy_label, _enemy_energy_bar, "combat.hud.energy",
			enemy.current_energy, enemy.max_energy)
	_set_row(_enemy_armour_label, _enemy_armour_bar, "combat.hud.armour",
			enemy.armour_current, enemy.armour_max)


func _set_row(label: Label, bar: ProgressBar, key: String, current: int, max_value: int) -> void:
	label.text = tr("combat.hud.stat_row").format({
		"name": tr(key), "current": current, "max": max_value,
	})
	bar.max_value = maxi(max_value, 1)
	bar.value = current


func _refresh_distance() -> void:
	_distance_label.text = tr(Enums.distance_band_key(ctx.band()))


## Placeholder status icons: tinted squares + stack count (distinct colors;
## real colorblind-safe icons arrive with final art — tracked in ASSET_MANIFEST).
func _refresh_status_rows() -> void:
	_fill_status_row(_player_status_row, player)
	_fill_status_row(_enemy_status_row, enemy)


func _fill_status_row(row: HBoxContainer, combatant: Combatant) -> void:
	for child in row.get_children():
		child.queue_free()
	for instance in combatant.status_effects:
		var swatch := ColorRect.new()
		swatch.color = instance.data.tint
		swatch.custom_minimum_size = Vector2(16, 16)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		if instance.stacks > 1:
			var stacks := Label.new()
			stacks.text = "x%d" % instance.stacks
			stacks.add_theme_font_size_override("font_size", 13)
			row.add_child(stacks)
