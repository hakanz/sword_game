class_name CombatHUD
extends CanvasLayer
## Combat HUD (charter §28): player HP/Energy/Armour, opponent HP/Armour,
## action bar, hint line, combat log. Fully mouse/touch driven — no hover or
## keyboard requirement. All visible text comes from translation keys.
## Reads combat state; NEVER computes combat math (charter §6).

signal action_selected(action: Enums.ActionType, skill: SkillData)

var player: Combatant = null
var enemy: Combatant = null
var ctx: CombatContext = null

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
@onready var _enemy_armour_label: Label = %EnemyArmourLabel
@onready var _enemy_armour_bar: ProgressBar = %EnemyArmourBar
@onready var _round_label: Label = %RoundLabel
@onready var _turn_label: Label = %TurnLabel
@onready var _distance_label: Label = %DistanceLabel
@onready var _hint_label: Label = %HintLabel
@onready var _log: RichTextLabel = %CombatLog
@onready var _player_status_row: HBoxContainer = %PlayerStatusRow
@onready var _enemy_status_row: HBoxContainer = %EnemyStatusRow
@onready var _skills_button: Button = %SkillsButton
@onready var _skill_panel: PanelContainer = %SkillPanel
@onready var _skill_list: VBoxContainer = %SkillList
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
	_skills_button.text = tr("combat.action.skills")
	for type: Enums.ActionType in _buttons.keys():
		(_buttons[type] as Button).pressed.connect(_on_action_button.bind(type))
	_skills_button.pressed.connect(_on_skills_toggled)
	end_player_turn()
	_hint_label.text = ""

	EventBus.combat_started.connect(_on_combat_started)
	EventBus.round_started.connect(_on_round_started)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.turn_skipped.connect(_on_turn_skipped)
	EventBus.action_resolved.connect(_on_action_resolved)
	EventBus.combatant_died.connect(_on_combatant_died)
	EventBus.status_applied.connect(_on_status_applied)
	EventBus.status_ticked.connect(_on_status_ticked)
	EventBus.status_expired.connect(_on_status_expired)


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
	enemy.armour_changed.connect(func(_c: int, _m: int) -> void: _refresh_stat_rows())

	_refresh_stat_rows()
	_refresh_status_rows()
	_refresh_distance()


func begin_player_turn(actor: Combatant) -> void:
	for type: Enums.ActionType in _buttons.keys():
		(_buttons[type] as Button).disabled = not CombatAction.is_valid(type, actor, ctx)
	_skills_button.disabled = actor.get_skills().is_empty()
	_populate_skill_panel(actor)
	var attack_reason: String = CombatAction.invalid_reason_key(Enums.ActionType.ATTACK, actor, ctx)
	_hint_label.text = tr(attack_reason) if attack_reason != "" else ""


func end_player_turn() -> void:
	for type: Enums.ActionType in _buttons.keys():
		(_buttons[type] as Button).disabled = true
	_skills_button.disabled = true
	_skill_panel.visible = false
	_hint_label.text = ""


func _on_action_button(type: Enums.ActionType) -> void:
	end_player_turn()
	action_selected.emit(type, null)


func _on_skills_toggled() -> void:
	_skill_panel.visible = not _skill_panel.visible


## Rebuilds the expand-on-demand skill submenu (charter §28) for this turn.
func _populate_skill_panel(actor: Combatant) -> void:
	for child in _skill_list.get_children():
		child.queue_free()
	for skill in actor.get_skills():
		var button := Button.new()
		var reason: String = CombatAction.skill_invalid_reason(skill, actor, ctx)
		var cooldown: int = actor.cooldown_remaining(skill.id)
		var label: String = "%s  (%d)" % [tr(skill.name_key), skill.energy_cost]
		if cooldown > 0:
			label = tr("combat.hint.cooldown").format({"rounds": cooldown}) + " — " + label
		button.text = label
		button.custom_minimum_size = Vector2(0, 48)
		button.disabled = reason != ""
		button.pressed.connect(_on_skill_button.bind(skill))
		_skill_list.add_child(button)


func _on_skill_button(skill: SkillData) -> void:
	end_player_turn()
	action_selected.emit(Enums.ActionType.SKILL, skill)


# --- EventBus listeners -----------------------------------------------------

func _on_combat_started(p: Combatant, e: Combatant) -> void:
	_append_log(tr("combat.log.combat_start").format({
		"player": p.display_name(),
		"enemy": e.display_name(),
	}))
	if e.data.intro_key != "":
		_append_log(tr(e.data.intro_key))


func _on_round_started(round_number: int) -> void:
	_round_label.text = tr("combat.hud.round").format({"round": round_number})
	_append_log(tr("combat.log.round").format({"round": round_number}))


func _on_turn_started(combatant: Combatant) -> void:
	if combatant.is_player_controlled:
		_turn_label.text = tr("combat.hud.your_turn")
	else:
		_turn_label.text = tr("combat.hud.enemy_turn").format({"name": combatant.display_name()})


func _on_turn_skipped(combatant: Combatant) -> void:
	_append_log(tr("combat.log.stunned").format({"name": combatant.display_name()}))


func _on_status_applied(target: Combatant, instance: StatusEffectInstance) -> void:
	_append_log(tr("combat.log.status_applied").format({
		"name": target.display_name(),
		"status": tr(instance.data.name_key),
	}))
	_refresh_status_rows()


func _on_status_ticked(target: Combatant, results: Array[StatusEffectSystem.TickResult]) -> void:
	for tick in results:
		if tick.damage > 0:
			_append_log(tr("combat.log.status_damage").format({
				"name": target.display_name(),
				"damage": tick.damage,
				"status": tr(tick.effect.name_key),
			}))
		if tick.healing > 0:
			_append_log(tr("combat.log.status_heal").format({
				"name": target.display_name(),
				"healing": tick.healing,
				"status": tr(tick.effect.name_key),
			}))
	_refresh_stat_rows()
	_refresh_status_rows()


func _on_status_expired(target: Combatant, effect: StatusEffectData) -> void:
	_append_log(tr("combat.log.status_expired").format({
		"name": target.display_name(),
		"status": tr(effect.name_key),
	}))
	_refresh_status_rows()


func _on_action_resolved(result: ActionResult) -> void:
	var actor_name: String = result.actor.display_name()
	match result.action:
		Enums.ActionType.ATTACK:
			if result.hit:
				_append_log(tr("combat.log.attack_hit").format({
					"attacker": actor_name,
					"defender": result.target.display_name(),
					"damage": result.mitigation.after_stance,
					"absorbed": result.mitigation.absorbed,
				}))
			else:
				_append_log(tr("combat.log.attack_miss").format({
					"attacker": actor_name,
					"defender": result.target.display_name(),
					"chance": roundi(result.hit_chance * 100.0),
				}))
		Enums.ActionType.SKILL:
			if result.target == null:
				_append_log(tr("combat.log.buff").format({
					"name": actor_name,
					"skill": tr(result.skill.name_key),
				}))
			elif result.hit:
				_append_log(tr("combat.log.skill_hit").format({
					"attacker": actor_name,
					"defender": result.target.display_name(),
					"skill": tr(result.skill.name_key),
					"damage": result.mitigation.after_stance,
					"absorbed": result.mitigation.absorbed,
				}))
			else:
				_append_log(tr("combat.log.skill_miss").format({
					"attacker": actor_name,
					"defender": result.target.display_name(),
					"skill": tr(result.skill.name_key),
					"chance": roundi(result.hit_chance * 100.0),
				}))
		Enums.ActionType.DEFEND:
			_append_log(tr("combat.log.defend").format({"name": actor_name}))
		Enums.ActionType.APPROACH:
			_refresh_distance()
			_append_log(tr("combat.log.approach").format({
				"name": actor_name,
				"distance": tr(Enums.distance_band_key(result.distance_after)),
			}))
		Enums.ActionType.RETREAT:
			_refresh_distance()
			_append_log(tr("combat.log.retreat").format({
				"name": actor_name,
				"distance": tr(Enums.distance_band_key(result.distance_after)),
			}))
		Enums.ActionType.REST:
			_append_log(tr("combat.log.rest").format({
				"name": actor_name,
				"energy": result.energy_restored,
			}))
	_refresh_stat_rows()


func _on_combatant_died(combatant: Combatant) -> void:
	if combatant.data.defeat_key != "":
		_append_log(tr(combatant.data.defeat_key))
	else:
		_append_log(tr("combat.log.death").format({"name": combatant.display_name()}))


# --- Internal refresh -------------------------------------------------------

func _refresh_stat_rows() -> void:
	_set_row(_player_hp_label, _player_hp_bar, "combat.hud.hp", player.current_hp, player.max_hp)
	_set_row(_player_energy_label, _player_energy_bar, "combat.hud.energy",
			player.current_energy, player.max_energy)
	_set_row(_player_armour_label, _player_armour_bar, "combat.hud.armour",
			player.armour_current, player.armour_max)
	_set_row(_enemy_hp_label, _enemy_hp_bar, "combat.hud.hp", enemy.current_hp, enemy.max_hp)
	_set_row(_enemy_armour_label, _enemy_armour_bar, "combat.hud.armour",
			enemy.armour_current, enemy.armour_max)


func _set_row(label: Label, bar: ProgressBar, key: String, current: int, max_value: int) -> void:
	label.text = tr("combat.hud.stat_row").format({
		"name": tr(key), "current": current, "max": max_value,
	})
	bar.max_value = maxi(max_value, 1)
	bar.value = current


func _refresh_distance() -> void:
	_distance_label.text = tr(Enums.distance_band_key(ctx.distance))


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


func _append_log(line: String) -> void:
	# add_text, never append_text: log lines contain fighter names, and
	# append_text would parse any "[...]" in them as BBCode.
	_log.add_text(line + "\n")
