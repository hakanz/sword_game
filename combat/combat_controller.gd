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
## Arena line: cell index -> x position (see CombatContext.CELLS).
const CELL_ORIGIN_X: float = 150.0
const CELL_SPACING_X: float = 140.0

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
	EventBus.combatant_died.connect(
			func(_c: Combatant) -> void: AudioManager.play(&"death"))

	player = Combatant.new()
	player.name = "PlayerCombatant"
	enemy = Combatant.new()
	enemy.name = "EnemyCombatant"
	world_root.add_child(player)
	world_root.add_child(enemy)
	player.setup(player_data, true, false)
	enemy.setup(enemy_data, false, true)
	ctx.setup(player, enemy)
	player.position = Vector2(_cell_to_x(player.cell), GROUND_Y)
	enemy.position = Vector2(_cell_to_x(enemy.cell), GROUND_Y)

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
			_spawn_float_text(actor, tr("status.stun.name") + "!", Color(0.95, 0.85, 0.3))
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
			# Announce every newly fallen fighter (a striker can die to their
			# own DoT in the same turn they kill - both must resolve).
			for fighter: Combatant in [player, enemy]:
				if not fighter.is_alive() and not fighter.death_announced:
					fighter.death_announced = true
					fighter.rig.play_death()
					EventBus.combatant_died.emit(fighter)
			break
	await _finish()


## Presentation wrapper around CombatResolver: wind-up animation, then the
## pure resolution, then impact/movement/rest feedback. Rules live ONLY in
## the resolver (shared with the battle simulator).
func _execute(actor: Combatant, decision: CombatDecision) -> void:
	var foe: Combatant = _foe_of(actor)
	var is_strike: bool = decision.type == Enums.ActionType.ATTACK \
			or (decision.type == Enums.ActionType.SKILL
					and decision.skill.target == SkillData.Target.FOE)

	var ranged_strike: bool = is_strike and actor.get_weapon().is_ranged()
	if is_strike:
		if decision.type == Enums.ActionType.SKILL:
			AudioManager.play(&"skill")
		actor.rig.play_attack_lunge()
		await _delay(0.16)

	var result: ActionResult = CombatResolver.execute(actor, foe, ctx, decision)

	if is_strike:
		if ranged_strike:
			await _animate_arrow(actor, foe, result.hit)
		await _present_strike(result, foe)
	else:
		match result.action:
			Enums.ActionType.SKILL:
				AudioManager.play(&"buff")
				if result.applied_status != null:
					_spawn_float_text(actor, tr(result.applied_status.name_key),
							result.applied_status.tint)
					CombatVfx.spawn_sparks(world_root, actor.position + Vector2(0, -80),
							result.applied_status.tint, 10, true)
				await _delay(0.4)
			Enums.ActionType.APPROACH, Enums.ActionType.RETREAT:
				AudioManager.play(&"step")
				_animate_step(actor)
				await _delay(0.3)
			Enums.ActionType.REST:
				if result.hp_restored > 0:
					_spawn_float_text(actor, "+%d" % result.hp_restored, Color(0.5, 0.9, 0.45))
			Enums.ActionType.SWITCH_WEAPON:
				AudioManager.play(&"switch")
				_spawn_float_text(actor, tr(actor.get_weapon().name_key),
						Color(0.85, 0.85, 0.95))
				await _delay(0.35)
			_:
				pass

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
			Enums.ActionType.keys()[result.action], detail,
			actor.current_hp, actor.max_hp, actor.current_energy, actor.max_energy,
			actor.armour_current, ctx.band()])

	EventBus.action_resolved.emit(result)
	if result.killed:
		foe.death_announced = true
		EventBus.combatant_died.emit(foe)
	await _delay(0.25)


## Placeholder arrow flight from archer to target (misses sail past).
func _animate_arrow(from: Combatant, to: Combatant, hit: bool) -> void:
	AudioManager.play(&"arrow")
	var arrow := ArrowVisual.new()
	world_root.add_child(arrow)
	arrow.position = from.position + Vector2(0, -85)
	var target: Vector2 = to.position + Vector2(0, -70)
	if not hit:
		var overshoot: float = 90.0 * signf(target.x - arrow.position.x)
		target += Vector2(overshoot, -18)
	arrow.rotation = (target - arrow.position).angle()
	var tween: Tween = create_tween()
	tween.tween_property(arrow, "position", target, 0.001 if GameManager.smoke_test else 0.2)
	await tween.finished
	arrow.queue_free()


## Impact feedback for an already-resolved strike (charter §25): sound +
## sparks + shake + floating number, tinted by armour-vs-flesh.
func _present_strike(result: ActionResult, foe: Combatant) -> void:
	if result.hit:
		foe.rig.play_hit_flash()
		var armour_only: bool = result.mitigation.hp_damage == 0
		AudioManager.play(&"armour_hit" if armour_only else &"hit")
		CombatVfx.spawn_sparks(world_root, foe.position + Vector2(0, -75),
				Color(0.72, 0.8, 0.95) if armour_only else Color(1.0, 0.55, 0.25))
		_shake(5.0 if armour_only else 8.0)
		_spawn_float_text(foe, str(result.mitigation.after_stance),
				Color(1.0, 0.85, 0.3) if armour_only else Color(1.0, 0.35, 0.3))
		if result.killed:
			foe.rig.play_death()
	else:
		AudioManager.play(&"miss")
		foe.rig.play_miss_dodge()
		CombatVfx.spawn_sparks(world_root, foe.position + Vector2(-18, -40),
				Color(0.75, 0.7, 0.6, 0.6), 6, true)
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
	if enemy.data.is_champion:
		result.champion_id = enemy.data.id
	result.victor_name = victor.display_name()
	result.loser_name = loser.display_name()
	GameManager.last_combat_result = result

	EventBus.combat_ended.emit(victor, loser)
	await _delay(1.4)
	SceneRouter.goto_results()


func _foe_of(actor: Combatant) -> Combatant:
	return enemy if actor == player else player


func _cell_to_x(cell: int) -> float:
	return CELL_ORIGIN_X + cell * CELL_SPACING_X


## Animates ONLY the fighter who moved (movement is a personal action).
func _animate_step(actor: Combatant) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(actor, "position:x", _cell_to_x(actor.cell), 0.28) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
	world_root.position = _world_offset()


func _world_offset() -> Vector2:
	var size: Vector2 = get_viewport_rect().size
	return ((size - Vector2(1280.0, 720.0)) / 2.0).floor()


## Brief impact shake around the centered world offset. Fixed (non-random)
## pattern: visuals never consume gameplay RNG. Kept small pending the
## accessibility screen-shake slider (charter §28).
func _shake(strength: float) -> void:
	if GameManager.smoke_test:
		return
	# Accessibility: player-tunable intensity (settings screen, charter §28).
	strength *= float(SaveManager.get_setting("screen_shake", 100)) / 100.0
	if strength < 0.5:
		return
	var base: Vector2 = _world_offset()
	var tween: Tween = create_tween()
	tween.tween_property(world_root, "position", base + Vector2(strength, -strength * 0.5), 0.04)
	tween.tween_property(world_root, "position", base + Vector2(-strength * 0.7, strength * 0.4), 0.05)
	tween.tween_property(world_root, "position", base + Vector2(strength * 0.35, strength * 0.2), 0.05)
	tween.tween_property(world_root, "position", base, 0.06)


func _delay(seconds: float) -> void:
	if GameManager.smoke_test:
		return
	# process_always=false: presentation timers must respect pause.
	await get_tree().create_timer(seconds, false).timeout
