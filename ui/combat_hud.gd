class_name CombatHUD
extends CanvasLayer
## Combat HUD (charter §28): fighter panels with icons, a RADIAL action menu
## that pops up around the player's gladiator on their turn (owner design,
## session 3), hint line, pause overlay, and an announcement banner.
## Fully mouse/touch driven; all visible text via translation keys.
## Reads combat state; NEVER computes combat math (charter §6).

signal action_selected(action: Enums.ActionType, skill: SkillData)

const ACTION_ICONS: Dictionary = {
	Enums.ActionType.ATTACK: preload("res://assets/icons/action_attack.svg"),
	Enums.ActionType.DEFEND: preload("res://assets/icons/action_defend.svg"),
	Enums.ActionType.APPROACH: preload("res://assets/icons/action_approach.svg"),
	Enums.ActionType.RETREAT: preload("res://assets/icons/action_retreat.svg"),
	Enums.ActionType.REST: preload("res://assets/icons/action_rest.svg"),
	Enums.ActionType.SWITCH_WEAPON: preload("res://assets/icons/action_switch.svg"),
}

const COST_COLOR := Color(0.98, 0.8, 0.35)
const COOLDOWN_COLOR := Color(1.0, 0.45, 0.4)
const AMMO_COLOR := Color(0.75, 0.9, 1.0)
const RADIAL_RADIUS: float = 142.0
const RADIAL_BUTTON: float = 58.0

var player: Combatant = null
var enemy: Combatant = null
var ctx: CombatContext = null

## Thin XP progress bar under the player's name (built in code — session-5
## owner design: level and XP always visible in the fight).
var _xp_bar: ProgressBar = null
## Crowd standing row per fighter (V2 §54), also built in code so the panel
## scene stays the layout authority: fighter -> {bar, label}.
var _crowd_rows: Dictionary = {}

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
@onready var _radial: Control = %RadialMenu
@onready var _pause_button: Button = %PauseButton
@onready var _pause_panel: Control = %PausePanel
@onready var _pause_title: Label = %PauseTitle
@onready var _resume_button: Button = %ResumeButton
@onready var _leave_button: Button = %LeaveButton
@onready var _leave_dialog: ConfirmationDialog = %LeaveDialog


func _ready() -> void:
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

	_pause_title.text = tr("pause.title")
	_resume_button.text = tr("pause.resume")
	_leave_button.text = tr("pause.leave")
	_leave_dialog.title = tr("pause.leave")
	_leave_dialog.dialog_text = tr("pause.leave_confirm")
	_leave_dialog.ok_button_text = tr("common.confirm")
	_leave_dialog.cancel_button_text = tr("common.cancel")
	_pause_button.pressed.connect(_set_paused.bind(true))
	_resume_button.pressed.connect(_set_paused.bind(false))
	_leave_button.pressed.connect(_leave_dialog.popup_centered)
	_leave_dialog.confirmed.connect(_on_leave_confirmed)

	end_player_turn()
	_hint_label.text = ""

	EventBus.combat_ended.connect(_on_combat_ended)
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.round_started.connect(_on_round_started)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.action_resolved.connect(_on_action_resolved)
	EventBus.combatant_died.connect(_on_combatant_died)
	EventBus.status_applied.connect(_on_status_changed)
	EventBus.status_ticked.connect(_on_status_ticked)
	EventBus.status_expired.connect(_on_status_gone)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)


func setup(new_player: Combatant, new_enemy: Combatant, combat_ctx: CombatContext) -> void:
	player = new_player
	enemy = new_enemy
	ctx = combat_ctx

	_player_name.text = player.display_name()
	_enemy_name.text = enemy.display_name()
	_build_xp_row()

	player.hp_changed.connect(func(_c: int, _m: int) -> void: _refresh_stat_rows())
	player.energy_changed.connect(func(_c: int, _m: int) -> void: _refresh_stat_rows())
	player.armour_changed.connect(func(_c: int, _m: int) -> void: _refresh_stat_rows())
	enemy.hp_changed.connect(func(_c: int, _m: int) -> void: _refresh_stat_rows())
	enemy.energy_changed.connect(func(_c: int, _m: int) -> void: _refresh_stat_rows())
	enemy.armour_changed.connect(func(_c: int, _m: int) -> void: _refresh_stat_rows())

	_build_crowd_row(player, _player_armour_bar)
	_build_crowd_row(enemy, _enemy_armour_bar)
	player.crowd_changed.connect(
			func(_v: int, _s: CrowdSystem.State) -> void: _refresh_crowd_row(player))
	enemy.crowd_changed.connect(
			func(_v: int, _s: CrowdSystem.State) -> void: _refresh_crowd_row(enemy))

	_refresh_stat_rows()
	_refresh_status_rows()
	_refresh_distance()


## Level tag on the name + a slim gold XP bar right under it. Reads the
## profile only (display) — progression math stays in the calculators.
func _build_xp_row() -> void:
	var profile: PlayerProfile = GameManager.profile
	if profile == null:
		return
	_player_name.text = "%s  ·  %s" % [player.display_name(),
			tr("combat.hud.level").format({"level": profile.level})]
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(0, 7)
	_xp_bar.show_percentage = false
	_xp_bar.max_value = ProgressionCalculator.xp_required(
			GameManager.PROGRESSION_CONFIG, profile.level)
	_xp_bar.value = profile.xp
	_xp_bar.tooltip_text = "%s %d / %d" % [tr("combat.hud.xp"),
			profile.xp, int(_xp_bar.max_value)]
	_xp_bar.add_theme_stylebox_override("fill", UITheme.bar_fill(Color(0.93, 0.76, 0.35)))
	var box: VBoxContainer = _player_name.get_parent()
	box.add_child(_xp_bar)
	box.move_child(_xp_bar, _player_name.get_index() + 1)


## Crowd standing row (icon + bar + state word), slotted under the armour row
## of the fighter's own panel so it reads as one more vital sign (V2 §54).
func _build_crowd_row(fighter: Combatant, after_bar: ProgressBar) -> void:
	var armour_row: Control = after_bar.get_parent()
	var panel: Node = armour_row.get_parent()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	panel.move_child(row, armour_row.get_index() + 1)

	var icon := TextureRect.new()
	icon.texture = preload("res://assets/icons/stat_crowd.svg")
	icon.custom_minimum_size = Vector2(18, 18)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var label := Label.new()
	label.custom_minimum_size = Vector2(96, 0)
	label.add_theme_font_size_override("font_size", 14)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.min_value = CrowdSystem.MINIMUM
	bar.max_value = CrowdSystem.MAXIMUM
	row.add_child(bar)

	_crowd_rows[fighter] = {"bar": bar, "label": label}
	_refresh_crowd_row(fighter)


func _refresh_crowd_row(fighter: Combatant) -> void:
	if not _crowd_rows.has(fighter):
		return
	var state: CrowdSystem.State = CrowdSystem.state_of(fighter.crowd)
	var bar: ProgressBar = _crowd_rows[fighter]["bar"]
	var label: Label = _crowd_rows[fighter]["label"]
	bar.value = fighter.crowd
	bar.add_theme_stylebox_override("fill", UITheme.bar_fill(_crowd_color(state)))
	label.text = tr(CrowdSystem.label_key(state))
	label.add_theme_color_override("font_color", _crowd_color(state))


func _crowd_color(state: CrowdSystem.State) -> Color:
	match state:
		CrowdSystem.State.HOSTILE:
			return Color(0.85, 0.35, 0.35)
		CrowdSystem.State.BORED:
			return Color(0.62, 0.6, 0.66)
		CrowdSystem.State.EXCITED:
			return Color(0.95, 0.7, 0.35)
		CrowdSystem.State.FRENZIED:
			return Color(1.0, 0.52, 0.28)
		_:
			return Color(0.78, 0.76, 0.82)


# --- Radial action menu (owner design: actions orbit the gladiator) ---------

func begin_player_turn(actor: Combatant) -> void:
	_build_radial(actor)
	var attack_reason: String = CombatAction.invalid_reason_key(Enums.ActionType.ATTACK, actor, ctx)
	_hint_label.text = tr(attack_reason) if attack_reason != "" else ""


func end_player_turn() -> void:
	for child in _radial.get_children():
		child.queue_free()
	_radial.visible = false
	_hint_label.text = ""


func _build_radial(actor: Combatant) -> void:
	for child in _radial.get_children():
		child.queue_free()
	_radial.visible = true

	# Screen anchor: the gladiator's chest. The HUD is a CanvasLayer, so it is
	# NOT camera-transformed — the world point must be projected through the
	# viewport's canvas transform, which carries CombatCamera's pan and zoom
	# (V2 §51). Anchoring on raw world coordinates would leave the ring
	# floating between the fighters the moment the camera zooms in.
	var to_screen: Transform2D = actor.get_global_transform_with_canvas()
	var center: Vector2 = to_screen * Vector2(0, -95)
	# The ring widens with the zoom so it keeps orbiting the fighter; the
	# BUTTONS stay their tuned size (touch targets, charter Godot Rules).
	var radius: float = RADIAL_RADIUS * maxf(to_screen.get_scale().x, 0.1)
	var toward_foe: float = 0.0 if ctx.foe_of(actor).position.x >= actor.position.x else PI

	var entries: Array[Dictionary] = []
	entries.append(_base_entry(actor, Enums.ActionType.ATTACK))
	for skill in actor.get_skills():
		entries.append(_skill_entry(actor, skill))
	entries.append(_base_entry(actor, Enums.ActionType.DEFEND))
	if actor.can_switch_weapon():
		entries.append(_base_entry(actor, Enums.ActionType.SWITCH_WEAPON))
	entries.append(_base_entry(actor, Enums.ActionType.REST))
	entries.append(_base_entry(actor, Enums.ActionType.RETREAT))
	entries.append(_base_entry(actor, Enums.ActionType.APPROACH))

	var count: int = entries.size()
	for index in count:
		var angle: float = toward_foe + TAU * index / count
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		_spawn_radial_button(entries[index], pos, index)


func _base_entry(actor: Combatant, type: Enums.ActionType) -> Dictionary:
	var badge: String = ""
	var badge_color: Color = COST_COLOR
	match type:
		Enums.ActionType.ATTACK:
			if actor.get_weapon().is_ranged():
				badge = str(actor.arrows)
				badge_color = AMMO_COLOR
			elif actor.get_weapon().energy_cost > 0:
				badge = str(actor.get_weapon().energy_cost)
		Enums.ActionType.APPROACH, Enums.ActionType.RETREAT:
			badge = str(CombatTuning.MOVE_ENERGY_COST)
		_:
			pass
	return {
		"icon": ACTION_ICONS[type],
		"name": tr(_action_name_key(type)),
		"badge": badge,
		"badge_color": badge_color,
		"valid": CombatAction.is_valid(type, actor, ctx),
		"callback": func() -> void:
			end_player_turn()
			action_selected.emit(type, null),
	}


func _skill_entry(actor: Combatant, skill: SkillData) -> Dictionary:
	var cooldown: int = actor.cooldown_remaining(skill.id)
	var badge: String = str(cooldown) if cooldown > 0 else str(maxi(skill.energy_cost, skill.mana_cost))
	return {
		"icon": skill.icon,
		"name": tr(skill.name_key),
		"badge": badge,
		"badge_color": COOLDOWN_COLOR if cooldown > 0 else COST_COLOR,
		"valid": CombatAction.is_skill_valid(skill, actor, ctx),
		"callback": func() -> void:
			end_player_turn()
			action_selected.emit(Enums.ActionType.SKILL, skill),
	}


func _spawn_radial_button(entry: Dictionary, pos: Vector2, index: int) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(RADIAL_BUTTON, RADIAL_BUTTON)
	button.size = button.custom_minimum_size
	button.position = pos - button.size / 2.0
	button.icon = entry["icon"]
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 32)
	button.disabled = not entry["valid"]
	button.tooltip_text = entry["name"]
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, UITheme.round_button_box(state))
	button.pressed.connect(entry["callback"])
	_radial.add_child(button)

	var name_label := Label.new()
	name_label.text = entry["name"]
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color",
			Color(0.95, 0.93, 0.98) if entry["valid"] else Color(0.6, 0.57, 0.65))
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(110, 0)
	name_label.position = pos + Vector2(-55, RADIAL_BUTTON / 2.0 + 2)
	_radial.add_child(name_label)

	if entry["badge"] != "":
		var badge := Label.new()
		badge.text = entry["badge"]
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_color_override("font_color", entry["badge_color"])
		badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		badge.add_theme_constant_override("shadow_offset_y", 1)
		badge.position = pos + Vector2(RADIAL_BUTTON / 2.0 - 12, -RADIAL_BUTTON / 2.0 - 8)
		_radial.add_child(badge)

	# Pop-in: each ring slot scales up with a tiny stagger.
	button.pivot_offset = button.size / 2.0
	button.scale = Vector2(0.3, 0.3)
	var tween: Tween = create_tween()
	tween.tween_interval(0.02 * index)
	tween.tween_property(button, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _action_name_key(type: Enums.ActionType) -> String:
	match type:
		Enums.ActionType.ATTACK: return "combat.action.attack"
		Enums.ActionType.DEFEND: return "combat.action.defend"
		Enums.ActionType.APPROACH: return "combat.action.approach"
		Enums.ActionType.RETREAT: return "combat.action.retreat"
		Enums.ActionType.REST: return "combat.action.rest"
		Enums.ActionType.SWITCH_WEAPON: return "combat.action.switch"
		_: return ""


# --- Pause ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Optional desktop shortcut — pause stays fully reachable by touch.
	# (This CanvasLayer runs with PROCESS_MODE_ALWAYS so Esc also unpauses.)
	if event.is_action_pressed("ui_cancel") and GameManager.last_combat_result == null:
		_set_paused(not get_tree().paused)


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_pause_panel.visible = paused
	_pause_button.visible = not paused


## Leaving mid-fight: no rewards, an active tournament run is forfeited.
func _on_leave_confirmed() -> void:
	if GameManager.last_combat_result != null:
		return  # fight already resolved while the dialog was open
	get_tree().paused = false
	GameManager.abandon_tournament()
	GameManager.last_combat_result = null
	SceneRouter.goto_town()


## Fading center-screen banner (champion intros/defeats and other big beats).
## A champion changing shape is announced on the same banner the intro and
## defeat lines use — the player must SEE the fight get harder (V2 §55).
func _on_boss_phase_changed(fighter: Combatant, phase: int) -> void:
	var key: String = fighter.data.phase_key(phase)
	if key != "":
		show_announcement(tr(key))


func show_announcement(text: String) -> void:
	_announce_label.text = text
	_announce_label.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(_announce_label, "modulate:a", 0.0, 0.8)


# --- EventBus listeners -----------------------------------------------------

func _on_combat_ended(_victor: Combatant, _loser: Combatant) -> void:
	# No pausing/forfeiting a finished fight.
	_set_paused(false)
	_pause_button.visible = false
	if _leave_dialog.visible:
		_leave_dialog.hide()


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
	# Smooth drain/fill (modern-feel UI, session 5) — skip when unchanged.
	if not is_equal_approx(bar.value, float(current)):
		var tween: Tween = create_tween()
		tween.tween_property(bar, "value", float(current), 0.3) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
