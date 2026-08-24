class_name CombatController
extends Node2D
## Orchestrates one combat encounter (charter §11 sub-state machine) WITHOUT
## doing the work itself: sequencing -> TurnManager, math -> calculators,
## enemy decisions -> CombatAI, presentation -> HUD/rigs. Status-effect
## resolution slots into _run_combat() when that phase lands.

## World coordinates are in the 1280x720 design space; WorldRoot re-centers
## that space in the real (stretch-expanded) viewport so fighters stay
## centered on every aspect ratio and clear of the anchored HUD bars.
const GROUND_Y: float = 500.0
const CENTER_X: float = 640.0
## Pixel gap between fighters per DistanceBand (ADJACENT..LONG).
const BAND_GAP_PX: Array[float] = [130.0, 260.0, 390.0, 520.0]

const PLAYER_FALLBACK: CharacterData = preload("res://data/characters/player_default.tres")
const ENEMY_FALLBACK: CharacterData = preload("res://data/characters/enemy_vosk.tres")
const ARENA_FALLBACK: ArenaData = preload("res://data/arenas/gravelmaw.tres")

var player: Combatant = null
var enemy: Combatant = null
var turn_manager := TurnManager.new()
var ctx := CombatContext.new()

@onready var world_root: Node2D = $WorldRoot
@onready var arena_visual: ArenaVisual = $WorldRoot/ArenaVisual
@onready var hud: CombatHUD = $CombatHUD


func _ready() -> void:
	# Fallbacks let the scene run standalone from the editor (F6) too.
	var player_data: CharacterData = GameManager.player_character
	if player_data == null:
		player_data = PLAYER_FALLBACK.duplicate(true)
		GameManager.player_character = player_data
	var enemy_data: CharacterData = GameManager.next_opponent
	if enemy_data == null:
		enemy_data = ENEMY_FALLBACK.duplicate(true)
		GameManager.next_opponent = enemy_data

	arena_visual.arena = GameManager.current_arena \
			if GameManager.current_arena != null else ARENA_FALLBACK

	get_viewport().size_changed.connect(_update_world_offset)
	_update_world_offset()

	player = Combatant.new()
	player.name = "PlayerCombatant"
	enemy = Combatant.new()
	enemy.name = "EnemyCombatant"
	world_root.add_child(player)
	world_root.add_child(enemy)
	player.setup(player_data, true, false)
	enemy.setup(enemy_data, false, true)
	_position_combatants(false)

	turn_manager.setup([player, enemy])
	hud.setup(player, enemy, ctx)

	_run_combat.call_deferred()


func _run_combat() -> void:
	EventBus.combat_started.emit(player, enemy)
	while true:
		var actor: Combatant = turn_manager.advance()
		if turn_manager.is_round_start():
			# Cap check BEFORE announcing — no phantom round beyond the cap.
			if turn_manager.round_number > CombatTuning.MAX_ROUNDS:
				break
			ctx.round_number = turn_manager.round_number
			EventBus.round_started.emit(turn_manager.round_number)
		actor.on_turn_started()
		actor.tick_cooldowns()
		EventBus.turn_started.emit(actor)

		if StatusEffectSystem.is_stunned(actor):
			# Stunned: the action is lost, but end-of-turn resolution still runs.
			EventBus.turn_skipped.emit(actor)
			await _delay(0.6)
		else:
			var decision: CombatDecision
			if actor.is_player_controlled and not GameManager.smoke_test:
				hud.begin_player_turn(actor)
				var selection: Array = await hud.action_selected
				hud.end_player_turn()
				decision = CombatDecision.new()
				decision.type = selection[0]
				decision.skill = selection[1]
			else:
				await _delay(0.5)
				decision = CombatAI.choose_action(actor, _foe_of(actor), ctx)
			await _execute(actor, decision)

		# STATUS_RESOLUTION (charter §11): DoTs/buffs tick on the actor's turn end.
		var ticks: Array[StatusEffectSystem.TickResult] = StatusEffectSystem.tick_turn_end(actor)
		if not ticks.is_empty():
			EventBus.status_ticked.emit(actor, ticks)
			await _delay(0.35)

		# Death check (charter §11) — combat ends immediately on a kill
		# (including a fighter succumbing to their own wounds' DoTs).
		if not player.is_alive() or not enemy.is_alive():
			var fallen: Combatant = player if not player.is_alive() else enemy
			if not fallen.death_announced:
				fallen.death_announced = true
				fallen.rig.play_death()
				EventBus.combatant_died.emit(fallen)
			break
	await _finish()


func _execute(actor: Combatant, decision: CombatDecision) -> void:
	var type: Enums.ActionType = decision.type
	if type == Enums.ActionType.SKILL:
		assert(CombatAction.is_skill_valid(decision.skill, actor, ctx),
				"Invalid skill reached execution: %s" % decision.skill.id)
	else:
		assert(CombatAction.is_valid(type, actor, ctx),
				"Invalid action reached execution: %s" % Enums.ActionType.keys()[type])
	var foe: Combatant = _foe_of(actor)
	var result := ActionResult.new()
	result.actor = actor
	result.action = type
	result.distance_after = ctx.distance

	if type == Enums.ActionType.SKILL:
		result.skill = decision.skill
		actor.spend_energy(decision.skill.energy_cost)
		actor.spend_mana(decision.skill.mana_cost)
		actor.set_cooldown(decision.skill.id, decision.skill.cooldown_rounds)
		if decision.skill.target == SkillData.Target.SELF:
			if decision.skill.applies_status != null:
				StatusEffectSystem.apply(actor, decision.skill.applies_status)
				result.applied_status = decision.skill.applies_status
				_spawn_float_text(actor, tr(decision.skill.applies_status.name_key),
						decision.skill.applies_status.tint)
			await _delay(0.4)
		else:
			result.target = foe
			await _resolve_strike(actor, foe, result, decision.skill.power_multiplier,
					decision.skill.accuracy_mod, decision.skill.armour_pen_bonus,
					decision.skill.applies_status)
	else:
		actor.spend_energy(CombatAction.energy_cost(type, actor))

	match type:
		Enums.ActionType.ATTACK:
			result.target = foe
			await _resolve_strike(actor, foe, result, 1.0, 0, 0.0, null)

		Enums.ActionType.DEFEND:
			actor.set_stance(Enums.Stance.DEFENDING)

		Enums.ActionType.APPROACH:
			ctx.approach()
			result.distance_after = ctx.distance
			_position_combatants(true)
			await _delay(0.3)

		Enums.ActionType.RETREAT:
			ctx.retreat()
			result.distance_after = ctx.distance
			_position_combatants(true)
			await _delay(0.3)

		Enums.ActionType.REST:
			result.energy_restored = actor.restore_energy(
					roundi(actor.max_energy * CombatTuning.REST_ENERGY_RESTORE_FRACTION))

	# Leaky defend counter (not a hard reset): alternating defend/attack
	# patterns still accumulate stall pressure instead of dodging the decay.
	actor.consecutive_defends = actor.consecutive_defends + 1 \
			if type == Enums.ActionType.DEFEND else maxi(actor.consecutive_defends - 1, 0)
	if type == Enums.ActionType.RETREAT:
		actor.total_retreats += 1

	if GameManager.smoke_test:
		# Console combat trace for CI/headless diagnosis (charter §34).
		var detail: String = ""
		if result.skill != null:
			detail = "[%s] " % result.skill.id
		if result.target != null:
			if result.hit:
				detail += "hit=%d (absorbed=%d hp=%d) chance=%.2f" % [
					result.mitigation.after_stance, result.mitigation.absorbed,
					result.mitigation.hp_damage, result.hit_chance]
			else:
				detail += "MISS chance=%.2f" % result.hit_chance
		print("R%03d %-24s %-9s %s [hp=%d/%d en=%d/%d arm=%d dist=%d]" % [
			turn_manager.round_number, actor.display_name(),
			Enums.ActionType.keys()[type], detail,
			actor.current_hp, actor.max_hp, actor.current_energy, actor.max_energy,
			actor.armour_current, ctx.distance])

	EventBus.action_resolved.emit(result)
	if result.killed:
		foe.death_announced = true
		EventBus.combatant_died.emit(foe)
	await _delay(0.25)


## Shared strike resolution for normal attacks and FOE-targeted skills:
## hit roll -> damage pipeline -> optional on-hit status.
func _resolve_strike(
		actor: Combatant, foe: Combatant, result: ActionResult,
		multiplier: float, accuracy_mod: int, pen_bonus: float,
		on_hit_status: StatusEffectData) -> void:
	result.hit_chance = HitCalculator.hit_chance(actor, foe, accuracy_mod)
	result.hit = RngService.chance(result.hit_chance)
	actor.rig.play_attack_lunge()
	await _delay(0.16)
	if result.hit:
		var raw: int = DamageCalculator.roll_attack_damage(actor, multiplier)
		var mitigation := DamageCalculator.compute_mitigation(
				raw,
				foe.get_resistance(actor.get_weapon().damage_type),
				foe.stance == Enums.Stance.DEFENDING,
				clampf(actor.get_weapon().armour_penetration + pen_bonus, 0.0, 1.0),
				foe.armour_current)
		foe.take_damage(mitigation)
		actor.damage_dealt_total += mitigation.after_stance
		result.mitigation = mitigation
		result.killed = not foe.is_alive()
		foe.rig.play_hit_flash()
		_spawn_float_text(foe, str(mitigation.after_stance),
				Color(1.0, 0.85, 0.3) if mitigation.hp_damage == 0 else Color(1.0, 0.35, 0.3))
		if on_hit_status != null and foe.is_alive():
			StatusEffectSystem.apply(foe, on_hit_status)
			result.applied_status = on_hit_status
		if result.killed:
			foe.rig.play_death()
	else:
		foe.rig.play_miss_dodge()
		_spawn_float_text(foe, tr("combat.float.miss"), Color(0.8, 0.8, 0.85))
	await _delay(0.35)


func _finish() -> void:
	var player_won: bool
	if player.is_alive() != enemy.is_alive():
		player_won = player.is_alive()
	else:
		player_won = CombatResult.stalemate_player_won(player, enemy)

	var victor: Combatant = player if player_won else enemy
	var loser: Combatant = enemy if player_won else player

	var result := CombatResult.new()
	result.player_won = player_won
	result.rounds = mini(turn_manager.round_number, CombatTuning.MAX_ROUNDS)
	result.player_damage_dealt = player.damage_dealt_total
	result.enemy_level = enemy.data.level
	result.victor_name = victor.display_name()
	result.loser_name = loser.display_name()
	GameManager.last_combat_result = result

	EventBus.combat_ended.emit(victor, loser)
	await _delay(1.4)
	SceneRouter.goto_results()


func _foe_of(actor: Combatant) -> Combatant:
	return enemy if actor == player else player


func _position_combatants(animated: bool) -> void:
	var gap: float = BAND_GAP_PX[ctx.distance]
	var player_pos := Vector2(CENTER_X - gap / 2.0, GROUND_Y)
	var enemy_pos := Vector2(CENTER_X + gap / 2.0, GROUND_Y)
	if animated:
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(player, "position", player_pos, 0.28) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(enemy, "position", enemy_pos, 0.28) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		player.position = player_pos
		enemy.position = enemy_pos


func _spawn_float_text(over: Combatant, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1))
	label.add_theme_constant_override("outline_size", 6)
	label.position = over.position + Vector2(-24, -190)
	world_root.add_child(label)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 46.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


## Centers the 1280x720 design space inside the actual expanded viewport.
func _update_world_offset() -> void:
	var size: Vector2 = get_viewport_rect().size
	world_root.position = ((size - Vector2(1280.0, 720.0)) / 2.0).floor()


func _delay(seconds: float) -> void:
	if GameManager.smoke_test:
		return
	await get_tree().create_timer(seconds).timeout
