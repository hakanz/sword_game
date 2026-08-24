class_name CombatHUD
extends CanvasLayer
## Combat HUD (charter §28): player HP/Energy/Armour, opponent HP/Armour,
## action bar, hint line, combat log. Fully mouse/touch driven — no hover or
## keyboard requirement. All visible text comes from translation keys.
## Reads combat state; NEVER computes combat math (charter §6).

signal action_selected(action: Enums.ActionType)

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
		(_buttons[type] as Button).pressed.connect(_on_action_button.bind(type))
	end_player_turn()
	_hint_label.text = ""

	EventBus.combat_started.connect(_on_combat_started)
	EventBus.round_started.connect(_on_round_started)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.action_resolved.connect(_on_action_resolved)
	EventBus.combatant_died.connect(_on_combatant_died)


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
	_refresh_distance()


func begin_player_turn(actor: Combatant) -> void:
	for type: Enums.ActionType in _buttons.keys():
		(_buttons[type] as Button).disabled = not CombatAction.is_valid(type, actor, ctx)
	var attack_reason: String = CombatAction.invalid_reason_key(Enums.ActionType.ATTACK, actor, ctx)
	_hint_label.text = tr(attack_reason) if attack_reason != "" else ""


func end_player_turn() -> void:
	for type: Enums.ActionType in _buttons.keys():
		(_buttons[type] as Button).disabled = true
	_hint_label.text = ""


func _on_action_button(type: Enums.ActionType) -> void:
	end_player_turn()
	action_selected.emit(type)


# --- EventBus listeners -----------------------------------------------------

func _on_combat_started(p: Combatant, e: Combatant) -> void:
	_append_log(tr("combat.log.combat_start").format({
		"player": p.display_name(),
		"enemy": e.display_name(),
	}))


func _on_round_started(round_number: int) -> void:
	_round_label.text = tr("combat.hud.round").format({"round": round_number})
	_append_log(tr("combat.log.round").format({"round": round_number}))


func _on_turn_started(combatant: Combatant) -> void:
	if combatant.is_player_controlled:
		_turn_label.text = tr("combat.hud.your_turn")
	else:
		_turn_label.text = tr("combat.hud.enemy_turn").format({"name": combatant.display_name()})


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


func _append_log(line: String) -> void:
	# add_text, never append_text: log lines contain fighter names, and
	# append_text would parse any "[...]" in them as BBCode.
	_log.add_text(line + "\n")
