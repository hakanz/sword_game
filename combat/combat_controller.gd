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

## Setting key for the screen-shake accessibility slider — shared with the
## settings screen so the reader and the writer can never drift apart.
const SHAKE_SETTING: String = "screen_shake"

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
## Dynamic framing camera (V2 §51). Optional by construction: a scene without
## it falls back to the classic static frame and a world-space shake.
@onready var camera: CombatCamera = get_node_or_null("WorldRoot/CombatCamera") as CombatCamera


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
	EventBus.crowd_state_changed.connect(_on_crowd_state_changed)

	player = Combatant.new()
	player.name = "PlayerCombatant"
	enemy = Combatant.new()
	enemy.name = "EnemyCombatant"
	world_root.add_child(player)
	world_root.add_child(enemy)
	player.setup(player_data, true, false)
	enemy.setup(enemy_data, false, true)

	# Session-6 ranged flow: after a WON fight the player's last-held weapon
	# comes back selected (a loss resets to the sidearm); a loss also drains
	# the next fight's opening energy (battle fatigue, consumed here).
	var profile: PlayerProfile = GameManager.profile
	if profile != null:
		if player.can_switch_weapon() and profile.prefers_main_weapon:
			player.switch_weapon()
		if profile.battle_fatigue:
			profile.battle_fatigue = false
			SaveManager.save_profile(profile)
			player.current_energy = roundi(player.max_energy * 0.6)
			player.energy_changed.emit(player.current_energy, player.max_energy)

	ctx.setup(player, enemy)
	player.position = Vector2(_cell_to_x(player.cell), GROUND_Y)
	enemy.position = Vector2(_cell_to_x(enemy.cell), GROUND_Y)

	turn_manager.setup([player, enemy])
	hud.setup(player, enemy, ctx)
	if camera != null:
		camera.track(player, enemy, ctx)

	_run_combat.call_deferred()


func _exit_tree() -> void:
	# A scene change during an impact freeze must never leave the whole game
	# in slow motion (CombatFeel dips Engine.time_scale globally).
	CombatFeel.release()


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
		# Charter §25 "Stunned": both rigs re-assert the reaction every turn,
		# so the stars appear the moment the status lands and clear the moment
		# it expires — including on the fighter who is not acting.
		for fighter: Combatant in [player, enemy]:
			fighter.rig.set_stunned(StatusEffectSystem.is_stunned(fighter))

		if StatusEffectSystem.is_stunned(actor):
			# Stunned: the action is lost, but end-of-turn resolution still runs.
			EventBus.turn_skipped.emit(actor)
			_spawn_float_text(actor, tr("status.stun.name") + "!", Color(0.95, 0.85, 0.3))
			await _delay(CombatFeel.BEAT_STUN_SKIPPED)
		else:
			var decision: CombatDecision
			if actor.is_player_controlled and not GameManager.smoke_test:
				if actor.current_energy <= 0 \
						and CombatAction.is_valid(Enums.ActionType.REST, actor, ctx):
					# Session-6 owner design: an empty energy pool rests
					# automatically — no menu for a fighter who cannot act.
					decision = CombatDecision.new()
					decision.type = Enums.ActionType.REST
					_spawn_float_text(actor, tr("combat.float.auto_rest"),
							Color(0.7, 0.85, 0.7))
					await _delay(0.5)
				else:
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
			await _delay(CombatFeel.BEAT_STATUS_TICK)

		# Death check (charter §11) — combat ends immediately on a kill
		# (including a fighter succumbing to their own wounds' DoTs).
		if not player.is_alive() or not enemy.is_alive():
			# Announce every newly fallen fighter (a striker can die to their
			# own DoT in the same turn they kill - both must resolve).
			for fighter: Combatant in [player, enemy]:
				if not fighter.is_alive() and not fighter.death_announced:
					fighter.death_announced = true
					fighter.rig.play_death()
					if camera != null:
						camera.punch_in(true)
					EventBus.combatant_died.emit(fighter)
			break
	await _finish()


## Presentation wrapper around CombatResolver: wind-up animation, then the
## pure resolution, then impact/movement/rest feedback. Rules live ONLY in
## the resolver (shared with the battle simulator).
func _execute(actor: Combatant, decision: CombatDecision) -> void:
	var foe: Combatant = _foe_of(actor)
	var cell_before: int = actor.cell
	var is_strike: bool = decision.type == Enums.ActionType.ATTACK \
			or (decision.type == Enums.ActionType.SKILL
					and decision.skill.target == SkillData.Target.FOE)

	var weapon_class: Enums.WeaponClass = actor.get_weapon().weapon_class
	var ranged_strike: bool = is_strike and actor.get_weapon().is_ranged()
	if is_strike:
		if decision.type == Enums.ActionType.SKILL:
			AudioManager.play(&"skill")
		actor.rig.play_attack_lunge(ranged_strike)
		# Wait for the blow to actually ARRIVE (anticipation + stroke): a maul
		# takes visibly longer than a dagger, and the impact feedback must
		# land on the connecting frame, not while the arm is still cocked
		# (CombatFeel is the ONE home of that table — V2 §51).
		await _delay(CombatFeel.impact_delay(weapon_class))

	var result: ActionResult = CombatResolver.execute(actor, foe, ctx, decision)

	if is_strike:
		if ranged_strike:
			await _animate_arrow(actor, foe, result.hit)
		await _present_strike(result, foe, weapon_class)
		if decision.type == Enums.ActionType.SKILL and decision.skill.taunts:
			actor.rig.play_taunt()
			await _delay(CombatFeel.BEAT_TAUNT)
	else:
		match result.action:
			Enums.ActionType.SKILL:
				AudioManager.play(&"buff")
				if decision.skill.taunts:
					actor.rig.play_taunt()
				if result.applied_status != null:
					_spawn_float_text(actor, tr(result.applied_status.name_key),
							result.applied_status.tint)
					CombatVfx.spawn_status_burst(world_root,
							actor.position + Vector2(0, -100), result.applied_status)
				await _delay(CombatFeel.BEAT_SKILL)
			Enums.ActionType.DEFEND:
				# Charter §25 "Block": the guard coming up is its own beat.
				actor.rig.play_block()
				await _delay(CombatFeel.BEAT_BLOCK)
			Enums.ActionType.APPROACH, Enums.ActionType.RETREAT:
				AudioManager.play(&"step")
				_animate_step(actor, absi(actor.cell - cell_before))
				await _delay(CombatFeel.BEAT_MOVE)
			Enums.ActionType.REST:
				actor.rig.play_rest()
				CombatVfx.spawn_sparks(world_root, actor.position + Vector2(0, -90),
						Color(0.5, 0.9, 0.45), 12, true)
				if result.hp_restored > 0:
					_spawn_float_text(actor, "+%d" % result.hp_restored, Color(0.5, 0.9, 0.45))
				await _delay(CombatFeel.BEAT_REST)
			Enums.ActionType.SWITCH_WEAPON:
				AudioManager.play(&"switch")
				actor.rig.play_switch_flourish()
				_spawn_float_text(actor, tr(actor.get_weapon().name_key),
						Color(0.85, 0.85, 0.95))
				await _delay(CombatFeel.BEAT_SWITCH)
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
	await _delay(CombatFeel.BEAT_AFTER_ACTION)


## Placeholder arrow flight from archer to target (misses sail past).
func _animate_arrow(from: Combatant, to: Combatant, hit: bool) -> void:
	AudioManager.play(&"arrow")
	var arrow := ArrowVisual.new()
	world_root.add_child(arrow)
	arrow.position = from.position + Vector2(0, -112)
	var target: Vector2 = to.position + Vector2(0, -92)
	if not hit:
		var overshoot: float = 90.0 * signf(target.x - arrow.position.x)
		target += Vector2(overshoot, -18)
	arrow.rotation = (target - arrow.position).angle()
	var tween: Tween = create_tween()
	tween.tween_property(arrow, "position", target, 0.001 if GameManager.smoke_test else 0.2)
	await tween.finished
	arrow.queue_free()


## Impact feedback for an already-resolved strike (charter §25): sound +
## sparks + hit-stop + shake + floating number, tinted by armour-vs-flesh.
## Weight comes from CombatFeel: the freeze, the shake and the recovery beat
## all scale with the weapon class that threw the blow (V2 §51).
func _present_strike(
		result: ActionResult, foe: Combatant, weapon_class: Enums.WeaponClass) -> void:
	var from_the_right: bool = foe.position.x < result.actor.position.x
	var chest: Vector2 = foe.position + Vector2(0, -95)
	if result.hit:
		var armour_only: bool = result.mitigation.hp_damage == 0
		# Charter §25: a crit rocks the fighter, an ordinary blow flinches them.
		if result.crit:
			foe.rig.play_critical_reaction()
		else:
			foe.rig.play_hit_flash()
		AudioManager.play(&"crit" if result.crit else
				(&"armour_hit" if armour_only else &"hit"))
		# Melee blows carve a visible arc; the element burst rides on-hit
		# statuses (flame skill -> flame at the target).
		if not result.actor.get_weapon().is_ranged():
			CombatVfx.spawn_slash(world_root, chest, from_the_right)
		CombatVfx.spawn_sparks(world_root, chest,
				Color(0.72, 0.8, 0.95) if armour_only else Color(1.0, 0.55, 0.25))
		if result.crit:
			CombatVfx.spawn_crit_burst(world_root, chest)
		# Blocked on the guard (charter §25 "shield impact") vs carried through
		# to flesh (charter §25 "blood particles", separately toggleable).
		if result.target_was_defending:
			CombatVfx.spawn_block_impact(world_root, chest)
		if result.mitigation.hp_damage > 0:
			CombatVfx.spawn_blood(world_root, chest, from_the_right,
					20 if result.crit else 14)
		if result.armour_broken:
			AudioManager.play(&"armour_hit")
			CombatVfx.spawn_armour_break(world_root, chest)
			_spawn_float_text(foe, tr("combat.float.armour_break"),
					Color(0.82, 0.86, 0.95), 26)
		CombatVfx.spawn_element_hit(world_root, chest,
				result.actor.get_weapon().damage_type)
		if result.applied_status != null:
			CombatVfx.spawn_status_burst(world_root, chest, result.applied_status)
		# Slam order: push the frame in, freeze the world on the impact
		# frame, then let the shake ring out as time resumes.
		if camera != null and (result.crit or result.killed):
			camera.punch_in(result.killed)
		await CombatFeel.hit_stop(get_tree(), weapon_class, result.crit)
		_shake((13.0 if result.crit else (5.0 if armour_only else 8.0))
				* CombatFeel.shake_scale(weapon_class))
		if result.crit:
			_spawn_float_text(foe, tr("combat.float.crit").format(
					{"damage": result.mitigation.after_stance}),
					Color(1.0, 0.45, 0.1), 40)
		else:
			_spawn_float_text(foe, str(result.mitigation.after_stance),
					Color(1.0, 0.85, 0.3) if armour_only else Color(1.0, 0.35, 0.3))
		if result.killed:
			foe.rig.play_death()
	elif result.target_was_defending:
		# Charter §25 "Parry": a guarded fighter turning the blow aside is a
		# different beat from simply not being there.
		AudioManager.play(&"armour_hit")
		foe.rig.play_parry()
		CombatVfx.spawn_block_impact(world_root, chest)
		_spawn_float_text(foe, tr("combat.float.parry"), Color(0.78, 0.86, 1.0))
	else:
		AudioManager.play(&"miss")
		foe.rig.play_miss_dodge()
		CombatVfx.spawn_sparks(world_root, foe.position + Vector2(-18, -50),
				Color(0.75, 0.7, 0.6, 0.6), 6, true)
		_spawn_float_text(foe, tr("combat.float.miss"), Color(0.8, 0.8, 0.85))
	# Recovery beat: heavy weapons take their time coming back to guard.
	await _delay(CombatFeel.recovery_time(weapon_class))


func _finish() -> void:
	# Never carry an impact freeze into the celebration/results flow.
	CombatFeel.release()
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
	result.player_hits = player.hits_landed
	result.player_actions = player.actions_taken
	result.player_ended_wielding_main = player.wielding_main
	result.player_could_switch = player.can_switch_weapon()
	result.enemy_level = enemy.data.level
	if enemy.data.is_champion:
		result.champion_id = enemy.data.id
	if GameManager.opponent_is_rival:
		result.rival_id = enemy.data.id
		result.rival_weapon_id = enemy.main_weapon.id
	result.victor_name = victor.display_name()
	result.loser_name = loser.display_name()
	GameManager.last_combat_result = result

	EventBus.combat_ended.emit(victor, loser)
	# The winner celebrates on the sand before the results (session 6).
	victor.rig.play_victory()
	await _delay(1.6)
	SceneRouter.goto_results()


## The pit changing its mind is an EVENT, not a stat tick: only the two ends
## of the meter get a roar/groan, so the feedback stays meaningful (V2 §54).
func _on_crowd_state_changed(fighter: Combatant, state: int, rising: bool) -> void:
	if GameManager.smoke_test:
		return
	if rising and state >= CrowdSystem.State.EXCITED:
		AudioManager.play(&"crowd_roar", "Ambience")
		_spawn_float_text(fighter, tr("combat.float.crowd_up"), Color(1.0, 0.72, 0.32), 26)
		CombatVfx.spawn_crowd_flare(world_root, fighter.position + Vector2(0, -110), true)
		# Charter §25 "Taunt": a fighter the stands have taken to plays up to
		# them. Only at the top of the meter, so it stays an event.
		if state >= CrowdSystem.State.FRENZIED and fighter.is_alive():
			fighter.rig.play_taunt()
	elif not rising and state <= CrowdSystem.State.BORED:
		AudioManager.play(&"crowd_groan", "Ambience")
		_spawn_float_text(fighter, tr("combat.float.crowd_down"), Color(0.72, 0.7, 0.78), 22)
		CombatVfx.spawn_crowd_flare(world_root, fighter.position + Vector2(0, -110), false)


func _foe_of(actor: Combatant) -> Combatant:
	return enemy if actor == player else player


func _cell_to_x(cell: int) -> float:
	return CELL_ORIGIN_X + cell * CELL_SPACING_X


## Animates ONLY the fighter who moved (movement is a personal action).
## Speed follows Agility (session-5 owner design): nimble fighters cross the
## sand visibly faster; a small hop sells the footwork.
func _animate_step(actor: Combatant, cells: int) -> void:
	var agility: int = actor.attributes.agility
	var duration: float = clampf(0.34 - 0.012 * (agility - 8), 0.16, 0.42)
	var tween: Tween = create_tween()
	tween.tween_property(actor, "position:x", _cell_to_x(actor.cell), duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Charter §25 Walk/Run: the gait itself belongs to the rig, and the number
	# of cells being crossed is what decides between the two.
	actor.rig.play_move(maxi(cells, 1), duration)


func _spawn_float_text(
		over: Combatant, text: String, color: Color, font_size: int = 30) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1))
	label.add_theme_constant_override("outline_size", 6)
	label.position = over.position + Vector2(-24, -235)
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


## Brief impact shake. Fixed (non-random) pattern: visuals never consume
## gameplay RNG. Strength arrives already weighted by the weapon's weight
## (CombatFeel.shake_scale) and is scaled here by the player's screen-shake
## setting (charter §28) — the one place that decides shake intensity.
## The camera performs it when present; the world-offset fallback keeps a
## camera-less scene working.
func _shake(strength: float) -> void:
	if GameManager.smoke_test:
		return
	# Accessibility: player-tunable intensity (settings screen, charter §28).
	strength *= float(SaveManager.get_setting(SHAKE_SETTING, 100)) / 100.0
	if strength < 0.5:
		return
	if camera != null:
		camera.shake(strength)
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
